/// The `system.*` side of [MockDaemon]: what the session daemon relays from the
/// privileged system service in session API 0.6, with the service's rules
/// (one mutating job at a time, `needs_acknowledgement` for base downgrades,
/// `state_conflict` for a stale revision or an unverified update or channel
/// rev, `channel.check` before `channel.set` (session API 0.17),
/// `authentication_required` for `ssh.set` to on, a 60 s cache for
/// `update.check`) and fake jobs that step through their stages and send
/// `job_started` / `job_progress` / `job_finished`.
///
/// Tests drive jobs by hand ([progressJob], [finishJob]) or give [stepDelay]
/// so they run by themselves. Placeholder data throughout.
library;

import 'dart:async';

import 'errors.dart';
import 'generated.dart';
import 'mock_server_relay.dart';
import 'mock_store.dart';
import 'mock_time_zones.dart';

/// What a building stage builds when a job runs by itself: (name, version).
const List<(String, String?)> mockBuilds = [
  ('hinteros-daemon', '0.7.1'),
  ('hinteros-launcher', '0.7.1'),
  ('system-units', null),
  ('etc', null),
];

/// Wire stages of each kind of job.
List<Stage> mockStagesOf(JobKind kind) => switch (kind) {
  JobKind.updateCheck || JobKind.channelCheck => const [
    Stage.preparing,
    Stage.fetching,
    Stage.verifying,
  ],
  JobKind.updateApply || JobKind.channel || JobKind.base => const [
    Stage.preparing,
    Stage.fetching,
    Stage.verifying,
    Stage.evaluating,
    Stage.downloading,
    Stage.building,
    Stage.activating,
    Stage.finishing,
  ],
  JobKind.rollback => const [
    Stage.preparing,
    Stage.activating,
    Stage.finishing,
  ],
  JobKind.storageMeasure => const [
    Stage.preparing,
    Stage.measuring,
    Stage.finishing,
  ],
  JobKind.cleanupSystem || JobKind.cleanupProfiles => const [
    Stage.preparing,
    Stage.cleaning,
    Stage.collecting,
    Stage.finishing,
  ],
  JobKind.servicesEnable || JobKind.servicesDisable => const [
    Stage.preparing,
    Stage.evaluating,
    Stage.building,
    Stage.activating,
    Stage.finishing,
  ],
  JobKind.tailscaleLogin => const [
    Stage.preparing,
    Stage.signingIn,
    Stage.finishing,
  ],
  JobKind.jellyfinLibraryAdd ||
  JobKind.jellyfinLibraryRemove ||
  JobKind.plexClaim ||
  JobKind.tailscaleLogout ||
  JobKind.cloudflareSetToken ||
  JobKind.cloudflareClearToken => const [
    Stage.preparing,
    Stage.configuring,
    Stage.finishing,
  ],
  _ => const [
    Stage.preparing,
    Stage.building,
    Stage.activating,
    Stage.finishing,
  ],
};

class _Job {
  _Job(this.id, this.kind, this.createdAt, {this.onSuccess});

  final String id;
  final JobKind kind;
  final int createdAt;
  final void Function()? onSuccess;
  JobState state = JobState.running;
  JobSubject subject = const JobSubject();
  int? percent;
  ProgressDetail? detail;
  int? lastActivityAt;
  Stage stage = Stage.preparing;
  int? finishedAt;
  ErrorObject? error;
  Object? result;
  bool restart = false;
  Timer? timer;

  /// The catalog ids an apps job installs or removes.
  List<String> apps = const [];

  /// A rollback that turns box features back on (`features_readded`).
  List<BoxFeature>? featuresReadded;

  /// A clean-up's result (0.14).
  CleanedResult? cleaned;

  /// A Tailscale sign-in: where it waits (stage signing_in).
  String? authUrl;
}

class MockSystemRelay {
  MockSystemRelay({
    required this.emit,
    DateTime Function()? now,
    this.stepDelay,
    this.authorize,
    List<StoreApp>? catalog,
    this.onAppsInstalled,
    this.onAppsRemoved,
  }) : _now = now ?? DateTime.now,
       catalog = catalog ?? mockStoreCatalog() {
    generations = [
      for (var g = generation!; g > generation! - 3; g--)
        Generation(
          generation: g,
          date: 1790000000 - (generation! - g) * 86400,
          rev: g == generation ? rev : null,
          current: g == generation,
          booted: g == generation! - 1,
        ),
    ];
  }

  /// Sends an event to the launcher (the daemon's `emitRaw`).
  final void Function(String name, Map<String, dynamic> params) emit;
  final DateTime Function() _now;

  /// Asks polkit for the admin password for an interactive action (the
  /// authentication agent): completes when authorized, throws
  /// `authentication_required` or `permission_denied`. Null: no agent.
  final Future<void> Function(String action, String message)? authorize;

  /// Time between stages when a job runs by itself; null: tests step jobs
  /// with [progressJob] and [finishJob].
  Duration? stepDelay;

  // ---- the box

  String version = '0.1.0';
  Channel? channel = Channel.stable;
  Base base = Base.unstable;

  /// The bases that are built: `base.set` to another one is `unavailable`.
  final builtBases = {Base.unstable};
  String? rev = '0f3c5a9e2b7d4c1a8e6f9b0d2c4e6a8b1d3f5a7c';
  int? generation = 42;
  String hostname = 'hinteros';
  bool dev = false;
  bool sshEnabled = false;

  /// An apps job finished: the box's app list changes (the daemon reloads it
  /// and sends `apps_changed`, 0.9).
  final void Function(List<StoreApp> apps)? onAppsInstalled;
  final void Function(List<String> ids)? onAppsRemoved;

  /// Catalog ids installed from the Store (`settings.get`, state.json apps).
  final List<String> installedApps = ['steam'];

  /// `has_data` (0.19): installed apps have data unless it was cleared;
  /// apps removed without their data leave it behind.
  final Set<String> dataCleared = {};
  final Set<String> dataLeft = {};
  bool _hasData(String id) =>
      (installedApps.contains(id) && !dataCleared.contains(id)) ||
      dataLeft.contains(id);

  /// The catalog of the running generation (`store.list`). Entries are wire
  /// apps; the `state` is worked out on every call.
  List<StoreApp> catalog;

  /// No catalog index on this system (`store.list` is `unavailable`).
  bool catalogMissing = false;

  /// This profile's permission opt-outs (0.18): app id -> denied names, as
  /// the session daemon keeps them in `permissions.json`.
  final Map<String, Set<String>> deniedPermissions = {};

  /// App [id]'s permissions with this profile's choices (empty for an app
  /// the catalog does not know).
  List<AppPermission> permissionsOf(String id) {
    final a = catalog.where((a) => a.id == id).firstOrNull;
    final denied = deniedPermissions[id] ?? const {};
    return [
      for (final p in a?.permissions ?? const <AppPermission>[])
        AppPermission(
          name: p.name,
          required: p.required,
          granted: p.required || !denied.contains(p.name),
        ),
    ];
  }

  /// `apps.set_permission` (answered by the session daemon; the catalog is
  /// here). Sends `store_changed`; the caller sends `apps_changed`.
  void setPermission(AppsSetPermissionParams p) {
    final a = catalog.where((a) => a.id == p.id).firstOrNull;
    if (a == null) {
      throw ApiException(ApiErrorCode.appNotFound, "no app with id '${p.id}'");
    }
    final perm = a.permissions.where((x) => x.name == p.permission).firstOrNull;
    if (perm == null) {
      throw ApiException(
        ApiErrorCode.unknownPermission,
        '${p.id} does not use ${p.permission}',
      );
    }
    if (perm.required) {
      if (p.granted) return;
      throw ApiException(
        ApiErrorCode.permissionRequired,
        '${p.id} needs ${p.permission}',
      );
    }
    log.add('apps.set_permission:${p.id}:${p.permission}:${p.granted}');
    final denied = deniedPermissions.putIfAbsent(p.id, () => {});
    p.granted ? denied.remove(p.permission) : denied.add(p.permission);
    if (denied.isEmpty) deniedPermissions.remove(p.id);
    emit('store_changed', const {});
  }

  /// The daemon resolved a catalog icon (0.9): `icon.path` appears and
  /// `store_changed` is sent.
  void setStoreIcon(String id, String? path) {
    final i = catalog.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final j = catalog[i].toJson();
    final icon = {...(j['icon'] as Map<String, dynamic>)};
    path == null ? icon.remove('path') : icon['path'] = path;
    catalog[i] = StoreApp.fromJson({...j, 'icon': icon});
    emit('store_changed', const {});
  }

  /// Free disk space, for `apps.install`.
  int freeDiskMib = 100000;

  /// `<id>=<terms version>` for every acceptance an install recorded.
  final List<String> acceptances = [];
  List<String> hostKeyFingerprints = [
    'SHA256:2CixtE95MNbZHanQGv6hP2D3qfguu9QZfjca2OaupKI',
  ];
  String revision =
      '6b2c1e0b9f4a7d3c5e8f1a2b4c6d8e0f1a3b5c7d9e1f2a4b6c8d0e2f4a6b8c0d';
  late List<Generation> generations;

  // ---- behaviour switches

  /// The system service is down / of another version: every `system.*` call
  /// fails with `system_unavailable`.
  SystemUnavailableDataReason? unavailable;

  /// polkit says yes to `org.hinteros.system.ssh` (an agent got the admin
  /// password). False (the 0.6 reality): `ssh.set` to on is
  /// `authentication_required`.
  bool adminAuthorized = false;

  /// What the next `update.check` job finds.
  AvailableUpdate? nextUpdate;

  /// The next job that finishes well asks for a session restart.
  bool restartNext = false;

  /// The next mutating call fails with this (rate limit, memory, ...).
  ApiException? failNext;

  /// The admin PIN check of the box-wide actions (`update.apply`,
  /// `rollback`, `channel.set`, `base.set`, `hardware.redetect`; system API
  /// 0.5): throws `pin_required` or `invalid_params`. Null: no PIN needed.
  /// [MockDaemon] sets it to its profiles' check.
  void Function(String? adminPin)? checkAdminPin;

  /// Jobs another profile started: `jobs.cancel` without `admin_pin` is
  /// `permission_denied {reason: starter}`.
  final Set<String> startedByOther = {};

  // ---- storage (0.14)

  /// The last measurement (`storage.get`); null until a `storage_measure`
  /// job finished (or a test sets [mockWireMeasurement]).
  Measurement? measurement;

  /// The detailed tree of each home, by profile id or `guest`.
  Map<String, StorageNode> homes = mockWireHomes();

  /// The automatic clean-up (`cleanup.get`).
  CleanupSettings cleanup = const CleanupSettings(
    enabled: true,
    frequency: CleanupFrequency.weekly,
    keepSystem: 5,
    keepProfiles: 5,
  );

  /// Whose session it is (a profile id or `guest`): their own tree needs no
  /// PIN. [MockDaemon] sets it to its profiles' current one.
  String Function()? currentOwner;

  /// A profile's display name (a job's subject); null: the id.
  String? Function(String id)? profileName;

  /// The profiles (id, name): their Jellyfin users (0.19).
  List<(String, String)> Function()? profileList;

  /// The Server section (0.19).
  late final server = MockServerRelay(this);

  /// A `storage_measure` job finished: the measurement is new.
  MeasuredResult _measured() {
    final at = _nowSeconds();
    measurement = mockWireMeasurement(at);
    return MeasuredResult(measuredAt: at);
  }

  // ---- time zone (0.16)

  /// The box's zone (`time_zone.get`); a new box is on UTC.
  String timeZone = 'UTC';

  /// First-boot mode (no admin profile yet): `time_zone.set` needs no PIN.
  /// [MockDaemon] sets it to its profiles' state.
  bool Function()? firstBoot;

  Map<String, dynamic> _timeZoneInfo() {
    final z = mockTimeZone(timeZone) ?? mockTimeZone('UTC')!;
    return SystemTimeZoneGetResult(
      zone: z.zone,
      offsetS: z.offset * 60,
      standardOffsetS: z.standard * 60,
      offsetValidUntil: z.until,
    ).toJson();
  }

  /// Ids the next jobs get (then random-looking ones).
  final List<String> jobIdQueue = [];

  /// Every mutating call that reached the service, in order: `ssh.set`...
  final List<String> log = [];

  // ---- state

  final _jobs = <String, _Job>{};
  int _n = 0;
  UpdateCheckResult? _lastCheck;
  ChannelCheckResult? _lastChannelCheck;

  /// What `channel.check` finds on each channel (session API 0.17); a
  /// placeholder release when unset.
  final Map<Channel, AvailableUpdate> channelTips = {};

  static AvailableUpdate _defaultTip(Channel c) => AvailableUpdate(
    rev: c == Channel.stable
        ? '7e2d4f6a8b1c3e5d7f9a0b2c4d6e8f1a3b5c7d9e'
        : '1a2b3c4d5e6f708192a3b4c59a8b7c6d5e4f3021',
    date: 1791300000,
    summary: c == Channel.stable ? 'HinterOS 0.7.0' : 'Beta',
    signer: 'release@hinteros',
    security: null,
    commits: 1,
    newApps: null,
    removedApps: null,
    version: '0.7.0',
    securitySummary: null,
  );

  Job? job(String id) => _jobs[id] == null ? null : _wire(_jobs[id]!);

  /// The running job's id, if any.
  String? get runningJobId =>
      _jobs.values.where((j) => j.state == JobState.running).firstOrNull?.id;

  // ---- dispatch

  static bool handles(String method) =>
      method.startsWith('system.') || method == 'store.list';

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params,
  ) async {
    final u = unavailable;
    if (u != null) {
      throw ApiException(
        ApiErrorCode.systemUnavailable,
        u == SystemUnavailableDataReason.down
            ? 'the system service is not running'
            : 'the system service speaks another API version',
        SystemUnavailableData(reason: u).toJson(),
      );
    }
    try {
      return await _dispatch(method, params);
    } on ApiException {
      rethrow;
    } on TypeError catch (e) {
      throw ApiException(ApiErrorCode.invalidParams, 'bad params: $e');
    } on FormatException catch (e) {
      throw ApiException(
        ApiErrorCode.invalidParams,
        'bad params: ${e.message}',
      );
    }
  }

  void _closed(Map<String, dynamic> params, Iterable<String> allowed) {
    for (final k in params.keys) {
      if (!allowed.contains(k)) {
        throw ApiException(ApiErrorCode.invalidParams, 'unknown field $k', {
          'field': k,
          'reason': 'unknown field',
        });
      }
    }
  }

  /// A closed params object (for the other parts of the service).
  void closedParams(Map<String, dynamic> params, Iterable<String> allowed) =>
      _closed(params, allowed);

  /// A mutating request reached the service: logged, [failNext] applied.
  void mutating(String what) => _mutating(what);

  /// `state_conflict` unless [revision] is state.json's.
  void staleRevision(String revision) => _staleRevision(revision);

  /// state.json changed.
  void bumpRevision() => _bumpRevision();

  void _mutating(String what) {
    log.add(what);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String method,
    Map<String, dynamic> p,
  ) async {
    switch (method) {
      case 'system.info':
        _closed(p, const []);
        return SystemInfoResult(
          version: version,
          channel: channel,
          base: base,
          rev: rev,
          generation: generation,
          hostname: hostname,
          dev: dev,
          ssh: SystemInfoResultSsh(
            enabled: sshEnabled,
            hostKeyFingerprints: List.of(hostKeyFingerprints),
          ),
        ).toJson();
      case 'system.settings.get':
        _closed(p, const []);
        return SystemSettingsGetResult(
          revision: revision,
          settings: SystemSettingsGetResultSettings(
            base: base,
            ssh: SystemSettingsGetResultSettingsSsh(enabled: sshEnabled),
            requirements: const [],
          ),
        ).toJson();
      case 'system.settings.set':
        _closed(p, const ['revision', 'changes']);
        final r = SystemSettingsSetParams.fromJson(p);
        if ((p['changes'] as Map).isNotEmpty) {
          throw ApiException(
            ApiErrorCode.invalidParams,
            'changes has no settable fields in this version',
            {'field': (p['changes'] as Map).keys.first, 'reason': 'unknown'},
          );
        }
        _mutating('settings.set');
        if (r.revision != revision) {
          throw const ApiException(
            ApiErrorCode.stateConflict,
            'state.json changed since settings.get',
            {'reason': 'revision'},
          );
        }
        return const SystemSettingsSetResult(jobId: null).toJson();
      case 'system.ssh.set':
        _closed(p, const ['enabled']);
        final enable = SystemSshSetParams.fromJson(p).enabled;
        _mutating('ssh.set:${enable ? 'on' : 'off'}');
        if (enable && !adminAuthorized) {
          final ask = authorize;
          if (ask == null) {
            throw const ApiException(
              ApiErrorCode.authenticationRequired,
              'org.hinteros.system.ssh needs interactive authentication',
              {'action': 'org.hinteros.system.ssh'},
            );
          }
          await ask(
            'org.hinteros.system.ssh',
            'Authentication is required to turn remote login (SSH) on or off',
          );
        }
        if (enable == sshEnabled) return const JobRef(jobId: null).toJson();
        return _started(
          JobKind.ssh,
          subject: JobSubject(enabled: enable),
          onSuccess: () {
            sshEnabled = enable;
            _bumpRevision();
          },
        );
      case 'store.list':
        _closed(p, const []);
        return _storeList().toJson();
      case 'system.apps.install':
        _closed(p, const ['ids', 'revision', 'accepted_terms']);
        return _appsInstall(SystemAppsInstallParams.fromJson(p));
      case 'system.apps.remove':
        _closed(p, const ['ids', 'revision', 'delete_data']);
        return _appsRemove(SystemAppsRemoveParams.fromJson(p));
      case 'system.apps.clear_data':
        _closed(p, const ['id']);
        final id = SystemAppsClearDataParams.fromJson(p).id;
        _mutating('apps.clear_data:$id');
        if (!catalog.any((a) => a.id == id)) {
          throw ApiException(
            ApiErrorCode.notFound,
            '$id is not in the catalog',
          );
        }
        return _started(
          JobKind.appsClearData,
          subject: _appsSubject([id], deleteData: true),
          onSuccess: () {
            dataLeft.remove(id);
            if (installedApps.contains(id)) dataCleared.add(id);
          },
        );
      case 'system.generations.list':
        _closed(p, const []);
        return SystemGenerationsListResult(generations: List.of(generations))
            .toJson();
      case 'system.rebuild':
        _closed(p, const []);
        _mutating('rebuild');
        return _started(JobKind.rebuild);
      case 'system.hardware.redetect':
        _closed(p, const ['admin_pin']);
        _mutating('hardware.redetect');
        checkAdminPin?.call(SystemHardwareRedetectParams.fromJson(p).adminPin);
        return _started(JobKind.hardwareRedetect);
      case 'system.rollback':
        _closed(p, const ['generation', 'admin_pin']);
        final rp = SystemRollbackParams.fromJson(p);
        final want = rp.generation;
        _mutating('rollback');
        checkAdminPin?.call(rp.adminPin);
        final cur = generations.firstWhere((g) => g.current);
        final target = want == null
            ? generations
                  .where((g) => g.generation < cur.generation)
                  .firstOrNull
            : generations.where((g) => g.generation == want).firstOrNull;
        if (target == null || target.current) {
          throw ApiException(
            ApiErrorCode.notFound,
            want == null
                ? 'there is no earlier generation'
                : 'generation $want is not on disk',
          );
        }
        final id = _start(
          JobKind.rollback,
          subject: JobSubject(
            generation: target.generation,
            fromGeneration: cur.generation,
          ),
          onSuccess: () {
            generation = target.generation;
            rev = target.rev;
            generations = [
              for (final g in generations)
                Generation(
                  generation: g.generation,
                  date: g.date,
                  rev: g.rev,
                  current: g.generation == target.generation,
                  booted: g.booted,
                ),
            ];
          },
        );
        _jobs[id]!.featuresReadded = target.readdsFeatures;
        return JobRef(jobId: id).toJson();
      case 'system.update.check':
        _closed(p, const []);
        _mutating('update.check');
        final cached = _lastCheck;
        if (cached != null &&
            _nowSeconds() - cached.checkedAt < 60 &&
            cached.channel == channel) {
          return SystemUpdateCheckResult(jobId: null, result: cached).toJson();
        }
        final id = _start(
          JobKind.updateCheck,
          onSuccess: () {
            _lastCheck = UpdateCheckResult(
              channel: channel ?? Channel.stable,
              currentRev: rev,
              available: nextUpdate,
              checkedAt: _nowSeconds(),
            );
          },
        );
        return SystemUpdateCheckResult(jobId: id, result: null).toJson();
      case 'system.update.apply':
        _closed(p, const ['rev', 'admin_pin']);
        final ap = SystemUpdateApplyParams.fromJson(p);
        final want = ap.rev;
        _mutating('update.apply');
        checkAdminPin?.call(ap.adminPin);
        final a = _lastCheck?.available;
        if (a == null || a.rev != want) {
          throw const ApiException(
            ApiErrorCode.stateConflict,
            'rev is not the last verified update',
            {'reason': 'update_rev'},
          );
        }
        return _started(
          JobKind.updateApply,
          subject: JobSubject(
            rev: a.rev,
            version: a.version,
            channel: channel,
            fromRev: rev,
            fromVersion: version,
          ),
          onSuccess: () {
            generation = (generation ?? 0) + 1;
            rev = a.rev;
            _lastCheck = null;
            generations = [
              Generation(
                generation: generation!,
                date: a.date,
                rev: a.rev,
                current: true,
                booted: false,
              ),
              for (final g in generations)
                Generation(
                  generation: g.generation,
                  date: g.date,
                  rev: g.rev,
                  current: false,
                  booted: g.booted,
                ),
            ];
          },
        );
      case 'system.channel.check':
        _closed(p, const ['channel']);
        final cc = SystemChannelCheckParams.fromJson(p);
        _mutating('channel.check');
        if (cc.channel == channel) return const JobRef(jobId: null).toJson();
        final to = cc.channel;
        final tip = channelTips[to] ?? _defaultTip(to);
        final id = _start(
          JobKind.channelCheck,
          subject: JobSubject(
            channel: to,
            fromChannel: channel,
            fromRev: rev,
            rev: tip.rev,
            version: tip.version,
          ),
          onSuccess: () {
            _lastChannelCheck = ChannelCheckResult(
              channel: to,
              currentRev: rev,
              target: tip,
              // Stable after beta goes back to an older version.
              older: channel == Channel.beta && to == Channel.stable,
              checkedAt: _nowSeconds(),
            );
          },
        );
        return JobRef(jobId: id).toJson();
      case 'system.channel.set':
        _closed(p, const ['channel', 'rev', 'admin_pin']);
        final c = SystemChannelSetParams.fromJson(p);
        _mutating('channel.set');
        checkAdminPin?.call(c.adminPin);
        if (c.channel == channel) return const JobRef(jobId: null).toJson();
        final checked = _lastChannelCheck;
        if (checked == null ||
            checked.channel != c.channel ||
            checked.currentRev != rev ||
            checked.target.rev != c.rev) {
          throw const ApiException(
            ApiErrorCode.stateConflict,
            'rev is not the last verified channel check',
            {'reason': 'channel_rev'},
          );
        }
        return _started(
          JobKind.channel,
          subject: JobSubject(
            channel: c.channel,
            fromChannel: channel,
            rev: checked.target.rev,
            version: checked.target.version,
            fromRev: rev,
            fromVersion: version,
          ),
          onSuccess: () {
            channel = c.channel;
            rev = checked.target.rev;
            _lastChannelCheck = null;
          },
        );
      case 'system.base.set':
        _closed(p, const ['base', 'acknowledge_downgrade', 'admin_pin']);
        final b = SystemBaseSetParams.fromJson(p);
        _mutating('base.set');
        checkAdminPin?.call(b.adminPin);
        if (b.base == base) return const JobRef(jobId: null).toJson();
        if (!builtBases.contains(b.base)) {
          throw const ApiException(
            ApiErrorCode.unavailable,
            'this base is not built',
            {'service': 'base', 'reason': 'not_built'},
          );
        }
        if (base == Base.unstable &&
            b.base == Base.stable &&
            b.acknowledgeDowngrade != true) {
          throw const ApiException(
            ApiErrorCode.needsAcknowledgement,
            'unstable to stable is a downgrade',
          );
        }
        return _started(
          JobKind.base,
          subject: JobSubject(base: b.base, fromBase: base),
          onSuccess: () {
            base = b.base;
            _bumpRevision();
          },
        );
      case 'system.storage.get':
        _closed(p, const []);
        return SystemStorageGetResult(measurement: measurement).toJson();
      case 'system.storage.measure':
        _closed(p, const []);
        _mutating('storage.measure');
        final running = _jobs.values
            .where(
              (j) =>
                  j.state == JobState.running &&
                  j.kind == JobKind.storageMeasure,
            )
            .firstOrNull;
        if (running != null) return JobRef(jobId: running.id).toJson();
        return _started(JobKind.storageMeasure);
      case 'system.storage.tree':
        _closed(p, const ['id', 'admin_pin']);
        final tp = SystemStorageTreeParams.fromJson(p);
        if (!RegExp(r'^(p[1-9][0-9]{0,2}|guest)$').hasMatch(tp.id)) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad id', {
            'field': 'id',
            'reason': 'bad_format',
          });
        }
        _mutating('storage.tree:${tp.id}');
        if (tp.id != currentOwner?.call()) checkAdminPin?.call(tp.adminPin);
        final m = measurement;
        final home = homes[tp.id];
        if (m == null || home == null) {
          throw const ApiException(ApiErrorCode.notFound, 'not measured');
        }
        return SystemStorageTreeResult(
          id: tp.id,
          measuredAt: m.measuredAt,
          root: home,
        ).toJson();
      case 'system.storage.cleanup_system' || 'system.storage.cleanup_profiles':
        _closed(p, const ['keep', 'admin_pin']);
        final keep = p['keep'] as int;
        final pin = p['admin_pin'] as String?;
        if (keep < 1 || keep > 10) {
          throw const ApiException(ApiErrorCode.invalidParams, 'keep', {
            'field': 'keep',
            'reason': 'out_of_range',
          });
        }
        final system = method == 'system.storage.cleanup_system';
        _mutating(system ? 'cleanup_system:$keep' : 'cleanup_profiles:$keep');
        checkAdminPin?.call(pin);
        final id = _start(
          system ? JobKind.cleanupSystem : JobKind.cleanupProfiles,
          subject: JobSubject(keep: keep),
        );
        _jobs[id]!.cleaned = CleanedResult(
          freedBytes: keep < 3 ? 3000000000 : 1200000000,
          generationsRemoved: keep < 3 ? 4 : 1,
        );
        return JobRef(jobId: id).toJson();
      case 'system.cleanup.get':
        _closed(p, const []);
        return cleanup.toJson();
      case 'system.cleanup.set':
        _closed(p, const [
          'enabled',
          'frequency',
          'keep_system',
          'keep_profiles',
          'admin_pin',
        ]);
        final cp = SystemCleanupSetParams.fromJson(p);
        for (final (k, v) in [
          ('keep_system', cp.keepSystem),
          ('keep_profiles', cp.keepProfiles),
        ]) {
          if (v < 1 || v > 10) {
            throw ApiException(ApiErrorCode.invalidParams, k, {
              'field': k,
              'reason': 'out_of_range',
            });
          }
        }
        _mutating('cleanup.set');
        checkAdminPin?.call(cp.adminPin);
        final want = CleanupSettings(
          enabled: cp.enabled,
          frequency: cp.frequency,
          keepSystem: cp.keepSystem,
          keepProfiles: cp.keepProfiles,
        );
        if (want == cleanup) return const JobRef(jobId: null).toJson();
        return _started(JobKind.cleanupSet, onSuccess: () => cleanup = want);
      case 'system.time_zone.get':
        _closed(p, const []);
        return _timeZoneInfo();
      case 'system.time_zone.list':
        _closed(p, const []);
        return SystemTimeZoneListResult(
          zones: [
            for (final z in mockTimeZones)
              TimeZoneEntry(
                zone: z.zone,
                offsetS: z.offset * 60,
                standardOffsetS: z.standard * 60,
              ),
          ],
        ).toJson();
      case 'system.time_zone.set':
        _closed(p, const ['zone', 'admin_pin']);
        final tp = SystemTimeZoneSetParams.fromJson(p);
        final parts = tp.zone.split('/');
        if (tp.zone.length > 64 ||
            !RegExp(r'^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$')
                .hasMatch(tp.zone) ||
            parts.any((s) => s == '.' || s == '..')) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad zone', {
            'field': 'zone',
            'reason': 'bad_format',
          });
        }
        _mutating('time_zone.set:${tp.zone}');
        if (!(firstBoot?.call() ?? false)) checkAdminPin?.call(tp.adminPin);
        if (mockTimeZone(tp.zone) == null) {
          throw const ApiException(ApiErrorCode.invalidParams, 'unknown zone', {
            'field': 'zone',
            'reason': 'unknown',
          });
        }
        final changed = tp.zone != timeZone;
        timeZone = tp.zone;
        final info = _timeZoneInfo();
        if (changed) emit('time_zone_changed', info);
        return info;
      case 'system.jobs.get':
        _closed(p, const ['job_id']);
        final j = _find(SystemJobsGetParams.fromJson(p).jobId);
        return SystemJobsGetResult(job: _wire(j)).toJson();
      case 'system.jobs.list':
        _closed(p, const []);
        final running = _jobs.values.where((j) => j.state == JobState.running);
        final done = _jobs.values
            .where((j) => j.state != JobState.running)
            .toList()
            .reversed
            .take(10);
        return SystemJobsListResult(
          jobs: [
            for (final j in [...running, ...done]) _wire(j),
          ],
        ).toJson();
      case 'system.jobs.cancel':
        _closed(p, const ['job_id', 'admin_pin']);
        final cp = SystemJobsCancelParams.fromJson(p);
        final j = _find(cp.jobId);
        _mutating('jobs.cancel');
        // A job another profile started: only with the admin PIN.
        if (startedByOther.contains(j.id)) {
          if (cp.adminPin == null) {
            throw ApiException(
              ApiErrorCode.permissionDenied,
              'another profile started this job',
              PermissionDeniedData(
                action: 'org.hinteros.system.jobs.cancel',
                reason: PermissionDeniedDataReason.starter,
              ).toJson(),
            );
          }
          checkAdminPin?.call(cp.adminPin);
        }
        if (j.state != JobState.running ||
            j.stage.index >= Stage.activating.index) {
          throw ApiException(
            ApiErrorCode.jobBusy,
            'the job is ${j.state == JobState.running ? 'activating and can no longer be cancelled' : 'already finished'}',
            JobBusyData(jobId: j.id).toJson(),
          );
        }
        finishJob(j.id, ok: false, cancelled: true);
        return JobRef(jobId: j.id).toJson();
    }
    if (MockServerRelay.handles(method)) return server.call(method, p);
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  // ---- the Store

  StoreApp _catalogApp(String id) => catalog.firstWhere(
    (a) => a.id == id,
    orElse: () => throw ApiException(
      ApiErrorCode.notFound,
      '$id is not in this system\'s catalog',
    ),
  );

  Set<String> _jobApps(JobKind kind) => {
    for (final j in _jobs.values)
      if (j.state == JobState.running && j.kind == kind) ...j.apps,
  };

  bool get _moreAfterUpdate =>
      _lastCheck?.available?.newApps?.isNotEmpty ?? false;
  bool _lastMore = false;

  StoreListResult _storeList() {
    if (catalogMissing) {
      throw const ApiException(
        ApiErrorCode.unavailable,
        'no catalog index on this system',
        {'service': 'catalog', 'reason': 'missing'},
      );
    }
    final installing = _jobApps(JobKind.appsInstall);
    final removing = _jobApps(JobKind.appsRemove);
    StoreApp with_(StoreApp a, StoreState s) => StoreApp.fromJson({
      ...a.toJson(),
      'state': s.value,
      'permissions': [for (final p in permissionsOf(a.id)) p.toJson()],
      'has_data': _hasData(a.id),
    });
    final apps = <StoreApp>[];
    for (final a in catalog) {
      final installed = installedApps.contains(a.id);
      // Removed from the catalog, but its data is still in the home: only
      // Clear data, no permissions.
      if (a.status == CatalogStatus.removed && !installed) {
        if (_hasData(a.id)) {
          apps.add(
            StoreApp.fromJson({
              ...with_(a, StoreState.leftover).toJson(),
              'permissions': const [],
              'full_access': false,
            }),
          );
        }
        continue;
      }
      if (a.status != CatalogStatus.available && !installed) continue;
      apps.add(
        with_(
          a,
          installing.contains(a.id) && !installed
              ? StoreState.installing
              : removing.contains(a.id) && installed
              ? StoreState.removing
              : !installed
              ? StoreState.available
              : switch (a.status) {
                  CatalogStatus.available => StoreState.installed,
                  CatalogStatus.removed => StoreState.unavailable,
                  _ => StoreState.retired,
                },
        ),
      );
    }
    // Installed but unknown to this catalog: shown so it can be removed.
    for (final id in installedApps) {
      if (catalog.any((a) => a.id == id)) continue;
      apps.add(
        with_(
          mockStoreApp(id: id, name: id, status: CatalogStatus.removed),
          removing.contains(id) ? StoreState.removing : StoreState.unavailable,
        ),
      );
    }
    apps.sort((a, b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return StoreListResult(
      indexVersion: 4,
      apps: apps,
      moreAfterUpdate: _moreAfterUpdate,
    );
  }

  void _staleRevision(String revision) {
    if (revision != this.revision) {
      throw const ApiException(
        ApiErrorCode.stateConflict,
        'state.json changed since settings.get',
        {'reason': 'revision'},
      );
    }
  }

  Map<String, dynamic> _appsInstall(SystemAppsInstallParams p) {
    _mutating('apps.install:${p.ids.join(',')}');
    _staleRevision(p.revision);
    for (final id in p.ids) {
      final a = _catalogApp(id);
      if (a.status != CatalogStatus.available && !installedApps.contains(id)) {
        throw ApiException(ApiErrorCode.invalidParams, '$id is not available', {
          'field': 'ids',
          'reason': 'not_available',
        });
      }
    }
    // What gets installed: the request and its depends, transitively, minus
    // what is installed already.
    final want = <String>[];
    void add(String id) {
      if (installedApps.contains(id) || want.contains(id)) return;
      want.add(id);
      _catalogApp(id).depends.forEach(add);
    }

    p.ids.forEach(add);
    if (want.isEmpty) return const JobRef(jobId: null).toJson();
    final all = {...installedApps, ...want};
    for (final id in want) {
      final a = _catalogApp(id);
      for (final other in all) {
        if (other == id) continue;
        final b = catalog.where((x) => x.id == other).firstOrNull;
        if (a.conflicts.contains(other) ||
            (b?.conflicts.contains(id) ?? false)) {
          throw ApiException(
            ApiErrorCode.appConflict,
            '$id conflicts with $other',
            AppConflictData(id: id, conflictsWith: other).toJson(),
          );
        }
      }
    }
    for (final id in want) {
      final t = _catalogApp(id).terms;
      if (t != null && p.acceptedTerms?[id] != t.version) {
        throw ApiException(
          ApiErrorCode.termsRequired,
          '$id needs its terms accepted (version ${t.version})',
          TermsRequiredData(id: id, version: t.version).toJson(),
        );
      }
    }
    final needed = want.fold<int>(0, (n, id) => n + _catalogApp(id).sizeMib);
    if (needed > freeDiskMib) {
      throw ApiException(
        ApiErrorCode.insufficientResources,
        'not enough free disk space',
        InsufficientResourcesData(
          kind: InsufficientResourcesDataKind.disk,
          neededBytes: needed << 20,
          availableBytes: freeDiskMib << 20,
        ).toJson(),
      );
    }
    for (final id in want) {
      final v = _catalogApp(id).terms?.version;
      if (v != null) acceptances.add('$id=$v');
    }
    return _started(
      JobKind.appsInstall,
      apps: want,
      subject: _appsSubject(want),
      onSuccess: () {
        installedApps.addAll(want);
        onAppsInstalled?.call([for (final id in want) _catalogApp(id)]);
        _bumpRevision();
      },
    );
  }

  Map<String, dynamic> _appsRemove(SystemAppsRemoveParams p) {
    _mutating('apps.remove:${p.ids.join(',')}:data=${p.deleteData}');
    _staleRevision(p.revision);
    for (final id in p.ids) {
      if (!installedApps.contains(id)) {
        throw ApiException(ApiErrorCode.notFound, '$id is not installed');
      }
    }
    for (final other in installedApps.where((i) => !p.ids.contains(i))) {
      final b = catalog.where((x) => x.id == other).firstOrNull;
      for (final id in p.ids) {
        if (b?.depends.contains(id) ?? false) {
          throw ApiException(
            ApiErrorCode.appConflict,
            '$other depends on $id',
            AppConflictData(id: id, conflictsWith: other).toJson(),
          );
        }
      }
    }
    return _started(
      JobKind.appsRemove,
      apps: List.of(p.ids),
      subject: _appsSubject(p.ids, deleteData: p.deleteData),
      onSuccess: () {
        installedApps.removeWhere(p.ids.contains);
        for (final id in p.ids) {
          dataCleared.remove(id);
          p.deleteData ? dataLeft.remove(id) : dataLeft.add(id);
        }
        onAppsRemoved?.call(List.of(p.ids));
        _bumpRevision();
      },
    );
  }

  /// An apps job's subject: whose apps, which ones (catalog names).
  JobSubject _appsSubject(List<String> ids, {bool? deleteData}) {
    final owner = currentOwner?.call();
    return JobSubject(
      owner: owner,
      profile: owner == null || owner == 'guest'
          ? null
          : SubjectProfile(id: owner, name: profileName?.call(owner) ?? owner),
      apps: [
        for (final id in ids)
          CatalogApp(
            id: id,
            name: catalog.where((a) => a.id == id).firstOrNull?.name ?? id,
          ),
      ],
      deleteData: deleteData,
    );
  }

  // ---- jobs

  int _nowSeconds() => _now().millisecondsSinceEpoch ~/ 1000;

  void _bumpRevision() {
    final n = int.parse(revision.substring(0, 8), radix: 16) + 7919;
    revision = n.toRadixString(16).padLeft(8, '0') + revision.substring(8);
  }

  _Job _find(String id) {
    final j = _jobs[id];
    if (j == null) {
      throw const ApiException(ApiErrorCode.notFound, 'no such job');
    }
    return j;
  }

  Map<String, dynamic> _started(
    JobKind kind, {
    void Function()? onSuccess,
    List<String> apps = const [],
    JobSubject subject = const JobSubject(),
  }) => JobRef(
    jobId: _start(kind, onSuccess: onSuccess, apps: apps, subject: subject),
  ).toJson();

  /// Starts a job of [kind] (one at a time: `job_busy`), for the other
  /// mocks whose methods run jobs (profiles, guest, starter set).
  String startJob(
    JobKind kind, {
    void Function()? onSuccess,
    JobSubject subject = const JobSubject(),
    String? authUrl,
  }) {
    final id = _start(kind, onSuccess: onSuccess, subject: subject);
    _jobs[id]!.authUrl = authUrl;
    return id;
  }

  String _start(
    JobKind kind, {
    void Function()? onSuccess,
    List<String> apps = const [],
    JobSubject subject = const JobSubject(),
  }) {
    final running = runningJobId;
    if (running != null) {
      throw ApiException(
        ApiErrorCode.jobBusy,
        'another job is running',
        JobBusyData(jobId: running).toJson(),
      );
    }
    final id = jobIdQueue.isNotEmpty
        ? jobIdQueue.removeAt(0)
        // In two halves: JavaScript numbers hold 53 bits (the web demo).
        : '3f9a0c2b${(0x7e4d1a65 + ++_n * 7919).toRadixString(16).padLeft(8, '0')}';
    final j = _Job(id, kind, _nowSeconds(), onSuccess: onSuccess)
      ..restart = restartNext
      ..apps = apps
      ..subject = subject;
    restartNext = false;
    _jobs[id] = j;
    emit(
      'job_started',
      JobStartedEvent(
        jobId: id,
        kind: kind,
        uid: 1000,
        subject: subject,
        startedAt: j.createdAt,
      ).toJson(),
    );
    if (kind == JobKind.appsInstall || kind == JobKind.appsRemove) {
      emit('store_changed', const {});
    }
    if (stepDelay != null) _autoRun(j);
    return id;
  }

  void _autoRun(_Job j) {
    final stages = mockStagesOf(j.kind);
    var i = 0;
    var pct = 0;
    var built = 0;
    void step() {
      if (j.state != JobState.running) return;
      final s = stages[i];
      if (s == Stage.downloading || s == Stage.measuring) {
        progressJob(j.id, s, percent: pct);
        pct += 25;
        if (pct <= 100) {
          j.timer = Timer(stepDelay!, step);
          return;
        }
      } else if (s == Stage.signingIn) {
        progressJob(j.id, s, authUrl: j.authUrl);
      } else if (s == Stage.building && built < mockBuilds.length) {
        // A few derivations, one at a time, like nix reports them.
        final (name, version) = mockBuilds[built];
        progressJob(
          j.id,
          s,
          percent: built * 100 ~/ mockBuilds.length,
          buildsDone: built,
          buildsTotal: mockBuilds.length,
          building: Building(
            name: name,
            version: version,
            phase: 'build',
            percent: 20,
          ),
        );
        built++;
        j.timer = Timer(stepDelay!, step);
        return;
      } else {
        progressJob(j.id, s);
      }
      i++;
      j.timer = i >= stages.length
          ? Timer(stepDelay!, () => finishJob(j.id))
          : Timer(stepDelay!, step);
    }

    j.timer = Timer(stepDelay!, step);
  }

  /// `job_progress` for a running job (a stage, a percent, what builds).
  void progressJob(
    String id,
    Stage stage, {
    int? percent,
    int? bytesTotal,
    int? buildsDone,
    int? buildsTotal,
    Building? building,
    String? authUrl,
  }) {
    final j = _find(id);
    if (j.state != JobState.running) return;
    j.stage = stage;
    j.percent = percent;
    j.lastActivityAt = _nowSeconds();
    final builds =
        buildsDone != null || buildsTotal != null || building != null;
    j.detail = authUrl != null
        ? ProgressDetail(authUrl: authUrl)
        : bytesTotal == null && !builds
        ? null
        : ProgressDetail(
            bytesDone: bytesTotal == null || percent == null
                ? null
                : bytesTotal * percent ~/ 100,
            bytesTotal: bytesTotal,
            buildsDone: buildsDone,
            buildsTotal: buildsTotal,
            buildsRunning: building == null ? null : 1,
            building: building,
          );
    _progress(j);
  }

  /// The heartbeat: the latest state again, with nothing new (the service
  /// sends one at least every 2 s while a job runs).
  void heartbeat(String id) {
    final j = _find(id);
    if (j.state != JobState.running) return;
    _progress(j);
  }

  void _progress(_Job j) => emit(
    'job_progress',
    JobProgressEvent(
      jobId: j.id,
      kind: j.kind,
      stage: j.stage,
      percent: j.percent,
      detail: j.detail,
      startedAt: j.createdAt,
      lastActivityAt: j.lastActivityAt,
    ).toJson(),
  );

  /// `job_finished`. A failure carries `job_failed` with the stage reached;
  /// [cancelled] is how `jobs.cancel` ends a job.
  void finishJob(
    String id, {
    bool ok = true,
    bool cancelled = false,
    ErrorObject? error,
    bool? sessionRestartRequired,
  }) {
    final j = _find(id);
    if (j.state != JobState.running) return;
    j.timer?.cancel();
    j.finishedAt = _nowSeconds();
    j.state = ok
        ? JobState.succeeded
        : cancelled
        ? JobState.cancelled
        : JobState.failed;
    if (!ok) {
      j.error =
          error ??
          ErrorObject(
            code: ApiErrorCode.jobFailed,
            message: cancelled ? 'cancelled' : 'the job failed',
            data: JobFailedData(
              stage: j.stage,
              logHint: '',
              reason: cancelled ? JobFailedDataReason.cancelled : null,
            ).toJson(),
          );
    }
    if (ok) {
      j.onSuccess?.call();
      j.stage = Stage.finishing;
      j.result = j.kind == JobKind.updateCheck
          ? _lastCheck?.toJson()
          : j.kind == JobKind.channelCheck
          ? _lastChannelCheck?.toJson()
          : j.kind == JobKind.storageMeasure
          ? _measured().toJson()
          : j.cleaned != null
          ? j.cleaned!.toJson()
          : AppliedResult(
              generation: generation,
              rev: rev,
              featuresReadded: j.featuresReadded,
            ).toJson();
    }
    final restart = sessionRestartRequired ?? (ok && j.restart);
    j.restart = restart;
    emit(
      'job_finished',
      JobFinishedEvent(
        jobId: id,
        kind: j.kind,
        ok: ok,
        error: j.error,
        result: j.result,
        sessionRestartRequired: restart,
        subject: j.subject,
        startedAt: j.createdAt,
        finishedAt: j.finishedAt!,
      ).toJson(),
    );
    final more = _moreAfterUpdate;
    if (j.kind == JobKind.appsInstall ||
        j.kind == JobKind.appsRemove ||
        (ok &&
            j.kind != JobKind.updateCheck &&
            j.kind != JobKind.channelCheck) ||
        more != _lastMore) {
      emit('store_changed', const {});
    }
    _lastMore = more;
  }

  Job _wire(_Job j) => Job(
    jobId: j.id,
    kind: j.kind,
    uid: 1000,
    state: j.state,
    stage: j.stage,
    createdAt: j.createdAt,
    finishedAt: j.finishedAt,
    error: j.error,
    result: j.result,
    sessionRestartRequired: j.restart,
    subject: j.subject,
    startedAt: j.createdAt,
    percent: j.state == JobState.running ? j.percent : null,
    detail: j.state == JobState.running ? j.detail : null,
    lastActivityAt: j.state == JobState.running ? j.lastActivityAt : null,
  );

  void dispose() {
    for (final j in _jobs.values) {
      j.timer?.cancel();
    }
  }
}

// ---------------------------------------------------------------- storage

StorageNode _node(
  NodeKind kind,
  int bytes, {
  List<StorageNode> children = const [],
  String? id,
  String? name,
  int? appId,
}) => StorageNode(
  kind: kind,
  bytes: bytes,
  children: children,
  id: id,
  name: name,
  appId: appId,
);

/// The homes of the mock box (James p1, Sam p3, the guest), wire shapes.
Map<String, StorageNode> mockWireHomes() => {
  'p1': _node(
    NodeKind.profile,
    3000000000,
    id: 'p1',
    children: [
      _node(
        NodeKind.steam,
        2000000000,
        children: [
          _node(NodeKind.steamGame, 2000000000, name: 'Portal 2', appId: 620),
        ],
      ),
      _node(NodeKind.dir, 800000000, name: '.local'),
      _node(NodeKind.files, 200000000),
    ],
  ),
  'p3': _node(
    NodeKind.profile,
    1000000000,
    id: 'p3',
    children: [
      _node(NodeKind.dir, 900000000, name: 'Music'),
      _node(NodeKind.files, 100000000),
    ],
  ),
  'guest': _node(
    NodeKind.guest,
    10000000,
    children: [_node(NodeKind.files, 10000000)],
  ),
};

/// A measurement of the mock box taken at [at] (Unix seconds).
Measurement mockWireMeasurement([int at = 1791300000]) {
  final homes = mockWireHomes();
  return Measurement(
    measuredAt: at,
    disk: const DiskUsage(
      totalBytes: 512000000000,
      usedBytes: 21000000000,
      freeBytes: 491000000000,
    ),
    root: _node(
      NodeKind.disk,
      512000000000,
      children: [
        _node(
          NodeKind.system,
          9000000000,
          children: [
            const StorageNode(
              kind: NodeKind.generation,
              bytes: 1400000000,
              children: [],
              generation: 42,
              date: 1790000000,
              current: true,
              booted: false,
            ),
            _node(NodeKind.common, 7600000000),
          ],
        ),
        _node(
          NodeKind.apps,
          3000000000,
          children: [
            _node(NodeKind.appEnv, 900000000, id: 'p1'),
            _node(NodeKind.shared, 2100000000),
          ],
        ),
        for (final e in homes.entries)
          _node(
            e.value.kind,
            e.value.bytes,
            id: e.key == 'guest' ? null : e.key,
          ),
        _node(NodeKind.media, 2000000000),
        _node(NodeKind.other, 1990000000),
        _node(NodeKind.free, 491000000000),
      ],
    ),
    garbageBytes: 1200000000,
    estimates: MeasurementEstimates(
      system: [
        for (var k = 1; k <= 10; k++)
          CleanupEstimate(
            keep: k,
            generations: k < 3 ? 3 - k : 0,
            bytes: 1200000000 + (k < 3 ? (3 - k) * 600000000 : 0),
          ),
      ],
      profiles: [
        for (var k = 1; k <= 10; k++)
          CleanupEstimate(
            keep: k,
            generations: k < 2 ? 2 : 0,
            bytes: 1200000000 + (k < 2 ? 300000000 : 0),
          ),
      ],
    ),
  );
}
