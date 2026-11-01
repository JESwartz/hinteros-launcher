import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of Settings > Storage at 1920x1080: the ring at the
/// top level, inside a profile, the clean-up confirmation, the automatic
/// clean-up, and high contrast. Regenerate with `nix run .#update-goldens`.
void main() {
  Harness harness({LauncherSettings settings = const LauncherSettings()}) {
    final services = MockSystemServices(
      iconDir: iconDir(),
      now: fixedNow,
      profileBox: MockProfileBox(
        now: fixedNow,
        profiles: [...MockProfileBox.defaultProfiles(), mockRobin()],
      ),
    );
    return Harness(settings: settings, services: services);
  }

  Future<void> shot(
    WidgetTester t,
    String name,
    Harness h, {
    Future<void> Function(WidgetTester)? run,
  }) async {
    setView(t);
    await h.pump(t);
    await enterSettingsEntry(t, 'storage');
    await run?.call(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('the ring at the top level', (t) async {
    // Right twice: the first profile (James) is selected.
    await shot(
      t,
      'storage_top_1080p',
      harness(),
      run: (t) => press(t, [kRight, kRight]),
    );
  });

  testWidgets('inside the own profile', (t) async {
    await shot(
      t,
      'storage_profile_1080p',
      harness(),
      run: (t) => press(t, [kRight, kRight, kEnter, kRight]),
    );
  });

  testWidgets('clean up the system, keep 1', (t) async {
    await shot(
      t,
      'storage_cleanup_confirm_1080p',
      harness(),
      run: (t) => press(t, [kDown, kDown, kEnter, kLeft, kLeft, kLeft, kLeft]),
    );
  });

  /// Down to Clean up the system, A, then left: caught while the left
  /// arrow is lit.
  Future<void> litLeft(WidgetTester t) async {
    await press(t, [kDown, kDown, kEnter]);
    await t.sendKeyEvent(kLeft);
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
  }

  testWidgets('the left arrow of the picker lights up when pressed', (t) async {
    await shot(t, 'storage_cleanup_arrow_lit_1080p', harness(), run: litLeft);
  });

  testWidgets('the picker, high contrast, text 1.6x, arrow lit', (t) async {
    await shot(
      t,
      'storage_cleanup_highcontrast_text160_1080p',
      harness(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      ),
      run: litLeft,
    );
  });

  testWidgets('high contrast inside the own profile', (t) async {
    await shot(
      t,
      'storage_profile_highcontrast_1080p',
      harness(settings: const LauncherSettings(highContrast: true)),
      run: (t) => press(t, [kRight, kRight, kEnter]),
    );
  });

  testWidgets('the automatic clean-up', (t) async {
    await shot(
      t,
      'storage_automatic_1080p',
      harness(),
      run: (t) =>
          press(t, [kDown, kDown, kDown, kDown, kEnter, kDown, kRight, kRight]),
    );
  });

  testWidgets('high contrast, text 1.6x, ring style', (t) async {
    await shot(
      t,
      'storage_highcontrast_text160_1080p',
      harness(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      ),
      run: (t) => press(t, [kRight]),
    );
  });

  testWidgets('glow focus style, inside the system', (t) async {
    await shot(
      t,
      'storage_system_glow_1080p',
      harness(settings: const LauncherSettings(focusStyle: FocusStyle.glow)),
      run: (t) => press(t, [kEnter, kRight]),
    );
  });

  testWidgets('bar focus style, the guest selected', (t) async {
    await shot(
      t,
      'storage_bar_1080p',
      harness(settings: const LauncherSettings(focusStyle: FocusStyle.bar)),
      run: (t) => press(t, [kLeft, kLeft, kLeft, kLeft]),
    );
  });
}
