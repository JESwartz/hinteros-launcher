/// The real system repositories: `SystemRepository` (info, SSH, power),
/// `UpdatesRepository` and `JobsRepository` over the session daemon's
/// `system.*` relay (the daemon forwards the privileged service's methods and
/// its three job events unchanged), and the runtime settings of session API
/// 0.7 (`daemon_runtime.dart`). Only the Store is still unavailable, see
/// [daemonSystemServices].
library;

import 'dart:async';

import '../api/api.dart' as api;
import '../log.dart';
import 'daemon_auth.dart';
import 'daemon_errors.dart';
import 'daemon_runtime.dart';
import 'daemon_store.dart';
import 'models.dart';
import 'repositories.dart';

export 'daemon_errors.dart';

// ---------------------------------------------------------------- wire mapping

JobKind _jobKind(api.JobKind k) => switch (k) {
  api.JobKind.settings || api.JobKind.rebuild => JobKind.rebuild,
  api.JobKind.hardwareRedetect => JobKind.hardwareRedetect,
  api.JobKind.ssh => JobKind.ssh,
  api.JobKind.updateCheck => JobKind.updateCheck,
  api.JobKind.updateApply => JobKind.update,
  api.JobKind.appsInstall => JobKind.install,
  api.JobKind.appsRemove => JobKind.remove,
  api.JobKind.rollback => JobKind.rollback,
  api.JobKind.channel => JobKind.channel,
  api.JobKind.base => JobKind.base,
  api.JobKind.unknown => JobKind.rebuild,
};

JobStage? _stage(api.Stage? s) => switch (s) {
  api.Stage.preparing => JobStage.preparing,
  api.Stage.fetching => JobStage.fetching,
  api.Stage.verifying => JobStage.verifying,
  api.Stage.evaluating => JobStage.evaluating,
  api.Stage.downloading => JobStage.downloading,
  api.Stage.building => JobStage.building,
  api.Stage.activating => JobStage.activating,
  api.Stage.finishing => JobStage.finishing,
  api.Stage.unknown || null => null,
};

UpdateChannel? _channel(api.Channel? c) => switch (c) {
  api.Channel.beta => UpdateChannel.beta,
  api.Channel.stable => UpdateChannel.stable,
  api.Channel.unknown || null => null,
};

NixBase _base(api.Base b) =>
    b == api.Base.stable ? NixBase.stable : NixBase.unstable;

SecuritySeverity _severity(api.Severity s) => switch (s) {
  api.Severity.low => SecuritySeverity.low,
  api.Severity.medium => SecuritySeverity.moderate,
  api.Severity.high => SecuritySeverity.high,
  api.Severity.critical => SecuritySeverity.critical,
  api.Severity.unknown => SecuritySeverity.unknown,
};

/// `available.version` if it is a release version (`0.6.1`, `0.7.0-rc.1`);
/// null for the daemon's short-revision fallback or an older daemon, which
/// leave the update to be named by its date.
String? releaseVersion(String? v) =>
    v != null && _semver.hasMatch(v) && v.length <= 32 ? v : null;

final _semver = RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$');

/// A daemon-provided line, trimmed to one line of at most 120 characters;
/// null when empty.
String? _oneLine(String? s) {
  if (s == null) return null;
  final line = s.split(RegExp(r'[\r\n]')).first.trim();
  if (line.isEmpty) return null;
  return line.length > 120 ? line.substring(0, 120) : line;
}

DateTime _unix(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

String _size(int bytes) => bytes >= 1 << 30
    ? '${(bytes / (1 << 30)).toStringAsFixed(1)} GB'
    : '${(bytes / (1 << 20)).round()} MB';

String? _progressText(api.ProgressDetail? d) {
  if (d == null) return null;
  if (d.bytesTotal != null && d.bytesTotal! > 0) {
    return '${_size(d.bytesDone ?? 0)} of ${_size(d.bytesTotal!)}';
  }
  if (d.pathsTotal != null && d.pathsTotal! > 0) {
    return '${d.pathsDone ?? 0} of ${d.pathsTotal} items';
  }
  return null;
}

/// `job_finished.error` / `jobs.get`'s error as the progress page shows it.
JobError _jobError(api.ErrorObject e) {
  final data = e.data is Map
      ? (e.data! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final stage = data['stage'] is String
      ? _stage(api.Stage.fromJson(data['stage']! as String))
      : null;
  final kind = switch (e.code) {
    api.ApiErrorCode.updateUnreachable => SystemErrorKind.updateUnreachable,
    api.ApiErrorCode.updateVerificationFailed =>
      SystemErrorKind.updateVerificationFailed,
    api.ApiErrorCode.needsAcknowledgement =>
      SystemErrorKind.needsAcknowledgement,
    api.ApiErrorCode.insufficientResources =>
      SystemErrorKind.insufficientResources,
    _ => null,
  };
  return JobError(
    message: e.message,
    stage: stage,
    logHint: data['log_hint'] as String?,
    kind: kind,
  );
}

/// A job that ended because of `jobs.cancel` (state `cancelled`, or
/// `job_finished` with `job_failed` and the message "cancelled").
bool _isCancel(api.ErrorObject? e) =>
    e != null &&
    e.code == api.ApiErrorCode.jobFailed &&
    e.message == 'cancelled';

Map<String, dynamic>? _asMap(Object? o) =>
    o is Map ? o.cast<String, dynamic>() : null;

// ---------------------------------------------------------------- jobs

class _Entry {
  _Entry(this.snap, {required this.kindKnown});

  JobSnapshot snap;

  /// `job_progress` does not carry the kind: an entry made from one waits
  /// for `job_started`, `job_finished` or the method that started the job.
  bool kindKnown;
  bool refreshed = false;
  final changes = StreamController<JobSnapshot>.broadcast(sync: true);
}

/// Follows jobs through `job_started` / `job_progress` / `job_finished`, with
/// `jobs.get` to catch up (a job that began before the launcher looked, or
/// events missed while disconnected).
class DaemonJobs implements JobsRepository {
  DaemonJobs(this._conn) {
    _events = _conn.events.listen(_onEvent);
    _status = _conn.statusChanges.listen((s) {
      if (s is api.Connected) unawaited(_resync());
    });
    unawaited(
      _conn
          .subscribeTo(const [
            api.EventName.jobStarted,
            api.EventName.jobProgress,
            api.EventName.jobFinished,
          ])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  late final StreamSubscription<api.SessionEvent> _events;
  late final StreamSubscription<api.ConnectionStatus> _status;
  final _jobs = <String, _Entry>{};

  /// Remembers a job this client started (the kind comes from the method).
  void track(String jobId, JobKind kind) {
    final e = _jobs[jobId];
    if (e == null) {
      _jobs[jobId] = _Entry(
        JobSnapshot(jobId: jobId, kind: kind),
        kindKnown: true,
      );
    } else if (!e.kindKnown) {
      e.kindKnown = true;
      e.snap = e.snap.copyWith(kind: kind);
    }
    _prune();
  }

  /// Starts a job through [call] (a relayed method returning a `JobRef`).
  Future<JobHandle> start(
    JobKind kind,
    Future<String?> Function() call, {
    String nothingToDo = 'There is nothing to change.',
  }) async {
    final id = await guardCall(call);
    if (id == null) {
      throw SystemException(SystemErrorKind.nothingToDo, nothingToDo);
    }
    track(id, kind);
    return JobHandle(id, kind);
  }

  void _prune() {
    final done = _jobs.entries.where((e) => e.value.snap.finished).toList();
    for (final e in done.take((done.length - 20).clamp(0, done.length))) {
      _jobs.remove(e.key);
    }
  }

  _Entry _entry(String id, {JobKind? kind}) => _jobs.putIfAbsent(
    id,
    () => _Entry(
      JobSnapshot(jobId: id, kind: kind ?? JobKind.rebuild),
      kindKnown: kind != null,
    ),
  );

  void _set(_Entry e, JobSnapshot s) {
    e.snap = s;
    e.changes.add(s);
  }

  void _onEvent(api.SessionEvent ev) {
    switch (ev) {
      case api.JobStartedEvent():
        final e = _entry(ev.jobId, kind: _jobKind(ev.kind));
        if (!e.kindKnown || e.snap.kind != _jobKind(ev.kind)) {
          e.kindKnown = true;
          _set(e, e.snap.copyWith(kind: _jobKind(ev.kind)));
        }
      case api.JobProgressEvent():
        final e = _entry(ev.jobId);
        if (e.snap.finished) return;
        final stage = _stage(ev.stage) ?? e.snap.stage;
        _set(
          e,
          e.snap.copyWith(
            stage: stage,
            percent: ev.percent,
            clearPercent: ev.percent == null,
            detail: _progressText(ev.detail),
          ),
        );
      case api.JobFinishedEvent():
        final e = _entry(ev.jobId, kind: _jobKind(ev.kind));
        final kind = _jobKind(ev.kind);
        if (!e.kindKnown) e.kindKnown = true;
        final cancelled = !ev.ok && _isCancel(ev.error);
        if (!ev.ok && !cancelled) {
          final err = ev.error;
          logSink(
            'hinteros-launcher: job ${kind.name} (${ev.jobId}) failed'
            '${err == null ? '' : ": ${err.code} ${err.message}"}',
          );
        }
        _set(
          e,
          e.snap.copyWith(
            kind: e.snap.kind == JobKind.rebuild ? kind : e.snap.kind,
            finished: true,
            ok: ev.ok,
            cancelled: cancelled,
            error: ev.ok || cancelled || ev.error == null
                ? null
                : _jobError(ev.error!),
            sessionRestartRequired: ev.sessionRestartRequired,
            result: _asMap(ev.result),
          ),
        );
      default:
    }
  }

  JobSnapshot _fromJob(api.Job j, JobSnapshot? old) {
    final finished = j.state != api.JobState.running;
    final cancelled =
        j.state == api.JobState.cancelled ||
        (j.state == api.JobState.failed && _isCancel(j.error));
    return JobSnapshot(
      jobId: j.jobId,
      kind: _jobKind(j.kind),
      stage: _stage(j.stage) ?? old?.stage ?? JobStage.preparing,
      percent: finished ? null : old?.percent,
      detail: finished ? null : old?.detail,
      finished: finished,
      ok: j.state == api.JobState.succeeded,
      cancelled: cancelled,
      error: finished && !cancelled && j.error != null
          ? _jobError(j.error!)
          : null,
      sessionRestartRequired: j.sessionRestartRequired,
      result: _asMap(j.result),
    );
  }

  /// Catches an entry up with `jobs.get`.
  Future<void> _refresh(String id) async {
    final api.Job job;
    try {
      job = (await _conn.systemJobsGet(api.SystemJobsGetParams(jobId: id))).job;
    } on api.ApiException catch (e) {
      if (e.code == api.ApiErrorCode.notFound) _jobs.remove(id);
      return;
    } catch (_) {
      return;
    }
    final e = _jobs[id];
    if (e == null) {
      final fresh = _entry(id, kind: _jobKind(job.kind));
      fresh.refreshed = true;
      _set(fresh, _fromJob(job, null));
      return;
    }
    e.refreshed = true;
    if (e.snap.finished) return;
    final s = _fromJob(job, e.snap);
    if (s.finished || s.stage != e.snap.stage) _set(e, s);
  }

  /// After a reconnect: events may have been missed, so look at every job
  /// that was still running.
  Future<void> _resync() async {
    for (final id in [
      for (final e in _jobs.entries)
        if (!e.value.snap.finished) e.key,
    ]) {
      await _refresh(id);
    }
  }

  @override
  Stream<JobSnapshot> watch(String jobId) {
    StreamSubscription<JobSnapshot>? sub;
    var closed = false;
    late final StreamController<JobSnapshot> c;

    void close() {
      if (closed) return;
      closed = true;
      sub?.cancel();
      c.close();
    }

    void follow(_Entry e) {
      if (closed) return;
      c.add(e.snap);
      if (e.snap.finished) return close();
      sub = e.changes.stream.listen((s) {
        c.add(s);
        if (s.finished) close();
      });
      if (!e.refreshed) unawaited(_refresh(jobId));
    }

    c = StreamController<JobSnapshot>(
      onListen: () {
        final known = _jobs[jobId];
        if (known != null) return follow(known);
        _refresh(jobId).then((_) {
          if (closed) return;
          final e = _jobs[jobId];
          if (e == null) {
            c.addError(
              const SystemException(SystemErrorKind.notFound, 'No such job.'),
            );
            close();
          } else {
            follow(e);
          }
        });
      },
      // Not returned: a cancel future would delay whoever cancels (and, in
      // widget tests, complete outside the fake-async zone).
      onCancel: () {
        closed = true;
        unawaited(sub?.cancel());
      },
    );
    return c.stream;
  }

  @override
  Future<void> cancel(String jobId) => guardCall(
    () => _conn.systemJobsCancel(api.SystemJobsCancelParams(jobId: jobId)),
  ).then((_) {});

  /// Waits for the job to finish and returns its final state.
  Future<JobSnapshot> finished(String jobId) =>
      watch(jobId).firstWhere((s) => s.finished);

  Future<void> dispose() async {
    await _events.cancel();
    await _status.cancel();
    for (final e in _jobs.values) {
      unawaited(e.changes.close());
    }
  }
}

// ---------------------------------------------------------------- updates

class DaemonUpdates implements UpdatesRepository {
  DaemonUpdates(this._conn, this._jobs);

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;
  final _changes = StreamController<UpdateStatus>.broadcast();
  UpdateStatus _status = const UpdateStatus(
    currentVersion: 'unknown',
    currentRev: '',
  );

  @override
  UpdateStatus get status => _status;
  @override
  Stream<UpdateStatus> get changes => _changes.stream;

  /// The startup check can come before the socket is up: wait a moment for
  /// the connection rather than report "unavailable" at once.
  Future<void> _connected() async {
    if (_conn.status is api.Connected) return;
    try {
      await _conn.waitConnected(timeout: const Duration(seconds: 5));
    } on TimeoutException {
      throw const api.DaemonUnavailableException();
    }
  }

  @override
  Future<UpdateStatus> check() => guardCall(() async {
    await _connected();
    final r = await _conn.systemUpdateCheck();
    var result = r.result;
    if (result == null) {
      // A new check: a job whose result comes with job_finished.
      final id = r.jobId;
      if (id == null) {
        throw const SystemException(
          SystemErrorKind.failed,
          'The update check gave no answer.',
        );
      }
      _jobs.track(id, JobKind.updateCheck);
      final done = await _jobs.finished(id);
      if (!done.ok) {
        final k = done.error?.kind;
        throw SystemException(
          k ?? SystemErrorKind.failed,
          done.error?.message ?? 'The update check did not finish.',
        );
      }
      final map = done.result;
      if (map == null) {
        throw const SystemException(
          SystemErrorKind.failed,
          'The update check gave no answer.',
        );
      }
      result = api.UpdateCheckResult.fromJson(map);
    }
    final info = await _conn.systemInfo();
    final a = result.available;
    _status = UpdateStatus(
      currentVersion: info.version,
      currentRev: result.currentRev ?? '',
      available: a == null
          ? null
          : AvailableUpdate(
              rev: a.rev,
              version: releaseVersion(a.version) ?? _dateVersion(_unix(a.date)),
              date: _unix(a.date),
              summary: a.summary,
              severity: a.security == null ? null : _severity(a.security!),
              securitySummary: _oneLine(a.securitySummary),
              signer: a.signer,
              newApps: a.newApps == null
                  ? null
                  : [for (final n in a.newApps!) CatalogChange(n.id, n.name)],
              removedApps: a.removedApps == null
                  ? null
                  : [
                      for (final n in a.removedApps!)
                        CatalogChange(n.id, n.name, reason: n.reason),
                    ],
            ),
      checkedAt: _unix(result.checkedAt),
    );
    _changes.add(_status);
    return _status;
  });

  static String _dateVersion(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<JobHandle> apply(String rev) => _jobs.start(
    JobKind.update,
    () async =>
        (await _conn.systemUpdateApply(api.SystemUpdateApplyParams(rev: rev)))
            .jobId,
  );

  @override
  Future<List<Generation>> generations() => guardCall(() async {
    final r = await _conn.systemGenerationsList();
    return [
      for (final g in r.generations)
        Generation(
          generation: g.generation,
          date: _unix(g.date),
          rev: g.rev,
          current: g.current,
          booted: g.booted,
        ),
    ];
  });

  @override
  Future<JobHandle> rollback({int? generation}) => _jobs.start(
    JobKind.rollback,
    () async => (await _conn.systemRollback(
      api.SystemRollbackParams(generation: generation),
    )).jobId,
  );

  @override
  Future<JobHandle> setChannel(
    UpdateChannel channel, {
    bool acknowledgeDowngrade = false,
  }) => _jobs.start(
    JobKind.channel,
    () async => (await _conn.systemChannelSet(
      api.SystemChannelSetParams(
        channel: channel == UpdateChannel.stable
            ? api.Channel.stable
            : api.Channel.beta,
        acknowledgeDowngrade: acknowledgeDowngrade ? true : null,
      ),
    )).jobId,
    nothingToDo: 'This box already follows that channel.',
  );

  @override
  Future<JobHandle> setBase(
    NixBase base, {
    bool acknowledgeDowngrade = false,
  }) => _jobs.start(
    JobKind.base,
    () async => (await _conn.systemBaseSet(
      api.SystemBaseSetParams(
        base: base == NixBase.stable ? api.Base.stable : api.Base.unstable,
        acknowledgeDowngrade: acknowledgeDowngrade ? true : null,
      ),
    )).jobId,
    nothingToDo: 'This box already uses that software base.',
  );
}

// ---------------------------------------------------------------- system

class DaemonSystem implements SystemRepository {
  DaemonSystem(this._conn, this._jobs);

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;

  @override
  Future<SystemInfo> info() => guardCall(() async {
    final i = await _conn.systemInfo();
    return SystemInfo(
      version: i.version,
      channel: _channel(i.channel),
      base: _base(i.base),
      rev: i.rev,
      generation: i.generation,
      hostname: i.hostname,
      dev: i.dev,
      hostKeyFingerprints: i.ssh.hostKeyFingerprints,
    );
  });

  @override
  Future<SshState> ssh() => guardCall(
    () async => SshState(enabled: (await _conn.systemInfo()).ssh.enabled),
  );

  /// `ssh.set`. polkit guards turning it on with `auth_admin`: the call waits
  /// while the session daemon (polkit's authentication agent) sends
  /// `authentication_requested`, which [DaemonAuth] hands to the prompt. This
  /// only ever sees the answer: a job id, `authentication_required` (the
  /// prompt was cancelled or timed out) or `permission_denied` (wrong
  /// passwords).
  @override
  Future<JobHandle> setSsh(bool enable) => _jobs.start(
    JobKind.ssh,
    () async =>
        (await _conn.systemSshSet(api.SystemSshSetParams(enabled: enable)))
            .jobId,
    nothingToDo: enable ? 'SSH is already on.' : 'SSH is already off.',
  );

  /// `settings.get`, then `settings.set` with the `revision` it returned; one
  /// retry on a stale revision. [changes] is empty in API 0.6 (the closed
  /// schema has no fields yet), so this is a re-apply of the current
  /// settings; null when there was nothing to do.
  @override
  Future<JobHandle?> applySettings() async {
    for (var attempt = 0; ; attempt++) {
      try {
        final got = await _conn.systemSettingsGet();
        final id = (await _conn.systemSettingsSet(
          api.SystemSettingsSetParams(
            revision: got.revision,
            changes: const api.SystemSettingsSetParamsChanges(),
          ),
        )).jobId;
        if (id == null) return null;
        _jobs.track(id, JobKind.rebuild);
        return JobHandle(id, JobKind.rebuild);
      } catch (e) {
        final err = systemExceptionFrom(e);
        if (err.kind == SystemErrorKind.stateConflict && attempt == 0) continue;
        throw err;
      }
    }
  }

  @override
  Future<void> power(PowerAction action) => guardCall(() async {
    switch (action) {
      case PowerAction.sleep:
        await _conn.powerSuspend();
      case PowerAction.restart:
        await _conn.powerReboot();
      case PowerAction.shutdown:
        await _conn.powerPoweroff();
    }
  });

  @override
  Future<Set<PowerAction>> powerAllowed() => guardCall(() async {
    final c = await _conn.powerCapabilities();
    bool ok(api.PowerCapability p) => p == api.PowerCapability.yes;
    return {
      if (ok(c.suspend)) PowerAction.sleep,
      if (ok(c.reboot)) PowerAction.restart,
      if (ok(c.poweroff)) PowerAction.shutdown,
    };
  });

  /// `session.restart`: the daemon answers and then ends the session, so the
  /// connection may drop before (or just after) the answer is read; that is
  /// the restart working.
  @override
  Future<void> restartSession() async {
    final wasConnected = _conn.status is api.Connected;
    try {
      await _conn.sessionRestart();
    } on api.DaemonUnavailableException {
      if (!wasConnected) {
        throw systemExceptionFrom(const api.DaemonUnavailableException());
      }
    } on api.ApiException catch (e) {
      final data = e.data is Map ? (e.data! as Map) : const {};
      if (e.code == api.ApiErrorCode.unavailable &&
          data['service'] == 'logind' &&
          data['reason'] == 'not_greetd') {
        throw const SystemException(
          SystemErrorKind.unavailable,
          'This is not a TV session, so it cannot be restarted from here.',
          data: {'reason': 'not_greetd'},
        );
      }
      throw systemExceptionFrom(e);
    }
  }
}

// ---------------------------------------------------------------- wiring

/// The services over a daemon connection (session API 0.8): system info, SSH,
/// updates, jobs, power, Wi-Fi, Bluetooth, display, audio, the admin password
/// prompt, session restart and the Store.
SystemServices daemonSystemServices(api.DaemonConnection connection) {
  final jobs = DaemonJobs(connection);
  return SystemServices(
    jobs: jobs,
    system: DaemonSystem(connection, jobs),
    updates: DaemonUpdates(connection, jobs),
    network: DaemonNetwork(connection),
    bluetooth: DaemonBluetooth(connection),
    displayAudio: DaemonDisplayAudio(connection),
    store: DaemonStore(connection, jobs),
    auth: DaemonAuth(connection),
  );
}
