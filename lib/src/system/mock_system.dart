/// In-process fakes of every system repository, in the spirit of `MockDaemon`:
/// they behave like the real service would (validation, errors, jobs with
/// stages) and are driven from tests or `--mock`. Everything here is
/// placeholder data: no real logos, no real vendor texts.
/// The real ones are in `daemon_system.dart` (TODO(0.7): Network, Bluetooth,
/// DisplayAudio, power).
library;

import 'dart:async';
import 'dart:io';

import '../api/mock_store.dart' show mockCatalogDir;
import 'catalog.dart';
import 'mock_profiles.dart';
import 'models.dart';
import 'repositories.dart';

export 'mock_profiles.dart';

String _hex(int n, int len) => n.toRadixString(16).padLeft(len, '0');

// ---------------------------------------------------------------- jobs

class _Job {
  _Job(this.snap);

  JobSnapshot snap;
  final changes = StreamController<JobSnapshot>.broadcast(sync: true);
  void Function()? onSuccess;
  void Function()? onFinish;
  Timer? timer;
}

/// Jobs the way the privileged service reports them: one mutating job at a
/// time, stages, progress, cancel until activation.
class MockJobs implements JobsRepository {
  MockJobs({this.stepDelay = const Duration(milliseconds: 700), this.autoRun});

  /// Time between stages when a job runs by itself.
  Duration stepDelay;

  /// Jobs run through their stages on their own (`--mock`, the dev window).
  /// Tests leave this off and drive jobs with [progress] and [finish].
  bool? autoRun;

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
  JobHandle? get running {
    for (final j in _jobs.values) {
      if (j.snap.running) return JobHandle(j.snap.jobId, j.snap.kind);
    }
    return null;
  }

  /// Starts a job. [onSuccess] is the side effect on the mock's state when it
  /// finishes well.
  JobHandle start(
    JobKind kind, {
    void Function()? onSuccess,
    void Function()? onFinish,
  }) {
    final r = running;
    if (r != null) {
      throw SystemException(
        SystemErrorKind.jobBusy,
        'Another change is still running.',
        data: {'job_id': r.jobId},
      );
    }
    final id = _hex(++_n * 7919 + 0xabc0de, 16);
    final job = _Job(JobSnapshot(jobId: id, kind: kind))
      ..onSuccess = onSuccess
      ..onFinish = onFinish;
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
    void step() {
      if (job.snap.finished) return;
      final s = stages[i];
      if (failWith != null && s == (failAt ?? stages.last)) {
        finish(job.snap.jobId, ok: false, error: failWith);
        return;
      }
      if (s == JobStage.downloading) {
        progress(job.snap.jobId, s, percent: pct, detail: '$pct% of the files');
        pct += 25;
        if (pct <= 100) {
          job.timer = Timer(stepDelay, step);
          return;
        }
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

  void progress(String jobId, JobStage stage, {int? percent, String? detail}) {
    final j = _jobs[jobId]!;
    j.snap = j.snap.copyWith(
      stage: stage,
      percent: percent,
      clearPercent: percent == null,
      detail: detail,
    );
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
    j.snap = j.snap.copyWith(
      finished: true,
      ok: ok,
      cancelled: cancelled,
      error: error,
      sessionRestartRequired:
          sessionRestartRequired ??
          (ok &&
              j.snap.kind.mayRestartSession &&
              j.snap.sessionRestartRequired),
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
        ),
    ];
  }

  final MockJobs jobs;
  final DateTime Function() _now;
  UpdateChannel channel;
  NixBase base;
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
  Future<JobHandle> apply(String rev) async {
    final a = _status.available;
    if (a == null || a.rev != rev) {
      throw const SystemException(
        SystemErrorKind.stateConflict,
        'That is not the update that was checked.',
      );
    }
    return jobs.start(
      JobKind.update,
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
  Future<JobHandle> rollback({int? generation}) async {
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

  @override
  Future<JobHandle> setChannel(
    UpdateChannel c, {
    bool acknowledgeDowngrade = false,
  }) async {
    if (c == UpdateChannel.stable &&
        channel == UpdateChannel.beta &&
        !acknowledgeDowngrade) {
      throw const SystemException(
        SystemErrorKind.needsAcknowledgement,
        'Stable may be older than what this box runs now.',
      );
    }
    return jobs.start(JobKind.channel, onSuccess: () => channel = c);
  }

  @override
  Future<JobHandle> setBase(
    NixBase b, {
    bool acknowledgeDowngrade = false,
  }) async {
    if (b == NixBase.stable &&
        base == NixBase.unstable &&
        !acknowledgeDowngrade) {
      throw const SystemException(
        SystemErrorKind.needsAcknowledgement,
        'Switching to the stable base downgrades software.',
      );
    }
    return jobs.start(JobKind.channel, onSuccess: () => base = b);
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
    return jobs.start(JobKind.ssh, onSuccess: () => _enabled = enable);
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

  /// The password every secured, unsaved mock network accepts.
  String password = 'wifi-pass';

  /// Calls, for tests: `connect:<ssid>`, `forget:<ssid>`, ...
  final List<String> log = [];
  Object? failScanWith;

  @override
  Future<NetworkStatus> status() async {
    final c = _networks.where((n) => n.connected).firstOrNull;
    return NetworkStatus(
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
    if (dir != null) ...loadCatalogIndex('$dir/catalog.json'),
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
               'jellyfin',
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

  /// Earlier app generations of this profile (newest first), below the
  /// current one, which is what [installed] holds.
  List<AppGeneration> earlierGenerations = [
    AppGeneration(
      generation: 2,
      date: DateTime(2026, 10, 3, 18),
      ids: const ['crunchyroll', 'firefox', 'jellyfin', 'steam', 'youtube'],
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

  /// `install:<id>:<id=terms version,...>` / `remove:<id>:<deleteData>` in
  /// order.
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
        isWeb: a.isWeb,
        depends: a.depends,
        conflicts: a.conflicts,
        terms: a.terms,
        free: a.free,
        installer: a.installer,
        installerDefault: a.installerDefault,
        onIso: a.onIso,
        buildsOnDevice: a.buildsOnDevice,
        dataPaths: a.dataPaths,
        icon: a.icon,
        removeDataWarning: a.removeDataWarning,
        state: stateOf(a.id),
        missingServices: a.missingServices,
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
      final f = File('$d/${app.id}.$ext');
      if (f.existsSync()) return f.path;
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
      onSuccess: () => _installed.addAll(want.map((w) => w.id)),
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
      onSuccess: () => _installed.remove(id),
      onFinish: () {
        _busy.remove(id);
        _changes.add(null);
      },
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
       );

  /// [autoRunJobs]: jobs step through their stages by themselves (`--mock`);
  /// tests drive them by hand. [iconDir]: the generic icon fixtures.
  factory MockSystemServices({
    bool autoRunJobs = false,
    String? iconDir,
    UpdateStatus? status,
    DateTime Function()? now,
    MockProfileBox? profileBox,
    String currentProfile = 'p1',
    bool setupRequired = false,
    List<StoreApp> extraApps = const [],
  }) {
    final jobs = MockJobs(autoRun: autoRunJobs);
    final updates = MockUpdates(jobs, status: status, now: now);
    final auth = MockAuth();
    final store = MockStore(
      jobs,
      iconDir: iconDir,
      now: now,
      catalog: extraApps.isEmpty ? null : [...mockCatalog(), ...extraApps],
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
      mockProfiles: MockProfiles(
        jobs,
        box: profileBox ?? MockProfileBox(now: now),
        currentId: currentProfile,
        setupRequired: setupRequired,
        adminApps: () => store.installed,
      ),
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

  void dispose() {
    mockJobs.dispose();
    mockProfiles.dispose();
  }
}
