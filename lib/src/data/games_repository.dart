import 'apps_repository.dart';

/// A game as the Games section shows it.
class Game {
  const Game({required this.id, required this.title, this.artworkPath});

  final String id;
  final String title;

  /// Absolute path to cover art (2:3), if the daemon has some.
  final String? artworkPath;
}

abstract class GamesRepository {
  Future<List<Game>> list();

  /// Starts [game]; throws like [AppsRepository.launch].
  Future<void> launch(Game game);
}

/// TODO(0.3): replace with a repository over `games.list` (artwork paths,
/// launch by Steam app id). Until then the only "game" the 0.2 daemon can know
/// about is the Steam app itself, so this lists the `apps.list` entries whose
/// id starts with `steam`.
class AppsBackedGamesRepository implements GamesRepository {
  AppsBackedGamesRepository(this._apps);

  final AppsRepository _apps;

  @override
  Future<List<Game>> list() async => [
    for (final a in await _apps.list())
      if (a.id.startsWith('steam'))
        Game(id: a.id, title: a.name, artworkPath: a.icon),
  ];

  @override
  Future<void> launch(Game game) async {
    await _apps.launch(game.id);
  }
}

/// TODO(0.3): drop once the real library is available; used by `--mock`,
/// widget tests and goldens so the Games grid has something to show.
class MockGamesRepository implements GamesRepository {
  MockGamesRepository({this.games = mockGames});

  final List<Game> games;
  final launched = <String>[];

  @override
  Future<List<Game>> list() async => games;

  @override
  Future<void> launch(Game game) async => launched.add(game.id);
}

const mockGames = <Game>[
  Game(id: 'g1', title: 'Hollow Knight'),
  Game(id: 'g2', title: 'Celeste'),
  Game(id: 'g3', title: 'Hades'),
  Game(id: 'g4', title: 'Stardew Valley'),
  Game(id: 'g5', title: 'Portal 2'),
  Game(id: 'g6', title: 'Cuphead'),
  Game(id: 'g7', title: 'Dead Cells'),
  Game(id: 'g8', title: 'Terraria'),
  Game(id: 'g9', title: 'Disco Elysium'),
  Game(id: 'g10', title: 'Rocket League'),
  Game(id: 'g11', title: 'Slay the Spire'),
  Game(id: 'g12', title: 'Vampire Survivors'),
  Game(id: 'g13', title: 'Balatro'),
  Game(id: 'g14', title: 'Factorio'),
];
