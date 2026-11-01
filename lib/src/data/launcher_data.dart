import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../log.dart';
import '../osk/osk_control.dart';
import 'app_icons.dart';
import 'apps_repository.dart';
import 'games_repository.dart';

/// Something the user asked for failed: a clear sentence naming the app, and the
/// daemon's error code and message as a detail line (also in the log).
class Failure {
  const Failure({required this.title, required this.body, this.detail});

  final String title;
  final String body;
  final String? detail;
}

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

  /// Shows the on-screen keyboard while one of the launcher's text fields has
  /// focus.
  late final OskControl osk = OskControl(connection);

  ConnectionStatus status = const Connecting();
  List<App>? appList;
  Object? appsError;
  List<Game> gameList = const [];

  /// Steam windows waiting to be seen (empty: nothing needs attention).
  List<SteamWindow> steamAttention = const [];

  /// The running app the user is being asked to close (confirm step), if any.
  ({String id, String name, String? iconPath})? closeRequest;
  List<RunningApp> running = const [];

  /// An app the launcher has asked to start and that the daemon has not yet
  /// reported focused (`focus_changed`), exited or failed: the full-screen
  /// "Starting ..." view shows while this is set.
  ({String id, String name, String? iconPath})? launching;

  /// The running app that has focus (`focus_changed`, `apps.running`);
  /// null: the launcher.
  String? focusedApp;

  /// The launcher is in front: no app has focus and no app is starting.
  bool get inFront => focusedApp == null && launching == null;

  /// Apps that got `focus_changed` since the current launch began (the event
  /// can arrive before the answer to `apps.launch`).
  final Set<String> _focusedSince = {};

  /// App ids launched this session, newest first (feeds Continue).
  final List<String> _recent = [];

  final _messages = StreamController<String>.broadcast();

  /// Short user-facing messages (launch failures) for a toast.
  Stream<String> get messages => _messages.stream;

  final _failures = StreamController<Failure>.broadcast();

  /// Failures to show in a dialog (a launch that did not work).
  Stream<Failure> get failures => _failures.stream;

  /// Set when the daemon says to go Home.
  final _homePressed = StreamController<void>.broadcast();
  Stream<void> get homePressed => _homePressed.stream;

  /// Controller input from the daemon.
  final _nav = StreamController<InputNavEvent>.broadcast();
  Stream<InputNavEvent> get inputNav => _nav.stream;

  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<SessionEvent>? _eventSub;

  /// The on-screen keyboard is up (`osk_changed`). The daemon then sends
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
            EventName.oskChanged,
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
      case OskChangedEvent():
        oskVisible = e.visible;
      case InputNavEvent():
        if (!oskVisible) _nav.add(e);
      case FocusChangedEvent():
        final id = e.app;
        focusedApp = id;
        notifyListeners();
        if (id != null) _focusedSince.add(id);
        if (id != null && launching?.id == id) _endLaunching();
        unawaited(refreshRunning());
      case AppExitedEvent():
        _exitWaiters.remove(e.id)?.complete();
        if (launching?.id == e.id) {
          final l = launching!;
          _endLaunching();
          if (e.reason == ExitReason.crashed ||
              e.reason == ExitReason.launchTimeout) {
            _failedToStart(l.name, e.reason, e.exitCode);
          }
        }
        unawaited(refreshRunning());
      case AppStartedEvent():
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
      final r = await apps.runningAndFocus();
      if (_disposed) return;
      running = r.apps;
      focusedApp = r.focused;
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
    return gameList.where((g) => g.steamAppId == appid).firstOrNull;
  }

  void _beginLaunching(String id, String name, String? iconPath) {
    _focusedSince.clear();
    launching = (id: id, name: name, iconPath: iconPath);
    notifyListeners();
  }

  void _endLaunching() {
    if (launching == null) return;
    launching = null;
    notifyListeners();
  }

  /// The launch answer came: follow the id the daemon uses, and finish if it
  /// already reported that app focused (or it had the focus already: then no
  /// `focus_changed` comes).
  void _launched(RunningApp app) {
    final l = launching;
    if (l == null) return;
    if (_focusedSince.contains(app.id) || focusedApp == app.id) {
      _endLaunching();
    } else if (app.id != l.id) {
      launching = (id: app.id, name: l.name, iconPath: l.iconPath);
      notifyListeners();
    }
  }

  /// B or Home: stop waiting and show Home. The app keeps starting.
  void cancelLaunching() => _endLaunching();

  void _failedToStart(String name, ExitReason reason, int? code) {
    final why = reason == ExitReason.launchTimeout
        ? 'it never showed a window'
        : 'it stopped right away${code == null ? '' : ' (exit status $code)'}';
    logFailure("start $name", why);
    if (!_failures.isClosed) {
      _failures.add(
        Failure(
          title: "Couldn't start $name",
          body: reason == ExitReason.launchTimeout
              ? "$name didn't open a window."
              : "$name stopped right away${code == null ? '' : ' (exit status $code)'}.",
          detail: reason.name,
        ),
      );
    }
  }

  /// Asked before an app whose vendor terms this profile has not accepted
  /// yet is started (it came with the starter set, `needs_terms`): the
  /// first-launch terms. False: it is not started.
  Future<bool> Function(App app)? beforeLaunch;

  /// Asked when every app display is in use (`no_app_display`, 0.18): which
  /// of the [running] apps to close so that [name] can open (its id), or
  /// null to open nothing. Nothing closes without this.
  Future<String?> Function(String name, List<RunningApp> running)?
  chooseAppToClose;

  /// How long an app the user chose to close may take to exit (the daemon
  /// kills it after its close timeout).
  static const closeWait = Duration(seconds: 30);

  /// `app_exited` for an app being closed so that another can open.
  final Map<String, Completer<void>> _exitWaiters = {};

  Future<void> launchApp(String id, String name) async {
    final app = appList?.where((a) => a.id == id).firstOrNull;
    final gate = beforeLaunch;
    if (app != null && app.needsTerms != null && gate != null) {
      if (!await gate(app)) return;
    }
    await _startApp(id, name);
  }

  Future<void> _startApp(String id, String name) async {
    _beginLaunching(id, name, _iconOf(id));
    try {
      _launched(await apps.launch(id));
      _recent
        ..remove(id)
        ..insert(0, id);
      if (_recent.length > 8) _recent.removeLast();
      unawaited(refreshRunning());
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.noAppDisplay && chooseAppToClose != null) {
        _endLaunching();
        if (await _closeOneFor(id, name, e)) await _startApp(id, name);
      } else {
        _fail('start', name, e);
      }
    } catch (e) {
      _fail('start', name, e);
    }
  }

  /// Every app display is in use: the user picks a running app to close (or
  /// cancels). True once the chosen app has exited, so its display is free.
  Future<bool> _closeOneFor(String id, String name, ApiException e) async {
    final List<RunningApp> holders;
    try {
      holders = NoAppDisplayData.fromJson(
        (e.data! as Map).cast<String, dynamic>(),
      ).apps;
    } catch (_) {
      _fail('start', name, e);
      return false;
    }
    final choose = chooseAppToClose;
    if (choose == null || holders.isEmpty) {
      _fail('start', name, e);
      return false;
    }
    final pick = await choose(name, holders);
    if (pick == null || _disposed) return false;
    final pickName =
        holders.where((r) => r.id == pick).firstOrNull?.name ?? pick;
    // "Starting ..." while the chosen app closes.
    _beginLaunching(id, name, _iconOf(id));
    final exited = (_exitWaiters[pick] ??= Completer<void>()).future;
    try {
      await apps.close(pick);
    } on ApiException catch (err) {
      if (err.code != ApiErrorCode.appNotFound) {
        _exitWaiters.remove(pick);
        _fail('close', pickName, err);
        return false;
      }
      // Gone already.
      _exitWaiters.remove(pick)?.complete();
    } catch (err) {
      _exitWaiters.remove(pick);
      _fail('close', pickName, err);
      return false;
    }
    unawaited(refreshRunning());
    final ok = await exited
        .then((_) => true)
        .timeout(closeWait, onTimeout: () => false);
    if (!ok) {
      _exitWaiters.remove(pick);
      _fail('close', pickName, TimeoutException('it did not exit'));
      return false;
    }
    return !_disposed;
  }

  /// A Continue card: running games and command apps are not in `apps.list`,
  /// so those are focused; everything else launches by id.
  Future<void> launchEntry(ContinueEntry e) async {
    if (e.isRunning && appList?.any((a) => a.id == e.id) != true) {
      try {
        await apps.focus(e.id);
      } catch (err) {
        _fail('switch to', e.name, err);
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
    _beginLaunching(g.runningId, g.name, null);
    try {
      _launched(await games.launch(g));
      unawaited(refreshRunning());
    } catch (e) {
      _fail('start', g.name, e);
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
      _fail('close', r.name, e);
    }
  }

  /// Closes app [id] without asking (the caller already did): a Store app
  /// is closed before it is removed. Not running is fine.
  Future<void> closeApp(String id) async {
    if (!isRunning(id)) return;
    try {
      await apps.close(id);
    } on ApiException catch (e) {
      if (e.code != ApiErrorCode.appNotFound) rethrow;
    }
    unawaited(refreshRunning());
  }

  /// Force Stop on the app's Store page: kills app [id] now (Steam: the
  /// whole client). Not running is fine.
  Future<void> forceStopApp(String id) async {
    if (!isRunning(id)) return;
    try {
      await apps.forceStop(id);
    } on ApiException catch (e) {
      if (e.code != ApiErrorCode.appNotFound) rethrow;
    }
    unawaited(refreshRunning());
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
      _fail('open', 'Steam', e);
    }
  }

  /// [verb] on [name] failed with [e]: logged with the code and message, and
  /// shown as a sentence naming the app.
  void _fail(String verb, String name, Object e) {
    _endLaunching();
    logFailure("$verb $name", e);
    final code = e is ApiException ? e.code : null;
    final body = switch (code) {
      ApiErrorCode.appNotFound =>
        "$name isn't installed any more. Install it again from the Store.",
      ApiErrorCode.appLaunchFailed =>
        "$name won't run. It may be broken or missing.",
      _ when e is DaemonUnavailableException =>
        "Lost the connection to the HinterOS service. Try again in a moment.",
      _ => 'Something went wrong.',
    };
    final detail = switch (e) {
      ApiException() => 'Error ${e.code}: ${e.message}',
      DaemonUnavailableException() => 'Not connected (${e.reason})',
      _ => '$e',
    };
    if (!_failures.isClosed) {
      _failures.add(
        Failure(title: "Couldn't $verb $name", body: body, detail: detail),
      );
    }
  }

  void _toast(String m) {
    if (!_messages.isClosed) _messages.add(m);
  }

  @override
  void dispose() {
    _disposed = true;
    _statusSub?.cancel();
    _eventSub?.cancel();
    _messages.close();
    _failures.close();
    _homePressed.close();
    _nav.close();
    super.dispose();
  }
}
