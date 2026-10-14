import 'package:flutter/widgets.dart' show ValueKey;
// The Store screens and the Games tab's "Install Steam" on the real
// repositories (DaemonStore and friends) over the mock daemon: install with
// the vendor terms and the job's progress, remove with data deletion, and what
// the user is told for each answer of the service.
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/ui/app_icon_view.dart';
import 'package:hinteros_launcher/src/ui/settings_screen.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness harness({
  Set<String> installed = const {'steam'},
  api.AvailableUpdate? update,
}) {
  final mock = api.MockDaemon(
    apps: appsWithIcons(),
    games: gamesWithArt(),
    now: fixedNow,
  );
  mock.system.installedApps
    ..clear()
    ..addAll(installed);
  // The daemon leaves Steam out of apps.list while it is not installed.
  if (!installed.contains('steam')) {
    mock.apps.removeWhere((a) => a.id == 'steam');
  }
  mock.system.nextUpdate = update;
  return Harness(
    mock: mock,
    realServices: daemonSystemServices(mock, now: fixedNow),
  );
}

/// The startup update check holds the system job slot: end it.
Future<void> endStartupCheck(WidgetTester t, Harness h) async {
  await t.pump();
  final id = h.mock.system.runningJobId;
  if (id != null) h.mock.system.finishJob(id);
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

/// What reached the system service for the apps (not the startup update check).
List<String> appsLog(Harness h) => [
  for (final l in h.mock.system.log)
    if (l.startsWith('apps.')) l,
];

bool buttonEnabled(WidgetTester t, String label) =>
    t.widget<HButton>(find.widgetWithText(HButton, label)).enabled;

/// The Store's detail page of an app: category [cat] (0 All, 1 Games,
/// 2 Video, 3 Utilities, 4 Installed), then [more] right and [rows] down in
/// the two-column grid (apps by name).
Future<void> openApp(
  WidgetTester t,
  int cat, {
  int more = 0,
  int rows = 0,
}) async {
  await openStore(t);
  await press(t, [
    ...List.filled(cat, kDown),
    kRight,
    ...List.filled(more, kRight),
    ...List.filled(rows, kDown),
  ]);
  await press(t, [kEnter]);
}

/// Pages through the terms until "Accept and install" is on.
Future<void> readTerms(WidgetTester t) async {
  for (var i = 0; i < 60 && !buttonEnabled(t, 'Accept and install'); i++) {
    await press(t, [kPageDown]);
  }
}

/// The Steam page (Games: Moonlight, RetroArch / Steam).
Future<void> openSteam(WidgetTester t) => openApp(t, 1, rows: 1);

void main() {
  group('install', () {
    testWidgets('Steam: confirm, terms read in full, the job, then installed', (
      t,
    ) async {
      setView(t);
      final h = harness(installed: {});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openSteam(t);
      expect(find.text('Not installed.'), findsOneWidget);
      await press(t, [kEnter]); // Install
      expect(find.text('Install Steam for this profile?'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Continue
      expect(find.text('Terms for Steam'), findsOneWidget);
      expect(buttonEnabled(t, 'Accept and install'), isFalse);
      await readTerms(t);
      expect(find.textContaining('END OF PLACEHOLDER TERMS'), findsOneWidget);
      expect(appsLog(h), isNot(contains('apps.install:steam')));
      await press(t, [kDown, kRight, kEnter]); // Accept and install
      // system.apps.install went out with the version that was read.
      expect(appsLog(h), ['apps.install:steam']);
      expect(h.mock.system.acceptances, ['steam=2026-09-10']);
      // The progress screen follows the job events.
      expect(find.text('Installing Steam'), findsOneWidget);
      final job = h.mock.system.runningJobId!;
      h.mock.system.progressJob(
        job,
        api.Stage.downloading,
        percent: 40,
        bytesTotal: 1000 << 20,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('40%'), findsWidgets);
      expect(find.textContaining('400 MB of 1000 MB'), findsOneWidget);
      h.mock.system.finishJob(job);
      await t.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      await press(t, [kEnter]); // Close
      // store_changed refreshed the listing: Steam is installed now.
      expect(h.mock.system.installedApps, ['steam']);
      expect(find.text('Installed.'), findsOneWidget);
    });

    testWidgets('a stale revision is retried once, silently', (t) async {
      setView(t);
      final h = harness(installed: {});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openApp(t, 1); // Moonlight, free
      h.mock.system.failNext = const api.ApiException(
        api.ApiErrorCode.stateConflict,
        'state.json changed since settings.get',
        {'reason': 'revision'},
      );
      await press(t, [kEnter, kRight, kEnter]); // Install, confirm
      expect(find.text('Installing Moonlight'), findsOneWidget);
      expect(appsLog(h), ['apps.install:moonlight', 'apps.install:moonlight']);
      expect(find.text("That didn't work"), findsNothing);
    });

    testWidgets('terms_required with a newer version shows the terms again', (
      t,
    ) async {
      setView(t);
      final h = harness(installed: {});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openSteam(t);
      await press(t, [kEnter, kRight, kEnter]); // Install, Continue
      await readTerms(t);
      // While the user read, the box's catalog got a newer terms version.
      h.mock.system.catalog = [
        for (final a in h.mock.system.catalog)
          a.id == 'steam'
              ? api.StoreApp.fromJson({
                  ...a.toJson(),
                  'terms': {...a.terms!.toJson(), 'version': '2026-10-01'},
                })
              : a,
      ];
      await press(t, [kDown, kRight, kEnter]); // Accept and install
      expect(appsLog(h), [
        'apps.install:steam',
      ], reason: 'the service said no to the first');
      expect(h.mock.system.acceptances, isEmpty);
      // The named terms come up again, with the new version recorded below.
      expect(find.text('Terms for Steam'), findsOneWidget);
      expect(buttonEnabled(t, 'Accept and install'), isFalse);
      await readTerms(t);
      await press(t, [kDown, kRight, kEnter]);
      expect(appsLog(h), ['apps.install:steam', 'apps.install:steam']);
      expect(h.mock.system.acceptances, ['steam=2026-10-01']);
      expect(find.text('Installing Steam'), findsOneWidget);
    });

    testWidgets('app_conflict says which app is in the way', (t) async {
      setView(t);
      final h = harness(installed: {'jellyfin'});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openApp(t, 2, rows: 1); // Video: Crunchyroll, Jellyfin / Kodi, Plex
      expect(find.text('Kodi'), findsWidgets);
      expect(
        find.textContaining("Can't be installed with Jellyfin"),
        findsOneWidget,
      );
      await press(t, [kEnter, kRight, kEnter]); // Install, confirm
      expect(find.text("Kodi can't be installed"), findsOneWidget);
      expect(
        find.textContaining(
          "Kodi can't be installed with Jellyfin. Remove Jellyfin first.",
        ),
        findsOneWidget,
      );
      expect(h.mock.system.runningJobId, isNull);
      await press(t, [kEnter]);
      expect(find.text("Kodi can't be installed"), findsNothing);
    });

    testWidgets('not enough disk space asks to free some', (t) async {
      setView(t);
      final h = harness(installed: {});
      h.mock.system.freeDiskMib = 100;
      await h.pump(t);
      await endStartupCheck(t, h);
      await openApp(t, 1, more: 1); // RetroArch (and its cores)
      await press(t, [kEnter, kRight, kEnter]);
      expect(find.text('Not enough space'), findsOneWidget);
      expect(find.textContaining('about 620 MB'), findsOneWidget);
      expect(find.textContaining('100 MB free'), findsOneWidget);
      expect(
        find.textContaining('Remove an app or delete files'),
        findsOneWidget,
      );
      expect(h.mock.system.runningJobId, isNull);
    });

    testWidgets('the card says Installing... while the job runs', (t) async {
      setView(t);
      final h = harness(installed: {});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openApp(t, 1); // Moonlight
      await press(t, [kEnter, kRight, kEnter]);
      expect(find.text('Installing Moonlight'), findsOneWidget);
      // Back leaves the page; the card says Installing... meanwhile.
      await press(t, [kEscape]);
      expect(find.byKey(const ValueKey('job-indicator')), findsOneWidget);
      expect(find.textContaining('Installing...'), findsWidgets);
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('job-indicator')), findsNothing);
      await press(t, [kEscape]); // detail page back to the list
      expect(find.text('Installed'), findsWidgets);
    });
  });

  group('remove', () {
    testWidgets('with data: two confirmations, then delete_data goes out', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await openSteam(t);
      expect(find.text('Installed.'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Remove
      expect(find.text('Remove Steam from this profile?'), findsOneWidget);
      await press(t, [kEnter, kDown, kRight, kEnter]); // tick, Remove
      expect(find.text('Delete all data of Steam?'), findsOneWidget);
      expect(find.textContaining('Games this profile installed'), findsWidgets);
      expect(appsLog(h), isEmpty);
      await press(t, [kRight, kEnter]); // Delete data and remove
      expect(appsLog(h), ['apps.remove:steam:data=true']);
      expect(find.text('Removing Steam'), findsOneWidget);
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      await press(t, [kEnter]);
      expect(h.mock.system.installedApps, isEmpty);
      expect(find.text('Not installed.'), findsOneWidget);
    });

    testWidgets('without data: one confirmation, delete_data false', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await openSteam(t);
      await press(t, [kRight, kEnter, kDown, kRight, kEnter]);
      expect(find.textContaining('Delete all data'), findsNothing);
      expect(appsLog(h), ['apps.remove:steam:data=false']);
    });

    testWidgets('a running app is closed first', (t) async {
      setView(t);
      final h = harness(installed: {'jellyfin'});
      await h.pump(t);
      await endStartupCheck(t, h);
      await h.launch(t, 'jellyfin');
      expect(h.mock.running.map((a) => a.id), ['jellyfin']);
      h.mock.pressHome();
      await t.pumpAndSettle();
      await openApp(t, 2, more: 1); // Video: Jellyfin
      await press(t, [kRight, kEnter]); // Remove
      expect(find.textContaining('Jellyfin closes first'), findsOneWidget);
      await press(t, [kDown, kRight, kEnter]);
      expect(h.mock.running, isEmpty);
      expect(appsLog(h), ['apps.remove:jellyfin:data=false']);
    });

    testWidgets('an app another one needs says which', (t) async {
      setView(t);
      final h = harness(installed: {'retroarch', 'retroarch-cores'});
      await h.pump(t);
      await endStartupCheck(t, h);
      // Utilities: Emulator cores, Firefox? (Firefox is not installed here.)
      await openApp(t, 3);
      expect(find.text('Emulator cores'), findsWidgets);
      await press(t, [kRight, kEnter, kDown, kRight, kEnter]);
      expect(find.text("Emulator cores can't be removed"), findsOneWidget);
      expect(
        find.textContaining('RetroArch needs Emulator cores'),
        findsOneWidget,
      );
    });
  });

  group('states of installed apps', () {
    testWidgets('a retired app says so and can be removed', (t) async {
      setView(t);
      final h = harness(installed: {'old-player'});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openApp(t, 4); // Installed
      expect(find.text('Old player'), findsWidgets);
      expect(find.text('Installed, no longer offered'), findsOneWidget);
      expect(
        find.textContaining(
          'This app is retired. Replaced by the Video player. It still works',
        ),
        findsOneWidget,
      );
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Install'), findsNothing);
    });

    testWidgets('an app the next update takes away says so', (t) async {
      setView(t);
      final h = harness(installed: {'mystery'});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openApp(t, 4); // Installed
      expect(find.text('Installed, going away'), findsOneWidget);
      expect(
        find.textContaining('The next update removes this app'),
        findsOneWidget,
      );
      expect(find.text('Remove'), findsOneWidget);
    });
  });

  group('after the next update', () {
    testWidgets('the Store names the apps, Updates names what goes away', (
      t,
    ) async {
      setView(t);
      final h = harness(
        installed: {'old-player'},
        update: const api.AvailableUpdate(
          rev: '9a8b7c6d5e4f30211a2b3c4d5e6f708192a3b4c5',
          date: 1791300000,
          summary: 'New apps.',
          signer: 'release@hinteros',
          security: null,
          commits: 2,
          newApps: [api.CatalogApp(id: 'new-app', name: 'New player')],
          removedApps: [
            api.RemovedApp(
              id: 'old-player',
              name: 'Old player',
              reason: 'Replaced by the Video player.',
            ),
          ],
        ),
      );
      await h.pump(t);
      await endStartupCheck(t, h);
      // The update banner sits between the tab bar and the content on Home
      // only; the Store tab is one tab right of Apps.
      await press(t, [kUp, kUp, kRight, kRight, kRight]);
      expect(
        find.text('More apps come with the next update: New player.'),
        findsOneWidget,
      );
      await press(t, [
        kRight, // Settings
        kDown,
        ...List.filled(settingsEntryIds.indexOf('updates'), kDown),
        kRight,
      ]);
      expect(
        find.textContaining(
          'This update removes Old player (Replaced by the Video player.)',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('New in the Store: New player'),
        findsOneWidget,
      );
    });
  });

  group('Games tab', () {
    testWidgets('Install Steam goes through the Store: terms, job, library', (
      t,
    ) async {
      setView(t);
      final h = harness(installed: {});
      await h.pump(t);
      await endStartupCheck(t, h);
      await openTab(t, 1);
      expect(find.text('Steam is not installed'), findsOneWidget);
      expect(find.text('Install Steam'), findsOneWidget);
      await press(t, [kEnter]);
      expect(find.text('Install Steam for this profile?'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Continue
      await readTerms(t);
      await press(t, [kDown, kRight, kEnter]);
      expect(appsLog(h), ['apps.install:steam']);
      expect(h.mock.system.acceptances, ['steam=2026-09-10']);
      expect(find.text('Installing Steam'), findsOneWidget);
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Close
      // The prompt is gone: Steam is installed.
      expect(find.text('Steam is not installed'), findsNothing);
    });

    testWidgets(
      'the prompt follows apps.list, even while the Store is unreachable',
      (t) async {
        setView(t);
        final h = harness(installed: {});
        h.mock.system.unavailable = api.SystemUnavailableDataReason.down;
        await h.pump(t);
        await openTab(t, 1);
        expect(find.text('Steam is not installed'), findsOneWidget);
        await press(t, [kEnter]);
        expect(find.text("The Store isn't available"), findsOneWidget);
      },
    );

    testWidgets('no prompt before apps.list has arrived', (t) async {
      setView(t);
      final h = harness(installed: {});
      await t.pumpWidget(h.app);
      expect(find.text('Steam is not installed'), findsNothing);
    });
  });

  group('session restart', () {
    Future<void> toRestartOffer(WidgetTester t, Harness h) async {
      h.mock.system.nextUpdate = const api.AvailableUpdate(
        rev: '9a8b7c6d5e4f30211a2b3c4d5e6f708192a3b4c5',
        date: 1791300000,
        summary: 'Fixes a flaw in the web engine.',
        signer: 'release@hinteros',
        security: api.Severity.high,
        commits: 3,
        newApps: null,
        removedApps: null,
      );
      await h.pump(t);
      await endStartupCheck(t, h);
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      h.mock.system.restartNext = true;
      await press(t, [kRight, kEnter]); // Update now
      await enterPin(t, '2468'); // the admin PIN
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      expect(find.text('Restart session'), findsOneWidget);
    }

    testWidgets('Restart session calls session.restart', (t) async {
      setView(t);
      final h = harness();
      await toRestartOffer(t, h);
      await t.sendKeyEvent(kEnter);
      await t.pump();
      await t.pump();
      expect(h.mock.sessionRestarts, 1);
      expect(find.text('Restarting the session…'), findsOneWidget);
    });

    testWidgets('a desktop session says it cannot be restarted from here', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.mock.sessionRestartAvailable = false;
      await toRestartOffer(t, h);
      await press(t, [kEnter]);
      expect(h.mock.sessionRestarts, 0);
      expect(find.textContaining('not a TV session'), findsOneWidget);
      expect(
        find.text('Restart session'),
        findsOneWidget,
        reason: 'still offered',
      );
    });
  });

  group('session API 0.9', () {
    testWidgets('a catalog icon (icon.path) replaces the letter tile', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await openStore(t);
      final before = find.byType(AppIconImage).evaluate().length;
      final path = '${iconDir()}/jellyfin.png';
      h.mock.system.setStoreIcon('moonlight', path); // store_changed
      await t.pumpAndSettle();
      await loadIcons(t, [path]);
      await t.pumpAndSettle();
      expect(find.byType(AppIconImage).evaluate().length, before + 1);
      // Its detail page shows it too.
      await press(t, [kRight, kDown, kEnter]);
      expect(find.text('Moonlight'), findsWidgets);
      expect(find.byType(AppIconImage).evaluate().length, greaterThan(before));
    });

    testWidgets('an app without icon.path keeps the letter', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await openStore(t);
      expect(find.text('M'), findsWidgets);
    });

    testWidgets(
      'apps_changed after the install job puts the app on Home and Apps',
      (t) async {
        setView(t);
        final h = harness(installed: {});
        await h.pump(t);
        await endStartupCheck(t, h);
        expect(h.data.appList!.any((a) => a.id == 'steam'), isFalse);
        await openTab(t, 1);
        await press(t, [kEnter, kRight, kEnter]); // Install Steam, Continue
        await readTerms(t);
        await press(t, [kDown, kRight, kEnter]);
        h.mock.system.finishJob(h.mock.system.runningJobId!);
        await t.pumpAndSettle();
        await press(t, [kEnter]); // Close
        expect(h.data.appList!.any((a) => a.id == 'steam'), isTrue);
        await press(t, [kUp, kLeft, kDown]); // Games to Home
        expect(find.text('Steam'), findsWidgets);
        expect(find.text('Steam is not installed'), findsNothing);
      },
    );

    testWidgets('removing Steam takes it off Home and shows the prompt again', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await openSteam(t);
      await press(t, [kRight, kEnter, kDown, kRight, kEnter]); // Remove
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      expect(h.data.appList!.any((a) => a.id == 'steam'), isFalse);
      await press(t, [kEnter]);
      await press(t, [kEscape, kEscape, kEscape]); // back out to Home
      await openTab(t, 1);
      expect(find.text('Steam is not installed'), findsOneWidget);
    });
  });
}
