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

  /// A `command` launch of this program fails with app_launch_failed.
  static const failingProgram = 'does-not-exist';

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
  final _running = <RunningApp>[];
  String? _focused;
  int _cmdCounter = 0;
  int _gamescopeCounter = 0;
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
      case 'apps.launch':
        return AppsLaunchResult(app: _launch(AppsLaunchParams.fromJson(params)))
            .toJson();
      case 'apps.running':
        return AppsRunningResult(
          apps: List.of(_running),
          focused: _focused,
        ).toJson();
      case 'apps.focus':
        if (!params.containsKey('id')) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'id is required',
          );
        }
        final id = params['id'];
        if (id != null && !_running.any((a) => a.id == id)) {
          throw ApiException(
            ApiErrorCode.appNotFound,
            "no running app with id '$id'",
          );
        }
        _setFocus(id as String?);
        return const AppsFocusResult().toJson();
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  RunningApp _launch(AppsLaunchParams p) {
    final given = [p.id, p.command, p.url].where((x) => x != null).length;
    if (given != 1) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        "exactly one of 'id', 'command' or 'url' is required",
      );
    }
    final RunningApp app;
    if (p.id != null) {
      final id = p.id!;
      final known = apps.where((a) => a.id == id).firstOrNull;
      if (known == null) {
        throw ApiException(ApiErrorCode.appNotFound, "no app with id '$id'");
      }
      // Already running: focus it instead.
      final running = _running.where((a) => a.id == id).firstOrNull;
      if (running != null) {
        _setFocus(id);
        return running;
      }
      app = _newRunning(id, known.name, AppSource.command);
    } else if (p.command != null) {
      final program = p.command!.first;
      if (program == failingProgram) {
        throw ApiException(
          ApiErrorCode.appLaunchFailed,
          'cannot start $program: No such file or directory (os error 2)',
        );
      }
      app = _newRunning(
        'cmd-${++_cmdCounter}',
        p.name ?? program.split('/').last,
        AppSource.command,
      );
    } else {
      final appid = int.parse(p.url!.split('/').last);
      final id = 'steam-$appid';
      final running = _running.where((a) => a.id == id).firstOrNull;
      if (running != null) {
        _setFocus(id);
        return running;
      }
      app = _newRunning(
        id,
        'Steam game $appid',
        AppSource.steam,
        gamescopeAppId: appid,
      );
    }
    _running.add(app);
    emitRaw('app_started', AppStartedEvent(app: app).toJson());
    _setFocus(app.id);
    return app;
  }

  RunningApp _newRunning(
    String id,
    String name,
    AppSource source, {
    int? gamescopeAppId,
  }) => RunningApp(
    id: id,
    name: name,
    source: source,
    gamescopeAppId: gamescopeAppId ?? 4100000000 + (++_gamescopeCounter),
    pid: source == AppSource.command ? 4200 + _running.length : null,
  );

  void _setFocus(String? id) {
    if (_focused == id) return;
    _focused = id;
    emitRaw('focus_changed', FocusChangedEvent(app: id).toJson());
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

  /// The Home button, on demand: the launcher comes to the front, then the event.
  void pressHome() {
    _setFocus(null);
    emitRaw('home_pressed');
  }

  /// Simulates the running app [id] ending. If it had focus, the launcher
  /// takes over again (app_exited, then focus_changed).
  void simulateExit(
    String id, {
    ExitReason reason = ExitReason.exited,
    int? exitCode,
  }) {
    if (!_running.any((a) => a.id == id)) return;
    _running.removeWhere((a) => a.id == id);
    emitRaw(
      'app_exited',
      AppExitedEvent(id: id, reason: reason, exitCode: exitCode).toJson(),
    );
    if (_focused == id) _setFocus(null);
  }

  /// A controller navigation intent. Like the daemon, only sent while the
  /// launcher has focus.
  void emitNav(NavAction action, [NavPhase phase = NavPhase.press]) {
    if (_focused != null) return;
    emitRaw('input_nav', InputNavEvent(action: action, phase: phase).toJson());
  }

  /// The running apps (for dev keys and tests).
  List<RunningApp> get running => List.unmodifiable(_running);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _statusController.close();
    await _eventController.close();
  }
}
