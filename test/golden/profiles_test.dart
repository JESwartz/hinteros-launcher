import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show Connecting;
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/ui/profiles/profile_loading.dart';

import '../profiles/loading_test.dart' show appWith, public;
import '../profiles/session_ending_test.dart' show removeOwnProfile;
import '../profiles/session_test.dart'
    show frames, harness, keys, openChip, typePin;
import '../profiles/store_profile_test.dart' show termsHarness;
import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Golden screenshots of the profile screens inside a session.
/// Regenerate with `nix run .#update-goldens`.
void main() {
  Future<void> shot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/profiles_${name}_1080p.png'),
  );

  testWidgets('chip menu', (t) async {
    setView(t);
    await harness().pump(t);
    await openChip(t);
    await shot(t, 'chip_menu');
  });

  testWidgets('switch picker', (t) async {
    setView(t);
    await harness().pump(t);
    await openChip(t);
    await keys(t, [kEnter]);
    await shot(t, 'switch_picker');
  });

  testWidgets('not responding', (t) async {
    setView(t);
    final h = harness();
    h.services.mockProfiles.blockingApp = (id: 'youtube', name: 'YouTube');
    await h.pump(t);
    await openChip(t);
    await keys(t, [kEnter, kRight, kEnter]);
    await typePin(t, '1357', settle: false); // Sam is locked
    await frames(t, 10);
    await shot(t, 'not_responding');
  });

  testWidgets('lock screen', (t) async {
    setView(t);
    final h = harness(current: 'p3');
    await h.pump(t);
    h.services.mockProfiles.sleep();
    await t.pumpAndSettle();
    await shot(t, 'lock_screen');
  });

  testWidgets('settings profiles', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'profiles');
    await shot(t, 'settings');
  });

  testWidgets('settings profiles, high contrast, text 1.6x', (t) async {
    setView(t);
    final h = Harness(
      settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      services: MockSystemServices(iconDir: iconDir(), now: fixedNow),
    );
    await h.pump(t);
    await enterSettingsEntry(t, 'profiles');
    await shot(t, 'settings_highcontrast_text160');
  });

  testWidgets('remove: the PIN with Delete held', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'profiles');
    // Sam, Remove (after Switch to this profile, Rename, new PIN), Remove.
    await keys(t, [kDown, kEnter, kDown, kDown, kDown, kEnter, kRight, kEnter]);
    for (final c in '2468'.split('')) {
      await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
    }
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    await shot(t, 'delete_pin_hold');
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
  });

  testWidgets('switch to a locked profile: its PIN in this session', (t) async {
    setView(t);
    await harness().pump(t);
    await openChip(t);
    await keys(t, [kEnter, kRight, kEnter]);
    await shot(t, 'switch_pin');
  });

  testWidgets('first boot: create your profile', (t) async {
    setView(t);
    final h = harness(
      setupRequired: true,
      box: MockProfileBox(profiles: [], now: fixedNow),
    );
    await h.pump(t);
    await keys(t, [kEnter]);
    for (
      var i = 0;
      i < 30 && find.text('Step 1 of 5').evaluate().isEmpty;
      i++
    ) {
      await keys(t, [kDown]);
      if (focusLabel()?.endsWith('/actions:0') ?? false) {
        await keys(t, [kEnter]);
      }
    }
    await shot(t, 'first_boot_name');
  });

  moreGoldens();
}

void moreGoldens() {
  Future<void> shot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/profiles_${name}_1080p.png'),
  );

  testWidgets('first-launch terms', (t) async {
    setView(t);
    final h = termsHarness();
    await h.pump(t);
    await keys(t, [kEnter]);
    await shot(t, 'first_launch_terms');
  });

  testWidgets('Store: needs a service', (t) async {
    setView(t);
    final h = Harness(
      services: MockSystemServices(
        iconDir: iconDir(),
        now: fixedNow,
        extraApps: const [mockServiceApp],
      ),
    );
    await h.pump(t);
    await openStore(t);
    for (var i = 0; i < 8; i++) {
      if (find.text('Crunchyroll').evaluate().isEmpty &&
          find.text('Music library').evaluate().isNotEmpty) {
        break;
      }
      await keys(t, [kDown]);
    }
    await keys(t, [kRight, kEnter]);
    await shot(t, 'store_needs_service');
  });

  testWidgets('rollback: profiles that go away or come back empty', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'updates');
    for (var i = 0; i < 10; i++) {
      if (focusLabel()?.endsWith('/rollback:0') ?? false) break;
      await keys(t, [kDown]);
    }
    await keys(t, [kEnter]);
    await shot(t, 'rollback_profiles');
  });

  testWidgets('rollback that turns box features back on (0.13)', (t) async {
    setView(t);
    await harness().pump(t);
    await enterSettingsEntry(t, 'updates');
    // check, channel, rollback, generations 12, 11, 10.
    await keys(t, [kDown, kDown, kDown, kDown, kDown, kEnter]);
    await shot(t, 'rollback_readds');
    // Roll back: the admin PIN first.
    await keys(t, [kRight, kEnter]);
    await shot(t, 'rollback_admin_pin');
  });

  testWidgets('End guest session: removed now', (t) async {
    setView(t);
    await harness(current: 'guest').pump(t);
    await openChip(t);
    await keys(t, [kDown, kEnter]);
    await shot(t, 'end_guest_confirm');
  });

  testWidgets('first frame: loading the profile', (t) async {
    setView(t);
    final h = Harness(mock: StuckConnection(const Connecting()));
    await t.pumpWidget(
      appWith(h, LoadingIdentity.fromPublicJson(public, 'hinteros')),
    );
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'startup_loading');
  });

  testWidgets('removing your own profile: the session ends', (t) async {
    final h = await removeOwnProfile(t);
    // The service has gone with the session: still only this page.
    h.mock.simulateDisconnect();
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'removing_own');
  });
}
