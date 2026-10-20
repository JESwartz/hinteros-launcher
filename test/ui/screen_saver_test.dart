// The screen saver: when it starts (only over the launcher), what closes it
// (the first press only closes it), and its settings.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show NavAction, NavPhase;
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/ui/screen_saver.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

import 'package:hinteros_launcher/src/api/mock.dart';

final _saver = find.byKey(const ValueKey('screen-saver'));
Finder _in(String text) =>
    find.descendant(of: _saver, matching: find.text(text));

Harness _harness({
  int minutes = 1,
  ScreenSaverStyle style = ScreenSaverStyle.black,
  bool reduceMotion = false,
}) => Harness(
  settings: LauncherSettings(
    screenSaverMinutes: minutes,
    screenSaverStyle: style,
    reduceMotion: reduceMotion,
  ),
);

void main() {
  test('settings: defaults, JSON round trip, bad values', () {
    const d = LauncherSettings();
    expect(d.screenSaverMinutes, 10);
    expect(d.screenSaverStyle, ScreenSaverStyle.clock);
    const s = LauncherSettings(
      screenSaverMinutes: 30,
      screenSaverStyle: ScreenSaverStyle.logo,
    );
    expect(LauncherSettings.fromJson(s.toJson()), s);
    expect(s.toJson()['screen_saver_style'], 'logo');
    final bad = LauncherSettings.fromJson({
      'screen_saver_minutes': 7,
      'screen_saver_style': 'fish',
    });
    expect(bad.screenSaverMinutes, 10);
    expect(bad.screenSaverStyle, ScreenSaverStyle.clock);
    expect(
      LauncherSettings.fromJson({'screen_saver_minutes': 0}).screenSaverMinutes,
      0,
    );
  });

  test('the press that closes it goes nowhere, its release neither', () {
    final c = ScreenSaverController(
      SettingsController(MemorySettingsStorage()),
    );
    addTearDown(c.dispose);
    c.allowed = true;
    c.show();
    expect(c.showing, true);
    expect(c.input(NavAction.accept, NavPhase.press), true);
    expect(c.showing, false);
    expect(c.input(NavAction.accept, NavPhase.repeat), true);
    expect(c.input(NavAction.accept, NavPhase.release), true);
    expect(c.input(NavAction.accept, NavPhase.press), false);
    expect(c.input(NavAction.down, NavPhase.press), false);
    // Show now: the release of its A does not close it.
    c.show();
    expect(c.input(NavAction.accept, NavPhase.release), true);
    expect(c.showing, true);
    // Not allowed (an app in front): closed, and no wait.
    c.allowed = false;
    expect(c.showing, false);
  });

  testWidgets('it starts after the time without input; input waits again', (
    t,
  ) async {
    setView(t);
    final h = _harness();
    await h.pump(t);
    await t.pump(const Duration(seconds: 40));
    await press(t, [kRight]);
    final focus = focusLabel();
    await t.pump(const Duration(seconds: 40));
    expect(_saver, findsNothing, reason: 'the press made it wait again');
    await t.pump(const Duration(seconds: 21));
    expect(_saver, findsOneWidget);
    // The first press only closes it.
    await press(t, [kRight]);
    expect(_saver, findsNothing);
    expect(focusLabel(), focus);
    // Off: never.
    h.settings.update(h.settings.value.copyWith(screenSaverMinutes: 0));
    await t.pump(const Duration(minutes: 31));
    expect(_saver, findsNothing);
  });

  testWidgets('not over an app; Home closes it and stays where it was', (
    t,
  ) async {
    setView(t);
    final h = _harness();
    await h.pump(t);
    await h.launch(t, 'youtube');
    await t.pump(const Duration(minutes: 2));
    expect(_saver, findsNothing);
    h.mock.pressHome();
    await t.pumpAndSettle();
    await press(t, [kRight]);
    final focus = focusLabel();
    await t.pump(const Duration(minutes: 1));
    expect(_saver, findsOneWidget);
    h.mock.pressHome();
    await t.pumpAndSettle();
    expect(_saver, findsNothing);
    expect(focusLabel(), focus);
  });

  testWidgets('Settings: start after, style, Show now', (t) async {
    setView(t);
    final h = _harness(minutes: 10);
    await h.pump(t);
    await enterSettingsEntry(t, 'screensaver');
    expect(focusLabel(), 'settings-detail-2/after:0');
    expect(find.text('10 minutes'), findsOneWidget);
    // The list opens at 10 minutes; one down is 15.
    await press(t, [kEnter, kDown, kEnter]);
    expect(h.settings.value.screenSaverMinutes, 15);
    expect(find.text('15 minutes'), findsOneWidget);
    await press(t, [kDown]);
    expect(focusLabel(), 'settings-detail-2/style:0');
    await press(t, [kEnter]);
    for (final s in ['Clock', 'Drifting logo', 'Black screen']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    // The list opens on the current style (black); up, then back down.
    await press(t, [kUp, kDown, kEnter]);
    expect(h.settings.value.screenSaverStyle, ScreenSaverStyle.black);
    await press(t, [kDown]);
    expect(focusLabel(), 'settings-detail-2/show:0');
    // A press and its release: it stays up.
    await press(t, [kEnter]);
    expect(_saver, findsOneWidget);
    await press(t, [kDown]);
    expect(_saver, findsNothing);
    expect(focusLabel(), 'settings-detail-2/show:0');
  });

  testWidgets('clock and logo; few frames', (t) async {
    setView(t);
    final h = _harness(style: ScreenSaverStyle.clock);
    await h.pump(t);
    await t.pump(const Duration(minutes: 1));
    expect(_saver, findsOneWidget);
    // The top bar's time, and the date.
    final texts = [
      for (final e
          in find
              .descendant(of: _saver, matching: find.byType(Text))
              .evaluate())
        (e.widget as Text).data!,
    ];
    expect(texts[0], matches(RegExp(r'^\d\d:\d\d$')));
    expect(find.text(texts[0]), findsNWidgets(2));
    expect(texts[1], matches(RegExp(r'^[A-Z][a-z]+day \d{1,2} [A-Z][a-z]+$')));
    // The clock does not animate (it moves each minute): it settles.
    await t.pumpAndSettle();
    await press(t, [kDown]);
    h.settings.update(
      h.settings.value.copyWith(screenSaverStyle: ScreenSaverStyle.logo),
    );
    await t.pump(const Duration(minutes: 1));
    expect(_in('HinterOS'), findsOneWidget);
    // The logo moves one pixel on each axis, eight times a second, always
    // on whole pixels.
    final at = t.getTopLeft(_in('HinterOS'));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.getTopLeft(_in('HinterOS')), at);
    await t.pump(const Duration(milliseconds: 50));
    var next = t.getTopLeft(_in('HinterOS'));
    expect((next.dx - at.dx).abs(), 1);
    expect((next.dy - at.dy).abs(), 1);
    for (var i = 0; i < 40; i++) {
      final before = next;
      await t.pump(const Duration(milliseconds: 125));
      next = t.getTopLeft(_in('HinterOS'));
      expect((next.dx - before.dx).abs(), lessThanOrEqualTo(1));
      expect((next.dy - before.dy).abs(), lessThanOrEqualTo(1));
      expect(next.dx, next.dx.roundToDouble());
      expect(next.dy, next.dy.roundToDouble());
    }
    // With reduce motion it holds still.
    h.settings.update(h.settings.value.copyWith(reduceMotion: true));
    await t.pump();
    final still = t.getTopLeft(_in('HinterOS'));
    await t.pump(const Duration(seconds: 2));
    expect(t.getTopLeft(_in('HinterOS')), still);
    await t.sendKeyEvent(kDown);
    await t.pump();
    expect(_saver, findsNothing);
  });

  testWidgets('the logo steps one physical pixel at any pixel ratio', (
    t,
  ) async {
    setView(t, dpr: 2);
    final h = _harness(style: ScreenSaverStyle.logo);
    await h.pump(t);
    await t.pump(const Duration(minutes: 1));
    final at = t.getTopLeft(_in('HinterOS'));
    await t.pump(const Duration(milliseconds: 125));
    final next = t.getTopLeft(_in('HinterOS'));
    expect((next.dx - at.dx).abs(), 0.5);
    expect((next.dy - at.dy).abs(), 0.5);
    await t.sendKeyEvent(kDown);
    await t.pump();
  });

  testWidgets('Steam: Steam comes forward; the clock when it cannot', (
    t,
  ) async {
    setView(t);
    final h = _harness(style: ScreenSaverStyle.steam);
    await h.pump(t);
    // Steam is not running: the clock.
    await t.pump(const Duration(minutes: 1));
    await t.pump();
    expect(h.mock.steamScreenSavers, 0);
    expect(_saver, findsOneWidget);
    expect(find.textContaining(RegExp(r'^[A-Z][a-z]+day ')), findsOneWidget);
    await press(t, [kDown]);
    expect(_saver, findsNothing);
    // Steam runs (opened, then Home): next time it comes forward instead.
    await h.launch(t, 'steam');
    h.mock.pressHome();
    await t.pumpAndSettle();
    await press(t, [kRight]);
    final focus = focusLabel();
    await t.pump(const Duration(minutes: 1));
    await t.pump();
    expect(h.mock.steamScreenSavers, 1);
    expect(h.data.focusedApp, 'steam');
    expect(_saver, findsNothing);
    // No wait while Steam is in front.
    await t.pump(const Duration(minutes: 5));
    expect(h.mock.steamScreenSavers, 1);
    // The first press brings the launcher back, as it was; then the wait
    // starts again.
    h.mock.endSteamScreenSaver();
    await t.pumpAndSettle();
    expect(h.data.focusedApp, isNull);
    expect(focusLabel(), focus);
    expect(_saver, findsNothing);
    await t.pump(const Duration(minutes: 1));
    await t.pump();
    expect(h.mock.steamScreenSavers, 2);
  });

  testWidgets('Settings: Steam only while it is installed, with its hint', (
    t,
  ) async {
    setView(t);
    final h = _harness(minutes: 10);
    await h.pump(t);
    await enterSettingsEntry(t, 'screensaver');
    await press(t, [kDown]);
    expect(focusLabel(), 'settings-detail-2/style:0');
    await press(t, [kEnter]);
    expect(find.text('Steam'), findsWidgets);
    // The list opens on the current style (black); Steam is next.
    await press(t, [kDown, kEnter]);
    expect(h.settings.value.screenSaverStyle, ScreenSaverStyle.steam);
    expect(find.textContaining('Steam: Settings > Power'), findsOneWidget);

    // Without Steam: no Steam choice.
    final n = Harness(
      mock: MockDaemon(
        apps: appsWithIcons().where((a) => a.id != 'steam').toList(),
        games: gamesWithArt(),
      ),
    );
    await n.pump(t);
    await enterSettingsEntry(t, 'screensaver');
    await press(t, [kDown, kEnter]);
    expect(find.text('Steam'), findsNothing);
  });
}
