import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import 'visible_box.dart';

/// Wraps a card with the focus indicator: scale-up (unless reducing motion)
/// and a [FocusStyle]-dependent marker drawn outside the card. The indicator
/// is a shape (thick ring, ring plus glow, or a bar), never only a colour, so
/// it survives colour blindness.
///
/// The scale-up never makes the item and its ring reach into its neighbours:
/// [scale] is an upper bound, and an item grows only as far as keeps its ring
/// [HinterTokens.focusClear] away from anything [gap] off its edges. Small
/// items get the full [scale]; wide ones (a Store card) grow less.
class FocusFrame extends StatelessWidget {
  const FocusFrame({
    super.key,
    required this.focused,
    required this.child,
    this.radius = HinterTokens.radiusCard,
    this.style,
    this.scale = HinterTokens.focusScale,
    this.gap = HinterTokens.focusSpacing,
  });

  final bool focused;
  final Widget child;
  final double radius;

  /// Overrides the style from the theme (settings preview).
  final FocusStyle? style;
  final double scale;

  /// The space between this item and its neighbours.
  final double gap;

  /// The scale an item of [size] grows to when focused: at most [scale], and
  /// at most what keeps the grown item plus its ring within [gap] less
  /// [HinterTokens.focusClear] of its edges. Never below 1.
  static double grownScale(Size size, double scale, double gap) {
    if (scale <= 1) return 1;
    final room = gap - HinterTokens.focusClear;
    // Scaled about the centre: an edge moves out d/2 * (s - 1) and the ring
    // reaches focusReach * s past it.
    double fit(double d) => (room + d / 2) / (HinterTokens.focusReach + d / 2);
    final s = math.min(scale, math.min(fit(size.width), fit(size.height)));
    return math.max(1, s);
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final style = this.style ?? t.focusStyle;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: focused && !t.reduceMotion ? 1 : 0),
      duration: t.fast,
      curve: Curves.easeOut,
      builder: (_, grow, child) =>
          _FocusGrow(grow: grow, scale: scale, gap: gap, child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (style == FocusStyle.glow)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: focused ? 1 : 0,
                  duration: t.fast,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        // Soft: it marks the card without reaching the
                        // cards next to it.
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: focused ? 1 : 0,
                duration: t.fast,
                child: _indicator(t, style),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator(HinterTokens t, FocusStyle style) {
    switch (style) {
      case FocusStyle.ring:
        // White ring, dark gap: reads on light and dark art alike.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -HinterTokens.focusReach,
              top: -HinterTokens.focusReach,
              right: -HinterTokens.focusReach,
              bottom: -HinterTokens.focusReach,
              child: VisibleDecoratedBox(
                fadeAware: false,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    radius + HinterTokens.focusReach,
                  ),
                  border: Border.all(color: t.focusRing, width: 6),
                ),
              ),
            ),
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: VisibleDecoratedBox(
                fadeAware: false,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 3),
                  border: Border.all(color: t.focusGap, width: 3),
                ),
              ),
            ),
          ],
        );
      case FocusStyle.glow:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: VisibleDecoratedBox(
                fadeAware: false,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 3),
                  border: Border.all(color: t.focusRing, width: 3),
                ),
              ),
            ),
          ],
        );
      case FocusStyle.bar:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              right: 8,
              bottom: -14,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.focusRing,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Scales its child about the centre by up to [scale], [grow] (0..1) of the
/// way, capped by [FocusFrame.grownScale] for the child's laid-out size.
class _FocusGrow extends SingleChildRenderObjectWidget {
  const _FocusGrow({
    required this.grow,
    required this.scale,
    required this.gap,
    super.child,
  });

  final double grow;
  final double scale;
  final double gap;

  @override
  _RenderFocusGrow createRenderObject(BuildContext context) =>
      _RenderFocusGrow(grow, scale, gap);

  @override
  void updateRenderObject(BuildContext context, _RenderFocusGrow r) => r
    ..grow = grow
    ..scale = scale
    ..gap = gap;
}

class _RenderFocusGrow extends RenderProxyBox {
  _RenderFocusGrow(this._grow, this._scale, this._gap);

  double _grow;
  set grow(double v) {
    if (v == _grow) return;
    _grow = v;
    markNeedsPaint();
  }

  double _scale;
  set scale(double v) {
    if (v == _scale) return;
    _scale = v;
    markNeedsPaint();
  }

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsPaint();
  }

  Matrix4? get _transform {
    if (_grow == 0 || !hasSize) return null;
    final s = 1 + _grow * (FocusFrame.grownScale(size, _scale, _gap) - 1);
    if (s == 1) return null;
    final c = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final m = _transform;
    if (m == null || child == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      m,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final m = _transform;
    if (m == null) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: m,
      position: position,
      hitTest: (r, p) => super.hitTestChildren(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final m = _transform;
    if (m != null) transform.multiply(m);
  }
}
