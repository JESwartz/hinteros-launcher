// Runs the real `hinteros-session` binary on a temp socket and drives it with
// DaemonClient. Needs HINTEROS_SESSION_BIN (set by the Nix integration check);
// skipped otherwise, so plain `flutter test` still works without Nix.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/data/apps_repository.dart';
import 'package:hinteros_launcher/src/data/games_repository.dart';
import 'package:hinteros_launcher/src/osk/osk_backend.dart';

final _bin = Platform.environment['HINTEROS_SESSION_BIN'];

/// The daemon repo's fake Steam home (`.../tests/fixtures/steam-home`), set by
/// the Nix integration check from the pinned `hinteros-daemon` input. Games
/// tests are skipped without it.
final _steamHome = Platform.environment['HINTEROS_STEAM_FIXTURE'];

String? _skip({bool needsSteam = false}) => _bin == null
    ? 'HINTEROS_SESSION_BIN not set'
    : needsSteam && _steamHome == null
    ? 'HINTEROS_STEAM_FIXTURE not set'
    : null;

void main() {
  // A generic picture from the repo (tool/gen_mock_icons.dart).
  final iconFixture =
      '${Directory.current.path}/test/fixtures/icons/jellyfin-desktop.png';
  late Directory dir;
  late String sock;
  late File keyLog;
  late Process daemon;
  final log = StringBuffer();
  DaemonClient? client;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('session_it');
    sock = '${dir.path}/run/session.sock';
    keyLog = File('${dir.path}/keys.log');
    // A dev-desktop session: no gamescope, no InputPlumber, and two configured
    // apps that exit by themselves (`sleep` keeps running until the test ends).
    // A Steam binary for the built-in `steam` entry (the Nix sandbox has
    // none on PATH); never started here.
    final steam = File('${dir.path}/steam')
      ..writeAsStringSync('#!/bin/sh\nexit 0\n');
    Process.runSync('chmod', ['755', steam.path]);
    final config = File('${dir.path}/session.toml')
      ..writeAsStringSync('''
[osk]
# No keyboard process to start; the daemon still tracks its visibility.
command = []

[steam]
path = "${steam.path}"

[[apps]]
id = "sleeper"
name = "Sleeper"
command = ["sleep", "60"]

[[apps]]
id = "crasher"
name = "Crasher"
command = ["sh", "-c", "exit 3"]

# An explicit icon path (a generic fixture picture), returned as is.
[[apps]]
id = "iconic"
name = "Iconic"
command = ["sleep", "60"]
icon = "$iconFixture"
''');
    daemon = await Process.start(_bin!, [
      '--socket',
      sock,
      '--config',
      config.path,
      '--no-gamescope',
      '--no-inputplumber',
      '--no-runtime',
      '--no-auth-agent',
      '--fake-keyboard',
      keyLog.path,
      if (_steamHome != null) ...[
        '--steam-dir',
        '$_steamHome/.local/share/Steam',
      ],
    ]);
    for (final s in [daemon.stdout, daemon.stderr]) {
      s.transform(utf8.decoder).listen(log.write);
    }
    // Wait for the socket to appear.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!File(sock).existsSync() &&
        FileSystemEntity.typeSync(sock) == FileSystemEntityType.notFound) {
      if (DateTime.now().isAfter(deadline)) fail('daemon did not bind: $log');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });

  tearDown(() async {
    await client?.close();
    daemon.kill(ProcessSignal.sigterm);
    await daemon.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        daemon.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    dir.deleteSync(recursive: true);
    log.clear();
  });

  test(
    'apps.list returns an app\'s icon path; apps_changed is a known event',
    () async {
      final c = client = DaemonClient(socketPath: sock);
      await c.subscribeTo([EventName.appsChanged]);
      await c.waitConnected();
      final apps = (await c.appsList()).apps;
      final iconic = apps.firstWhere((a) => a.id == 'iconic');
      expect(iconic.icon, iconFixture);
      expect(File(iconic.icon!).existsSync(), isTrue);
      // The built-in Steam entry and apps without a config icon: whatever the
      // box offers (a desktop file or a theme), never a made-up path.
      for (final a in apps) {
        if (a.icon != null) expect(a.icon, startsWith('/'));
      }
    },
    skip: _skip(),
  );

  test(
    'handshake at 0.8, ping, apps.list and home_pressed (SIGUSR1)',
    () async {
      final c = client = DaemonClient(socketPath: sock);
      await c.subscribeTo([EventName.homePressed]);
      final connected = await c.waitConnected();
      expect(connected.apiVersion, apiVersion);
      expect(connected.server.name, 'hinteros-session');

      expect((await c.ping(const PingParams(nonce: 'hi'))).nonce, 'hi');

      final apps = (await c.appsList()).apps;
      expect(apps, isNotEmpty);
      // The built-in Steam entry comes first (Big Picture).
      expect(apps.map((a) => a.id), ['steam', 'sleeper', 'crasher', 'iconic']);

      final home = c.events.firstWhere((e) => e is HomePressedEvent);
      // Subscription is acknowledged by now; the daemon turns SIGUSR1 into the event.
      daemon.kill(ProcessSignal.sigusr1);
      expect(
        await home.timeout(const Duration(seconds: 10)),
        isA<HomePressedEvent>(),
      );
    },
    skip: _skip(),
  );

  test('apps.launch, apps.running, app_started and app_exited', () async {
    final c = client = DaemonClient(socketPath: sock);
    await c.subscribeTo([
      EventName.appStarted,
      EventName.appExited,
      EventName.focusChanged,
    ]);
    await c.waitConnected();
    const wait = Duration(seconds: 10);

    // Errors carry their codes.
    await expectLater(
      c.appsLaunch(const AppsLaunchParams(id: 'nope')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.appNotFound,
        ),
      ),
    );
    await expectLater(
      c.appsLaunch(const AppsLaunchParams(command: ['does-not-exist'])),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.appLaunchFailed,
        ),
      ),
    );

    // A configured app starts and is listed as running.
    final started = c.events.firstWhere((e) => e is AppStartedEvent);
    final app = (await c.appsLaunch(const AppsLaunchParams(id: 'sleeper'))).app;
    expect(app.id, 'sleeper');
    expect(app.source, AppSource.command);
    expect((await started.timeout(wait) as AppStartedEvent).app.id, 'sleeper');
    expect((await c.appsRunning()).apps.map((a) => a.id), ['sleeper']);

    // One that exits non-zero is reported as crashed with its status.
    final exited = c.events.firstWhere(
      (e) => e is AppExitedEvent && e.id != 'sleeper',
    );
    await c.appsLaunch(const AppsLaunchParams(id: 'crasher'));
    final e = await exited.timeout(wait) as AppExitedEvent;
    expect(e.id, 'crasher');
    expect(e.reason, ExitReason.crashed);
    expect(e.exitCode, 3);

    // Focusing an app that is not running is an error; the launcher is fine.
    await expectLater(
      c.appsFocus(const AppsFocusParams(id: 'crasher')),
      throwsA(isA<ApiException>()),
    );
    await c.appsFocus(const AppsFocusParams(id: null));
  }, skip: _skip());

  test('apps.close ends a command app with reason closed', () async {
    final c = client = DaemonClient(socketPath: sock);
    await c.subscribeTo([EventName.appStarted, EventName.appExited]);
    await c.waitConnected();
    const wait = Duration(seconds: 15);
    final repo = AppsRepository(c);

    await c.appsLaunch(const AppsLaunchParams(id: 'sleeper'));
    expect((await c.appsRunning()).apps.map((a) => a.id), ['sleeper']);

    final exited = c.events.firstWhere((e) => e is AppExitedEvent);
    await repo.close('sleeper');
    final e = await exited.timeout(wait) as AppExitedEvent;
    expect(e.id, 'sleeper');
    expect(e.reason, ExitReason.closed);
    expect((await c.appsRunning()).apps, isEmpty);

    // Closing what does not run is app_not_found.
    await expectLater(
      repo.close('sleeper'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.appNotFound,
        ),
      ),
    );
  }, skip: _skip());

  test('games.list reads the Steam library; attention is empty without Steam windows', () async {
    final c = client = DaemonClient(socketPath: sock);
    await c.waitConnected();
    final games = await GamesRepository(c).list();
    expect(games.map((g) => g.name), [
      "Baldur's Gate 3",
      'Dota 2',
      'Hades',
      'Portal 2',
    ]);
    final portal = games.last;
    expect(portal.steamAppId, 620);
    expect(portal.installState, InstallState.installed);
    expect(portal.canLaunch, isTrue);
    expect(portal.lastPlayed, 1786300589);
    // Artwork paths are real files the launcher can load.
    expect(File(portal.artwork.portrait!).existsSync(), isTrue);
    expect(portal.artwork.hero, isNotNull);
    expect(games.first.artwork.hero, isNull, reason: 'missing art is null');
    // Every game came with a consistent install state.
    expect(
      games.map((g) => g.installState),
      everyElement(isNot(InstallState.unknown)),
    );

    // Steam is not running here: nothing needs attention, nothing to focus.
    expect((await c.steamAttention()).windows, isEmpty);
    await expectLater(
      c.steamFocus(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.steamNoWindows,
        ),
      ),
    );
  }, skip: _skip(needsSteam: true));

  test(
    'a client built for another API version gets a typed mismatch',
    () async {
      final c = client = DaemonClient(
        socketPath: sock,
        clientApiVersion: '9.9',
      );
      c.start();
      final s = await c.statusChanges
          .firstWhere((s) => s is VersionMismatch)
          .timeout(const Duration(seconds: 10));
      s as VersionMismatch;
      expect(s.clientApiVersion, '9.9');
      expect(s.serverApiVersion, apiVersion);
    },
    skip: _skip(),
  );

  group('on-screen keyboard and keys (API 0.4)', () {
    // A second daemon that the group tears down itself (no fake keyboard, so
    // keys.* answers keyboard_unavailable; or the keyboard disabled).
    Future<String> extraDaemon(List<String> args, {String config = ''}) async {
      final cfg = File('${dir.path}/extra.toml')..writeAsStringSync(config);
      final s = '${dir.path}/extra/session.sock';
      final p = await Process.start(_bin!, [
        '--socket',
        s,
        '--config',
        cfg.path,
        '--no-gamescope',
        '--no-inputplumber',
        '--no-auth-agent',
        ...args,
      ]);
      addTearDown(() async {
        p.kill(ProcessSignal.sigterm);
        await p.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            p.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      });
      for (final st in [p.stdout, p.stderr]) {
        st.drain<void>();
      }
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (FileSystemEntity.typeSync(s) == FileSystemEntityType.notFound) {
        if (DateTime.now().isAfter(deadline)) fail('extra daemon did not bind');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return s;
    }

    Future<String> keyLogIs(String expected) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      var got = '';
      while (DateTime.now().isBefore(deadline)) {
        got = keyLog.existsSync() ? keyLog.readAsStringSync() : '';
        if (got == expected) return got;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return got;
    }

    test(
      'hinteros-osk: show and hide reach every client as osk_changed',
      () async {
        final osk = DaemonOskBackend(
          DaemonClient(socketPath: sock, clientInfo: DaemonOskBackend.oskPeer),
        );
        addTearDown(osk.dispose);
        final launcher = client = DaemonClient(socketPath: sock);
        await launcher.subscribeTo([EventName.oskChanged]);
        await launcher.waitConnected();
        final oskHello = await osk.connection.waitConnected();
        expect(oskHello.apiVersion, apiVersion);
        expect(
          (osk.connection as DaemonClient).clientInfo.name,
          'hinteros-osk',
        );

        final oskSeen = <bool>[];
        osk.visibility.listen(oskSeen.add);
        final launcherSeen = <bool>[];
        launcher.events
            .where((e) => e is OskChangedEvent)
            .listen((e) => launcherSeen.add((e as OskChangedEvent).visible));
        // Subscriptions are acknowledged before the first request returns.
        await launcher.ping(const PingParams(nonce: 'sync'));

        expect((await launcher.oskShow()).visible, isTrue);
        await osk.hide();
        const wait = Duration(milliseconds: 100);
        for (
          var i = 0;
          i < 100 && (oskSeen.length < 2 || launcherSeen.length < 2);
          i++
        ) {
          await Future<void>.delayed(wait);
        }
        expect(oskSeen, [true, false]);
        expect(launcherSeen, [true, false]);
      },
      skip: _skip(),
    );

    test('keys.type, keys.key and keys.action write key events to the fake keyboard', () async {
      final osk = DaemonOskBackend(
        DaemonClient(socketPath: sock, clientInfo: DaemonOskBackend.oskPeer),
      );
      addTearDown(osk.dispose);
      await osk.connection.waitConnected();

      expect(await osk.type('a:'), isEmpty);
      await osk.key(Key.l, modifiers: [Modifier.ctrl]);
      await osk.action(OskAction.backspace);
      // a, then shift+; (colon), ctrl+l, backspace: Linux key codes.
      expect(
        await keyLogIs(
          'down 30\nup 30\ndown 42\ndown 39\nup 39\nup 42\n'
          'down 29\ndown 38\nup 38\nup 29\ndown 14\nup 14\n',
        ),
        'down 30\nup 30\ndown 42\ndown 39\nup 39\nup 42\n'
        'down 29\ndown 38\nup 38\nup 29\ndown 14\nup 14\n',
      );
    }, skip: _skip());

    test('keys.type of non-US text reports untypeable characters', () async {
      // No gamescope input method here, so the é cannot be typed; the rest is.
      final c = client = DaemonClient(socketPath: sock);
      await c.waitConnected();
      final r = await c.keysType(const KeysTypeParams(text: 'aé'));
      expect(r.untypeable, ['é']);
      expect(await keyLogIs('down 30\nup 30\n'), 'down 30\nup 30\n');
    }, skip: _skip());

    test('without a virtual keyboard keys.* is keyboard_unavailable', () async {
      final s = await extraDaemon(['--no-uinput']);
      final backend = DaemonOskBackend(
        DaemonClient(socketPath: s, clientInfo: DaemonOskBackend.oskPeer),
      );
      addTearDown(backend.dispose);
      await backend.connection.waitConnected();
      Matcher unavailable() => throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.keyboardUnavailable,
        ),
      );
      await expectLater(backend.type('x'), unavailable());
      await expectLater(backend.action(OskAction.tab), unavailable());
      await expectLater(backend.key(Key.escape), unavailable());
    }, skip: _skip());

    test('osk.show is osk_unavailable when the keyboard is disabled', () async {
      final s = await extraDaemon([
        '--no-uinput',
      ], config: '[osk]\nenable = false\n');
      final c = client = DaemonClient(socketPath: s);
      await c.waitConnected();
      await expectLater(
        c.oskShow(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.oskUnavailable,
          ),
        ),
      );
    }, skip: _skip());
  });
}
