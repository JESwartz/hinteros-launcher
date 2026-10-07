import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/installer_harness.dart';

/// Golden screenshots of the installer screens at 1920x1080 (and the disk
/// warning in high contrast). Regenerate with `nix run .#update-goldens`.
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
    required Future<void> Function(InstallerHarness h) setup,
  }) async {
    final h = InstallerHarness(backend: backend, settings: settings);
    await h.pump(t);
    await h.flow.refreshNetwork();
    await h.flow.loadCatalog();
    await h.flow.loadDisks();
    await setup(h);
    await t.pumpAndSettle();
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
        await h.choose(t, 'w0');
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

  Future<void> firstWarning(InstallerHarness h, WidgetTester t) async {
    h.flow.go(InstallerStep.disk);
    await t.pumpAndSettle();
    await h.choose(t, 'd0');
    await h.choose(t, 'actions', 1);
  }

  testWidgets('disk: the first warning', (t) async {
    await shot(t, 'disk_warning', setup: (h) => firstWarning(h, t));
  });

  testWidgets('disk: the first warning, high contrast and large text', (
    t,
  ) async {
    await shot(
      t,
      'disk_warning_highcontrast',
      settings: const LauncherSettings(highContrast: true, textScale: 1.4),
      setup: (h) => firstWarning(h, t),
    );
  });

  testWidgets('disk: the second confirmation', (t) async {
    await shot(
      t,
      'disk_confirm',
      setup: (h) async {
        await firstWarning(h, t);
        await h.press(t, NavAction.right);
        await h.accept(t);
      },
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

  testWidgets('progress with a warning', (t) async {
    final b = FakeInstallerBackend(delay: const Duration(milliseconds: 50));
    await shot(
      t,
      'progress',
      backend: b,
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
}
