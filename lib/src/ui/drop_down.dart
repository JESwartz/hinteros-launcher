/// A drop-down for the controller (the time zone picker, Settings > Display,
/// the first-boot display step): a field that shows the current choice with
/// a down arrow. A on the field opens the list of choices under (or over)
/// it, at the current one: up and down move, A chooses, B closes. A list in
/// groups has a header per group; left and right (or L1 and R1) go to the
/// previous or next group. A field under something the list must not cover
/// (the time zone map) opens its list only under it ([DropDown.below]).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../api/api.dart' show NavAction;
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'widgets.dart' show Spinner;

/// One choice of the list: [build] makes its content (after the mark of the
/// current choice).
class DropDownChoice<T> {
  const DropDownChoice({
    required this.value,
    required this.build,
    this.current = false,
  });

  final T value;
  final WidgetBuilder build;

  /// The choice in use: marked, and the list opens at it.
  final bool current;
}

/// Choices under a [header]; null: no header line.
class DropDownGroup<T> {
  const DropDownGroup(this.header, this.choices);

  final String? header;
  final List<DropDownChoice<T>> choices;
}

/// The field (one item, at [rowKey]:0 of [region]) and its list. Put it in a
/// pane with `Pane.row(rowKey, 1, DropDown(...))`.
class DropDown<T> extends StatefulWidget {
  const DropDown({
    super.key,
    required this.region,
    required this.rowKey,
    required this.field,
    required this.groups,
    required this.onChoose,
    this.busy = false,
    this.listKey = const ValueKey('drop-down-list'),
    this.onHighlight,
    this.below = false,
    this.keepInView,
  });

  final NavRegion region;
  final String rowKey;

  /// The closed field's content: the current choice.
  final Widget field;

  /// The list's choices, made when the list opens.
  final List<DropDownGroup<T>> Function() groups;

  /// A choice was made in the list. The current choice again is ignored, so
  /// this only sees a change.
  final void Function(T value) onChoose;

  /// A change is being applied: a spinner instead of the arrow, A does
  /// nothing.
  final bool busy;

  /// The key of the open list.
  final Key listKey;

  /// The focused choice while the list is open (also the first one, where
  /// it opens); null when it closes (after [onChoose] if a choice was made).
  final void Function(T? value)? onHighlight;

  /// The list opens only under the field, shorter if needed; over it only
  /// when there is no room for two lines under it.
  final bool below;

  /// What holds the field and must stay in view with it (the time zone
  /// picker: the map over the field). On focus it is scrolled into the
  /// middle instead of the field; before the list opens, up to the top, so
  /// the list has room under the field.
  final GlobalKey? keepInView;

  @override
  State<DropDown<T>> createState() => _DropDownState<T>();
}

class _DropDownState<T> extends State<DropDown<T>> {
  final _link = LayerLink();
  final _field = GlobalKey();
  bool _open = false;

  /// The open list. It follows the field, so it closes when the field
  /// goes (a pane rebuilt without it): else an invisible modal holds focus.
  ModalHandle<DropDownChoice<T>>? _list;

  @override
  void dispose() {
    final l = _list;
    // After the frame: the modal stack does not change while the tree is
    // being torn down.
    if (l != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => l.close());
    }
    super.dispose();
  }

  /// Room left over [DropDown.keepInView] when it is scrolled to the top:
  /// past the fade at the top of a pane.
  static const _topRoom = HinterTokens.s4;

  void _revealMiddle() {
    final c = widget.keepInView?.currentContext;
    if (c == null) return;
    unawaited(
      Scrollable.ensureVisible(
        c,
        alignment: 0.5,
        duration: HinterTheme.of(context).medium,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Scrolls [DropDown.keepInView] up to the top of its scroll view (as far
  /// as it goes), and waits for the frame that lays it out there.
  Future<void> _revealTop() async {
    final c = widget.keepInView?.currentContext;
    final box = c?.findRenderObject();
    if (c == null || box == null) return;
    final position = Scrollable.maybeOf(c)?.position;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (position == null || viewport == null) return;
    final to = (viewport.getOffsetToReveal(box, 0).offset - _topRoom).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((to - position.pixels).abs() < 1) return;
    position.jumpTo(to);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _openList() async {
    if (_open || widget.busy) return;
    final groups = widget.groups();
    if (groups.every((g) => g.choices.isEmpty)) return;
    _open = true;
    try {
      await _revealTop();
      if (!mounted) return;
      await _showList(groups);
    } finally {
      _open = false;
    }
  }

  Future<void> _showList(List<DropDownGroup<T>> groups) async {
    final box = _field.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final anchor = topLeft & box.size;
    final keep =
        widget.keepInView?.currentContext?.findRenderObject() as RenderBox?;
    final clear = keep == null || !keep.hasSize
        ? null
        : keep.localToGlobal(Offset.zero) & keep.size;
    final screen = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final onHighlight = widget.onHighlight;
    final opened = ModalScope.of(context).open<DropDownChoice<T>>(
      (c, modal) => DropDownList<T>(
        key: widget.listKey,
        modal: modal,
        groups: groups,
        link: _link,
        anchor: anchor,
        screen: screen,
        textScale: textScale,
        below: widget.below,
        clear: clear,
        onHighlight: onHighlight == null ? null : (c) => onHighlight(c.value),
      ),
    );
    _list = opened.handle;
    final chosen = await opened.result;
    if (identical(_list, opened.handle)) _list = null;
    if (mounted && chosen != null && !chosen.current) {
      widget.onChoose(chosen.value);
    }
    if (mounted) onHighlight?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: NavFocusable(
        region: widget.region,
        rowKey: widget.rowKey,
        col: 0,
        onSelect: () => unawaited(_openList()),
        scrollIntoView: widget.keepInView == null,
        onFocused: widget.keepInView == null ? null : _revealMiddle,
        builder: (_, f) => KeyedSubtree(
          key: _field,
          child: DropDownField(
            focused: f,
            busy: widget.busy,
            child: widget.field,
          ),
        ),
      ),
    );
  }
}

/// The closed drop-down: [child] and a down arrow (it opens a list).
class DropDownField extends StatelessWidget {
  const DropDownField({
    super.key,
    required this.child,
    required this.focused,
    this.busy = false,
  });

  final Widget child;
  final bool focused;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          border: Border.all(color: t.textDim, width: t.highContrast ? 3 : 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2,
          ),
          child: Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: HinterTokens.s2),
              SizedBox(
                width: 36,
                height: 36,
                child: busy
                    ? const Center(child: Spinner(size: 28))
                    : CustomPaint(painter: _ArrowPainter(t.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The drop-down's arrow: a chevron that points down.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width * 0.18, s.height * 0.36)
      ..lineTo(s.width * 0.5, s.height * 0.68)
      ..lineTo(s.width * 0.82, s.height * 0.36);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter o) => o.color != color;
}

// ------------------------------------------------------------------ the list

/// One line of the open list: a group's header or a choice.
typedef _Line<T> = ({String? header, DropDownChoice<T>? choice, int index});

/// The open drop-down: every choice, under (or over) the field at [anchor]
/// (global), following it through [link]. Resolves with the chosen choice;
/// null on B.
class DropDownList<T> extends StatefulWidget {
  const DropDownList({
    super.key,
    required this.modal,
    required this.groups,
    required this.link,
    required this.anchor,
    required this.screen,
    this.textScale = 1,
    this.below = false,
    this.clear,
    this.onHighlight,
  });

  final ModalHandle<DropDownChoice<T>> modal;
  final List<DropDownGroup<T>> groups;
  final LayerLink link;
  final Rect anchor;
  final Size screen;

  /// The text size setting: the lines grow with it.
  final double textScale;

  /// See [DropDown.below].
  final bool below;

  /// Not shaded (global): what [DropDown.keepInView] keeps in view.
  final Rect? clear;

  /// The focused choice, at each move.
  final void Function(DropDownChoice<T> choice)? onHighlight;

  /// Line heights at 100% text.
  static const rowHeight = 64.0;
  static const headerHeight = 56.0;

  @override
  State<DropDownList<T>> createState() => _DropDownListState<T>();
}

class _DropDownListState<T> extends State<DropDownList<T>> {
  late final List<_Line<T>> _lines;

  /// Where each choice's line starts (the nav rows: `c0`, `c1`, ...), and
  /// the first choice of each group.
  late final List<double> _choiceTop;
  late final List<int> _groupStarts;
  late final double _height;
  late final bool _below;
  late final ScrollController _scroll;
  late final double _total;

  /// Room above the first and under the last row; rows that scroll past
  /// the edges fade out over the same height.
  static const _pad = HinterTokens.s2;

  NavRegion get _region => widget.modal.region;

  double get _scale => math.max(1.0, widget.textScale);
  double get _rowH => DropDownList.rowHeight * _scale;
  double get _headH => DropDownList.headerHeight * _scale;

  @override
  void initState() {
    super.initState();
    final lines = <_Line<T>>[];
    final tops = <double>[];
    final starts = <int>[];
    var cur = 0;
    var y = _pad;
    for (final g in widget.groups) {
      if (g.choices.isEmpty) continue;
      if (g.header != null) {
        lines.add((header: g.header, choice: null, index: -1));
        y += _headH;
      }
      starts.add(tops.length);
      for (final c in g.choices) {
        if (c.current) cur = tops.length;
        lines.add((header: null, choice: c, index: tops.length));
        tops.add(y);
        y += _rowH;
      }
    }
    _lines = lines;
    _choiceTop = tops;
    _groupStarts = starts;
    final total = y + _pad;

    // Under the field when there is room for a good part of the list,
    // else over it. Only under it ([DropDownList.below]) while two lines
    // fit there.
    const margin = HinterTokens.s4;
    final under = widget.screen.height - widget.anchor.bottom - margin;
    final over = widget.anchor.top - margin;
    _below =
        (widget.below && under - HinterTokens.s1 >= 2 * _rowH) ||
        under >= 6 * _rowH ||
        under >= over;
    final room = (_below ? under : over) - HinterTokens.s1;
    _height = math.max(
      math.min(math.min(room, 10.5 * _rowH), total),
      math.min(2 * _rowH, total),
    );

    _scroll = ScrollController(initialScrollOffset: _centered(cur, total));
    _region.setRows([
      for (var i = 0; i < _choiceTop.length; i++) NavRow('c$i', 1),
    ]);
    _region.model.goTo(cur, 0);
    _total = total;
    _region.onRevealHook = (row, _) => _reveal(row);
    if (_groupStarts.length > 1) {
      _region.interceptMove = (dir) => switch (dir) {
        NavDir.left => _jumpGroup(-1),
        NavDir.right => _jumpGroup(1),
        _ => false,
      };
      _region.onAction = (a) => switch (a) {
        NavAction.pageLeft => _jumpGroup(-1),
        NavAction.pageRight => _jumpGroup(1),
        _ => false,
      };
    }
  }

  /// Scrolls choice [row] into the middle at once (its row is built in the
  /// next frame; a focus asked for before that lands then).
  void _reveal(int row) {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(
      _centered(row, _total).clamp(0.0, _scroll.position.maxScrollExtent),
    );
  }

  /// The scroll offset that puts choice [i] in the middle of the list.
  double _centered(int i, double total) {
    if (_choiceTop.isEmpty) return 0;
    final top = _choiceTop[i] - (_height - _rowH) / 2;
    return top.clamp(0.0, math.max(0.0, total - _height));
  }

  /// To the first choice of the next group ([step] 1), or of this group and
  /// then the one before ([step] -1).
  bool _jumpGroup(int step) {
    final row = _region.model.row;
    var g = _groupStarts.lastIndexWhere((s) => s <= row);
    if (step > 0) {
      g = math.min(g + 1, _groupStarts.length - 1);
    } else if (_groupStarts[g] == row) {
      g = math.max(g - 1, 0);
    }
    final target = _groupStarts[g];
    if (target != row) {
      _region.model.goTo(target, 0);
      _region.changed();
      _reveal(target);
      unawaited(_region.focusCurrent());
    }
    return true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final width = widget.anchor.width;
    return Stack(
      children: [
        Positioned.fill(child: _Shade(clear: widget.clear)),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: widget.link,
            showWhenUnlinked: false,
            targetAnchor: _below ? Alignment.bottomLeft : Alignment.topLeft,
            followerAnchor: _below ? Alignment.topLeft : Alignment.bottomLeft,
            offset: Offset(0, _below ? HinterTokens.s1 : -HinterTokens.s1),
            child: SizedBox(
              width: width,
              height: _height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
                  border: Border.all(
                    color: t.highContrast ? t.text : t.textDim,
                    width: t.highContrast ? 3 : 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x99000000), blurRadius: 24),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    HinterTokens.radiusSmall - 2,
                  ),
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0x00000000),
                        Color(0xFF000000),
                        Color(0xFF000000),
                        Color(0x00000000),
                      ],
                      stops: [0, _pad / r.height, 1 - _pad / r.height, 1],
                    ).createShader(r),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: _pad),
                      itemCount: _lines.length,
                      itemExtentBuilder: (i, _) => i >= _lines.length
                          ? null
                          : _lines[i].choice == null
                          ? _headH
                          : _rowH,
                      itemBuilder: (context, i) {
                        final l = _lines[i];
                        final c = l.choice;
                        if (c == null) return _Header(l.header!);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HinterTokens.s2,
                            vertical: 4,
                          ),
                          child: NavFocusable(
                            region: _region,
                            rowKey: 'c${l.index}',
                            col: 0,
                            onSelect: () => widget.modal.close(c),
                            onFocused: widget.onHighlight == null
                                ? null
                                : () => widget.onHighlight!(c),
                            builder: (_, f) =>
                                _ChoiceRow(choice: c, focused: f),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HinterTokens.s3,
        HinterTokens.s2,
        HinterTokens.s3,
        0,
      ),
      child: Text(
        text,
        maxLines: 1,
        style: t.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.focused});

  final DropDownChoice<Object?> choice;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final current = choice.current;
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: focused ? t.surfaceHigh : t.surface,
            borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HinterTokens.s2),
            child: Row(
              children: [
                // The choice in use: a filled disc in a ring (a shape, not
                // only a colour), like the other settings choices.
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current ? t.text : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: current
                      ? Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: HinterTokens.s2),
                Expanded(child: Builder(builder: choice.build)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The shade over the screen behind the open list, with a hole at [clear]
/// (global), where things must stay as they are (the time zone map).
class _Shade extends LeafRenderObjectWidget {
  const _Shade({this.clear});

  final Rect? clear;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShade(clear);

  @override
  void updateRenderObject(BuildContext context, _RenderShade r) =>
      r.clear = clear;
}

class _RenderShade extends RenderBox {
  _RenderShade(this._clear);

  Rect? _clear;
  set clear(Rect? v) {
    if (v == _clear) return;
    _clear = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final area = offset & size;
    final c = _clear;
    if (c == null) {
      context.canvas.drawRect(area, paint);
      return;
    }
    // [clear] is global; [offset] is in the layer this paints into.
    final hole = c.shift(offset - localToGlobal(Offset.zero));
    context.canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(area)
        ..addRRect(
          RRect.fromRectAndRadius(
            hole,
            const Radius.circular(HinterTokens.radiusSmall),
          ),
        ),
      paint,
    );
  }
}
