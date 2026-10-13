import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart' show NavAction, NavPhase;
import '../nav/nav_controller.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'nav_focusable.dart';

// Hold to confirm: an action that cannot be undone runs only after A (or
// Enter) is held down on its button for [HoldController.duration]. Pressing
// turns the button slightly red at once and fills it with red from the left;
// letting go early empties it and nothing happens. Used by the PIN pad
// (removing a profile, 3 s) and the installer (erasing the disk, 5 s).

/// The timing of one hold: [start] on press, [stop] on release; [onDone]
/// runs once the hold has lasted [duration]. Listen to it to redraw the fill.
class HoldController extends ChangeNotifier {
  HoldController({
    required TickerProvider vsync,
    required this.duration,
    required this.onDone,
  }) {
    _anim = AnimationController(vsync: vsync, duration: duration)
      ..addListener(notifyListeners)
      ..addStatusListener((s) {
        if (s != AnimationStatus.completed || !_holding) return;
        _holding = false;
        notifyListeners();
        onDone();
        _anim.value = 0;
      });
  }

  final Duration duration;
  final VoidCallback onDone;
  late final AnimationController _anim;
  bool _holding = false;

  /// Held down right now.
  bool get holding => _holding;

  /// How full the button is (0 to 1) while held; null when not held.
  double? get fill => _holding ? _anim.value : null;

  void start() {
    if (_holding) return;
    _holding = true;
    notifyListeners();
    unawaited(_anim.forward(from: 0));
  }

  /// Let go: the fill empties and nothing happens.
  void stop() {
    if (!_holding) return;
    _anim.stop();
    _anim.value = 0;
    _holding = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}

/// The look of a hold: [base] with a [border] at rest; held ([fill] not
/// null), light red filling with red from the left, a red border.
class HoldFill extends StatelessWidget {
  const HoldFill({
    super.key,
    required this.fill,
    required this.base,
    required this.border,
    required this.radius,
    required this.child,
    this.width,
    this.height,
  });

  final double? fill;
  final Color base;
  final Color border;
  final double radius;
  final double? width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final h = fill;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: h == null ? base : Color.lerp(base, t.danger, 0.35),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: h != null ? t.danger : border, width: 2),
      ),
      child: Stack(
        children: [
          if (h != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: h.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: ColoredBox(color: t.danger),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// A button at `rowKey:col` of [region] that runs [onDone] only when A (or
/// Enter) is held on it for [duration]. A short press does nothing. It
/// takes the region's [NavRegion.onRaw] while it is shown.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.region,
    required this.rowKey,
    required this.col,
    required this.label,
    required this.duration,
    required this.onDone,
    this.enabled = true,
  });

  final NavRegion region;
  final String rowKey;
  final int col;
  final String label;
  final Duration duration;
  final VoidCallback onDone;
  final bool enabled;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final _hold = HoldController(
    vsync: this,
    duration: widget.duration,
    onDone: () => widget.onDone(),
  );

  @override
  void initState() {
    super.initState();
    widget.region.onRaw = _raw;
  }

  @override
  void didUpdateWidget(HoldButton old) {
    super.didUpdateWidget(old);
    if (old.region != widget.region) {
      if (old.region.onRaw == _raw) old.region.onRaw = null;
      widget.region.onRaw = _raw;
    }
    if (!widget.enabled) _hold.stop();
  }

  @override
  void dispose() {
    if (widget.region.onRaw == _raw) widget.region.onRaw = null;
    _hold.dispose();
    super.dispose();
  }

  bool get _onButton =>
      widget.region.model.currentRow?.key == widget.rowKey &&
      widget.region.model.col == widget.col;

  /// A on this button is the hold (press starts, release stops); anything
  /// else lets go and goes on as usual.
  bool _raw(NavAction a, NavPhase phase) {
    if (a != NavAction.accept) {
      if (phase == NavPhase.press) _hold.stop();
      return false;
    }
    switch (phase) {
      case NavPhase.press:
        if (!_onButton) return false;
        if (widget.enabled) _hold.start();
        return true;
      case NavPhase.release:
        _hold.stop();
        return false;
      case NavPhase.repeat || NavPhase.unknown:
        return _onButton;
    }
  }

  /// Enter from a keyboard that reaches the focused button directly.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final enter =
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter) return KeyEventResult.ignored;
    if (e is KeyDownEvent && widget.enabled) _hold.start();
    if (e is KeyUpEvent) _hold.stop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: NavFocusable(
        region: widget.region,
        rowKey: widget.rowKey,
        col: widget.col,
        builder: (_, focused) => ListenableBuilder(
          listenable: _hold,
          builder: (context, _) {
            final h = _hold.fill;
            final on = widget.enabled;
            return FocusFrame(
              focused: focused,
              radius: HinterTokens.radiusPill,
              scale: 1.05,
              child: HoldFill(
                fill: h,
                base: t.surface,
                border: on ? t.danger : t.textDim.withValues(alpha: 0.5),
                radius: HinterTokens.radiusPill,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HinterTokens.s4,
                    vertical: HinterTokens.s1 + 4,
                  ),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: t.label.copyWith(
                      color: h != null
                          ? t.text
                          : (on ? t.danger : t.textDim.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
