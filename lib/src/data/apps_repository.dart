import '../api/api.dart';

/// What the launcher shows and does with TV apps. Everything goes through
/// here so the UI never talks to the daemon connection directly.
class AppsRepository {
  AppsRepository(this.connection);

  final DaemonConnection connection;

  Future<List<App>> list() async => (await connection.appsList()).apps;

  Future<List<RunningApp>> running() async =>
      (await connection.appsRunning()).apps;

  /// The running apps and the one with focus (null: the launcher).
  Future<({List<RunningApp> apps, String? focused})> runningAndFocus() async {
    final r = await connection.appsRunning();
    return (apps: r.apps, focused: r.focused);
  }

  /// Starts [app], or focuses it if it already runs.
  Future<RunningApp> launch(String id) async =>
      (await connection.appsLaunch(AppsLaunchParams(id: id))).app;

  /// Brings the running app [id] to the front.
  Future<void> focus(String id) async {
    await connection.appsFocus(AppsFocusParams(id: id));
  }

  /// Asks the running app [id] to quit; `app_exited` (reason `closed`)
  /// follows. For Steam this closes Big Picture, not the client.
  Future<void> close(String id) async {
    await connection.appsClose(AppsCloseParams(id: id));
  }

  /// Steam's windows that are waiting to be seen (empty: none).
  Future<List<SteamWindow>> steamAttention() async =>
      (await connection.steamAttention()).windows;

  /// Brings Steam's windows to the front; throws 2003 when there are none.
  /// [screensaver]: as the screen saver (the daemon keeps the input, and the
  /// first press comes back here).
  Future<RunningApp> focusSteam({bool screensaver = false}) async =>
      (await connection.steamFocus(
        SteamFocusParams(screensaver: screensaver ? true : null),
      )).app;
}
