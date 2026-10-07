import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/nav_controller.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/ui/app_selection.dart';

import '../support/harness.dart';
import '../support/modal_host_harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the system screens (Settings > System, the progress
/// page, the Store, the terms page, the security notice, the installer app
/// selection), all at 1920x1080. Regenerate with `nix run .#update-goldens`.
void main() {
  Harness harness({
    LauncherSettings settings = const LauncherSettings(),
    UpdateStatus? status,
    Set<String>? installed,
  }) {
    final services = MockSystemServices(
      iconDir: iconDir(),
      now: fixedNow,
      status: status,
    );
    if (installed != null) services.mockStore.setInstalled(installed);
    return Harness(settings: settings, services: services);
  }

  Future<void> shot(
    WidgetTester t,
    String name,
    Harness h, {
    Future<void> Function(WidgetTester)? run,
  }) async {
    setView(t);
    await h.pump(t);
    await run?.call(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  const hc160 = LauncherSettings(textScale: 1.6, highContrast: true);

  group('Settings > System', () {
    for (final id in ['net', 'display', 'audio', 'power', 'ssh', 'about']) {
      testWidgets('settings $id', (t) async {
        await shot(
          t,
          'settings_sys_${id}_1080p',
          harness(),
          run: (t) => enterSettingsEntry(t, id),
        );
      });
    }
    testWidgets('settings bluetooth after a scan', (t) async {
      await shot(
        t,
        'settings_sys_bt_1080p',
        harness(),
        run: (t) async {
          await enterSettingsEntry(t, 'bt');
          await press(t, [kEnter, kDown, kDown, kDown]);
        },
      );
    });
    testWidgets('settings updates with an update available', (t) async {
      final h = harness();
      h.services.mockUpdates.nextAvailable = mockOrdinaryUpdate();
      await shot(
        t,
        'settings_sys_updates_1080p',
        h,
        run: (t) async {
          // The startup check found the update: Home shows the reminder
          // banner, whose "See update" opens Settings > Updates.
          await press(t, [kUp, kEnter]);
        },
      );
    });
    testWidgets('settings network, text 1.6x, high contrast', (t) async {
      await shot(
        t,
        'settings_sys_net_highcontrast_text160_1080p',
        harness(settings: hc160),
        run: (t) async {
          await enterSettingsEntry(t, 'net');
          await press(t, [kDown, kDown, kDown]);
        },
      );
    });
    testWidgets('admin password for SSH (masked)', (t) async {
      await shot(
        t,
        'ssh_admin_password_1080p',
        harness(),
        run: (t) async {
          await enterSettingsEntry(t, 'ssh');
          await press(t, [kEnter]);
          await t.enterText(find.byType(TextField), 'secret');
          await t.pumpAndSettle();
        },
      );
    });
    testWidgets('SSH needs an admin (the real daemon, no polkit agent)', (
      t,
    ) async {
      final mock = MockDaemon(
        apps: appsWithIcons(),
        games: gamesWithArt(),
        now: fixedNow,
      );
      await shot(
        t,
        'ssh_needs_admin_1080p',
        Harness(mock: mock, realServices: daemonSystemServices(mock)),
        run: (t) async {
          await enterSettingsEntry(t, 'ssh');
          await press(t, [kEnter]);
        },
      );
    });
    testWidgets('About on a developer build: DEV badge, host keys', (t) async {
      final h = harness();
      h.services.mockSystem.dev = true;
      await shot(
        t,
        'about_dev_1080p',
        h,
        run: (t) => enterSettingsEntry(t, 'about'),
      );
    });
    testWidgets('settings unavailable (the system service is down)', (t) async {
      final mock = MockDaemon(
        apps: appsWithIcons(),
        games: gamesWithArt(),
        now: fixedNow,
      );
      mock.system.unavailable = SystemUnavailableDataReason.down;
      await shot(
        t,
        'settings_unavailable_1080p',
        Harness(mock: mock, realServices: daemonSystemServices(mock)),
        run: (t) => enterSettingsEntry(t, 'about'),
      );
    });
    testWidgets('Wi-Fi password dialog', (t) async {
      await shot(
        t,
        'wifi_password_1080p',
        harness(),
        run: (t) async {
          await enterSettingsEntry(t, 'net');
          await press(t, [kDown, kDown, kDown, kDown, kEnter]);
          await t.enterText(find.byType(TextField), 'wrong');
          await press(t, [kEnter]);
        },
      );
    });
    testWidgets('safe area guide', (t) async {
      await shot(
        t,
        'display_safe_area_1080p',
        harness(),
        run: (t) async {
          await enterSettingsEntry(t, 'display');
          await press(t, [kEnter]);
        },
      );
    });
    testWidgets('keep this resolution', (t) async {
      await shot(
        t,
        'display_keep_1080p',
        harness(),
        run: (t) async {
          await enterSettingsEntry(t, 'display');
          await press(t, [kDown, kEnter]);
        },
      );
    });
  });

  group('progress', () {
    Future<void> startUpdate(WidgetTester t, Harness h) async {
      h.services.mockUpdates.nextAvailable = mockOrdinaryUpdate();
      await enterSettingsEntry(t, 'updates');
      await press(t, [kEnter, kDown, kEnter, kRight, kEnter]);
    }

    testWidgets('downloading, 40 percent', (t) async {
      final h = harness();
      await shot(
        t,
        'progress_downloading_1080p',
        h,
        run: (t) async {
          await startUpdate(t, h);
          h.services.mockJobs.progress(
            h.services.mockJobs.started.single.jobId,
            JobStage.downloading,
            percent: 40,
            detail: '212 of 530 MB',
          );
          await t.pumpAndSettle();
        },
      );
    });
    testWidgets('done, session restart offered', (t) async {
      final h = harness();
      h.services.mockJobs.restartNext = true;
      await shot(
        t,
        'progress_restart_session_1080p',
        h,
        run: (t) async {
          await startUpdate(t, h);
          h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
          await t.pumpAndSettle();
        },
      );
    });
    testWidgets('failure says nothing changed', (t) async {
      final h = harness();
      await shot(
        t,
        'progress_failed_1080p',
        h,
        run: (t) async {
          await startUpdate(t, h);
          h.services.mockJobs.finish(
            h.services.mockJobs.started.single.jobId,
            ok: false,
            error: const JobError(
              message: 'The cache could not be reached.',
              stage: JobStage.downloading,
              logHint: 'hinteros-job@7f3a.service',
            ),
          );
          await t.pumpAndSettle();
        },
      );
    });
    testWidgets('activating: cannot cancel, high contrast, text 1.6x', (
      t,
    ) async {
      final h = harness(settings: hc160);
      await shot(
        t,
        'progress_activating_highcontrast_text160_1080p',
        h,
        run: (t) async {
          await startUpdate(t, h);
          h.services.mockJobs.progress(
            h.services.mockJobs.started.single.jobId,
            JobStage.activating,
          );
          await t.pumpAndSettle();
        },
      );
    });
  });

  group('security notice and reminder', () {
    testWidgets('security notice, 3 seconds left', (t) async {
      await shot(
        t,
        'security_notice_1080p',
        harness(status: mockBehind(mockSecurityUpdate())),
        run: (t) => t.pump(const Duration(seconds: 2)),
      );
    });
    testWidgets('security notice unlocked, high contrast, text 1.6x', (
      t,
    ) async {
      await shot(
        t,
        'security_notice_highcontrast_text160_1080p',
        harness(settings: hc160, status: mockBehind(mockSecurityUpdate())),
        run: (t) => t.pump(const Duration(seconds: 5)),
      );
    });
    testWidgets('security notice, 4 seconds left, high contrast, text 1.6x', (
      t,
    ) async {
      await shot(
        t,
        'security_notice_locked_highcontrast_text160_1080p',
        harness(settings: hc160, status: mockBehind(mockSecurityUpdate())),
        run: (t) => t.pump(const Duration(seconds: 1)),
      );
    });
    testWidgets('home with the update reminder', (t) async {
      await shot(
        t,
        'home_update_reminder_1080p',
        harness(status: mockBehind(mockOrdinaryUpdate())),
      );
    });
  });

  group('Store', () {
    testWidgets('all', (t) async {
      await shot(t, 'store_all_1080p', harness(), run: openStore);
    });
    testWidgets('games, text 1.6x, high contrast', (t) async {
      await shot(
        t,
        'store_games_highcontrast_text160_1080p',
        harness(settings: hc160),
        run: (t) async {
          await openStore(t);
          await press(t, [kDown, kRight]);
        },
      );
    });
    testWidgets('app detail, not installed', (t) async {
      await shot(
        t,
        'store_app_detail_1080p',
        harness(installed: {'jellyfin'}),
        run: (t) async {
          await openStore(t);
          await press(t, [kDown, kRight, kEnter]);
        },
      );
    });
    testWidgets('install confirm with dependencies', (t) async {
      await shot(
        t,
        'store_install_confirm_1080p',
        harness(installed: {'jellyfin'}),
        run: (t) async {
          await openStore(t);
          await press(t, [kDown, kRight, kDown, kEnter, kEnter]);
        },
      );
    });
    testWidgets('terms of an app', (t) async {
      await shot(
        t,
        'terms_1080p',
        harness(installed: {'jellyfin'}),
        run: (t) async {
          await openStore(t);
          await press(t, [
            kDown,
            kRight,
            kRight,
            kEnter,
            kEnter,
            kRight,
            kEnter,
          ]);
        },
      );
    });
    testWidgets('terms scrolled to the end, high contrast, text 1.6x', (
      t,
    ) async {
      await shot(
        t,
        'terms_end_highcontrast_text160_1080p',
        harness(settings: hc160, installed: {'jellyfin'}),
        run: (t) async {
          await openStore(t);
          await press(t, [
            kDown,
            kRight,
            kRight,
            kEnter,
            kEnter,
            kRight,
            kEnter,
          ]);
          for (var i = 0; i < 80; i++) {
            await t.sendKeyEvent(kPageDown);
            await t.pump();
          }
          await t.pumpAndSettle();
        },
      );
    });
    testWidgets('terms, high contrast, text 1.6x, from the top', (t) async {
      await shot(
        t,
        'terms_highcontrast_text160_1080p',
        harness(settings: hc160, installed: {'jellyfin'}),
        run: (t) async {
          await openStore(t);
          await press(t, [
            kDown,
            kRight,
            kRight,
            kEnter,
            kEnter,
            kRight,
            kEnter,
          ]);
        },
      );
    });
    testWidgets('remove asks to delete data (Steam warns)', (t) async {
      await shot(
        t,
        'store_remove_confirm_1080p',
        harness(),
        run: (t) async {
          await openStore(t);
          await press(t, [
            kDown,
            kRight,
            kRight,
            kEnter,
            kRight,
            kEnter,
            kEnter,
          ]);
        },
      );
    });
    testWidgets('second confirmation of data deletion', (t) async {
      await shot(
        t,
        'store_delete_data_confirm_1080p',
        harness(),
        run: (t) async {
          await openStore(t);
          await press(t, [
            kDown, kRight, kRight, kEnter, kRight, kEnter, // Steam, Remove
            kEnter, kDown, kRight, kEnter, // tick, Remove
          ]);
        },
      );
    });
    testWidgets('Games tab asks to install Steam', (t) async {
      await shot(
        t,
        'games_steam_missing_1080p',
        harness(installed: {'jellyfin'}),
        run: (t) => openTab(t, 1),
      );
    });
  });

  testWidgets('installer app selection', (t) async {
    setView(t);
    final c = AppSelectionController(mockCatalog());
    final host = ModalTestHost();
    final region = NavRegion('selection');
    host.nav.adopt(region);
    await host.pump(
      t,
      (_) => Padding(
        padding: const EdgeInsets.all(96),
        child: AppSelectionView(
          controller: c,
          region: region,
          onContinue: () {},
        ),
      ),
    );
    host.nav.focusRegion(region);
    await t.pumpAndSettle();
    await host.act(t, NavAction.accept); // Steam: needs terms
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/installer_app_selection_1080p.png'),
    );
  });
}
