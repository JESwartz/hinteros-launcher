// Runs the real `hinteros-session` binary on a temp socket and drives it with
// DaemonClient. Needs HINTEROS_SESSION_BIN (set by the Nix integration check);
// skipped otherwise, so plain `flutter test` still works without Nix.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';

final _bin = Platform.environment['HINTEROS_SESSION_BIN'];

void main() {
  late Directory dir;
  late String sock;
  late Process daemon;
  final log = StringBuffer();
  DaemonClient? client;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('session_it');
    sock = '${dir.path}/run/session.sock';
    daemon = await Process.start(_bin!, ['--socket', sock]);
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

  test('handshake, ping, apps.list and home_pressed (SIGUSR1)', () async {
    final c = client = DaemonClient(socketPath: sock);
    await c.subscribeTo([EventName.homePressed]);
    final connected = await c.waitConnected();
    expect(connected.apiVersion, apiVersion);
    expect(connected.server.name, 'hinteros-session');

    expect((await c.ping(const PingParams(nonce: 'hi'))).nonce, 'hi');

    final apps = (await c.appsList()).apps;
    expect(apps, isNotEmpty);
    expect(apps.map((a) => a.id), contains('steam'));

    final home = c.events.firstWhere((e) => e is HomePressedEvent);
    // Subscription is acknowledged by now; the daemon turns SIGUSR1 into the event.
    daemon.kill(ProcessSignal.sigusr1);
    expect(
      await home.timeout(const Duration(seconds: 10)),
      isA<HomePressedEvent>(),
    );
  }, skip: _bin == null ? 'HINTEROS_SESSION_BIN not set' : null);

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
    skip: _bin == null ? 'HINTEROS_SESSION_BIN not set' : null,
  );
}
