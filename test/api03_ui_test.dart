import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/ui/cards.dart';

import 'support/harness.dart';

/// What API 0.3 added, through the UI: games from games.list with install
/// states, closing running apps, and Steam's attention banner.
void main() {
  const up = LogicalKeyboardKey.arrowUp;
  const down = LogicalKeyboardKey.arrowDown;
  const right = LogicalKeyboardKey.arrowRight;
  const enter = LogicalKeyboardKey.enter;
  const escape = LogicalKeyboardKey.escape;
  const y = LogicalKeyboardKey.keyY;

  Future<void> keys(WidgetTester t, List<LogicalKeyboardKey> ks) async {
    for (final k in ks) {
      await t.sendKeyEvent(k);
      await t.pumpAndSettle();
    }
  }

  // Up to the tab bar, to Games, into the grid (first cover).
  const toGames = [up, right, down];

  group('games', () {
    testWidgets('the grid shows games.list with install-state badges', (
      t,
    ) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await keys(t, toGames);
      expect(find.text('Balatro'), findsOneWidget);
      expect(find.text('Updating'), findsOneWidget);
      expect(find.text('Update required'), findsOneWidget);
      // Sorted like the daemon sends them; Portal 2 is the ninth.
      expect(focusLabel(), 'games/r0:0');
    });

    testWidgets('an installed game launches by Steam URL', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await keys(t, [...toGames, right, right, down]); // r1:2, Portal 2
      await keys(t, [enter]);
      expect(h.mock.running.map((a) => a.id), ['steam-620']);
      expect(h.mock.running.single.name, 'Portal 2');
      expect(find.text('Running'), findsOneWidget);
    });

    testWidgets('a game that needs an update is explained, not started', (
      t,
    ) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await keys(t, [...toGames, down, enter]); // r1:0, Hades
      expect(h.mock.running, isEmpty);
      expect(find.textContaining('needs an update first'), findsOneWidget);
    });

    testWidgets('games_changed refreshes the grid', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await keys(t, toGames);
      expect(find.text('Updating'), findsOneWidget);
      h.mock.toggleFirstUpdate(); // Factorio finishes
      await t.pumpAndSettle();
      expect(find.text('Updating'), findsNothing);
    });

    testWidgets('a game running shows on Continue with its name', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await h.mock.appsLaunch(
        const AppsLaunchParams(url: 'steam://rungameid/620'),
      );
      await t.pumpAndSettle();
      expect(find.text('Portal 2'), findsWidgets);
      await keys(t, [up]);
      expect(focusLabel(), 'home/continue:0');
      await keys(t, [enter]); // focuses it (it is not an apps.list entry)
      expect(h.mock.running.single.id, 'steam-620');
    });
  });

  group('close', () {
    testWidgets('Back asks first; Cancel keeps the app', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await h.launch(t, 'jellyfin');
      await keys(t, [up]);
      expect(focusLabel(), 'home/continue:0');
      await keys(t, [escape]);
      expect(find.text('Close Jellyfin?'), findsOneWidget);
      expect(focusLabel(), 'dialog/buttons:0', reason: 'Cancel is focused');
      // Nothing behind the dialog moves.
      await keys(t, [down, down]);
      expect(focusLabel(), 'dialog/buttons:0');
      await keys(t, [enter]);
      expect(find.text('Close Jellyfin?'), findsNothing);
      expect(h.mock.running.map((a) => a.id), ['jellyfin']);
      expect(focusLabel(), 'home/continue:0');
      // Back cancels too.
      await keys(t, [escape, escape]);
      expect(find.text('Close Jellyfin?'), findsNothing);
      expect(h.mock.running, hasLength(1));
    });

    testWidgets('confirming closes the app; Continue and badges update', (
      t,
    ) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await h.launch(t, 'jellyfin');
      final seen = <SessionEvent>[];
      h.mock.events.listen(seen.add);
      await keys(t, [up, escape, right, enter]);
      expect(h.mock.running, isEmpty);
      expect(find.text('Close Jellyfin?'), findsNothing);
      expect(find.text('Running'), findsNothing);
      expect(seen.whereType<AppExitedEvent>().single.reason, ExitReason.closed);
      expect(focusLabel(), startsWith('home/'));
    });

    testWidgets('input_nav back works like the key', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await h.launch(t, 'youtube');
      await h.launch(t, 'steam'); // Steam now has focus; Home gives it back
      h.mock.pressHome();
      await t.pumpAndSettle();
      h.mock.emitNav(NavAction.back); // on Continue: running apps first
      await t.pumpAndSettle();
      expect(find.textContaining('Close '), findsOneWidget);
    });

    testWidgets('Y no longer closes a running app', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await h.launch(t, 'jellyfin');
      await keys(t, [up, y]);
      expect(find.text('Close Jellyfin?'), findsNothing);
    });

    testWidgets('nothing happens on an app that is not running', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await keys(t, [escape]);
      expect(find.textContaining('Close '), findsNothing);
    });

    testWidgets('the dialog goes away if the app ends meanwhile', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await h.launch(t, 'jellyfin');
      await keys(t, [up, escape]);
      expect(find.text('Close Jellyfin?'), findsOneWidget);
      h.mock.simulateExit('jellyfin');
      await t.pumpAndSettle();
      expect(find.text('Close Jellyfin?'), findsNothing);
    });

    testWidgets('a running game can be closed from the Games grid', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      await keys(t, [...toGames, right, right, down, enter]); // Portal 2
      expect(h.mock.running, hasLength(1));
      h.mock.pressHome();
      await t.pumpAndSettle();
      // Home is not built while Games shows, so it comes back on apps.
      await keys(t, [up, up, right, down]);
      expect(focusLabel(), 'games/r1:2');
      await keys(t, [escape]);
      expect(find.text('Close Portal 2?'), findsOneWidget);
      await keys(t, [right, enter]);
      expect(h.mock.running, isEmpty);
    });
  });

  group('Steam attention', () {
    const guard = SteamWindow(window: 1, title: 'Steam Guard', pid: 2412);

    testWidgets('the banner shows, opens Steam and clears', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      expect(find.textContaining('Steam needs your attention'), findsNothing);
      h.mock.setSteamAttention(const [guard]);
      await t.pumpAndSettle();
      expect(
        find.text('Steam needs your attention: Steam Guard'),
        findsOneWidget,
      );
      // The banner is between the tab bar and the content.
      await keys(t, [up]);
      expect(focusLabel(), 'banner/banner:0');
      await keys(t, [up]);
      expect(focusLabel(), 'tabs/tabs:0');
      await keys(t, [down, enter]);
      expect(h.mock.running.single.id, 'steam');
      expect(h.mock.running.single.source, AppSource.steamClient);
      expect(find.textContaining('Steam needs your attention'), findsNothing);
      expect(h.mock.attention, isEmpty);
    });

    testWidgets('an empty list clears it, focus returns to the content', (
      t,
    ) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      h.mock.setSteamAttention(const [guard]);
      await t.pumpAndSettle();
      await keys(t, [up]);
      expect(focusLabel(), 'banner/banner:0');
      h.mock.setSteamAttention(const []);
      await t.pumpAndSettle();
      expect(find.textContaining('Steam needs your attention'), findsNothing);
      expect(focusLabel(), startsWith('home/'));
    });

    testWidgets('is queried on connect', (t) async {
      setView(t);
      final mock = MockDaemon(games: gamesWithArt());
      mock.setSteamAttention(const [guard]);
      final h = Harness(mock: mock);
      await h.pump(t);
      expect(find.textContaining('Steam Guard'), findsOneWidget);
    });

    testWidgets('X opens Steam too; several windows are counted', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      h.mock.setSteamAttention(const [
        guard,
        SteamWindow(window: 2, title: 'Updates'),
      ]);
      await t.pumpAndSettle();
      expect(find.textContaining('(and 1 more)'), findsOneWidget);
      await keys(t, [LogicalKeyboardKey.keyX]);
      expect(h.mock.running.single.id, 'steam');
    });
  });

  group('badges', () {
    for (final scale in [1.0, 1.2, 1.4, 1.6]) {
      testWidgets('install badges fit narrow Home covers at text ${scale}x', (
        t,
      ) async {
        setView(t);
        final h = Harness(settings: LauncherSettings(textScale: scale));
        await h.pump(t);
        // Whole words, two lines on narrow covers, never cut off.
        for (final label in ['Update\nrequired', 'Updating']) {
          final badge = find.text(label);
          expect(badge, findsOneWidget, reason: label);
          final card = find.ancestor(
            of: badge,
            matching: find.byType(GameCard),
          );
          final cover = t.getRect(card).topLeft & Size(176, 176 * 3 / 2);
          // Every line shows (no maxLines cut-off).
          expect(
            t.renderObject<RenderParagraph>(badge).didExceedMaxLines,
            isFalse,
            reason: label,
          );
          final r = t.getRect(badge);
          expect(
            cover.inflate(0.5).contains(r.topLeft) &&
                cover.inflate(0.5).contains(r.bottomRight),
            isTrue,
            reason: '$label at $scale: $r not inside $cover',
          );
        }
      });
    }
  });
}
