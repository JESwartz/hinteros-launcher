import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../log.dart';
import 'daemon.dart';
import 'errors.dart';
import 'generated.dart';
import 'version.dart';

/// Session socket path: `HINTEROS_SESSION_SOCKET`, else
/// `$XDG_RUNTIME_DIR/hinteros/session.sock`, else null.
String? defaultSocketPath([Map<String, String>? env]) {
  env ??= Platform.environment;
  final explicit = env['HINTEROS_SESSION_SOCKET'];
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final runtime = env['XDG_RUNTIME_DIR'];
  if (runtime != null && runtime.isNotEmpty) {
    return '$runtime/hinteros/session.sock';
  }
  return null;
}

/// The launcher's connection to `hinteros-session`: JSON-RPC 2.0 over a Unix
/// socket, one JSON message per line.
///
/// [start] connects, does the `hello` handshake and re-subscribes; if the
/// daemon is missing, drops, or speaks another API version, [status] says so
/// and the client retries with exponential backoff until [close].
class DaemonClient extends DaemonConnection {
  DaemonClient({
    required this.socketPath,
    this.clientInfo = const Peer(
      name: 'hinteros-launcher',
      version: launcherVersion,
    ),
    this.clientApiVersion = apiVersion,
    this.initialBackoff = const Duration(milliseconds: 250),
    this.maxBackoff = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 10),
    this.interactiveTimeout = const Duration(seconds: 340),
  });

  final String? socketPath;
  final Peer clientInfo;
  final String clientApiVersion;
  final Duration initialBackoff;
  final Duration maxBackoff;

  /// How long a call waits that the daemon answers at once.
  final Duration requestTimeout;

  /// How long a relayed call may wait for the admin password (the system
  /// service waits up to 300 s, the daemon up to 330 s).
  final Duration interactiveTimeout;

  /// Relayed calls that may wait for the admin password (the daemon's
  /// `system::may_interact`).
  static const _interactive = {'system.ssh.set', 'system.profiles.reset_pin'};

  /// Calls the daemon may take longer to answer, each 5 s over the daemon's
  /// own limit, so its answer (or its own timeout error) arrives: NetworkManager
  /// and BlueZ calls (30 s; wifi.connect 60 s, bluetooth.pair 90 s), relayed
  /// system calls (60 s).
  static const _slow = {
    'wifi.connect': Duration(seconds: 65),
    'bluetooth.pair': Duration(seconds: 95),
  };
  static const _runtimeTimeout = Duration(seconds: 35);
  static const _relayTimeout = Duration(seconds: 65);
  static const _runtimePrefixes = [
    'wifi.',
    'bluetooth.',
    'audio.',
    'display.',
    'power.',
    'network.',
  ];

  /// How long [rpc] waits for an answer to [method].
  Duration timeoutFor(String method) {
    if (_interactive.contains(method)) return interactiveTimeout;
    final slow = _slow[method];
    if (slow != null) return slow;
    if (method.startsWith('system.')) return _relayTimeout;
    if (_runtimePrefixes.any(method.startsWith)) return _runtimeTimeout;
    return requestTimeout;
  }

  ConnectionStatus _status = const Connecting();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<SessionEvent>.broadcast();
  final _desired = <EventName>{};
  final _closeSignal = Completer<void>();
  _Connection? _connection;
  bool _started = false;
  bool _closed = false;
  Future<void>? _loopDone;

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusChanges => _statusController.stream;

  @override
  Stream<SessionEvent> get events => _eventController.stream;

  void _setStatus(ConnectionStatus s) {
    if (_closed) return;
    _status = s;
    _statusController.add(s);
  }

  @override
  void start() {
    if (_started) return;
    _started = true;
    _loopDone = _loop();
  }

  Future<void> _loop() async {
    var backoff = initialBackoff;
    while (!_closed) {
      _setStatus(const Connecting());
      _Connection? conn;
      try {
        conn = await _connect();
        _connection = conn;
        await _handshake(conn);
        backoff = initialBackoff;
        await conn.closed;
        if (!_closed) _setStatus(const Unreachable('connection closed'));
      } on _Mismatch catch (m) {
        _setStatus(
          VersionMismatch(
            clientApiVersion: m.client,
            serverApiVersion: m.server,
          ),
        );
      } catch (e) {
        _setStatus(Unreachable(_describe(e)));
      } finally {
        _connection = null;
        conn?.close();
      }
      if (_closed) break;
      await Future.any([Future<void>.delayed(backoff), _closeSignal.future]);
      backoff = _min(backoff * 2, maxBackoff);
    }
  }

  static Duration _min(Duration a, Duration b) => a < b ? a : b;

  String _describe(Object e) {
    if (e is SocketException) {
      final os = e.osError?.message;
      return '${e.message}${os == null || e.message.contains(os) ? '' : ': $os'}';
    }
    return e.toString();
  }

  Future<_Connection> _connect() async {
    final path = socketPath;
    if (path == null) {
      throw const DaemonUnavailableException(
        'no socket path (set HINTEROS_SESSION_SOCKET or XDG_RUNTIME_DIR)',
      );
    }
    final socket = await Socket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    return _Connection(socket, _onNotification, requestTimeout);
  }

  Future<void> _handshake(_Connection conn) async {
    final HelloResult hello;
    try {
      hello = HelloResult.fromJson(
        await conn.request(
          'hello',
          HelloParams(
            apiVersion: clientApiVersion,
            client: clientInfo,
          ).toJson(),
        ),
      );
    } on ApiException catch (e) {
      final data = e.versionMismatch;
      if (data != null) {
        throw _Mismatch(data.clientApiVersion, data.serverApiVersion);
      }
      rethrow;
    }
    // Defence in depth: a daemon that accepted us but reports an
    // incompatible version is still a mismatch.
    final mine = ApiVersionNumber.parse(clientApiVersion);
    final theirs = ApiVersionNumber.parse(hello.apiVersion);
    if (!theirs.isCompatibleWith(mine)) {
      throw _Mismatch(clientApiVersion, hello.apiVersion);
    }
    // subscribeTo and unsubscribeFrom only record names until the handshake
    // is done, so send again until what is sent is what is wanted.
    final sent = <EventName>{};
    for (;;) {
      final add = _desired.difference(sent);
      final drop = sent.difference(_desired);
      if (add.isEmpty && drop.isEmpty) break;
      if (add.isNotEmpty) {
        await conn.request(
          'subscribe',
          SubscribeParams(events: add.toList()).toJson(),
        );
        sent.addAll(add);
      }
      if (drop.isNotEmpty) {
        await conn.request(
          'unsubscribe',
          UnsubscribeParams(events: drop.toList()).toJson(),
        );
        sent.removeAll(drop);
      }
    }
    conn.handshaken = true;
    _setStatus(Connected(apiVersion: hello.apiVersion, server: hello.server));
  }

  void _onNotification(String method, Map<String, dynamic> params) {
    if (_closed) return;
    SessionEvent event;
    try {
      event = SessionEvent.fromNotification(method, params);
    } catch (e) {
      // A known event this client cannot read (a value of a newer daemon):
      // it goes on like an event this client does not know.
      logFailure('reading the $method event', e);
      event = UnknownSessionEvent(method, params);
    }
    _eventController.add(event);
  }

  @override
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) {
    final conn = _connection;
    if (conn == null || !conn.handshaken) {
      return Future.error(const DaemonUnavailableException());
    }
    return conn.request(method, params, timeout: timeoutFor(method));
  }

  @override
  Future<void> subscribeTo(Iterable<EventName> names) async {
    _desired.addAll(names);
    if (_connection?.handshaken ?? false) {
      await subscribe(SubscribeParams(events: names.toList()));
    }
  }

  @override
  Future<void> unsubscribeFrom(Iterable<EventName> names) async {
    _desired.removeAll(names);
    if (_connection?.handshaken ?? false) {
      await unsubscribe(UnsubscribeParams(events: names.toList()));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_closeSignal.isCompleted) _closeSignal.complete();
    _connection?.close();
    await _loopDone;
    await _statusController.close();
    await _eventController.close();
  }
}

class _Mismatch implements Exception {
  _Mismatch(this.client, this.server);
  final String client;
  final String server;
}

/// One socket: framing, id correlation, notification dispatch.
class _Connection {
  _Connection(this._socket, this._onNotification, this._timeout) {
    _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onError: (_) => _finish(), onDone: _finish);
  }

  final Socket _socket;
  final void Function(String, Map<String, dynamic>) _onNotification;
  final Duration _timeout;
  final _pending = <Object, Completer<Map<String, dynamic>>>{};
  final _done = Completer<void>();
  int _nextId = 1;
  bool handshaken = false;

  /// Completes when the socket is gone.
  Future<void> get closed => _done.future;

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout,
  }) {
    if (_done.isCompleted) {
      return Future.error(
        const DaemonUnavailableException('connection closed'),
      );
    }
    final id = _nextId++;
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    try {
      _socket.write(
        '${jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params})}\n',
      );
    } catch (e) {
      _pending.remove(id);
      return Future.error(DaemonUnavailableException('$e'));
    }
    final limit = timeout ?? _timeout;
    return c.future.timeout(
      limit,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('$method timed out', limit);
      },
    );
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    final Object? msg;
    try {
      msg = jsonDecode(line);
    } catch (_) {
      return; // not ours to answer; the daemon closes on its own bad input
    }
    if (msg is! Map) return;
    final id = msg['id'];
    if (id != null && (msg.containsKey('result') || msg.containsKey('error'))) {
      final c = _pending.remove(id);
      if (c == null) return;
      final err = msg['error'];
      if (err is Map) {
        final code = err['code'];
        c.completeError(
          ApiException(
            code is num ? code.toInt() : ApiErrorCode.internalError,
            '${err['message'] ?? ''}',
            err['data'],
          ),
        );
      } else {
        final r = msg['result'];
        c.complete(r is Map ? r.cast<String, dynamic>() : <String, dynamic>{});
      }
    } else if (id == null && msg['method'] is String) {
      final p = msg['params'];
      _onNotification(
        msg['method'] as String,
        p is Map ? p.cast<String, dynamic>() : <String, dynamic>{},
      );
    }
  }

  void _finish() {
    if (_done.isCompleted) return;
    _done.complete();
    final err = const DaemonUnavailableException('connection closed');
    for (final c in _pending.values) {
      c.completeError(err);
    }
    _pending.clear();
  }

  void close() {
    _socket.destroy();
    _finish();
  }
}
