/// Profiles inside a profile's session: the current profile (for the chip),
/// first-boot mode, the one-time "Set your PIN", the sleep lock screen, and
/// switching (the in-session picker, the "Switching..." page and the
/// not-responding pop-up). The shell owns one [ProfileSession].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api.dart' show AppSource, RunningApp;
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../pages.dart' show FullPage;
import '../session_ending.dart';
import '../widgets.dart';
import 'first_boot_page.dart';
import 'picker_view.dart';
import 'profile_form.dart';
import 'profile_loading.dart';
import 'profile_ui.dart';

/// The session's text entry for profile names: the dialog with the
/// daemon's on-screen keyboard.
EditText sessionEditText(BuildContext context) =>
    ({required title, required initial, hint}) => showTextEntry(
      context,
      title: title,
      initial: initial,
      body: hint,
      submitLabel: 'Done',
      submit: (text) async => nameProblem(text),
      // The keyboard's Enter only closes it; Done or Cancel decides.
      enterSubmits: false,
    );

/// The current profile and the pages the session itself raises.
class ProfileSession extends ChangeNotifier {
  ProfileSession({
    required this.services,
    required this.modals,
    required this.context,
    required this.running,
    this.ending,
  });

  final SystemServices services;
  final ModalController modals;

  /// A context under the shell's [ModalScope].
  final BuildContext Function() context;

  /// What runs in this profile now (for "Switching closes ...").
  final List<RunningApp> Function() running;

  /// The shell's "session ending" state: set once a switch has begun or
  /// the guest session ends, so the service going away with the session
  /// shows no connection error.
  final SessionEndingController? ending;

  ProfilesRepository get profiles => services.profiles;

  CurrentProfile? current;
  final _subs = <StreamSubscription<Object?>>[];
  ModalHandle<String>? _lock;
  bool _switching = false;
  bool _started = false;

  /// Loads the current profile and raises what it needs (first-boot mode,
  /// "Set your PIN", the lock screen). Call again after a reconnect.
  Future<void> start() async {
    if (!_started) {
      _started = true;
      _subs
        ..add(profiles.lockChanges.listen(_onLock))
        ..add(profiles.changes.listen(_onChanges))
        ..add(profiles.switchEvents.listen(_onSwitchEvent));
    }
    final CurrentProfile c;
    try {
      c = await profiles.current();
    } on SystemException {
      // A daemon without profiles (or not reachable yet): no chip.
      return;
    }
    current = c;
    notifyListeners();
    if (c.setupRequired) {
      await _firstBoot();
    } else if (!c.pinSet && !c.guest) {
      await _setFirstPin();
    }
    if (current?.screenLocked ?? false) _onLock(true);
  }

  void _onChanges(List<ProfileInfo> list) {
    final c = current;
    if (c == null) return;
    final me = list.where((p) => p.id == c.id).firstOrNull;
    if (me == null) return;
    current = c.copyWith(name: me.name, color: me.color, locked: me.locked);
    notifyListeners();
    // A schema-1 box reports no PIN to set until its migration ran; ask for
    // one as soon as the migrated profile has none.
    if (c.pinSet && !c.guest && !_askingPin) unawaited(_recheckPin());
  }

  Future<void> _recheckPin() async {
    try {
      final c = await profiles.current();
      if (c.pinSet || c.guest || c.setupRequired || _askingPin) return;
      current = current?.copyWith(pinSet: false);
      await _setFirstPin();
    } on SystemException {
      // Asked again with the next change or start.
    }
  }

  // ---- first boot and the first PIN

  Future<void> _firstBoot() async {
    await modals.show<void>(
      (context, modal) => FirstBootPage(
        modal: modal,
        services: services,
        onCreated: () async {
          try {
            current = await profiles.current();
            notifyListeners();
          } on SystemException {
            // The chip appears with the next start.
          }
        },
      ),
    );
  }

  bool _askingPin = false;

  Future<void> _setFirstPin() async {
    if (_askingPin) return;
    _askingPin = true;
    try {
      await _askFirstPin();
    } finally {
      _askingPin = false;
    }
  }

  Future<void> _askFirstPin() async {
    final ctx = context();
    String? first;
    var unavailable = false;
    while (true) {
      first = await showPinEntry(
        ctx,
        title: 'Set your PIN',
        body:
            'Choose a PIN for ${current?.displayName ?? 'this profile'}: '
            '4 to 8 digits.',
        disclaimer: true,
        canLeave: false,
        submitLabel: 'Next',
        check: (_) async => const PinAccepted(),
      );
      if (first == null || !ctx.mounted) return;
      final again = await showPinEntry(
        ctx,
        title: 'Set your PIN',
        body: 'Type the PIN again.',
        check: (pin) async {
          if (pin != first) {
            return const PinFailed("The PINs don't match.");
          }
          try {
            await profiles.setPin(pin);
            return const PinAccepted();
          } on SystemException catch (e) {
            if (e.kind == SystemErrorKind.unavailable) {
              // No PINs on this box yet (schema 1): never trap the person
              // behind a page that cannot succeed.
              unavailable = true;
              return const PinAccepted();
            }
            return PinAttempt.fromError(e);
          } catch (e) {
            return PinAttempt.fromError(e);
          }
        },
      );
      if (unavailable) return;
      if (again != null) break;
      if (!ctx.mounted) return;
    }
    current = current?.copyWith(pinSet: true);
    notifyListeners();
  }

  // ---- the sleep lock

  void _onLock(bool locked) {
    if (!locked) {
      _lock?.close();
      _lock = null;
      current = current?.copyWith(screenLocked: false);
      return;
    }
    if (_lock != null) return;
    final c = current;
    current = c?.copyWith(screenLocked: true);
    final opened = modals.open<String>(
      (context, modal) => PinEntryPage(
        modal: modal,
        title: c?.displayName ?? 'Locked',
        body: 'Type the PIN to unlock.',
        forgotPinFor: c?.displayName,
        canLeave: false,
        avatar: ProfileAvatar(
          initial: c?.initial ?? '?',
          color: c?.color,
          locked: true,
          size: 200,
        ),
        check: (pin) async {
          try {
            await profiles.unlock(pin);
            return const PinAccepted();
          } catch (e) {
            return PinAttempt.fromError(e);
          }
        },
        extraActions: [
          (
            label: 'Switch profile',
            onSelect: () => unawaited(switchProfile(context)),
          ),
        ],
      ),
    );
    _lock = opened.handle;
    unawaited(
      opened.result.then((_) {
        if (_lock == opened.handle) _lock = null;
      }),
    );
  }

  // ---- switching

  /// Switch profile: the same picker as at boot, over the session. The
  /// current profile stays open (choosing it, or B, goes back to it); another
  /// profile or Guest goes straight to the Switching page (one confirmation
  /// only while a game runs; a locked profile's PIN first); Add profile
  /// creates one and switches to it.
  Future<void> switchProfile(BuildContext context) async {
    final ProfilesState state;
    try {
      state = await profiles.list();
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(
          context,
          title: "Can't switch right now",
          body: e.message,
        );
      }
      return;
    }
    if (!context.mounted) return;
    final me = current;
    final tile = await ModalScope.of(context).show<PickerTile>(
      (context, modal) => SessionPickerPage(
        modal: modal,
        state: state,
        current: me,
        system: services.system,
        changes: profiles.changes,
      ),
    );
    if (tile == null || tile.current || !context.mounted) return;
    if (tile.kind == PickerTileKind.add) {
      final made = await createProfileFlow(
        context,
        services,
        taken: [for (final p in state.profiles) p.name],
      );
      if (made == null || !context.mounted) return;
      if (!await _confirmGame(context)) return;
      if (!context.mounted) return;
      // Its PIN was just typed twice: no third time.
      await startSwitch(
        context,
        made.id,
        made.name,
        pin: made.locked ? made.pin : null,
      );
      return;
    }
    if (!await _confirmGame(context)) return;
    if (!context.mounted) return;
    await startSwitch(
      context,
      tile.id!,
      tile.name,
      locked: tile.locked,
      avatar: tile.kind == PickerTileKind.profile
          ? ProfileAvatar(
              initial: tile.initial ?? '?',
              color: tile.color,
              locked: true,
              size: 200,
            )
          : null,
    );
  }

  /// "Switch to this profile" (Settings -> Profiles): as choosing its tile in
  /// the picker.
  Future<void> switchToProfile(BuildContext context, ProfileInfo p) async {
    if (!await _confirmGame(context)) return;
    if (!context.mounted) return;
    await startSwitch(
      context,
      p.id,
      p.name,
      locked: p.locked,
      avatar: ProfileAvatar(
        initial: p.initial,
        color: p.color,
        locked: true,
        size: 200,
      ),
    );
  }

  /// A running game loses what it has not saved: the one question before a
  /// switch. True: go on.
  Future<bool> _confirmGame(BuildContext context) async {
    final games = running().where((a) => a.source == AppSource.steam).toList();
    if (games.isEmpty) return true;
    final sure = await showConfirm(
      context,
      title: '${games.first.name} is still running',
      body: 'Unsaved progress is lost. Switch anyway?',
      confirmLabel: 'Close it and switch',
      danger: true,
    );
    return sure != null;
  }

  /// `session.switch_profile`, then the Switching page until the session
  /// ends (or the switch is cancelled). A [locked] profile's PIN is asked
  /// first, on the PIN pad, while this session stays as it is: a wrong PIN
  /// says so and B goes back, nothing closes. Only the right PIN starts the
  /// switch (the daemon checks it before closing anything, and the greeter
  /// then enters the profile without asking again). [pin]: already known
  /// (a profile just created).
  Future<void> startSwitch(
    BuildContext context,
    String id,
    String name, {
    bool locked = false,
    String? pin,
    ProfileAvatar? avatar,
  }) async {
    // From here on, switch events belong to this switch (not to one started
    // elsewhere).
    _switching = true;
    try {
      if (locked && pin == null) {
        final typed = await showPinEntry(
          context,
          title: 'Switch to $name',
          body: "Type $name's PIN.",
          avatar: avatar,
          forgotPinFor: name,
          check: (p) async {
            try {
              await profiles.switchTo(id, pin: p);
              return const PinAccepted();
            } catch (e) {
              return PinAttempt.fromError(e);
            }
          },
        );
        if (typed == null) return;
      } else {
        try {
          await profiles.switchTo(id, pin: pin);
        } on SystemException catch (e) {
          if (context.mounted) {
            await showMessage(
              context,
              title: "Couldn't switch",
              body: e.message,
            );
          }
          return;
        }
      }
      _lock?.close();
      // The switch has begun: this session ends with it (unless cancelled).
      await _whileEnding(
        SessionEnding(
          title: 'Switching to $name…',
          identity: id == CurrentProfile.guestId
              ? LoadingIdentity.guestIdentity
              : LoadingIdentity(name: name, color: avatar?.color),
          cover: false,
        ),
        () => modals.show<void>(
          (context, modal) => SwitchingPage(
            modal: modal,
            profiles: profiles,
            targetName: name,
            fromName: current?.displayName ?? 'this profile',
          ),
        ),
      );
    } finally {
      _switching = false;
    }
  }

  void _onSwitchEvent(SwitchEvent e) {
    // A switch the launcher did not start (the quick menu): show it too.
    if (_switching) return;
    _switching = true;
    unawaited(
      _whileEnding(
        SessionEnding(
          title: 'Switching profile…',
          identity: _identity(),
          cover: false,
        ),
        () => modals.show<void>(
          (context, modal) => SwitchingPage(
            modal: modal,
            profiles: profiles,
            targetName: null,
            fromName: current?.displayName ?? 'this profile',
            first: e,
          ),
        ),
      ).whenComplete(() => _switching = false),
    );
  }

  /// The current profile, for the ending page.
  LoadingIdentity _identity() {
    final c = current;
    if (c == null) return const LoadingIdentity();
    if (c.guest) return LoadingIdentity.guestIdentity;
    return LoadingIdentity(name: c.name, color: c.color);
  }

  /// [page] (the Switching page) with the session ending: it closes only
  /// when the switch was cancelled, and then the session goes on.
  Future<void> _whileEnding(
    SessionEnding e,
    Future<void> Function() page,
  ) async {
    ending?.begin(e);
    try {
      await page();
    } finally {
      ending?.abandon(e);
    }
  }

  /// End guest session: confirm, then the session ends.
  Future<void> endGuest(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'End the guest session?',
      body:
          'Everything the guest did (sign-ins, apps, files) is removed when '
          'the box restarts.',
      confirmLabel: 'End guest session',
      danger: true,
    );
    if (ok == null || !context.mounted) return;
    try {
      await profiles.endGuest();
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
      return;
    }
    if (!context.mounted) return;
    _switching = true;
    try {
      await _whileEnding(
        const SessionEnding(
          title: 'Ending the guest session…',
          identity: LoadingIdentity.guestIdentity,
          cover: false,
        ),
        () => modals.show<void>(
          (context, modal) => SwitchingPage(
            modal: modal,
            profiles: profiles,
            targetName: null,
            fromName: 'Guest',
          ),
        ),
      );
    } finally {
      _switching = false;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}

/// A new profile from Settings or the in-session picker: the form, the
/// create job ("Getting things ready"). Null: given up or it failed (said).
Future<({String id, String name, String pin, bool locked})?> createProfileFlow(
  BuildContext context,
  SystemServices services, {
  required List<String> taken,
}) async {
  final form = await showProfileForm(
    context,
    editText: sessionEditText(context),
    taken: taken,
  );
  if (form == null || !context.mounted) return null;
  final ProfileJob job;
  try {
    job = await services.profiles.create(
      name: form.name,
      color: form.color,
      pin: form.pin,
      locked: form.locked,
    );
  } catch (e) {
    if (context.mounted) {
      await showMessage(
        context,
        title: "Couldn't add the profile",
        body: e is SystemException && e.kind == SystemErrorKind.profileLimit
            ? 'This box has the maximum number of profiles.'
            : (e is SystemException ? e.message : '$e'),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  final ok = await showProfileJob(
    context,
    jobs: services.jobs,
    job: job.job,
    what: "Creating ${form.name}'s profile... (about a minute)",
  );
  return ok
      ? (id: job.id, name: form.name, pin: form.pin, locked: form.locked)
      : null;
}

/// The picker inside a session: the boot picker's screen with the current
/// profile marked "Open" and focused. Closes with the chosen tile (the
/// current one: back to the session), or null on B.
class SessionPickerPage extends StatefulWidget {
  const SessionPickerPage({
    super.key,
    required this.modal,
    required this.state,
    required this.current,
    this.system,
    this.changes,
  });

  final ModalHandle<PickerTile> modal;
  final ProfilesState state;
  final CurrentProfile? current;

  /// `profiles_changed`: the tiles follow it (a profile removed or added
  /// while the picker is up).
  final Stream<List<ProfileInfo>>? changes;

  /// Power (sleep, restart, shut down); null: no Power row.
  final SystemRepository? system;

  @override
  State<SessionPickerPage> createState() => _SessionPickerPageState();
}

class _SessionPickerPageState extends State<SessionPickerPage> {
  String? _message;
  bool _focused = false;
  late ProfilesState _state = widget.state;
  StreamSubscription<List<ProfileInfo>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.changes?.listen((list) {
      if (!mounted) return;
      setState(
        () => _state = ProfilesState(
          profiles: list,
          guestEnabled: _state.guestEnabled,
          guestUsage: _state.guestUsage,
          max: _state.max,
          firstBoot: _state.firstBoot,
        ),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  bool get _guestSession => widget.current?.guest ?? false;

  List<PickerTile> _tiles() {
    final me = widget.current?.id;
    return pickerTiles(
      profiles: [
        for (final p in _state.profiles)
          PickerTile.profile(
            id: p.id,
            name: p.name,
            initial: p.initial,
            color: p.color,
            locked: p.locked,
            admin: p.admin,
            current: !_guestSession && p.id == me,
          ),
      ],
      guest: _state.guestEnabled || _guestSession,
      guestCurrent: _guestSession,
      max: _state.max,
    );
  }

  Future<void> _power(PowerAction a) async {
    final s = widget.system;
    if (s == null) return;
    try {
      if (a == PowerAction.sleep) {
        await s.power(a);
      } else {
        await endSessionWith(context, powerEnding(a), () => s.power(a));
      }
    } on SystemException catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.modal.region;
    final tiles = _tiles();
    if (!_focused) {
      _focused = true;
      final i = tiles.indexWhere((t) => t.current);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) region.model.goTo(0, i < 0 ? 0 : i);
      });
    }
    return ProfilePickerView(
      region: region,
      tiles: tiles,
      onSelect: widget.modal.close,
      power: [
        if (widget.system != null) ...[
          PowerAction.sleep,
          PowerAction.restart,
          PowerAction.shutdown,
        ],
      ],
      onPower: (a) => unawaited(_power(a)),
      message: _message,
    );
  }
}

/// "Switching to Sam...": what the switch is doing, and the not-responding
/// pop-up when an app does not close. Never closed by Back; Cancel switch
/// (in the pop-up) closes it.
class SwitchingPage extends StatefulWidget {
  const SwitchingPage({
    super.key,
    required this.modal,
    required this.profiles,
    required this.targetName,
    required this.fromName,
    this.first,
  });

  final ModalHandle<void> modal;
  final ProfilesRepository profiles;

  /// Null: the picker (ending the guest session, a switch from elsewhere).
  final String? targetName;
  final String fromName;
  final SwitchEvent? first;

  @override
  State<SwitchingPage> createState() => _SwitchingPageState();
}

class _SwitchingPageState extends State<SwitchingPage> {
  StreamSubscription<SwitchEvent>? _sub;
  SwitchProgress _progress = const SwitchProgress(SwitchStage.closingApps);
  SwitchBlocked? _blocked;
  String? _error;
  bool _busy = false;

  /// Seconds since the last `switch_blocked`: the pop-up keeps counting
  /// ("YouTube isn't responding (14 s)") from its `waited_s`.
  int _since = 0;
  Timer? _tick;

  void _setBlocked(SwitchBlocked? b) {
    _blocked = b;
    _since = 0;
    _tick?.cancel();
    _tick = b == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _since++);
          });
  }

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () => false;
    final f = widget.first;
    if (f != null) _apply(f);
    _sub = widget.profiles.switchEvents.listen((e) {
      if (!mounted) return;
      if (e is SwitchProgress && e.stage == SwitchStage.cancelled) {
        // Cancelled (here or by another client): the session stays.
        widget.modal.close();
        return;
      }
      setState(() => _apply(e));
    });
  }

  void _apply(SwitchEvent e) {
    switch (e) {
      case SwitchProgress():
        _progress = e;
        _setBlocked(null);
      case SwitchBlocked():
        _setBlocked(e);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _do(Future<void> Function() f, {bool closes = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
      if (!mounted) return;
      if (closes) {
        widget.modal.close();
        return;
      }
      setState(() => _setBlocked(null));
    } on SystemException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    final b = _blocked;
    region.setRows([NavRow('buttons', b == null ? 1 : 3)]);
    final stage = switch (_progress.stage) {
      SwitchStage.closingApps =>
        _progress.appName == null
            ? 'Closing apps...'
            : 'Closing ${_progress.appName}...',
      SwitchStage.closingSteam => 'Closing Steam...',
      SwitchStage.ending || SwitchStage.cancelled =>
        widget.targetName == null
            ? 'Opening the profile picker...'
            : 'Opening ${widget.targetName}...',
    };
    return FullPage(
      title: widget.targetName == null
          ? 'Leaving ${widget.fromName}'
          : 'Switching to ${widget.targetName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b == null)
            StatusLine(stage, busy: true)
          else ...[
            Text(
              "${b.appName} isn't responding (${b.waited.inSeconds + _since} s).",
              style: t.title,
            ),
            const SizedBox(height: HinterTokens.s1),
            Text('Force close can lose unsaved data.', style: t.body),
          ],
          if (_error != null) ...[
            const SizedBox(height: HinterTokens.s2),
            StatusLine(_error!, error: true),
          ],
          const SizedBox(height: HinterTokens.s4),
          DialogButtons(
            region: region,
            rowKey: 'buttons',
            buttons: b == null
                ? [btn('Please wait', null, enabled: false)]
                : [
                    btn(
                      'Keep waiting',
                      () => unawaited(_do(widget.profiles.keepWaiting)),
                      primary: true,
                      enabled: !_busy,
                    ),
                    btn(
                      'Force close',
                      () => unawaited(
                        _do(() => widget.profiles.forceClose(b.appId)),
                      ),
                      danger: true,
                      enabled: !_busy,
                    ),
                    btn(
                      'Cancel switch',
                      () => unawaited(
                        _do(widget.profiles.cancelSwitch, closes: true),
                      ),
                      enabled: !_busy,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
