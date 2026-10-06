// DaemonClient against a scripted fake server on a real Unix socket.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';

/// A tiny NDJSON JSON-RPC server. [onRequest] returns the full response
/// message for a request (or null to stay silent); it may also push events
/// through [FakeConn.send].
class FakeServer {
  FakeServer._(this._server, this.path);

  final ServerSocket _server;
  final String path;
  final conns = <FakeConn>[];
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? Function(FakeConn, Map<String, dynamic>)? onRequest;

  static Future<FakeServer> bind(String path) async {
    final s = await ServerSocket.bind(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    final f = FakeServer._(s, path);
    s.listen((sock) {
      final c = FakeConn(sock);
      f.conns.add(c);
      sock
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final req = jsonDecode(line) as Map<String, dynamic>;
            f.requests.add(req);
            final res = f.onRequest?.call(c, req);
            if (res != null) c.send(res);
          }, onError: (_) {});
    });
    return f;
  }

  Future<void> close() async {
    for (final c in conns) {
      c.socket.destroy();
    }
    await _server.close();
  }
}

class FakeConn {
  FakeConn(this.socket);
  final Socket socket;
  void send(Map<String, dynamic> m) => socket.write('${jsonEncode(m)}\n');
}

Map<String, dynamic> ok(Object id, Map<String, dynamic> result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

Map<String, dynamic> err(Object id, int code, String msg, [Object? data]) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': msg, 'data': ?data},
};

Map<String, dynamic> helloOk(Object id, [String v = apiVersion]) => ok(id, {
  'api_version': v,
  'server': {'name': 'fake', 'version': '0'},
});

void main() {
  late Directory dir;
  late String path;
  FakeServer? server;
  DaemonClient? client;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('client_test');
    path = '${dir.path}/s.sock';
  });
  tearDown(() async {
    await client?.close();
    await server?.close();
    server = null;
    client = null;
    dir.deleteSync(recursive: true);
  });

  DaemonClient mk() => client = DaemonClient(
    socketPath: path,
    initialBackoff: const Duration(milliseconds: 20),
    maxBackoff: const Duration(milliseconds: 100),
    requestTimeout: const Duration(seconds: 2),
  );

  test('handshake, request/response correlation, events', () async {
    server = await FakeServer.bind(path);
    final held = <Map<String, dynamic>>[];
    server!.onRequest = (c, req) {
      switch (req['method']) {
        case 'hello':
          expect(req['params']['api_version'], apiVersion);
          return helloOk(req['id']);
        case 'subscribe':
          return ok(req['id'], {'events': req['params']['events']});
        case 'ping':
          // Answer pings out of order: hold the first, answer it after the second.
          held.add(req);
          if (held.length == 2) {
            c.send(ok(held[1]['id'], {'nonce': held[1]['params']['nonce']}));
            c.send({
              'jsonrpc': '2.0',
              'method': 'home_pressed',
              'params': <String, dynamic>{},
            });
            c.send(ok(held[0]['id'], {'nonce': held[0]['params']['nonce']}));
          }
          return null;
        case 'apps.list':
          return ok(req['id'], {
            'apps': [
              {'id': 'a', 'name': 'A', 'kind': 'native'},
            ],
          });
      }
      return err(req['id'], -32601, 'nope');
    };
    final c = mk();
    await c.subscribeTo([EventName.homePressed]); // before connecting
    final events = <SessionEvent>[];
    c.events.listen(events.add);
    final connected = await c.waitConnected();
    expect(connected.apiVersion, apiVersion);
    expect(server!.requests.map((r) => r['method']), ['hello', 'subscribe']);

    final p1 = c.ping(const PingParams(nonce: 'one'));
    final p2 = c.ping(const PingParams(nonce: 'two'));
    expect((await p1).nonce, 'one');
    expect((await p2).nonce, 'two');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, [isA<HomePressedEvent>()]);

    expect((await c.appsList()).apps.single.name, 'A');
    await expectLater(
      c.rpc('does.not.exist', {}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', -32601)),
    );
  });

  test('requests before connecting fail with DaemonUnavailableException', () {
    final c = mk();
    expect(c.ping(), throwsA(isA<DaemonUnavailableException>()));
  });

  test(
    'unreachable while there is no socket, connects once it appears',
    () async {
      final c = mk()..start();
      final first = await c.statusChanges
          .firstWhere((s) => s is Unreachable)
          .timeout(const Duration(seconds: 5));
      expect(first, isA<Unreachable>());
      server = await FakeServer.bind(path);
      server!.onRequest = (c, req) => helloOk(req['id']);
      await c.waitConnected();
    },
  );

  test(
    'version_mismatch (1002) becomes a typed status and is retried',
    () async {
      server = await FakeServer.bind(path);
      server!.onRequest = (c, req) => err(
        req['id'],
        ApiErrorCode.versionMismatch,
        'mismatch',
        {'client_api_version': apiVersion, 'server_api_version': '0.9'},
      );
      final c = mk()..start();
      final s = await c.statusChanges
          .firstWhere((s) => s is VersionMismatch)
          .timeout(const Duration(seconds: 5));
      s as VersionMismatch;
      expect(s.clientApiVersion, apiVersion);
      expect(s.serverApiVersion, '0.9');
      // Retried with backoff: more than one hello arrives.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        server!.requests.where((r) => r['method'] == 'hello').length,
        greaterThan(1),
      );
    },
  );

  test(
    'an incompatible version in a successful hello is a mismatch too',
    () async {
      server = await FakeServer.bind(path);
      server!.onRequest = (c, req) => helloOk(req['id'], '7.0');
      final c = mk()..start();
      final s = await c.statusChanges
          .firstWhere((s) => s is VersionMismatch)
          .timeout(const Duration(seconds: 5));
      expect((s as VersionMismatch).serverApiVersion, '7.0');
    },
  );

  test('reconnects after a drop and re-subscribes', () async {
    server = await FakeServer.bind(path);
    server!.onRequest = (c, req) => switch (req['method']) {
      'hello' => helloOk(req['id']),
      'subscribe' => ok(req['id'], {'events': req['params']['events']}),
      _ => err(req['id'], -32601, 'nope'),
    };
    final c = mk();
    await c.subscribeTo([EventName.homePressed]);
    await c.waitConnected();
    final dropped = c.statusChanges.firstWhere((s) => s is! Connected);
    server!.conns.first.socket.destroy();
    await dropped.timeout(const Duration(seconds: 5));
    await c.statusChanges
        .firstWhere((s) => s is Connected)
        .timeout(const Duration(seconds: 5));
    final methods = server!.requests.map((r) => r['method']).toList();
    expect(methods, ['hello', 'subscribe', 'hello', 'subscribe']);
  });

  test('pending requests fail when the connection drops', () async {
    server = await FakeServer.bind(path);
    server!.onRequest = (c, req) =>
        req['method'] == 'hello' ? helloOk(req['id']) : null;
    final c = mk();
    await c.waitConnected();
    final pending = c.ping();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    server!.conns.first.socket.destroy();
    await expectLater(pending, throwsA(isA<DaemonUnavailableException>()));
  });

  test('defaultSocketPath prefers HINTEROS_SESSION_SOCKET', () {
    expect(
      defaultSocketPath({
        'HINTEROS_SESSION_SOCKET': '/x/s.sock',
        'XDG_RUNTIME_DIR': '/run/user/1',
      }),
      '/x/s.sock',
    );
    expect(
      defaultSocketPath({'XDG_RUNTIME_DIR': '/run/user/1'}),
      '/run/user/1/hinteros/session.sock',
    );
    expect(defaultSocketPath({}), isNull);
  });
}
