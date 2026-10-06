import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'app_icons.dart';
import 'apps_repository.dart';
import 'games_repository.dart';

/// One card of the Continue row.
class ContinueEntry {
  const ContinueEntry({
    required this.id,
    required this.name,
    this.running,
    this.artPath,
    this.iconPath,
  });

  final String id;
  final String name;

  /// Landscape art that fills the card: a running game's header image.
  final String? artPath;

  /// The app's icon, drawn on a tinted backdrop.
  final String? iconPath;

  /// Null when it is only a recent launch.
  final RunningApp? running;
  bool get isRunning => running != null;
}

/// The launcher's view of the world: connection state, apps, games, what is
/// running. Screens listen to this; it owns all daemon traffic through the
/// repositories. Events are not replayed by the daemon, so everything is
/// re-queried on connect and when an event says something changed.
class LauncherData extends ChangeNotifier {
  LauncherData({
    required this.connection,
    required this.apps,
    required this.games,
  });

  final DaemonConnection connection;
  final AppsRepository apps;
  final GamesRepository games;

  ConnectionStatus status = const Connecting();
  List<App>? appList;
  Object? appsError;
  List<Game> gameList = const [];

  /// Steam windows waiting to be seen (empty: nothing needs attention).
  List<SteamWindow> steamAttention = const [];

  /// The running app the user is being asked to close (confirm step), if any.
  ({String id, String name, String? iconPath})? closeRequest;
  List<RunningApp> running = const [];

  /// App ids launched this session, newest first (feeds Continue).
  final List<String> _recent = [];

  final _messages = StreamController<String>.broadcast();

  /// Short user-facing messages (launch failures) for a toast.
  Stream<String> get messages => _messages.stream;

  /// Set when the daemon says to go Home.
  final _homePressed = StreamController<void>.broadcast();
  Stream<void> get homePressed => _homePressed.stream;

  /// Controller input from the daemon.
  final _nav = StreamController<InputNavEvent>.broadcast();
  Stream<InputNavEvent> get inputNav => _nav.stream;

  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<SessionEvent>? _eventSub;

  /// The on-screen keyboard is up (`osk_visibility`). The daemon then sends
  /// `input_nav` only to the keyboard, so this is a second line of defence.
  bool oskVisible = false;
  bool _disposed = false;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    status = connection.status;
    _statusSub = connection.statusChanges.listen(_onStatus);
    _eventSub = connection.events.listen(_onEvent);
    connection.start();
    unawaited(
      connection
          .subscribeTo([
            EventName.homePressed,
            EventName.appStarted,
            EventName.appExited,
            EventName.focusChanged,
            EventName.inputNav,
            EventName.gamesChanged,
            EventName.appsChanged,
            EventName.steamAttention,
            EventName.oskVisibility,
          ])
          .catchError((_) {}),
    );
    if (status is Connected) _refreshAll();
  }

  void _onStatus(ConnectionStatus s) {
    if (_disposed) return;
    final was = status is Connected;
    status = s;
    if (s is! Connected) oskVisible = false;
    notifyListeners();
    if (s is Connected && !was) _refreshAll();
  }

  void _onEvent(SessionEvent e) {
    switch (e) {
      case HomePressedEvent():
        _homePressed.add(null);
      case OskVisibilityEvent():
        oskVisible = e.visible;
      case InputNavEvent():
        if (!oskVisible) _nav.add(e);
      case AppStartedEvent() || AppExitedEvent() || FocusChangedEvent():
        unawaited(refreshRunning());
      case GamesChangedEvent():
        unawaited(_refreshGames());
      case AppsChangedEvent():
        unawaited(_refreshApps());
      case SteamAttentionEvent():
        steamAttention = e.windows;
        notifyListeners();
      default:
        break;
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshApps(),
      refreshRunning(),
      _refreshGames(),
      _refreshAttention(),
    ]);
  }

  Future<void> _refreshApps() async {
    try {
      // Icon files may have changed behind the same path.
      AppIconCache.instance.invalidate();
      final l = await apps.list();
      if (_disposed) return;
      appList = l;
      appsError = null;
    } catch (e) {
      if (_disposed) return;
      appsError = e;
    }
    notifyListeners();
  }

  Future<void> _refreshGames() async {
    try {
      final g = await games.list();
      if (_disposed) return;
      gameList = g;
      notifyListeners();
    } catch (_) {
      // Best effort: Games just stays empty.
    }
  }

  Future<void> _refreshAttention() async {
    try {
      final w = await apps.steamAttention();
      if (_disposed) return;
      steamAttention = w;
      notifyListeners();
    } catch (_) {
      // Best effort: the banner just does not show.
    }
  }

  Future<void> refreshRunning() async {
    try {
      final r = await apps.running();
      if (_disposed) return;
      running = r;
      if (closeRequest != null && !isRunning(closeRequest!.id)) {
        closeRequest = null; // it ended by itself
      }
      notifyListeners();
    } catch (_) {
      // Best effort: the badge is decoration.
    }
  }

  bool isRunning(String id) => running.any((r) => r.id == id);

  /// Running apps first, then this session's recent launches that are not
  /// running (when still listed).
  List<ContinueEntry> get continueEntries => [
    for (final r in running)
      ContinueEntry(
        id: r.id,
        name: r.name,
        running: r,
        artPath: _gameOfRunning(r.id)?.artwork.header,
        iconPath: _iconOf(r.id),
      ),
    for (final id in _recent)
      if (!isRunning(id))
        if (appList?.where((a) => a.id == id).firstOrNull case final a?)
          ContinueEntry(id: a.id, name: a.name, iconPath: a.icon),
  ];

  String? _iconOf(String id) =>
      appList?.where((a) => a.id == id).firstOrNull?.icon;

  /// The library game behind a running id `steam-<appid>`, if known.
  Game? _gameOfRunning(String id) {
    final m = RegExp(r'^steam-(\d+)$').firstMatch(id);
    if (m == null) return null;
    final appid = int.parse(m[1]!);
    return gameList.where((g) => g.appid == appid).firstOrNull;
  }

  Future<void> launchApp(String id, String name) async {
    try {
      await apps.launch(id);
      _recent
        ..remove(id)
        ..insert(0, id);
      if (_recent.length > 8) _recent.removeLast();
      unawaited(refreshRunning());
    } catch (e) {
      _toast("Couldn't start $name: ${describe(e)}");
    }
  }

  /// A Continue card: running games and command apps are not in `apps.list`,
  /// so those are focused; everything else launches by id.
  Future<void> launchEntry(ContinueEntry e) async {
    if (e.isRunning && appList?.any((a) => a.id == e.id) != true) {
      try {
        await apps.focus(e.id);
      } catch (err) {
        _toast("Couldn't switch to ${e.name}: ${describe(err)}");
      }
      return;
    }
    await launchApp(e.id, e.name);
  }

  Future<void> launchGame(Game g) async {
    final why = g.cannotLaunchReason;
    if (why != null) {
      _toast(why);
      return;
    }
    try {
      await games.launch(g);
      unawaited(refreshRunning());
    } catch (e) {
      _toast("Couldn't start ${g.name}: ${describe(e)}");
    }
  }

  /// The running app behind game [g], if it runs.
  bool isGameRunning(Game g) => isRunning(g.runningId);

  /// Asks to close the running app [id] (a confirm step comes first).
  void requestClose(String id, String name) {
    if (!isRunning(id)) return;
    closeRequest = (id: id, name: name, iconPath: _iconOf(id));
    notifyListeners();
  }

  void cancelClose() {
    if (closeRequest == null) return;
    closeRequest = null;
    notifyListeners();
  }

  /// The user confirmed: close the app. Continue follows `app_exited`.
  Future<void> confirmClose() async {
    final r = closeRequest;
    if (r == null) return;
    closeRequest = null;
    notifyListeners();
    try {
      await apps.close(r.id);
      unawaited(refreshRunning());
    } catch (e) {
      _toast("Couldn't close ${r.name}: ${describe(e)}");
    }
  }

  /// "Open Steam" on the attention banner.
  Future<void> focusSteam() async {
    try {
      await apps.focusSteam();
      unawaited(refreshRunning());
    } catch (e) {
      if (e is ApiException && e.code == ApiErrorCode.steamNoWindows) {
        // Gone already: refresh the banner.
        unawaited(_refreshAttention());
        return;
      }
      _toast("Couldn't open Steam: ${describe(e)}");
    }
  }

  void _toast(String m) {
    if (!_messages.isClosed) _messages.add(m);
  }

  static String describe(Object e) => switch (e) {
    ApiException() => e.message,
    DaemonUnavailableException() => 'the HinterOS service is not connected',
    _ => '$e',
  };

  @override
  void dispose() {
    _disposed = true;
    _statusSub?.cancel();
    _eventSub?.cancel();
    _messages.close();
    _homePressed.close();
    _nav.close();
    super.dispose();
  }
}
