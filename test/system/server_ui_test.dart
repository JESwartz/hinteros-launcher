// The Server tab (session API 0.19) through the screens, on the in-process
// mocks: the list, each service's page, the admin PIN before every change,
// the job page (the Tailscale sign-in's QR code), the library and accounts
// pages, and the service's refusals.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/server.dart';
import 'package:hinteros_launcher/src/ui/qr_code.dart';
import 'package:hinteros_launcher/src/ui/server/server_screen.dart';
import 'package:hinteros_launcher/src/ui/server/service_page.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness harness() => Harness(
  services: MockSystemServices(iconDir: iconDir(), now: fixedNow),
);

/// The rows of the mock: Cloudflare Tunnel, Jellyfin server, Plex Media
/// Server, Tailscale.
const cloudflareRow = 0;
const jellyfinRow = 1;
const plexRow = 2;
const tailscaleRow = 3;

/// The Server tab, service [row]'s page.
Future<void> openService(WidgetTester t, int row) async {
  await openServer(t);
  await press(t, [...List.filled(row, kDown), kEnter]);
}

/// Focus to the button or row with [text] on the page on top, by Down then
/// Right (rows first, then along the row).
Future<void> focusText(WidgetTester t, String text) async {
  bool on() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return find
        .descendant(of: find.byWidget(ctx.widget), matching: find.text(text))
        .evaluate()
        .isNotEmpty;
  }

  if (!on()) await press(t, List.filled(12, kUp));
  for (var i = 0; i < 20 && !on(); i++) {
    if (i > 0) await press(t, [kDown]);
    for (var j = 0; j < 4 && !on(); j++) {
      await press(t, [kRight]);
    }
    if (!on()) {
      for (var j = 0; j < 4; j++) {
        await press(t, [kLeft]);
      }
    }
  }
  expect(on(), isTrue, reason: 'no focus on "$text"');
}

Future<void> choose(WidgetTester t, String text) async {
  await focusText(t, text);
  await press(t, [kEnter]);
}

/// The confirm dialog on top: its confirm button (the second).
Future<void> confirm(WidgetTester t) => press(t, [kRight, kEnter]);

MockServer server(Harness h) => h.services.mockServer;

/// [f] on the service's page (the list stays under it).
Finder onPage(Finder f) =>
    find.descendant(of: find.byType(ServicePage), matching: f);

/// Finishes the running job and closes its page.
Future<void> finishJob(WidgetTester t, Harness h, {bool ok = true}) async {
  final j = h.services.mockJobs.runningJob!;
  h.services.mockJobs.finish(j.jobId, ok: ok);
  await t.pumpAndSettle();
  await press(t, [kEnter]); // Close
}

String stateOf(WidgetTester t, String name) {
  final row = find.ancestor(
    of: find.text(name),
    matching: find.byType(ServiceRow),
  );
  return t
      .widget<Text>(
        find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('service-state')),
        ),
      )
      .data!;
}

void main() {
  test('a library row: the kind, then its folder under /srv/media', () {
    const l = JellyfinLibrary(
      id: 'a2c4e6f8a0b2c4d6e8f0a2b4c6d8e0f2',
      name: 'Books',
      kind: LibraryKind.other,
    );
    expect(librarySubtitle(l), 'Other');
    expect(
      librarySubtitle(
        const JellyfinLibrary(
          id: 'f137a2dd21bbc1b99aa5c0f6bf02a805',
          name: 'Movies',
          kind: LibraryKind.movies,
          folder: 'Movies',
        ),
      ),
      'Movies · /srv/media/Movies',
    );
  });

  testWidgets('the tab lists every service with its state', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openServer(t);
    expect(focusLabel(), 'server/s0:0');
    expect(stateOf(t, 'Cloudflare Tunnel'), 'Off');
    expect(stateOf(t, 'Jellyfin server'), 'Running');
    expect(stateOf(t, 'Plex Media Server'), 'Needs setup');
    expect(stateOf(t, 'Tailscale'), 'Off');
  });

  testWidgets('the states follow the unit and the setup', (t) async {
    ServerService s(ServiceDetail? d, {UnitStatus? status}) => ServerService(
      id: 'x',
      name: 'X',
      enabled: true,
      status: status ?? UnitStatus.active,
      detail: d,
    );
    expect(const ServerService(id: 'x', name: 'X').state, ServiceState.off);
    expect(s(null, status: UnitStatus.failed).state, ServiceState.error);
    expect(s(null, status: UnitStatus.activating).state, ServiceState.starting);
    expect(s(null, status: UnitStatus.inactive).state, ServiceState.error);
    expect(s(null).state, ServiceState.running);
    expect(
      s(const JellyfinDetail(setupDone: false)).state,
      ServiceState.starting,
    );
    expect(s(const PlexDetail(claimed: false)).state, ServiceState.needsSetup);
    expect(
      s(const TailscaleDetail(state: TailscaleState.needsLogin)).state,
      ServiceState.needsSetup,
    );
    expect(
      s(const TailscaleDetail(state: TailscaleState.unavailable)).state,
      ServiceState.error,
    );
    expect(
      s(
        const CloudflareDetail(tokenSet: false, connected: false),
        status: UnitStatus.inactive,
      ).state,
      ServiceState.needsSetup,
    );
    expect(
      s(const CloudflareDetail(tokenSet: true, connected: false)).state,
      ServiceState.error,
    );
    expect(
      s(const CloudflareDetail(tokenSet: true, connected: true)).state,
      ServiceState.running,
    );
  });

  testWidgets('Turn on asks for the admin PIN, then runs the job', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, tailscaleRow);
    expect(find.text('Tailscale'), findsWidgets);
    expect(onPage(find.text('Off')), findsOneWidget);
    await choose(t, 'Turn on');
    expect(find.text('Turn on Tailscale'), findsOneWidget, reason: 'the pad');
    await enterPin(t, '1357');
    expect(find.text('Wrong PIN.'), findsOneWidget);
    expect(h.services.mockJobs.started, isEmpty);
    await enterPin(t, '2468');
    expect(h.services.mockJobs.started.single.kind, JobKind.servicesEnable);
    expect(find.text('Turning on Tailscale'), findsOneWidget);
    await finishJob(t, h);
    expect(server(h).tailscale.enabled, isTrue);
    // The page shows the new state.
    expect(onPage(find.text('Needs setup')), findsOneWidget);
    expect(find.text('Not signed in.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Back on the PIN pad changes nothing', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, tailscaleRow);
    await choose(t, 'Turn on');
    await press(t, [kEscape]);
    expect(h.services.mockJobs.started, isEmpty);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('Plex: its terms first, then the PIN', (t) async {
    setView(t);
    final h = harness();
    server(h).plex.enabled = false;
    await h.pump(t);
    await openService(t, plexRow);
    await choose(t, 'Turn on');
    expect(find.text('Terms for Plex Media Server'), findsOneWidget);
    // Read to the end, then accept.
    await press(t, List.filled(30, kDown));
    await choose(t, 'Accept and turn on');
    await enterPin(t, '2468');
    expect(server(h).accepted, {'plex-media-server': '2025-10-30'});
    expect(h.services.mockJobs.started.single.kind, JobKind.servicesEnable);
  });

  testWidgets('Plex: declined terms turn nothing on', (t) async {
    setView(t);
    final h = harness();
    server(h).plex.enabled = false;
    await h.pump(t);
    await openService(t, plexRow);
    await choose(t, 'Turn on');
    await choose(t, 'Decline');
    expect(find.text('Terms for Plex Media Server'), findsNothing);
    expect(h.services.mockJobs.started, isEmpty);
    expect(server(h).log, isEmpty);
  });

  testWidgets('Plex: the claim code', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, plexRow);
    expect(find.text('Not linked to a Plex account.'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is QrCodeView && w.data == plexClaimUrl),
      findsOneWidget,
    );
    expect(find.text('plex.tv/claim'), findsOneWidget);
    final field = find.byType(TextField);
    expect(t.widget<TextField>(field).controller!.text, 'claim-');
    // A wrong code: said at once, no PIN.
    await t.enterText(field, 'claim-short');
    await choose(t, 'Link');
    expect(find.text('The code is not correct.'), findsOneWidget);
    expect(server(h).log, isEmpty);
    await t.enterText(field, 'claim-AbCdEfGhIjKlMnOpQrSt');
    await choose(t, 'Link');
    await enterPin(t, '2468');
    expect(h.services.mockJobs.started.single.kind, JobKind.plexClaim);
    await finishJob(t, h);
    expect(find.text('Linked to a Plex account.'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
    expect(onPage(find.text('Running')), findsOneWidget);
  });

  testWidgets('Tailscale: the sign-in address as a QR code on the job page', (
    t,
  ) async {
    setView(t);
    final h = harness();
    server(h).tailscale.enabled = true;
    await h.pump(t);
    await openService(t, tailscaleRow);
    await choose(t, 'Sign in');
    await enterPin(t, '2468');
    final job = h.services.mockJobs.started.single;
    expect(job.kind, JobKind.tailscaleLogin);
    expect(find.text('Signing in to Tailscale'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
    h.services.mockJobs.progress(
      job.jobId,
      JobStage.signingIn,
      authUrl: 'https://login.tailscale.com/a/1a2b3c4d5e6f',
    );
    await t.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is QrCodeView &&
            w.data == 'https://login.tailscale.com/a/1a2b3c4d5e6f',
      ),
      findsOneWidget,
    );
    expect(find.text('Scan the code to sign in.'), findsOneWidget);
    expect(
      find.text('https://login.tailscale.com/a/1a2b3c4d5e6f'),
      findsOneWidget,
    );
    // The wait can be cancelled.
    expect(find.text('Cancel'), findsOneWidget);
    // A newer address replaces it.
    h.services.mockJobs.progress(
      job.jobId,
      JobStage.signingIn,
      authUrl: 'https://login.tailscale.com/a/ffff',
    );
    await t.pumpAndSettle();
    expect(find.text('https://login.tailscale.com/a/ffff'), findsOneWidget);
    await finishJob(t, h);
    expect(find.text('Signed in.'), findsOneWidget);
    expect(find.text('Address: 100.101.102.103'), findsOneWidget);
    expect(find.text('Key expires: 2027-04-18'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Tailscale: the key expiry is in the box time zone', (t) async {
    setView(t);
    final h = harness();
    // 2027-04-18 00:00 UTC is the evening before in Los Angeles.
    h.services.mockTimeZone.zone = 'America/Los_Angeles';
    server(h).tailscale
      ..enabled = true
      ..tailscale = TailscaleState.running;
    await h.pump(t);
    await openService(t, tailscaleRow);
    expect(find.text('Key expires: 2027-04-17'), findsOneWidget);
  });

  testWidgets('Tailscale: nobody signed in in time', (t) async {
    setView(t);
    final h = harness();
    server(h).tailscale.enabled = true;
    await h.pump(t);
    await openService(t, tailscaleRow);
    await choose(t, 'Sign in');
    await enterPin(t, '2468');
    final job = h.services.mockJobs.runningJob!;
    h.services.mockJobs.finish(
      job.jobId,
      ok: false,
      error: JobError(
        message: serverFailureText('timeout')!,
        stage: JobStage.signingIn,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Nobody signed in in time.'), findsOneWidget);
  });

  testWidgets('Jellyfin: address, libraries, remove one', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, jellyfinRow);
    expect(find.text('Address: http://192.168.1.42:8096'), findsOneWidget);
    expect(find.text('Movies'), findsWidgets);
    expect(find.text('Shows'), findsOneWidget);
    expect(find.text('Shows · /srv/media/TV/Series'), findsOneWidget);
    await choose(t, 'Shows');
    expect(find.text('Remove the library Shows?'), findsOneWidget);
    await confirm(t);
    await enterPin(t, '2468');
    expect(h.services.mockJobs.started.single.kind, JobKind.libraryRemove);
    expect(find.text('Removing the library Shows'), findsOneWidget);
    await finishJob(t, h);
    expect(find.text('Shows'), findsNothing);
    expect(server(h).jellyfin.libraries.map((l) => l.name), ['Movies']);
  });

  testWidgets('Jellyfin: add a library from a folder in /srv/media', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, jellyfinRow);
    await choose(t, 'Add library');
    expect(find.text('Add library'), findsWidgets);
    expect(find.text('Choose a folder'), findsOneWidget);
    await press(t, [kEnter]); // Folder
    expect(find.text('Choose a folder'), findsWidgets);
    expect(find.text('/srv/media'), findsOneWidget);
    // TV has folders: A opens it.
    await choose(t, 'TV');
    expect(find.text('/srv/media/TV'), findsOneWidget);
    expect(find.text('Cartoons'), findsOneWidget);
    // Back goes one level up, A again opens it.
    await press(t, [kEscape]);
    expect(find.text('/srv/media'), findsOneWidget);
    await choose(t, 'TV');
    // A folder without folders is chosen.
    await choose(t, 'Cartoons');
    expect(find.text('TV/Cartoons'), findsOneWidget);
    final name = find.byType(TextField);
    expect(t.widget<TextField>(name).controller!.text, 'Cartoons');
    await choose(t, 'Shows');
    await choose(t, 'Add');
    await enterPin(t, '2468');
    expect(h.services.mockJobs.started.single.kind, JobKind.libraryAdd);
    expect(
      server(h).log.last,
      'jellyfin.libraries.add:Cartoons:shows:TV/Cartoons',
    );
    await finishJob(t, h);
    // The page closed; the library is in the list.
    expect(find.text('Add library'), findsOneWidget);
    expect(find.text('Shows · /srv/media/TV/Cartoons'), findsOneWidget);
  });

  testWidgets('Jellyfin: "Use this folder" and a taken name', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, jellyfinRow);
    await choose(t, 'Add library');
    await press(t, [kEnter]);
    await choose(t, 'Movies');
    await choose(t, 'Use this folder');
    expect(find.text('Movies'), findsWidgets);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Movies',
    );
    await choose(t, 'Add');
    await enterPin(t, '2468');
    // The service says so; the page stays for another name.
    expect(find.text('A library has this name.'), findsOneWidget);
    await press(t, [kEnter]);
    expect(find.text('Choose a folder'), findsNothing);
    expect(h.services.mockJobs.started, isEmpty);
    expect(find.text('Kind'), findsOneWidget);
  });

  testWidgets('Jellyfin: Show accounts asks for the PIN', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, jellyfinRow);
    await choose(t, 'Show accounts');
    expect(find.text('Show accounts'), findsWidgets);
    await enterPin(t, '2468');
    expect(find.text('Jellyfin accounts'), findsOneWidget);
    expect(find.text('k3v9q2m7x4p8w6t5'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('James'), findsWidgets);
    expect(server(h).log, ['jellyfin.users.reveal']);
    await press(t, [kEnter]); // Close
    expect(find.text('Jellyfin accounts'), findsNothing);
  });

  testWidgets('Jellyfin: Turn off, with the server data, asks twice', (
    t,
  ) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, jellyfinRow);
    await choose(t, 'Turn off');
    expect(find.text('Turn off Jellyfin server?'), findsOneWidget);
    await press(t, [kEnter]); // the check box
    await press(t, [kDown, kRight, kEnter]); // Turn off
    expect(find.text('Delete all data of Jellyfin server?'), findsOneWidget);
    await confirm(t);
    await enterPin(t, '2468');
    expect(server(h).log.last, 'services.disable:jellyfin-server:data=true');
    expect(find.text('Turning off Jellyfin server'), findsOneWidget);
    expect(find.text('The server data is deleted too.'), findsOneWidget);
    await finishJob(t, h);
    expect(find.text('Turn on'), findsOneWidget);
    expect(server(h).jellyfin.libraries, isEmpty);
  });

  testWidgets('Jellyfin: Turn off keeps the data unless asked', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openService(t, jellyfinRow);
    await choose(t, 'Turn off');
    await press(t, [kDown, kRight, kEnter]);
    expect(find.text('Delete all data of Jellyfin server?'), findsNothing);
    await enterPin(t, '2468');
    expect(server(h).log.last, 'services.disable:jellyfin-server:data=false');
  });

  testWidgets('Tailscale: Turn off can delete its data too', (t) async {
    setView(t);
    final h = harness();
    server(h).tailscale.enabled = true;
    await h.pump(t);
    await openService(t, tailscaleRow);
    await choose(t, 'Turn off');
    expect(find.text('Delete server data'), findsOneWidget);
    expect(find.text('Sign-in and settings.'), findsOneWidget);
    await press(t, [kEnter]); // the check box
    await press(t, [kDown, kRight, kEnter]); // Turn off
    expect(find.text('Delete all data of Tailscale?'), findsOneWidget);
    expect(find.text("You can't undo this."), findsOneWidget);
    await confirm(t);
    await enterPin(t, '2468');
    expect(server(h).log.last, 'services.disable:tailscale:data=true');
  });

  testWidgets('Turn off without data to delete: no check box', (t) async {
    setView(t);
    final h = harness();
    server(h).cloudflare
      ..enabled = true
      ..hasData = false;
    await h.pump(t);
    await openService(t, cloudflareRow);
    await choose(t, 'Turn off');
    expect(find.text('Turn off Cloudflare Tunnel?'), findsOneWidget);
    expect(find.text('Delete server data'), findsNothing);
  });

  testWidgets('Cloudflare: the route, the token, a refused token', (t) async {
    setView(t);
    final h = harness();
    server(h).cloudflare.enabled = true;
    await h.pump(t);
    await openService(t, cloudflareRow);
    expect(find.text('No token.'), findsOneWidget);
    expect(
      find.text('Route this address in Zero Trust: 192.168.1.42'),
      findsOneWidget,
    );
    final field = find.byType(TextField);
    await choose(t, 'Save token');
    expect(find.text('Type the token.'), findsOneWidget);
    await t.enterText(field, 'eyJhIjoiYiJ9');
    await choose(t, 'Save token');
    await enterPin(t, '2468');
    expect(find.text('This is not a tunnel token.'), findsOneWidget);
    await press(t, [kEnter]);
    expect(h.services.mockJobs.started, isEmpty);
    await t.enterText(
      field,
      'eyJhIjoiMDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYiLCJ0IjoiNmYxYzhh'
      'MmUtM2I0ZC00ZTVmLThhOWItMGMxZDJlM2Y0YTViIiwicyI6IkJ3Y0hCd2NIQndjSEJ3'
      'Y0hCd2NIQndjSEJ3Y0hCd2NIQndjSEJ3Y0hCd2M9In0=',
    );
    await choose(t, 'Save token');
    await enterPin(t, '2468');
    expect(h.services.mockJobs.started.single.kind, JobKind.cloudflareSetToken);
    await finishJob(t, h);
    expect(find.text('Connected.'), findsOneWidget);
    expect(t.widget<TextField>(field).controller!.text, isEmpty);
    await choose(t, 'Remove token');
    expect(find.text('Remove the token?'), findsOneWidget);
    await confirm(t);
    await enterPin(t, '2468');
    expect(h.services.mockJobs.started.last.kind, JobKind.cloudflareClearToken);
  });

  testWidgets('a service that is off or not ready says so', (t) async {
    setView(t);
    final h = harness();
    server(h).jellyfin.setupDone = false;
    await h.pump(t);
    await openServer(t);
    expect(stateOf(t, 'Jellyfin server'), 'Starting');
    await press(t, [kDown, kEnter]);
    expect(find.text('Setting up...'), findsOneWidget);
    // Nothing to do with libraries until the first run is done.
    for (final b in ['Add library', 'Show accounts']) {
      expect(t.widget<HButton>(find.widgetWithText(HButton, b)).enabled, false);
    }
  });

  testWidgets('the list is unavailable without the system service', (t) async {
    setView(t);
    final h = harness();
    server(h).failNext = const SystemException(
      SystemErrorKind.unavailable,
      'Settings are unavailable. The HinterOS system service is not running.',
    );
    await h.pump(t);
    await openTab(t, 4);
    expect(find.text("The Server section isn't available"), findsOneWidget);
  });
}
