import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/plan.dart';
import 'package:hinteros_launcher/src/installer/progress.dart';

import '../support/installer_harness.dart';

const online = NetworkState(
  wiredConnected: true,
  wifiAvailable: true,
  online: true,
);

const _sda = '/dev/sda';

/// The mock disks, with [existing] on the SATA disk (d1).
List<DiskInfo> disksWith(ExistingInstall? existing) {
  final d = mockDisks();
  return [d[0], d[1].withInstall(existing), ...d.skip(2)];
}

void main() {
  Future<InstallerHarness> toDisk(
    WidgetTester t, {
    FakeInstallerBackend? backend,
  }) async {
    final h = InstallerHarness(backend: backend);
    await h.start(t);
    await h.choose(t, 'actions', 1);
    expect(h.flow.step, InstallerStep.disk);
    return h;
  }

  /// On the disk step with the SATA disk chosen.
  Future<InstallerHarness> toChoice(
    WidgetTester t, {
    FakeInstallerBackend? backend,
  }) async {
    final h = await toDisk(t, backend: backend);
    await h.choose(t, 'd1');
    return h;
  }

  /// Keep data, all the way to the summary.
  Future<InstallerHarness> toKeepSummary(
    WidgetTester t, {
    FakeInstallerBackend? backend,
  }) async {
    final h = await toChoice(t, backend: backend);
    await h.choose(t, 'actions', 1);
    await h.choose(t, 'actions');
    expect(h.flow.step, InstallerStep.summary);
    return h;
  }

  void fillErase(InstallerHarness h) {
    h.flow.setUsername('james');
    h.flow.setPassword('change-me-now');
    h.flow.setRepeat('change-me-now');
    h.flow.setHostname('tv-box');
    h.flow.toggleSsh();
  }

  group('the disk step', () {
    testWidgets('no install on the disk: no choice to make', (t) async {
      final h = await toDisk(t);
      await h.choose(t, 'd0');
      expect(find.text('Keep data'), findsNothing);
      expect(find.text('Erase all'), findsNothing);
      expect(h.flow.keepData, isFalse);
      expect(find.textContaining('It will be erased'), findsOneWidget);
    });

    testWidgets('an install that can be kept: Keep data is the default', (
      t,
    ) async {
      final h = await toChoice(t);
      expect(find.text('Keep data'), findsOneWidget);
      expect(find.text('Erase all'), findsOneWidget);
      expect(h.flow.keepData, isTrue);
      expect(find.textContaining('It will be erased'), findsNothing);
      await h.choose(t, 'erase');
      expect(h.flow.keepData, isFalse);
      expect(find.textContaining('It will be erased'), findsOneWidget);
      await h.choose(t, 'keep');
      expect(h.flow.keepData, isTrue);
    });

    testWidgets('schemaOk false: only Erase all, and one line that says why', (
      t,
    ) async {
      final h = await toChoice(
        t,
        backend: FakeInstallerBackend(
          disks: disksWith(
            const ExistingInstall(schemaOk: false, version: '9.0.0'),
          ),
        ),
      );
      expect(find.text('Keep data'), findsNothing);
      expect(find.text('Erase all'), findsOneWidget);
      expect(find.text('Cannot keep data on this disk.'), findsOneWidget);
      expect(find.textContaining('9.0.0'), findsNothing);
      expect(h.flow.keepData, isFalse);
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.account);
    });

    testWidgets('a newer install than the medium: both versions, once', (
      t,
    ) async {
      await toChoice(
        t,
        backend: FakeInstallerBackend(
          disks: disksWith(
            const ExistingInstall(schemaOk: true, version: '0.9.0'),
          ),
        ),
      );
      expect(
        find.text('This replaces HinterOS 0.9.0 with the older 0.7.0.'),
        findsOneWidget,
      );
    });

    for (final (name, version, infoError) in [
      ('older', '0.6.0', null),
      ('the same', '0.7.0', null),
      ('not known on the disk', null, null),
      ('not a release', '1a2b3c4d5e6f', null),
      ('not known on the medium', '0.9.0', const InstallerException('old')),
    ]) {
      testWidgets('versions $name: no line about them', (t) async {
        await toChoice(
          t,
          backend: FakeInstallerBackend(
            disks: disksWith(ExistingInstall(schemaOk: true, version: version)),
            infoError: infoError,
          ),
        );
        expect(find.text('Keep data'), findsOneWidget);
        expect(find.textContaining('This replaces'), findsNothing);
      });
    }

    testWidgets('another disk, and back: the default again', (t) async {
      final h = await toChoice(t);
      await h.choose(t, 'erase');
      expect(h.flow.keepData, isFalse);
      await h.choose(t, 'd0');
      expect(find.text('Erase all'), findsNothing);
      expect(h.flow.keepData, isFalse);
      await h.choose(t, 'd1');
      expect(h.flow.keepData, isTrue);
    });

    testWidgets('the same disk chosen again: Erase all stays', (t) async {
      final h = await toChoice(t);
      await h.choose(t, 'erase');
      await h.choose(t, 'd1');
      expect(h.flow.keepData, isFalse);
    });

    testWidgets('the list changes: the choice follows the disk', (t) async {
      final h = await toChoice(t);
      expect(h.flow.keepData, isTrue);

      // The install cannot be read any more.
      final sda = h.flow.disk!;
      h.backend.setDisk(_sda, disksWith(null)[1]);
      await h.choose(t, 'actions', 0);
      expect(h.flow.disk!.path, _sda);
      expect(h.flow.keepData, isFalse);
      expect(find.text('Keep data'), findsNothing);
      expect(find.textContaining('It will be erased'), findsOneWidget);
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.account);
      await h.back(t);

      // It can be read again, and another disk took its place: no choice.
      h.backend.setDisk(_sda, sda);
      h.backend.replug(_sda);
      await h.choose(t, 'actions', 0);
      expect(h.flow.disk, isNull);
      expect(h.flow.keepData, isFalse);
    });

    testWidgets('Erase all stays when the same disk is listed again', (
      t,
    ) async {
      final h = await toChoice(t);
      await h.choose(t, 'erase');
      await h.choose(t, 'actions', 0);
      expect(h.flow.keepData, isFalse);
    });

    testWidgets('a slow listing: one at a time, and no way on until it ends', (
      t,
    ) async {
      final h = await toChoice(t);
      final gate = Completer<void>();
      h.backend.disksHold = gate.future;
      final before = h.backend.calls.where((c) => c == 'disks').length;
      unawaited(h.flow.loadDisks());
      unawaited(h.flow.loadDisks());
      await t.pump();
      await t.pump();
      expect(h.flow.loadingDisks, isTrue);
      expect(buttonEnabled(t, 'Continue'), isFalse);
      expect(buttonEnabled(t, 'Look again'), isFalse);
      expect(find.text('Looking for disks...'), findsOneWidget);
      gate.complete();
      h.backend.disksHold = null;
      await h.settle(t);
      expect(h.flow.loadingDisks, isFalse);
      expect(buttonEnabled(t, 'Continue'), isTrue);
      expect(find.text('Looking for disks...'), findsNothing);
      expect(h.backend.calls.where((c) => c == 'disks').length, before + 1);
    });
  });

  group('the steps', () {
    testWidgets('Keep data: only the options, and only the channel', (t) async {
      final h = await toChoice(t);
      expect(find.text('Step 2 of 4'), findsOneWidget);
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.options);
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('Update channel'), findsOneWidget);
      expect(find.text('Computer name'), findsNothing);
      expect(find.text('Enable SSH'), findsNothing);
      await h.choose(t, 'actions');
      expect(h.flow.step, InstallerStep.summary);
      expect(find.text('Step 4 of 4'), findsOneWidget);
      // And back the same way.
      await h.back(t);
      expect(h.flow.step, InstallerStep.options);
      await h.back(t);
      expect(h.flow.step, InstallerStep.disk);
    });

    testWidgets('a bad computer name does not stop Keep data', (t) async {
      final h = await toChoice(t);
      h.flow.setHostname('-bad-');
      await t.pump();
      expect(h.flow.ready, isTrue);
      await h.choose(t, 'actions', 1);
      expect(buttonEnabled(t, 'Continue'), isTrue);
      expect(find.textContaining('hyphens'), findsNothing);
    });

    testWidgets('Erase all on the same disk: every step again', (t) async {
      final h = await toChoice(t);
      await h.choose(t, 'erase');
      expect(find.text('Step 2 of 6'), findsOneWidget);
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.account);
      expect(h.flow.ready, isFalse);
      await h.back(t);
      expect(h.flow.step, InstallerStep.disk);
    });

    testWidgets('from Keep data back to Erase all: nothing is skipped', (
      t,
    ) async {
      final h = await toKeepSummary(t);
      await h.back(t);
      await h.back(t);
      await h.choose(t, 'erase');
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.account);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      expect(h.flow.ready, isFalse, reason: 'no account yet');
      await h.back(t);
      expect(h.flow.step, InstallerStep.apps);
      await h.back(t);
      expect(h.flow.step, InstallerStep.options);
      await h.back(t);
      expect(h.flow.step, InstallerStep.account);
    });
  });

  group('the plan', () {
    testWidgets('exactly what the backend takes', (t) async {
      final h = await toKeepSummary(t);
      expect(h.flow.buildPlan().toJson(), {
        'disk': _sda,
        'diskSeq': 2,
        'keepData': true,
        'channel': 'stable',
        'network': 'offline',
      });
    });

    testWidgets('online, on a joined Wi-Fi network, on beta', (t) async {
      final backend = FakeInstallerBackend(
        state: const NetworkState(wifiAvailable: true),
        wifiPasswords: {'Living Room': 'correct horse'},
      );
      final h = await toKeepSummary(t, backend: backend);
      await h.flow.joinWifi(
        (await backend.scanWifi()).first,
        psk: 'correct horse',
      );
      h.flow.toggleChannel();
      expect(h.flow.buildPlan().toJson(), {
        'disk': _sda,
        'diskSeq': 2,
        'keepData': true,
        'channel': 'beta',
        'network': 'auto',
        'wifi': {'ssid': 'Living Room', 'psk': 'correct horse'},
      });
    });

    testWidgets('answers given for Erase all do not reach the plan', (t) async {
      final backend = FakeInstallerBackend(state: online, newer: mockNewer());
      final h = InstallerHarness(backend: backend);
      await h.start(t);
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.version);
      await h.choose(t, 'newer');
      expect(h.flow.step, InstallerStep.disk);
      await h.choose(t, 'd1');
      await h.choose(t, 'erase');
      fillErase(h);
      final steam = h.flow.apps!.apps.firstWhere((a) => a.id == 'steam');
      h.flow.apps!.toggle('steam');
      h.flow.apps!.accept(steam);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      expect(h.flow.buildPlan().toJson()['rev'], isNotNull);
      expect(find.text('Erase and install'), findsOneWidget);

      // Back to the disk step, and Keep data.
      h.flow.go(InstallerStep.disk);
      await t.pumpAndSettle();
      await h.choose(t, 'keep');
      await h.choose(t, 'actions', 1);
      await h.choose(t, 'actions');
      expect(h.flow.step, InstallerStep.summary);
      expect(h.flow.buildPlan().toJson(), {
        'disk': _sda,
        'diskSeq': 2,
        'keepData': true,
        'channel': 'stable',
        'network': 'auto',
      });
      expect(find.textContaining('(1a2b3c4)'), findsOneWidget);
      expect(find.textContaining('0.7.1'), findsNothing);

      await h.eraseAndInstall(t);
      expect(backend.plans.length, 2);
      expect(backend.plans.first.containsKey('rev'), isFalse);
      expect(h.flow.step, InstallerStep.done);
    });

    testWidgets('a channel change does not offer a newer HinterOS', (t) async {
      final backend = FakeInstallerBackend(
        state: online,
        newer: {InstallChannel.beta: mockNewer()[InstallChannel.beta]!},
      );
      final h = InstallerHarness(backend: backend);
      await h.start(t);
      await h.choose(t, 'actions', 1);
      await h.choose(t, 'd1');
      await h.choose(t, 'actions', 1);
      await h.choose(t, 'channel');
      await h.choose(t, 'actions');
      expect(h.flow.step, InstallerStep.summary);
      expect(backend.calls, isNot(contains('checkNewer:beta')));
      expect(h.flow.buildPlan().toJson()['channel'], 'beta');
      expect(h.flow.buildPlan().toJson().containsKey('rev'), isFalse);
    });
  });

  group('the confirmation', () {
    testWidgets('Keep data says it keeps the files', (t) async {
      await toKeepSummary(t);
      expect(
        find.text('Keep data on Example SATA SSD 1TB, 1.0 TB'),
        findsOneWidget,
      );
      expect(
        find.text('Your files stay on this disk. HinterOS is installed again.'),
        findsOneWidget,
      );
      expect(find.text('Keep data and install'), findsOneWidget);
      expect(
        find.text('Hold A on Keep data and install for 5 seconds.'),
        findsOneWidget,
      );
      expect(find.textContaining('Erase'), findsNothing);
      expect(find.textContaining('deleted'), findsNothing);
      for (final s in ['Admin user', 'Computer name', 'SSH', 'Apps']) {
        expect(find.text(s), findsNothing);
      }
      expect(find.text('Update channel'), findsOneWidget);
    });

    testWidgets('Erase all on a disk with an install says it erases', (
      t,
    ) async {
      final h = await toChoice(t);
      await h.choose(t, 'erase');
      fillErase(h);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      expect(find.text('Erase Example SATA SSD 1TB, 1.0 TB'), findsOneWidget);
      expect(
        find.text('Everything on this disk is deleted. You cannot undo this.'),
        findsOneWidget,
      );
      expect(find.text('Erase and install'), findsOneWidget);
      expect(find.textContaining('Keep data'), findsNothing);
    });

    testWidgets('a short hold starts nothing', (t) async {
      final h = await toKeepSummary(t);
      await h.moveTo(t, 'actions', 1);
      await h.holdAccept(t, const Duration(seconds: 4));
      expect(h.flow.step, InstallerStep.summary);
      expect(h.backend.calls, isNot(contains('validate')));
    });
  });

  group('the install', () {
    testWidgets('the stages of a keepData run, without apps', (t) async {
      final backend = FakeInstallerBackend(
        delay: const Duration(milliseconds: 20),
      );
      final h = await toKeepSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      for (var i = 0; i < 400 && h.flow.progressStage != 'mount'; i++) {
        await t.pump(const Duration(milliseconds: 5));
      }
      expect(h.flow.stages, keepInstallStages);
      expect(find.text('Preparing the disk'), findsWidgets);
      expect(find.text('Working'), findsNothing);
      expect(find.textContaining('Erasing'), findsNothing);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.done);
      expect(h.flow.appProgress, isEmpty);
      expect(
        find.text('HinterOS 0.7.0 stable (1a2b3c4) is installed'),
        findsOneWidget,
      );
    });

    testWidgets('it needs neither an account nor the catalog', (t) async {
      final h = InstallerHarness();
      await h.pump(t);
      await h.flow.loadDisks();
      h.flow.chooseDisk(h.flow.disks![1]);
      expect(h.flow.ready, isTrue);
      expect(h.flow.buildPlan().keepData, isTrue);
    });

    testWidgets('a run with Erase all has its own stages', (t) async {
      final h = await toChoice(t);
      await h.choose(t, 'erase');
      fillErase(h);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      await h.eraseAndInstall(t);
      expect(h.flow.step, InstallerStep.done);
      expect(h.flow.stages, installStages);
      expect(h.backend.plans.first.containsKey('keepData'), isFalse);
      expect(h.backend.plans.first['hostname'], 'tv-box');
    });

    for (final code in ['keep-no-install', 'keep-schema-newer']) {
      testWidgets('refused with $code: the disk is chosen again', (t) async {
        final backend = FakeInstallerBackend()
          ..validateScript = FakeScript.refused(code, 'cannot keep');
        final h = await toKeepSummary(t, backend: backend);
        await h.eraseAndInstall(t);
        expect(h.flow.phase, InstallPhase.refused);
        expect(find.text('The install did not start'), findsOneWidget);
        expect(find.text('Nothing was changed on your disk.'), findsOneWidget);
        expect(find.text(explainCode(code)), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        await h.choose(t, 'actions');
        expect(h.flow.step, InstallerStep.disk);
        expect(h.flow.disk, isNull);
        expect(h.flow.keepData, isFalse);
      });
    }

    testWidgets('failed part-way: says the files stay; Try again keeps', (
      t,
    ) async {
      final backend = FakeInstallerBackend()
        ..installScript = FakeScript.failed(
          code: 'esp-failed',
          message: 'the EFI system partition did not get the volume id',
        );
      final h = await toKeepSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.failed);
      expect(find.textContaining('Your files stay on the disk'), findsWidgets);
      expect(find.textContaining('The disk may be changed'), findsNothing);
      backend.installScript = null;
      await h.choose(t, 'actions');
      await h.settle(t);
      expect(h.flow.step, InstallerStep.done);
      expect(backend.plans.last['keepData'], isTrue);
    });

    /// The next listing after a failed run: mounted at /mnt, so the backend
    /// has not looked inside it.
    DiskInfo leftBehind() => DiskInfo(
      path: _sda,
      name: 'sda',
      sizeBytes: mockDisks()[1].sizeBytes,
      diskSeq: 2,
      model: mockDisks()[1].model,
      transport: 'sata',
      installLeftover: true,
    );

    testWidgets('a failed run leaves the disk mounted: Keep data stays', (
      t,
    ) async {
      final backend = FakeInstallerBackend()
        ..installScript = FakeScript.failed();
      final h = await toKeepSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.failed);
      backend.setDisk(_sda, leftBehind());
      await h.moveTo(t, 'actions', 1); // Change my choices
      await h.accept(t);
      expect(h.flow.step, InstallerStep.summary);
      await h.back(t);
      await h.back(t);
      expect(h.flow.step, InstallerStep.disk);
      await h.settle(t);
      expect(find.text('Keep data'), findsOneWidget);
      expect(h.flow.keepData, isTrue);
    });

    testWidgets('after a failed Erase all nothing is left to keep', (t) async {
      final backend = FakeInstallerBackend()
        ..installScript = FakeScript.failed();
      final h = await toChoice(t, backend: backend);
      await h.choose(t, 'erase');
      fillErase(h);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.failed);
      backend.setDisk(_sda, leftBehind());
      await h.moveTo(t, 'actions', 1);
      await h.accept(t);
      h.flow.go(InstallerStep.disk);
      await h.settle(t);
      expect(find.text('Keep data'), findsNothing);
      expect(h.flow.keepData, isFalse);
    });
  });
}
