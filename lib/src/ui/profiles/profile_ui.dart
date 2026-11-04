/// The pieces every profile screen shares: the profile colours, the avatar
/// (colour and initial, a lock glyph, the admin badge), the picker tile, the
/// PIN pad and its full-screen page with the wrong-PIN backoff.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart' show NavAction, NavPhase;
import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/profiles.dart';
import '../../theme/hinter_theme.dart';
import '../focus_frame.dart';
import '../hold.dart';
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';

/// The wording every PIN screen carries (profiles.md: no screen calls a PIN
/// secure).
const pinDisclaimer =
    'Your PIN stops others from using your profile by mistake. Someone with '
    'access to this box can get around it.';

/// The colour of a profile. Mid-tone colours that keep their hue on a dark
/// TV; the initial on top picks black or white for contrast.
Color profileColor(ProfileColor c) => switch (c) {
  ProfileColor.teal => const Color(0xFF2BB3A3),
  ProfileColor.blue => const Color(0xFF4C8DF6),
  ProfileColor.purple => const Color(0xFF9B6BF2),
  ProfileColor.pink => const Color(0xFFE86FB3),
  ProfileColor.red => const Color(0xFFE5534B),
  ProfileColor.orange => const Color(0xFFF08C3A),
  ProfileColor.yellow => const Color(0xFFE8C547),
  ProfileColor.green => const Color(0xFF5DBB63),
};

Color _onColor(Color c) =>
    c.computeLuminance() > 0.35 ? const Color(0xFF101418) : Colors.white;

/// A round avatar: the profile's colour with its initial, a padlock badge
/// when it is locked. The guest is a ring with a dashed look (no colour).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initial,
    this.color,
    this.size = 160,
    this.locked = false,
    this.guest = false,
  });

  final String initial;
  final ProfileColor? color;
  final double size;
  final bool locked;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final fill = color == null ? t.surfaceHigh : profileColor(color!);
    final fg = color == null ? t.text : _onColor(fill);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: guest || t.highContrast
                    ? Border.all(color: t.text, width: size * 0.03 + 1)
                    : null,
              ),
              child: Center(
                child: Text(
                  initial,
                  // The avatar's own size, not the text scale: it is a
                  // picture of the name.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    fontSize: size * 0.48,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          if (locked)
            Positioned(
              right: -size * 0.02,
              bottom: -size * 0.02,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(
                  color: t.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.text, width: 2),
                ),
                child: Center(child: LockMark(size: size * 0.2)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small "Admin" label (words, not only a colour or a glyph).
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: t.textDim, width: 2),
        borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
      ),
      child: Text('Admin', style: t.caption.copyWith(color: t.text)),
    );
  }
}

/// "Open": the profile whose session is running (the in-session picker).
class CurrentBadge extends StatelessWidget {
  const CurrentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Container(
      key: const ValueKey('current-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
      ),
      child: Text('Open', style: t.caption.copyWith(color: t.onAccent)),
    );
  }
}

/// A picker tile: a big avatar with the name under it (and a lock and the
/// admin badge where they apply). Also Guest and Add profile.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.name,
    required this.focused,
    this.initial,
    this.color,
    this.locked = false,
    this.admin = false,
    this.guest = false,
    this.add = false,
    this.note,
    this.current = false,
  });

  final String name;
  final bool focused;
  final String? initial;
  final ProfileColor? color;
  final bool locked;
  final bool admin;
  final bool guest;

  /// The Add profile tile: a plus instead of an initial.
  final bool add;

  /// A line under the name ("Try again in 30 s").
  final String? note;

  /// The profile whose session is open (the in-session picker): an "Open"
  /// badge; choosing it goes back to it.
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusCard,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(
          vertical: HinterTokens.s3,
          horizontal: HinterTokens.s2,
        ),
        decoration: BoxDecoration(
          color: focused ? t.surfaceHigh : t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
          border: t.highContrast
              ? Border.all(color: t.textDim, width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              initial: add ? '+' : (initial ?? '?'),
              color: add || guest ? null : color,
              locked: locked,
              guest: guest || add,
            ),
            const SizedBox(height: HinterTokens.s2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.label,
            ),
            if (admin) ...[
              const SizedBox(height: HinterTokens.s1),
              const AdminBadge(),
            ],
            if (current) ...[
              const SizedBox(height: HinterTokens.s1),
              const CurrentBadge(),
            ],
            if (note != null) ...[
              const SizedBox(height: HinterTokens.s1),
              Text(note!, textAlign: TextAlign.center, style: t.caption),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- PIN pad

/// The digits typed so far on a [PinPad].
class PinController extends ChangeNotifier {
  PinController({this.maxLength = 8});

  final int maxLength;
  String _pin = '';

  String get pin => _pin;
  bool get isEmpty => _pin.isEmpty;

  void add(String digit) {
    if (_pin.length >= maxLength) return;
    _pin += digit;
    notifyListeners();
  }

  /// Deletes the last digit; false when there was none.
  bool delete() {
    if (_pin.isEmpty) return false;
    _pin = _pin.substring(0, _pin.length - 1);
    notifyListeners();
    return true;
  }

  void clear() {
    if (_pin.isEmpty) return;
    _pin = '';
    notifyListeners();
  }
}

/// A 3x4 keypad for PINs in rows `pin0`..`pin3` of [region]: D-pad to move,
/// A to press, B deletes (B with nothing typed calls [onBackEmpty]), the
/// bottom row is Delete, 0 and OK. Digits show as dots. A physical keyboard
/// types digits; Enter is OK. No auto-submit (PINs have 4 to 8 digits).
///
/// [holdToSubmit] (removing a profile): the OK key ([submitLabel], "Delete")
/// must be held down that long, A or Enter. Pressing it turns it slightly red
/// at once and fills it with red from the left; letting go early empties it
/// and nothing happens; full, [onSubmit] runs ([HoldController], [HoldFill]).
/// The key that deletes a digit is then called "Erase".
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.region,
    required this.controller,
    required this.onSubmit,
    this.onBackEmpty,
    this.enabled = true,
    this.submitLabel = 'OK',
    this.holdToSubmit,
  });

  final NavRegion region;
  final PinController controller;
  final VoidCallback onSubmit;

  /// B with nothing typed. Null: B then does nothing.
  final VoidCallback? onBackEmpty;

  /// False while a backoff lock lasts: the keys are dimmed and do nothing.
  final bool enabled;
  final String submitLabel;
  final Duration? holdToSubmit;

  /// The rows the pad puts in its region.
  static const rows = [
    NavRow('pin0', 3),
    NavRow('pin1', 3),
    NavRow('pin2', 3),
    NavRow('pin3', 3),
  ];

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  /// The hold of the submit key ([PinPad.holdToSubmit]).
  HoldController? _hold;

  /// The region's Back before the pad took it: given back on dispose (a
  /// form step after the PIN).
  bool Function()? _outerBack;

  @override
  void initState() {
    super.initState();
    _outerBack = widget.region.onBack;
    widget.region.onBack = _back;
    final h = widget.holdToSubmit;
    if (h != null) {
      _hold = HoldController(
        vsync: this,
        duration: h,
        onDone: () => widget.onSubmit(),
      );
      widget.region.onRaw = _raw;
    }
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.region != widget.region) {
      if (old.region.onBack == _back) old.region.onBack = _outerBack;
      _outerBack = widget.region.onBack;
      widget.region.onBack = _back;
      if (_hold != null) widget.region.onRaw = _raw;
    }
  }

  @override
  void dispose() {
    if (widget.region.onBack == _back) widget.region.onBack = _outerBack;
    if (widget.region.onRaw == _raw) widget.region.onRaw = null;
    _hold?.dispose();
    super.dispose();
  }

  bool get _onSubmitKey =>
      widget.region.model.currentRow?.key == 'pin3' &&
      widget.region.model.col == 2;

  bool get _canSubmit => widget.enabled && validPin(widget.controller.pin);

  /// A (press, repeats, release) while the pad's region has focus: on the
  /// submit key it is the hold; anywhere else the usual press.
  bool _raw(NavAction a, NavPhase phase) {
    if (a != NavAction.accept) return false;
    switch (phase) {
      case NavPhase.press:
        if (!_onSubmitKey) return false;
        _startHold();
        return true;
      case NavPhase.release:
        _stopHold();
        return false;
      case NavPhase.repeat || NavPhase.unknown:
        return _onSubmitKey;
    }
  }

  void _startHold() {
    if (_canSubmit) _hold?.start();
  }

  void _stopHold() => _hold?.stop();

  /// Always consumed: with no [PinPad.onBackEmpty], B on the empty pad does
  /// nothing (a lock that cannot be left).
  bool _back() {
    if (widget.controller.delete()) return true;
    widget.onBackEmpty?.call();
    return true;
  }

  void _digit(String d) {
    if (widget.enabled) widget.controller.add(d);
  }

  void _submit() {
    // Held, not pressed (the hold runs it).
    if (_hold != null) return;
    if (_canSubmit) widget.onSubmit();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final enter =
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (enter && _hold != null) {
      if (e is KeyDownEvent) _startHold();
      if (e is KeyUpEvent) _stopHold();
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final c = e.character;
    if (c != null && c.length == 1 && '0123456789'.contains(c)) {
      _digit(c);
      return KeyEventResult.handled;
    }
    if (enter) {
      if (e is KeyDownEvent) _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hold = _hold;
    final labels = [
      const ['1', '2', '3'],
      const ['4', '5', '6'],
      const ['7', '8', '9'],
      [hold == null ? 'Delete' : 'Erase', '0', 'OK'],
    ];
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.controller, ?hold]),
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinDots(length: widget.controller.pin.length),
            const SizedBox(height: HinterTokens.s3),
            for (var r = 0; r < 4; r++) ...[
              if (r > 0) const SizedBox(height: HinterTokens.s2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < 3; c++) ...[
                    if (c > 0) const SizedBox(width: HinterTokens.s2),
                    NavFocusable(
                      region: widget.region,
                      rowKey: 'pin$r',
                      col: c,
                      scrollIntoView: false,
                      onSelect: switch (labels[r][c]) {
                        'Delete' || 'Erase' => () => widget.controller.delete(),
                        'OK' => _submit,
                        final d => () => _digit(d),
                      },
                      builder: (_, f) => _Key(
                        label: labels[r][c] == 'OK'
                            ? widget.submitLabel
                            : labels[r][c],
                        focused: f,
                        enabled:
                            widget.enabled &&
                            (labels[r][c] != 'OK' ||
                                validPin(widget.controller.pin)) &&
                            (r < 3 || c != 0 || !widget.controller.isEmpty),
                        wide: labels[r][c].length > 1,
                        hold: labels[r][c] == 'OK' ? hold?.fill : null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.focused,
    required this.enabled,
    required this.wide,
    this.hold,
  });

  final String label;
  final bool focused;
  final bool enabled;
  final bool wide;

  /// Held down (0 to 1 of the time needed): a light red key filling with
  /// red from the left. Null: not held.
  final double? hold;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final base = focused ? t.surfaceHigh : t.surface;
    final h = hold;
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1.06,
      child: HoldFill(
        fill: h,
        width: 150,
        height: 104,
        base: base,
        border: enabled ? t.textDim : t.textDim.withValues(alpha: 0.4),
        radius: HinterTokens.radiusSmall,
        child: Center(
          child: Text(
            label,
            style: (wide ? t.label : t.title).copyWith(
              color: h != null
                  ? t.text
                  : (enabled ? t.text : t.textDim.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The typed PIN as dots (at least four places, so an empty pad shows what
/// is expected).
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final places = length < 4 ? 4 : length;
    return Semantics(
      label: '$length digits typed',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < places; i++) ...[
            if (i > 0) const SizedBox(width: HinterTokens.s2),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < length ? t.text : null,
                border: Border.all(color: t.text, width: 3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- PIN page

/// How a PIN that was tried came out.
sealed class PinAttempt {
  const PinAttempt();

  /// From what a call that took a PIN threw: a wrong PIN, the backoff lock or
  /// the admin PIN's lock until a restart, else the message of another
  /// failure.
  static PinAttempt fromError(Object e) {
    final r = PinRefusal.of(e);
    if (r != null) {
      if (r.rebootRequired) return const PinRebootRequired();
      return r.retryAt == null ? const PinWrong() : PinLocked(r.retryAt!);
    }
    return PinFailed(
      e is SystemException ? e.message : 'Something went wrong ($e).',
    );
  }
}

/// It worked; the page closes.
final class PinAccepted extends PinAttempt {
  const PinAccepted();
}

/// "Wrong PIN."
final class PinWrong extends PinAttempt {
  const PinWrong();
}

/// "Too many tries. Try again in 30 seconds", counting down.
final class PinLocked extends PinAttempt {
  const PinLocked(this.until);
  final DateTime until;
}

/// The admin profile's PIN is refused until the box restarts ([rebootPinText]);
/// the pad takes no more digits.
final class PinRebootRequired extends PinAttempt {
  const PinRebootRequired();
}

/// What the pad says while the admin PIN is refused until a restart.
const rebootPinText = 'Too many wrong PINs. Restart the box to try again.';

/// Something else went wrong (shown as is; the pad stays).
final class PinFailed extends PinAttempt {
  const PinFailed(this.message);
  final String message;
}

/// "Try again in 30 seconds" / "in 2 minutes".
String retryText(Duration left) {
  final s = left.inMilliseconds <= 0 ? 0 : (left.inMilliseconds / 1000).ceil();
  if (s <= 90) return 'Try again in $s ${s == 1 ? 'second' : 'seconds'}.';
  final m = (s / 60).ceil();
  return 'Try again in $m minutes.';
}

/// Asks for a PIN on a full page with the pad: [check] gets each PIN that
/// is submitted and says how it went. Resolves with the accepted PIN, or
/// null when Back left the empty pad. [lockedUntil]: the profile is in its
/// backoff lock already.
Future<String?> showPinEntry(
  BuildContext context, {
  required String title,
  String? body,
  ProfileAvatar? avatar,
  required Future<PinAttempt> Function(String pin) check,
  DateTime? lockedUntil,
  String submitLabel = 'OK',
  bool disclaimer = false,
  DateTime Function()? now,
  List<({String label, VoidCallback onSelect})> extraActions = const [],
  bool canLeave = true,
  String? forgotPinFor,
  Duration? holdToSubmit,
}) => ModalScope.of(context).show<String>(
  (context, modal) => PinEntryPage(
    holdToSubmit: holdToSubmit,
    forgotPinFor: forgotPinFor,
    modal: modal,
    title: title,
    body: body,
    avatar: avatar,
    check: check,
    lockedUntil: lockedUntil,
    submitLabel: submitLabel,
    disclaimer: disclaimer,
    now: now,
    extraActions: extraActions,
    canLeave: canLeave,
  ),
);

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({
    super.key,
    required this.modal,
    required this.title,
    required this.check,
    this.body,
    this.avatar,
    this.lockedUntil,
    this.submitLabel = 'OK',
    this.disclaimer = false,
    this.now,
    this.canLeave = true,
    this.extraActions = const [],
    this.forgotPinFor,
    this.holdToSubmit,
  });

  final ModalHandle<String> modal;
  final String title;
  final String? body;
  final ProfileAvatar? avatar;
  final Future<PinAttempt> Function(String pin) check;
  final DateTime? lockedUntil;
  final String submitLabel;
  final bool disclaimer;
  final DateTime Function()? now;

  /// False: Back on the empty pad does nothing (the sleep lock).
  final bool canLeave;

  /// Buttons under the pad ("Switch profile" on the lock screen).
  final List<({String label, VoidCallback onSelect})> extraActions;

  /// Asking for an existing PIN: whose ([forgotPinAdmin] for the admin
  /// profile's). Shows how a forgotten one is removed. Null: a new PIN is
  /// being chosen (no hint).
  /// The submit key ([submitLabel]) is held this long instead of pressed
  /// (removing a profile).
  final Duration? holdToSubmit;

  final String? forgotPinFor;

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final _pin = PinController();
  bool _busy = false;
  String? _error;
  DateTime? _lockedUntil;
  Timer? _tick;
  bool _reboot = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () => false;
    final l = widget.lockedUntil;
    if (l != null && l.isAfter(_now())) _lock(l);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pin.dispose();
    super.dispose();
  }

  bool get _locked => _lockedUntil != null;

  void _lock(DateTime until) {
    _lockedUntil = until;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_now().isBefore(_lockedUntil!)) {
        _tick?.cancel();
        setState(() {
          _lockedUntil = null;
          _error = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || _locked || _reboot) return;
    final pin = _pin.pin;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.check(pin);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PinAccepted():
        widget.modal.close(pin);
      case PinWrong():
        _pin.clear();
        setState(() => _error = 'Wrong PIN.');
      case PinLocked(:final until):
        _pin.clear();
        setState(() {
          _error = null;
          _lock(until);
        });
      case PinRebootRequired():
        _pin.clear();
        setState(() {
          _error = null;
          _reboot = true;
        });
      case PinFailed(:final message):
        _pin.clear();
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows([
      ...PinPad.rows,
      if (widget.extraActions.isNotEmpty)
        NavRow('extra', widget.extraActions.length),
    ]);
    final until = _lockedUntil;
    return FullPage(
      title: widget.title,
      subtitle: widget.body,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.avatar != null) ...[
                  widget.avatar!,
                  const SizedBox(height: HinterTokens.s3),
                ],
                if (_reboot)
                  const StatusLine(rebootPinText, error: true)
                else if (until != null)
                  StatusLine(
                    'Too many tries. ${retryText(until.difference(_now()))}',
                    error: true,
                  )
                else if (_error != null)
                  StatusLine(_error!, error: true)
                else if (_busy)
                  const StatusLine('Checking...', busy: true),
                const SizedBox(height: HinterTokens.s3),
                Text(
                  '${switch (widget.holdToSubmit) {
                    null => '',
                    final h => 'Hold A on ${widget.submitLabel} for '
                        '${h.inSeconds} seconds. ',
                  }}B deletes a digit'
                  '${widget.canLeave ? ' or goes back' : ''}.',
                  style: t.caption,
                ),
                if (widget.disclaimer) ...[
                  const SizedBox(height: HinterTokens.s2),
                  Text(pinDisclaimer, style: t.caption),
                ],
                if (widget.forgotPinFor case final who?) ...[
                  const SizedBox(height: HinterTokens.s3),
                  ForgotPinHint(who: who),
                ],
              ],
            ),
          ),
          const SizedBox(width: HinterTokens.s5),
          Column(
            children: [
              PinPad(
                region: region,
                controller: _pin,
                enabled: !_busy && until == null && !_reboot,
                submitLabel: widget.submitLabel,
                holdToSubmit: widget.holdToSubmit,
                onSubmit: () => unawaited(_submit()),
                onBackEmpty: widget.canLeave ? widget.modal.close : null,
              ),
              if (widget.extraActions.isNotEmpty) ...[
                const SizedBox(height: HinterTokens.s3),
                DialogButtonsRow(
                  region: region,
                  rowKey: 'extra',
                  buttons: [
                    for (final a in widget.extraActions)
                      btn(a.label, a.onSelect),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A row of buttons in a region row (like the dialogs' button row).
class DialogButtonsRow extends StatelessWidget {
  const DialogButtonsRow({
    super.key,
    required this.region,
    required this.rowKey,
    required this.buttons,
  });

  final NavRegion region;
  final String rowKey;
  final List<
    ({
      String label,
      VoidCallback? onSelect,
      bool primary,
      bool enabled,
      bool danger,
    })
  >
  buttons;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: HinterTokens.s2,
    runSpacing: HinterTokens.s1,
    children: [
      for (var i = 0; i < buttons.length; i++)
        NavFocusable(
          region: region,
          rowKey: rowKey,
          col: i,
          scrollIntoView: false,
          onSelect: buttons[i].enabled ? buttons[i].onSelect : null,
          builder: (_, f) => HButton(
            label: buttons[i].label,
            focused: f,
            primary: buttons[i].primary,
            enabled: buttons[i].enabled,
            danger: buttons[i].danger,
          ),
        ),
    ],
  );
}

/// Asks for the admin profile's PIN for an action on another profile or the
/// box, and runs [action] with it; a wrong PIN stays on the pad. Resolves
/// with whether the action ran.
Future<bool> withAdminPin(
  BuildContext context, {
  required String title,
  String? body,
  required Future<void> Function(String pin) action,
}) async {
  final pin = await showPinEntry(
    context,
    title: title,
    body: body ?? "Type the admin profile's PIN.",
    forgotPinFor: forgotPinAdmin,
    check: (pin) async {
      try {
        await action(pin);
        return const PinAccepted();
      } catch (e) {
        return PinAttempt.fromError(e);
      }
    },
  );
  return pin != null;
}

/// A box-wide action (update, rollback, channel, base, hardware; API 0.13)
/// with the admin profile's PIN, on the same pad as [withAdminPin]. The pad
/// comes first when the admin profile has a PIN; without one (or when
/// `profiles.list` fails) or without an admin profile (first boot: the call says why) the action runs with no
/// PIN, and a `pin_required {pin: admin}` answer then still opens the pad.
/// A wrong PIN stays on the pad; anything else the action throws closes it
/// and is thrown from here. Resolves with the action's result, or null when
/// Back left the pad (nothing ran).
Future<T?> withBoxAdminPin<T extends Object>(
  BuildContext context,
  ProfilesRepository profiles, {
  required String title,
  required Future<T> Function(String? pin) action,
}) async {
  ProfileInfo? admin;
  var known = false;
  try {
    admin = (await profiles.list()).admin;
    known = true;
  } on SystemException {
    // No connection: try without a PIN.
  }
  if (!known || admin == null || !admin.pinSet) {
    try {
      return await action(null);
    } on SystemException catch (e) {
      final r = PinRefusal.of(e);
      // No admin profile (first boot): no PIN can help.
      if (r == null || r.kind != PinKind.admin || (known && admin == null)) {
        rethrow;
      }
    }
  }
  if (!context.mounted) return null;
  T? result;
  Object? failure;
  StackTrace? trace;
  final pin = await showPinEntry(
    context,
    title: title,
    body: "Type the admin profile's PIN.",
    forgotPinFor: forgotPinAdmin,
    check: (pin) async {
      try {
        result = await action(pin);
      } catch (e, st) {
        if (PinRefusal.of(e) != null) return PinAttempt.fromError(e);
        failure = e;
        trace = st;
      }
      return const PinAccepted();
    },
  );
  if (pin == null) return null;
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result;
}

// ---------------------------------------------------------------- forgotten PIN

/// [PinEntryPage.forgotPinFor] when the admin profile's PIN is asked and its
/// name is not at hand.
const forgotPinAdmin = '';

/// "Forgot your PIN?": only the person who set up the box can remove a PIN,
/// from a terminal as root (`sudo hinteros-system reset-pin <name>`, owner
/// decision); the profile then chooses a new one at its next start. The
/// command is in the documentation, not on screen (the UI is not the docs).
class ForgotPinHint extends StatelessWidget {
  const ForgotPinHint({super.key, required this.who});

  /// The profile's name, or [forgotPinAdmin].
  final String who;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Column(
      key: const ValueKey('forgot-pin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forgot your PIN?', style: t.caption.copyWith(color: t.text)),
        Text('Ask the person who set up this box.', style: t.caption),
      ],
    );
  }
}
