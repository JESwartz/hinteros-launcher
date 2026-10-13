/// The `system.*` side of [MockDaemon]: what the session daemon relays from the
/// privileged system service in session API 0.6, with the service's rules
/// (one mutating job at a time, `needs_acknowledgement` for downgrades,
/// `state_conflict` for a stale revision or an unverified update rev,
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
import 'mock_store.dart';

/// Wire stages of each kind of job (system-api.md "Job model").
List<Stage> mockStagesOf(JobKind kind) => switch (kind) {
  JobKind.updateCheck => const [
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

  /// The catalog of the running generation (`store.list`). Entries are wire
  /// apps; the `state` is worked out on every call.
  List<StoreApp> catalog;

  /// No catalog index on this system (`store.list` is `unavailable`).
  bool catalogMissing = false;

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
  /// 0.5): throws `pin_required` or `invalid_params`. Null: no PIN needed (a
  /// schema-1 box). [MockDaemon] sets it to its profiles' check.
  void Function(String? adminPin)? checkAdminPin;

  /// Ids the next jobs get (then random-looking ones).
  final List<String> jobIdQueue = [];

  /// Every mutating call that reached the service, in order: `ssh.set`...
  final List<String> log = [];

  // ---- state

  final _jobs = <String, _Job>{};
  int _n = 0;
  UpdateCheckResult? _lastCheck;

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
            apps: List.of(installedApps),
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
      case 'system.channel.set':
        _closed(p, const ['channel', 'acknowledge_downgrade', 'admin_pin']);
        final c = SystemChannelSetParams.fromJson(p);
        if (c.channel == Channel.unknown) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad channel');
        }
        _mutating('channel.set');
        checkAdminPin?.call(c.adminPin);
        if (c.channel == channel) return const JobRef(jobId: null).toJson();
        if (channel == Channel.beta &&
            c.channel == Channel.stable &&
            c.acknowledgeDowngrade != true) {
          throw const ApiException(
            ApiErrorCode.needsAcknowledgement,
            'switching from beta to stable is a downgrade',
          );
        }
        return _started(JobKind.channel, onSuccess: () => channel = c.channel);
      case 'system.base.set':
        _closed(p, const ['base', 'acknowledge_downgrade', 'admin_pin']);
        final b = SystemBaseSetParams.fromJson(p);
        if (b.base == Base.unknown) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad base');
        }
        _mutating('base.set');
        checkAdminPin?.call(b.adminPin);
        if (b.base == base) return const JobRef(jobId: null).toJson();
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
          onSuccess: () {
            base = b.base;
            _bumpRevision();
          },
        );
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
        _closed(p, const ['job_id']);
        final j = _find(SystemJobsCancelParams.fromJson(p).jobId);
        _mutating('jobs.cancel');
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
    StoreApp with_(StoreApp a, StoreState s) =>
        StoreApp.fromJson({...a.toJson(), 'state': s.value});
    final apps = <StoreApp>[];
    for (final a in catalog) {
      final installed = installedApps.contains(a.id);
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
      indexVersion: 2,
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
      onSuccess: () {
        installedApps.removeWhere(p.ids.contains);
        onAppsRemoved?.call(List.of(p.ids));
        _bumpRevision();
      },
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
  }) => JobRef(
    jobId: _start(kind, onSuccess: onSuccess, apps: apps),
  ).toJson();

  /// Starts a job of [kind] (one at a time: `job_busy`), for the other
  /// mocks whose methods run jobs (profiles, guest, starter set).
  String startJob(JobKind kind, {void Function()? onSuccess}) =>
      _start(kind, onSuccess: onSuccess);

  String _start(
    JobKind kind, {
    void Function()? onSuccess,
    List<String> apps = const [],
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
        : (0x3f9a0c2b7e4d1a65 + ++_n * 7919).toRadixString(16).padLeft(16, '0');
    final j = _Job(id, kind, _nowSeconds(), onSuccess: onSuccess)
      ..restart = restartNext
      ..apps = apps;
    restartNext = false;
    _jobs[id] = j;
    emit(
      'job_started',
      JobStartedEvent(jobId: id, kind: kind, uid: 1000).toJson(),
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
    void step() {
      if (j.state != JobState.running) return;
      final s = stages[i];
      if (s == Stage.downloading) {
        progressJob(j.id, s, percent: pct);
        pct += 25;
        if (pct <= 100) {
          j.timer = Timer(stepDelay!, step);
          return;
        }
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

  /// `job_progress` for a running job.
  void progressJob(String id, Stage stage, {int? percent, int? bytesTotal}) {
    final j = _find(id);
    if (j.state != JobState.running) return;
    j.stage = stage;
    emit(
      'job_progress',
      JobProgressEvent(
        jobId: id,
        stage: stage,
        percent: percent,
        detail: bytesTotal == null
            ? null
            : ProgressDetail(
                bytesDone: percent == null ? null : bytesTotal * percent ~/ 100,
                bytesTotal: bytesTotal,
              ),
      ).toJson(),
    );
  }

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
            data: JobFailedData(stage: j.stage, logHint: '').toJson(),
          );
    }
    if (ok) {
      j.onSuccess?.call();
      j.stage = Stage.finishing;
      j.result = j.kind == JobKind.updateCheck
          ? _lastCheck?.toJson()
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
      ).toJson(),
    );
    final more = _moreAfterUpdate;
    if (j.kind == JobKind.appsInstall ||
        j.kind == JobKind.appsRemove ||
        (ok && j.kind != JobKind.updateCheck) ||
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
  );

  void dispose() {
    for (final j in _jobs.values) {
      j.timer?.cancel();
    }
  }
}
