import 'dart:async';

import 'daemon.dart';
import 'errors.dart';
import 'generated.dart';
import 'version.dart';

/// The default fake app list.
const mockApps = <App>[
  App(id: 'steam', name: 'Steam', kind: AppKind.native),
  App(id: 'jellyfin', name: 'Jellyfin', kind: AppKind.native),
  App(id: 'youtube', name: 'YouTube', kind: AppKind.web),
  App(id: 'plex', name: 'Plex', kind: AppKind.native),
  App(id: 'kodi', name: 'Kodi', kind: AppKind.native),
  App(id: 'netflix', name: 'Netflix', kind: AppKind.web),
  App(id: 'spotify', name: 'Spotify', kind: AppKind.web),
  App(id: 'firefox', name: 'Firefox', kind: AppKind.native),
];

/// In-process stand-in for `hinteros-session`, for widget tests and desktop
/// development (`--mock`). It follows the same rules as the real daemon:
/// handshake first (1001), no second hello (1003), version check (1002),
/// events only for subscribed names. [rpc] speaks the wire shapes, so the
/// contract test can replay schema examples straight through it.
class MockDaemon extends DaemonConnection {
  MockDaemon({List<App> apps = mockApps, this.serverApiVersion = apiVersion})
    : apps = List.of(apps);

  final List<App> apps;

  /// The API version this mock claims to serve.
  final String serverApiVersion;

  static const serverPeer = Peer(
    name: 'hinteros-session-mock',
    version: '0.0.0',
  );

  ConnectionStatus _status = const Connecting();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<SessionEvent>.broadcast();
  final _subscribed = <String>[];
  final _desired = <EventName>{};
  bool _handshaken = false;
  bool _closed = false;

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusChanges => _statusController.stream;

  @override
  Stream<SessionEvent> get events => _eventController.stream;

  void _setStatus(ConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  @override
  void start() {
    if (_handshaken || _closed) return;
    rpc(
      'hello',
      HelloParams(
        apiVersion: apiVersion,
        client: const Peer(name: 'hinteros-launcher', version: '0.1.0'),
      ).toJson(),
    ).then((_) {
      if (_desired.isNotEmpty) {
        _subscribed.addAll(_desired.map((e) => e.value));
      }
      _setStatus(Connected(apiVersion: serverApiVersion, server: serverPeer));
    }, onError: (Object e) => _setStatus(Unreachable('$e')));
  }

  @override
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (method == 'hello') {
      if (_handshaken) {
        throw const ApiException(
          ApiErrorCode.alreadyHandshaken,
          'hello was already called',
        );
      }
      final p = HelloParams.fromJson(params);
      final mine = ApiVersionNumber.parse(serverApiVersion);
      final theirs = ApiVersionNumber.parse(p.apiVersion);
      if (!mine.isCompatibleWith(theirs)) {
        throw ApiException(
          ApiErrorCode.versionMismatch,
          'API version mismatch: client ${p.apiVersion}, server $serverApiVersion',
          VersionMismatchData(
            clientApiVersion: p.apiVersion,
            serverApiVersion: serverApiVersion,
          ).toJson(),
        );
      }
      _handshaken = true;
      return HelloResult(
        apiVersion: mine.negotiate(theirs).toString(),
        server: serverPeer,
      ).toJson();
    }
    if (!_handshaken) {
      throw const ApiException(
        ApiErrorCode.handshakeRequired,
        'call hello first',
      );
    }
    switch (method) {
      case 'ping':
        return PingResult(nonce: PingParams.fromJson(params).nonce).toJson();
      case 'subscribe':
        final names = _eventNames(params);
        for (final n in names) {
          if (!_subscribed.contains(n)) _subscribed.add(n);
        }
        return {'events': List<String>.of(_subscribed)};
      case 'unsubscribe':
        _subscribed.removeWhere(_eventNames(params).contains);
        return {'events': List<String>.of(_subscribed)};
      case 'apps.list':
        return AppsListResult(apps: List.of(apps)).toJson();
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  List<String> _eventNames(Map<String, dynamic> params) {
    final e = params['events'];
    if (e is! List || e.any((x) => x is! String)) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        'events must be an array of event names',
      );
    }
    return e.cast<String>();
  }

  @override
  Future<void> subscribeTo(Iterable<EventName> names) async {
    _desired.addAll(names);
    if (_handshaken) {
      await subscribe(SubscribeParams(events: names.toList()));
    }
  }

  @override
  Future<void> unsubscribeFrom(Iterable<EventName> names) async {
    _desired.removeAll(names);
    if (_handshaken) {
      await unsubscribe(UnsubscribeParams(events: names.toList()));
    }
  }

  /// Emits the event if this connection subscribed to [name] (like the daemon).
  void emitRaw(String name, [Map<String, dynamic> params = const {}]) {
    if (_closed || !_subscribed.contains(name)) return;
    _eventController.add(SessionEvent.fromNotification(name, params));
  }

  /// The Home button, on demand.
  void pressHome() => emitRaw('home_pressed');

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _statusController.close();
    await _eventController.close();
  }
}
