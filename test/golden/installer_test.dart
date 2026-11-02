import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart' show pumpFor;
import '../support/installer_harness.dart';

/// Golden screenshots of the installer screens at 1920x1080 (and the
/// summary in high contrast). Regenerate with `nix run .#update-goldens`.
void main() {
  const wired = NetworkState(
    wiredConnected: true,
    wifiAvailable: true,
    online: true,
  );

  Future<void> shot(
    WidgetTester t,
    String name, {
    FakeInstallerBackend? backend,
    LauncherSettings settings = const LauncherSettings(),
    bool settle = true,
    DateTime Function()? clock,
    required Future<void> Function(InstallerHarness h) setup,
  }) async {
    final h = InstallerHarness(
      backend: backend,
      settings: settings,
      clock: clock,
    );
    await h.pump(t);
    await h.flow.refreshNetwork();
    await h.flow.loadCatalog();
    await h.flow.loadDisks();
    await setup(h);
    // A running install must not move on while the screen settles.
    if (settle) await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/installer_${name}_1080p.png'),
    );
  }

  /// Everything filled in, on the summary screen.
  Future<void> filled(InstallerHarness h, WidgetTester t) async {
    h.flow.chooseDisk(h.flow.disks!.first);
    h.flow.setUsername('james');
    h.flow.setPassword('change-me-now');
    h.flow.setRepeat('change-me-now');
    h.flow.go(InstallerStep.summary);
    await t.pumpAndSettle();
  }

  testWidgets('welcome', (t) async {
    await shot(t, 'welcome', setup: (h) async {});
  });

  testWidgets('network with Wi-Fi networks, joined', (t) async {
    final b = FakeInstallerBackend(
      state: const NetworkState(wifiAvailable: true),
      wifiPasswords: {'Living Room': 'correct horse'},
    );
    await shot(
      t,
      'network',
      backend: b,
      setup: (h) async {
        h.flow.go(InstallerStep.network);
        await t.pumpAndSettle();
        await h.choose(t, 'w:Living Room');
        await h.type(t, 'correct horse');
        await h.moveTo(t, 'actions', 1);
      },
    );
  });

  testWidgets('network offline', (t) async {
    await shot(
      t,
      'network_offline',
      backend: FakeInstallerBackend(
        state: const NetworkState(wifiAvailable: true),
      ),
      setup: (h) async {
        h.flow.go(InstallerStep.network);
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('network checking', (t) async {
    final gate = Completer<void>();
    await shot(
      t,
      'network_checking',
      backend: FakeInstallerBackend(state: wired),
      settle: false,
      setup: (h) async {
        h.flow.go(InstallerStep.network);
        await t.pumpAndSettle();
        h.backend.networkHold = gate.future;
        unawaited(h.flow.refreshNetwork());
        await t.pump(const Duration(milliseconds: 700));
      },
    );
    gate.complete();
    await t.pumpAndSettle();
  });

  testWidgets('disk: usable and unusable disks', (t) async {
    await shot(
      t,
      'disk',
      setup: (h) async {
        h.flow.go(InstallerStep.disk);
        await t.pumpAndSettle();
        await h.choose(t, 'd0');
        await h.moveTo(t, 'actions', 1);
      },
    );
  });

  /// From the internet step on, as the installer goes: right to the disk
  /// step when an install can be kept.
  Future<void> leaveNetwork(InstallerHarness h, WidgetTester t) async {
    h.flow.go(InstallerStep.network);
    await t.pumpAndSettle();
    h.flow.next();
    await t.pumpAndSettle();
  }

  /// The disk step with the disk that has HinterOS on it chosen.
  Future<void> toKeepChoice(InstallerHarness h, WidgetTester t) async {
    await leaveNetwork(h, t);
    h.flow.go(InstallerStep.disk);
    await t.pumpAndSettle();
    await h.choose(t, 'd1');
    await h.moveTo(t, 'actions', 1);
  }

  /// [existing] on the disk with HinterOS on it.
  List<DiskInfo> withExisting(ExistingInstall existing) {
    final d = mockDisks();
    return [d[0], d[1].withInstall(existing), ...d.skip(2)];
  }

  testWidgets('disk: Keep data or Erase all', (t) async {
    await shot(t, 'disk_keep', setup: (h) => toKeepChoice(h, t));
  });

  testWidgets('disk: Keep data would install an older HinterOS', (t) async {
    await shot(
      t,
      'disk_keep_older',
      backend: FakeInstallerBackend(
        disks: withExisting(
          const ExistingInstall(schemaOk: true, version: '0.9.0'),
        ),
      ),
      setup: (h) => toKeepChoice(h, t),
    );
  });

  testWidgets('disk: an install that cannot be kept', (t) async {
    await shot(
      t,
      'disk_keep_refused',
      backend: FakeInstallerBackend(
        disks: withExisting(
          const ExistingInstall(schemaOk: false, version: '9.0.0'),
        ),
      ),
      setup: (h) => toKeepChoice(h, t),
    );
  });

  testWidgets('account with a password that does not match', (t) async {
    await shot(
      t,
      'account',
      setup: (h) async {
        h.flow.go(InstallerStep.account);
        await t.pumpAndSettle();
        h.flow.setUsername('james');
        h.flow.setPassword('change-me-now');
        h.flow.setRepeat('change-me-nod');
        await t.pumpAndSettle();
        await h.moveTo(t, 'pw2');
      },
    );
  });

  testWidgets('the in-app keyboard, typing a password', (t) async {
    await shot(
      t,
      'keyboard',
      setup: (h) async {
        h.flow.go(InstallerStep.account);
        await t.pumpAndSettle();
        await h.choose(t, 'pw');
        // Eight keys with the controller, along the first row.
        for (var i = 0; i < 8; i++) {
          await h.accept(t);
          await h.press(t, NavAction.right);
        }
        await t.pump(const Duration(seconds: 2));
      },
    );
  });

  testWidgets('options', (t) async {
    await shot(
      t,
      'options',
      setup: (h) async {
        h.flow.go(InstallerStep.options);
        await t.pumpAndSettle();
        await h.moveTo(t, 'ssh');
      },
    );
  });

  testWidgets('options, Keep data', (t) async {
    await shot(
      t,
      'options_keep',
      setup: (h) async {
        await toKeepChoice(h, t);
        await h.accept(t);
        await h.choose(t, 'actions');
        expect(h.flow.step, InstallerStep.options);
      },
    );
  });

  testWidgets('account, Keep data', (t) async {
    await shot(
      t,
      'account_keep',
      setup: (h) async {
        await toKeepChoice(h, t);
        await h.accept(t);
        expect(h.flow.step, InstallerStep.account);
      },
    );
  });

  testWidgets('apps, offline', (t) async {
    await shot(
      t,
      'apps_offline',
      setup: (h) async {
        h.flow.go(InstallerStep.apps);
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('apps, online, with terms to accept', (t) async {
    await shot(
      t,
      'apps_online',
      backend: FakeInstallerBackend(state: wired),
      setup: (h) async {
        h.flow.go(InstallerStep.apps);
        await t.pumpAndSettle();
        final steam = h.flow.apps!.apps.indexWhere((a) => a.id == 'steam');
        await h.choose(t, 'a$steam');
      },
    );
  });

  testWidgets('summary', (t) async {
    await shot(
      t,
      'summary',
      setup: (h) async {
        h.flow.toggleSsh();
        await filled(h, t);
      },
    );
  });

  testWidgets('summary, high contrast and large text', (t) async {
    await shot(
      t,
      'summary_highcontrast',
      settings: const LauncherSettings(highContrast: true, textScale: 1.4),
      setup: (h) => filled(h, t),
    );
  });

  /// Keep data, on the summary screen.
  Future<void> keepSummary(InstallerHarness h, WidgetTester t) async {
    await leaveNetwork(h, t);
    h.flow.chooseDisk(h.flow.disks![1]);
    h.flow.go(InstallerStep.summary);
    await t.pumpAndSettle();
  }

  testWidgets('summary, Keep data', (t) async {
    await shot(t, 'summary_keep', setup: (h) => keepSummary(h, t));
  });

  testWidgets('summary, Keep data, high contrast and large text', (t) async {
    await shot(
      t,
      'summary_keep_highcontrast',
      settings: const LauncherSettings(highContrast: true, textScale: 1.4),
      setup: (h) => keepSummary(h, t),
    );
  });

  testWidgets('progress, Keep data', (t) async {
    await shot(
      t,
      'progress_keep',
      backend: FakeInstallerBackend(delay: const Duration(milliseconds: 50)),
      settle: false,
      setup: (h) async {
        await keepSummary(h, t);
        h.flow.go(InstallerStep.install);
        unawaited(h.flow.startInstall());
        for (var i = 0; i < 600 && h.flow.percent < 20; i++) {
          await t.pump(const Duration(milliseconds: 10));
        }
      },
    );
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the install that keeps data did not finish (exit 1)', (t) async {
    await shot(
      t,
      'failed_keep',
      backend: FakeInstallerBackend()..installScript = FakeScript.failed(),
      setup: (h) async {
        await keepSummary(h, t);
        await h.choose(t, 'actions', 1);
      },
    );
  });

  testWidgets('summary, Erase and install held for 2 of 5 seconds', (t) async {
    InstallerHarness? held;
    await shot(
      t,
      'summary_hold',
      settle: false,
      setup: (h) async {
        held = h;
        await filled(h, t);
        await h.moveTo(t, 'actions', 1);
        h.console(t).action(NavAction.accept, NavPhase.press);
        await pumpFor(t, const Duration(seconds: 2));
      },
    );
    held!.console(t).action(NavAction.accept, NavPhase.release);
    await t.pumpAndSettle();
    expect(held!.flow.step, InstallerStep.summary);
  });

  testWidgets('progress with a warning', (t) async {
    final b = FakeInstallerBackend(delay: const Duration(milliseconds: 50));
    await shot(
      t,
      'progress',
      backend: b,
      settle: false,
      setup: (h) async {
        await filled(h, t);
        await h.choose(t, 'actions', 1);
        for (var i = 0; i < 400 && h.flow.percent < 57; i++) {
          await t.pump(const Duration(milliseconds: 10));
        }
      },
    );
    // Let the fake finish so no timer is left behind.
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the install did not start (exit 2)', (t) async {
    await shot(
      t,
      'refused',
      backend: FakeInstallerBackend()
        ..validateScript = FakeScript.refused(
          'disk-in-use',
          '/dev/nvme0n1 is in use (mounted at: /iso)',
        ),
      setup: (h) async {
        await filled(h, t);
        await h.choose(t, 'actions', 1);
      },
    );
  });

  testWidgets('the install did not finish (exit 1)', (t) async {
    await shot(
      t,
      'failed',
      backend: FakeInstallerBackend()..installScript = FakeScript.failed(),
      setup: (h) async {
        await filled(h, t);
        await h.choose(t, 'actions', 1);
      },
    );
  });

  testWidgets('done', (t) async {
    await shot(
      t,
      'done',
      setup: (h) async {
        await filled(h, t);
        await h.choose(t, 'actions', 1);
      },
    );
  });

  /// A two-stage install.
  FakeInstallerBackend twoStage({
    List<String> failing = const [],
    Duration delay = const Duration(milliseconds: 50),
  }) =>
      FakeInstallerBackend(delay: delay)
        ..installScriptFor = (plan) =>
            FakeScript.twoStage(plan.apps, failing: failing);

  Future<void> install(
    InstallerHarness h,
    WidgetTester t,
    bool Function() until,
  ) async {
    await filled(h, t);
    h.flow.go(InstallerStep.install);
    unawaited(h.flow.startInstall());
    for (var i = 0; i < 600 && !until(); i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('progress, system stage', (t) async {
    await shot(
      t,
      'progress_system',
      backend: twoStage(),
      settle: false,
      setup: (h) => install(h, t, () => h.flow.percent >= 57),
    );
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('progress, apps stage', (t) async {
    await shot(
      t,
      'progress_apps',
      backend: twoStage(failing: ['firefox']),
      settle: false,
      setup: (h) => install(
        h,
        t,
        () => h.flow.appProgress.last.state == AppInstallState.installing,
      ),
    );
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('done, some apps could not be installed', (t) async {
    await shot(
      t,
      'done_failed_apps',
      backend: twoStage(failing: ['youtube'], delay: Duration.zero),
      setup: (h) async {
        await filled(h, t);
        await h.choose(t, 'actions', 1);
      },
    );
  });

  /// Online with a newer HinterOS on the channel, on the version step.
  Future<void> toVersion(InstallerHarness h, WidgetTester t) async {
    h.flow.go(InstallerStep.network);
    await t.pumpAndSettle();
    await h.choose(t, 'actions', 1);
    expect(h.flow.step, InstallerStep.version);
  }

  testWidgets('version: a newer HinterOS on the channel', (t) async {
    await shot(
      t,
      'version',
      backend: FakeInstallerBackend(state: wired, newer: mockNewer()),
      setup: (h) => toVersion(h, t),
    );
  });

  testWidgets('version, high contrast and large text', (t) async {
    await shot(
      t,
      'version_highcontrast',
      backend: FakeInstallerBackend(state: wired, newer: mockNewer()),
      settings: const LauncherSettings(highContrast: true, textScale: 1.4),
      setup: (h) => toVersion(h, t),
    );
  });

  testWidgets('the newer HinterOS did not finish (exit 1)', (t) async {
    await shot(
      t,
      'newer_failed',
      backend: FakeInstallerBackend(state: wired, newer: mockNewer())
        ..newerInstallScript = FakeScript.failed(),
      setup: (h) async {
        await toVersion(h, t);
        await h.choose(t, 'newer');
        await filled(h, t);
        await h.choose(t, 'actions', 1);
      },
    );
  });

  testWidgets('progress, a newer HinterOS builds', (t) async {
    var now = InstallerHarness.fixedNow;
    await shot(
      t,
      'progress_build',
      // Slow lines: the time counts up between them.
      backend: FakeInstallerBackend(
        state: wired,
        newer: mockNewer(),
        delay: const Duration(seconds: 40),
      )..newerInstallScript = FakeScript.newerOk('0.7.1'),
      clock: () => now,
      settle: false,
      setup: (h) async {
        await toVersion(h, t);
        await h.choose(t, 'newer');
        await filled(h, t);
        await h.choose(t, 'actions', 1);
        for (var i = 0; i < 900 && h.flow.buildIndex != 3; i++) {
          await t.pump(const Duration(seconds: 1));
        }
        now = now.add(const Duration(minutes: 6));
        // The build line counts up by itself; a fixed spinner frame.
        await t.pump(const Duration(seconds: 15));
        expect(
          find.text(
            'Building hinteros-launcher (3 of 12): 88%. Time elapsed: 06:00',
          ),
          findsOneWidget,
        );
      },
    );
    await t.pump(const Duration(minutes: 15));
  });
}
