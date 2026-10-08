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
import '../nav_focusable.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';
import 'profile_form.dart';
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
  });

  final GreeterRepository greeter;
  final JobsRepository jobs;

  /// Power (sleep, restart, shut down); null: no Power row.
  final SystemRepository? system;

  /// Controller input (the greeter daemon's `input_nav`).
  final Stream<PadEvent>? pad;
  final bool hideCursor;
  final DateTime Function()? now;

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
      ),
    ),
  );
}

class GreeterScreen extends StatefulWidget {
  const GreeterScreen({
    super.key,
    required this.console,
    required this.greeter,
    required this.jobs,
    this.system,
    this.onAppearance,
    this.now,
  });

  final ConsoleController console;
  final GreeterRepository greeter;
  final JobsRepository jobs;
  final SystemRepository? system;
  final void Function(PickerAppearance)? onAppearance;
  final DateTime Function()? now;

  @override
  State<GreeterScreen> createState() => _GreeterScreenState();
}

class _GreeterScreenState extends State<GreeterScreen> {
  PickerView? _view;
  Object? _error;

  /// Set once a profile's session is starting: the picker is done.
  String? _entering;
  bool _focusedFirst = false;
  String? _message;

  ConsoleController get _c => widget.console;
  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _c.onBack = () => true;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final v = await widget.greeter.load();
      if (!mounted) return;
      setState(() {
        _view = v;
        _error = null;
      });
      widget.onAppearance?.call(v.appearance);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      // The daemon may still be starting: try again by itself.
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 3), () {
        if (mounted && _view == null) unawaited(_load());
      });
    }
  }

  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  /// The tiles in order: the profiles, Guest, Add profile.
  List<_Entry> _entries(PickerView v) => [
    for (final p in v.profiles) _Entry.profile(p),
    if (v.guest) const _Entry.guest(),
    if (v.profiles.length < 8) const _Entry.add(),
  ];

  void _started(String id, String name) {
    setState(() {
      _entering = name;
      _message = null;
    });
  }

  Future<void> _choose(_Entry e) async {
    switch (e.kind) {
      case _Kind.add:
        await _add();
      case _Kind.guest:
        await _enter(CurrentProfile.guestId, 'Guest');
      case _Kind.profile:
        await _enter(e.profile!.id, e.profile!.name, profile: e.profile);
    }
  }

  Future<void> _enter(String id, String name, {PickerProfile? profile}) async {
    LoginOutcome r;
    try {
      r = await widget.greeter.login(id);
    } on SystemException catch (e) {
      setState(() => _message = e.message);
      return;
    }
    if (!mounted) return;
    if (r is LoginStarted) {
      _started(id, name);
      return;
    }
    if (r is LoginRefused) {
      // Still locked out from earlier tries.
      await _askPin(id, name, profile, lockedUntil: r.retryAt);
      return;
    }
    await _askPin(id, name, profile, lockedUntil: profile?.lockedUntil);
  }

  Future<void> _askPin(
    String id,
    String name,
    PickerProfile? profile, {
    DateTime? lockedUntil,
  }) async {
    final pin = await showPinEntry(
      context,
      title: name,
      body: "Type $name's PIN.",
      now: widget.now,
      lockedUntil: lockedUntil != null && lockedUntil.isAfter(_now())
          ? lockedUntil
          : null,
      avatar: ProfileAvatar(
        initial: profile?.initial ?? '?',
        color: profile?.color,
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
      _c.refocus();
      return;
    }
    _started(id, name);
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
            ? 'This box has as many profiles as it can have.'
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
    await _enter(job.id, form.name);
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
    final t = HinterTheme.of(context);
    final region = _c.content;
    final entering = _entering;
    if (entering != null) {
      region.setRows(const []);
      return FullPage(
        title: entering == 'Guest' ? 'Guest' : 'Hello, $entering',
        child: const Align(
          alignment: Alignment.topLeft,
          child: StatusLine('Opening...', busy: true),
        ),
      );
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
                    : "The profiles can't be shown right now.",
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
    final entries = _entries(v);
    final power = [
      if (widget.system != null) ...[
        PowerAction.sleep,
        PowerAction.restart,
        PowerAction.shutdown,
      ],
    ];
    region.setRows([
      NavRow('tiles', entries.length),
      if (power.isNotEmpty) NavRow('power', power.length),
    ]);
    if (!_focusedFirst) {
      _focusedFirst = true;
      final i = entries.indexWhere(
        (e) =>
            e.profile?.id == v.focus ||
            (e.kind == _Kind.guest && v.focus == CurrentProfile.guestId),
      );
      region.model.goTo(0, i < 0 ? 0 : i);
      WidgetsBinding.instance.addPostFrameCallback((_) => _c.refocus());
    }
    return FullPage(
      title: v.firstBoot ? 'Welcome' : 'Who is watching?',
      subtitle: v.firstBoot
          ? 'This box is getting ready for its first profile.'
          : 'Choose your profile. Move with the D-pad, A chooses.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: HinterTokens.s4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: HinterTokens.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: HinterTokens.s4),
                  NavFocusable(
                    region: region,
                    rowKey: 'tiles',
                    col: i,
                    onSelect: () => unawaited(_choose(entries[i])),
                    builder: (_, f) => _tile(entries[i], f),
                  ),
                ],
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: HinterTokens.s2),
            StatusLine(_message!, error: true),
          ],
          const Spacer(),
          if (power.isNotEmpty)
            Row(
              children: [
                Text('Power', style: t.bodyDim),
                const SizedBox(width: HinterTokens.s3),
                DialogButtonsRow(
                  region: region,
                  rowKey: 'power',
                  buttons: [
                    for (final a in power)
                      btn(a.label, () => unawaited(_power(a))),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tile(_Entry e, bool focused) {
    switch (e.kind) {
      case _Kind.guest:
        return ProfileTile(
          name: 'Guest',
          initial: 'G',
          guest: true,
          focused: focused,
          note: 'Cleared at restart',
        );
      case _Kind.add:
        return ProfileTile(name: 'Add profile', add: true, focused: focused);
      case _Kind.profile:
        final p = e.profile!;
        final until = p.lockedUntil;
        return ProfileTile(
          name: p.name,
          initial: p.initial,
          color: p.color,
          locked: p.locked,
          admin: p.admin,
          focused: focused,
          note: until != null && until.isAfter(_now())
              ? retryText(until.difference(_now()))
              : null,
        );
    }
  }
}

enum _Kind { profile, guest, add }

class _Entry {
  const _Entry.profile(PickerProfile this.profile) : kind = _Kind.profile;
  const _Entry.guest() : kind = _Kind.guest, profile = null;
  const _Entry.add() : kind = _Kind.add, profile = null;

  final _Kind kind;
  final PickerProfile? profile;
}
