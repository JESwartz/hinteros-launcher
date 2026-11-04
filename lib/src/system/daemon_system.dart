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
import 'daemon_controller.dart';
import 'daemon_errors.dart';
import 'daemon_profiles.dart';
import 'daemon_runtime.dart';
import 'daemon_server.dart';
import 'daemon_storage.dart';
import 'daemon_store.dart';
import 'daemon_time_zone.dart';
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
  api.JobKind.appsRollback => JobKind.appsRollback,
  api.JobKind.profilesCreate => JobKind.profileCreate,
  api.JobKind.profilesRemove => JobKind.profileRemove,
  api.JobKind.guestSet => JobKind.guest,
  api.JobKind.starterSet => JobKind.starterSet,
  api.JobKind.guestEnd => JobKind.guestEnd,
  api.JobKind.storageMeasure => JobKind.storageMeasure,
  api.JobKind.cleanupSystem => JobKind.cleanupSystem,
  api.JobKind.cleanupProfiles => JobKind.cleanupProfiles,
  api.JobKind.cleanupSet => JobKind.cleanupSet,
  api.JobKind.channelCheck => JobKind.channelCheck,
  api.JobKind.servicesEnable => JobKind.servicesEnable,
  api.JobKind.servicesDisable => JobKind.servicesDisable,
  api.JobKind.jellyfinLibraryAdd => JobKind.libraryAdd,
  api.JobKind.jellyfinLibraryRemove => JobKind.libraryRemove,
  api.JobKind.plexClaim => JobKind.plexClaim,
  api.JobKind.tailscaleLogin => JobKind.tailscaleLogin,
  api.JobKind.tailscaleLogout => JobKind.tailscaleLogout,
  api.JobKind.cloudflareSetToken => JobKind.cloudflareSetToken,
  api.JobKind.cloudflareClearToken => JobKind.cloudflareClearToken,
  api.JobKind.appsClearData => JobKind.clearData,
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
  api.Stage.box => JobStage.box,
  api.Stage.apps => JobStage.apps,
  api.Stage.measuring => JobStage.measuring,
  api.Stage.cleaning => JobStage.cleaning,
  api.Stage.collecting => JobStage.collecting,
  api.Stage.configuring => JobStage.configuring,
  api.Stage.signingIn => JobStage.signingIn,
  api.Stage.unknown || null => null,
};

UpdateChannel? _channel(api.Channel? c) => switch (c) {
  api.Channel.beta => UpdateChannel.beta,
  api.Channel.stable => UpdateChannel.stable,
  // A channel of a newer daemon: none this launcher can show.
  api.Channel.unknown || null => null,
};

/// A base of a newer daemon is null.
NixBase? _base(api.Base b) => switch (b) {
  api.Base.stable => NixBase.stable,
  api.Base.unstable => NixBase.unstable,
  api.Base.unknown => null,
};

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

/// How a release is named on screen. `release/version` is the release's own
/// version (promote writes it into every beta and stable release); a beta
/// adds its commit: `0.7.2.1a2b3c4 beta`, `0.7.2 stable`. Anything else (no
/// channel, the date fallback, no revision) is shown as it is.
String releaseName(String version, String? rev, UpdateChannel? channel) {
  if (releaseVersion(version) == null) return version;
  return switch (channel) {
    UpdateChannel.beta when rev != null && _hexRev.hasMatch(rev) =>
      '$version.${rev.substring(0, 7)} beta',
    UpdateChannel.stable => '$version stable',
    _ => version,
  };
}

final _hexRev = RegExp(r'^[0-9a-f]{7,}$');

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

/// `subject` (0.15): what a job is about.
JobSubject _subject(api.JobSubject? s) {
  if (s == null) return const JobSubject();
  return JobSubject(
    owner: s.owner,
    profileId: s.profile?.id,
    profileName: _oneLine(s.profile?.name),
    apps: [
      for (final a in s.apps ?? const <api.CatalogApp>[])
        (id: a.id, name: _oneLine(a.name) ?? a.id),
    ],
    deleteData: s.deleteData ?? false,
    fromOwner: s.fromOwner,
    generation: s.generation,
    fromGeneration: s.fromGeneration,
    rev: s.rev,
    // Named the way the update screens name releases.
    version: s.version == null
        ? null
        : releaseName(s.version!, s.rev, _channel(s.channel)),
    channel: _channel(s.channel),
    fromChannel: _channel(s.fromChannel),
    fromRev: s.fromRev,
    fromVersion: s.fromVersion == null
        ? null
        : releaseName(
            s.fromVersion!,
            s.fromRev,
            _channel(s.fromChannel ?? s.channel),
          ),
    base: s.base == null ? null : _base(s.base!),
    fromBase: s.fromBase == null ? null : _base(s.fromBase!),
    enabled: s.enabled,
    keep: s.keep,
    frequency: switch (s.frequency) {
      api.CleanupFrequency.daily => CleanupFrequency.daily,
      api.CleanupFrequency.weekly => CleanupFrequency.weekly,
      api.CleanupFrequency.monthly => CleanupFrequency.monthly,
      _ => null,
    },
    keepSystem: s.keepSystem,
    keepProfiles: s.keepProfiles,
    services: [
      for (final a in s.services ?? const <api.CatalogApp>[])
        (id: a.id, name: _oneLine(a.name) ?? a.id),
    ],
    library: _oneLine(s.library?.name),
  );
}

/// `detail.builds_*` and `building` (0.15); null when nix builds nothing.
BuildProgress? _build(api.ProgressDetail? d) {
  if (d == null) return null;
  final b = d.building;
  if (d.buildsTotal == null && d.buildsDone == null && b == null) return null;
  return BuildProgress(
    done: d.buildsDone,
    total: d.buildsTotal,
    running: d.buildsRunning,
    name: _oneLine(b?.name),
    version: _oneLine(b?.version),
    phase: _oneLine(b?.phase),
    percent: b?.percent?.clamp(0, 99),
  );
}

/// `detail.auth_url` (0.19): where a Tailscale sign-in waits. Only an https
/// address of printable ASCII is shown (the schema's rule).
String? _authUrl(api.ProgressDetail? d) {
  final u = d?.authUrl;
  if (u == null || u.length > 512) return null;
  return RegExp(r'^https://[!-~]+$').hasMatch(u) ? u : null;
}

DateTime? _unixOrNull(int? seconds) => seconds == null ? null : _unix(seconds);

/// `update_verification_failed {reason: older_than_seen}` (session API 0.17):
/// the server offers an older version than one this box already verified.
const olderThanSeen =
    'This version is older than one this box already saw. Try again later.';

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
  // The daemon's message is for the log (the job_finished handler logs it):
  // the screen gets a short line of its own.
  return JobError(
    message: switch (kind) {
      SystemErrorKind.updateUnreachable =>
        "Can't reach the update server right now. Try again later.",
      SystemErrorKind.updateVerificationFailed
          when data['reason'] == 'older_than_seen' =>
        olderThanSeen,
      SystemErrorKind.updateVerificationFailed =>
        'The update failed its safety check.',
      SystemErrorKind.needsAcknowledgement => 'This is a downgrade.',
      SystemErrorKind.insufficientResources =>
        data['kind'] == 'disk'
            ? 'Not enough free disk space.'
            : 'Not enough free memory.',
      // 0.19: why a job of the Server section failed.
      _ when serverFailureText(data['reason']) != null => serverFailureText(
        data['reason'],
      )!,
      _ => stage == null ? 'Job failed' : 'Job failed while ${_verb(stage)}',
    },
    stage: stage,
    logHint: data['log_hint'] as String?,
    kind: kind,
  );
}

/// The error's `log_hint`, for the log line of a failed job.
String _hint(api.ErrorObject? e) {
  final d = e?.data;
  final h = d is Map ? d['log_hint'] : null;
  return h is String && h.isNotEmpty ? ' (log hint: $h)' : '';
}

/// The stage in "Job failed while ...".
String _verb(JobStage s) => switch (s) {
  JobStage.preparing => 'preparing',
  JobStage.fetching => 'fetching',
  JobStage.verifying => 'verifying',
  JobStage.box => 'preparing the box',
  JobStage.evaluating => 'evaluating',
  JobStage.downloading => 'downloading',
  JobStage.building => 'building',
  JobStage.activating => 'switching over',
  JobStage.apps => 'updating the apps',
  JobStage.measuring => 'scanning',
  JobStage.cleaning => 'removing old versions',
  JobStage.collecting => 'deleting unused files',
  JobStage.configuring => 'setting up',
  JobStage.signingIn => 'waiting for the sign-in',
  JobStage.finishing => 'finishing',
};

/// A job that ended because of `jobs.cancel` (state `cancelled`, or
/// `job_finished` with `job_failed` and the message "cancelled").
bool _isCancel(api.ErrorObject? e) =>
    e != null &&
    e.code == api.ApiErrorCode.jobFailed &&
    e.message == 'cancelled';

Map<String, dynamic>? _asMap(Object? o) =>
    o is Map ? o.cast<String, dynamic>() : null;

/// [map] as a job result; null when there is none or when it is unreadable
/// (a newer daemon).
T? _readResult<T>(
  Map<String, dynamic>? map,
  T Function(Map<String, dynamic>) read,
) {
  if (map == null) return null;
  try {
    return read(map);
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  }
}

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
  DaemonJobs(this._conn, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
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
  final DateTime Function() _clock;
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
    String nothingToDo = 'Nothing to change.',
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
        e.kindKnown = true;
        _set(
          e,
          e.snap.copyWith(
            kind: _jobKind(ev.kind),
            subject: _subject(ev.subject),
            startedAt: _unix(ev.startedAt),
            heardAt: now(),
          ),
        );
      case api.JobProgressEvent():
        final e = _entry(ev.jobId, kind: _jobKind(ev.kind));
        if (e.snap.finished) return;
        final stage = _stage(ev.stage) ?? e.snap.stage;
        final known = e.kindKnown;
        e.kindKnown = true;
        // Also a heartbeat (at least every 2 s, maybe with nothing new):
        // it says the job is alive.
        _set(
          e,
          e.snap.copyWith(
            kind: known ? null : _jobKind(ev.kind),
            stage: stage,
            percent: ev.percent,
            clearPercent: ev.percent == null,
            detail: _progressText(ev.detail),
            clearDetail: _progressText(ev.detail) == null,
            build: _build(ev.detail),
            clearBuild: _build(ev.detail) == null,
            // A heartbeat may leave the address out: kept while it waits.
            authUrl: _authUrl(ev.detail),
            clearAuthUrl: stage != JobStage.signingIn,
            subject: ev.subject == null ? null : _subject(ev.subject),
            startedAt: _unix(ev.startedAt),
            lastActivityAt: _unixOrNull(ev.lastActivityAt),
            heardAt: now(),
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
            '${err == null ? '' : ": ${err.code} ${err.message}"}'
            '${_hint(err)}',
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
            subject: _subject(ev.subject),
            startedAt: _unix(ev.startedAt),
            finishedAt: _unix(ev.finishedAt),
            heardAt: now(),
            clearPercent: true,
            clearBuild: true,
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
      percent: finished ? null : j.percent,
      detail: finished ? null : _progressText(j.detail),
      build: finished ? null : _build(j.detail),
      authUrl: finished ? null : _authUrl(j.detail),
      finished: finished,
      ok: j.state == api.JobState.succeeded,
      cancelled: cancelled,
      error: finished && !cancelled && j.error != null
          ? _jobError(j.error!)
          : null,
      sessionRestartRequired: j.sessionRestartRequired,
      result: _asMap(j.result),
      subject: _subject(j.subject),
      startedAt: _unix(j.startedAt),
      finishedAt: _unixOrNull(j.finishedAt),
      lastActivityAt: _unixOrNull(j.lastActivityAt),
      heardAt: now(),
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
    _set(e, _fromJob(job, e.snap));
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

  @override
  DateTime now() => _clock();

  @override
  Future<JobSnapshot?> running() async {
    final api.SystemJobsListResult r;
    try {
      r = await _conn.systemJobsList();
    } catch (_) {
      return null;
    }
    // The running job, if any, comes first.
    final j = r.jobs.where((j) => j.state == api.JobState.running).firstOrNull;
    if (j == null) return null;
    final e = _entry(j.jobId, kind: _jobKind(j.kind));
    e.refreshed = true;
    if (!e.snap.finished) _set(e, _fromJob(j, e.snap));
    return e.snap;
  }

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
          'The update check gave no result.',
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
      result = _readResult(done.result, api.UpdateCheckResult.fromJson);
      if (result == null) {
        throw const SystemException(
          SystemErrorKind.failed,
          'The update check gave no result.',
        );
      }
    }
    final info = await _conn.systemInfo();
    final channel = _channel(info.channel);
    final a = result.available;
    _status = UpdateStatus(
      currentVersion: releaseName(info.version, info.rev, channel),
      currentRev: result.currentRev ?? '',
      available: a == null
          ? null
          : AvailableUpdate(
              rev: a.rev,
              version: releaseVersion(a.version) == null
                  ? _dateVersion(_unix(a.date))
                  : releaseName(a.version!, a.rev, channel),
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
  Future<JobHandle> apply(String rev, {String? adminPin}) => _jobs.start(
    JobKind.update,
    () async => (await _conn.systemUpdateApply(
      api.SystemUpdateApplyParams(rev: rev, adminPin: adminPin),
    )).jobId,
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
          profiles: g.profiles == null
              ? null
              : [for (final p in g.profiles!) (id: p.id, name: p.name)],
          readdsFeatures: [
            for (final f in g.readdsFeatures ?? const <api.BoxFeature>[])
              f.toJson(),
          ],
        ),
    ];
  });

  @override
  Future<JobHandle> rollback({int? generation, String? adminPin}) =>
      _jobs.start(
        JobKind.rollback,
        () async => (await _conn.systemRollback(
          api.SystemRollbackParams(generation: generation, adminPin: adminPin),
        )).jobId,
      );

  static api.Channel _apiChannel(UpdateChannel c) =>
      c == UpdateChannel.stable ? api.Channel.stable : api.Channel.beta;

  @override
  Future<ChannelTarget> checkChannel(UpdateChannel channel) =>
      guardCall(() async {
        await _connected();
        final h = await _jobs.start(
          JobKind.channelCheck,
          () async => (await _conn.systemChannelCheck(
            api.SystemChannelCheckParams(channel: _apiChannel(channel)),
          )).jobId,
          nothingToDo: 'This box already uses that channel.',
        );
        final done = await _jobs.finished(h.jobId);
        if (!done.ok) {
          throw SystemException(
            done.error?.kind ?? SystemErrorKind.failed,
            done.error?.message ?? 'The check did not finish.',
          );
        }
        final r = _readResult(done.result, api.ChannelCheckResult.fromJson);
        if (r == null) {
          throw const SystemException(
            SystemErrorKind.failed,
            'The check gave no result.',
          );
        }
        final t = r.target;
        return ChannelTarget(
          channel: channel,
          rev: t.rev,
          version: releaseVersion(t.version) == null
              ? _dateVersion(_unix(t.date))
              : releaseName(t.version!, t.rev, channel),
          date: _unix(t.date),
          older: r.older,
        );
      });

  @override
  Future<JobHandle> setChannel(
    UpdateChannel channel, {
    required String rev,
    String? adminPin,
  }) => _jobs.start(
    JobKind.channel,
    () async => (await _conn.systemChannelSet(
      api.SystemChannelSetParams(
        channel: _apiChannel(channel),
        rev: rev,
        adminPin: adminPin,
      ),
    )).jobId,
    nothingToDo: 'This box already uses that channel.',
  );

  @override
  Future<JobHandle> setBase(
    NixBase base, {
    bool acknowledgeDowngrade = false,
    String? adminPin,
  }) => _jobs.start(
    JobKind.base,
    () async => (await _conn.systemBaseSet(
      api.SystemBaseSetParams(
        base: base == NixBase.stable ? api.Base.stable : api.Base.unstable,
        acknowledgeDowngrade: acknowledgeDowngrade ? true : null,
        adminPin: adminPin,
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
    final channel = _channel(i.channel);
    return SystemInfo(
      version: releaseName(i.version, i.rev, channel),
      channel: channel,
      // A base of a newer daemon: unstable, the only one 1.0 builds.
      base: _base(i.base) ?? NixBase.unstable,
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

  @override
  Future<JobHandle> redetectHardware({String? adminPin}) => _jobs.start(
    JobKind.hardwareRedetect,
    () async => (await _conn.systemHardwareRedetect(
      api.SystemHardwareRedetectParams(adminPin: adminPin),
    )).jobId,
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
        logFailure('settings.set', e);
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

  @override
  Future<AppDisplaySetting> appDisplays() => guardCall(() async {
    final r = await _conn.appsDisplaysGet();
    return AppDisplaySetting(
      count: r.count,
      active: r.active,
      min: r.min,
      max: r.max,
    );
  });

  @override
  Future<AppDisplaySetting> setAppDisplays(int count) => guardCall(() async {
    final r = await _conn.appsDisplaysSet(
      api.AppsDisplaysSetParams(count: count),
    );
    return AppDisplaySetting(
      count: r.count,
      active: r.active,
      min: r.min,
      max: r.max,
    );
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
          'This is not a TV session.',
          data: {'reason': 'not_greetd'},
        );
      }
      logFailure('session.restart', e);
      throw systemExceptionFrom(e);
    }
  }
}

// ---------------------------------------------------------------- wiring

/// The services over a daemon connection (session API 0.8): system info, SSH,
/// updates, jobs, power, Wi-Fi, Bluetooth, display, audio, the admin password
/// prompt, session restart and the Store.
/// [now]: the box clock (tests give the mock daemon's).
SystemServices daemonSystemServices(
  api.DaemonConnection connection, {
  DateTime Function()? now,
}) {
  final jobs = DaemonJobs(connection, clock: now);
  return SystemServices(
    jobs: jobs,
    system: DaemonSystem(connection, jobs),
    updates: DaemonUpdates(connection, jobs),
    network: DaemonNetwork(connection),
    bluetooth: DaemonBluetooth(connection),
    displayAudio: DaemonDisplayAudio(connection),
    store: DaemonStore(connection, jobs),
    auth: DaemonAuth(connection),
    profiles: DaemonProfiles(connection, jobs),
    storage: DaemonStorage(connection, jobs),
    timeZone: DaemonTimeZone(connection),
    server: DaemonServer(connection, jobs),
    controller: DaemonController(connection),
  );
}
