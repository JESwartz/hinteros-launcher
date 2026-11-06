import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'common.dart';

/// A [DecoratedBox] that stays a closed box when a vertical scroll view cuts
/// it: its decoration (fill and border) is drawn around the part that shows,
/// so the cut edge gets a border too, and its child is clipped to that part.
/// Under an [EdgeFade] the part that shows ends where the fade begins (the box
/// is never half faded). A decoration without a border paints as usual.
class VisibleDecoratedBox extends StatelessWidget {
  const VisibleDecoratedBox({
    super.key,
    required this.decoration,
    this.padding,
    this.fadeAware = true,
    this.child,
  });

  final BoxDecoration decoration;

  /// Inside the decoration, around [child] (as in a [Container]).
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  /// Ends at the start of an [EdgeFade] (false: at the viewport edge, under
  /// the fade; for a focus ring, which reaches past the first row into the
  /// fade).
  final bool fadeAware;

  @override
  Widget build(BuildContext context) {
    Widget? inner = child;
    if (padding != null) inner = Padding(padding: padding!, child: inner);
    final scrollable = decoration.border == null
        ? null
        : Scrollable.maybeOf(context, axis: Axis.vertical);
    if (scrollable == null) {
      return DecoratedBox(decoration: decoration, child: inner);
    }
    final fade = fadeAware ? EdgeFade.of(scrollable.context) : null;
    return _VisibleBox(
      decoration: decoration,
      viewport: scrollable.context,
      position: scrollable.position,
      hiddenTop: fade?.top ?? 0,
      hiddenBottom: fade?.bottom ?? 0,
      child: inner,
    );
  }
}

class _VisibleBox extends SingleChildRenderObjectWidget {
  const _VisibleBox({
    required this.decoration,
    required this.viewport,
    required this.position,
    required this.hiddenTop,
    required this.hiddenBottom,
    super.child,
  });

  final BoxDecoration decoration;
  final BuildContext viewport;
  final ScrollPosition position;
  final double hiddenTop;
  final double hiddenBottom;

  @override
  RenderVisibleBox createRenderObject(BuildContext context) =>
      RenderVisibleBox(decoration, viewport, position, hiddenTop, hiddenBottom);

  @override
  void updateRenderObject(BuildContext context, RenderVisibleBox r) => r
    ..decoration = decoration
    ..viewport = viewport
    ..position = position
    ..hiddenTop = hiddenTop
    ..hiddenBottom = hiddenBottom;
}

/// The render object of [VisibleDecoratedBox]; [visibleRect] is the part of
/// the box that shows (in its own coordinates).
class RenderVisibleBox extends RenderProxyBox {
  /// A cut box shows only when at least this much of it shows.
  static const double minShown = 24;

  RenderVisibleBox(
    this._decoration,
    this._viewport,
    this._position,
    this._hiddenTop,
    this._hiddenBottom,
  );

  BoxDecoration _decoration;
  set decoration(BoxDecoration v) {
    if (v == _decoration) return;
    _decoration = v;
    _painter?.dispose();
    _painter = null;
    markNeedsPaint();
  }

  BuildContext _viewport;
  set viewport(BuildContext v) {
    if (v == _viewport) return;
    _viewport = v;
    markNeedsPaint();
  }

  ScrollPosition _position;
  set position(ScrollPosition v) {
    if (v == _position) return;
    if (attached) _position.removeListener(markNeedsPaint);
    _position = v;
    if (attached) _position.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _hiddenTop;
  set hiddenTop(double v) {
    if (v == _hiddenTop) return;
    _hiddenTop = v;
    markNeedsPaint();
  }

  double _hiddenBottom;
  set hiddenBottom(double v) {
    if (v == _hiddenBottom) return;
    _hiddenBottom = v;
    markNeedsPaint();
  }

  BoxPainter? _painter;
  final _clip = LayerHandle<ClipRRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _position.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _position.removeListener(markNeedsPaint);
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  /// The part of this box inside the viewport, less the faded edges; the
  /// whole box when it is not cut.
  Rect get visibleRect {
    final whole = Offset.zero & size;
    final view = _viewport.mounted ? _viewport.findRenderObject() : null;
    if (view is! RenderBox || !view.attached || !view.hasSize) return whole;
    final toView = getTransformTo(view);
    final inView = MatrixUtils.transformRect(toView, whole);
    final top = math.max(inView.top, _hiddenTop);
    final bottom = math.min(inView.bottom, view.size.height - _hiddenBottom);
    if (top <= inView.top && bottom >= inView.bottom) return whole;
    if (bottom <= top) return Rect.zero;
    final shown = Rect.fromLTRB(inView.left, top, inView.right, bottom);
    final back = Matrix4.tryInvert(toView);
    if (back == null) return whole;
    // Exact along the scroll axis; the sides stay where they are.
    final r = MatrixUtils.transformRect(back, shown);
    return Rect.fromLTRB(0, r.top, size.width, r.bottom).intersect(whole);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final whole = Offset.zero & size;
    final shown = visibleRect;
    if (shown == whole) {
      _clip.layer = null;
      _paintDecoration(context, offset, whole, _decoration);
      super.paint(context, offset);
      return;
    }
    // A sliver too thin to read is left out (an empty strip looks broken).
    if (shown.height < minShown) {
      _clip.layer = null;
      return;
    }
    // Cut: fill, the child clipped to the shown part, then the border on top
    // (the child must not cover the new edge).
    _paintDecoration(
      context,
      offset,
      shown,
      _decoration.copyWith(border: null),
    );
    final radius =
        _decoration.borderRadius?.resolve(TextDirection.ltr) ??
        BorderRadius.zero;
    _clip.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      shown,
      radius.toRRect(shown),
      super.paint,
      oldLayer: _clip.layer,
    );
    _paintDecoration(
      context,
      offset,
      shown,
      BoxDecoration(
        border: _decoration.border,
        borderRadius: _decoration.borderRadius,
        shape: _decoration.shape,
      ),
      cache: false,
    );
  }

  void _paintDecoration(
    PaintingContext context,
    Offset offset,
    Rect rect,
    BoxDecoration d, {
    bool cache = true,
  }) {
    final config = ImageConfiguration(
      size: rect.size,
      textDirection: TextDirection.ltr,
    );
    if (cache && d == _decoration) {
      _painter ??= d.createBoxPainter(markNeedsPaint);
      _painter!.paint(context.canvas, offset + rect.topLeft, config);
      return;
    }
    final p = d.createBoxPainter();
    p.paint(context.canvas, offset + rect.topLeft, config);
    p.dispose();
  }
}
