import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/ui/drop_down.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the time zone picker at 1920x1080: Settings > Time
/// zone (the map with the band of the zone's standard offset, the drop-down
/// under it), the open list under the field, high contrast at 1.6x text,
/// and the first-boot step. Regenerate with `nix run .#update-goldens`.
void main() {
  Harness harness({
    String zone = 'America/Chicago',
    LauncherSettings settings = const LauncherSettings(),
    bool setupRequired = false,
    MockProfileBox? box,
  }) => Harness(
    settings: settings,
    services: MockSystemServices(
      iconDir: iconDir(),
      now: fixedNow,
      timeZone: zone,
      setupRequired: setupRequired,
      profileBox: box,
    ),
  );

  Future<void> shot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/time_zone_${name}_1080p.png'),
  );

  /// The open list is under the field, on the screen, with room for at
  /// least two zones; all of the map is on the screen, over the field.
  void expectListUnderField(WidgetTester t, {double textScale = 1}) {
    final map = t.getRect(find.byKey(const ValueKey('time-zone-map')));
    final field = t.getRect(find.byType(DropDownField));
    // The list's box (the follower moves it; its own rect does not).
    final list = t.getRect(
      find
          .descendant(
            of: find.byType(CompositedTransformFollower),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(map.top, greaterThanOrEqualTo(0));
    expect(map.bottom, lessThanOrEqualTo(field.top));
    expect(list.top, greaterThanOrEqualTo(field.bottom));
    expect(list.bottom, lessThanOrEqualTo(1080));
    expect(list.overlaps(map), isFalse);
    expect(list.height, greaterThanOrEqualTo(2 * 64 * textScale));
  }

  testWidgets('Settings > Time zone', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'time');
    await shot(t, 'settings');
  });

  testWidgets('the open list, at the zone', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'time');
    await press(t, [kEnter, kDown]);
    expectListUnderField(t);
    await shot(t, 'list');
  });

  testWidgets('a half-hour zone in high contrast at 1.6x', (t) async {
    setView(t);
    await harness(
      zone: 'Asia/Kolkata',
      settings: const LauncherSettings(highContrast: true, textScale: 1.6),
    ).pump(t);
    await enterSettingsEntry(t, 'time');
    await shot(t, 'settings_highcontrast_text160');
  });

  testWidgets('the open list in high contrast at 1.6x', (t) async {
    setView(t);
    await harness(
      zone: 'Asia/Kolkata',
      settings: const LauncherSettings(highContrast: true, textScale: 1.6),
    ).pump(t);
    await enterSettingsEntry(t, 'time');
    await press(t, [kEnter, kUp]);
    expectListUnderField(t, textScale: 1.6);
    await shot(t, 'list_highcontrast_text160');
  });

  Future<void> toFirstBootZone(
    WidgetTester t, {
    LauncherSettings settings = const LauncherSettings(),
  }) async {
    final h = harness(
      zone: 'UTC',
      settings: settings,
      setupRequired: true,
      box: MockProfileBox(profiles: [], now: fixedNow),
    );
    await h.pump(t);
    await press(t, [kEnter]);
    for (var i = 0; i < 30 && find.text('Time zone').evaluate().isEmpty; i++) {
      await press(t, [kDown]);
      if (focusLabel()?.endsWith('/actions:0') ?? false) {
        await press(t, [kEnter]);
      }
    }
  }

  testWidgets('first boot: the Time zone step', (t) async {
    setView(t);
    await toFirstBootZone(t);
    await shot(t, 'first_boot');
  });

  // No shot: the list itself is in the Settings shots.
  testWidgets('first boot at 1.6x: the list opens under the field', (t) async {
    setView(t);
    await toFirstBootZone(
      t,
      settings: const LauncherSettings(highContrast: true, textScale: 1.6),
    );
    await press(t, [kEnter]);
    expectListUnderField(t, textScale: 1.6);
  });
}
