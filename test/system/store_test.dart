import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show App, AppKind;
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness harness() => Harness(
  services: MockSystemServices(iconDir: iconDir(), now: fixedNow),
);

bool buttonEnabled(WidgetTester t, String label) =>
    t.widget<HButton>(find.widgetWithText(HButton, label)).enabled;

/// Store, category [cat] (0 All, 1 Games, 2 Video, ...), first app.
Future<void> openApp(
  WidgetTester t,
  int cat, [
  int more = 0,
  int rows = 0,
]) async {
  await openStore(t);
  await press(t, [
    ...List.filled(cat, kDown),
    kRight,
    ...List.filled(more, kRight),
    ...List.filled(rows, kDown),
  ]);
  await press(t, [kEnter]);
}

void main() {
  testWidgets('Store tab: categories, apps, installed marks, update note', (
    t,
  ) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openStore(t);
    expect(focusLabel(), 'store-cats/c0:0');
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Steam'), findsOneWidget);
    expect(find.text('Installed'), findsWidgets);
    expect(find.byKey(const ValueKey('more-apps')), findsOneWidget);
    expect(find.text('More apps come with the next update.'), findsOneWidget);
    await press(t, [kDown]);
    expect(find.text('Moonlight'), findsOneWidget, reason: 'Games category');
    await press(t, [kRight]);
    expect(focusLabel(), 'store-grid/r0:0');
    await press(t, [kLeft]);
    expect(focusLabel(), 'store-cats/c1:0');
  });

  testWidgets('the Server tab comes after the Store', (t) async {
    setView(t);
    await harness().pump(t);
    await openServer(t);
    expect(focusLabel(), 'server/s0:0');
  });

  testWidgets('the update note is gone when no catalog change is pending', (
    t,
  ) async {
    setView(t);
    final h = harness();
    h.services.mockStore.moreAfterUpdate = false;
    await h.pump(t);
    await openStore(t);
    expect(find.byKey(const ValueKey('more-apps')), findsNothing);
  });

  testWidgets('RetroArch: the confirm names what comes along and the total', (
    t,
  ) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openStore(t);
    await press(t, [kDown, kRight, kDown, kEnter]); // grid row 1: RetroArch
    expect(find.text('RetroArch'), findsWidgets);
    await press(t, [kEnter]); // Install
    expect(find.text('Install RetroArch for this profile?'), findsOneWidget);
    expect(find.textContaining('Emulator cores (400 MB)'), findsOneWidget);
    expect(find.textContaining('about 620 MB'), findsOneWidget);
    await press(t, [kRight, kEnter]); // Install
    expect(h.services.mockStore.log, ['install:retroarch:']);
  });

  group('vendor terms', () {
    Future<void> toTerms(WidgetTester t, Harness h) async {
      h.services.mockStore.setInstalled({'plex-htpc', 'jellyfin'});
      await h.pump(t);
      await openApp(t, 1, 1); // Steam (Moonlight comes first)
      await press(t, [kEnter]); // Install
      expect(find.text('Install Steam for this profile?'), findsOneWidget);
      expect(find.textContaining('Read and accept it next'), findsOneWidget);
      expect(find.textContaining('Steam has full access'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Continue
      expect(find.text('Terms for Steam'), findsOneWidget);
    }

    testWidgets('Accept and install stays off until the end is read', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await toTerms(t, h);
      expect(buttonEnabled(t, 'Accept and install'), isFalse);
      expect(find.textContaining('PLACEHOLDER TERMS'), findsOneWidget);
      // Down scrolls the text, it does not reach the buttons.
      await press(t, [kDown]);
      expect(focusLabel(), endsWith('/text:0'));
      expect(buttonEnabled(t, 'Accept and install'), isFalse);
      // Page buttons read on; the end enables it.
      for (var i = 0; i < 60 && !buttonEnabled(t, 'Accept and install'); i++) {
        await press(t, [kPageDown]);
      }
      expect(buttonEnabled(t, 'Accept and install'), isTrue);
      expect(find.textContaining('END OF PLACEHOLDER TERMS'), findsOneWidget);
      await press(t, [kDown, kRight, kEnter]);
      expect(h.services.mockStore.log, ['install:steam:steam=2026-09-10']);
      expect(h.services.mockStore.acceptances, ['steam=2026-09-10']);
      expect(h.services.mockJobs.started.single.kind, JobKind.install);
    });

    testWidgets(
      'a disabled Accept does nothing, and Decline installs nothing',
      (t) async {
        setView(t);
        final h = harness();
        await toTerms(t, h);
        // Scroll just far enough to reach the buttons is impossible before the
        // end; Back declines.
        await press(t, [kEscape]);
        expect(find.text('Terms for Steam'), findsNothing);
        expect(h.services.mockStore.log, isEmpty);
        expect(h.services.mockJobs.started, isEmpty);
      },
    );

    testWidgets('the store refuses an install without the accepted version', (
      t,
    ) async {
      final h = harness();
      h.services.mockStore.setInstalled({});
      expect(
        () => h.services.mockStore.install('plex-htpc'),
        throwsA(
          isA<SystemException>().having(
            (e) => e.kind,
            'kind',
            SystemErrorKind.termsRequired,
          ),
        ),
      );
    });

    testWidgets('down at the top of the buttons goes back to the text', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await toTerms(t, h);
      for (var i = 0; i < 60 && !buttonEnabled(t, 'Accept and install'); i++) {
        await press(t, [kPageDown]);
      }
      await press(t, [kDown]);
      expect(focusLabel(), endsWith('/buttons:0'));
      await press(t, [kUp]);
      expect(focusLabel(), endsWith('/text:0'));
    });
  });

  group('remove', () {
    testWidgets('data deletion needs a second confirmation (Steam warns)', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openApp(
        t,
        1,
        1,
      ); // Steam (Moonlight comes first) (installed): detail
      expect(find.text('Installed.'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Remove
      expect(find.text('Remove Steam from this profile?'), findsOneWidget);
      expect(
        find.textContaining('Games this profile installed through Steam'),
        findsOneWidget,
      );
      await press(t, [kEnter, kDown, kRight, kEnter]); // tick, Remove
      expect(find.text('Delete all data of Steam?'), findsOneWidget);
      expect(
        find.textContaining('Games this profile installed through Steam'),
        findsOneWidget,
      );
      expect(h.services.mockStore.log, isEmpty, reason: 'nothing yet');
      await press(t, [kEnter]); // Cancel (focused first)
      expect(find.text('Delete all data of Steam?'), findsNothing);
      expect(h.services.mockStore.log, isEmpty);
      expect(h.services.mockJobs.started, isEmpty);
      // Again, and confirm this time.
      await press(t, [kEnter, kEnter, kDown, kRight, kEnter]);
      await press(t, [kRight, kEnter]);
      expect(h.services.mockStore.log, ['remove:steam:true']);
      expect(h.services.mockJobs.started.single.kind, JobKind.remove);
    });

    testWidgets('without the option there is a single confirmation', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openApp(t, 2, 0, 1); // Video, second row, first column: Plex
      await press(t, [kRight, kEnter]);
      expect(find.text('Remove Plex from this profile?'), findsOneWidget);
      await press(t, [kDown, kRight, kEnter]);
      expect(find.textContaining('Delete all data'), findsNothing);
      expect(h.services.mockStore.log, ['remove:plex-htpc:false']);
    });
  });

  group('Games tab', () {
    testWidgets('prompts to install Steam when it is missing', (t) async {
      setView(t);
      final h = harness();
      h.services.mockStore.setInstalled({'jellyfin'});
      h.mock.apps.removeWhere((a) => a.id == 'steam');
      await h.pump(t);
      await openTab(t, 1);
      expect(find.text('Steam is not installed'), findsOneWidget);
      expect(focusLabel(), 'games/install-steam:0');
      await press(t, [kEnter]);
      // The install flow starts right here, not in the Store tab.
      expect(find.text('Install Steam for this profile?'), findsOneWidget);
      expect(find.textContaining('Read and accept it next'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Continue
      expect(find.text('Terms for Steam'), findsOneWidget);
      for (var i = 0; i < 60 && !buttonEnabled(t, 'Accept and install'); i++) {
        await press(t, [kPageDown]);
      }
      await press(t, [kDown, kRight, kEnter]);
      expect(h.services.mockStore.log, ['install:steam:steam=2026-09-10']);
      expect(
        find.text('Installing Steam'),
        findsOneWidget,
        reason: 'progress page',
      );
    });

    testWidgets('shows the library when Steam is installed', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openTab(t, 1);
      expect(find.text('Steam is not installed'), findsNothing);
    });
  });

  group('permissions', () {
    /// The Video player's detail page (Video, third row, second column); it
    /// declares a required Controller, a Microphone and the Downloads folder.
    Future<void> openPlayer(WidgetTester t) async {
      await openApp(t, 2, 1, 2);
      expect(find.text('Video player'), findsWidgets);
    }

    testWidgets('install: all on, Required is locked, one turned off', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openPlayer(t);
      expect(find.text('Permissions'), findsNothing, reason: 'not installed');
      await press(t, [kEnter]); // Install
      expect(
        find.text('Install Video player for this profile?'),
        findsOneWidget,
      );
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Controller'), findsOneWidget);
      expect(find.text('Microphone'), findsOneWidget);
      expect(find.text('Downloads folder'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('On'), findsNWidgets(3));
      expect(
        find.textContaining('full access'),
        findsNothing,
        reason: 'sandboxed',
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      // Focus starts on the first switch; a locked one does not move.
      expect(focusLabel(), endsWith('/switch0:0'));
      await press(t, [kEnter]);
      expect(find.text('Required'), findsOneWidget);
      await press(t, [kDown, kEnter]); // Microphone off
      expect(focusLabel(), endsWith('/switch1:0'));
      expect(find.text('Off'), findsOneWidget);
      await press(t, [kDown, kEnter, kEnter]); // Downloads off and on again
      expect(find.text('Off'), findsOneWidget);
      await press(t, [kDown]);
      expect(focusLabel(), endsWith('/buttons:0'));
      await press(t, [kUp]);
      expect(focusLabel(), endsWith('/switch2:0'));
      expect(h.services.mockStore.log, isEmpty, reason: 'nothing set yet');
      await press(t, [kDown, kRight, kEnter]); // Accept
      expect(h.services.mockStore.log, [
        'set_permission:mpv:mic:false',
        'install:mpv:',
      ]);
      expect(h.services.mockStore.denied, {
        'mpv': {'mic'},
      });
      expect(h.services.mockJobs.started.single.kind, JobKind.install);
    });

    testWidgets('install: Cancel and Back set nothing', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openPlayer(t);
      await press(t, [kEnter, kDown, kEnter, kDown, kDown, kEnter]); // Cancel
      expect(find.text('Install Video player for this profile?'), findsNothing);
      await press(t, [kEnter, kDown, kEnter, kEscape]); // Back
      expect(find.text('Install Video player for this profile?'), findsNothing);
      expect(h.services.mockStore.log, isEmpty);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('install: an earlier opt-out left on is granted again', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.services.mockStore.setPermission('mpv', 'downloads', false);
      h.services.mockStore.log.clear();
      await h.pump(t);
      await openPlayer(t);
      await press(t, [kEnter]);
      expect(find.text('On'), findsNWidgets(3), reason: 'all on, as asked');
      await press(t, [kDown, kDown, kDown, kRight, kEnter]); // Accept
      expect(h.services.mockStore.log, [
        'set_permission:mpv:downloads:true',
        'install:mpv:',
      ]);
    });

    testWidgets('install: a failed choice stops the install', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openPlayer(t);
      await press(t, [kEnter, kDown, kEnter]); // Microphone off
      h.services.mockStore.failNext = const SystemException(
        SystemErrorKind.notFound,
        'This app does not use that permission.',
      );
      await press(t, [kDown, kDown, kRight, kEnter]); // Accept
      expect(find.text("That didn't work"), findsOneWidget);
      expect(
        find.text('This app does not use that permission.'),
        findsOneWidget,
      );
      expect(h.services.mockStore.log, isEmpty);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('app page: switches after the buttons, change, restart line', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.services.mockStore.setInstalled({'mpv'});
      h.mock.apps.add(
        const App(
          id: 'mpv',
          name: 'Video player',
          kind: AppKind.native,
          permissions: [],
        ),
      );
      await h.pump(t);
      await openPlayer(t);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Restart the app to apply.'), findsNothing);
      expect(find.text('Required'), findsOneWidget);
      // Back stays first; the switches come after the buttons.
      expect(focusLabel(), endsWith('/actions:0'));
      await press(t, [kDown]);
      expect(focusLabel(), endsWith('/perm-gamepad:0'));
      await press(t, [kEnter]); // locked
      expect(h.services.mockStore.log, isEmpty);
      await press(t, [kDown, kEnter]); // Microphone off
      expect(focusLabel(), endsWith('/perm-mic:0'));
      expect(h.services.mockStore.log, ['set_permission:mpv:mic:false']);
      expect(find.text('Off'), findsOneWidget);
      await press(t, [kEnter]); // and on again
      expect(h.services.mockStore.log.last, 'set_permission:mpv:mic:true');
      expect(find.text('Off'), findsNothing);
      // While it runs, one line says when a change applies.
      await h.launch(t, 'mpv');
      expect(find.text('Restart the app to apply.'), findsOneWidget);
      await press(t, [kDown]);
      expect(focusLabel(), endsWith('/perm-downloads:0'));
      // A refused change shows the usual message.
      h.services.mockStore.failNext = const SystemException(
        SystemErrorKind.unavailable,
        'Settings are unavailable.',
      );
      await press(t, [kEnter]);
      expect(find.text("That didn't work"), findsOneWidget);
      await press(t, [kEnter]);
      expect(find.text('Off'), findsNothing);
    });

    testWidgets('no permissions: no section, the confirm as before', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openApp(t, 2, 0, 1); // Plex (installed)
      expect(find.text('Installed.'), findsOneWidget);
      expect(find.text('Permissions'), findsNothing);
    });

    test('labels: short names, unknown ones as they are', () {
      expect(permissionLabel('gamepad'), 'Controller');
      expect(permissionLabel('mic'), 'Microphone');
      expect(permissionLabel('downloads'), 'Downloads folder');
      expect(permissionLabel('lan'), 'Local network');
      expect(permissionLabel('camera'), 'camera');
    });
  });
}
