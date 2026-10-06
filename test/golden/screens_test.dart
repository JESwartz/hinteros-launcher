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
  // With something running, Home has a Continue row above Apps.
  const toAppsRunning = [up, up, right, right, down];
  const toSettings = [up, right, right, right, right, down];

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
  testWidgets('home games row, text 1.6x: badges fit narrow covers', (t) async {
    await shot(
      t,
      'home_games_row_text160_1080p',
      h: Harness(settings: const LauncherSettings(textScale: 1.6)),
      keys: [down, down, right, right],
    );
  });
  testWidgets('games 1080p', (t) async {
    await shot(t, 'games_1080p', keys: [...toGames, right]);
  });
  testWidgets('games scrolled to the last row', (t) async {
    await shot(
      t,
      'games_scrolled_1080p',
      keys: [...toGames, right, right, down, down],
    );
  });
  testWidgets('games with artwork, second row focused', (t) async {
    await shot(
      t,
      'games_artwork_1080p',
      keys: [...toGames, right, down, right],
    );
  });
  testWidgets('games text 1.6x, high contrast', (t) async {
    await shot(
      t,
      'games_highcontrast_text160_1080p',
      h: Harness(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      ),
      keys: [...toGames, down, right],
    );
  });
  testWidgets('home with a running game and a running app', (t) async {
    await shot(
      t,
      'home_running_game_1080p',
      setup: (t, h) async {
        await h.mock.appsLaunch(
          const AppsLaunchParams(url: 'steam://rungameid/620'),
        );
        await h.launch(t, 'jellyfin');
        h.mock.pressHome();
        await t.pumpAndSettle();
      },
      keys: [right],
    );
  });
  testWidgets('steam attention banner', (t) async {
    await shot(
      t,
      'home_steam_attention_1080p',
      setup: (t, h) async {
        h.mock.setSteamAttention(const [
          SteamWindow(window: 6291459, title: 'Steam Guard', pid: 2412),
        ]);
        await t.pumpAndSettle();
      },
      keys: [up],
    );
  });
  testWidgets('steam attention banner over Games, text 1.6x', (t) async {
    await shot(
      t,
      'games_steam_attention_text160_1080p',
      h: Harness(settings: const LauncherSettings(textScale: 1.6)),
      setup: (t, h) async {
        h.mock.setSteamAttention(const [
          SteamWindow(window: 6291459, title: 'Steam Guard', pid: 2412),
        ]);
        await t.pumpAndSettle();
      },
      keys: [up, up, right, down],
    );
  });
  testWidgets('close confirm', (t) async {
    await shot(
      t,
      'close_confirm_1080p',
      setup: (t, h) async {
        await h.launch(t, 'jellyfin');
        await h.launch(t, 'steam');
        h.mock.pressHome();
        await t.pumpAndSettle();
      },
      keys: [right, LogicalKeyboardKey.keyY, right],
    );
  });
  testWidgets('close confirm, high contrast, text 1.6x', (t) async {
    await shot(
      t,
      'close_confirm_highcontrast_text160_1080p',
      h: Harness(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      ),
      setup: (t, h) async {
        await h.launch(t, 'jellyfin');
        h.mock.pressHome();
        await t.pumpAndSettle();
      },
      keys: [LogicalKeyboardKey.keyY],
    );
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
    await shot(
      t,
      'apps_1080p',
      setup: (t, h) async => h.launch(t, 'youtube'),
      keys: [...toAppsRunning, right],
    );
  });
  for (final scale in [1.3, 1.6]) {
    testWidgets('apps at text $scale, running app', (t) async {
      await shot(
        t,
        'apps_text${(scale * 100).round()}_1080p',
        h: Harness(settings: LauncherSettings(textScale: scale)),
        setup: (t, h) async => h.launch(t, 'youtube'),
        keys: [...toAppsRunning, right],
      );
    });
  }
  testWidgets('apps high contrast, text 1.6x, running app', (t) async {
    await shot(
      t,
      'apps_highcontrast_text160_1080p',
      h: Harness(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      ),
      setup: (t, h) async => h.launch(t, 'youtube'),
      keys: [...toAppsRunning, right],
    );
  });
  testWidgets('apps with a broken and a missing icon file, letter tiles', (
    t,
  ) async {
    final apps = [
      for (final a in appsWithIcons())
        switch (a.id) {
          'firefox' => App(
            id: a.id,
            name: a.name,
            kind: a.kind,
            icon: '${iconDir()}/broken.png',
          ),
          'youtube' => App(
            id: a.id,
            name: a.name,
            kind: a.kind,
            icon: '${iconDir()}/not-there.png',
          ),
          _ => a,
        },
    ];
    await shot(
      t,
      'apps_broken_icons_1080p',
      h: Harness(
        mock: MockDaemon(apps: apps, games: gamesWithArt()),
      ),
      setup: (t, h) => loadIcons(t, [
        '${iconDir()}/broken.png',
        '${iconDir()}/not-there.png',
      ]),
      keys: [up, right, right, down, right, right],
    );
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
  testWidgets('settings: show typed text on the on-screen keyboard', (t) async {
    await shot(
      t,
      'settings_osk_text_1080p',
      keys: [...toSettings, down, down, down, down],
    );
  });
  testWidgets('settings, first system entry (Network)', (t) async {
    await shot(
      t,
      'settings_system_1080p',
      keys: [...toSettings, down, down, down, down, down],
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
