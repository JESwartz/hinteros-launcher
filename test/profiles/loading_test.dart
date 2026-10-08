import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart'
    show Connecting, Unreachable;
import 'package:hinteros_launcher/src/app.dart';
import 'package:hinteros_launcher/src/system/profiles.dart';
import 'package:hinteros_launcher/src/ui/profiles/profile_loading.dart';

import '../support/harness.dart';

/// "Loading Sam…" between the picker and Home: the identity from the
/// service's public view, the page on the session's first frames until Home
/// has its data.
const public = '''
{"version": 1, "profiles": [
  {"id": "p1", "user": "hinteros", "name": "James", "color": "teal", "locked": false, "admin": true, "locked_until": null},
  {"id": "p3", "user": "hinteros-p3", "name": "Sam", "color": "orange", "locked": true, "admin": false, "locked_until": null}],
 "guest": {"enabled": true, "user": "hinteros-guest"}, "first_boot": false}
''';

/// The harness's app with a startup identity.
Widget appWith(Harness h, LoadingIdentity id) => LauncherApp(
  data: h.data,
  settings: h.settings,
  services: h.services,
  now: fixedNow,
  startup: id,
);

void main() {
  test('the identity comes from the public view by user', () {
    final sam = LoadingIdentity.fromPublicJson(public, 'hinteros-p3');
    expect(sam.name, 'Sam');
    expect(sam.color, ProfileColor.orange);
    expect(sam.initial, 'S');
    final guest = LoadingIdentity.fromPublicJson(public, 'hinteros-guest');
    expect(guest.name, 'Guest');
    expect(guest.guest, isTrue);
    expect(LoadingIdentity.fromPublicJson(public, 'nobody').name, isNull);
    expect(LoadingIdentity.fromPublicJson('{nope', 'hinteros').name, isNull);
    expect(
      LoadingIdentity.fromPublicView(
        'hinteros',
        path: '/nonexistent/profiles-public.json',
      ).name,
      isNull,
    );
  });

  testWidgets('the first frame is "Loading James…", then Home', (t) async {
    setView(t);
    final h = Harness();
    await h.precacheArt(t);
    await h.precacheIcons(t);
    await t.pumpWidget(
      appWith(h, LoadingIdentity.fromPublicJson(public, 'hinteros')),
    );
    expect(find.text('Loading James…'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-loading')), findsOneWidget);
    // The mock answers: Home's data is there, the page goes.
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('profile-loading')), findsNothing);
    expect(find.text('YouTube'), findsWidgets);
  });

  testWidgets('no answer: the page gives way after 20 s', (t) async {
    setView(t);
    final h = Harness(mock: StuckConnection(const Connecting()));
    await t.pumpWidget(appWith(h, const LoadingIdentity()));
    const page = ValueKey('profile-loading');
    expect(find.byKey(page), findsOneWidget);
    await t.pump(const Duration(seconds: 15));
    expect(find.byKey(page), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    await t.pump();
    expect(find.byKey(const ValueKey('profile-loading')), findsNothing);
    expect(find.text('Connecting to the HinterOS service'), findsOneWidget);
  });

  testWidgets('a connection error while the session starts: the loading page', (
    t,
  ) async {
    setView(t);
    final h = Harness(
      mock: StuckConnection(const Unreachable('connection refused')),
    );
    await t.pumpWidget(appWith(h, const LoadingIdentity(name: 'James')));
    const page = ValueKey('profile-loading');
    for (final s in [1, 5, 12]) {
      await t.pump(Duration(seconds: s));
      expect(find.byKey(page), findsOneWidget, reason: '$s s');
      expect(find.text('Loading James…'), findsOneWidget);
      // Covered by the page (the shell below still has the notice).
      expect(find.textContaining("Can't reach").hitTestable(), findsNothing);
    }
    // It really fails: after the start, the error.
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(find.byKey(page), findsNothing);
    expect(
      find.textContaining("Can't reach the HinterOS service"),
      findsOneWidget,
    );
  });

  testWidgets('without a startup identity there is no loading page', (t) async {
    setView(t);
    await Harness().pump(t);
    expect(find.byKey(const ValueKey('profile-loading')), findsNothing);
  });
}
