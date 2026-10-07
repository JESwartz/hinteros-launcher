import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
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
  const OskApp({super.key, required this.backend, required this.settings});

  final OskBackend backend;

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
            child: OskScreen(backend: backend, showTyped: s.showTypedOnOsk),
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
/// above or below), `accept` types the key, `back` is Backspace (also while
/// held), `context` is Shift on the letters page and "More" on the symbol
/// pages, `secondary` is Space, L1/R1 (`page_left`/`page_right`) switch to
/// letters / symbols.
class OskScreen extends StatefulWidget {
  const OskScreen({
    super.key,
    required this.backend,
    this.showTyped = false,
    this.initialText = '',
  });

  final OskBackend backend;

  /// Text the field already holds (shown in the preview, taken off by
  /// Backspace). Empty for the daemon-backed keyboard.
  final String initialText;

  /// The "Show typed text on the on-screen keyboard" setting; off masks the
  /// preview strip.
  final bool showTyped;

  @override
  State<OskScreen> createState() => _OskScreenState();
}

class _OskScreenState extends State<OskScreen> {
  late final OskState _state = OskState(widget.backend)
    ..showTyped = widget.showTyped
    ..seed(widget.initialText);
  final _nav = NavController();
  final _region = NavRegion('osk', rememberPerRow: false, wrapHorizontal: true);
  StreamSubscription<InputNavEvent>? _sub;
  StreamSubscription<bool>? _visSub;

  @override
  void didUpdateWidget(OskScreen old) {
    super.didUpdateWidget(old);
    _state.showTyped = widget.showTyped;
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
  void _onAction(NavAction action, NavPhase phase) {
    if (phase == NavPhase.release || phase == NavPhase.unknown) return;
    switch (action) {
      case NavAction.back:
        _state.backspace(); // press and repeat
      case NavAction.context when phase == NavPhase.press:
        _state.context();
      case NavAction.secondary when phase == NavPhase.press:
        _state.space();
      case NavAction.pageLeft when phase == NavPhase.press:
        _state.setPage(OskPage.letters);
      case NavAction.pageRight when phase == NavPhase.press:
        _state.setPage(OskPage.symbols);
      default:
        _nav.dispatch(action, phase);
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
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.backspace) {
      return NavAction.back;
    }
    if (k == LogicalKeyboardKey.pageUp) return NavAction.pageLeft;
    if (k == LogicalKeyboardKey.pageDown) return NavAction.pageRight;
    if (k == LogicalKeyboardKey.keyY) return NavAction.context;
    if (k == LogicalKeyboardKey.keyX) return NavAction.secondary;
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final action = _actionForKey(e.logicalKey);
    if (action == null) return KeyEventResult.ignored;
    _onAction(action, switch (e) {
      KeyDownEvent() => NavPhase.press,
      KeyRepeatEvent() => NavPhase.repeat,
      _ => NavPhase.release,
    });
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
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
                child: _Keys(state: _state, region: _region),
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
    // Masked unless the setting is on (it may be a password). The tail only,
    // so the newest character is always visible.
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
                Text('Y Shift   X Space   B Delete', style: t.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Keys extends StatelessWidget {
  const _Keys({required this.state, required this.region});

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
  });

  final OskKey keyDef;
  final bool focused;
  final ShiftState shift;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final isShift = keyDef.kind == KeyKind.shift;
    final caps = isShift && shift == ShiftState.caps;
    final once = isShift && shift == ShiftState.once;
    final char = keyDef.kind == KeyKind.char;
    final fill = caps
        ? t.accent
        : focused
        ? t.surfaceHigh
        : t.surface;
    final fg = caps ? t.onAccent : (once ? t.accent : t.text);
    final style = (char ? t.title : t.label).copyWith(
      color: fg,
      fontWeight: char && !once ? FontWeight.w400 : FontWeight.w700,
    );
    final radius = BorderRadius.circular(HinterTokens.radiusSmall);
    return Semantics(
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
            color: t.accent.withValues(alpha: caps ? 0 : 0.28),
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
