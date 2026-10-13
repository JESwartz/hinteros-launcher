import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/nav_controller.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/ui/app_selection.dart';
import 'package:hinteros_launcher/src/ui/pages.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/modal_host_harness.dart';

bool enabled(WidgetTester t, String label) =>
    t.widget<HButton>(find.widgetWithText(HButton, label)).enabled;

void main() {
  const down = NavAction.down;
  const right = NavAction.right;
  const accept = NavAction.accept;

  group('installer app selection', () {
    late AppSelectionController c;
    late NavRegion region;
    late ModalTestHost host;
    var continued = 0;

    Future<void> start(WidgetTester t, {bool online = true}) async {
      setView(t);
      continued = 0;
      c = AppSelectionController(mockCatalog());
      host = ModalTestHost();
      region = NavRegion('selection');
      host.nav.adopt(region);
      await host.pump(
        t,
        (_) => AppSelectionView(
          controller: c,
          region: region,
          online: online,
          onContinue: () => continued++,
        ),
      );
      host.nav.focusRegion(region);
      await t.pumpAndSettle();
    }

    testWidgets(
      'the apps marked installerDefault are selected at first, nothing else',
      (t) async {
        await start(t);
        expect(c.selected, {'youtube', 'firefox'});
        expect(
          [
            for (final a in c.apps)
              if (a.installerDefault) a.id,
          ],
          ['firefox', 'youtube'],
        );
      },
    );

    testWidgets('each app says whether it is on the ISO or needs a download', (
      t,
    ) async {
      await start(t);
      // On the installer: Jellyfin, YouTube, Crunchyroll, Firefox.
      expect(find.text('On the installer'), findsNWidgets(4));
      expect(find.text('Download, 1.0 GB'), findsOneWidget, reason: 'Steam');
      expect(find.text('Download, 300 MB'), findsOneWidget, reason: 'Plex');
      expect(find.textContaining('Nothing to download'), findsOneWidget);
    });

    testWidgets('selecting a download app adds up the size and needs terms', (
      t,
    ) async {
      await start(t);
      for (var i = 0; i < c.apps.indexWhere((a) => a.id == 'steam'); i++) {
        await host.act(t, down);
      }
      await host.act(t, accept); // Steam
      expect(c.isSelected('steam'), isTrue);
      expect(c.downloadMiB, 1000);
      expect(find.text('Read and accept'), findsOneWidget);
      expect(enabled(t, 'Continue'), isFalse);
      expect(
        find.textContaining('Accept the terms or untick those apps'),
        findsOneWidget,
      );
    });

    testWidgets('Continue waits for the terms, which must be read to the end', (
      t,
    ) async {
      await start(t);
      for (var i = 0; i < c.apps.indexWhere((a) => a.id == 'steam'); i++) {
        await host.act(t, down);
      }
      await host.act(t, accept); // tick Steam
      // The terms row comes after the app rows.
      final steamAt = c.apps.indexWhere((a) => a.id == 'steam');
      for (var i = steamAt; i < c.apps.length; i++) {
        await host.act(t, down);
      }
      await host.act(t, accept); // open the terms
      expect(find.text('Terms for Steam'), findsOneWidget);
      expect(enabled(t, 'Accept and install'), isFalse);
      for (var i = 0; i < 60 && !enabled(t, 'Accept and install'); i++) {
        await host.act(t, NavAction.pageRight);
      }
      await host.act(t, down);
      await host.act(t, right);
      await host.act(t, accept);
      expect(find.text('Terms for Steam'), findsNothing);
      expect(c.termsAccepted(c.apps.first), isTrue);
      expect(find.text('Accepted'), findsOneWidget);
      expect(enabled(t, 'Continue'), isTrue);
      expect(c.acceptances, {'steam': '2026-09-10'});
      // Unticking withdraws it; ticking again asks again.
      host.nav.focusRegion(region);
      c.toggle('steam');
      c.toggle('steam');
      expect(c.termsComplete, isFalse);
      expect(c.acceptances, isEmpty);
    });

    testWidgets('offline, apps that need a download are disabled', (t) async {
      await start(t, online: false);
      expect(
        find.text('Needs internet'),
        findsNWidgets(c.apps.where((a) => !a.onIso).length),
      );
      for (var i = 0; i < c.apps.indexWhere((a) => a.id == 'steam'); i++) {
        await host.act(t, down);
      }
      await host.act(t, accept); // Steam: refused
      expect(c.isSelected('steam'), isFalse);
      expect(find.text('Read and accept'), findsNothing);
      c.toggle('plex-htpc');
      c.dropDownloads();
      expect(c.selected, {'youtube', 'firefox'});
    });

    testWidgets('Continue calls back when allowed', (t) async {
      await start(t);
      for (var i = 0; i <= c.apps.length - 1; i++) {
        await host.act(t, down);
      }
      await host.act(t, accept);
      expect(continued, 1);
    });
  });

  group('security notice lockout, exact timing', () {
    testWidgets('inert for 5 seconds, then Update now and Later', (t) async {
      setView(t);
      final host = ModalTestHost();
      await host.pump(t, (_) => const SizedBox());
      SecurityChoice? choice;
      host.modals
          .show<SecurityChoice>(
            (c, m) => SecurityNotice(modal: m, update: mockSecurityUpdate()),
          )
          .then((v) => choice = v);
      await t.pumpAndSettle();
      expect(
        find.textContaining('You can choose in 5 seconds'),
        findsOneWidget,
      );

      await t.pump(const Duration(milliseconds: 4500));
      expect(find.textContaining('in 1 second'), findsOneWidget);
      expect(enabled(t, 'Update now (1)'), isFalse);
      host.nav.dispatch(NavAction.accept, NavPhase.press);
      host.nav.dispatch(NavAction.back, NavPhase.press);
      await t.pump();
      expect(choice, isNull);
      expect(host.modals.isOpen, isTrue);

      await t.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Choose when to update'), findsOneWidget);
      expect(enabled(t, 'Later'), isTrue);
      expect(enabled(t, 'Update now'), isTrue);
      host.nav.dispatch(NavAction.right, NavPhase.press);
      host.nav.dispatch(NavAction.accept, NavPhase.press);
      await t.pumpAndSettle();
      expect(choice, SecurityChoice.updateNow);
    });

    testWidgets('a custom lockout and 1.6x text still show the severity', (
      t,
    ) async {
      setView(t);
      final host = ModalTestHost(
        settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      );
      await host.pump(t, (_) => const SizedBox());
      host.modals.show<SecurityChoice>(
        (c, m) => SecurityNotice(
          modal: m,
          update: mockSecurityUpdate(severity: SecuritySeverity.moderate),
          lockout: const Duration(seconds: 2),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Severity: Moderate'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      expect(enabled(t, 'Later'), isTrue);
    });
  });

  testWidgets('modals stack: Back closes only the top one', (t) async {
    setView(t);
    final host = ModalTestHost();
    await host.pump(t, (_) => const SizedBox());
    final results = <String?>[];
    for (final name in ['one', 'two']) {
      host.modals
          .show<String>((c, m) {
            m.region.setRows(const []);
            return Text(name);
          })
          .then(results.add);
    }
    await t.pumpAndSettle();
    expect(host.modals.depth, 2);
    host.nav.dispatch(NavAction.back, NavPhase.press);
    await t.pumpAndSettle();
    expect(host.modals.depth, 1);
    expect(results, [null]);
  });
}
