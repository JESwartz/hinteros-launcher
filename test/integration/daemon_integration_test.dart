// Runs the real `hinteros-session` binary on a temp socket and drives it with
// DaemonClient. Needs HINTEROS_SESSION_BIN (set by the Nix integration check);
// skipped otherwise, so plain `flutter test` still works without Nix.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/data/apps_repository.dart';
import 'package:hinteros_launcher/src/data/games_repository.dart';

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
  late Directory dir;
  late String sock;
  late Process daemon;
  final log = StringBuffer();
  DaemonClient? client;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('session_it');
    sock = '${dir.path}/run/session.sock';
    // A dev-desktop session: no gamescope, no InputPlumber, and two configured
    // apps that exit by themselves (`sleep` keeps running until the test ends).
    final config = File('${dir.path}/session.toml')
      ..writeAsStringSync('''
[[apps]]
id = "sleeper"
name = "Sleeper"
command = ["sleep", "60"]

[[apps]]
id = "crasher"
name = "Crasher"
command = ["sh", "-c", "exit 3"]
''');
    daemon = await Process.start(_bin!, [
      '--socket',
      sock,
      '--config',
      config.path,
      '--no-gamescope',
      '--no-inputplumber',
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
    'handshake at 0.3, ping, apps.list and home_pressed (SIGUSR1)',
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
      expect(apps.map((a) => a.id), ['steam', 'sleeper', 'crasher']);

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
    expect(portal.appid, 620);
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
}
