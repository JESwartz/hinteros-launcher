import '../api/api.dart';

/// What the launcher shows and does with TV apps. Everything goes through
/// here so the UI never talks to the daemon connection directly.
class AppsRepository {
  AppsRepository(this.connection);

  final DaemonConnection connection;

  Future<List<App>> list() async => (await connection.appsList()).apps;

  Future<List<RunningApp>> running() async =>
      (await connection.appsRunning()).apps;

  /// Starts [app], or focuses it if it already runs.
  Future<RunningApp> launch(String id) async =>
      (await connection.appsLaunch(AppsLaunchParams(id: id))).app;

  // TODO(0.3): Future<void> close(String id) once apps.close exists, for a
  // "Close" action on Continue cards.
}
