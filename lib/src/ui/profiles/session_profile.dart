/// Profiles inside a profile's session: the current profile (for the chip),
/// first-boot mode, the one-time "Set your PIN", the sleep lock screen, and
/// switching (the in-session picker, the "Switching..." page and the
/// not-responding pop-up). The shell owns one [ProfileSession].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api.dart' show AppSource, NavAction, NavPhase, RunningApp;
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';
import 'first_boot_page.dart';
import 'profile_form.dart';
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
    );

/// The current profile and the pages the session itself raises.
class ProfileSession extends ChangeNotifier {
  ProfileSession({
    required this.services,
    required this.modals,
    required this.context,
    required this.running,
  });

  final SystemServices services;
  final ModalController modals;

  /// A context under the shell's [ModalScope].
  final BuildContext Function() context;

  /// What runs in this profile now (for "Switching closes ...").
  final List<RunningApp> Function() running;

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
            'Profiles have PINs now. Choose one for '
            '${current?.displayName ?? 'this profile'}: 4 to 8 digits.',
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
            return const PinFailed("The two PINs didn't match.");
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
        body: 'This profile is locked. Type its PIN to go on.',
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

  /// The in-session picker, the confirmations, then the Switching page.
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
    final target = await ModalScope.of(context).show<_Target>(
      (context, modal) =>
          _SwitchPicker(modal: modal, state: state, currentId: me?.id),
    );
    if (target == null || !context.mounted) return;
    final apps = running();
    if (apps.isNotEmpty) {
      final names = apps.map((a) => a.name).join(', ');
      final ok = await showConfirm(
        context,
        title: 'Switch to ${target.name}?',
        body:
            'Switching closes everything running in '
            "${me?.displayName ?? 'this profile'}'s profile: $names.",
        confirmLabel: 'Switch',
      );
      if (ok == null || !context.mounted) return;
      final games = apps.where((a) => a.source == AppSource.steam).toList();
      if (games.isNotEmpty) {
        final sure = await showConfirm(
          context,
          title: '${games.first.name} is still running',
          body:
              'A game is running. Progress that is not saved is lost when '
              'it closes. Switch anyway?',
          confirmLabel: 'Close it and switch',
          danger: true,
        );
        if (sure == null || !context.mounted) return;
      }
    }
    await startSwitch(context, target.id, target.name);
  }

  /// `session.switch_profile`, then the Switching page until the session
  /// ends (or the switch is cancelled).
  Future<void> startSwitch(BuildContext context, String id, String name) async {
    try {
      await profiles.switchTo(id);
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(context, title: "Couldn't switch", body: e.message);
      }
      return;
    }
    _switching = true;
    _lock?.close();
    try {
      await modals.show<void>(
        (context, modal) => SwitchingPage(
          modal: modal,
          profiles: profiles,
          targetName: name,
          fromName: current?.displayName ?? 'this profile',
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
      modals
          .show<void>(
            (context, modal) => SwitchingPage(
              modal: modal,
              profiles: profiles,
              targetName: null,
              fromName: current?.displayName ?? 'this profile',
              first: e,
            ),
          )
          .whenComplete(() => _switching = false),
    );
  }

  /// End guest session: confirm, then the session ends.
  Future<void> endGuest(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'End the guest session?',
      body:
          'The guest session ends and the profile picker opens. Everything '
          'the guest did (sign-ins, installed apps, files) is removed when '
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
    await modals.show<void>(
      (context, modal) => SwitchingPage(
        modal: modal,
        profiles: profiles,
        targetName: null,
        fromName: 'Guest',
      ),
    );
    _switching = false;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}

class _Target {
  const _Target(this.id, this.name);
  final String id;
  final String name;
}

/// The picker inside a session: every other profile, and Guest.
class _SwitchPicker extends StatelessWidget {
  const _SwitchPicker({
    required this.modal,
    required this.state,
    required this.currentId,
  });

  final ModalHandle<_Target> modal;
  final ProfilesState state;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final p in state.profiles)
        if (p.id != currentId) p,
    ];
    final guest = state.guestEnabled && currentId != CurrentProfile.guestId;
    final n = others.length + (guest ? 1 : 0);
    modal.region.setRows([if (n > 0) NavRow('tiles', n)]);
    final t = HinterTheme.of(context);
    return FullPage(
      title: 'Switch profile',
      subtitle: 'B goes back.',
      child: n == 0
          ? Text(
              'There is no other profile yet. Add one in Settings, Profiles.',
              style: t.body,
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(vertical: HinterTokens.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < others.length; i++) ...[
                    if (i > 0) const SizedBox(width: HinterTokens.s4),
                    NavFocusable(
                      region: modal.region,
                      rowKey: 'tiles',
                      col: i,
                      onSelect: () =>
                          modal.close(_Target(others[i].id, others[i].name)),
                      builder: (_, f) => ProfileTile(
                        name: others[i].name,
                        initial: others[i].initial,
                        color: others[i].color,
                        locked: others[i].locked,
                        admin: others[i].admin,
                        focused: f,
                      ),
                    ),
                  ],
                  if (guest) ...[
                    if (others.isNotEmpty)
                      const SizedBox(width: HinterTokens.s4),
                    NavFocusable(
                      region: modal.region,
                      rowKey: 'tiles',
                      col: others.length,
                      onSelect: () => modal.close(
                        const _Target(CurrentProfile.guestId, 'Guest'),
                      ),
                      builder: (_, f) => ProfileTile(
                        name: 'Guest',
                        initial: 'G',
                        guest: true,
                        focused: f,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
        _blocked = null;
      case SwitchBlocked():
        _blocked = e;
    }
  }

  @override
  void dispose() {
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
      setState(() => _blocked = null);
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
            ? 'Closing the apps...'
            : 'Closing ${_progress.appName}...',
      SwitchStage.closingSteam => 'Closing Steam (it saves to the cloud)...',
      SwitchStage.ending ||
      SwitchStage.cancelled => 'Opening the profile picker...',
    };
    return FullPage(
      title: widget.targetName == null
          ? 'Leaving ${widget.fromName}'
          : 'Switching to ${widget.targetName}',
      subtitle: 'Everything running in ${widget.fromName} closes first.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b == null)
            StatusLine(stage, busy: true)
          else ...[
            Text(
              "${b.appName} isn't responding (${b.waited.inSeconds} s).",
              style: t.title,
            ),
            const SizedBox(height: HinterTokens.s1),
            Text('Force-closing it may lose unsaved data.', style: t.body),
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

// ---------------------------------------------------------------- hold A

/// "Hold A for 3 seconds to remove Sam": A held down fills the bar; letting
/// go early starts over. Resolves true when held long enough.
Future<bool> showHoldToConfirm(
  BuildContext context, {
  required String title,
  required String body,
  Duration hold = const Duration(seconds: 3),
}) async =>
    await ModalScope.of(context).show<bool>(
      (context, modal) =>
          HoldToConfirmPage(modal: modal, title: title, body: body, hold: hold),
    ) ??
    false;

class HoldToConfirmPage extends StatefulWidget {
  const HoldToConfirmPage({
    super.key,
    required this.modal,
    required this.title,
    required this.body,
    this.hold = const Duration(seconds: 3),
  });

  final ModalHandle<bool> modal;
  final String title;
  final String body;
  final Duration hold;

  @override
  State<HoldToConfirmPage> createState() => _HoldToConfirmPageState();
}

class _HoldToConfirmPageState extends State<HoldToConfirmPage>
    with SingleTickerProviderStateMixin {
  late final _bar = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.modal.close(true);
    });

  @override
  void initState() {
    super.initState();
    widget.modal.region.onRaw = (action, phase) {
      if (action != NavAction.accept) return false;
      if (phase == NavPhase.press) {
        unawaited(_bar.forward(from: 0));
      } else if (phase == NavPhase.release) {
        _bar.stop();
        _bar.value = 0;
      }
      return true;
    };
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows([const NavRow('hold', 1)]);
    return FullPage(
      title: widget.title,
      subtitle: 'B goes back.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body, style: t.body),
          const SizedBox(height: HinterTokens.s4),
          NavFocusable(
            region: region,
            rowKey: 'hold',
            col: 0,
            scrollIntoView: false,
            builder: (_, f) => HButton(
              label: 'Hold A',
              focused: f,
              danger: true,
              primary: true,
            ),
          ),
          const SizedBox(height: HinterTokens.s3),
          SizedBox(
            width: 900,
            child: AnimatedBuilder(
              animation: _bar,
              builder: (context, _) => HBar(fraction: _bar.value),
            ),
          ),
        ],
      ),
    );
  }
}
