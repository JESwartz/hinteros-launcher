/// The Store data of [MockDaemon] (session API 0.8): a catalog in the wire
/// shape of `store.list`, built from the real-format index fixture
/// (`test/fixtures/catalog`, placeholder terms text) plus a few mock-only
/// entries that exercise dependencies, conflicts and the retired and removed
/// states. Placeholder data throughout.
library;

import 'dart:convert';
import 'dart:io';

import 'generated.dart';

/// The directory of the real-format catalog fixture (`catalog.json` plus
/// `terms/`): `$HINTEROS_MOCK_CATALOG`, else `test/fixtures/catalog` found
/// from the working directory upwards.
String? mockCatalogDir() {
  final env = Platform.environment['HINTEROS_MOCK_CATALOG'];
  if (env != null && env.isNotEmpty) return env;
  var d = Directory.current;
  for (var i = 0; i < 6; i++) {
    final c = '${d.path}/test/fixtures/catalog';
    if (File('$c/catalog.json').existsSync()) return c;
    if (d.parent.path == d.path) break;
    d = d.parent;
  }
  return null;
}

/// One entry of the wire catalog with sensible defaults; [state] is what the
/// relay recomputes on every `store.list`.
StoreApp mockStoreApp({
  required String id,
  required String name,
  String summary = '',
  String description = '',
  String category = 'utilities',
  int sizeMib = 10,
  List<String> depends = const [],
  List<String> conflicts = const [],
  List<String> dataPaths = const [],
  StoreAppTerms? terms,
  bool free = true,
  CatalogStatus status = CatalogStatus.available,
  String? statusReason,
  AppKind kind = AppKind.native,
  StoreAppIcon icon = const StoreAppIcon(firefoxProfile: false),
  List<AppPermission> permissions = const [],
  bool fullAccess = false,
  bool hasData = false,
}) => StoreApp(
  id: id,
  name: name,
  summary: summary,
  description: description,
  category: category,
  homepage: 'https://example.invalid/$id',
  kind: kind,
  sizeMib: sizeMib,
  icon: icon,
  requires: const [],
  depends: depends,
  conflicts: conflicts,
  installer: false,
  onIso: false,
  installerDefault: false,
  dataPaths: dataPaths,
  terms: terms,
  buildsOnDevice: false,
  free: free,
  redistributable: true,
  status: status,
  statusReason: statusReason,
  state: StoreState.available,
  permissions: permissions,
  fullAccess: fullAccess,
  hasData: hasData,
);

/// The fixture index (camelCase) as wire apps (snake_case), the
/// terms file paths made absolute like the daemon's. Empty without the
/// fixture.
List<StoreApp> _fixtureApps(String? dir) {
  if (dir == null) return const [];
  final root = Directory(dir).absolute.path;
  final index = jsonDecode(
    File('$root/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final a in (index['apps'] as List).cast<Map<String, dynamic>>())
      // Services (index 3 `kind: service`) are not Store apps, as in the daemon.
      if (a['kind'] != 'service')
        StoreApp(
          id: a['id'] as String,
          name: a['name'] as String,
          summary: a['summary'] as String? ?? '',
          description: a['description'] as String? ?? '',
          category: a['category'] as String? ?? 'other',
          homepage: a['homepage'] as String? ?? '',
          kind: (a['type'] ?? a['kind']) == 'web'
              ? AppKind.web
              : AppKind.native,
          sizeMib: (a['sizeMiB'] as num?)?.toInt() ?? 0,
          icon: () {
            final i = (a['icon'] as Map?)?.cast<String, dynamic>() ?? {};
            return StoreAppIcon(
              desktopId: i['desktopId'] as String?,
              siteUrl: i['siteUrl'] as String?,
              iconUrl: i['iconUrl'] as String?,
              firefoxProfile: i['firefoxProfile'] == true,
              path: i['path'] as String?,
            );
          }(),
          requires: [...(a['requires'] as List? ?? []).cast<String>()],
          depends: [...(a['depends'] as List? ?? []).cast<String>()],
          conflicts: [...(a['conflicts'] as List? ?? []).cast<String>()],
          installer: a['starter'] != null || a['installer'] == true,
          onIso: a['onIso'] == true,
          installerDefault:
              a['starter'] == 'ticked' || a['installerDefault'] == true,
          dataPaths: [...(a['dataPaths'] as List? ?? []).cast<String>()],
          terms: a['terms'] is Map
              ? () {
                  final t = (a['terms'] as Map).cast<String, dynamic>();
                  return StoreAppTerms(
                    title: t['title'] as String,
                    version: t['version'] as String,
                    url: t['url'] as String,
                    retrieved: t['retrieved'] as String,
                    file: '$root/${t['file']}',
                  );
                }()
              : null,
          readme: a['readme'] is Map
              ? () {
                  final r = (a['readme'] as Map).cast<String, dynamic>();
                  return StoreAppReadme(
                    url: r['url'] as String,
                    retrieved: r['retrieved'] as String,
                    file: '$root/${r['file']}',
                  );
                }()
              : null,
          buildsOnDevice: a['buildsOnDevice'] == true,
          free: a['free'] == true,
          redistributable: a['redistributable'] == true,
          status: CatalogStatus.fromJson(a['status'] as String? ?? 'available'),
          statusReason: a['statusReason'] as String?,
          state: StoreState.available,
          // Index 3 (optional): name -> "required" / "optional".
          permissions: [
            for (final e in ((a['permissions'] as Map?) ?? const {}).entries)
              AppPermission(
                name: e.key as String,
                required: e.value == 'required',
                granted: true,
              ),
          ],
          fullAccess: a['sandbox'] == false,
          hasData: false,
        ),
  ];
}

/// The mock daemon's catalog: the fixture, RetroArch with the cores it
/// depends on, a video player (with permissions), Kodi (conflicts with Jellyfin) and a retired
/// app.
List<StoreApp> mockStoreCatalog({String? dir}) => [
  ..._fixtureApps(dir ?? mockCatalogDir()),
  mockStoreApp(
    id: 'retroarch',
    name: 'RetroArch',
    summary: 'Classic consoles in one frontend.',
    description:
        'Runs old console games. Needs the emulator cores, which are '
        'installed with it.',
    category: 'games',
    sizeMib: 220,
    depends: const ['retroarch-cores'],
    dataPaths: const ['.config/retroarch'],
    icon: const StoreAppIcon(desktopId: 'retroarch', firefoxProfile: false),
  ),
  mockStoreApp(
    id: 'retroarch-cores',
    name: 'Emulator cores',
    summary: 'The emulators RetroArch loads.',
    sizeMib: 400,
  ),
  mockStoreApp(
    id: 'mpv',
    name: 'Video player',
    summary: 'Plays files from USB drives and shares.',
    category: 'video',
    sizeMib: 60,
    permissions: const [
      AppPermission(name: 'gamepad', required: true, granted: true),
      AppPermission(name: 'mic', required: false, granted: true),
      AppPermission(name: 'downloads', required: false, granted: true),
    ],
  ),
  mockStoreApp(
    id: 'kodi',
    name: 'Kodi',
    summary: 'A media centre.',
    category: 'video',
    sizeMib: 200,
    conflicts: const ['jellyfin'],
  ),
  mockStoreApp(
    id: 'old-player',
    name: 'Old player',
    summary: 'A media player that is no longer updated.',
    category: 'video',
    sizeMib: 80,
    status: CatalogStatus.retired,
    statusReason: 'Replaced by the Video player.',
  ),
];
