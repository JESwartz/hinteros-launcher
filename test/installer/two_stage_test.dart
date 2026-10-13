import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/progress.dart';

import '../support/installer_harness.dart';

/// The install in two stages: the system, then the apps.
void main() {
  group('progress lines with a phase', () {
    test('phase, app and failed_apps are read', () {
      final e = parseProgressLine(
        '{"stage":"install","percent":98,"level":"warn","message":"m",'
        '"code":"app-failed","phase":"apps","app":"youtube"}',
      )!;
      expect(e.phase, InstallSection.apps);
      expect(e.app, 'youtube');
      expect(e.isWarning, isTrue);
      final d = parseProgressLine(
        '{"stage":"done","percent":100,"level":"info","message":"ok",'
        '"phase":"apps","failed_apps":["youtube","plex"]}',
      )!;
      expect(d.isDone, isTrue);
      expect(d.failedApps, ['youtube', 'plex']);
    });

    test('lines without a phase count as the system', () {
      final e = parseProgressLine(
        '{"stage":"install","percent":5,"level":"info","message":"m"}',
      )!;
      expect(e.phase, InstallSection.system);
      expect(e.app, isNull);
      expect(e.failedApps, isEmpty);
      final odd = parseProgressLine(
        '{"stage":"install","percent":5,"message":"m","phase":"bogus",'
        '"failed_apps":"x"}',
      )!;
      expect(odd.phase, InstallSection.system);
      expect(odd.failedApps, isEmpty);
    });
  });

  group('the progress screen', () {
    Future<InstallerHarness> start(
      WidgetTester t, {
      List<String> failing = const [],
      bool twoStage = true,
    }) async {
      final backend = FakeInstallerBackend(
        delay: const Duration(milliseconds: 100),
      );
      if (twoStage) {
        backend.installScriptFor = (plan) =>
            FakeScript.twoStage(plan.apps, failing: failing);
      }
      final h = InstallerHarness(backend: backend);
      await h.pump(t);
      await h.flow.refreshNetwork();
      await h.flow.loadCatalog();
      await h.flow.loadDisks();
      h.flow.chooseDisk(h.flow.disks!.first);
      h.flow.setUsername('james');
      h.flow.setPassword('change-me-now');
      h.flow.setRepeat('change-me-now');
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      await h.choose(t, 'actions', 1);
      return h;
    }

    Future<void> until(WidgetTester t, bool Function() ok) async {
      for (var i = 0; i < 200 && !ok(); i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(ok(), isTrue);
    }

    Future<void> finish(WidgetTester t, InstallerHarness h) async {
      await until(t, () => !h.flow.running);
      await t.pumpAndSettle();
    }

    testWidgets('system phase: apps wait, only the system has progress', (
      t,
    ) async {
      final h = await start(t);
      await until(t, () => h.flow.percent >= 57);
      expect(h.flow.section, InstallSection.system);
      expect(find.text('Installing HinterOS'), findsWidgets);
      expect(find.text('Installing apps'), findsNothing);
      expect(find.byKey(const ValueKey('apps-line')), findsNothing);
      expect(h.flow.systemPercent, h.flow.percent);
      expect(h.flow.appsPercent, 0);
      await finish(t, h);
    });

    testWidgets('apps phase: system is complete, apps have their states', (
      t,
    ) async {
      final h = await start(t, failing: ['youtube']);
      await until(t, () => h.flow.section == InstallSection.apps);
      expect(h.flow.systemPercent, 100);
      expect(find.text('Checking your choices'), findsNothing);
      await t.pump();
      expect(find.text('Installing apps'), findsNothing);
      expect(find.text('Installing HinterOS'), findsWidgets);
      expect(find.textContaining(' · 1 of 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('apps-percent')), findsNothing);
      expect(h.flow.appsLine, contains(' · 1 of 2'));
      expect(h.flow.stepPercent, 40, reason: 'this app\'s own bar');
      expect(
        h.flow.appProgress.map((a) => a.state),
        contains(AppInstallState.installing),
      );
      // Firefox done, YouTube installing then failed.
      await until(
        t,
        () =>
            h.flow.appProgress.last.state == AppInstallState.failed ||
            !h.flow.running,
      );
      final states = {for (final a in h.flow.appProgress) a.id: a.state};
      expect(states['youtube'], AppInstallState.failed);
      await finish(t, h);
    });

    testWidgets('done with a failed app lists it', (t) async {
      final h = await start(t, failing: ['youtube']);
      await finish(t, h);
      expect(h.flow.step, InstallerStep.done);
      expect(
        find.textContaining(
          'These apps did not install. Add them later from the Store: YouTube',
        ),
        findsOneWidget,
      );
    });

    testWidgets('done with every app fine says nothing about failures', (
      t,
    ) async {
      final h = await start(t);
      await finish(t, h);
      expect(h.flow.step, InstallerStep.done);
      expect(find.textContaining("couldn't be installed"), findsNothing);
      expect(h.flow.failedAppNames, isEmpty);
      expect(
        h.flow.appProgress.map((a) => a.state),
        everyElement(AppInstallState.done),
      );
    });

    testWidgets('a backend without phases still works (all system)', (t) async {
      final h = await start(t, twoStage: false);
      await until(t, () => h.flow.percent >= 57);
      expect(h.flow.section, InstallSection.system);
      expect(find.byKey(const ValueKey('percent')), findsOneWidget);
      await finish(t, h);
      expect(h.flow.step, InstallerStep.done);
    });
  });
}
