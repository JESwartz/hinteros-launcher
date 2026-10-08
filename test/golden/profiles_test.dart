import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';

import '../profiles/session_test.dart' show frames, harness, keys, openChip;
import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the profile screens inside a session.
/// Regenerate with `nix run .#update-goldens`.
void main() {
  Future<void> shot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/profiles_${name}_1080p.png'),
  );

  testWidgets('chip menu', (t) async {
    setView(t);
    await harness().pump(t);
    await openChip(t);
    await shot(t, 'chip_menu');
  });

  testWidgets('switch picker', (t) async {
    setView(t);
    await harness().pump(t);
    await openChip(t);
    await keys(t, [kEnter]);
    await shot(t, 'switch_picker');
  });

  testWidgets('not responding', (t) async {
    setView(t);
    final h = harness();
    h.services.mockProfiles.blockingApp = (id: 'youtube', name: 'YouTube');
    await h.pump(t);
    await openChip(t);
    await keys(t, [kEnter, kEnter]);
    await frames(t, 10);
    await shot(t, 'not_responding');
  });

  testWidgets('lock screen', (t) async {
    setView(t);
    final h = harness(current: 'p3');
    await h.pump(t);
    h.services.mockProfiles.sleep();
    await t.pumpAndSettle();
    await shot(t, 'lock_screen');
  });

  testWidgets('settings profiles', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'profiles');
    await shot(t, 'settings');
  });

  testWidgets('settings profiles, high contrast, text 1.6x', (t) async {
    setView(t);
    final h = Harness(
      settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      services: MockSystemServices(iconDir: iconDir(), now: fixedNow),
    );
    await h.pump(t);
    await enterSettingsEntry(t, 'profiles');
    await shot(t, 'settings_highcontrast_text160');
  });

  testWidgets('hold to remove', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'profiles');
    await keys(t, [kDown, kEnter, kDown, kDown, kEnter, kRight, kEnter]);
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    await shot(t, 'hold_remove');
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
  });

  testWidgets('first boot: create your profile', (t) async {
    setView(t);
    final h = harness(
      setupRequired: true,
      box: MockProfileBox(profiles: [], now: fixedNow),
    );
    await h.pump(t);
    await keys(t, [kEnter]);
    for (
      var i = 0;
      i < 30 && find.text('Create your profile').evaluate().isEmpty;
      i++
    ) {
      await keys(t, [kDown]);
      if (focusLabel()?.endsWith('/actions:0') ?? false) {
        await keys(t, [kEnter]);
      }
    }
    await keys(t, [kEnter]);
    await shot(t, 'first_boot_name');
  });
}
