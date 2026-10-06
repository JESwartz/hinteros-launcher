import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart';

/// Golden screenshots (TESTING.md): every screen at 1920x1080, Home and Games
/// also at 3840x2160 (1920x1080 logical at DPR 2), plus Home in the
/// high-contrast, 1.6x text variant. Regenerate with `nix run .#update-goldens`.
void main() {
  const fourK = (size: Size(1920, 1080), dpr: 2.0);

  Future<void> shot(
    WidgetTester tester,
    String name, {
    Harness? h,
    Future<void> Function(WidgetTester, Harness)? setup,
    List<LogicalKeyboardKey> keys = const [],
    double dpr = 1.0,
  }) async {
    setView(tester, dpr: dpr);
    h ??= Harness();
    await h.pump(tester);
    await setup?.call(tester, h);
    for (final k in keys) {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  // Something running, so Home has a Continue row.
  Future<void> running(WidgetTester t, Harness h) async {
    await h.launch(t, 'jellyfin');
    await h.launch(t, 'steam');
  }

  const right = LogicalKeyboardKey.arrowRight;
  const down = LogicalKeyboardKey.arrowDown;
  const up = LogicalKeyboardKey.arrowUp;
  // From Home content: up to the tab bar, then to the tab and back down.
  const toGames = [up, right, down];
  const toApps = [up, right, right, down];
  const toSettings = [up, right, right, right, down];

  testWidgets('home 1080p', (t) async {
    await shot(t, 'home_1080p', setup: running, keys: [right]);
  });
  testWidgets('home 4k', (t) async {
    await shot(t, 'home_4k', setup: running, keys: [right], dpr: fourK.dpr);
  });
  testWidgets('home high contrast, text 1.6x', (t) async {
    await shot(
      t,
      'home_highcontrast_text160_1080p',
      h: Harness(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      ),
      setup: (t, h) async {
        await h.launch(t, 'jellyfin');
        h.mock.pressHome(); // back to the first card, now in Continue
        await t.pumpAndSettle();
      },
      keys: [right],
    );
  });
  testWidgets('home scrolled to games', (t) async {
    await shot(
      t,
      'home_games_row_1080p',
      setup: running,
      keys: [down, down, right, right],
    );
  });
  testWidgets('games 1080p', (t) async {
    await shot(t, 'games_1080p', keys: [...toGames, right, right, down, down]);
  });
  testWidgets('games 4k', (t) async {
    await shot(
      t,
      'games_4k',
      keys: [...toGames, right, right, down],
      dpr: fourK.dpr,
    );
  });
  testWidgets('apps 1080p', (t) async {
    await shot(t, 'apps_1080p', keys: [...toApps, down, right]);
  });
  testWidgets('settings 1080p', (t) async {
    await shot(t, 'settings_1080p', keys: [...toSettings, down, down]);
  });
  testWidgets('settings detail, glow focus style', (t) async {
    await shot(
      t,
      'settings_focus_detail_1080p',
      h: Harness(settings: const LauncherSettings(focusStyle: FocusStyle.glow)),
      keys: [...toSettings, down, down, right, down],
    );
  });
  testWidgets('settings system placeholder', (t) async {
    await shot(
      t,
      'settings_system_1080p',
      keys: [...toSettings, down, down, down, down],
    );
  });
  testWidgets('daemon unreachable', (t) async {
    await shot(
      t,
      'home_unreachable_1080p',
      h: Harness(mock: StuckConnection(const Unreachable('no such file'))),
    );
  });
}
