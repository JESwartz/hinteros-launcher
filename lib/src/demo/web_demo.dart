/// The browser demo's content (`lib/web_main.dart`): free apps and games
/// only, generic profile names, placeholder numbers. The files are under
/// `assets/demo/` (web-only assets, see `assets/demo/NOTICE`), read through
/// the local files seam, so a desktop test can check them from the repo.
/// The desktop `--mock` and the tests keep their own fixtures.
library;

import '../api/api.dart'
    show App, AppKind, Game, GameArtwork, InstallState, MockDaemon;
import '../platform/local_files.dart';
import '../system/catalog.dart';
import '../system/mock_system.dart';
import '../system/models.dart';
import '../system/profiles.dart';
import '../system/storage.dart';

const demoDir = 'assets/demo';
const demoIconDir = '$demoDir/icons';
const demoArtDir = '$demoDir/art';
const demoCatalogPath = '$demoDir/catalog/catalog.json';

/// The texts the browser preloads (the catalog and its READMEs).
const demoTextPrefixes = ['$demoDir/catalog/'];

/// The admin password of the demo (made up, safe to print).
const demoAdminPassword = 'blue harbour';

/// The games of the demo, in the Games tab while installed. Every other
/// installed catalog entry is an app.
const demoGameIds = [
  'supertuxkart',
  'neverball',
  'shattered-pixel-dungeon',
  'openarena',
  'freedoom-phase1',
];

/// The Apps tab's order.
const demoAppIds = ['jellyfin', 'moonlight', 'firefox'];

/// Installed at the start; OpenArena and Freedoom wait in the Store.
const demoInstalled = {
  'jellyfin',
  'moonlight',
  'firefox',
  'supertuxkart',
  'neverball',
  'shattered-pixel-dungeon',
};

/// The Store catalog, in the real index format, read by the real parser.
List<StoreApp> demoCatalog() => parseCatalogIndex(
  readLocalText(demoCatalogPath)!,
  readTerms: termsReaderFor(demoCatalogPath),
  readReadme: readmeReaderFor(demoCatalogPath),
);

String? _icon(String id) {
  for (final ext in ['png', 'svg']) {
    final p = '$demoIconDir/$id.$ext';
    if (localFileExists(p)) return p;
  }
  return null;
}

/// The Apps tab for [installed].
List<App> demoApps(List<StoreApp> catalog, Set<String> installed) => [
  for (final id in demoAppIds)
    for (final a in catalog)
      if (a.id == id && installed.contains(id))
        App(
          id: a.id,
          name: a.name,
          kind: a.isWeb ? AppKind.web : AppKind.native,
          icon: _icon(a.id),
          permissions: const [],
        ),
];

/// When each game was last played (seconds), for the Continue row.
const _lastPlayed = {
  'supertuxkart': 1790000000,
  'neverball': 1789000000,
  'shattered-pixel-dungeon': 1788000000,
};

/// The Games tab for [installed]: placeholder cover art, no Steam.
List<Game> demoGames(List<StoreApp> catalog, Set<String> installed) => [
  for (final (i, id) in demoGameIds.indexed)
    for (final a in catalog)
      if (a.id == id && installed.contains(id))
        Game(
          // Not a Steam id: the mock only needs a number per game.
          appid: 900001 + i,
          name: a.name,
          installState: InstallState.installed,
          sizeBytes: a.sizeMiB * 1024 * 1024,
          lastPlayed: _lastPlayed[id],
          artwork: GameArtwork(
            portrait: '$demoArtDir/${id}_portrait.png',
            header: '$demoArtDir/${id}_header.png',
            hero: null,
            logo: null,
            icon: null,
          ),
        ),
];

/// Alex (admin, PIN 2580), Sam (PIN 1593, locked) and Robin (PIN 7410).
List<MockProfile> demoProfiles() => [
  MockProfile(
    id: 'p1',
    name: 'Alex',
    color: ProfileColor.teal,
    pin: '2580',
    admin: true,
    usage: ProfileUsage(
      totalBytes: _gb(14.2),
      steamGamesBytes: 0,
      at: DateTime(2026, 10, 7, 21),
    ),
    lastUsedAt: DateTime(2026, 10, 7, 22),
  ),
  MockProfile(
    id: 'p2',
    name: 'Sam',
    color: ProfileColor.orange,
    pin: '1593',
    locked: true,
    usage: ProfileUsage(
      totalBytes: _gb(9.6),
      steamGamesBytes: 0,
      at: DateTime(2026, 10, 7, 21),
    ),
    lastUsedAt: DateTime(2026, 10, 6, 19),
  ),
  MockProfile(
    id: 'p3',
    name: 'Robin',
    color: ProfileColor.purple,
    pin: '7410',
    usage: ProfileUsage(
      totalBytes: _gb(1.8),
      steamGamesBytes: 0,
      at: DateTime(2026, 10, 7, 21),
    ),
    lastUsedAt: DateTime(2026, 10, 5, 17),
  ),
];

/// The system generations, with the demo's names.
List<Generation> demoGenerations() => [
  for (var g = 12; g >= 9; g--)
    Generation(
      generation: g,
      date: DateTime(2026, 9, g + 6, 9),
      rev: (g * 0x1234567).toRadixString(16).padLeft(40, '0'),
      current: g == 12,
      booted: g == 12,
      profiles: switch (g) {
        12 => const [
          (id: 'p1', name: 'Alex'),
          (id: 'p2', name: 'Sam'),
          (id: 'p3', name: 'Robin'),
        ],
        11 => const [(id: 'p1', name: 'Alex'), (id: 'p2', name: 'Sam')],
        10 => const [(id: 'p1', name: 'Alex')],
        _ => null,
      },
    ),
];

int _gb(double gb) => (gb * 1000 * 1000 * 1000).round();

StorageNode _sum(StorageKind kind, List<StorageNode> children, {String? id}) =>
    StorageNode(
      kind: kind,
      bytes: children.fold<int>(0, (a, c) => a + c.bytes),
      children: children,
      id: id,
    );

StorageNode _dir(String name, double gb) => StorageNode(
  kind: StorageKind.dir,
  bytes: _gb(gb),
  name: name,
  children: [StorageNode(kind: StorageKind.files, bytes: _gb(gb))],
);

/// The folders of each home (profile id or `guest`): no Steam games.
StorageNode demoHome(String id) {
  final children = switch (id) {
    'p1' => [
      _dir('.local', 6.1),
      _dir('Videos', 4.3),
      _dir('.cache', 2.2),
      _dir('Downloads', 1.6),
    ],
    'p2' => [_dir('Music', 5.8), _dir('.local', 2.4), _dir('.cache', 1.4)],
    'p3' => [_dir('.local', 1.1), _dir('.cache', 0.6)],
    _ => [_dir('.cache', 0.3)],
  };
  return id == 'guest'
      ? _sum(StorageKind.guest, children)
      : _sum(StorageKind.profile, children, id: id);
}

/// The mock daemon and system services of the demo, wired so that Store
/// installs and removals show in Apps and Games.
class WebDemo {
  WebDemo._(this.daemon, this.services);

  /// [autoRunJobs]: jobs step through their stages by themselves (the
  /// page); tests drive them by hand.
  factory WebDemo({bool autoRunJobs = true}) {
    final catalog = demoCatalog();
    final daemon = MockDaemon(
      apps: demoApps(catalog, demoInstalled),
      games: demoGames(catalog, demoInstalled),
    );
    final services = MockSystemServices(
      autoRunJobs: autoRunJobs,
      iconDir: demoIconDir,
      profileBox: MockProfileBox(profiles: demoProfiles()),
      catalog: catalog,
      installed: demoInstalled,
      generations: demoGenerations(),
      homes: demoHome,
    );
    services.mockAuth.adminPassword = demoAdminPassword;
    services.mockProfiles.starter = StarterSet(const [
      'firefox',
      'jellyfin',
    ], updatedAt: DateTime(2026, 10, 1));
    services.mockStore.earlierGenerations = [
      AppGeneration(
        generation: 2,
        date: DateTime(2026, 10, 3, 18),
        ids: const ['firefox', 'jellyfin', 'supertuxkart'],
      ),
      AppGeneration(
        generation: 1,
        date: DateTime(2026, 9, 28, 12),
        ids: const ['firefox', 'jellyfin'],
        systemRev: '0f3c5a9e2b7d4c1a8e6f9b0d2c4e6a8b1d3f5a7c',
      ),
    ];
    final demo = WebDemo._(daemon, services);
    services.mockStore.changes.listen((_) => demo._sync(catalog));
    return demo;
  }

  final MockDaemon daemon;
  final MockSystemServices services;

  void _sync(List<StoreApp> catalog) {
    final installed = services.mockStore.installed;
    final apps = demoApps(catalog, installed);
    if (apps.map((a) => a.id).join(',') !=
        daemon.apps.map((a) => a.id).join(',')) {
      daemon.apps
        ..clear()
        ..addAll(apps);
      daemon.emitRaw('apps_changed');
    }
    final games = demoGames(catalog, installed);
    if (games.map((g) => g.appid).join(',') !=
        daemon.games.map((g) => g.appid).join(',')) {
      daemon.setGames(games);
    }
  }
}
