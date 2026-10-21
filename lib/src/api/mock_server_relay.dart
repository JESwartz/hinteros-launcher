/// The Server section of [MockSystemRelay] (session API 0.19, system API
/// 0.11): `services.list`, `media.folders`, the service jobs and
/// `jellyfin.users.reveal` / `client_token`, with the service's rules (the
/// admin PIN, the state.json revision, Plex's terms, `unavailable {service,
/// reason: off | not_ready}`). Placeholder data throughout.
library;

import 'dart:convert';

import 'errors.dart';
import 'generated.dart';
import 'mock_system_relay.dart';

/// The folders under the mock's `/srv/media`: a path to its subfolders.
const mockMediaTree = <String, List<String>>{
  '': ['Movies', 'Music', 'Photos', 'TV'],
  'Movies': ['Films', 'Kids'],
  'Movies/Films': [],
  'Movies/Kids': [],
  'Music': [],
  'Photos': ['2025', '2026'],
  'Photos/2025': [],
  'Photos/2026': [],
  'TV': ['Cartoons', 'Series'],
  'TV/Cartoons': [],
  'TV/Series': [],
};

/// One service of the mock box, with what it keeps while off.
class MockWireService {
  MockWireService(
    this.id,
    this.name,
    this.setup, {
    this.terms,
    this.icon = const ServiceIcon(firefoxProfile: false),
  });

  final String id;
  final String name;
  final Setup setup;
  final ServiceTerms? terms;

  /// The catalog's icon; `path` as the session daemon adds it once resolved.
  ServiceIcon icon;

  /// The catalog entry has `stateDirs`.
  bool hasData = true;
  bool enabled = false;
  UnitState status = UnitState.active;

  /// Jellyfin.
  bool setupDone = true;
  List<JellyfinLibrary> libraries = [];

  /// Plex.
  bool claimed = false;

  /// Tailscale.
  TailscaleState tailscale = TailscaleState.needsLogin;

  /// Cloudflare.
  bool tokenSet = false;
  bool connected = false;
}

class MockServerRelay {
  MockServerRelay(this._relay) {
    jellyfin
      ..enabled = true
      ..libraries = const [
        JellyfinLibrary(
          id: 'f137a2dd21bbc1b99aa5c0f6bf02a805',
          name: 'Movies',
          kind: LibraryKindShown.movies,
          folder: 'Movies',
        ),
        JellyfinLibrary(
          id: 'a2c4e6f8a0b2c4d6e8f0a2b4c6d8e0f2',
          name: 'Books',
          kind: LibraryKindShown.other,
          folder: null,
        ),
      ];
  }

  final MockSystemRelay _relay;

  final jellyfin = MockWireService(
    'jellyfin-server',
    'Jellyfin server',
    Setup.jellyfin,
    icon: const ServiceIcon(
      iconUrl: 'https://raw.githubusercontent.com/jellyfin/jellyfin-ux/master/branding/SVG/icon-transparent.svg',
      sha256:
          '817c25b47442b192250448fe48cd5f265fe9183bc75aa12030bbe335495255d1',
      siteUrl: 'https://jellyfin.org',
      firefoxProfile: false,
      path: '/home/tv/.cache/hinteros/icons/jellyfin-server.svg',
    ),
  );
  final plex = MockWireService(
    'plex-media-server',
    'Plex Media Server',
    Setup.plex,
    terms: const ServiceTerms(
      title: 'Plex Terms of Service',
      version: '2025-10-30',
      url: 'https://www.plex.tv/about/privacy-legal/plex-terms-of-service/',
      file: '/run/current-system/sw/share/hinteros/terms/plex-media-server-2025-10-30.txt',
    ),
    icon: const ServiceIcon(
      iconUrl: 'https://watch.plex.tv/icons/icon-512x512.png',
      sha256:
          '78072fd57aacff1f73dee6432fb8d7f0360f300b4545422fb767cce638c4e7d3',
      siteUrl: 'https://www.plex.tv',
      firefoxProfile: false,
    ),
  );
  final tailscale = MockWireService(
    'tailscale',
    'Tailscale',
    Setup.tailscale,
    icon: const ServiceIcon(
      siteUrl: 'https://tailscale.com',
      firefoxProfile: false,
      path: '/home/tv/.cache/hinteros/icons/tailscale.png',
    ),
  );
  final cloudflare = MockWireService(
    'cloudflare-tunnel',
    'Cloudflare Tunnel',
    Setup.cloudflare,
    icon: const ServiceIcon(
      siteUrl: 'https://www.cloudflare.com/products/tunnel/',
      firefoxProfile: false,
    ),
  );

  List<MockWireService> get services => [cloudflare, jellyfin, plex, tailscale];

  String localIp = '192.168.1.42';

  /// Where a Tailscale sign-in waits (`job_progress.detail.auth_url`).
  String authUrl = 'https://login.tailscale.com/a/1a2b3c4d5e6f';

  /// The folders under `/srv/media`.
  Map<String, List<String>> media = mockMediaTree;

  /// The terms versions accepted (`<id>=<version>`).
  final List<String> acceptances = [];

  static bool handles(String method) => const {
    'system.services.list',
    'system.services.enable',
    'system.services.disable',
    'system.media.folders',
    'system.jellyfin.libraries.add',
    'system.jellyfin.libraries.remove',
    'system.jellyfin.users.reveal',
    'system.jellyfin.client_token',
    'system.plex.claim',
    'system.tailscale.login',
    'system.tailscale.logout',
    'system.cloudflare.set_token',
    'system.cloudflare.clear_token',
  }.contains(method);

  Map<String, dynamic> call(String method, Map<String, dynamic> p) {
    switch (method) {
      case 'system.services.list':
        _relay.closedParams(p, const []);
        return SystemServicesListResult(
          revision: _relay.revision,
          services: [for (final s in services) _info(s)],
        ).toJson();
      case 'system.services.enable':
        _relay.closedParams(p, const [
          'ids',
          'pin',
          'revision',
          'accepted_terms',
        ]);
        return _enable(SystemServicesEnableParams.fromJson(p));
      case 'system.services.disable':
        _relay.closedParams(p, const ['ids', 'pin', 'revision', 'delete_data']);
        return _disable(SystemServicesDisableParams.fromJson(p));
      case 'system.media.folders':
        _relay.closedParams(p, const ['folder_id']);
        final id = SystemMediaFoldersParams.fromJson(p).folderId;
        final names = media[id ?? ''];
        if (names == null) {
          throw const ApiException(ApiErrorCode.notFound, 'no such folder');
        }
        return SystemMediaFoldersResult(
          folderId: id,
          folders: [
            for (final n in names)
              MediaFolder(
                id: id == null ? n : '$id/$n',
                name: n,
                hasChildren:
                    media[id == null ? n : '$id/$n']?.isNotEmpty ?? false,
              ),
          ],
        ).toJson();
      case 'system.jellyfin.libraries.add':
        _relay.closedParams(p, const ['pin', 'name', 'kind', 'folder']);
        return _addLibrary(SystemJellyfinLibrariesAddParams.fromJson(p));
      case 'system.jellyfin.libraries.remove':
        _relay.closedParams(p, const ['pin', 'library_id']);
        final r = SystemJellyfinLibrariesRemoveParams.fromJson(p);
        _relay.mutating('jellyfin.libraries.remove:${r.libraryId}');
        _relay.checkAdminPin?.call(r.pin);
        _ready(jellyfin, 'jellyfin');
        final l = jellyfin.libraries
            .where((l) => l.id == r.libraryId)
            .firstOrNull;
        if (l == null) {
          throw const ApiException(ApiErrorCode.notFound, 'no such library');
        }
        return _job(
          JobKind.jellyfinLibraryRemove,
          subject: JobSubject(
            library: SubjectLibrary(id: l.id, name: l.name),
          ),
          onSuccess: () => jellyfin.libraries = [
            for (final x in jellyfin.libraries)
              if (x.id != l.id) x,
          ],
        );
      case 'system.jellyfin.users.reveal':
        _relay.closedParams(p, const ['pin']);
        final r = SystemJellyfinUsersRevealParams.fromJson(p);
        _relay.mutating('jellyfin.users.reveal');
        _relay.checkAdminPin?.call(r.pin);
        _on(jellyfin, 'jellyfin');
        return SystemJellyfinUsersRevealResult(
          admin: jellyfin.setupDone
              ? const JellyfinAccount(
                  name: 'admin',
                  password: 'k3v9q2m7x4p8w6t5',
                )
              : null,
          users: [
            for (final (i, (id, name)) in _profiles().indexed)
              JellyfinProfileAccount(
                profileId: id,
                profileName: name,
                name: name,
                password: ['h7d2n9r4c6w3m8q5', 't5z8j3k6v2b9x4p7'][i % 2],
              ),
          ],
        ).toJson();
      case 'system.jellyfin.client_token':
        _relay.closedParams(p, const []);
        final owner = _relay.currentOwner?.call() ?? 'p1';
        if (owner == 'guest') {
          throw const ApiException(
            ApiErrorCode.permissionDenied,
            'only a profile can do this',
            {'action': 'org.hinteros.system.services', 'reason': 'profile'},
          );
        }
        _ready(jellyfin, 'jellyfin');
        return SystemJellyfinClientTokenResult(
          serverId: '0f1e2d3c4b5a69788796a5b4c3d2e1f0',
          userId: '6f2c1f0e9d3b4a5c8e7f112233445566',
          deviceId: 'hinteros-$owner',
          accessToken: '4a7b9c2d1e3f5a6b8c0d2e4f6a8b0c1d',
        ).toJson();
      case 'system.plex.claim':
        _relay.closedParams(p, const ['pin', 'code']);
        final r = SystemPlexClaimParams.fromJson(p);
        if (!RegExp(r'^claim-[A-Za-z0-9_-]{20}$').hasMatch(r.code)) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad code', {
            'field': 'code',
            'reason': 'pattern',
          });
        }
        _relay.mutating('plex.claim');
        _relay.checkAdminPin?.call(r.pin);
        _on(plex, 'plex');
        if (plex.claimed) return const JobRef(jobId: null).toJson();
        return _job(JobKind.plexClaim, onSuccess: () => plex.claimed = true);
      case 'system.tailscale.login':
        _relay.closedParams(p, const ['pin']);
        _relay.mutating('tailscale.login');
        _relay.checkAdminPin?.call(SystemTailscaleLoginParams.fromJson(p).pin);
        _on(tailscale, 'tailscale');
        if (tailscale.tailscale == TailscaleState.running) {
          return const JobRef(jobId: null).toJson();
        }
        return JobRef(
          jobId: _relay.startJob(
            JobKind.tailscaleLogin,
            authUrl: authUrl,
            onSuccess: () => tailscale.tailscale = TailscaleState.running,
          ),
        ).toJson();
      case 'system.tailscale.logout':
        _relay.closedParams(p, const ['pin']);
        _relay.mutating('tailscale.logout');
        _relay.checkAdminPin?.call(SystemTailscaleLogoutParams.fromJson(p).pin);
        _on(tailscale, 'tailscale');
        if (tailscale.tailscale == TailscaleState.needsLogin) {
          return const JobRef(jobId: null).toJson();
        }
        return _job(
          JobKind.tailscaleLogout,
          onSuccess: () => tailscale.tailscale = TailscaleState.needsLogin,
        );
      case 'system.cloudflare.set_token':
        _relay.closedParams(p, const ['pin', 'token']);
        final r = SystemCloudflareSetTokenParams.fromJson(p);
        final bad = tokenProblem(r.token);
        if (bad != null) {
          throw ApiException(ApiErrorCode.invalidParams, 'not a tunnel token', {
            'field': 'token',
            'reason': bad,
          });
        }
        _relay.mutating('cloudflare.set_token');
        _relay.checkAdminPin?.call(r.pin);
        _on(cloudflare, 'cloudflare');
        return _job(
          JobKind.cloudflareSetToken,
          onSuccess: () => cloudflare
            ..tokenSet = true
            ..connected = true,
        );
      case 'system.cloudflare.clear_token':
        _relay.closedParams(p, const ['pin']);
        _relay.mutating('cloudflare.clear_token');
        _relay.checkAdminPin?.call(
          SystemCloudflareClearTokenParams.fromJson(p).pin,
        );
        _on(cloudflare, 'cloudflare');
        if (!cloudflare.tokenSet) return const JobRef(jobId: null).toJson();
        return _job(
          JobKind.cloudflareClearToken,
          onSuccess: () => cloudflare
            ..tokenSet = false
            ..connected = false,
        );
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  /// Why [token] is not a remotely managed tunnel's token (cloudflared's
  /// rules: padded base64 of exactly `a`, `t`, `s` and maybe `e`); null
  /// when it is one.
  static String? tokenProblem(String token) {
    if (token.isEmpty || token.length > 512) return 'bad_length';
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(base64.decode(token)));
    } on FormatException {
      return 'not_base64';
    }
    if (j is! Map ||
        !j.keys.toSet().containsAll(const {'a', 't', 's'}) ||
        j.keys.any((k) => !const {'a', 't', 's', 'e'}.contains(k))) {
      return 'not_a_token';
    }
    if (j['a'] is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(j['a'])) {
      return 'bad_account';
    }
    if (j['t'] is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(j['t'])) {
      return 'bad_tunnel_id';
    }
    try {
      final n = base64.decode(j['s'] as String).length;
      if (n < 32 || n > 256) return 'bad_secret';
    } on Object {
      return 'bad_secret';
    }
    return null;
  }

  List<(String, String)> _profiles() =>
      _relay.profileList?.call() ?? const [('p1', 'Alex'), ('p2', 'Sam')];

  /// The session daemon resolved a service's icon: `icon.path` appears and
  /// `store_changed` is sent.
  void setServiceIcon(MockWireService s, String? path) {
    final j = s.icon.toJson();
    path == null ? j.remove('path') : j['path'] = path;
    s.icon = ServiceIcon.fromJson(j);
    _relay.emit('store_changed', const {});
  }

  ServiceInfo _info(MockWireService s) => ServiceInfo(
    id: s.id,
    name: s.name,
    available: true,
    enabled: s.enabled,
    status: s.enabled ? s.status : null,
    setup: s.setup,
    terms: s.enabled ? null : s.terms,
    detail: s.enabled ? _detail(s) : null,
    icon: s.icon,
    hasData: s.hasData,
  );

  Map<String, dynamic> _detail(MockWireService s) {
    final running = s.tailscale == TailscaleState.running;
    return switch (s.setup) {
      Setup.jellyfin => JellyfinDetail(
        setupDone: s.setupDone,
        url: 'http://$localIp:8096',
        libraries: List.of(s.libraries),
        users: [
          if (s.setupDone)
            for (final (id, name) in _profiles())
              JellyfinDetailUsersItem(profileId: id, jellyfinUser: name),
        ],
      ).toJson(),
      Setup.plex => PlexDetail(
        claimed: s.claimed,
        serverName: 'hinteros',
        url: 'http://$localIp:32400',
      ).toJson(),
      Setup.tailscale => TailscaleDetail(
        state: s.tailscale,
        name: running ? 'hinteros' : null,
        ip4: running ? '100.101.102.103' : null,
        dnsName: running ? 'hinteros.tail1234.ts.net' : null,
        tailnet: running ? 'owner@example.com' : null,
        keyExpiry: running ? 1808042400 : null,
      ).toJson(),
      _ => CloudflareDetail(
        tokenSet: s.tokenSet,
        connected: s.connected,
        localIp: localIp,
      ).toJson(),
    };
  }

  MockWireService? _service(String id) =>
      services.where((s) => s.id == id).firstOrNull;

  void _on(MockWireService s, String service) {
    if (!s.enabled) {
      throw ApiException(ApiErrorCode.unavailable, 'the service is off', {
        'service': service,
        'reason': 'off',
      });
    }
  }

  void _ready(MockWireService s, String service) {
    _on(s, service);
    if (!s.setupDone) {
      throw ApiException(ApiErrorCode.unavailable, 'the service is not ready', {
        'service': service,
        'reason': 'not_ready',
      });
    }
  }

  Map<String, dynamic> _job(
    JobKind kind, {
    void Function()? onSuccess,
    JobSubject subject = const JobSubject(),
  }) => JobRef(
    jobId: _relay.startJob(kind, onSuccess: onSuccess, subject: subject),
  ).toJson();

  /// The ids must be services of the catalog; app ids are refused.
  List<MockWireService> _services(List<String> ids) => [
    for (final id in ids)
      _service(id) ??
          (_relay.catalog.any((a) => a.id == id)
              ? throw ApiException(
                  ApiErrorCode.invalidParams,
                  '$id is not a service',
                  {'field': 'ids', 'reason': 'not_a_service'},
                )
              : throw ApiException(
                  ApiErrorCode.notFound,
                  '$id is not in the catalog',
                )),
  ];

  Map<String, dynamic> _enable(SystemServicesEnableParams p) {
    _relay.mutating('services.enable:${p.ids.join(',')}');
    _relay.checkAdminPin?.call(p.pin);
    final want = [
      for (final s in _services(p.ids))
        if (!s.enabled) s,
    ];
    _relay.staleRevision(p.revision);
    for (final s in want) {
      final t = s.terms;
      if (t != null && p.acceptedTerms?[s.id] != t.version) {
        throw ApiException(
          ApiErrorCode.termsRequired,
          '${s.id} needs its terms accepted (version ${t.version})',
          TermsRequiredData(id: s.id, version: t.version).toJson(),
        );
      }
    }
    if (want.isEmpty) return const JobRef(jobId: null).toJson();
    for (final s in want) {
      if (s.terms case final t?) acceptances.add('${s.id}=${t.version}');
    }
    return _job(
      JobKind.servicesEnable,
      subject: JobSubject(
        services: [for (final s in want) CatalogApp(id: s.id, name: s.name)],
      ),
      onSuccess: () {
        for (final s in want) {
          s
            ..enabled = true
            ..status = UnitState.active;
        }
        _relay.bumpRevision();
      },
    );
  }

  Map<String, dynamic> _disable(SystemServicesDisableParams p) {
    _relay.mutating('services.disable:${p.ids.join(',')}:data=${p.deleteData}');
    _relay.checkAdminPin?.call(p.pin);
    final off = _services(p.ids);
    _relay.staleRevision(p.revision);
    for (final s in off) {
      if (!s.enabled) {
        throw ApiException(ApiErrorCode.notFound, '${s.id} is not on');
      }
    }
    return _job(
      JobKind.servicesDisable,
      subject: JobSubject(
        services: [for (final s in off) CatalogApp(id: s.id, name: s.name)],
        deleteData: p.deleteData,
      ),
      onSuccess: () {
        for (final s in off) {
          s.enabled = false;
          if (p.deleteData) {
            s
              ..libraries = []
              ..claimed = false
              ..tailscale = TailscaleState.needsLogin
              ..tokenSet = false
              ..connected = false;
          }
        }
        _relay.bumpRevision();
      },
    );
  }

  Map<String, dynamic> _addLibrary(SystemJellyfinLibrariesAddParams p) {
    final name = p.name.trim();
    if (name.isEmpty || name.length > 64) {
      throw const ApiException(ApiErrorCode.invalidParams, 'bad name', {
        'field': 'name',
        'reason': 'bad_length',
      });
    }
    if (RegExp(r'[/\\:*?"<>|\x00-\x1f\x7f]').hasMatch(name)) {
      throw const ApiException(ApiErrorCode.invalidParams, 'bad name', {
        'field': 'name',
        'reason': 'bad_name',
      });
    }
    _relay.mutating('jellyfin.libraries.add:$name:${p.kind.value}:${p.folder}');
    _relay.checkAdminPin?.call(p.pin);
    _ready(jellyfin, 'jellyfin');
    if (jellyfin.libraries.any(
      (l) => l.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        'a library has this name',
        {'field': 'name', 'reason': 'exists'},
      );
    }
    if (!media.containsKey(p.folder)) {
      throw const ApiException(ApiErrorCode.notFound, 'no such folder');
    }
    final id = (0xc0ffee + jellyfin.libraries.length * 7919)
        .toRadixString(16)
        .padLeft(32, '0');
    return _job(
      JobKind.jellyfinLibraryAdd,
      subject: JobSubject(
        library: SubjectLibrary(name: name, kind: p.kind, folder: p.folder),
      ),
      onSuccess: () => jellyfin.libraries = [
        ...jellyfin.libraries,
        JellyfinLibrary(
          id: id,
          name: name,
          kind: switch (p.kind) {
            LibraryKind.movies => LibraryKindShown.movies,
            LibraryKind.shows => LibraryKindShown.shows,
            LibraryKind.music => LibraryKindShown.music,
            _ => LibraryKindShown.mixed,
          },
          folder: p.folder,
        ),
      ],
    );
  }
}
