/// [ServerRepository] over the session daemon's relayed Server section
/// (session API 0.19, system API 0.11): `system.services.list`,
/// `system.media.folders`, the service jobs and `jellyfin.users.reveal`.
library;

import 'dart:async';

import '../api/api.dart' as api;
import 'catalog.dart' show readBoxTerms;
import 'daemon_errors.dart';
import 'daemon_system.dart' show DaemonJobs;
import 'daemon_util.dart';
import 'models.dart';
import 'server.dart';

/// Reads a terms text from its absolute path on the box; null when it is
/// missing or unreadable.
typedef ServiceTermsReader = String? Function(String path);

UnitStatus? _unit(api.UnitState? s) => switch (s) {
  null => null,
  api.UnitState.active => UnitStatus.active,
  api.UnitState.reloading => UnitStatus.reloading,
  api.UnitState.inactive => UnitStatus.inactive,
  api.UnitState.failed => UnitStatus.failed,
  api.UnitState.activating => UnitStatus.activating,
  api.UnitState.deactivating => UnitStatus.deactivating,
  api.UnitState.maintenance => UnitStatus.maintenance,
  api.UnitState.refreshing => UnitStatus.refreshing,
  api.UnitState.unknown => UnitStatus.unknown,
};

ServiceSetup _setup(api.Setup? s) => switch (s) {
  api.Setup.jellyfinServer => ServiceSetup.jellyfinServer,
  api.Setup.plexMediaServer => ServiceSetup.plexMediaServer,
  api.Setup.tailscale => ServiceSetup.tailscale,
  api.Setup.cloudflareTunnel => ServiceSetup.cloudflareTunnel,
  // A flow this launcher does not know: only on and off.
  api.Setup.unknown || null => ServiceSetup.none,
};

LibraryKind _kind(api.LibraryKindShown k) => switch (k) {
  api.LibraryKindShown.movies => LibraryKind.movies,
  api.LibraryKindShown.shows => LibraryKind.shows,
  api.LibraryKindShown.music => LibraryKind.music,
  api.LibraryKindShown.mixed => LibraryKind.mixed,
  api.LibraryKindShown.other => LibraryKind.other,
};

api.LibraryKind _wireKind(LibraryKind k) => switch (k) {
  LibraryKind.movies => api.LibraryKind.movies,
  LibraryKind.shows => api.LibraryKind.shows,
  LibraryKind.music => api.LibraryKind.music,
  LibraryKind.mixed || LibraryKind.other => api.LibraryKind.mixed,
};

TailscaleState _tailscale(api.TailscaleState s) => switch (s) {
  api.TailscaleState.needsLogin => TailscaleState.needsLogin,
  api.TailscaleState.needsApproval => TailscaleState.needsApproval,
  api.TailscaleState.starting => TailscaleState.starting,
  api.TailscaleState.running => TailscaleState.running,
  api.TailscaleState.stopped => TailscaleState.stopped,
  api.TailscaleState.unavailable ||
  api.TailscaleState.unknown => TailscaleState.unavailable,
};

/// `detail` by the setup it belongs to (the schema's `oneOf` is not typed).
ServiceDetail? _detail(ServiceSetup setup, Object? d) {
  if (d is! Map) return null;
  final j = d.cast<String, dynamic>();
  try {
    switch (setup) {
      case ServiceSetup.jellyfinServer:
        final w = api.JellyfinDetail.fromJson(j);
        return JellyfinDetail(
          setupDone: w.setupDone,
          url: oneLine(w.url, 256),
          libraries: [
            for (final l in w.libraries)
              JellyfinLibrary(
                id: l.id,
                name: oneLine(l.name) ?? l.id,
                kind: _kind(l.kind),
                folder: l.folder,
              ),
          ],
          users: {
            for (final u in w.users)
              u.profileId: oneLine(u.jellyfinUser) ?? u.profileId,
          },
        );
      case ServiceSetup.plexMediaServer:
        final w = api.PlexDetail.fromJson(j);
        return PlexDetail(
          claimed: w.claimed,
          serverName: oneLine(w.serverName),
          url: oneLine(w.url, 256),
        );
      case ServiceSetup.tailscale:
        final w = api.TailscaleDetail.fromJson(j);
        return TailscaleDetail(
          state: _tailscale(w.state),
          name: oneLine(w.name),
          ip4: oneLine(w.ip4),
          dnsName: oneLine(w.dnsName, 256),
          tailnet: oneLine(w.tailnet),
          keyExpiry: w.keyExpiry == null ? null : unixTime(w.keyExpiry!),
        );
      case ServiceSetup.cloudflareTunnel:
        final w = api.CloudflareDetail.fromJson(j);
        return CloudflareDetail(
          tokenSet: w.tokenSet,
          connected: w.connected,
          localIp: oneLine(w.localIp),
        );
      case ServiceSetup.none:
        return null;
    }
  } on TypeError {
    // A detail of another shape than its setup says: nothing to show.
    return null;
  }
}

class DaemonServer implements ServerRepository {
  DaemonServer(this._conn, this._jobs, {this.readTerms = readBoxTerms}) {
    _events = _conn.events.listen((e) {
      if (e is api.JobFinishedEvent && _kinds.contains(e.kind)) {
        _changes.add(null);
      } else if (e is api.StoreChangedEvent && _iconsPending) {
        // A catalog icon arrived, maybe a service's (`icon.path`).
        _changes.add(null);
      }
    });
    _status = _conn.statusChanges.listen((s) {
      if (s is api.Connected) _changes.add(null);
    });
    // Job events: [DaemonJobs] subscribes to them.
    unawaited(
      _conn
          .subscribeTo(const [api.EventName.storeChanged])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;
  final ServiceTermsReader readTerms;
  late final StreamSubscription<api.SessionEvent> _events;
  late final StreamSubscription<api.ConnectionStatus> _status;
  final _changes = StreamController<void>.broadcast();

  /// The last list has a service whose icon the session daemon has not
  /// resolved yet: `store_changed` may mean it has now.
  bool _iconsPending = false;

  static const _kinds = {
    api.JobKind.servicesEnable,
    api.JobKind.servicesDisable,
    api.JobKind.jellyfinLibraryAdd,
    api.JobKind.jellyfinLibraryRemove,
    api.JobKind.plexClaim,
    api.JobKind.tailscaleLogin,
    api.JobKind.tailscaleLogout,
    api.JobKind.cloudflareSetToken,
    api.JobKind.cloudflareClearToken,
  };

  @override
  Stream<void> get changes => _changes.stream;

  ServerService _service(api.ServiceInfo s) {
    final setup = _setup(s.setup);
    final t = s.terms;
    final text = t == null ? null : readTerms(t.file);
    return ServerService(
      id: s.id,
      name: oneLine(s.name, 64) ?? s.id,
      available: s.available,
      enabled: s.enabled,
      status: _unit(s.status),
      setup: setup,
      terms: t == null || text == null
          ? null
          : VendorTerms(
              title: t.title,
              version: t.version,
              url: t.url,
              retrieved: '',
              file: t.file,
              text: text,
            ),
      termsMissing: t != null && text == null,
      detail: s.enabled ? _detail(setup, s.detail) : null,
      iconPath: s.icon?.path,
      hasData: s.hasData,
    );
  }

  @override
  Future<ServerList> list() => guardCall(() async {
    final r = await _conn.systemServicesList();
    _iconsPending = r.services.any((s) {
      final i = s.icon;
      return i != null &&
          i.path == null &&
          (i.desktopId != null || i.iconUrl != null || i.siteUrl != null);
    });
    return ServerList(
      revision: r.revision,
      services: [for (final s in r.services) _service(s)],
    );
  });

  @override
  Future<List<MediaFolder>> folders([String? folderId]) => guardCall(() async {
    final r = await _conn.systemMediaFolders(
      api.SystemMediaFoldersParams(folderId: folderId),
    );
    return [
      for (final f in r.folders)
        MediaFolder(
          id: f.id,
          name: oneLine(f.name) ?? f.id,
          hasChildren: f.hasChildren,
        ),
    ];
  });

  /// Starts a job with the admin [pin]; none yet asks for it.
  Future<JobHandle> _start(
    JobKind kind,
    String? pin,
    Future<String?> Function(String pin) call, {
    String nothingToDo = 'Nothing to change.',
  }) async {
    if (pin == null) throw missingAdminPin;
    try {
      return await _jobs.start(kind, () => call(pin), nothingToDo: nothingToDo);
    } on SystemException catch (e) {
      throw serverRefusal(e);
    }
  }

  /// Runs [call] with `services.list`'s revision; a stale one is read again
  /// and the call made once more.
  Future<T> _withRevision<T>(Future<T> Function(String revision) call) async {
    for (var attempt = 0; ; attempt++) {
      final revision = (await _conn.systemServicesList()).revision;
      try {
        return await call(revision);
      } on api.ApiException catch (e) {
        if (e.code == api.ApiErrorCode.stateConflict && attempt == 0) continue;
        rethrow;
      }
    }
  }

  @override
  Future<JobHandle> enable(
    String id, {
    String? pin,
    Map<String, String> acceptedTerms = const {},
  }) => _start(
    JobKind.servicesEnable,
    pin,
    (pin) => _withRevision(
      (revision) async => (await _conn.systemServicesEnable(
        api.SystemServicesEnableParams(
          ids: [id],
          pin: pin,
          revision: revision,
          acceptedTerms: acceptedTerms.isEmpty ? null : {...acceptedTerms},
        ),
      )).jobId,
    ),
    nothingToDo: 'It is on already.',
  );

  @override
  Future<JobHandle> disable(
    String id, {
    String? pin,
    bool deleteData = false,
  }) => _start(
    JobKind.servicesDisable,
    pin,
    (pin) => _withRevision(
      (revision) async => (await _conn.systemServicesDisable(
        api.SystemServicesDisableParams(
          ids: [id],
          pin: pin,
          revision: revision,
          deleteData: deleteData,
        ),
      )).jobId,
    ),
    nothingToDo: 'It is off already.',
  );

  @override
  Future<JobHandle> addLibrary({
    required String name,
    required LibraryKind kind,
    required String folder,
    String? pin,
  }) => _start(
    JobKind.libraryAdd,
    pin,
    (pin) async => (await _conn.systemJellyfinLibrariesAdd(
      api.SystemJellyfinLibrariesAddParams(
        pin: pin,
        name: name,
        kind: _wireKind(kind),
        folder: folder,
      ),
    )).jobId,
  );

  @override
  Future<JobHandle> removeLibrary(String libraryId, {String? pin}) => _start(
    JobKind.libraryRemove,
    pin,
    (pin) async => (await _conn.systemJellyfinLibrariesRemove(
      api.SystemJellyfinLibrariesRemoveParams(pin: pin, libraryId: libraryId),
    )).jobId,
  );

  @override
  Future<JellyfinAccounts> revealAccounts({String? pin}) async {
    if (pin == null) throw missingAdminPin;
    return guardCall(() async {
      final r = await _conn.systemJellyfinUsersReveal(
        api.SystemJellyfinUsersRevealParams(pin: pin),
      );
      final a = r.admin;
      return JellyfinAccounts(
        admin: a == null
            ? null
            : JellyfinAccount(
                name: oneLine(a.name) ?? '',
                password: a.password,
              ),
        users: [
          for (final u in r.users)
            JellyfinAccount(
              name: oneLine(u.name) ?? '',
              password: u.password,
              profileName: oneLine(u.profileName) ?? u.profileId,
            ),
        ],
      );
    });
  }

  @override
  Future<JobHandle> claimPlex(String code, {String? pin}) => _start(
    JobKind.plexClaim,
    pin,
    (pin) async => (await _conn.systemPlexClaim(
      api.SystemPlexClaimParams(pin: pin, code: code),
    )).jobId,
    nothingToDo: 'Plex is linked already.',
  );

  @override
  Future<JobHandle> tailscaleLogin({String? pin}) => _start(
    JobKind.tailscaleLogin,
    pin,
    (pin) async => (await _conn.systemTailscaleLogin(
      api.SystemTailscaleLoginParams(pin: pin),
    )).jobId,
    nothingToDo: 'Tailscale is signed in already.',
  );

  @override
  Future<JobHandle> tailscaleLogout({String? pin}) => _start(
    JobKind.tailscaleLogout,
    pin,
    (pin) async => (await _conn.systemTailscaleLogout(
      api.SystemTailscaleLogoutParams(pin: pin),
    )).jobId,
    nothingToDo: 'Tailscale is signed out already.',
  );

  @override
  Future<JobHandle> setCloudflareToken(String token, {String? pin}) => _start(
    JobKind.cloudflareSetToken,
    pin,
    (pin) async => (await _conn.systemCloudflareSetToken(
      api.SystemCloudflareSetTokenParams(pin: pin, token: token),
    )).jobId,
  );

  @override
  Future<JobHandle> clearCloudflareToken({String? pin}) => _start(
    JobKind.cloudflareClearToken,
    pin,
    (pin) async => (await _conn.systemCloudflareClearToken(
      api.SystemCloudflareClearTokenParams(pin: pin),
    )).jobId,
    nothingToDo: 'There is no token.',
  );

  Future<void> dispose() async {
    await _events.cancel();
    await _status.cancel();
    await _changes.close();
  }
}
