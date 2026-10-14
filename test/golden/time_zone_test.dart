import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the time zone picker at 1920x1080: Settings > Time
/// zone (the drop-down and the map with the band of the zone's standard
/// offset), the open list, high contrast at 1.6x text, and the first-boot
/// step. Regenerate with `nix run .#update-goldens`.
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
    await shot(t, 'list_highcontrast_text160');
  });

  testWidgets('first boot: the Time zone step', (t) async {
    setView(t);
    final h = harness(
      zone: 'UTC',
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
    await shot(t, 'first_boot');
  });
}
