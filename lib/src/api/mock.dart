import 'dart:async';
import 'dart:io' show File;

import 'daemon.dart';
import 'errors.dart';
import 'generated.dart';
import 'mock_runtime.dart';
import 'mock_system_relay.dart';
import 'version.dart';

/// The default fake app list: what a fresh HinterOS has (the built-in Steam
/// entry first, then the default apps; Plex is a Store app).
const mockApps = <App>[
  App(id: 'steam', name: 'Steam', kind: AppKind.native),
  App(id: 'jellyfin', name: 'Jellyfin', kind: AppKind.native),
  App(id: 'youtube', name: 'YouTube', kind: AppKind.web),
  App(id: 'crunchyroll', name: 'Crunchyroll', kind: AppKind.web),
  App(id: 'firefox', name: 'Firefox', kind: AppKind.native),
  App(id: 'plex', name: 'Plex', kind: AppKind.native),
];

/// The default apps with local icons from [iconDir] (holding `<app-id>.png` or
/// `.svg`, made by `tool/gen_mock_icons.dart`). Apps in [without] get none,
/// like an app whose icon cannot be found or has not arrived yet.
List<App> mockAppsWithIcons(String iconDir, {Set<String> without = const {}}) {
  String? find(String id) {
    for (final ext in ['png', 'svg']) {
      if (File('$iconDir/$id.$ext').existsSync()) return '$iconDir/$id.$ext';
    }
    return null;
  }

  return [
    for (final a in mockApps)
      App(
        id: a.id,
        name: a.name,
        kind: a.kind,
        icon: without.contains(a.id) ? null : find(a.id),
      ),
  ];
}

/// A fake Steam library, sorted by name like the daemon does. With [artDir]
/// (holding `<slug>_portrait.png` and `<slug>_header.png`, made by
/// `tool/gen_mock_art.dart`) a few games get local artwork; the others have
/// none, like freshly installed ones.
List<Game> mockGames({String? artDir}) {
  GameArtwork art(String slug, {bool header = true}) => GameArtwork(
    portrait: artDir == null ? null : '$artDir/${slug}_portrait.png',
    header: artDir == null || !header ? null : '$artDir/${slug}_header.png',
    hero: null,
    logo: null,
    icon: null,
  );
  const none = GameArtwork(
    portrait: null,
    header: null,
    hero: null,
    logo: null,
    icon: null,
  );
  Game g(
    int appid,
    String name,
    GameArtwork artwork, {
    InstallState state = InstallState.installed,
    double gb = 4.2,
    int? lastPlayed,
  }) => Game(
    appid: appid,
    name: name,
    installState: state,
    sizeBytes: (gb * 1e9).round(),
    lastPlayed: lastPlayed,
    artwork: artwork,
  );
  return [
    g(2379780, 'Balatro', none, gb: 0.1, lastPlayed: 1790000000),
    g(504230, 'Celeste', art('celeste'), gb: 1.2, lastPlayed: 1789000000),
    g(268910, 'Cuphead', none, gb: 3.5),
    g(588650, 'Dead Cells', none, gb: 0.5, lastPlayed: 1786000000),
    g(632470, 'Disco Elysium', none, gb: 21),
    g(427520, 'Factorio', none, state: InstallState.updating, gb: 2.1),
    g(
      1145360,
      'Hades',
      art('hades'),
      state: InstallState.updateRequired,
      gb: 15,
      lastPlayed: 1788000000,
    ),
    g(
      367520,
      'Hollow Knight',
      art('hollow', header: false),
      gb: 9,
      lastPlayed: 1787000000,
    ),
    g(620, 'Portal 2', art('portal'), gb: 13, lastPlayed: 1786300589),
    g(252950, 'Rocket League', none, gb: 20),
    g(646570, 'Slay the Spire', none, gb: 0.6),
    g(413150, 'Stardew Valley', none, gb: 0.7, lastPlayed: 1785000000),
    g(105600, 'Terraria', none, state: InstallState.installing, gb: 0.3),
    g(1794680, 'Vampire Survivors', none, gb: 0.2),
  ];
}

/// In-process stand-in for `hinteros-session`, for widget tests and desktop
/// development (`--mock`). It follows the same rules as the real daemon:
/// handshake first (1001), no second hello (1003), version check (1002),
/// events only for subscribed names. [rpc] speaks the wire shapes, so the
/// contract test can replay schema examples straight through it.
class MockDaemon extends DaemonConnection {
  MockDaemon({
    List<App> apps = mockApps,
    List<Game>? games,
    this.serverApiVersion = apiVersion,
    this.clientName = 'hinteros-launcher',
    Duration? systemStepDelay,
    DateTime Function()? now,
  }) : apps = List.of(apps),
       _games = List.of(games ?? mockGames()) {
    system = MockSystemRelay(
      emit: (name, params) => emitRaw(name, params),
      now: now,
      stepDelay: systemStepDelay,
    );
    runtime = MockRuntime(emit: (name, params) => emitRaw(name, params));
  }

  /// The relayed system service (session API 0.6): its state, fake jobs and
  /// switches for failures. Methods `system.*` go here.
  late final MockSystemRelay system;

  /// The runtime settings (session API 0.7): Wi-Fi, Bluetooth, audio,
  /// display and power, with switches for failures. Methods `network.*`,
  /// `wifi.*`, `bluetooth.*`, `audio.*`, `display.*` and `power.*` go here.
  late final MockRuntime runtime;

  final List<App> apps;
  List<Game> _games;
  List<SteamWindow> _attention = const [];

  /// A `command` launch of this program fails with app_launch_failed.
  static const failingProgram = 'does-not-exist';

  /// Steam's own gamescope app id.
  static const steamGamescopeAppId = 769;

  /// The API version this mock claims to serve.
  final String serverApiVersion;

  /// The hello client name. `hinteros-osk` marks the on-screen keyboard's
  /// connection, which alone gets `input_nav` while the keyboard is visible.
  final String clientName;

  /// Config: the on-screen keyboard exists (`osk.show` else osk_unavailable).
  bool oskEnabled = true;

  /// Config: a virtual keyboard exists (`keys.*` else keyboard_unavailable).
  bool keyboardAvailable = true;

  bool _oskVisible = false;

  /// Whether the on-screen keyboard is shown (`osk.show`, `osk_visibility`).
  bool get oskVisible => _oskVisible;

  final List<String> _keyLog = [];

  /// What `keys.*` was asked to send, in order: `type:<text>`,
  /// `key:<key>[+mod...]`, `action:<name>`.
  List<String> get keyLog => List.unmodifiable(_keyLog);

  /// Everything `keys.type` typed (without the untypeable characters).
  String get typedText => _keyLog
      .where((c) => c.startsWith('type:'))
      .map((c) => c.substring(5))
      .join();

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
        client: Peer(name: clientName, version: '0.1.0'),
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
    if (MockSystemRelay.handles(method)) return system.call(method, params);
    if (MockRuntime.handles(method)) return runtime.call(method, params);
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
      case 'games.list':
        return GamesListResult(games: List.of(_games)).toJson();
      case 'steam.attention':
        return SteamAttentionResult(windows: List.of(_attention)).toJson();
      case 'steam.focus':
        return SteamFocusResult(app: _focusSteam()).toJson();
      case 'apps.close':
        if (params['id'] is! String) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'id is required',
          );
        }
        _close(params['id'] as String);
        return const AppsCloseResult().toJson();
      case 'apps.launch':
        return AppsLaunchResult(app: _launch(AppsLaunchParams.fromJson(params)))
            .toJson();
      case 'apps.running':
        return AppsRunningResult(
          apps: List.of(_running),
          focused: _focused,
        ).toJson();
      case 'osk.show':
        if (!oskEnabled) {
          throw const ApiException(
            ApiErrorCode.oskUnavailable,
            'the on-screen keyboard is disabled ([osk] enable = false)',
          );
        }
        _setOsk(true);
        return const OskShowResult(visible: true).toJson();
      case 'osk.hide':
        _setOsk(false);
        return const OskHideResult(visible: false).toJson();
      case 'keys.type':
        return _keysType(KeysTypeParams.fromJson(params)).toJson();
      case 'keys.key':
        final k = KeysKeyParams.fromJson(params);
        if (k.key == Key.unknown ||
            (k.modifiers ?? []).contains(Modifier.unknown)) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'unknown key or modifier',
          );
        }
        _needKeyboard();
        _keyLog.add(
          'key:${[k.key.value, ...?k.modifiers?.map((m) => m.value)].join('+')}',
        );
        return const KeysKeyResult().toJson();
      case 'keys.action':
        final a = KeysActionParams.fromJson(params).action;
        if (a == KeyAction.unknown) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'unknown action',
          );
        }
        _needKeyboard();
        _keyLog.add('action:${a.value}');
        return const KeysActionResult().toJson();
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

  void _setOsk(bool visible) {
    if (_oskVisible == visible) return;
    _oskVisible = visible;
    emitRaw('osk_visibility', OskVisibilityEvent(visible: visible).toJson());
  }

  void _needKeyboard() {
    if (!keyboardAvailable) {
      throw const ApiException(
        ApiErrorCode.keyboardUnavailable,
        'no virtual keyboard (/dev/uinput)',
      );
    }
  }

  /// Like the daemon with a US uinput keyboard and no input method: printable
  /// ASCII types, anything else is untypeable.
  KeysTypeResult _keysType(KeysTypeParams p) {
    _needKeyboard();
    final ok = StringBuffer();
    final bad = <String>[];
    for (final r in p.text.runes) {
      final c = String.fromCharCode(r);
      (r >= 0x20 && r < 0x7f ? ok.write(c) : bad.add(c));
    }
    _keyLog.add('type:$ok');
    return KeysTypeResult(untypeable: bad);
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
      app = id == 'steam'
          ? _newRunning(
              id,
              known.name,
              AppSource.steamClient,
              gamescopeAppId: steamGamescopeAppId,
            )
          : _newRunning(id, known.name, AppSource.command);
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
      final m = RegExp(r'^steam://rungameid/(\d+)$').firstMatch(p.url!);
      if (m == null) {
        throw const ApiException(
          ApiErrorCode.invalidParams,
          "url must be steam://rungameid/<appid>",
        );
      }
      final appid = int.parse(m[1]!);
      final id = 'steam-$appid';
      final running = _running.where((a) => a.id == id).firstOrNull;
      if (running != null) {
        _setFocus(id);
        return running;
      }
      app = _newRunning(
        id,
        _games.where((g) => g.appid == appid).firstOrNull?.name ??
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

  /// apps.close: the app goes away, `app_exited` says `closed`.
  void _close(String id) {
    if (!_running.any((a) => a.id == id)) {
      throw ApiException(
        ApiErrorCode.appNotFound,
        "no running app with id '$id'",
      );
    }
    simulateExit(id, reason: ExitReason.closed);
  }

  /// steam.focus: Steam's windows come to the front as the app `steam`.
  RunningApp _focusSteam() {
    if (_attention.isEmpty) {
      throw const ApiException(
        ApiErrorCode.steamNoWindows,
        'Steam has no windows to show',
      );
    }
    var app = _running.where((a) => a.id == 'steam').firstOrNull;
    if (app == null) {
      app = _newRunning(
        'steam',
        'Steam',
        AppSource.steamClient,
        gamescopeAppId: steamGamescopeAppId,
      );
      _running.add(app);
      emitRaw('app_started', AppStartedEvent(app: app).toJson());
    }
    _setFocus('steam');
    setSteamAttention(const []);
    return app;
  }

  void _setFocus(String? id) {
    if (_focused == id) return;
    _focused = id;
    _setOsk(false);
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

  /// The Steam library changed (a game finished updating, was installed...).
  /// App [id] gets (or loses, with null) its icon: `apps_changed`, like the
  /// daemon when a web icon finishes downloading.
  void setAppIcon(String id, String? icon) {
    final i = apps.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final a = apps[i];
    apps[i] = App(id: a.id, name: a.name, kind: a.kind, icon: icon);
    emitRaw('apps_changed');
  }

  /// Dev key: the next app without an icon that has a fixture in [iconDir]
  /// gets it. Returns its id, or null when all have one.
  String? iconArrives(String iconDir) {
    for (final a in apps) {
      if (a.icon != null) continue;
      for (final ext in ['png', 'svg']) {
        final p = '$iconDir/${a.id}.$ext';
        if (File(p).existsSync()) {
          setAppIcon(a.id, p);
          return a.id;
        }
      }
    }
    return null;
  }

  void setGames(List<Game> games) {
    _games = List.of(games);
    emitRaw('games_changed');
  }

  List<Game> get games => List.unmodifiable(_games);

  /// Dev key: the first game that is not installed finishes its update; if
  /// all are installed, the first one needs an update again.
  void toggleFirstUpdate() {
    final i = _games.indexWhere(
      (g) => g.installState != InstallState.installed,
    );
    final j = i >= 0 ? i : 0;
    final g = _games[j];
    final next = List.of(_games);
    next[j] = Game(
      appid: g.appid,
      name: g.name,
      installState: i >= 0
          ? InstallState.installed
          : InstallState.updateRequired,
      sizeBytes: g.sizeBytes,
      lastPlayed: g.lastPlayed,
      artwork: g.artwork,
    );
    setGames(next);
  }

  /// Steam shows dialogs that wait to be seen (empty: none any more).
  void setSteamAttention(List<SteamWindow> windows) {
    if (_attention.length == windows.length &&
        _attention.every(windows.contains)) {
      return;
    }
    _attention = List.of(windows);
    emitRaw(
      'steam_attention',
      SteamAttentionEvent(windows: _attention).toJson(),
    );
  }

  List<SteamWindow> get attention => List.unmodifiable(_attention);

  /// The Home button, on demand: the launcher comes to the front, then the event.
  void pressHome() {
    _setFocus(null);
    _setOsk(false);
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
    // While the keyboard is up, only its own connection gets input.
    if (_oskVisible ? clientName != 'hinteros-osk' : _focused != null) return;
    emitRaw('input_nav', InputNavEvent(action: action, phase: phase).toJson());
  }

  /// The running apps (for dev keys and tests).
  List<RunningApp> get running => List.unmodifiable(_running);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    system.dispose();
    await _statusController.close();
    await _eventController.close();
  }
}
