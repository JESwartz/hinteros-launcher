/// The Server section's in-process fake (`--mock`, widget tests): the four
/// services of the catalog with the service's rules (the admin PIN,
/// `unavailable` while off or not set up, Plex's terms, one job at a time).
/// Placeholder data throughout: no real addresses, accounts or tokens.
library;

import 'dart:async';

import '../api/mock_server_relay.dart' show MockServerRelay, mockMediaTree;
import '../platform/local_files.dart';
import 'mock_profiles.dart';
import 'models.dart';
import 'server.dart';
import 'mock_system.dart' show MockJobs;

/// The placeholder terms text of the mock's Plex.
const _plexTerms = VendorTerms(
  title: 'Plex Terms of Service',
  version: '2025-10-30',
  url: 'https://www.plex.tv/about/privacy-legal/plex-terms-of-service/',
  retrieved: '2026-10-06',
  file: '/run/current-system/sw/share/hinteros/terms/plex-media-server.txt',
  text:
      'PLACEHOLDER TERMS FOR TESTS.\n\n'
      'This text stands in for the vendor terms of Plex Media Server. '
      'The real text is copied into the catalog with the date it was '
      'retrieved and shown here in full before the server is turned on.\n\n'
      'Read to the end to accept.',
);

/// One service of the mock box and what it keeps while off.
class MockService {
  MockService(this.id, this.name, this.setup, {this.terms});

  final String id;
  final String name;
  final ServiceSetup setup;
  final VendorTerms? terms;
  bool enabled = false;
  UnitStatus status = UnitStatus.active;

  /// The catalog entry has `stateDirs`: Turn off can delete them.
  bool hasData = true;

  // Jellyfin.
  bool setupDone = true;
  List<JellyfinLibrary> libraries = [];

  // Plex.
  bool claimed = false;

  // Tailscale.
  TailscaleState tailscale = TailscaleState.needsLogin;

  // Cloudflare.
  bool tokenSet = false;
  bool connected = false;
}

class MockServer implements ServerRepository {
  MockServer(this._jobs, {required this.box, this.iconDir}) {
    jellyfin
      ..enabled = true
      ..libraries = [
        const JellyfinLibrary(
          id: 'f137a2dd21bbc1b99aa5c0f6bf02a805',
          name: 'Movies',
          kind: LibraryKind.movies,
          folder: 'Movies',
        ),
        const JellyfinLibrary(
          id: 'a2c4e6f8a0b2c4d6e8f0a2b4c6d8e0f2',
          name: 'Shows',
          kind: LibraryKind.shows,
          folder: 'TV/Series',
        ),
      ];
    plex.enabled = true;
  }

  final MockJobs _jobs;

  /// The profiles: the admin PIN, and the profiles' Jellyfin users.
  final MockProfileBox box;

  /// The generic icon fixtures (`test/fixtures/icons`); null: letter tiles.
  final String? iconDir;

  final jellyfin = MockService(
    'jellyfin-server',
    'Jellyfin server',
    ServiceSetup.jellyfinServer,
  );
  final plex = MockService(
    'plex-media-server',
    'Plex Media Server',
    ServiceSetup.plexMediaServer,
    terms: _plexTerms,
  );
  final tailscale = MockService(
    'tailscale',
    'Tailscale',
    ServiceSetup.tailscale,
  );
  final cloudflare = MockService(
    'cloudflare-tunnel',
    'Cloudflare Tunnel',
    ServiceSetup.cloudflareTunnel,
  );

  /// The box's address on the local network.
  String localIp = '192.168.1.42';

  /// The address a Tailscale sign-in waits at.
  String authUrl = 'https://login.tailscale.com/a/1a2b3c4d5e6f';

  /// The folders under `/srv/media`.
  Map<String, List<String>> media = mockMediaTree;

  /// Every request that reached the service, in order (no PINs, codes or
  /// tokens).
  final List<String> log = [];

  /// The terms versions accepted, per service id.
  final Map<String, String> accepted = {};

  /// The next request fails with this.
  SystemException? failNext;

  int _revision = 0x6b2c1e0b;
  final _changes = StreamController<void>.broadcast(sync: true);

  List<MockService> get services => [cloudflare, jellyfin, plex, tailscale];

  @override
  Stream<void> get changes => _changes.stream;

  void _changed() {
    _revision += 7919;
    _changes.add(null);
  }

  String get revision => _revision.toRadixString(16).padLeft(8, '0');

  ServiceDetail? _detail(MockService s) => switch (s.setup) {
    ServiceSetup.jellyfinServer => JellyfinDetail(
      setupDone: s.setupDone,
      url: 'http://$localIp:8096',
      libraries: List.of(s.libraries),
      users: {
        for (final p in box.profiles)
          if (s.setupDone) p.id: p.name,
      },
    ),
    ServiceSetup.plexMediaServer => PlexDetail(
      claimed: s.claimed,
      serverName: 'hinteros',
      url: 'http://$localIp:32400',
    ),
    ServiceSetup.tailscale => TailscaleDetail(
      state: s.tailscale,
      name: s.tailscale == TailscaleState.running ? 'hinteros' : null,
      ip4: s.tailscale == TailscaleState.running ? '100.101.102.103' : null,
      dnsName: s.tailscale == TailscaleState.running
          ? 'hinteros.tail1234.ts.net'
          : null,
      tailnet: s.tailscale == TailscaleState.running
          ? 'owner@example.com'
          : null,
      keyExpiry: s.tailscale == TailscaleState.running
          ? DateTime.utc(2027, 4, 18)
          : null,
    ),
    ServiceSetup.cloudflareTunnel => CloudflareDetail(
      tokenSet: s.tokenSet,
      connected: s.connected,
      localIp: localIp,
    ),
    ServiceSetup.none => null,
  };

  ServerService _service(MockService s) => ServerService(
    id: s.id,
    name: s.name,
    enabled: s.enabled,
    status: s.enabled ? s.status : null,
    setup: s.setup,
    terms: s.terms,
    detail: s.enabled ? _detail(s) : null,
    iconPath: _icon(s.id),
    hasData: s.hasData,
  );

  @override
  Future<ServerList> list() async {
    _fail();
    return ServerList(
      revision: revision,
      services: [for (final s in services) _service(s)],
    );
  }

  void _fail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<List<MediaFolder>> folders([String? folderId]) async {
    _fail();
    final names = media[folderId ?? ''];
    if (names == null) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'That folder is not there.',
      );
    }
    return [
      for (final n in names)
        MediaFolder(
          id: folderId == null ? n : '$folderId/$n',
          name: n,
          hasChildren:
              media[folderId == null ? n : '$folderId/$n']?.isNotEmpty ?? false,
        ),
    ];
  }

  /// The generic placeholder icons, by service id (no logos).
  String? _icon(String id) {
    final d = iconDir;
    if (d == null) return null;
    final name = switch (id) {
      'jellyfin-server' => 'jellyfin-desktop',
      'plex-media-server' => 'plex',
      _ => id,
    };
    for (final ext in ['png', 'svg']) {
      final p = '$d/$name.$ext';
      if (localFileExists(p)) return p;
    }
    return null;
  }

  MockService _byId(String id) => services.firstWhere(
    (s) => s.id == id,
    orElse: () => throw const SystemException(
      SystemErrorKind.notFound,
      'That is not there any more.',
    ),
  );

  /// The checks of every change: the admin PIN, then [failNext].
  void _check(String what, String? pin) {
    log.add(what);
    box.checkBoxAdmin(pin);
    _fail();
  }

  /// [s] must be on (and, with [ready], set up).
  void _needOn(MockService s, String service, {bool ready = false}) {
    if (!s.enabled) {
      throw SystemException(
        SystemErrorKind.unavailable,
        '${s.name} is off.',
        data: {'service': service, 'reason': 'off'},
      );
    }
    if (ready && !s.setupDone) {
      throw SystemException(
        SystemErrorKind.unavailable,
        '${s.name} is not ready. Try again in a moment.',
        data: {'service': service, 'reason': 'not_ready'},
      );
    }
  }

  static const _nothing = SystemErrorKind.nothingToDo;

  @override
  Future<JobHandle> enable(
    String id, {
    String? pin,
    Map<String, String> acceptedTerms = const {},
  }) async {
    _check('services.enable:$id', pin);
    final s = _byId(id);
    if (s.enabled) throw const SystemException(_nothing, 'It is on already.');
    final t = s.terms;
    if (t != null && acceptedTerms[id] != t.version) {
      throw SystemException(
        SystemErrorKind.termsRequired,
        'Accept the terms of ${s.name} first.',
        data: {'id': id, 'version': t.version},
      );
    }
    if (t != null) accepted[id] = t.version;
    return _jobs.start(
      JobKind.servicesEnable,
      subject: JobSubject(services: [(id: id, name: s.name)]),
      onSuccess: () {
        s
          ..enabled = true
          ..status = UnitStatus.active;
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> disable(
    String id, {
    String? pin,
    bool deleteData = false,
  }) async {
    _check('services.disable:$id:data=$deleteData', pin);
    final s = _byId(id);
    if (!s.enabled) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'That is not there any more.',
      );
    }
    return _jobs.start(
      JobKind.servicesDisable,
      subject: JobSubject(
        services: [(id: id, name: s.name)],
        deleteData: deleteData,
      ),
      onSuccess: () {
        s.enabled = false;
        if (deleteData) {
          s
            ..libraries = []
            ..claimed = false
            ..tailscale = TailscaleState.needsLogin
            ..tokenSet = false
            ..connected = false;
        }
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> addLibrary({
    required String name,
    required LibraryKind kind,
    required String folder,
    String? pin,
  }) async {
    _check('jellyfin.libraries.add:$name:${kind.name}:$folder', pin);
    final s = jellyfin;
    _needOn(s, 'jellyfin', ready: true);
    final n = name.trim();
    if (n.isEmpty || n.length > 64) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'Type a name of 1 to 64 characters.',
        data: {'field': 'name', 'reason': 'bad_length'},
      );
    }
    if (RegExp(r'[/\\:*?"<>|\x00-\x1f]').hasMatch(n)) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'The name has a character that is not allowed.',
        data: {'field': 'name', 'reason': 'bad_name'},
      );
    }
    if (s.libraries.any((l) => l.name.toLowerCase() == n.toLowerCase())) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'A library has this name.',
        data: {'field': 'name', 'reason': 'exists'},
      );
    }
    if (!media.containsKey(folder)) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'That folder is not there.',
      );
    }
    return _jobs.start(
      JobKind.libraryAdd,
      subject: JobSubject(library: n),
      onSuccess: () {
        s.libraries = [
          ...s.libraries,
          JellyfinLibrary(
            id: (0xc0ffee + s.libraries.length * 7919)
                .toRadixString(16)
                .padLeft(32, '0'),
            name: n,
            kind: kind,
            folder: folder,
          ),
        ];
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> removeLibrary(String libraryId, {String? pin}) async {
    _check('jellyfin.libraries.remove:$libraryId', pin);
    final s = jellyfin;
    _needOn(s, 'jellyfin', ready: true);
    final l = s.libraries.where((l) => l.id == libraryId).firstOrNull;
    if (l == null) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'That is not there any more.',
      );
    }
    return _jobs.start(
      JobKind.libraryRemove,
      subject: JobSubject(library: l.name),
      onSuccess: () {
        s.libraries = [
          for (final x in s.libraries)
            if (x.id != libraryId) x,
        ];
        _changed();
      },
    );
  }

  @override
  Future<JellyfinAccounts> revealAccounts({String? pin}) async {
    _check('jellyfin.users.reveal', pin);
    _needOn(jellyfin, 'jellyfin');
    return JellyfinAccounts(
      admin: jellyfin.setupDone
          ? const JellyfinAccount(name: 'admin', password: 'k3v9q2m7x4p8w6t5')
          : null,
      users: [
        for (final (i, p) in box.profiles.indexed)
          JellyfinAccount(
            name: p.name,
            password: _password(i),
            profileName: p.name,
          ),
      ],
    );
  }

  static String _password(int i) =>
      ['h7d2n9r4c6w3m8q5', 't5z8j3k6v2b9x4p7', 'm4q8w2r6t9y3u7i5'][i % 3];

  @override
  Future<JobHandle> claimPlex(String code, {String? pin}) async {
    _check('plex.claim', pin);
    final s = plex;
    _needOn(s, 'plex');
    if (!plexClaimCode.hasMatch(code)) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'The code is not correct.',
        data: {'field': 'code', 'reason': 'pattern'},
      );
    }
    if (s.claimed) {
      throw const SystemException(_nothing, 'Plex is linked already.');
    }
    return _jobs.start(
      JobKind.plexClaim,
      onSuccess: () {
        s.claimed = true;
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> tailscaleLogin({String? pin}) async {
    _check('tailscale.login', pin);
    final s = tailscale;
    _needOn(s, 'tailscale');
    if (s.tailscale == TailscaleState.running) {
      throw const SystemException(_nothing, 'Tailscale is signed in already.');
    }
    return _jobs.start(
      JobKind.tailscaleLogin,
      authUrl: authUrl,
      onSuccess: () {
        s.tailscale = TailscaleState.running;
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> tailscaleLogout({String? pin}) async {
    _check('tailscale.logout', pin);
    final s = tailscale;
    _needOn(s, 'tailscale');
    if (s.tailscale == TailscaleState.needsLogin) {
      throw const SystemException(_nothing, 'Tailscale is signed out already.');
    }
    return _jobs.start(
      JobKind.tailscaleLogout,
      onSuccess: () {
        s.tailscale = TailscaleState.needsLogin;
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> setCloudflareToken(String token, {String? pin}) async {
    _check('cloudflare.set_token', pin);
    final s = cloudflare;
    _needOn(s, 'cloudflare');
    if (MockServerRelay.tokenProblem(token) != null) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'This is not a tunnel token.',
        data: {'field': 'token', 'reason': 'not_a_token'},
      );
    }
    return _jobs.start(
      JobKind.cloudflareSetToken,
      onSuccess: () {
        s
          ..tokenSet = true
          ..connected = true;
        _changed();
      },
    );
  }

  @override
  Future<JobHandle> clearCloudflareToken({String? pin}) async {
    _check('cloudflare.clear_token', pin);
    final s = cloudflare;
    _needOn(s, 'cloudflare');
    if (!s.tokenSet) {
      throw const SystemException(_nothing, 'There is no token.');
    }
    return _jobs.start(
      JobKind.cloudflareClearToken,
      onSuccess: () {
        s
          ..tokenSet = false
          ..connected = false;
        _changed();
      },
    );
  }
}
