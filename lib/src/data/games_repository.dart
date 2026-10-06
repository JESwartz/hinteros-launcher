import '../api/api.dart';

/// Whether a game can be started right now. Only an installed game can; Steam
/// itself would update or finish a game first, which the launcher cannot show.
extension GameState on Game {
  bool get canLaunch => installState == InstallState.installed;

  /// Unknown states (a newer daemon) are treated like an update in progress.
  InstallState get effectiveState => installState == InstallState.unknown
      ? InstallState.updating
      : installState;

  /// The id the daemon gives this game while it runs.
  String get runningId => 'steam-$appid';

  /// Short badge text for the card, null for an installed game.
  String? get badge => switch (effectiveState) {
    InstallState.installed => null,
    InstallState.updateRequired => 'Update required',
    InstallState.updating => 'Updating',
    InstallState.installing => 'Installing',
    InstallState.uninstalling => 'Removing',
    InstallState.unknown => 'Updating',
  };

  /// Badge text for narrow cards.
  String? get shortBadge => switch (effectiveState) {
    InstallState.updateRequired => 'Update',
    _ => badge,
  };

  /// Why [canLaunch] is false, for a message; null when it can launch.
  String? get cannotLaunchReason => switch (effectiveState) {
    InstallState.installed => null,
    InstallState.updateRequired =>
      '$name needs an update first. Open Steam to update it.',
    InstallState.updating =>
      '$name is updating. You can play it when that is done.',
    InstallState.installing =>
      '$name is still installing. You can play it when that is done.',
    InstallState.uninstalling => '$name is being removed.',
    InstallState.unknown => '$name is updating.',
  };
}

/// The Steam library through `games.list`, and launching its games.
class GamesRepository {
  GamesRepository(this.connection);

  final DaemonConnection connection;

  Future<List<Game>> list() async => (await connection.gamesList()).games;

  /// Starts [game] through Steam (or focuses it when it already runs).
  Future<RunningApp> launch(Game game) async => (await connection.appsLaunch(
    AppsLaunchParams(url: 'steam://rungameid/${game.appid}'),
  )).app;
}
