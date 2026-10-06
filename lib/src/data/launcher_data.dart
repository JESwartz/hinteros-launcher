import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'apps_repository.dart';
import 'games_repository.dart';

/// One card of the Continue row.
class ContinueEntry {
  const ContinueEntry({required this.id, required this.name, this.running});

  final String id;
  final String name;

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
          ])
          .catchError((_) {}),
    );
    if (status is Connected) _refreshAll();
  }

  void _onStatus(ConnectionStatus s) {
    if (_disposed) return;
    final was = status is Connected;
    status = s;
    notifyListeners();
    if (s is Connected && !was) _refreshAll();
  }

  void _onEvent(SessionEvent e) {
    switch (e) {
      case HomePressedEvent():
        _homePressed.add(null);
      case InputNavEvent():
        _nav.add(e);
      case AppStartedEvent() || AppExitedEvent() || FocusChangedEvent():
        unawaited(refreshRunning());
      default:
        break;
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshApps(), refreshRunning(), _refreshGames()]);
  }

  Future<void> _refreshApps() async {
    try {
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

  // TODO(0.3): refresh again on a games-changed event.
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

  Future<void> refreshRunning() async {
    try {
      final r = await apps.running();
      if (_disposed) return;
      running = r;
      notifyListeners();
    } catch (_) {
      // Best effort: the badge is decoration.
    }
  }

  bool isRunning(String id) => running.any((r) => r.id == id);

  /// Running apps first, then this session's recent launches that are not
  /// running (when still listed).
  List<ContinueEntry> get continueEntries => [
    for (final r in running) ContinueEntry(id: r.id, name: r.name, running: r),
    for (final id in _recent)
      if (!isRunning(id))
        if (appList?.where((a) => a.id == id).firstOrNull case final a?)
          ContinueEntry(id: a.id, name: a.name),
  ];

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

  Future<void> launchGame(Game g) async {
    try {
      await games.launch(g);
      unawaited(refreshRunning());
    } catch (e) {
      _toast("Couldn't start ${g.title}: ${describe(e)}");
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
