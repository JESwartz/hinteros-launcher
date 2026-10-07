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
}

class MockSystemRelay {
  MockSystemRelay({
    required this.emit,
    DateTime Function()? now,
    this.stepDelay,
  }) : _now = now ?? DateTime.now {
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

  /// Catalog ids installed from the Store (`settings.get`, state.json apps).
  final List<String> installedApps = ['steam'];
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

  static bool handles(String method) => method.startsWith('system.');

  Map<String, dynamic> call(String method, Map<String, dynamic> params) {
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
      return _dispatch(method, params);
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

  Map<String, dynamic> _dispatch(String method, Map<String, dynamic> p) {
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
          throw const ApiException(
            ApiErrorCode.authenticationRequired,
            'org.hinteros.system.ssh needs interactive authentication',
            {'action': 'org.hinteros.system.ssh'},
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
      case 'system.generations.list':
        _closed(p, const []);
        return SystemGenerationsListResult(generations: List.of(generations))
            .toJson();
      case 'system.rebuild':
        _closed(p, const []);
        _mutating('rebuild');
        return _started(JobKind.rebuild);
      case 'system.hardware.redetect':
        _closed(p, const []);
        _mutating('hardware.redetect');
        return _started(JobKind.hardwareRedetect);
      case 'system.rollback':
        _closed(p, const ['generation']);
        final want = SystemRollbackParams.fromJson(p).generation;
        _mutating('rollback');
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
        return _started(
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
        _closed(p, const ['rev']);
        final want = SystemUpdateApplyParams.fromJson(p).rev;
        _mutating('update.apply');
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
        _closed(p, const ['channel', 'acknowledge_downgrade']);
        final c = SystemChannelSetParams.fromJson(p);
        if (c.channel == Channel.unknown) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad channel');
        }
        _mutating('channel.set');
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
        _closed(p, const ['base', 'acknowledge_downgrade']);
        final b = SystemBaseSetParams.fromJson(p);
        if (b.base == Base.unknown) {
          throw const ApiException(ApiErrorCode.invalidParams, 'bad base');
        }
        _mutating('base.set');
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

  Map<String, dynamic> _started(JobKind kind, {void Function()? onSuccess}) =>
      JobRef(jobId: _start(kind, onSuccess: onSuccess)).toJson();

  String _start(JobKind kind, {void Function()? onSuccess}) {
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
      ..restart = restartNext;
    restartNext = false;
    _jobs[id] = j;
    emit(
      'job_started',
      JobStartedEvent(jobId: id, kind: kind, uid: 1000).toJson(),
    );
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
          : AppliedResult(generation: generation, rev: rev).toJson();
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
