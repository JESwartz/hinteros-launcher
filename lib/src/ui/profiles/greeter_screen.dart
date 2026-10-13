/// The profile picker (`hinteros-launcher --greeter`): what the greeter
/// session shows at boot and between profiles. A row of profile tiles
/// (colour, initial, name, a lock on locked profiles, the admin badge), then
/// Guest and Add profile, and Power below. It talks only to the greeter-mode
/// session daemon ([GreeterRepository]).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../installer/gamepad.dart' show PadEvent;
import '../../installer/ui/host.dart';
import '../../nav/nav_model.dart';
import '../../settings/launcher_settings.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';
import 'picker_view.dart';
import 'profile_form.dart';
import 'profile_loading.dart';
import 'profile_ui.dart';

/// The picker as an app: the picker's appearance (the most accessible of the
/// profiles' own) once it is known.
class GreeterApp extends StatefulWidget {
  const GreeterApp({
    super.key,
    required this.greeter,
    required this.jobs,
    this.system,
    this.pad,
    this.hideCursor = true,
    this.now,
    this.onEntered,
  });

  final GreeterRepository greeter;
  final JobsRepository jobs;

  /// Power (sleep, restart, shut down); null: no Power row.
  final SystemRepository? system;

  /// Controller input (the greeter daemon's `input_nav`).
  final Stream<PadEvent>? pad;
  final bool hideCursor;
  final DateTime Function()? now;

  /// A profile's session starts (greetd accepted the login): the picker
  /// quits, so greetd starts it at once (it would SIGTERM the greeter after
  /// 5 s otherwise).
  final VoidCallback? onEntered;

  @override
  State<GreeterApp> createState() => _GreeterAppState();
}

class _GreeterAppState extends State<GreeterApp> {
  LauncherSettings _settings = const LauncherSettings();

  void _appearance(PickerAppearance a) {
    final s = LauncherSettings(
      textScale: a.textScale,
      highContrast: a.highContrast,
      reduceMotion: a.reduceMotion,
    );
    if (s.textScale == _settings.textScale &&
        s.highContrast == _settings.highContrast &&
        s.reduceMotion == _settings.reduceMotion) {
      return;
    }
    setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) => ConsoleApp(
    settings: _settings,
    hideCursor: widget.hideCursor,
    title: 'HinterOS',
    home: ConsoleHost(
      pad: widget.pad,
      builder: (context, console) => GreeterScreen(
        console: console,
        greeter: widget.greeter,
        jobs: widget.jobs,
        system: widget.system,
        onAppearance: _appearance,
        now: widget.now,
        onEntered: widget.onEntered,
      ),
    ),
  );
}

/// How often the picker reads greeter.list again while it is up.
const greeterRefreshEvery = Duration(seconds: 3);

/// How long after the picker starts a failed greeter.list keeps "Starting..."
/// (the greeter daemon starts with it) before the error shows, as the
/// launcher's own start does.
const greeterStartupGrace = Duration(seconds: 20);

class GreeterScreen extends StatefulWidget {
  const GreeterScreen({
    super.key,
    required this.console,
    required this.greeter,
    required this.jobs,
    this.system,
    this.onAppearance,
    this.now,
    this.onEntered,
  });

  final ConsoleController console;
  final GreeterRepository greeter;
  final JobsRepository jobs;
  final SystemRepository? system;
  final void Function(PickerAppearance)? onAppearance;
  final DateTime Function()? now;
  final VoidCallback? onEntered;

  @override
  State<GreeterScreen> createState() => _GreeterScreenState();
}

class _GreeterScreenState extends State<GreeterScreen> {
  PickerView? _view;
  Object? _error;

  /// Set once a profile's session is starting: the picker is done.
  LoadingIdentity? _entering;
  bool _focusedFirst = false;
  String? _message;

  /// greeter.list's `switch_to`, taken once: the picker goes straight to that
  /// profile (its PIN pad) instead of showing the tiles first.
  bool _switchTaken = false;
  bool _goingStraight = false;

  ConsoleController get _c => widget.console;
  DateTime _now() => (widget.now ?? DateTime.now)();

  /// The tiles follow the public view while the picker is up (a profile removed
  /// or added meanwhile, e.g. removing your own profile ends your session
  /// before the removal job is done): greeter.list again every few seconds.
  Timer? _refresh;

  /// When the picker started (see [greeterStartupGrace]).
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _c.onBack = () => true;
    _openedAt = _now();
    unawaited(_load());
    _refresh = Timer.periodic(greeterRefreshEvery, (_) => unawaited(_reload()));
  }

  static String _signature(PickerView v) => [
    for (final p in v.profiles)
      '${p.id}|${p.name}|${p.color}|${p.locked}|${p.admin}|${p.lockedUntil}',
    'guest:${v.guest}',
  ].join(';');

  Future<void> _reload() async {
    final old = _view;
    if (old == null || _entering != null || _goingStraight) return;
    try {
      final v = await widget.greeter.load();
      if (!mounted || _entering != null) return;
      if (_signature(v) != _signature(old)) setState(() => _view = v);
    } catch (_) {
      // The next tick tries again.
    }
  }

  Future<void> _load() async {
    try {
      final v = await widget.greeter.load();
      if (!mounted) return;
      final straight = _straightTo(v);
      setState(() {
        _view = v;
        _error = null;
        _goingStraight = straight != null;
      });
      widget.onAppearance?.call(v.appearance);
      if (straight != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_straight(straight));
        });
      }
    } catch (e) {
      if (!mounted) return;
      // At boot the picker starts as the greeter daemon does: its connection
      // is usually not up for the first request. Keep "Starting..." and ask
      // again soon; only a failure that outlasts the start shows.
      final starting = _now().difference(_openedAt) < greeterStartupGrace;
      if (!starting) setState(() => _error = e);
      _retry?.cancel();
      _retry = Timer(
        starting
            ? const Duration(milliseconds: 500)
            : const Duration(seconds: 3),
        () {
          if (mounted && _view == null) unawaited(_load());
        },
      );
    }
  }

  /// The pending switch's target tile, the first time the list has one.
  PickerTile? _straightTo(PickerView v) {
    if (_switchTaken) return null;
    final id = v.switchTo;
    if (id == null) return null;
    _switchTaken = true;
    if (id == CurrentProfile.guestId) {
      return v.guest ? const PickerTile.guest() : null;
    }
    final p = v.byId(id);
    return p == null ? null : _profileTile(p);
  }

  Future<void> _straight(PickerTile tile) async {
    await _choose(tile);
    if (mounted && _entering == null) setState(() => _goingStraight = false);
  }

  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  PickerTile _profileTile(PickerProfile p) {
    final until = p.lockedUntil;
    return PickerTile.profile(
      id: p.id,
      name: p.name,
      initial: p.initial,
      color: p.color,
      locked: p.locked,
      admin: p.admin,
      note: until != null && until.isAfter(_now())
          ? retryText(until.difference(_now()))
          : null,
    );
  }

  /// The tiles in order: the profiles, Guest, Add profile.
  List<PickerTile> _tiles(PickerView v) => pickerTiles(
    profiles: [for (final p in v.profiles) _profileTile(p)],
    guest: v.guest,
  );

  void _started(PickerTile tile) {
    setState(() {
      _entering = tile.kind == PickerTileKind.guest
          ? LoadingIdentity.guestIdentity
          : LoadingIdentity(name: tile.name, color: tile.color);
      _message = null;
    });
    widget.onEntered?.call();
  }

  Future<void> _choose(PickerTile e) async {
    switch (e.kind) {
      case PickerTileKind.add:
        await _add();
      case PickerTileKind.guest:
      case PickerTileKind.profile:
        await _enter(e);
    }
  }

  Future<void> _enter(PickerTile tile) async {
    final id = tile.id!;
    LoginOutcome r;
    try {
      r = await widget.greeter.login(id);
    } on SystemException catch (e) {
      setState(() => _message = e.message);
      return;
    }
    if (!mounted) return;
    if (r is LoginStarted) {
      _started(tile);
      return;
    }
    final profile = _view?.byId(id);
    if (r is LoginRefused) {
      // Still locked out from earlier tries.
      await _askPin(tile, profile, lockedUntil: r.retryAt);
      return;
    }
    await _askPin(tile, profile, lockedUntil: profile?.lockedUntil);
  }

  Future<void> _askPin(
    PickerTile tile,
    PickerProfile? profile, {
    DateTime? lockedUntil,
  }) async {
    final id = tile.id!;
    final name = tile.name;
    final pin = await showPinEntry(
      context,
      title: name,
      body: "Type $name's PIN.",
      now: widget.now,
      forgotPinFor: name,
      lockedUntil: lockedUntil != null && lockedUntil.isAfter(_now())
          ? lockedUntil
          : null,
      avatar: ProfileAvatar(
        initial: profile?.initial ?? tile.initial ?? '?',
        color: profile?.color ?? tile.color,
        locked: true,
        size: 200,
      ),
      check: (pin) async {
        try {
          final r = await widget.greeter.login(id, pin: pin);
          return switch (r) {
            LoginStarted() => const PinAccepted(),
            LoginRefused(:final retryAt) =>
              retryAt == null ? const PinWrong() : PinLocked(retryAt),
            LoginNeedsPin() => const PinWrong(),
          };
        } catch (e) {
          return PinAttempt.fromError(e);
        }
      },
    );
    if (!mounted) return;
    if (pin == null) {
      unawaited(widget.greeter.cancel().catchError((_) {}));
      if (_goingStraight) setState(() => _goingStraight = false);
      _c.refocus();
      return;
    }
    _started(tile);
  }

  Future<void> _add() async {
    final v = _view;
    final form = await showProfileForm(
      context,
      editText: ({required title, required initial, hint}) => _c.editText(
        title: title,
        initial: initial,
        hint: hint,
        maxLength: 32,
      ),
      taken: [for (final p in v?.profiles ?? const <PickerProfile>[]) p.name],
    );
    if (form == null || !mounted) {
      _c.refocus();
      return;
    }
    final ProfileJob job;
    try {
      job = await widget.greeter.create(
        name: form.name,
        color: form.color,
        pin: form.pin,
        locked: form.locked,
      );
    } on SystemException catch (e) {
      setState(
        () => _message = e.kind == SystemErrorKind.profileLimit
            ? 'This box has the maximum number of profiles.'
            : e.message,
      );
      return;
    }
    if (!mounted) return;
    final ok = await showProfileJob(
      context,
      jobs: widget.jobs,
      job: job.job,
      what: "Creating ${form.name}'s profile... (about a minute)",
    );
    if (!mounted) return;
    if (!ok) {
      await _load();
      return;
    }
    // A one-time token lets the creator straight in.
    await _enter(
      PickerTile.profile(
        id: job.id,
        name: form.name,
        initial: form.name.isEmpty
            ? '?'
            : String.fromCharCode(form.name.runes.first).toUpperCase(),
        color: form.color,
        locked: form.locked,
      ),
    );
  }

  Future<void> _power(PowerAction a) async {
    final s = widget.system;
    if (s == null) return;
    try {
      await s.power(a);
    } on SystemException catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final region = _c.content;
    final entering = _entering;
    if (entering != null) {
      region.setRows(const []);
      return ProfileLoadingPage(identity: entering);
    }
    final v = _view;
    if (v == null) {
      final err = _error;
      region.setRows([if (err != null) const NavRow('retry', 1)]);
      return FullPage(
        title: 'HinterOS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (err == null)
              const StatusLine('Starting...', busy: true)
            else ...[
              StatusLine(
                err is SystemException
                    ? err.message
                    : "Can't show the profiles right now.",
                error: true,
              ),
              const SizedBox(height: HinterTokens.s3),
              DialogButtonsRow(
                region: region,
                rowKey: 'retry',
                buttons: [
                  btn('Try again', () {
                    setState(() => _error = null);
                    unawaited(_load());
                  }, primary: true),
                ],
              ),
            ],
          ],
        ),
      );
    }
    if (_goingStraight) {
      // On the way to the switch target's PIN pad: never the bare tiles
      // (a still background: the pad opens over it at once).
      region.setRows(const []);
      return ColoredBox(
        color: HinterTheme.of(context).background,
        child: const SizedBox.expand(),
      );
    }
    final tiles = _tiles(v);
    if (!_focusedFirst) {
      _focusedFirst = true;
      final i = tiles.indexWhere((e) => e.id != null && e.id == v.focus);
      // Rows first (the view sets them), then the focus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        region.model.goTo(0, i < 0 ? 0 : i);
        _c.refocus();
      });
    }
    return ProfilePickerView(
      region: region,
      tiles: tiles,
      onSelect: (t) => unawaited(_choose(t)),
      title: v.firstBoot ? 'Welcome' : 'Who is watching?',
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
