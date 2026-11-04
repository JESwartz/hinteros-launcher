import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../theme/hinter_theme.dart';

/// A focusable item of a [NavRegion] at ([rowKey], [col]). It owns nothing:
/// the focus node comes from the region, the accept action is registered with
/// it, and gaining focus scrolls the item into view. Visuals come from
/// [builder].
class NavFocusable extends StatefulWidget {
  const NavFocusable({
    super.key,
    required this.region,
    required this.rowKey,
    required this.col,
    required this.builder,
    this.onSelect,
    this.onContext,
    this.onFocused,
    this.scrollIntoView = true,
  });

  final NavRegion region;
  final String rowKey;
  final int col;
  final Widget Function(BuildContext context, bool focused) builder;

  /// What accept does.
  final VoidCallback? onSelect;

  /// What Back (B/Circle) does on this item instead of going back: closing
  /// a running app or game. Null: Back goes back as usual.
  final VoidCallback? onContext;

  /// Called when this item gains focus.
  final VoidCallback? onFocused;
  final bool scrollIntoView;

  @override
  State<NavFocusable> createState() => _NavFocusableState();
}

class _NavFocusableState extends State<NavFocusable> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    // The node belongs to the region, not to this widget: when one page
    // replaces another, the item at the same row and column takes over a
    // node that already has focus, and no focus change follows.
    _focused = widget.region.nodeAt(widget.rowKey, widget.col).hasFocus;
    widget.region.registerSelect(widget.rowKey, widget.col, widget.onSelect);
    widget.region.registerContext(widget.rowKey, widget.col, widget.onContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.region.itemBuilt(widget.rowKey, widget.col);
    });
  }

  @override
  void didUpdateWidget(NavFocusable old) {
    super.didUpdateWidget(old);
    if (old.region != widget.region ||
        old.rowKey != widget.rowKey ||
        old.col != widget.col) {
      old.region.unregisterSelect(old.rowKey, old.col);
      old.region.releaseContext(old.rowKey, old.col, old.onContext);
      _focused = widget.region.nodeAt(widget.rowKey, widget.col).hasFocus;
    }
    widget.region.registerSelect(widget.rowKey, widget.col, widget.onSelect);
    widget.region.registerContext(widget.rowKey, widget.col, widget.onContext);
  }

  @override
  void dispose() {
    widget.region.releaseSelect(widget.rowKey, widget.col, widget.onSelect);
    widget.region.releaseContext(widget.rowKey, widget.col, widget.onContext);
    super.dispose();
  }

  void _onFocusChange(bool focused) {
    if (_focused != focused) setState(() => _focused = focused);
    if (!focused) return;
    widget.region.noteFocused(widget.rowKey, widget.col);
    widget.onFocused?.call();
    if (widget.scrollIntoView) {
      final t = HinterTheme.of(context);
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: t.medium,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.region.nodeAt(widget.rowKey, widget.col),
      onFocusChange: _onFocusChange,
      child: widget.builder(context, _focused),
    );
  }
}
