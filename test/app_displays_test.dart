import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';

import 'support/harness.dart';
import 'support/nav_helpers.dart';

/// Session API 0.18: each app runs on a display of its own. With all of them
/// in use the launcher asks which app to close (`no_app_display`); the number
/// is a setting ("Apps open at once") that applies after a session restart.
void main() {
  /// Jellyfin and YouTube hold both of the mock's two app displays.
  Future<Harness> full(WidgetTester t) async {
    setView(t);
    final h = Harness();
    h.mock.appDisplays = 2;
    await h.pump(t);
    await h.launch(t, 'jellyfin-desktop');
    await h.launch(t, 'youtube');
    h.mock.pressHome();
    await t.pumpAndSettle();
    return h;
  }

  List<String> running(Harness h) => [for (final a in h.mock.running) a.id];

  testWidgets(
    'all displays in use: pick an app, it closes, the new one opens',
    (t) async {
      final h = await full(t);
      final launch = h.data.launchApp('crunchyroll', 'Crunchyroll');
      await t.pumpAndSettle();
      expect(find.text('Close an app to open Crunchyroll'), findsOneWidget);
      expect(find.text('Jellyfin'), findsWidgets);
      expect(find.text('YouTube'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(running(h), ['jellyfin-desktop', 'youtube']);
      // Down to YouTube, A.
      await press(t, [kDown, kEnter]);
      await launch;
      await t.pumpAndSettle();
      expect(find.text('Close an app to open Crunchyroll'), findsNothing);
      expect(running(h), ['jellyfin-desktop', 'crunchyroll']);
      expect(h.data.focusedApp, 'crunchyroll');
    },
  );

  testWidgets('all displays in use: Cancel closes nothing and opens nothing', (
    t,
  ) async {
    final h = await full(t);
    final launch = h.data.launchApp('crunchyroll', 'Crunchyroll');
    await t.pumpAndSettle();
    await press(t, [kDown, kDown, kEnter]);
    await launch;
    await t.pumpAndSettle();
    expect(find.text('Close an app to open Crunchyroll'), findsNothing);
    expect(running(h), ['jellyfin-desktop', 'youtube']);
    expect(h.data.launching, isNull);

    // Back works like Cancel.
    final again = h.data.launchApp('crunchyroll', 'Crunchyroll');
    await t.pumpAndSettle();
    await press(t, [kEscape]);
    await again;
    expect(running(h), ['jellyfin-desktop', 'youtube']);
  });

  testWidgets('a running app is only focused; Steam needs no display', (
    t,
  ) async {
    final h = await full(t);
    await h.data.launchApp('jellyfin-desktop', 'Jellyfin');
    await t.pumpAndSettle();
    expect(find.textContaining('Close an app'), findsNothing);
    await h.data.launchApp('steam', 'Steam');
    await t.pumpAndSettle();
    expect(find.textContaining('Close an app'), findsNothing);
    expect(running(h), ['jellyfin-desktop', 'youtube', 'steam']);
  });

  group('Settings: Apps open at once', () {
    Harness daemonHarness() {
      final mock = MockDaemon(
        apps: appsWithIcons(),
        games: gamesWithArt(),
        now: fixedNow,
      );
      return Harness(mock: mock, realServices: daemonSystemServices(mock));
    }

    Future<void> open(WidgetTester t, Harness h) async {
      setView(t);
      await h.pump(t);
      await t.pump();
      final job = h.mock.system.runningJobId;
      if (job != null) h.mock.system.finishJob(job);
      await t.pumpAndSettle();
      await enterSettingsEntry(t, 'app_displays');
    }

    testWidgets('a new number is saved; restart later or now', (t) async {
      final h = daemonHarness();
      await open(t, h);
      expect(find.text('4 apps'), findsOneWidget);
      // Open the list at 4, down to 6.
      await press(t, [kEnter, kDown, kDown, kEnter]);
      expect(h.mock.appDisplaysSetting, 6);
      expect(find.text('Restart the session now?'), findsOneWidget);
      expect(find.text('All running apps close.'), findsOneWidget);
      await press(t, [kEscape]);
      expect(find.text('6 apps'), findsOneWidget);
      expect(find.text('Restart the session to apply this.'), findsOneWidget);
      expect(h.mock.sessionRestarts, 0);
      // The button restarts the session.
      await press(t, [kDown]);
      await t.sendKeyEvent(kEnter);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(seconds: 1));
      expect(h.mock.sessionRestarts, 1);
    });

    testWidgets('back to what the session has: nothing to restart', (t) async {
      final h = daemonHarness();
      h.mock.appDisplaysSetting = 6;
      await open(t, h);
      expect(find.text('Restart the session to apply this.'), findsOneWidget);
      // The list opens at 6: up to 4.
      await press(t, [kEnter, kUp, kUp, kEnter]);
      expect(h.mock.appDisplaysSetting, 4);
      expect(find.text('Restart the session now?'), findsNothing);
      expect(find.text('Restart the session to apply this.'), findsNothing);
    });

    testWidgets('no app displays on this box', (t) async {
      final h = daemonHarness();
      h.mock.appDisplays = null;
      await openSettingsAt(t, h);
      expect(find.text('Not available on this box.'), findsOneWidget);
    });
  });

  test('the mock refuses a launch only for apps that need a display', () async {
    final mock = MockDaemon(apps: appsWithIcons());
    mock.appDisplays = 1;
    await mock.rpc('hello', {
      'api_version': apiVersion,
      'client': {'name': 'hinteros-launcher', 'version': '0'},
    });
    await mock.appsLaunch(const AppsLaunchParams(id: 'jellyfin-desktop'));
    await mock.appsLaunch(const AppsLaunchParams(url: 'steam://rungameid/620'));
    final err = await mock
        .appsLaunch(const AppsLaunchParams(id: 'youtube'))
        .then<ApiException?>(
          (_) => null,
          onError: (Object e) => e as ApiException,
        );
    expect(err?.code, ApiErrorCode.noAppDisplay);
    final data = NoAppDisplayData.fromJson(
      (err!.data! as Map).cast<String, dynamic>(),
    );
    expect([for (final a in data.apps) a.id], ['jellyfin-desktop']);
    expect(
      (await mock.appsDisplaysSet(const AppsDisplaysSetParams(count: 3)))
          .active,
      1,
    );
  });
}

/// Settings, the System group, without entering a section (it may have no
/// rows).
Future<void> openSettingsAt(WidgetTester t, Harness h) async {
  setView(t);
  await h.pump(t);
  await t.pump();
  final job = h.mock.system.runningJobId;
  if (job != null) h.mock.system.finishJob(job);
  await t.pumpAndSettle();
  await openSettingsEntry(t, 'app_displays');
  await t.pumpAndSettle();
}
