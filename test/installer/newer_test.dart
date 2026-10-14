import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/parsers.dart';
import 'package:hinteros_launcher/src/installer/plan.dart';
import 'package:hinteros_launcher/src/installer/progress.dart';
import 'package:hinteros_launcher/src/log.dart';

import '../support/installer_harness.dart';

/// The version step: a newer signed HinterOS on the installer's channel
/// (`hinteros-install --check-newer`) or the one on the USB stick.
void main() {
  const wired = NetworkState(
    wiredConnected: true,
    wifiAvailable: true,
    online: true,
  );
  const isoLabel = 'HinterOS 0.7.0 stable (1a2b3c4)';
  const newerLabel = 'HinterOS 0.7.1 stable (9f8e7d6)';
  final stableRev = mockNewer()[InstallChannel.stable]!.rev;

  late List<String> logged;
  setUp(() {
    logged = [];
    final old = logSink;
    logSink = logged.add;
    addTearDown(() => logSink = old);
  });

  /// From Welcome, through the internet step's Continue.
  Future<InstallerHarness> pastNetwork(
    WidgetTester t,
    FakeInstallerBackend backend, {
    DateTime Function()? clock,
  }) async {
    final h = InstallerHarness(backend: backend, clock: clock);
    await h.start(t);
    await h.choose(t, 'actions', 1);
    return h;
  }

  /// The answers from the disk to the apps, then the summary.
  Future<void> fill(InstallerHarness h, WidgetTester t) async {
    await h.flow.loadCatalog();
    await h.flow.loadDisks();
    h.flow.chooseDisk(h.flow.disks!.first);
    h.flow.setUsername('james');
    h.flow.setPassword('change-me-now');
    h.flow.setRepeat('change-me-now');
    h.flow.go(InstallerStep.summary);
    await t.pumpAndSettle();
  }

  group('the version step is skipped', () {
    testWidgets('offline: no check, straight to the disk', (t) async {
      final b = FakeInstallerBackend(newer: mockNewer());
      final h = await pastNetwork(t, b);
      expect(h.flow.step, InstallerStep.disk);
      expect(b.calls.where((c) => c.startsWith('checkNewer')), isEmpty);
      expect(find.text('Step 2 of 6'), findsOneWidget);
      await fill(h, t);
      expect(find.text(isoLabel), findsOneWidget, reason: 'from --info');
      expect(h.flow.buildPlan().toJson().containsKey('rev'), isFalse);
    });

    testWidgets('online, nothing newer: the ISO version, named', (t) async {
      final b = FakeInstallerBackend(state: wired);
      final h = await pastNetwork(t, b);
      expect(h.flow.step, InstallerStep.disk);
      expect(b.calls, contains('checkNewer:default'));
      expect(find.text('Step 2 of 6'), findsOneWidget);
      await h.back(t);
      expect(h.flow.step, InstallerStep.network, reason: 'Back skips it too');
      await fill(h, t);
      expect(find.text(isoLabel), findsOneWidget);
      expect(h.flow.buildPlan().rev, isNull);
    });

    testWidgets('the check fails: logged, the ISO version', (t) async {
      final b = FakeInstallerBackend(
        state: wired,
        newer: mockNewer(),
        checkError: const InstallerException(
          'the tip is not signed',
          code: 'unsigned',
        ),
      );
      final h = await pastNetwork(t, b);
      expect(h.flow.step, InstallerStep.disk);
      expect(
        logged.join('\n'),
        contains(
          'checking for a newer HinterOS failed: the tip is not signed '
          '(unsigned)',
        ),
      );
      expect(find.textContaining('signed'), findsNothing);
      await fill(h, t);
      expect(find.text(isoLabel), findsOneWidget, reason: 'from --info');
      expect(h.flow.buildPlan().rev, isNull);
    });
  });

  group('offline: the version and channel from --info', () {
    const betaLabel = 'HinterOS 0.7.1.1a2b3c4 beta';

    testWidgets('a beta installer starts on Beta and names its version', (
      t,
    ) async {
      final b = FakeInstallerBackend(
        newer: mockNewer(),
        defaultChannel: InstallChannel.beta,
      );
      final h = await pastNetwork(t, b);
      expect(b.calls, contains('info'));
      expect(b.calls.where((c) => c.startsWith('checkNewer')), isEmpty);
      expect(h.flow.channel, InstallChannel.beta);
      h.flow.go(InstallerStep.options);
      await t.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      await fill(h, t);
      expect(find.text(betaLabel), findsOneWidget);
      expect(find.text('HinterOS from this USB stick'), findsNothing);
      final plan = h.flow.buildPlan().toJson();
      expect(plan['channel'], 'beta');
      expect(plan.containsKey('rev'), isFalse);
    });

    testWidgets('a stable installer: Stable and its version', (t) async {
      final b = FakeInstallerBackend();
      final h = await pastNetwork(t, b);
      expect(h.flow.channel, InstallChannel.stable);
      await fill(h, t);
      expect(find.text(isoLabel), findsOneWidget);
    });

    testWidgets('a channel the person chose stays', (t) async {
      final b = FakeInstallerBackend(defaultChannel: InstallChannel.beta);
      final h = await pastNetwork(t, b);
      h.flow.toggleChannel(); // Stable
      await h.flow.loadInfo();
      expect(h.flow.channel, InstallChannel.stable);
    });

    testWidgets('--info fails: logged, Stable, no version name', (t) async {
      final b = FakeInstallerBackend(
        defaultChannel: InstallChannel.beta,
        infoError: const InstallerException(
          'hinteros-install failed (status 2).',
        ),
      );
      final h = await pastNetwork(t, b);
      expect(
        logged.join('\n'),
        contains(
          'reading the installer version failed: '
          'hinteros-install failed (status 2).',
        ),
      );
      expect(h.flow.channel, InstallChannel.stable);
      await fill(h, t);
      expect(find.text('HinterOS from this USB stick'), findsOneWidget);
    });

    test('--info output: read, or a bad shape refused', () {
      final r = parseInstallerInfo(
        '{"iso":{"rev":"$stableRev","version":"0.7.0"},"channel":"beta"}',
      );
      expect(r.channel, InstallChannel.beta);
      expect(r.iso.rev, stableRev);
      expect(r.iso.version, '0.7.0');
      expect(
        () => parseInstallerInfo('{"iso":{"rev":"x"},"channel":"stable"}'),
        throwsFormatException,
      );
      expect(
        () => parseInstallerInfo(
          '{"iso":{"rev":"$stableRev","version":"0.7.0"},"channel":"x"}',
        ),
        throwsFormatException,
      );
    });
  });

  group('a newer HinterOS', () {
    testWidgets('two buttons, the ISO one focused; the newer sets plan.rev', (
      t,
    ) async {
      final b = FakeInstallerBackend(state: wired, newer: mockNewer());
      final h = await pastNetwork(t, b);
      expect(h.flow.step, InstallerStep.version);
      expect(find.text('Step 2 of 7'), findsOneWidget);
      expect(find.text('Install $isoLabel'), findsOneWidget);
      expect(find.text('Install $newerLabel'), findsOneWidget);
      expect(
        find.text('The newer version needs the internet.'),
        findsOneWidget,
      );
      expect(h.focus, 'content/iso:0', reason: 'the ISO version is default');

      await h.choose(t, 'newer');
      expect(h.flow.step, InstallerStep.disk);
      expect(find.text('Step 3 of 7'), findsOneWidget);
      expect(h.flow.chosenRev, stableRev);
      await h.back(t);
      expect(h.flow.step, InstallerStep.version, reason: 'Back shows it again');
      await h.back(t);
      expect(h.flow.step, InstallerStep.network);

      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.version);
      await h.choose(t, 'newer');
      await fill(h, t);
      expect(find.text(newerLabel), findsOneWidget);
      expect(h.flow.buildPlan().toJson()['rev'], stableRev);
      expect(h.flow.buildPlan().toJson()['channel'], 'stable');
    });

    testWidgets('choosing the ISO version: no rev', (t) async {
      final b = FakeInstallerBackend(state: wired, newer: mockNewer());
      final h = await pastNetwork(t, b);
      await h.accept(t); // the focused ISO button
      expect(h.flow.step, InstallerStep.disk);
      await fill(h, t);
      expect(find.text(isoLabel), findsOneWidget);
      expect(h.flow.buildPlan().toJson().containsKey('rev'), isFalse);
    });

    testWidgets('a beta installer: its channel is the default, beta names', (
      t,
    ) async {
      final b = FakeInstallerBackend(
        state: wired,
        newer: mockNewer(),
        defaultChannel: InstallChannel.beta,
      );
      final h = await pastNetwork(t, b);
      expect(h.flow.channel, InstallChannel.beta);
      expect(
        find.text('Install HinterOS 0.7.1.1a2b3c4 beta'),
        findsOneWidget,
        reason: 'beta: the next patch plus the commit, as on a box',
      );
      expect(find.text('Install HinterOS 0.7.1.5e4d3c2 beta'), findsOneWidget);
    });

    testWidgets('a channel change checks again and asks again', (t) async {
      final b = FakeInstallerBackend(state: wired, newer: mockNewer());
      final h = await pastNetwork(t, b);
      await h.choose(t, 'newer');
      expect(h.flow.chosenRev, stableRev);
      h.flow.go(InstallerStep.options);
      await t.pumpAndSettle();

      // Same channel: no new check, no question.
      await h.choose(t, 'actions');
      expect(h.flow.step, InstallerStep.apps);
      expect(b.calls.where((c) => c.startsWith('checkNewer')).length, 1);

      await h.back(t);
      await h.choose(t, 'channel'); // Beta
      expect(h.flow.chosenRev, isNull, reason: 'the stable choice is dropped');
      await h.choose(t, 'actions');
      expect(
        b.calls.lastWhere((c) => c.startsWith('checkNewer')),
        'checkNewer:beta',
      );
      expect(h.flow.step, InstallerStep.version);
      expect(find.text('Install HinterOS 0.7.1.5e4d3c2 beta'), findsOneWidget);
      await h.back(t);
      expect(h.flow.step, InstallerStep.options);
      await h.choose(t, 'actions');
      expect(h.flow.step, InstallerStep.version);
      await h.choose(t, 'newer');
      expect(h.flow.step, InstallerStep.apps, reason: 'on after the options');
      expect(h.flow.installsNewer, isTrue);
      expect(h.flow.chosenRev, mockNewer()[InstallChannel.beta]!.rev);

      // Back to stable, where nothing is newer now: no question.
      b.newer.remove(InstallChannel.stable);
      await h.back(t);
      await h.choose(t, 'channel'); // Stable
      await h.choose(t, 'actions');
      expect(
        b.calls.lastWhere((c) => c.startsWith('checkNewer')),
        'checkNewer:stable',
      );
      expect(h.flow.step, InstallerStep.apps);
      expect(h.flow.chosenRev, isNull);
      expect(h.flow.installsNewer, isFalse);
    });
  });

  group('the newer HinterOS does not install', () {
    Future<InstallerHarness> failNewer(
      WidgetTester t,
      FakeScript script,
    ) async {
      final b = FakeInstallerBackend(state: wired, newer: mockNewer())
        ..newerInstallScript = script;
      final h = await pastNetwork(t, b);
      await h.choose(t, 'newer');
      await fill(h, t);
      await h.eraseAndInstall(t);
      return h;
    }

    testWidgets('try again, or choose the ISO version, which installs', (
      t,
    ) async {
      final h = await failNewer(t, FakeScript.failed());
      final b = h.backend;
      expect(h.flow.phase, InstallPhase.failed);
      expect(find.text('The install did not finish'), findsOneWidget);
      expect(find.textContaining('The disk may be changed'), findsOneWidget);
      expect(find.text('Version: $newerLabel'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Choose another version'), findsOneWidget);
      expect(find.text('Change my choices'), findsNothing);

      // Try again runs the same newer install.
      await h.accept(t);
      expect(h.flow.phase, InstallPhase.failed);
      expect(b.calls.where((c) => c == 'install').length, 2);
      expect(b.plans.last['rev'], stableRev);

      // Cancel: the version step again (after a new check), then the ISO.
      final checks = b.calls.where((c) => c.startsWith('checkNewer')).length;
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.version);
      expect(
        b.calls.where((c) => c.startsWith('checkNewer')).length,
        checks + 1,
      );
      expect(h.focus, 'content/iso:0');
      await h.accept(t);
      expect(h.flow.step, InstallerStep.summary);
      expect(find.text(isoLabel), findsOneWidget);
      await h.eraseAndInstall(t);
      expect(h.flow.step, InstallerStep.done);
      expect(b.plans.last.containsKey('rev'), isFalse);
      expect(find.text('$isoLabel is installed'), findsOneWidget);
    });

    testWidgets('not downloaded: the disk was not touched', (t) async {
      final h = await failNewer(t, FakeScript.fetchFailed());
      expect(h.flow.phase, InstallPhase.failed);
      expect(find.text('The install did not start'), findsOneWidget);
      expect(find.text('Nothing was changed on your disk.'), findsOneWidget);
      expect(find.textContaining('did not download'), findsOneWidget);
      expect(find.text('Choose another version'), findsOneWidget);
    });

    testWidgets('the channel has nothing newer now: on to the summary', (
      t,
    ) async {
      final h = await failNewer(
        t,
        FakeScript.refused('rev-not-tip', 'the channel moved on'),
      );
      expect(h.flow.phase, InstallPhase.refused);
      expect(find.textContaining('Choose the version again'), findsOneWidget);
      h.backend.newer.clear();
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.summary);
      expect(find.text(isoLabel), findsOneWidget);
      expect(h.flow.buildPlan().rev, isNull);
    });
  });

  testWidgets('the newer HinterOS installs: download stage, named on Done', (
    t,
  ) async {
    final b = FakeInstallerBackend(
      state: wired,
      newer: mockNewer(),
      delay: const Duration(milliseconds: 50),
    )..newerInstallScript = FakeScript.newerOk('0.7.1');
    final h = await pastNetwork(t, b);
    await h.choose(t, 'newer');
    await fill(h, t);
    await h.eraseAndInstall(t);
    for (var i = 0; i < 200 && h.flow.progressStage != 'fetch'; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(
      find.textContaining('Step 2 of 10 · Downloading HinterOS'),
      findsOneWidget,
    );
    expect(h.flow.stepPercent, isNull, reason: 'an indeterminate bar');
    for (var i = 0; i < 400 && h.flow.running; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    await t.pumpAndSettle();
    expect(h.flow.step, InstallerStep.done);
    expect(find.text('$newerLabel is installed'), findsOneWidget);
  });

  testWidgets('the newer HinterOS builds: package name, count, minutes', (
    t,
  ) async {
    var now = DateTime.utc(2026, 10, 14, 12);
    final b = FakeInstallerBackend(
      state: wired,
      newer: mockNewer(),
      // Slow lines: the minutes count up between them.
      delay: const Duration(seconds: 40),
    )..newerInstallScript = FakeScript.newerOk('0.7.1');
    final h = await pastNetwork(t, b, clock: () => now);
    await h.choose(t, 'newer');
    await fill(h, t);
    await h.eraseAndInstall(t);
    String? line() {
      final f = find.byKey(const ValueKey('build-line'));
      return f.evaluate().isEmpty ? null : t.widget<Text>(f).data;
    }

    for (var i = 0; i < 600 && h.flow.progressStage != 'packages'; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(find.text('Downloading packages'), findsOneWidget);
    expect(find.text('Copying packages'), findsNothing);
    expect(line(), isNull, reason: 'not building yet');

    for (var i = 0; i < 600 && h.flow.buildName == null; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(
      find.textContaining('Step 7 of 10 · Building HinterOS'),
      findsOneWidget,
    );
    expect(line(), 'Building hinteros-daemon (1 of 12)');
    // The same package again: its start time stays.
    now = now.add(const Duration(minutes: 2));
    for (var i = 0; i < 60 && h.flow.percent < 50; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(h.flow.buildName, 'hinteros-daemon');
    expect(line(), 'Building hinteros-daemon (1 of 12, 2 min)');

    // The next package starts its own count.
    for (var i = 0; i < 60 && h.flow.buildIndex == 1; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(line(), 'Building hinteros-launcher (3 of 12)');
    // Under a minute: no minutes. Then the line counts up by itself.
    now = now.add(const Duration(seconds: 50));
    await t.pump(const Duration(seconds: 15));
    expect(line(), 'Building hinteros-launcher (3 of 12)');
    now = now.add(const Duration(minutes: 6));
    await t.pump(const Duration(seconds: 15));
    expect(line(), 'Building hinteros-launcher (3 of 12, 6 min)');

    // Nothing is building: the backend's words again.
    for (var i = 0; i < 60 && h.flow.buildName != null; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(line(), isNull);
    expect(find.text('12 of 12 built'), findsOneWidget);
    for (var i = 0; i < 600 && h.flow.running; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();
    expect(h.flow.step, InstallerStep.done);
    expect(h.flow.buildSince, isNull);
  });

  group('wire formats', () {
    test('plan.rev is sent only when set', () {
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'h',
        adminUser: 'u',
        adminPassword: 'p',
      );
      expect(plan.toJson().containsKey('rev'), isFalse);
      const withRev = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'h',
        adminUser: 'u',
        adminPassword: 'p',
        rev: 'abc',
      );
      expect(withRev.toJson()['rev'], 'abc');
    });

    test('the done line carries rev and version', () {
      final e = parseProgressLine(
        '{"phase":"apps","stage":"done","percent":100,"level":"info",'
        '"message":"HinterOS 0.7.1 is installed","failed_apps":[],'
        '"rev":"$stableRev","version":"0.7.1"}',
      )!;
      expect(e.rev, stableRev);
      expect(e.version, '0.7.1');
    });

    test('check output: a newer rev without a version, a bad shape', () {
      final r = parseNewerCheck(
        '{"channel":"stable","iso":{"rev":"$stableRev","version":"0.7.0"},'
        '"newer":{"rev":"${'a' * 40}","version":"","date":1,"signer":"x"}}',
      );
      expect(r.newer!.version, 'a' * 12);
      expect(
        () => parseNewerCheck('{"channel":"stable","iso":{"rev":"x"}}'),
        throwsFormatException,
      );
      expect(
        () => parseNewerCheck('{"channel":"other","iso":null}'),
        throwsFormatException,
      );
    });

    test('version names, the way the launcher names them', () {
      const rev = '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d';
      expect(
        installVersionLabel('0.7.0', rev, InstallChannel.stable),
        'HinterOS 0.7.0 stable (1a2b3c4)',
      );
      expect(
        installVersionLabel('0.7.0', rev, InstallChannel.beta),
        'HinterOS 0.7.1.1a2b3c4 beta',
      );
    });
  });
}
