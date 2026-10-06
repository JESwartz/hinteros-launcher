import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'nav_focusable.dart';

/// A vertically scrolling grid of fixed-size cells bound to a [NavRegion]
/// (one region row per grid row). Rows are built lazily; the column count is
/// derived from the available width, so it also works in a small window.
/// Column is sticky across short rows (see [NavGridModel]).
class NavGridView extends StatefulWidget {
  const NavGridView({
    super.key,
    required this.region,
    required this.itemCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.itemBuilder,
    this.onSelect,
    this.gap = HinterTokens.s4,
  });

  final NavRegion region;
  final int itemCount;
  final double cellWidth;

  /// Includes everything below the art (titles).
  final double cellHeight;
  final double gap;
  final Widget Function(BuildContext context, int index, bool focused)
  itemBuilder;
  final void Function(int index)? onSelect;

  @override
  State<NavGridView> createState() => _NavGridViewState();
}

class _NavGridViewState extends State<NavGridView> {
  final _scroll = ScrollController();

  // Room for the focus ring and scale-up above and below each row.
  static const _vPad = HinterTokens.s3;

  double get _rowExtent => widget.cellHeight + 2 * _vPad;

  /// Scrolls by whole rows, the least needed to show [row] completely.
  void _showRow(int row, {required bool animate}) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final top = row * _rowExtent;
    final bottom = top + _rowExtent;
    double? target;
    if (top < pos.pixels) {
      target = top;
    } else if (bottom > pos.pixels + pos.viewportDimension) {
      target = bottom - pos.viewportDimension;
    }
    if (target == null) return;
    target = target.clamp(0.0, pos.maxScrollExtent);
    final t = HinterTheme.of(context);
    if (animate && t.medium > Duration.zero) {
      _scroll.animateTo(target, duration: t.medium, curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _reveal(int row, int col) async => _showRow(row, animate: false);

  void _onRegion() => _showRow(widget.region.model.row, animate: true);

  @override
  void initState() {
    super.initState();
    widget.region.onRevealHook = _reveal;
    widget.region.addListener(_onRegion);
  }

  @override
  void dispose() {
    widget.region.removeListener(_onRegion);
    if (widget.region.onRevealHook == _reveal) {
      widget.region.onRevealHook = null;
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const margin = HinterTokens.margin;
        final avail = c.maxWidth - 2 * margin;
        final cols = math.max(
          1,
          ((avail + widget.gap) / (widget.cellWidth + widget.gap)).floor(),
        );
        final rows = (widget.itemCount / cols).ceil();
        widget.region.setRows([
          for (var r = 0; r < rows; r++)
            NavRow(
              'r$r',
              r < rows - 1 ? cols : widget.itemCount - (rows - 1) * cols,
            ),
        ]);
        return ListView.builder(
          controller: _scroll,
          itemExtent: _rowExtent,
          itemCount: rows,
          padding: const EdgeInsets.only(bottom: HinterTokens.s4),
          itemBuilder: (context, r) {
            final n = math.min(cols, widget.itemCount - r * cols);
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: margin,
                vertical: _vPad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var k = 0; k < n; k++) ...[
                    if (k > 0) SizedBox(width: widget.gap),
                    NavFocusable(
                      region: widget.region,
                      scrollIntoView: false,
                      rowKey: 'r$r',
                      col: k,
                      onSelect: widget.onSelect == null
                          ? null
                          : () => widget.onSelect!(r * cols + k),
                      builder: (ctx, f) =>
                          widget.itemBuilder(ctx, r * cols + k, f),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
