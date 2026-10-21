import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/server.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the Server tab at 1920x1080: the list, each
/// service's page (off, Jellyfin, Plex to link, Tailscale signed in,
/// Cloudflare without a token), the Tailscale sign-in on the job page,
/// Add library, the folder picker and the accounts. Regenerate with
/// `nix run .#update-goldens`.
void main() {
  Harness harness({
    LauncherSettings settings = const LauncherSettings(),
    void Function(MockServer s)? setUp,
  }) {
    final services = MockSystemServices(iconDir: iconDir(), now: fixedNow);
    setUp?.call(services.mockServer);
    return Harness(settings: settings, services: services);
  }

  /// The rows: Cloudflare Tunnel, Jellyfin server, Plex Media Server,
  /// Tailscale.
  Future<void> shot(
    WidgetTester t,
    String name,
    Harness h, {
    int? row,
    Future<void> Function(WidgetTester)? run,
  }) async {
    setView(t);
    await h.pump(t);
    await openServer(t);
    if (row != null) await press(t, [...List.filled(row, kDown), kEnter]);
    await run?.call(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  /// Every state at once.
  void mixed(MockServer s) {
    s.cloudflare
      ..enabled = true
      ..tokenSet = true;
    s.tailscale
      ..enabled = true
      ..status = UnitStatus.activating;
  }

  testWidgets('the tab', (t) async {
    await shot(t, 'server_tab_1080p', harness(setUp: mixed));
  });

  testWidgets('the tab, high contrast, text 1.6x', (t) async {
    await shot(
      t,
      'server_tab_highcontrast_text160_1080p',
      harness(
        settings: const LauncherSettings(highContrast: true, textScale: 1.6),
        setUp: mixed,
      ),
    );
  });

  testWidgets('a service that is off', (t) async {
    await shot(t, 'server_off_1080p', harness(), row: 3);
  });

  testWidgets('Jellyfin', (t) async {
    await shot(t, 'server_jellyfin_1080p', harness(), row: 1);
  });

  testWidgets('Plex to link', (t) async {
    await shot(t, 'server_plex_1080p', harness(), row: 2);
  });

  testWidgets('Plex to link, high contrast, text 1.6x', (t) async {
    await shot(
      t,
      'server_plex_highcontrast_text160_1080p',
      harness(
        settings: const LauncherSettings(highContrast: true, textScale: 1.6),
      ),
      row: 2,
    );
  });

  testWidgets('Tailscale signed in', (t) async {
    await shot(
      t,
      'server_tailscale_1080p',
      harness(
        setUp: (s) => s.tailscale
          ..enabled = true
          ..tailscale = TailscaleState.running,
      ),
      row: 3,
    );
  });

  testWidgets('Tailscale: the sign-in on the job page', (t) async {
    final h = harness(setUp: (s) => s.tailscale.enabled = true);
    await shot(
      t,
      'server_tailscale_signin_1080p',
      h,
      row: 3,
      run: (t) async {
        await press(t, [kEnter]); // Sign in
        await enterPin(t, '2468');
        final j = h.services.mockJobs.runningJob!;
        h.services.mockJobs.progress(
          j.jobId,
          JobStage.signingIn,
          authUrl: 'https://login.tailscale.com/a/1a2b3c4d5e6f',
        );
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('Cloudflare without a token', (t) async {
    await shot(
      t,
      'server_cloudflare_1080p',
      harness(setUp: (s) => s.cloudflare.enabled = true),
      row: 0,
    );
  });

  testWidgets('Add library', (t) async {
    await shot(
      t,
      'server_add_library_1080p',
      harness(),
      row: 1,
      run: (t) async {
        await press(t, [kDown, kDown, kEnter]); // Add library
        await press(t, [kEnter]); // Folder
        await press(t, [kDown, kDown, kDown, kEnter]); // TV
        await press(t, [kDown, kDown, kEnter]); // Series
      },
    );
  });

  testWidgets('the folder picker', (t) async {
    await shot(
      t,
      'server_folders_1080p',
      harness(),
      row: 1,
      run: (t) async {
        await press(t, [kDown, kDown, kEnter]);
        await press(t, [kEnter]);
        await press(t, [kEnter]); // Movies
      },
    );
  });

  testWidgets('the Jellyfin accounts', (t) async {
    await shot(
      t,
      'server_accounts_1080p',
      harness(),
      row: 1,
      run: (t) async {
        await press(t, [kDown, kDown, kDown, kEnter]); // Show accounts
        await enterPin(t, '2468');
      },
    );
  });
}
