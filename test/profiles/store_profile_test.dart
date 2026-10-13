import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// The Store and apps per profile: first-launch terms of a starter-set app,
/// an app that needs a service the box does not run, the "for this profile"
/// wording.
AppNeedsTerms steamTerms() => AppNeedsTerms(
  title: 'Steam Subscriber Agreement',
  version: '2026-09-10',
  url: 'https://store.steampowered.com/subscriber_agreement/',
  retrieved: '2026-10-06',
  file:
      '${Directory.current.path}/test/fixtures/catalog/terms/steam-2026-09-10.txt',
);

Harness termsHarness() {
  final h = Harness();
  h.mock.setNeedsTerms('steam', steamTerms());
  h.services.mockStore
    ..setNeedsTerms(['steam'])
    ..onTermsAccepted = (id) => h.mock.setNeedsTerms(id, null);
  return h;
}

/// Down the terms text to its end, then onto the buttons.
Future<void> readToEnd(WidgetTester t) async {
  for (var i = 0; i < 60; i++) {
    await press(t, [kDown]);
    if (focusLabel()?.contains('/buttons:') ?? false) break;
  }
}

void main() {
  testWidgets('first launch of a starter-set app shows its terms; '
      'accepting records them and opens it', (t) async {
    setView(t);
    final h = termsHarness();
    await h.pump(t);
    expect(focusLabel(), 'home/apps:0'); // Steam
    await press(t, [kEnter]);
    expect(find.text('Terms for Steam'), findsOneWidget);
    expect(find.textContaining('Read to the end to accept'), findsOneWidget);
    expect(h.mock.running, isEmpty);
    await readToEnd(t);
    await press(t, [kRight, kEnter]); // Accept and open
    expect(h.services.mockStore.acceptances, ['steam=2026-09-10']);
    expect(h.mock.running.map((a) => a.id), ['steam']);
  });

  testWidgets('declining leaves it installed and offers Remove', (t) async {
    setView(t);
    final h = termsHarness();
    await h.pump(t);
    await press(t, [kEnter]);
    await readToEnd(t);
    await press(t, [kLeft, kEnter]); // Decline
    expect(find.text("Steam won't open"), findsOneWidget);
    expect(find.text('Remove Steam'), findsOneWidget);
    await press(t, [kEnter]); // Keep it for later
    expect(h.mock.running, isEmpty);
    expect(h.services.mockStore.acceptances, isEmpty);
  });

  testWidgets('an app that needs a service: red text, Install disabled', (
    t,
  ) async {
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
    // The Music category holds just this app.
    for (var i = 0; i < 8; i++) {
      if (find.text('Crunchyroll').evaluate().isEmpty &&
          find.text('Music library').evaluate().isNotEmpty) {
        break;
      }
      await press(t, [kDown]);
    }
    await press(t, [kRight]);
    await press(t, [kEnter]);
    expect(
      find.textContaining(
        'Music library needs Jellyfin server, which this box does not run.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not installed.'), findsOneWidget);
    await press(t, [kEnter]); // Install is disabled
    expect(find.textContaining('for this profile?'), findsNothing);
    expect(h.services.mockStore.log, isEmpty);
  });
}
