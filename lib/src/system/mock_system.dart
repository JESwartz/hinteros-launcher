/// In-process fakes of every system repository, in the spirit of `MockDaemon`:
/// they behave like the real service would (validation, errors, jobs with
/// stages) and are driven from tests or `--mock`. Everything here is
/// placeholder data: no real logos, no real vendor texts.
/// The real ones are in `daemon_system.dart` (TODO(0.7): Network, Bluetooth,
/// DisplayAudio, power).
library;

import 'dart:async';

import '../api/mock_store.dart' show mockCatalogDir;
import '../platform/local_files.dart';
import 'catalog.dart';
import 'mock_controller.dart';
import 'mock_profiles.dart';
import 'mock_server.dart';
import 'mock_storage.dart';
import 'mock_time_zone.dart';
import 'models.dart';
import 'repositories.dart';

export 'mock_profiles.dart';
export 'mock_server.dart';
export 'mock_storage.dart';
export 'mock_time_zone.dart';

String _hex(int n, int len) => n.toRadixString(16).padLeft(len, '0');

// ---------------------------------------------------------------- jobs

class _Job {
  _Job(this.snap);

  JobSnapshot snap;
  final changes = StreamController<JobSnapshot>.broadcast(sync: true);
  void Function()? onSuccess;
  void Function()? onFinish;

  /// `job_finished.result` when it finishes well.
  Map<String, dynamic>? result;
  Timer? timer;
  Timer? beat;

  /// A Tailscale sign-in: the address its signing_in stage reports.
  String? authUrl;
}

/// What a scripted build builds (`--mock`): name, version. Nix finds the
/// last three late (the total grows), as it can.
const mockBuildScript = <(String, String?)>[
  ('hinteros-daemon', '0.7.1'),
  ('hinteros-launcher', '0.7.1'),
  ('hinteros-system', '0.7.1'),
  ('moonlight-qt', '6.1.0'),
  ('mesa', '25.2.3'),
  ('linux-firmware', '20260910'),
  ('gamescope', '3.16.4'),
  ('system-units', null),
  ('etc', null),
  ('hinteros-session', '0.7.1'),
  ('dbus-1', null),
  ('nixos-system-hinteros', '0.7.1'),
];

/// Nix's phases, in order, as a scripted build goes through them.
const _phases = ['unpack', 'configure', 'build', 'install'];

/// What the daemon gives for [_phases] (the build's own percent).
const _phasePercents = [0, 10, 20, 88];

/// Jobs the way the privileged service reports them: one mutating job at a
/// time, stages, progress, cancel until activation.
class MockJobs implements JobsRepository {
  MockJobs({
    this.stepDelay = const Duration(milliseconds: 700),
    this.autoRun,
    DateTime Function()? now,
  }) : clock = now ?? DateTime.now;

  /// Time between stages when a job runs by itself.
  Duration stepDelay;

  /// Jobs run through their stages on their own (`--mock`, the dev window):
  /// a long build of twelve, with names, phases and heartbeats. Tests leave
  /// this off and drive jobs with [progress], [heartbeat] and [finish].
  bool? autoRun;

  /// The box clock (tests move it on).
  DateTime Function() clock;

  final _jobs = <String, _Job>{};
  int _n = 0;

  /// Makes the next started job fail at [failStage] with [failWith].
  JobError? failNextWith;
  JobStage? failNextAt;

  /// The next job asks for a session restart when it finishes.
  bool restartNext = false;

  /// Every job started, in order.
  final List<JobHandle> started = [];

  JobSnapshot? snapshot(String jobId) => _jobs[jobId]?.snap;

  /// The running job, if any.
  JobHandle? get runningJob {
    for (final j in _jobs.values) {
      if (j.snap.running) return JobHandle(j.snap.jobId, j.snap.kind);
    }
    return null;
  }

  @override
  DateTime now() => clock();

  @override
  Future<JobSnapshot?> running() async {
    final r = runningJob;
    return r == null ? null : _jobs[r.jobId]!.snap;
  }

  /// Starts a job. [onSuccess] is the side effect on the mock's state when it
  /// finishes well; [subject] says what it is about.
  JobHandle start(
    JobKind kind, {
    void Function()? onSuccess,
    void Function()? onFinish,
    Map<String, dynamic>? result,
    JobSubject subject = const JobSubject(),
    String? authUrl,
  }) {
    final r = runningJob;
    if (r != null) {
      throw SystemException(
        SystemErrorKind.jobBusy,
        'Another change is still running.',
        data: {'job_id': r.jobId},
      );
    }
    final id = _hex(++_n * 7919 + 0xabc0de, 16);
    final at = clock();
    final job =
        _Job(
            JobSnapshot(
              jobId: id,
              kind: kind,
              subject: subject,
              startedAt: at,
              heardAt: at,
            ),
          )
          ..onSuccess = onSuccess
          ..onFinish = onFinish
          ..result = result
          ..authUrl = authUrl;
    _jobs[id] = job;
    final h = JobHandle(id, kind);
    started.add(h);
    final failAt = failNextAt;
    final failWith = failNextWith;
    final restart = restartNext;
    failNextWith = null;
    failNextAt = null;
    restartNext = false;
    if (autoRun ?? false) {
      _run(job, failAt: failWith == null ? null : failAt, failWith: failWith);
    } else if (failWith != null) {
      // Manual mode: the failure is delivered by finish() in the test; keep
      // it for them.
      job.snap = job.snap.copyWith(stage: failAt ?? job.snap.stage);
    }
    if (restart) job.snap = job.snap.copyWith(sessionRestartRequired: true);
    return h;
  }

  void _run(_Job job, {JobStage? failAt, JobError? failWith}) {
    final stages = job.snap.kind.stages;
    var i = 0;
    var pct = 0;
    var built = 0;
    var phase = 0;
    var waited = 0;
    // The heartbeat: every 2 s, also when nothing changed.
    job.beat = Timer.periodic(
      const Duration(seconds: 2),
      (_) => heartbeat(job.snap.jobId),
    );
    void step() {
      if (job.snap.finished) return;
      final s = stages[i];
      if (failWith != null && s == (failAt ?? stages.last)) {
        finish(job.snap.jobId, ok: false, error: failWith);
        return;
      }
      if (s == JobStage.downloading || s == JobStage.measuring) {
        progress(
          job.snap.jobId,
          s,
          percent: pct,
          detail: s == JobStage.downloading ? '${pct * 3} MB of 300 MB' : null,
        );
        pct += 25;
        if (pct <= 100) {
          job.timer = Timer(stepDelay, step);
          return;
        }
      } else if (s == JobStage.signingIn && waited < 8) {
        // The person scans the code and signs in, after a while.
        progress(job.snap.jobId, s, authUrl: job.authUrl);
        waited++;
        job.timer = Timer(stepDelay, step);
        return;
      } else if (s == JobStage.building && built < mockBuildScript.length) {
        // Nix knows of nine at first and finds three more half way.
        final total = built < 5 ? 9 : mockBuildScript.length;
        final (name, version) = mockBuildScript[built];
        progress(
          job.snap.jobId,
          s,
          percent: built * 100 ~/ total,
          build: BuildProgress(
            done: built,
            total: total,
            running: 1,
            name: name,
            version: version,
            phase: _phases[phase],
            percent: _phasePercents[phase],
          ),
        );
        if (++phase == _phases.length) {
          phase = 0;
          built++;
        }
        job.timer = Timer(stepDelay, step);
        return;
      } else {
        progress(job.snap.jobId, s);
      }
      i++;
      if (i >= stages.length) {
        job.timer = Timer(stepDelay, () => finish(job.snap.jobId, ok: true));
      } else {
        job.timer = Timer(stepDelay, step);
      }
    }

    job.timer = Timer(stepDelay, step);
  }

  void progress(
    String jobId,
    JobStage stage, {
    int? percent,
    String? detail,
    BuildProgress? build,
    String? authUrl,
  }) {
    final j = _jobs[jobId]!;
    final at = clock();
    j.snap = j.snap.copyWith(
      authUrl: authUrl,
      clearAuthUrl: authUrl == null,
      stage: stage,
      percent: percent,
      clearPercent: percent == null,
      detail: detail,
      clearDetail: detail == null,
      build: build,
      clearBuild: build == null,
      lastActivityAt: at,
      heardAt: at,
    );
    j.changes.add(j.snap);
  }

  /// A heartbeat (`job_progress` with nothing new): the job is alive.
  void heartbeat(String jobId) {
    final j = _jobs[jobId]!;
    if (j.snap.finished) return;
    j.snap = j.snap.copyWith(heardAt: clock());
    j.changes.add(j.snap);
  }

  /// Ends the job (`job_finished`).
  void finish(
    String jobId, {
    bool ok = true,
    JobError? error,
    bool cancelled = false,
    bool? sessionRestartRequired,
  }) {
    final j = _jobs[jobId]!;
    if (j.snap.finished) return;
    j.timer?.cancel();
    j.beat?.cancel();
    final at = clock();
    j.snap = j.snap.copyWith(
      finished: true,
      ok: ok,
      cancelled: cancelled,
      error: error,
      result: ok ? j.result : null,
      sessionRestartRequired:
          sessionRestartRequired ??
          (ok &&
              j.snap.kind.mayRestartSession &&
              j.snap.sessionRestartRequired),
      clearPercent: true,
      clearBuild: true,
      finishedAt: at,
      heardAt: at,
    );
    if (ok) j.onSuccess?.call();
    j.onFinish?.call();
    j.changes.add(j.snap);
  }

  @override
  Stream<JobSnapshot> watch(String jobId) {
    final j = _jobs[jobId];
    if (j == null) {
      return Stream.error(
        const SystemException(SystemErrorKind.notFound, 'No such job.'),
      );
    }
    return Stream.multi((c) {
      c.add(j.snap);
      if (j.snap.finished) {
        c.close();
        return;
      }
      final sub = j.changes.stream.listen((s) {
        c.add(s);
        if (s.finished) c.close();
      }, onDone: c.close);
      c.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> cancel(String jobId) async {
    final j = _jobs[jobId];
    if (j == null) {
      throw const SystemException(SystemErrorKind.notFound, 'No such job.');
    }
    if (!j.snap.canCancel) {
      throw SystemException(
        SystemErrorKind.jobBusy,
        'Too late to cancel.',
        data: {'job_id': jobId},
      );
    }
    finish(jobId, ok: false, cancelled: true);
  }

  void dispose() {
    for (final j in _jobs.values) {
      j.timer?.cancel();
      j.beat?.cancel();
    }
  }
}

// ---------------------------------------------------------------- updates

class MockUpdates implements UpdatesRepository {
  MockUpdates(
    this.jobs, {
    UpdateStatus? status,
    this.channel = UpdateChannel.beta,
    this.base = NixBase.unstable,
    DateTime Function()? now,
    this.box,
    List<Generation>? generations,
  }) : _now = now ?? DateTime.now,
       _status = status ?? mockUpToDate() {
    _generations = [
      for (var g = 12; g >= 9; g--)
        Generation(
          generation: g,
          date: DateTime(2026, 9, g + 6, 9),
          rev: _hex(g * 0x1234567, 40),
          current: g == 12,
          booted: g == 12,
          // The accounts each generation has (M7): Sam since 12, Alex
          // (removed since) in 11, before profiles nothing known.
          profiles: switch (g) {
            12 => const [(id: 'p1', name: 'James'), (id: 'p3', name: 'Sam')],
            11 => const [(id: 'p1', name: 'James'), (id: 'p2', name: 'Alex')],
            10 => const [(id: 'p1', name: 'James')],
            _ => null,
          },
          // Steam came after 10: a rollback to it turns 32-bit graphics
          // back on (0.13).
          readdsFeatures: g == 10
              ? const ['graphics32', 'steam-devices']
              : const [],
        ),
    ];
    if (generations != null) _generations = generations;
  }

  final MockJobs jobs;

  /// The profiles whose admin PIN the box-wide actions need (update,
  /// rollback, channel, base, hardware). Null: none needed.
  MockProfileBox? box;
  final DateTime Function() _now;
  UpdateChannel channel;
  NixBase base;

  /// The bases that are built: [setBase] to another one is refused.
  final builtBases = {NixBase.unstable};
  UpdateStatus _status;
  late List<Generation> _generations;
  final _changes = StreamController<UpdateStatus>.broadcast();

  /// What the next `check()` finds.
  AvailableUpdate? nextAvailable;

  /// The next `check()` throws this.
  SystemException? failCheckWith;

  /// Number of checks done.
  int checks = 0;

  @override
  UpdateStatus get status => _status;
  @override
  Stream<UpdateStatus> get changes => _changes.stream;

  /// Test hook: set the status as if a check had found it.
  void setStatus(UpdateStatus s) {
    _status = s;
    _changes.add(s);
  }

  @override
  Future<UpdateStatus> check() async {
    checks++;
    final f = failCheckWith;
    if (f != null) throw f;
    setStatus(
      UpdateStatus(
        currentVersion: _status.currentVersion,
        currentRev: _status.currentRev,
        available: nextAvailable ?? _status.available,
        checkedAt: _now(),
      ),
    );
    return _status;
  }

  @override
  Future<JobHandle> apply(String rev, {String? adminPin}) async {
    box?.checkBoxAdmin(adminPin);
    final a = _status.available;
    if (a == null || a.rev != rev) {
      throw const SystemException(
        SystemErrorKind.stateConflict,
        'That is not the update that was checked.',
      );
    }
    return jobs.start(
      JobKind.update,
      subject: JobSubject(
        rev: a.rev,
        version: a.version,
        channel: channel,
        fromRev: _status.currentRev,
        fromVersion: _status.currentVersion,
      ),
      onSuccess: () {
        _generations = [
          Generation(
            generation: _generations.first.generation + 1,
            date: _now(),
            rev: a.rev,
            current: true,
            booted: false,
          ),
          for (final g in _generations)
            Generation(
              generation: g.generation,
              date: g.date,
              rev: g.rev,
              booted: g.booted,
            ),
        ];
        setStatus(
          UpdateStatus(
            currentVersion: a.version,
            currentRev: a.rev,
            checkedAt: _now(),
          ),
        );
      },
    );
  }

  @override
  Future<List<Generation>> generations() async => _generations;

  @override
  Future<JobHandle> rollback({int? generation, String? adminPin}) async {
    box?.checkBoxAdmin(adminPin);
    final cur = _generations.firstWhere((g) => g.current);
    final target = generation == null
        ? _generations.firstWhere(
            (g) => g.generation < cur.generation,
            orElse: () => cur,
          )
        : _generations.where((g) => g.generation == generation).firstOrNull;
    if (target == null || target.current) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'There is no such earlier version.',
      );
    }
    return jobs.start(
      JobKind.rollback,
      subject: JobSubject(
        generation: target.generation,
        fromGeneration: cur.generation,
      ),
      result: target.readdsFeatures.isEmpty
          ? null
          : {'features_readded': target.readdsFeatures},
      onSuccess: () {
        _generations = [
          for (final g in _generations)
            Generation(
              generation: g.generation,
              date: g.date,
              rev: g.rev,
              current: g.generation == target.generation,
              booted: g.booted,
            ),
        ];
        setStatus(
          UpdateStatus(
            currentVersion: 'rev ${shortRev(target.rev)}',
            currentRev: target.rev ?? '',
            available: _status.available,
            checkedAt: _status.checkedAt,
          ),
        );
      },
    );
  }

  /// The last [checkChannel] result (what [setChannel] accepts).
  ChannelTarget? checkedChannel;

  /// The next [checkChannel] throws this.
  SystemException? failChannelCheckWith;

  @override
  Future<ChannelTarget> checkChannel(UpdateChannel c) async {
    if (c == channel) {
      throw const SystemException(
        SystemErrorKind.nothingToDo,
        'This box already uses that channel.',
      );
    }
    final f = failChannelCheckWith;
    if (f != null) throw f;
    // Stable after beta goes back to an older version.
    return checkedChannel = ChannelTarget(
      channel: c,
      rev: c == UpdateChannel.stable
          ? '7e2d4f6a8b1c3e5d7f9a0b2c4d6e8f1a3b5c7d9e'
          : '1a2b3c4d5e6f708192a3b4c59a8b7c6d5e4f3021',
      version: c == UpdateChannel.stable
          ? '0.6.0 stable'
          : '0.6.1.1a2b3c4 beta',
      date: DateTime(2026, 10, 1),
      older: c == UpdateChannel.stable,
    );
  }

  @override
  Future<JobHandle> setChannel(
    UpdateChannel c, {
    required String rev,
    String? adminPin,
  }) async {
    box?.checkBoxAdmin(adminPin);
    final t = checkedChannel;
    if (c == channel) {
      throw const SystemException(
        SystemErrorKind.nothingToDo,
        'This box already uses that channel.',
      );
    }
    if (t == null || t.channel != c || t.rev != rev) {
      throw const SystemException(
        SystemErrorKind.stateConflict,
        'The channel changed. Try again.',
      );
    }
    return jobs.start(
      JobKind.channel,
      subject: JobSubject(
        channel: c,
        fromChannel: channel,
        rev: rev,
        version: t.version,
      ),
      onSuccess: () => channel = c,
    );
  }

  @override
  Future<JobHandle> setBase(
    NixBase b, {
    bool acknowledgeDowngrade = false,
    String? adminPin,
  }) async {
    box?.checkBoxAdmin(adminPin);
    if (!builtBases.contains(b)) {
      throw const SystemException(
        SystemErrorKind.unavailable,
        "That software base isn't available on this box.",
        data: {'service': 'base', 'reason': 'not_built'},
      );
    }
    if (b == NixBase.stable &&
        base == NixBase.unstable &&
        !acknowledgeDowngrade) {
      throw const SystemException(
        SystemErrorKind.needsAcknowledgement,
        'Switching to the stable base downgrades software.',
      );
    }
    return jobs.start(
      JobKind.base,
      subject: JobSubject(base: b, fromBase: base),
      onSuccess: () => base = b,
    );
  }
}

UpdateStatus mockUpToDate() => const UpdateStatus(
  currentVersion: '0.6.0',
  currentRev: 'a3f9c0de5b1e4c7a9d2f8b6e0c1a3d5f7b9e2c4a',
);

/// An ordinary update (not security).
AvailableUpdate mockOrdinaryUpdate({bool catalogChanged = true}) =>
    AvailableUpdate(
      rev: '5d1c8e3f7a2b4096c1e8d3f5a7b9c0e2d4f6a8b1',
      version: '0.6.1',
      date: DateTime(2026, 10, 5),
      summary: 'New apps in the Store, Wi-Fi reconnect fix.',
      signer: 'release',
      newApps: catalogChanged
          ? const [CatalogChange('mpv', 'Video player')]
          : null,
    );

AvailableUpdate mockSecurityUpdate({
  SecuritySeverity severity = SecuritySeverity.high,
  String? securitySummary =
      'A website could take over the browser in a profile.',
}) => AvailableUpdate(
  rev: '9e4b2a7c1d6f3085b2c9e7a4d1f6b3c8e5a2d9f0',
  version: '0.6.2',
  date: DateTime(2026, 10, 6),
  summary: 'Fixes a flaw in the web engine used by Firefox and the web apps.',
  severity: severity,
  securitySummary: securitySummary,
  signer: 'release',
  newApps: const [CatalogChange('mpv', 'Video player')],
);

UpdateStatus mockBehind(AvailableUpdate a) => UpdateStatus(
  currentVersion: '0.6.0',
  currentRev: 'a3f9c0de5b1e4c7a9d2f8b6e0c1a3d5f7b9e2c4a',
  available: a,
  checkedAt: DateTime(2026, 10, 6, 8),
);

// ---------------------------------------------------------------- system

class MockSystem implements SystemRepository {
  MockSystem(this.jobs, this.updates, this.auth, {this.dev = false});

  final MockJobs jobs;
  final MockUpdates updates;

  /// The admin password prompt turning SSH on goes through.
  final MockAuth auth;

  /// A developer build (`system.info.dev`): About shows the DEV badge.
  bool dev;
  bool _enabled = false;

  /// Everything done to the box: `power:<action>`, `ssh:on`, ...
  final List<String> log = [];

  @override
  Future<SystemInfo> info() async => SystemInfo(
    version: updates.status.currentVersion,
    channel: updates.channel,
    base: updates.base,
    rev: updates.status.currentRev,
    generation: 12,
    hostname: 'hinteros-livingroom',
    dev: dev,
    hostKeyFingerprints: const [
      'SHA256:hK4s9WqY2mRz7LxD0vTb3NcUe5GfJ8aPiOyH1CwEoXg (ed25519)',
    ],
  );

  @override
  Future<void> power(PowerAction action) async =>
      log.add('power:${action.name}');

  /// What `power.capabilities` allows.
  Set<PowerAction> allowedActions = {...PowerAction.values};

  @override
  Future<Set<PowerAction>> powerAllowed() async => allowedActions;

  /// `apps.displays.*`: the setting and what this session has.
  AppDisplaySetting appDisplaySetting = const AppDisplaySetting(
    count: 4,
    active: 4,
  );

  @override
  Future<AppDisplaySetting> appDisplays() async => appDisplaySetting;

  @override
  Future<AppDisplaySetting> setAppDisplays(int count) async {
    log.add('app-displays:$count');
    final s = appDisplaySetting;
    return appDisplaySetting = AppDisplaySetting(
      count: count,
      active: s.active,
      min: s.min,
      max: s.max,
    );
  }

  /// Makes the next `restartSession` fail with this.
  SystemException? restartFails;

  @override
  Future<void> restartSession() async {
    final e = restartFails;
    if (e != null) throw e;
    log.add('session:restart');
  }

  @override
  Future<SshState> ssh() async => SshState(enabled: _enabled);

  @override
  Future<JobHandle?> applySettings() async => null;

  @override
  Future<JobHandle> redetectHardware({String? adminPin}) async {
    updates.box?.checkBoxAdmin(adminPin);
    log.add('hardware:redetect');
    return jobs.start(JobKind.hardwareRedetect);
  }

  @override
  Future<JobHandle> setSsh(bool enable) async {
    if (enable) {
      // polkit auth_admin: the prompt is the shell's, this waits for it.
      switch (await auth.ask(
        action: 'org.hinteros.system.ssh',
        message:
            'Authentication is required to turn remote login (SSH) on or off',
      )) {
        case AuthOutcome.authorized:
          break;
        case AuthOutcome.failed:
          throw const SystemException(
            SystemErrorKind.permissionDenied,
            'Wrong admin password too many times. Nothing was changed.',
          );
        case AuthOutcome.cancelled:
          throw const SystemException(
            SystemErrorKind.authenticationRequired,
            'No admin password was given, so nothing was changed.',
            data: {'action': 'org.hinteros.system.ssh'},
          );
      }
    }
    log.add('ssh:${enable ? 'on' : 'off'}');
    return jobs.start(
      JobKind.ssh,
      subject: JobSubject(enabled: enable),
      onSuccess: () => _enabled = enable,
    );
  }
}

// ---------------------------------------------------------------- admin password

/// The admin password prompt as the real one behaves: a call that needs the
/// password [ask]s and waits; the UI [respond]s (3 tries) or [cancel]s.
class MockAuth implements AuthRepository {
  /// The admin account's password in this mock (placeholder).
  String adminPassword = 'correct horse';
  String account = 'admin';
  int maxAttempts = 3;

  /// How many passwords were checked (never which).
  int attempts = 0;

  /// How many prompts were cancelled by the UI.
  int cancels = 0;

  final _requests = StreamController<AuthRequest>.broadcast(sync: true);
  final _finished = StreamController<AuthFinished>.broadcast(sync: true);
  final _pending = <String, ({int left, Completer<AuthOutcome> done})>{};
  int _n = 0;

  /// Cookies that wait for an answer.
  List<String> get pending => _pending.keys.toList();

  @override
  Stream<AuthRequest> get requests => _requests.stream;
  @override
  Stream<AuthFinished> get finished => _finished.stream;

  Future<AuthOutcome> ask({required String action, required String message}) {
    final cookie = 'mock-${++_n}';
    final done = Completer<AuthOutcome>();
    _pending[cookie] = (left: maxAttempts, done: done);
    _requests.add(
      AuthRequest(
        cookie: cookie,
        action: action,
        message: message,
        account: account,
      ),
    );
    return done.future;
  }

  void _end(String cookie, AuthOutcome o) {
    final p = _pending.remove(cookie);
    if (p == null) return;
    _finished.add(AuthFinished(cookie, o));
    p.done.complete(o);
  }

  @override
  Future<AuthAnswer> respond(String cookie, String password) async {
    final p = _pending[cookie];
    if (p == null) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'There is no such request any more.',
      );
    }
    attempts++;
    final left = p.left - 1;
    final ok = password == adminPassword;
    if (ok) {
      _end(cookie, AuthOutcome.authorized);
    } else if (left <= 0) {
      _end(cookie, AuthOutcome.failed);
    } else {
      _pending[cookie] = (left: left, done: p.done);
    }
    return AuthAnswer(ok: ok, attemptsLeft: left);
  }

  @override
  Future<void> cancel(String cookie) async {
    if (_pending.containsKey(cookie)) cancels++;
    _end(cookie, AuthOutcome.cancelled);
  }
}

// ---------------------------------------------------------------- network

class MockNetwork implements NetworkRepository {
  MockNetwork() {
    _networks = [
      const WifiNetwork(
        ssid: 'Hinter-Home',
        signal: 88,
        connected: true,
        saved: true,
      ),
      const WifiNetwork(ssid: 'Hinter-Home-5G', signal: 72, saved: true),
      const WifiNetwork(ssid: 'Neighbour Net', signal: 54),
      const WifiNetwork(ssid: 'Cafe Guest', signal: 33, secured: false),
      const WifiNetwork(ssid: 'Basement', signal: 12),
    ];
  }

  late List<WifiNetwork> _networks;
  bool _wifi = true;

  /// False: the box has no Wi-Fi adapter.
  bool wifiAvailable = true;

  /// The password every secured, unsaved mock network accepts.
  String password = 'wifi-pass';

  /// Calls, for tests: `connect:<ssid>`, `forget:<ssid>`, ...
  final List<String> log = [];
  Object? failScanWith;

  @override
  Future<NetworkStatus> status() async {
    final c = _networks.where((n) => n.connected).firstOrNull;
    return NetworkStatus(
      wifiAvailable: wifiAvailable,
      wifiEnabled: _wifi,
      wifiSsid: c?.ssid,
      address: c == null ? null : '192.168.1.42',
    );
  }

  @override
  Future<List<WifiNetwork>> scan() async {
    if (failScanWith != null) throw failScanWith!;
    if (!_wifi) return const [];
    return [..._networks]..sort((a, b) => b.signal.compareTo(a.signal));
  }

  @override
  Future<List<WifiNetwork>> list() => scan();

  @override
  Stream<NetworkStatus> get statusChanges => const Stream.empty();

  @override
  Stream<List<WifiNetwork>> get listChanges => const Stream.empty();

  WifiNetwork _find(String ssid) => _networks.firstWhere(
    (n) => n.ssid == ssid,
    orElse: () => throw const SystemException(
      SystemErrorKind.deviceFailed,
      'That network is no longer in range.',
    ),
  );

  void _replace(String ssid, WifiNetwork Function(WifiNetwork) f) {
    _networks = [for (final n in _networks) n.ssid == ssid ? f(n) : n];
  }

  @override
  Future<void> connect(String ssid, {String? password}) async {
    final n = _find(ssid);
    log.add('connect:$ssid');
    if (n.secured && !n.saved) {
      if (password == null) {
        throw const SystemException(
          SystemErrorKind.invalidParams,
          'This network needs a password.',
        );
      }
      if (password != this.password) {
        throw const SystemException(
          SystemErrorKind.wrongPassword,
          'The password was not accepted.',
        );
      }
    }
    _networks = [
      for (final w in _networks)
        WifiNetwork(
          ssid: w.ssid,
          signal: w.signal,
          secured: w.secured,
          connected: w.ssid == ssid,
          saved: w.saved || w.ssid == ssid,
        ),
    ];
  }

  @override
  Future<void> disconnect() async {
    log.add('disconnect');
    _networks = [
      for (final w in _networks)
        WifiNetwork(
          ssid: w.ssid,
          signal: w.signal,
          secured: w.secured,
          saved: w.saved,
        ),
    ];
  }

  @override
  Future<void> forget(String ssid) async {
    log.add('forget:$ssid');
    _replace(
      ssid,
      (w) => WifiNetwork(ssid: w.ssid, signal: w.signal, secured: w.secured),
    );
  }

  @override
  Future<void> setWifiEnabled(bool enabled) async {
    log.add('wifi:${enabled ? 'on' : 'off'}');
    _wifi = enabled;
  }
}

// ---------------------------------------------------------------- bluetooth

class MockBluetooth implements BluetoothRepository {
  MockBluetooth() {
    _devices = [
      const BtDevice(
        id: 'AA:00:11',
        name: 'Pad One',
        kind: BtKind.controller,
        paired: true,
        connected: true,
      ),
      const BtDevice(
        id: 'AA:00:22',
        name: 'Living Room Buds',
        kind: BtKind.headset,
        paired: true,
      ),
    ];
    _nearby = [
      const BtDevice(id: 'BB:00:33', name: 'Pad Two', kind: BtKind.controller),
      const BtDevice(id: 'BB:00:44', name: 'Soundbar', kind: BtKind.speaker),
      const BtDevice(
        id: 'BB:00:55',
        name: 'Keyboard K1',
        kind: BtKind.keyboard,
      ),
    ];
  }

  late List<BtDevice> _devices;
  late List<BtDevice> _nearby;
  bool _scanning = false;
  final _changes = StreamController<List<BtDevice>>.broadcast();
  final List<String> log = [];

  @override
  bool get scanning => _scanning;
  @override
  Future<void> load() async {}
  @override
  Stream<BtConfirmRequest> get confirmRequests => const Stream.empty();
  @override
  Future<void> confirm(String id, {required bool accept}) async =>
      log.add('confirm:$id:$accept');
  @override
  Stream<List<BtDevice>> get devices => _changes.stream;
  @override
  List<BtDevice> get current => List.unmodifiable(_devices);

  void _emit() => _changes.add(current);

  @override
  Future<void> startScan() async {
    _scanning = true;
    for (final d in _nearby) {
      if (!_devices.any((e) => e.id == d.id)) _devices = [..._devices, d];
    }
    _emit();
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
    _emit();
  }

  void _update(String id, BtDevice Function(BtDevice) f) {
    if (!_devices.any((d) => d.id == id)) {
      throw const SystemException(
        SystemErrorKind.deviceFailed,
        'That device is no longer in range.',
      );
    }
    _devices = [for (final d in _devices) d.id == id ? f(d) : d];
    _emit();
  }

  @override
  Future<void> pair(String id) async {
    log.add('pair:$id');
    _update(id, (d) => d.copyWith(paired: true, connected: true));
  }

  @override
  Future<void> connect(String id) async {
    log.add('connect:$id');
    _update(id, (d) => d.copyWith(connected: true));
  }

  @override
  Future<void> disconnect(String id) async {
    log.add('disconnect:$id');
    _update(id, (d) => d.copyWith(connected: false));
  }

  @override
  Future<void> forget(String id) async {
    log.add('forget:$id');
    _devices = [
      for (final d in _devices)
        if (d.id != id) d,
    ];
    _emit();
  }
}

// ---------------------------------------------------------------- display, audio

class MockDisplayAudio implements DisplayAudioRepository {
  MockDisplayAudio() {
    _modes = const [
      DisplayMode(width: 3840, height: 2160, refreshHz: 60),
      DisplayMode(width: 3840, height: 2160, refreshHz: 30),
      DisplayMode(width: 2560, height: 1440, refreshHz: 120),
      DisplayMode(width: 1920, height: 1080, refreshHz: 120),
      DisplayMode(
        width: 1920,
        height: 1080,
        refreshHz: 60,
        current: true,
        preferred: true,
      ),
      DisplayMode(width: 1280, height: 720, refreshHz: 60),
    ];
  }

  late List<DisplayMode> _modes;
  DisplayMode? _previous;
  var _outputs = const [
    AudioOutput(id: 'hdmi', name: 'TV (HDMI)', current: true),
    AudioOutput(id: 'bt-buds', name: 'Living Room Buds (Bluetooth)'),
    AudioOutput(id: 'analog', name: 'Headphone jack'),
  ];
  int _volume = 55;
  bool _muted = false;
  final List<String> log = [];

  @override
  Future<DisplayInfo> displayModes() async => DisplayInfo(modes: _modes);

  @override
  Future<void> setDisplayMode(DisplayMode m) async {
    log.add('mode:${m.id}');
    _previous = _modes.where((d) => d.current).firstOrNull;
    _modes = [
      for (final d in _modes)
        DisplayMode(
          width: d.width,
          height: d.height,
          refreshHz: d.refreshHz,
          preferred: d.preferred,
          current: d.id == m.id,
        ),
    ];
  }

  @override
  Future<void> keepDisplayMode() async => log.add('keep');

  @override
  Future<void> revertDisplayMode() async {
    log.add('revert');
    final to = _previous;
    if (to == null) return;
    _modes = [
      for (final d in _modes)
        DisplayMode(
          width: d.width,
          height: d.height,
          refreshHz: d.refreshHz,
          preferred: d.preferred,
          current: d.id == to.id,
        ),
    ];
  }

  @override
  Stream<AudioState> get audioChanges => const Stream.empty();

  @override
  Future<AudioState> audio() async =>
      AudioState(outputs: _outputs, volume: _volume, muted: _muted);

  @override
  Future<void> setAudioOutput(String id) async {
    log.add('output:$id');
    _outputs = [
      for (final o in _outputs)
        AudioOutput(id: o.id, name: o.name, current: o.id == id),
    ];
  }

  @override
  Future<void> setVolume(int percent) async {
    log.add('volume:$percent');
    _volume = percent.clamp(0, 100);
  }

  @override
  Future<void> setMuted(bool muted) async {
    log.add('muted:$muted');
    _muted = muted;
  }
}

// ---------------------------------------------------------------- store

/// A mock-only app that needs a service the box does not run (the Store
/// shows why it cannot be installed).
const mockServiceApp = StoreApp(
  id: 'music-sync',
  name: 'Music library',
  summary: 'Your home server\'s music on the TV.',
  description:
      'Plays the music on your Jellyfin server. Needs the Jellyfin server on '
      'this box.',
  category: StoreCategory.music,
  sizeMiB: 80,
  installer: false,
  icon: StoreIcon(desktopId: 'music-sync'),
  missingServices: [(id: 'jellyfin-server', name: 'Jellyfin server')],
);

/// The mock Store's catalog: the fixture in the real index format, read by
/// the same parser as the real one, plus three mock-only entries (RetroArch
/// and its cores, a video player) that exercise dependencies and the Store
/// categories. Falls back to just those when the fixture is not found.
List<StoreApp> mockCatalog() {
  final dir = mockCatalogDir();
  return [
    if (dir != null)
      ...parseCatalogIndex(
        readLocalText('$dir/catalog.json')!,
        readTerms: termsReaderFor('$dir/catalog.json'),
        readReadme: readmeReaderFor('$dir/catalog.json'),
      ),
    const StoreApp(
      id: 'retroarch',
      name: 'RetroArch',
      summary: 'Classic consoles in one frontend.',
      description:
          'Runs old console games. Needs the emulator cores, which are '
          'installed with it.',
      category: StoreCategory.games,
      sizeMiB: 220,
      installer: false,
      depends: ['retroarch-cores'],
      icon: StoreIcon(desktopId: 'retroarch'),
    ),
    const StoreApp(
      id: 'retroarch-cores',
      name: 'Emulator cores',
      summary: 'The emulators RetroArch loads.',
      category: StoreCategory.utilities,
      sizeMiB: 400,
      installer: false,
      icon: StoreIcon(desktopId: 'retroarch-cores'),
    ),
    const StoreApp(
      id: 'mpv',
      name: 'Video player',
      summary: 'Plays files from USB drives and shares.',
      category: StoreCategory.video,
      sizeMiB: 60,
      installer: false,
      icon: StoreIcon(desktopId: 'mpv'),
      permissions: [
        AppPermission(name: 'gamepad', required: true),
        AppPermission(name: 'mic'),
        AppPermission(name: 'downloads'),
      ],
    ),
  ];
}

class MockStore implements StoreRepository {
  MockStore(
    this.jobs, {
    List<StoreApp>? catalog,
    Set<String>? installed,
    this.iconDir,
    this.moreAfterUpdate = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _catalog = catalog ?? mockCatalog(),
       _installed = {
         ...(installed ??
             const {
               'steam',
               'plex-htpc',
               'jellyfin-desktop',
               'youtube',
               'crunchyroll',
               'firefox',
             }),
       };

  final MockJobs jobs;
  final DateTime Function() _now;
  final List<StoreApp> _catalog;
  final Set<String> _installed;
  final _busy = <String, StoreState>{};
  final Set<String> _needsTerms = {};

  /// This profile's opt-outs: app id -> denied permission names (only
  /// optional ones, as in the session daemon's `permissions.json`).
  final Map<String, Set<String>> denied = {};

  /// Earlier app generations of this profile (newest first), below the
  /// current one, which is what [installed] holds.
  List<AppGeneration> earlierGenerations = [
    AppGeneration(
      generation: 2,
      date: DateTime(2026, 10, 3, 18),
      ids: const [
        'crunchyroll',
        'firefox',
        'jellyfin-desktop',
        'steam',
        'youtube',
      ],
    ),
    AppGeneration(
      generation: 1,
      date: DateTime(2026, 9, 28, 12),
      ids: const ['firefox', 'youtube'],
      systemRev: '0f3c5a9e2b7d4c1a8e6f9b0d2c4e6a8b1d3f5a7c',
    ),
  ];
  int _generation = 3;

  /// Where the generic placeholder icons are (`<id>.png`); null: none.
  final String? iconDir;
  final _changes = StreamController<void>.broadcast();

  @override
  bool moreAfterUpdate;

  /// `install:<id>:<id=terms version,...>` / `remove:<id>:<deleteData>` /
  /// `set_permission:<id>:<permission>:<granted>` in order.
  final List<String> log = [];

  /// `<id>=<terms version>` for every acceptance the box would record.
  final List<String> acceptances = [];

  /// The next install or remove fails with this (a conflict, no space...).
  SystemException? failNext;

  @override
  bool get loaded => true;
  @override
  Set<String> get installed => Set.unmodifiable(_installed);
  @override
  Stream<void> get changes => _changes.stream;

  @override
  StoreState stateOf(String id) =>
      _busy[id] ??
      (_installed.contains(id) ? StoreState.installed : StoreState.available);

  @override
  List<StoreApp> get apps => [
    for (final a in _catalog)
      StoreApp(
        id: a.id,
        name: a.name,
        summary: a.summary,
        description: a.description,
        category: a.category,
        sizeMiB: a.sizeMiB,
        homepage: a.homepage,
        depends: a.depends,
        conflicts: a.conflicts,
        terms: a.terms,
        readme: a.readme,
        unfree: a.unfree,
        installer: a.installer,
        installerDefault: a.installerDefault,
        onIso: a.onIso,
        delivery: a.delivery,
        dataPaths: a.dataPaths,
        icon: a.icon,
        removeDataWarning: a.removeDataWarning,
        state: stateOf(a.id),
        missingServices: a.missingServices,
        permissions: [
          for (final p in a.permissions)
            p.copyWith(granted: !(denied[a.id]?.contains(p.name) ?? false)),
        ],
        fullAccess: a.fullAccess,
        hasData: _hasData(a.id),
      ),
  ];

  @override
  Set<String> get needsTerms => Set.unmodifiable(_needsTerms);

  /// The profile accepted app [id]'s terms (the session daemon would
  /// re-read its app list now).
  void Function(String id)? onTermsAccepted;

  /// Apps this profile got with the starter set without accepting their
  /// terms yet.
  void setNeedsTerms(Iterable<String> ids) {
    _needsTerms
      ..clear()
      ..addAll(ids);
    _changes.add(null);
  }

  @override
  Future<void> acceptTerms(String id, String version) async {
    _maybeFail();
    if (!_needsTerms.contains(id)) {
      throw SystemException(
        SystemErrorKind.notFound,
        '$id has no terms waiting to be accepted.',
      );
    }
    final t = _app(id).terms;
    if (t != null && t.version != version) {
      throw SystemException(
        SystemErrorKind.termsRequired,
        'The terms of $id have to be accepted first.',
        data: {'id': id, 'version': t.version},
      );
    }
    log.add('accept_terms:$id=$version');
    acceptances.add('$id=$version');
    _needsTerms.remove(id);
    onTermsAccepted?.call(id);
    _changes.add(null);
  }

  @override
  Future<void> setPermission(String id, String permission, bool granted) async {
    final a = _app(id);
    _maybeFail();
    final p = a.permissions.where((p) => p.name == permission).firstOrNull;
    if (p == null) {
      throw SystemException(
        SystemErrorKind.notFound,
        '${a.name} has no such permission.',
        data: {'id': id, 'permission': permission},
      );
    }
    if (p.required && !granted) {
      throw SystemException(
        SystemErrorKind.invalidParams,
        '${a.name} needs this permission.',
        data: {'id': id, 'permission': permission},
      );
    }
    log.add('set_permission:$id:$permission:$granted');
    final d = denied.putIfAbsent(id, () => {});
    granted ? d.remove(permission) : d.add(permission);
    if (d.isEmpty) denied.remove(id);
    _changes.add(null);
  }

  @override
  Future<List<AppGeneration>> appGenerations() async => [
    AppGeneration(
      generation: _generation,
      date: _now(),
      ids: [..._installed]..sort(),
      current: true,
    ),
    ...earlierGenerations,
  ];

  @override
  Future<JobHandle> rollbackApps(int generation) async {
    _maybeFail();
    final g = earlierGenerations
        .where((g) => g.generation == generation)
        .firstOrNull;
    if (g == null) {
      throw SystemException(
        SystemErrorKind.notFound,
        'Generation $generation is not there.',
      );
    }
    log.add('rollback_apps:$generation');
    return jobs.start(
      JobKind.appsRollback,
      subject: JobSubject(generation: generation, fromGeneration: _generation),
      onSuccess: () {
        final before = AppGeneration(
          generation: _generation,
          date: _now(),
          ids: [..._installed]..sort(),
        );
        earlierGenerations = [before, ...earlierGenerations].take(3).toList();
        _generation++;
        _installed
          ..clear()
          ..addAll(g.ids);
      },
      onFinish: () => _changes.add(null),
    );
  }

  void setInstalled(Iterable<String> ids) {
    _installed
      ..clear()
      ..addAll(ids);
    _changes.add(null);
  }

  @override
  Future<List<StoreApp>> catalog() async => apps;

  @override
  Future<String?> resolveIcon(StoreApp app) async {
    if (app.icon.path != null) return app.icon.path;
    final d = iconDir;
    if (d == null) return null;
    for (final ext in ['png', 'svg']) {
      final p = '$d/${app.id}.$ext';
      if (localFileExists(p)) return p;
    }
    return null;
  }

  StoreApp _app(String id) => _catalog.firstWhere(
    (a) => a.id == id,
    orElse: () => throw const SystemException(
      SystemErrorKind.notFound,
      'That app is not in this version of the catalog.',
    ),
  );

  void _maybeFail() {
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
  }

  @override
  Future<JobHandle> install(
    String id, {
    Map<String, String> acceptedTerms = const {},
  }) async {
    final a = _app(id);
    _maybeFail();
    // What the service installs: the app and its depends, transitively.
    final want = <StoreApp>[];
    void add(StoreApp x) {
      if (_installed.contains(x.id) || want.any((w) => w.id == x.id)) return;
      want.add(x);
      x.depends.map(_app).forEach(add);
    }

    add(a);
    if (a.missingServices.isNotEmpty) {
      throw SystemException(
        SystemErrorKind.invalidParams,
        '${a.name} needs ${a.missingServices.map((s) => s.name).join(', ')}, '
        'which this box does not run.',
        data: const {'field': 'ids', 'reason': 'needs_service'},
      );
    }
    for (final w in want) {
      final t = w.terms;
      if (t != null && acceptedTerms[w.id] != t.version) {
        throw SystemException(
          SystemErrorKind.termsRequired,
          'The terms of ${w.id} have to be accepted first.',
          data: {'id': w.id, 'version': t.version},
        );
      }
    }
    final given = acceptedTerms.entries.map((e) => '${e.key}=${e.value}');
    log.add('install:$id:${(given.toList()..sort()).join(',')}');
    acceptances.addAll(given);
    for (final w in want) {
      _busy[w.id] = StoreState.installing;
    }
    _changes.add(null);
    return jobs.start(
      JobKind.install,
      subject: JobSubject(
        apps: [for (final w in want) (id: w.id, name: w.name)],
      ),
      onSuccess: () {
        _installed.addAll(want.map((w) => w.id));
        dataCleared.removeAll(want.map((w) => w.id));
      },
      onFinish: () {
        for (final w in want) {
          _busy.remove(w.id);
        }
        _changes.add(null);
      },
    );
  }

  @override
  Future<JobHandle> remove(String id, {bool deleteData = false}) async {
    _app(id);
    _maybeFail();
    log.add('remove:$id:$deleteData');
    _needsTerms.remove(id);
    _busy[id] = StoreState.removing;
    _changes.add(null);
    return jobs.start(
      JobKind.remove,
      subject: JobSubject(
        apps: [(id: id, name: _app(id).name)],
        deleteData: deleteData,
      ),
      onSuccess: () {
        _installed.remove(id);
        dataCleared.remove(id);
        deleteData ? dataLeft.remove(id) : dataLeft.add(id);
      },
      onFinish: () {
        _busy.remove(id);
        _changes.add(null);
      },
    );
  }

  /// `has_data`: installed apps have data unless it was cleared; apps
  /// removed without their data leave it behind.
  final Set<String> dataCleared = {};
  final Set<String> dataLeft = {};
  bool _hasData(String id) =>
      (_installed.contains(id) && !dataCleared.contains(id)) ||
      dataLeft.contains(id);

  @override
  Future<JobHandle> clearData(String id) async {
    _app(id);
    _maybeFail();
    log.add('clear:$id');
    return jobs.start(
      JobKind.clearData,
      subject: JobSubject(
        apps: [(id: id, name: _app(id).name)],
        deleteData: true,
      ),
      onSuccess: () {
        dataLeft.remove(id);
        if (_installed.contains(id)) dataCleared.add(id);
      },
      onFinish: () => _changes.add(null),
    );
  }
}

// ---------------------------------------------------------------- bundle

/// A complete set of fakes, with handles to the concrete mocks.
class MockSystemServices extends SystemServices {
  MockSystemServices._({
    required this.mockJobs,
    required this.mockUpdates,
    required this.mockSystem,
    required this.mockNetwork,
    required this.mockBluetooth,
    required this.mockDisplayAudio,
    required this.mockStore,
    required this.mockAuth,
    required this.mockProfiles,
    required this.mockStorage,
    required this.mockTimeZone,
    required this.mockServer,
    required this.mockController,
  }) : super(
         jobs: mockJobs,
         system: mockSystem,
         updates: mockUpdates,
         network: mockNetwork,
         bluetooth: mockBluetooth,
         displayAudio: mockDisplayAudio,
         store: mockStore,
         auth: mockAuth,
         profiles: mockProfiles,
         storage: mockStorage,
         timeZone: mockTimeZone,
         server: mockServer,
         controller: mockController,
       );

  /// [autoRunJobs]: jobs step through their stages by themselves (`--mock`);
  /// tests drive them by hand. [iconDir]: the generic icon fixtures.
  /// [catalog], [installed], [generations] and [homes] replace the mock's
  /// own Store catalog, installed apps, system generations and storage
  /// trees (the browser demo has its own content).
  factory MockSystemServices({
    bool autoRunJobs = false,
    String? iconDir,
    UpdateStatus? status,
    DateTime Function()? now,
    MockProfileBox? profileBox,
    String currentProfile = 'p1',
    bool setupRequired = false,
    List<StoreApp> extraApps = const [],
    bool storageMeasured = true,
    String timeZone = 'UTC',
    List<StoreApp>? catalog,
    Set<String>? installed,
    List<Generation>? generations,
    StorageNode Function(String id)? homes,
  }) {
    final jobs = MockJobs(autoRun: autoRunJobs, now: now);
    final box = profileBox ?? MockProfileBox(now: now);
    final updates = MockUpdates(
      jobs,
      status: status,
      now: now,
      box: box,
      generations: generations,
    );
    final auth = MockAuth();
    final store = MockStore(
      jobs,
      iconDir: iconDir,
      now: now,
      catalog:
          catalog ??
          (extraApps.isEmpty ? null : [...mockCatalog(), ...extraApps]),
      installed: installed,
    );
    final profiles = MockProfiles(
      jobs,
      box: box,
      currentId: currentProfile,
      setupRequired: setupRequired,
      adminApps: () => store.installed,
    );
    return MockSystemServices._(
      mockJobs: jobs,
      mockUpdates: updates,
      mockSystem: MockSystem(jobs, updates, auth),
      mockAuth: auth,
      mockNetwork: MockNetwork(),
      mockBluetooth: MockBluetooth(),
      mockDisplayAudio: MockDisplayAudio(),
      mockStore: store,
      mockProfiles: profiles,
      mockStorage: MockStorage(
        jobs,
        box: box,
        currentId: () => profiles.currentId,
        now: now,
        measured: storageMeasured,
        home: homes ?? mockHome,
      ),
      mockTimeZone: MockTimeZone(
        box: box,
        firstBoot: () =>
            profiles.setupRequired || !box.profiles.any((p) => p.admin),
        zone: timeZone,
      ),
      mockServer: MockServer(jobs, box: box, iconDir: iconDir),
      mockController: MockController(autoAnswer: autoRunJobs),
    );
  }

  final MockJobs mockJobs;
  final MockUpdates mockUpdates;
  final MockSystem mockSystem;
  final MockNetwork mockNetwork;
  final MockBluetooth mockBluetooth;
  final MockDisplayAudio mockDisplayAudio;
  final MockStore mockStore;
  final MockAuth mockAuth;
  final MockProfiles mockProfiles;
  final MockStorage mockStorage;
  final MockTimeZone mockTimeZone;
  final MockServer mockServer;
  final MockController mockController;

  void dispose() {
    mockJobs.dispose();
    mockProfiles.dispose();
  }
}
