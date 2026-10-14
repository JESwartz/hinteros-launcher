// The time zone (session API 0.16): the picker (the drop-down's list, the
// map's band from the standard offset), Settings > Time zone with the admin
// PIN, the first-boot step without one, and the top-bar clock (UTC plus the
// daemon's offset, again at the next change and on `time_zone_changed`).
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/mock_time_zones.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/time_zone.dart';
import 'package:hinteros_launcher/src/ui/time_zone/time_zone_map.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

const _askPin = "Type the admin profile's PIN.";

Harness harness({
  String zone = 'UTC',
  bool setupRequired = false,
  MockProfileBox? box,
  DateTime Function() now = fixedNow,
}) => Harness(
  services: MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    timeZone: zone,
    setupRequired: setupRequired,
    profileBox: box,
  ),
  now: now,
);

/// The band the map highlights.
Duration? mapBand(WidgetTester t) =>
    t.widget<TimeZoneMap>(find.byType(TimeZoneMap)).standardOffset;

bool listOpen() =>
    find.byKey(const ValueKey('time-zone-list')).evaluate().isNotEmpty;

/// The zone of the focused list row (`modal-N/zK:0`), in list order.
String? focusedZone(List<TimeZoneEntry> zones) {
  final m = RegExp(r'/z(\d+):0$').firstMatch(focusLabel() ?? '');
  if (m == null) return null;
  final ordered = [for (final (_, list) in groupTimeZones(zones)) ...list];
  return ordered[int.parse(m[1]!)].zone;
}

void main() {
  final all = [
    for (final z in mockTimeZones)
      TimeZoneEntry(
        zone: z.zone,
        offset: Duration(minutes: z.offset),
        standardOffset: Duration(minutes: z.standard),
      ),
  ];

  group('model', () {
    test('offsets: a real minus sign, hours and minutes', () {
      expect(formatUtcOffset(const Duration(hours: -6)), 'UTC−06:00');
      expect(formatUtcOffset(const Duration(minutes: 330)), 'UTC+05:30');
      expect(formatUtcOffset(const Duration(minutes: -150)), 'UTC−02:30');
      expect(formatUtcOffset(Duration.zero), 'UTC+00:00');
    });

    test('grouped by region in the design order, each by name', () {
      final g = groupTimeZones(all.reversed);
      expect([for (final (r, _) in g) r], timeZoneRegions);
      final america = g.firstWhere((x) => x.$1 == 'America').$2;
      expect(america.first.zone, 'America/Anchorage');
      expect([
        for (final z in america) z.zone,
      ], [for (final z in america) z.zone]..sort());
    });

    test('the wall clock is UTC plus the offset', () {
      const chicago = TimeZoneInfo(
        zone: 'America/Chicago',
        offset: Duration(hours: -5),
        standardOffset: Duration(hours: -6),
      );
      expect(
        chicago.wallClock(DateTime.utc(2026, 10, 6, 20, 30)),
        DateTime.utc(2026, 10, 6, 15, 30),
      );
    });

    test('the map asset has the land and a band per standard offset', () {
      final d = TimeZoneMapData.parse(
        File(TimeZoneMapData.asset).readAsBytesSync(),
      );
      expect(d.unitsPerDegree, 10);
      expect(d.land.getBounds().width, greaterThan(3000));
      for (final h in [-10.0, -6.0, -5.0, 0.0, 1.0, 5.5, 5.75, 9.5, 12.0]) {
        expect(d.bands, contains((h * 3600).round()), reason: '$h');
      }
      expect(File(TimeZoneMapData.asset).lengthSync(), lessThan(500 * 1024));
    });
  });

  group('Settings > Time zone', () {
    testWidgets('shows the zone; the map shows its standard offset band', (
      t,
    ) async {
      setView(t);
      final h = harness(zone: 'America/Chicago');
      await h.pump(t);
      await enterSettingsEntry(t, 'time');
      expect(find.text('America/Chicago'), findsOneWidget);
      expect(find.text('UTC−05:00'), findsOneWidget);
      // Summer time is on: the band is the standard offset's (-6), not -5.
      expect(mapBand(t), const Duration(hours: -6));
      expect(focusLabel(), 'settings-detail/zone:0');
    });

    testWidgets('the list opens at the zone; D-pad moves, B closes', (t) async {
      setView(t);
      final h = harness(zone: 'Europe/Paris');
      await h.pump(t);
      await enterSettingsEntry(t, 'time');
      await press(t, [kEnter]);
      expect(listOpen(), isTrue);
      expect(focusedZone(all), 'Europe/Paris');
      expect(find.text('UTC+02:00'), findsWidgets);
      await press(t, [kDown]);
      expect(focusedZone(all), 'Europe/Rome');
      await press(t, [kUp, kUp]);
      expect(focusedZone(all), 'Europe/Moscow');
      // Right: the next region; left: this region's start, then the one
      // before.
      await press(t, [kRight]);
      expect(focusedZone(all), 'Indian/Chagos');
      await press(t, [kDown, kLeft]);
      expect(focusedZone(all), 'Indian/Chagos');
      await press(t, [kLeft]);
      expect(focusedZone(all), 'Europe/Berlin');
      await press(t, [kEscape]);
      expect(listOpen(), isFalse);
      expect(focusLabel(), 'settings-detail/zone:0');
      expect(h.services.mockTimeZone.log, isEmpty);
      expect(find.text(_askPin), findsNothing);
    });

    testWidgets('A chooses; the admin PIN sets it at once', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'time');
      expect(find.text('UTC+00:00'), findsOneWidget);
      expect(mapBand(t), Duration.zero);
      await press(t, [kEnter]);
      expect(focusedZone(all), 'UTC');
      // UTC is last: left goes back region by region to America.
      await press(t, List.filled(8, kLeft));
      expect(focusedZone(all), 'America/Anchorage');
      await press(t, List.filled(4, kDown));
      expect(focusedZone(all), 'America/Chicago');
      await press(t, [kEnter]);
      expect(listOpen(), isFalse);
      expect(find.text('Set the time zone'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockTimeZone.log, isEmpty);
      await enterPin(t, '1357');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockTimeZone.log, isEmpty);
      await enterPin(t, '2468');
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockTimeZone.zone, 'America/Chicago');
      expect(find.text('America/Chicago'), findsOneWidget);
      expect(mapBand(t), const Duration(hours: -6));
    });

    testWidgets('Back on the PIN pad changes nothing', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'time');
      await press(t, [kEnter, kLeft, kEnter]); // Pacific/Auckland
      expect(find.text(_askPin), findsOneWidget);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockTimeZone.zone, 'UTC');
      expect(find.text('UTC+00:00'), findsOneWidget);
      expect(mapBand(t), Duration.zero);
    });

    testWidgets('choosing the zone it is on asks nothing', (t) async {
      setView(t);
      final h = harness(zone: 'Asia/Tokyo');
      await h.pump(t);
      await enterSettingsEntry(t, 'time');
      await press(t, [kEnter, kEnter]);
      expect(listOpen(), isFalse);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockTimeZone.log, isEmpty);
    });
  });

  group('first boot', () {
    testWidgets('a Time zone step after Internet: UTC, set with no PIN', (
      t,
    ) async {
      setView(t);
      final box = MockProfileBox(profiles: [], now: fixedNow);
      final h = harness(setupRequired: true, box: box);
      await h.pump(t);
      await press(t, [kEnter]); // Start
      for (final title in ['Internet', 'Time zone']) {
        for (var i = 0; i < 20 && find.text(title).evaluate().isEmpty; i++) {
          await press(t, [kDown]);
          if (focusLabel()?.endsWith('/actions:0') ?? false) {
            await press(t, [kEnter]);
          }
        }
        expect(find.text(title), findsWidgets, reason: title);
      }
      expect(find.text('Step 4 of 7'), findsOneWidget);
      // It starts on UTC, the drop-down focused.
      expect(find.text('UTC+00:00'), findsOneWidget);
      expect(mapBand(t), Duration.zero);
      expect(focusLabel(), endsWith('/zone:0'));
      await press(t, [kEnter, kLeft, kLeft, kLeft, kEnter]); // Europe/Berlin
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockTimeZone.log, ['Europe/Berlin']);
      expect(find.text('Europe/Berlin'), findsOneWidget);
      expect(mapBand(t), const Duration(hours: 1));
      await press(t, [kDown, kEnter]); // Continue
      expect(find.text('Display'), findsOneWidget);
      await press(t, [kEscape]); // back: the zone is kept
      expect(find.text('Europe/Berlin'), findsOneWidget);
    });
  });

  group('clock', () {
    testWidgets('UTC plus the offset; again on time_zone_changed', (t) async {
      setView(t);
      final h = harness(
        zone: 'America/Chicago',
        now: () => DateTime.utc(2026, 10, 6, 20, 30),
      );
      await h.pump(t);
      expect(find.text('15:30'), findsOneWidget);
      h.services.mockTimeZone.changeElsewhere('Asia/Kolkata');
      await t.pumpAndSettle();
      expect(find.text('02:00'), findsOneWidget);
    });

    testWidgets('gets the zone again at the next offset change', (t) async {
      setView(t);
      // 07:00 UTC on 2026-11-01: Chicago leaves summer time.
      var now = DateTime.utc(2026, 11, 1, 6, 58);
      final h = harness(zone: 'America/Chicago', now: () => now);
      await h.pump(t);
      expect(find.text('01:58'), findsOneWidget);
      final gets = h.services.mockTimeZone.gets;
      // The mock's offsets are fixed: a zone without summer time stands in
      // for Chicago after the change.
      h.services.mockTimeZone.zone = 'America/Mexico_City';
      now = DateTime.utc(2026, 11, 1, 7, 0, 30);
      await t.pump(const Duration(minutes: 1));
      expect(h.services.mockTimeZone.gets, gets);
      await t.pump(const Duration(minutes: 1, seconds: 2));
      await t.pumpAndSettle();
      expect(h.services.mockTimeZone.gets, gets + 1);
      expect(find.text('01:00'), findsOneWidget);
    });
  });
}
