/// The time zone picker of first boot and Settings: a drop-down that shows
/// the zone (`UTC−06:00  America/Chicago`) and, under it, the world map with
/// that zone's band. A on the drop-down opens the list of every zone, grouped
/// by region, at the current zone: up and down move, left and right (or L1
/// and R1) go to the previous or next region, A chooses, B closes. The map
/// only shows; the drop-down chooses.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/api.dart' show NavAction;
import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/time_zone.dart';
import '../../theme/hinter_theme.dart';
import '../focus_frame.dart';
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../widgets.dart' show Spinner;
import 'time_zone_map.dart';

/// The drop-down (one item, at [rowKey]:0 of [region]) and the map. Put it in
/// a pane with `Pane.row(rowKey, 1, TimeZonePicker(...))`.
class TimeZonePicker extends StatefulWidget {
  const TimeZonePicker({
    super.key,
    required this.region,
    required this.rowKey,
    required this.zones,
    required this.current,
    required this.onChoose,
    this.busy = false,
    this.maxWidth = 1100,
  });

  final NavRegion region;
  final String rowKey;

  /// Every zone (`time_zone.list`).
  final List<TimeZoneEntry> zones;

  /// The box's zone: shown, highlighted on the map, the list opens at it.
  final TimeZoneInfo current;

  /// A zone was chosen in the list (also the current one again: ignored by
  /// the picker, so this only sees a change).
  final void Function(TimeZoneEntry zone) onChoose;

  /// A change is being applied: a spinner instead of the arrow, A does
  /// nothing.
  final bool busy;
  final double maxWidth;

  @override
  State<TimeZonePicker> createState() => _TimeZonePickerState();
}

class _TimeZonePickerState extends State<TimeZonePicker> {
  final _link = LayerLink();
  final _field = GlobalKey();
  bool _open = false;

  Future<void> _openList() async {
    if (_open || widget.busy || widget.zones.isEmpty) return;
    final box = _field.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final anchor = topLeft & box.size;
    final screen = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    _open = true;
    final TimeZoneEntry? chosen;
    try {
      chosen = await ModalScope.of(context).show<TimeZoneEntry>(
        (c, modal) => TimeZoneList(
          modal: modal,
          zones: widget.zones,
          current: widget.current.zone,
          link: _link,
          anchor: anchor,
          screen: screen,
          textScale: textScale,
        ),
      );
    } finally {
      _open = false;
    }
    if (!mounted || chosen == null || chosen.zone == widget.current.zone) {
      return;
    }
    widget.onChoose(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.current;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CompositedTransformTarget(
            link: _link,
            child: NavFocusable(
              region: widget.region,
              rowKey: widget.rowKey,
              col: 0,
              onSelect: () => unawaited(_openList()),
              builder: (_, f) => KeyedSubtree(
                key: _field,
                child: _DropDownField(
                  offset: formatUtcOffset(c.offset),
                  zone: c.zone,
                  focused: f,
                  busy: widget.busy,
                ),
              ),
            ),
          ),
          const SizedBox(height: HinterTokens.s3),
          TimeZoneMap(standardOffset: c.standardOffset),
        ],
      ),
    );
  }
}

/// The closed drop-down: offset, zone, and a down arrow (it opens a list).
class _DropDownField extends StatelessWidget {
  const _DropDownField({
    required this.offset,
    required this.zone,
    required this.focused,
    required this.busy,
  });

  final String offset;
  final String zone;
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
              _OffsetText(offset, style: t.label),
              const SizedBox(width: HinterTokens.s3),
              Expanded(
                child: Text(
                  zone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
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

/// `UTC−06:00` in figures of one width, so the zones line up.
class _OffsetText extends StatelessWidget {
  const _OffsetText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  );
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

/// One line of the open list: a region's name or a zone.
typedef _Line = ({String? region, TimeZoneEntry? zone, int index});

/// The open drop-down: every zone by region, under (or over) the field at
/// [anchor] (global), following it through [link]. Resolves with the chosen
/// zone; null on B.
class TimeZoneList extends StatefulWidget {
  const TimeZoneList({
    super.key,
    required this.modal,
    required this.zones,
    required this.current,
    required this.link,
    required this.anchor,
    required this.screen,
    this.textScale = 1,
  });

  final ModalHandle<TimeZoneEntry> modal;
  final List<TimeZoneEntry> zones;
  final String current;
  final LayerLink link;
  final Rect anchor;
  final Size screen;

  /// The text size setting: the lines grow with it.
  final double textScale;

  /// Line heights at 100% text.
  static const rowHeight = 64.0;
  static const headerHeight = 56.0;

  @override
  State<TimeZoneList> createState() => _TimeZoneListState();
}

class _TimeZoneListState extends State<TimeZoneList> {
  late final List<_Line> _lines;

  /// The zones in list order (the nav rows: `z0`, `z1`, ...).
  late final List<TimeZoneEntry> _zones;

  /// Where each zone's line starts, and the first zone of each region.
  late final List<double> _zoneTop;
  late final List<int> _regionStarts;
  late final double _height;
  late final bool _below;
  late final ScrollController _scroll;
  late final double _total;

  /// Room above the first and under the last row; rows that scroll past
  /// the edges fade out over the same height.
  static const _pad = HinterTokens.s2;

  NavRegion get _region => widget.modal.region;

  double get _scale => math.max(1.0, widget.textScale);
  double get _rowH => TimeZoneList.rowHeight * _scale;
  double get _headH => TimeZoneList.headerHeight * _scale;

  @override
  void initState() {
    super.initState();
    final lines = <_Line>[];
    final zones = <TimeZoneEntry>[];
    final tops = <double>[];
    final starts = <int>[];
    var y = _pad;
    for (final (region, list) in groupTimeZones(widget.zones)) {
      lines.add((region: region, zone: null, index: -1));
      y += _headH;
      starts.add(zones.length);
      for (final z in list) {
        lines.add((region: null, zone: z, index: zones.length));
        tops.add(y);
        zones.add(z);
        y += _rowH;
      }
    }
    _lines = lines;
    _zones = zones;
    _zoneTop = tops;
    _regionStarts = starts;
    final total = y + _pad;

    // Under the field when there is room for a good part of the list,
    // else over it.
    const margin = HinterTokens.s4;
    final under = widget.screen.height - widget.anchor.bottom - margin;
    final over = widget.anchor.top - margin;
    _below = under >= 6 * _rowH || under >= over;
    final room = (_below ? under : over) - HinterTokens.s1;
    _height = math.max(
      math.min(math.min(room, 10.5 * _rowH), total),
      2 * _rowH,
    );

    final cur = math.max(0, _zones.indexWhere((z) => z.zone == widget.current));
    _scroll = ScrollController(initialScrollOffset: _centered(cur, total));
    _region.setRows([for (var i = 0; i < _zones.length; i++) NavRow('z$i', 1)]);
    _region.model.goTo(cur, 0);
    _total = total;
    _region.onRevealHook = (row, _) => _reveal(row);
    _region.interceptMove = (dir) => switch (dir) {
      NavDir.left => _jumpRegion(-1),
      NavDir.right => _jumpRegion(1),
      _ => false,
    };
    _region.onAction = (a) => switch (a) {
      NavAction.pageLeft => _jumpRegion(-1),
      NavAction.pageRight => _jumpRegion(1),
      _ => false,
    };
  }

  /// Scrolls zone [row] into the middle at once (its row is built in the
  /// next frame; a focus asked for before that lands then).
  void _reveal(int row) {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(
      _centered(row, _total).clamp(0.0, _scroll.position.maxScrollExtent),
    );
  }

  /// The scroll offset that puts zone [i] in the middle of the list.
  double _centered(int i, double total) {
    if (_zoneTop.isEmpty) return 0;
    final top = _zoneTop[i] - (_height - _rowH) / 2;
    return top.clamp(0.0, math.max(0.0, total - _height));
  }

  /// To the first zone of the next region ([step] 1), or of this region
  /// and then the one before ([step] -1).
  bool _jumpRegion(int step) {
    final row = _region.model.row;
    var r = _regionStarts.lastIndexWhere((s) => s <= row);
    if (step > 0) {
      r = math.min(r + 1, _regionStarts.length - 1);
    } else if (_regionStarts[r] == row) {
      r = math.max(r - 1, 0);
    }
    final target = _regionStarts[r];
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
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
        ),
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
              key: const ValueKey('time-zone-list'),
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
                          : _lines[i].zone == null
                          ? _headH
                          : _rowH,
                      itemBuilder: (context, i) {
                        final l = _lines[i];
                        final z = l.zone;
                        if (z == null) return _RegionHeader(l.region!);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HinterTokens.s2,
                            vertical: 4,
                          ),
                          child: NavFocusable(
                            region: _region,
                            rowKey: 'z${l.index}',
                            col: 0,
                            onSelect: () => widget.modal.close(z),
                            builder: (_, f) => _ZoneRow(
                              zone: z,
                              current: z.zone == widget.current,
                              focused: f,
                            ),
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

class _RegionHeader extends StatelessWidget {
  const _RegionHeader(this.region);

  final String region;

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
        region,
        maxLines: 1,
        style: t.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.current,
    required this.focused,
  });

  final TimeZoneEntry zone;
  final bool current;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final style = t.body.copyWith(
      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
    );
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
                // The zone the box is on: a filled disc in a ring (a shape,
                // not only a colour), like the other settings choices.
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
                SizedBox(
                  // Room for `UTC−10:30` at every text size.
                  width:
                      180 *
                      math.max(1.0, MediaQuery.textScalerOf(context).scale(1)),
                  child: _OffsetText(
                    formatUtcOffset(zone.offset),
                    style: style,
                  ),
                ),
                const SizedBox(width: HinterTokens.s2),
                Expanded(
                  child: Text(
                    zone.zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
