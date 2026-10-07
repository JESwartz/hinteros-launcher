import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the runtime settings on the real repositories over
/// the mock daemon (session API 0.7): the Bluetooth passkey, a refused Wi-Fi
/// password, a display that cannot change, a refused power action and a section
/// whose service is missing. 1920x1080; `nix run .#update-goldens`.
void main() {
  Harness harness([LauncherSettings settings = const LauncherSettings()]) {
    final mock = MockDaemon(
      apps: appsWithIcons(),
      games: gamesWithArt(),
      now: fixedNow,
    );
    return Harness(
      mock: mock,
      settings: settings,
      realServices: daemonSystemServices(mock),
    );
  }

  Future<void> shot(
    WidgetTester t,
    String name,
    Harness h, {
    Future<void> Function(WidgetTester)? run,
  }) async {
    setView(t);
    await h.pump(t);
    // The startup update check holds a job; the golden is about the setting.
    await t.pump();
    final job = h.mock.system.runningJobId;
    if (job != null) h.mock.system.finishJob(job);
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    await run?.call(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  const hc160 = LauncherSettings(textScale: 1.6, highContrast: true);

  testWidgets('Bluetooth: compare the code on both screens', (t) async {
    await shot(
      t,
      'bt_pair_confirm_1080p',
      harness(),
      run: (t) async {
        await enterSettingsEntry(t, 'bt');
        await press(t, [kEnter, kDown, kDown, kDown, kDown, kEnter]);
        await press(t, [kRight, kEnter]);
      },
    );
  });

  testWidgets('Bluetooth: type the code on the device, high contrast 1.6x', (
    t,
  ) async {
    await shot(
      t,
      'bt_pair_display_code_highcontrast_text160_1080p',
      harness(hc160),
      run: (t) async {
        await enterSettingsEntry(t, 'bt');
        await press(t, [kEnter, kDown, kDown, kDown, kEnter]);
        await press(t, [kRight, kEnter]);
      },
    );
  });

  testWidgets('Bluetooth: BlueZ is not there', (t) async {
    final h = harness();
    h.mock.runtime.setUnavailable('bluez');
    await shot(
      t,
      'settings_bt_unavailable_1080p',
      h,
      run: (t) => enterSettingsEntry(t, 'bt'),
    );
  });

  testWidgets('Wi-Fi: the password was not accepted', (t) async {
    await shot(
      t,
      'wifi_wrong_password_1080p',
      harness(),
      run: (t) async {
        await enterSettingsEntry(t, 'net');
        await press(t, [kDown, kDown, kDown, kDown, kDown, kEnter]);
        await t.enterText(find.byType(TextField), 'nope nope');
        await press(t, [kEnter]);
      },
    );
  });

  testWidgets('Wi-Fi: connected, no internet (daemon status)', (t) async {
    final h = harness();
    h.mock.runtime.connectivity = Connectivity.limited;
    await shot(
      t,
      'settings_net_no_internet_1080p',
      h,
      run: (t) => enterSettingsEntry(t, 'net'),
    );
  });

  testWidgets('Display: this display cannot change its mode', (t) async {
    final h = harness();
    h.mock.runtime.displayCanSet = false;
    await shot(
      t,
      'settings_display_cannot_set_1080p',
      h,
      run: (t) => enterSettingsEntry(t, 'display'),
    );
  });

  testWidgets('Display: keep or go back, from the daemon', (t) async {
    await shot(
      t,
      'display_keep_daemon_1080p',
      harness(),
      run: (t) async {
        await enterSettingsEntry(t, 'display');
        await press(t, [kDown, kDown, kEnter]);
        await t.pump(const Duration(seconds: 3));
      },
    );
  });

  testWidgets('Power: refused while an update is being applied', (t) async {
    final h = harness();
    h.mock.runtime.inhibited = true;
    await shot(
      t,
      'power_inhibited_1080p',
      h,
      run: (t) async {
        await enterSettingsEntry(t, 'power');
        await press(t, [kEnter]);
      },
    );
  });

  testWidgets('Power: logind allows only some actions', (t) async {
    final h = harness();
    h.mock.runtime.powerCapabilities = const PowerCapabilities(
      suspend: PowerCapability.no,
      reboot: PowerCapability.yes,
      poweroff: PowerCapability.challenge,
    );
    await shot(
      t,
      'settings_power_restricted_1080p',
      h,
      run: (t) => enterSettingsEntry(t, 'power'),
    );
  });
}
