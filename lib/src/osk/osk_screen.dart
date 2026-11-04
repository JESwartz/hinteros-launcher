import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../nav/soft_key.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import '../ui/nav_focusable.dart';
import 'osk_backend.dart';
import 'osk_layout.dart';
import 'osk_state.dart';

/// The layout is designed for a 1080 logical pixel tall screen, like the
/// launcher; [OskApp] scales it by the real height.
const oskDesignHeight = 1080.0;

/// The panel takes this share of the screen height, docked at the bottom.
const oskPanelShare = 0.4;

/// The on-screen keyboard app: a transparent screen with the keyboard panel
/// docked at the bottom. Fully transparent outside the panel (the native
/// window has an ARGB visual, see linux/runner).
class OskApp extends StatelessWidget {
  const OskApp({
    super.key,
    required this.backend,
    required this.settings,
    this.echoKeys,
  });

  final OskBackend backend;

  /// Physical key presses to echo on the keys (see [OskScreen.echoKeys]).
  final Stream<SoftKey>? echoKeys;

  /// Local launcher settings (text size, high contrast, focus marker).
  final ValueListenable<LauncherSettings> settings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LauncherSettings>(
      valueListenable: settings,
      builder: (context, s, _) {
        final tokens = HinterTokens.fromSettings(s);
        return MaterialApp(
          title: 'HinterOS keyboard',
          debugShowCheckedModeBanner: false,
          theme: HinterTheme.material(tokens)
              .copyWith(scaffoldBackgroundColor: Colors.transparent),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(s.textScale),
              disableAnimations: s.reduceMotion,
            ),
            child: HinterTheme(
              tokens: tokens,
              child: _DesignScale(child: child!),
            ),
          ),
          home: Material(
            type: MaterialType.transparency,
            child: OskScreen(
              backend: backend,
              showTyped: s.showTypedOnOsk,
              echoKeys: echoKeys,
            ),
          ),
        );
      },
    );
  }
}

/// Lays the content out as if the screen were [oskDesignHeight] tall, whatever
/// its real size (a 4K screen at devicePixelRatio 1 under gamescope gets the
/// same keyboard, scaled up), without painting anything itself.
class _DesignScale extends StatelessWidget {
  const _DesignScale({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = size.height / oskDesignHeight;
    if (scale == 1) return child;
    final design = Size(size.width / scale, oskDesignHeight);
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: design.width,
      maxWidth: design.width,
      minHeight: design.height,
      maxHeight: design.height,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: design,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: design),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Keyboard, preview strip and the input layer: `input_nav` and the dev keys
/// become [NavAction]s here, once.
///
/// Controls: D-pad moves between keys (left/right wrap, up/down go to the key
/// above or below), `accept` types the key, `back` (B) closes the
/// keyboard, `secondary` (X) is Backspace (also while held), `context` (Y) is
/// Shift on the letters page and "More" on the symbol pages, Space is a key on
/// the grid, L1/R1 (`page_left`/`page_right`) switch to
/// letters / symbols.
class OskScreen extends StatefulWidget {
  const OskScreen({
    super.key,
    required this.backend,
    this.showTyped = false,
    this.password = false,
    this.initialText = '',
    this.hardwareKeys = false,
    this.onEscape,
    this.softKeys,
    this.echoKeys,
  });

  final OskBackend backend;

  /// Text the field already holds (shown in the preview, taken off by
  /// Backspace). Empty for the daemon-backed keyboard.
  final String initialText;

  /// The "Show typed passwords" setting: on, a password field's preview is
  /// not masked either.
  final bool showTyped;

  /// The field is a password (masked preview). The daemon-backed keyboard
  /// learns it from `osk_changed` instead ([OskBackend.passwordField]).
  final bool password;

  /// A physical keyboard types into the field (the installer, where the
  /// keyboard is in this process): printable keys are text, Backspace
  /// deletes, Enter submits, and Escape calls [onEscape] (cancel). Off: the
  /// keys only move the focus, like the D-pad.
  final bool hardwareKeys;
  final VoidCallback? onEscape;

  /// Where keys from the evdev fallback arrive (see [SoftKeySink]).
  final SoftKeySink? softKeys;

  /// Keys pressed on a physical keyboard, for feedback only: the matching
  /// key lights up briefly and the focus follows it. Nothing is typed from
  /// here. (The daemon-backed keyboard reads them from evdev; the in-app
  /// one sees its keys already.)
  final Stream<SoftKey>? echoKeys;

  @override
  State<OskScreen> createState() => _OskScreenState();
}

class _OskScreenState extends State<OskScreen> {
  late final OskState _state = OskState(widget.backend)
    ..showTyped = widget.showTyped
    ..password = widget.password
    ..seed(widget.initialText);
  final _nav = NavController();
  final _region = NavRegion('osk', rememberPerRow: false, wrapHorizontal: true);
  StreamSubscription<InputNavEvent>? _sub;
  StreamSubscription<bool>? _visSub;
  StreamSubscription<SoftKey>? _echoSub;

  /// Keys drawn as pressed (`row:col` of the current page), for a moment.
  Set<String> _pressed = const {};
  Timer? _pressTimer;

  /// How long a physical key press shows on the keyboard.
  static const pressFor = Duration(milliseconds: 150);

  @override
  void didUpdateWidget(OskScreen old) {
    super.didUpdateWidget(old);
    _state.showTyped = widget.showTyped;
    if (widget.password != old.password) _state.password = widget.password;
  }

  @override
  void initState() {
    super.initState();
    _nav.adopt(_region);
    _sub = widget.backend.nav.listen((e) => _onAction(e.action, e.phase));
    // A fresh start for every opening: focus back on the first letter.
    _visSub = widget.backend.visibility.listen((visible) {
      if (visible) _focusStart();
    });
    widget.softKeys?.handler = _softKey;
    _echoSub = widget.echoKeys?.listen(_echoSoft);
    _state.addListener(_onState);
    _syncRows();
    _focusStart();
  }

  void _syncRows() {
    _region.setRows([
      for (final r in _state.rows) NavRow(r.id, r.keys.length, spans: r.spans),
    ]);
  }

  void _onState() {
    if (!mounted) return;
    _syncRows();
    setState(() {});
  }

  void _focusStart() {
    _region.model.goTo(1, 0); // q
    _nav.focusRegion(_region);
  }

  /// The one action layer: `input_nav` and the dev keys both end up here.
  /// Actions currently held (pressed and not yet released). A repeat that
  /// arrives after the release (late events from the daemon) is dropped, so
  /// nothing plays on after the stick is back at rest.
  final _held = <NavAction>{};

  void _onAction(NavAction action, NavPhase phase) {
    if (phase == NavPhase.release) {
      _held.remove(action);
      return;
    }
    if (phase == NavPhase.unknown) return;
    if (phase == NavPhase.press) {
      _held.add(action);
    } else if (!_held.contains(action)) {
      return;
    }
    switch (action) {
      case NavAction.back when phase == NavPhase.press:
        _close();
      case NavAction.back:
        break;
      case NavAction.secondary:
        _state.backspace(); // X: press and repeat
      case NavAction.context when phase == NavPhase.press:
        _state.context();
      case NavAction.pageLeft when phase == NavPhase.press:
        _state.setPage(OskPage.letters);
      case NavAction.pageRight when phase == NavPhase.press:
        _state.setPage(OskPage.symbols);
      default:
        _nav.dispatch(action, phase);
    }
  }

  /// B: close the keyboard. The system keyboard asks the daemon to hide it;
  /// the installer's in-app one cancels the edit, like View.
  void _close() {
    if (widget.hardwareKeys) {
      widget.onEscape?.call();
    } else {
      unawaited(widget.backend.hide());
    }
  }

  static NavAction? _actionForKey(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowLeft) return NavAction.left;
    if (k == LogicalKeyboardKey.arrowRight) return NavAction.right;
    if (k == LogicalKeyboardKey.arrowUp) return NavAction.up;
    if (k == LogicalKeyboardKey.arrowDown) return NavAction.down;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      return NavAction.accept;
    }
    if (k == LogicalKeyboardKey.escape) return NavAction.back; // B: close
    if (k == LogicalKeyboardKey.backspace) return NavAction.secondary; // X
    if (k == LogicalKeyboardKey.pageUp) return NavAction.pageLeft;
    if (k == LogicalKeyboardKey.pageDown) return NavAction.pageRight;
    if (k == LogicalKeyboardKey.keyY) return NavAction.context;
    if (k == LogicalKeyboardKey.keyX) return NavAction.secondary;
    return null;
  }

  KeyEventResult _hardwareKey(KeyEvent e) {
    final hw = HardwareKeyboard.instance;
    if (e is! KeyUpEvent) {
      _echo(e.logicalKey, e.character, hw.isShiftPressed);
    }
    return _typedKey(
      e.logicalKey,
      e.character,
      isDown: e is KeyDownEvent,
      isRepeat: e is KeyRepeatEvent,
      modifier: hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed,
    );
  }

  /// A key from the evdev fallback (the window has no keyboard focus):
  /// the same handling as a hardware key. True if it was used.
  bool _softKey(SoftKey k) {
    if (!widget.hardwareKeys) return false;
    if (k.phase != NavPhase.release) _echo(k.key, k.character, k.shift);
    final r = _typedKey(
      k.key,
      k.character,
      isDown: k.phase == NavPhase.press,
      isRepeat: k.phase == NavPhase.repeat,
      modifier: false,
    );
    if (r != KeyEventResult.ignored) return true;
    final action = _actionForKey(k.key);
    if (action == null) return false;
    _onAction(action, k.phase);
    return true;
  }

  KeyEventResult _typedKey(
    LogicalKeyboardKey k,
    String? c, {
    required bool isDown,
    required bool isRepeat,
    required bool modifier,
  }) {
    final down = isDown || isRepeat;
    if (k == LogicalKeyboardKey.backspace) {
      if (down) _state.backspace();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (isDown) _state.press(const OskKey(KeyKind.done, 'Done'));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (isDown) widget.onEscape?.call();
      return KeyEventResult.handled;
    }
    if (c != null &&
        c.isNotEmpty &&
        c.runes.first >= 0x20 &&
        c.runes.first != 0x7f &&
        !modifier) {
      if (down) _state.typeText(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (widget.hardwareKeys) {
      final r = _hardwareKey(e);
      if (r != KeyEventResult.ignored) return r;
    }
    final action = _actionForKey(e.logicalKey);
    if (action == null) return KeyEventResult.ignored;
    _onAction(action, switch (e) {
      KeyDownEvent() => NavPhase.press,
      KeyRepeatEvent() => NavPhase.repeat,
      _ => NavPhase.release,
    });
    return KeyEventResult.handled;
  }

  void _echoSoft(SoftKey k) {
    if (k.phase == NavPhase.release) return;
    _echo(k.key, k.character, k.shift);
  }

  /// Shows a physical key on the keyboard: switches to the page that has it,
  /// moves the focus to it and presses it for [pressFor]. Visual only: it
  /// never types (the key itself reaches the field some other way).
  void _echo(LogicalKeyboardKey key, String? char, bool shift) {
    final KeyKind? kind = key == LogicalKeyboardKey.space
        ? KeyKind.space
        : key == LogicalKeyboardKey.backspace
        ? KeyKind.backspace
        : (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter)
        ? KeyKind.enter
        : key == LogicalKeyboardKey.tab
        ? KeyKind.tab
        : null;
    final printable =
        kind == null &&
        char != null &&
        char.isNotEmpty &&
        char.runes.first > 0x20 &&
        char.runes.first != 0x7f;
    if (kind == null && !printable) return;
    final pos = oskLocate(
      char: kind == null ? char : null,
      kind: kind,
      page: _state.page,
      shift: _state.shift,
    );
    if (pos == null) return;
    _state.setPage(pos.page); // (rows are in sync right after this)
    final rows = _state.rows;
    final pressed = {'${rows[pos.row].id}:${pos.col}'};
    // A capital: Shift is part of the press.
    final upper =
        kind == null &&
        char != char!.toLowerCase() &&
        _state.shift == ShiftState.off;
    if (upper && pos.page == OskPage.letters) pressed.add('r3:0');
    _region.model.goTo(pos.row, pos.col);
    _nav.focusRegion(_region);
    _pressTimer?.cancel();
    setState(() => _pressed = pressed);
    _pressTimer = Timer(pressFor, () {
      if (mounted) setState(() => _pressed = const {});
    });
  }

  @override
  void dispose() {
    if (widget.softKeys?.handler == _softKey) widget.softKeys?.handler = null;
    _echoSub?.cancel();
    _pressTimer?.cancel();
    _sub?.cancel();
    _visSub?.cancel();
    _state.removeListener(_onState);
    _state.dispose();
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final height = MediaQuery.sizeOf(context).height * oskPanelShare;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const ValueKey('osk-panel'),
          height: height,
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(HinterTokens.s4),
            ),
            border: Border(
              top: BorderSide(
                color: t.highContrast ? t.textDim : t.surfaceHigh,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            HinterTokens.margin,
            HinterTokens.s2,
            HinterTokens.margin,
            HinterTokens.s3,
          ),
          child: Column(
            children: [
              _PreviewStrip(state: _state),
              const SizedBox(height: HinterTokens.s1),
              Expanded(
                child: _Keys(state: _state, region: _region, pressed: _pressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What was typed since opening, and an error if keys do not arrive.
class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({required this.state});

  final OskState state;

  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final error = state.error;
    final notice = state.notice;
    // Masked for a password (unless the setting is on). The tail only, so the
    // newest character is always visible.
    final typed = state.preview;
    final shown = typed.length > 60
        ? '…${typed.substring(typed.length - 60)}'
        : typed;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HinterTokens.s2),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: (error ?? notice) != null
                      ? Text(
                          (error ?? notice)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: error != null ? t.danger : t.text,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            shown.isEmpty ? 'Typed text appears here' : shown,
                            key: const ValueKey('osk-preview'),
                            maxLines: 1,
                            style: shown.isEmpty ? t.caption : t.body,
                          ),
                        ),
                ),
              ),
              if (scale <= 1.3) ...[
                const SizedBox(width: HinterTokens.s2),
                Text('A Type   B Close   X Delete   Y Shift', style: t.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Keys extends StatelessWidget {
  const _Keys({
    required this.state,
    required this.region,
    this.pressed = const {},
  });

  final Set<String> pressed;
  final OskState state;
  final NavRegion region;

  static const gap = 12.0;
  static const rowCount = 5;

  @override
  Widget build(BuildContext context) {
    final rows = state.rows;
    return LayoutBuilder(
      builder: (context, c) {
        final rowH = (c.maxHeight - gap * (rowCount - 1)) / rowCount;
        Widget row(OskRow r) => SizedBox(
          height: rowH,
          child: Row(
            children: [
              for (var i = 0; i < r.keys.length; i++)
                Expanded(
                  flex: r.keys[i].span,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                    child: NavFocusable(
                      region: region,
                      rowKey: r.id,
                      col: i,
                      scrollIntoView: false,
                      onSelect: () => state.press(r.keys[i]),
                      builder: (_, focused) => _KeyCap(
                        key: ValueKey('${r.id}:$i'),
                        keyDef: r.keys[i],
                        focused: focused,
                        shift: state.shift,
                        pressed: pressed.contains('${r.id}:$i'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i == rows.length - 1 && rows.length < rowCount)
                const Spacer(),
              if (i > 0 && !(i == rows.length - 1 && rows.length < rowCount))
                const SizedBox(height: gap),
              row(rows[i]),
            ],
          ],
        );
      },
    );
  }
}

/// One key. The focus marker is drawn inside the key (keys are packed too
/// tightly for a ring outside them) and differs in shape per [FocusStyle].
class _KeyCap extends StatelessWidget {
  const _KeyCap({
    super.key,
    required this.keyDef,
    required this.focused,
    required this.shift,
    this.pressed = false,
  });

  final OskKey keyDef;
  final bool focused;

  /// A physical key is down on this one: pressed in, accent colours.
  final bool pressed;
  final ShiftState shift;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final isShift = keyDef.kind == KeyKind.shift;
    final caps = isShift && shift == ShiftState.caps;
    final once = isShift && shift == ShiftState.once;
    final char = keyDef.kind == KeyKind.char;
    final fill = (caps || pressed)
        ? t.accent
        : focused
        ? t.surfaceHigh
        : t.surface;
    final fg = (caps || pressed) ? t.onAccent : (once ? t.accent : t.text);
    final style = (char ? t.title : t.label).copyWith(
      color: fg,
      fontWeight: char && !once ? FontWeight.w400 : FontWeight.w700,
    );
    final radius = BorderRadius.circular(HinterTokens.radiusSmall);
    // Pressed shrinks the key a little (never grows: nothing is drawn outside
    // the key's bounds, over the transparent ARGB window).
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedScale(
      scale: pressed ? 0.94 : 1,
      duration: still ? Duration.zero : const Duration(milliseconds: 60),
      child: Semantics(
        label: keyDef.label,
        button: true,
        focused: focused,
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: radius,
                  // One-shot shift: an outline, caps lock: filled (and "Caps").
                  border: once
                      ? Border.all(color: t.accent, width: 3)
                      : (t.highContrast && !focused
                            ? Border.all(color: t.textDim, width: 2)
                            : null),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(keyDef.label, maxLines: 1, style: style),
                    ),
                  ),
                ),
              ),
              if (focused)
                IgnorePointer(child: _marker(t, radius, t.focusStyle, caps)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marker(
    HinterTokens t,
    BorderRadius radius,
    FocusStyle style,
    bool caps,
  ) {
    switch (style) {
      case FocusStyle.ring:
        // Thick ring, then a dark gap, inside the key.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: t.focusRing, width: 6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  HinterTokens.radiusSmall - 6,
                ),
                border: Border.all(color: t.focusGap, width: 3),
              ),
            ),
          ),
        );
      case FocusStyle.glow:
        // Thin ring and an accent wash.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            // Opaque: the window is ARGB, so no translucent blends here.
            color: caps
                ? t.accent
                : Color.alphaBlend(
                    t.accent.withValues(alpha: 0.28),
                    t.surfaceHigh,
                  ),
            border: Border.all(color: t.focusRing, width: 3),
          ),
        );
      case FocusStyle.bar:
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 12, right: 12),
            child: SizedBox(
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.focusRing,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
    }
  }
}
