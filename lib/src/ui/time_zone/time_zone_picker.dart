/// The time zone picker of first boot and Settings: the world map with the
/// zone's band and, under it, a drop-down that shows the zone
/// (`UTC−06:00  America/Chicago`). A on the drop-down opens the list of every
/// zone by UTC offset, highest at the top (UTC+14:00, ..., UTC+00:00, ...,
/// UTC−12:00), with a header per offset, at the current zone, under the
/// field (it never covers the map): up and down move, left and right (or L1
/// and R1) go to the previous or next offset, A chooses, B closes. The map
/// follows the focus in the list; B puts it back on the box's zone, a choice
/// keeps it there while it is applied. The map only shows; the drop-down
/// chooses. The band is the zone's standard offset (the map's bands are by
/// standard offset), so summer time does not move it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../system/time_zone.dart';
import '../../theme/hinter_theme.dart';
import '../drop_down.dart';
import 'time_zone_map.dart';

/// The map and the drop-down (one item, at [rowKey]:0 of [region]). Put it
/// in a pane with `Pane.row(rowKey, 1, TimeZonePicker(...))`.
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
  /// the picker, so this only sees a change). The map shows it until the
  /// future completes (the change is applied, or not).
  final FutureOr<void> Function(TimeZoneEntry zone) onChoose;

  /// A change is being applied: a spinner instead of the arrow, A does
  /// nothing.
  final bool busy;
  final double maxWidth;

  @override
  State<TimeZonePicker> createState() => _TimeZonePickerState();
}

class _TimeZonePickerState extends State<TimeZonePicker> {
  final _picker = GlobalKey();

  /// The zone under the focus while the list is open.
  TimeZoneEntry? _preview;

  /// The zone chosen, while it is applied.
  TimeZoneEntry? _chosen;

  /// The list: a group per offset, highest first.
  List<DropDownGroup<TimeZoneEntry>> _groups() => [
    for (final (offset, list) in groupTimeZones(widget.zones))
      DropDownGroup(formatUtcOffset(offset), [
        for (final z in list)
          DropDownChoice(
            value: z,
            current: z.zone == widget.current.zone,
            build: (_) =>
                _ZoneLine(zone: z, current: z.zone == widget.current.zone),
          ),
      ]),
  ];

  Future<void> _choose(TimeZoneEntry z) async {
    setState(() => _chosen = z);
    try {
      await widget.onChoose(z);
    } finally {
      if (mounted && _chosen == z) setState(() => _chosen = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final c = widget.current;
    return ConstrainedBox(
      key: _picker,
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TimeZoneMap(
            standardOffset:
                (_preview ?? _chosen)?.standardOffset ?? c.standardOffset,
          ),
          const SizedBox(height: HinterTokens.s3),
          DropDown<TimeZoneEntry>(
            region: widget.region,
            rowKey: widget.rowKey,
            busy: widget.busy,
            listKey: const ValueKey('time-zone-list'),
            groups: _groups,
            onChoose: (z) => unawaited(_choose(z)),
            onHighlight: (z) => setState(() => _preview = z),
            below: true,
            keepInView: _picker,
            field: Row(
              children: [
                _OffsetText(formatUtcOffset(c.offset), style: t.label),
                const SizedBox(width: HinterTokens.s3),
                Expanded(
                  child: Text(
                    c.zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
        ],
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

/// A zone in the list: its offset, then its name.
class _ZoneLine extends StatelessWidget {
  const _ZoneLine({required this.zone, required this.current});

  final TimeZoneEntry zone;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final style = t.body.copyWith(
      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
    );
    return Row(
      children: [
        SizedBox(
          // Room for `UTC−10:30` at every text size.
          width: 180 * math.max(1.0, MediaQuery.textScalerOf(context).scale(1)),
          child: _OffsetText(formatUtcOffset(zone.offset), style: style),
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
    );
  }
}
