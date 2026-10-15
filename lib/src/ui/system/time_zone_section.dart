/// Settings -> Time zone: the box's zone in the picker (map and drop-down).
/// A box-wide setting: a change takes the admin PIN on the usual pad
/// ([withBoxAdminPin]) and applies at once (no job).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../system/models.dart';
import '../../system/time_zone.dart';
import '../dialogs.dart';
import '../profiles/profile_ui.dart' show withBoxAdminPin;
import '../time_zone/time_zone_picker.dart';
import '../widgets.dart';
import 'common.dart';

class TimeZoneSection extends StatefulWidget {
  const TimeZoneSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<TimeZoneSection> createState() => _TimeZoneSectionState();
}

class _TimeZoneSectionState extends State<TimeZoneSection> {
  bool _busy = false;

  TimeZoneRepository get _tz => widget.env.services.timeZone;

  Future<void> _set(TimeZoneEntry z, Future<void> Function() reload) async {
    final c = context;
    try {
      final info = await withBoxAdminPin(
        c,
        widget.env.services.profiles,
        title: 'Set the time zone',
        // Busy only while it is applied (not while the pad is up).
        action: (pin) async {
          if (mounted) setState(() => _busy = true);
          try {
            return await _tz.set(z.zone, adminPin: pin);
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
      );
      if (info != null) await reload();
    } on SystemException catch (e) {
      if (c.mounted) {
        await showMessage(c, title: "That didn't work", body: e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loaded<(TimeZoneInfo, List<TimeZoneEntry>)>(
      region: widget.env.region,
      load: () async => (await _tz.get(), await _tz.list()),
      updates: [
        _tz.changes.map(
          (i) =>
              (d) => (i, d.$2),
        ),
      ],
      builder: (context, data, reload) {
        final (info, zones) = data;
        final p = Pane(widget.env.region);
        p.row(
          'zone',
          1,
          TimeZonePicker(
            region: widget.env.region,
            rowKey: 'zone',
            zones: zones,
            current: info,
            busy: _busy,
            onChoose: (z) => _set(z, reload),
          ),
        );
        return p.build();
      },
    );
  }
}
