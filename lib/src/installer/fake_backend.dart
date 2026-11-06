import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../system/mock_system.dart' show mockCatalog;
import '../system/models.dart';
import 'backend.dart';
import 'plan.dart';
import 'progress.dart';

/// What a fake backend call prints and how it exits.
class FakeScript {
  const FakeScript(this.events, this.exitCode);

  final List<InstallEvent> events;
  final int exitCode;

  static InstallEvent _e(
    String stage,
    int percent,
    String message, [
    InstallLevel level = InstallLevel.info,
    String? code,
    int? step,
  ]) => InstallEvent(
    stepPercent: step,
    stage: stage,
    percent: percent,
    level: level,
    message: message,
    code: code,
  );

  /// A `build` line; [name] null: nothing is being built right now.
  static InstallEvent _b(
    int percent,
    String message,
    int step, [
    String? name,
    int? index,
    int? buildPercent,
  ]) => InstallEvent(
    stage: 'build',
    percent: percent,
    level: InstallLevel.info,
    message: message,
    stepPercent: step,
    build: name,
    buildIndex: index,
    buildTotal: 12,
    buildPercent: buildPercent,
  );

  /// The system stages: the packages (copied from the USB stick with
  /// [copy], else downloaded), the build until [until] percent, then the
  /// boot loader.
  static List<InstallEvent> _system({bool copy = false, int until = 100}) => [
    if (copy) _e('packages', 31, 'Copying flake inputs to the new system'),
    _e('packages', 32, 'Getting the package list'),
    _e('packages', 36, '120 of 480 packages', InstallLevel.info, null, 25),
    _e('packages', 40, '480 of 480 packages', InstallLevel.info, null, 100),
    _b(42, 'Building hinteros-daemon (1 of 12)', 0, 'hinteros-daemon', 1),
    _b(50, 'Building hinteros-daemon (1 of 12)', 8, 'hinteros-daemon', 1, 20),
    if (until > 50) ...[
      _b(
        57,
        'Building hinteros-launcher (3 of 12)',
        17,
        'hinteros-launcher',
        3,
        88,
      ),
      _b(80, '12 of 12 built', 100),
      _e('bootloader', 85, 'Installing the boot loader'),
      _e(
        'bootloader',
        90,
        'System installed, boot loader written',
        InstallLevel.info,
        null,
        100,
      ),
    ],
  ];

  /// `--validate-only` that accepts the plan.
  static final validateOk = FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 4, 'Offline install: only the apps on this installer'),
    _e('validate', 8, 'Plan accepted'),
    _e('done', 100, 'Plan and machine are fine (validate only)'),
  ], 0);

  /// A whole install with one warning on the way.
  static final installOk = FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 8, 'Plan accepted'),
    _e('partition', 10, 'Erasing and partitioning the disk'),
    _e('partition', 20, 'Disk is partitioned and mounted'),
    _e('facter', 22, 'Detecting hardware'),
    _e(
      'facter',
      26,
      'Hardware detection failed; continuing with generic hardware support',
      InstallLevel.warn,
      'facter-failed',
    ),
    _e('config', 28, 'Writing the device configuration'),
    _e('config', 30, 'Device configuration written to /etc/hinteros'),
    ..._system(copy: true),
    _e('snapshot', 92, 'Checking the config snapshot'),
    _e('snapshot', 95, '/etc/hinteros matches the installed generation'),
    _e('finalize', 97, 'Flushing to disk'),
    _e('done', 100, 'HinterOS is installed. Remove the installer medium.'),
  ], 0);

  /// A whole install that keeps the data: `mount` for `partition`, no apps
  /// stage.
  static final keepOk = FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 8, 'Plan accepted: keep all data'),
    _e('mount', 10, 'Mounting the install'),
    _e('mount', 20, 'The install is mounted; nothing was erased'),
    _e('facter', 22, 'Detecting hardware'),
    _e('config', 30, 'Device configuration written to /etc/hinteros'),
    ..._system(copy: true),
    _e('snapshot', 92, 'Checking the config snapshot'),
    _e('finalize', 97, 'Flushing to disk'),
    _e('done', 100, 'HinterOS is installed. All data is kept.'),
  ], 0);

  /// A whole two-stage install: the system, then each of [apps]; the ones
  /// in [failing] end with an `app-failed` warning (the exit status stays 0).
  static FakeScript twoStage(
    List<String> apps, {
    List<String> failing = const [],
  }) {
    final n = apps.length;
    InstallEvent sys(String stage, int pct, String m, [int? step]) =>
        InstallEvent(
          stepPercent: step,
          stage: stage,
          percent: pct,
          level: InstallLevel.info,
          message: m,
        );
    InstallEvent app(int pct, String m, String id, int index, [String? code]) =>
        InstallEvent(
          appIndex: index,
          appTotal: n,
          stepPercent: code == null ? 40 : 100,
          stage: 'install',
          percent: pct,
          level: code == null ? InstallLevel.info : InstallLevel.warn,
          message: m,
          code: code,
          phase: InstallSection.apps,
          app: id,
        );
    return FakeScript([
      sys('validate', 0, 'Checking the plan'),
      sys('validate', 8, 'Plan accepted'),
      sys('partition', 20, 'Disk is partitioned and mounted'),
      sys('config', 30, 'Device configuration written'),
      ..._system(),
      sys('snapshot', 90, 'Checking the config snapshot'),
      sys('finalize', 97, 'System installed'),
      for (var i = 0; i < n; i++) ...[
        app(97 + 3 * i ~/ n, 'Installing ${apps[i]}', apps[i], i + 1),
        if (failing.contains(apps[i]))
          app(
            97 + 3 * (i + 1) ~/ n,
            '${apps[i]} could not be installed',
            apps[i],
            i + 1,
            'app-failed',
          ),
      ],
      InstallEvent(
        stage: 'done',
        percent: 100,
        level: InstallLevel.info,
        message: 'HinterOS is installed. Remove the installer medium.',
        phase: InstallSection.apps,
        failedApps: failing,
      ),
    ], 0);
  }

  /// The plan or machine is refused: exit 2, nothing touched.
  static FakeScript refused(String code, String message) => FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 0, message, InstallLevel.error, code),
  ], 2);

  /// Fails part-way: exit 1.
  static FakeScript failed({
    String code = 'install-failed',
    String message = 'nixos-install failed (exit 1); see $installLogPath',
    int percent = 57,
  }) => FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 8, 'Plan accepted'),
    _e('partition', 20, 'Disk is partitioned and mounted'),
    ..._system(until: 50),
    _e('build', percent, message, InstallLevel.error, code),
  ], 1);

  /// A whole install of a newer HinterOS: validate, then `fetch` (no
  /// measurable fraction), then the usual stages.
  static FakeScript newerOk(String version) => FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 6, 'Checking the newer HinterOS on the stable channel'),
    _e('validate', 8, 'Plan accepted'),
    _e('fetch', 9, 'Downloading HinterOS $version'),
    _e('fetch', 9, 'HinterOS $version is downloaded'),
    _e('partition', 20, 'Disk is partitioned and mounted'),
    _e('config', 30, 'Device configuration written'),
    ..._system(),
    _e('snapshot', 90, 'Checking the config snapshot'),
    _e('finalize', 97, 'System installed'),
    _e('done', 100, 'HinterOS $version is installed.'),
  ], 0);

  /// The newer HinterOS does not download: exit 1, the disk not touched.
  static FakeScript fetchFailed() => FakeScript([
    _e('validate', 0, 'Checking the plan'),
    _e('validate', 8, 'Plan accepted'),
    _e('fetch', 9, 'Downloading HinterOS'),
    _e(
      'fetch',
      9,
      'could not download the newer revision; see $installLogPath',
      InstallLevel.error,
      'fetch-failed',
    ),
  ], 1);
}

/// A scripted backend: no processes, no devices. Used by the widget tests
/// and by `--installer --mock` on the desktop. Records what it was asked.
class FakeInstallerBackend implements InstallerBackend {
  FakeInstallerBackend({
    this.state = const NetworkState(),
    this.networkHold,
    this.scanHold,
    List<WifiAp>? wifi,
    List<DiskInfo>? disks,
    List<StoreApp>? catalog,
    this.validateScript,
    this.installScript,
    this.delay = Duration.zero,
    this.wifiPasswords = const {},
    Map<InstallChannel, HinterRelease>? newer,
    this.checkError,
    this.defaultChannel = InstallChannel.stable,
    this.infoError,
  }) : newer = newer ?? {},
       _wifi = wifi ?? mockWifi(),
       _disks = List.of(disks ?? mockDisks()),
       _catalog = catalog ?? mockInstallerCatalog();

  /// What `network()` reports; joining Wi-Fi changes it.
  NetworkState state;

  /// When set, `network()` / `scanWifi()` wait for these before answering
  /// (a slow check, for tests).
  Future<void>? networkHold;

  /// States `network()` answers with first, one per call (a cable being
  /// plugged in: nothing, connecting, connected); then [state] again.
  final networkQueue = <NetworkState>[];
  Future<void>? scanHold;

  /// When set, `connectWifi()` waits for this first (a slow join, for tests).
  Future<void>? connectHold;
  final List<WifiAp> _wifi;
  final List<DiskInfo> _disks;
  final List<StoreApp> _catalog;

  /// Null: [FakeScript.validateOk] / [FakeScript.installOk]. Set again
  /// between calls to script a retry.
  FakeScript? validateScript;
  FakeScript? installScript;

  /// Builds the install script from the plan (the apps it names), when
  /// [installScript] is not set.
  FakeScript Function(InstallPlan plan)? installScriptFor;

  /// Pause between progress lines (the desktop mock is slow on purpose).
  Duration delay;

  /// `ssid -> password` for secured networks; others fail to connect.
  final Map<String, String> wifiPasswords;

  /// Runs when `install` is called, before its script: a test or scenario
  /// changes the machine there (see [replug]).
  void Function()? beforeInstall;

  /// Every call, in order: `network`, `scanWifi`, `connectWifi:<ssid>`,
  /// `disks`, `catalog`, `info`, `checkNewer:<channel>`, `validate`,
  /// `install`, `reboot`.
  final calls = <String>[];

  /// The installer's own revision, as `--info` and `--check-newer` report
  /// it.
  static const isoRelease = HinterRelease(
    rev: '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d',
    version: '0.7.0',
  );

  /// What each channel offers that is newer than [isoRelease] (none by
  /// default). Change it between calls to script a channel moving on.
  Map<InstallChannel, HinterRelease> newer;

  /// When set, `checkNewer` fails with it (offline, unsigned, ...).
  InstallerException? checkError;

  /// The channel a check without one gets and `--info` reports
  /// (`hinteros.installer.channel`): beta for a beta installer.
  InstallChannel defaultChannel;

  /// When set, `info` fails with it (an older installer without `--info`).
  InstallerException? infoError;

  /// When set, `checkNewer` waits for it (a slow check, for tests).
  Future<void>? checkHold;

  /// The script of an install with a newer `rev` (null: [installScript] and
  /// the rest, as for the installer's own version).
  FakeScript? newerInstallScript;

  /// The plan of every `validate` / `install` call as the backend would get
  /// it on stdin (UTF-8 JSON). Contains the password: this is a fake.
  final stdinPlans = <String>[];

  /// `stdinPlans` decoded.
  List<Map<String, Object?>> get plans => [
    for (final p in stdinPlans) jsonDecode(p) as Map<String, Object?>,
  ];

  bool get rebooted => calls.contains('reboot');

  /// Whether the probe of the cache server works (false: link up but no
  /// internet).
  bool reachable = true;

  final _monitor = StreamController<void>.broadcast();

  /// What `nmcli monitor` printing a line looks like.
  void emitNetworkEvent() => _monitor.add(null);

  @override
  Future<NetworkState> network({bool force = false}) async {
    calls.add('network');
    if (force && state.linkUp) calls.add('connectivity check');
    await networkHold;
    if (networkQueue.isNotEmpty) state = networkQueue.removeAt(0);
    return state.withOnline(state.linkUp && state.online && reachable);
  }

  /// When set, `networkLink()` waits for it (a slow nmcli, for tests).
  Future<void>? linkHold;

  @override
  Future<NetworkState> networkLink() async {
    calls.add('networkLink');
    await linkHold;
    return state.withOnline(false);
  }

  @override
  Stream<void> watchNetwork() {
    late final StreamController<void> c;
    StreamSubscription<void>? sub;
    c = StreamController<void>(
      onListen: () {
        calls.add('monitor:start');
        sub = _monitor.stream.listen(c.add);
      },
      onCancel: () {
        calls.add('monitor:stop');
        return sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Future<List<WifiAp>> scanWifi() async {
    calls.add('scanWifi');
    await scanHold;
    return List.of(_wifi);
  }

  @override
  Future<void> connectWifi(String ssid, {String? psk}) async {
    calls.add('connectWifi:$ssid');
    await connectHold;
    final ap = _wifi.where((a) => a.ssid == ssid).firstOrNull;
    if (ap == null) throw const InstallerException('Network not found.');
    if (ap.secured && wifiPasswords[ssid] != psk) {
      throw InstallerException(
        'Could not connect to "$ssid". Check the password and try again.',
      );
    }
    state = NetworkState(
      wiredConnected: state.wiredConnected,
      wifiAvailable: true,
      wifiSsid: ssid,
      online: true,
    );
  }

  /// When set, `disks()` waits for it (a slow listing, for tests).
  Future<void>? disksHold;

  /// The listing does not look inside the disks (`--list-disks` gave no
  /// answer in time, plain lsblk listed them).
  bool disksUnchecked = false;

  @override
  Future<List<DiskInfo>> disks() async {
    calls.add('disks');
    await disksHold;
    return [for (final d in _disks) disksUnchecked ? d.unchecked() : d];
  }

  /// The disk at [path] is unplugged and plugged in again: the same path, a
  /// new disk sequence number (as the kernel does).
  void replug(String path) {
    final i = _disks.indexWhere((d) => d.path == path);
    final next = _disks.map((x) => x.diskSeq ?? 0).reduce(max) + 1;
    _disks[i] = _disks[i].copyWith(diskSeq: next);
  }

  /// What the next listing says about the disk at [path] (a disk that
  /// changed, or that is mounted).
  void setDisk(String path, DiskInfo d) =>
      _disks[_disks.indexWhere((x) => x.path == path)] = d;

  /// As the backend checks a keepData plan: only what it takes, and an
  /// install it can keep. Null: it is fine, or does not keep the data.
  FakeScript? _keepRefusal(InstallPlan plan) {
    if (!plan.keepData) return null;
    const notKept = {'base', 'apps', 'acceptedTerms', 'rev'};
    final field = plan.toJson().keys.where(notKept.contains).firstOrNull;
    if (field != null) {
      return FakeScript.refused(
        'keep-data-field',
        'a keepData plan does not take $field',
      );
    }
    final d = _disks.where((x) => x.path == plan.disk).first;
    return d.existing?.schemaOk == true
        ? null
        : FakeScript.refused(
            'keep-no-install',
            '${plan.disk} has no HinterOS install',
          );
  }

  /// As the backend checks the plan's disk: there, and the same disk
  /// sequence number. Null: it is.
  FakeScript? _diskRefusal(InstallPlan plan) {
    final d = _disks.where((x) => x.path == plan.disk).firstOrNull;
    if (d == null) {
      return FakeScript.refused(
        'disk-not-found',
        '${plan.disk} is not a block device on this machine',
      );
    }
    if (d.diskSeq != plan.diskSeq) {
      return FakeScript.refused(
        'disk-changed',
        'the disk changed: ${plan.disk} is now disk ${d.diskSeq}, not disk '
            '${plan.diskSeq} of the plan. Nothing was touched. Select the '
            'disk again',
      );
    }
    return null;
  }

  @override
  Future<List<StoreApp>> catalog() async {
    calls.add('catalog');
    return List.of(_catalog);
  }

  @override
  Future<InstallerInfo> info() async {
    calls.add('info');
    final error = infoError;
    if (error != null) throw error;
    return InstallerInfo(iso: isoRelease, channel: defaultChannel);
  }

  @override
  Future<NewerCheck> checkNewer({InstallChannel? channel}) async {
    final ch = channel ?? defaultChannel;
    calls.add('checkNewer:${channel?.name ?? 'default'}');
    await checkHold;
    final error = checkError;
    if (error != null) throw error;
    return NewerCheck(channel: ch, iso: isoRelease, newer: newer[ch]);
  }

  /// What a plan installs: a newer release it names, else the installer's.
  HinterRelease _installed(InstallPlan plan) =>
      newer.values.where((r) => r.rev == plan.rev).firstOrNull ?? isoRelease;

  InstallRun _run(String call, InstallPlan plan, FakeScript script) {
    calls.add(call);
    stdinPlans.add(utf8.decode(plan.encode()));
    final c = StreamController<InstallEvent>();
    final done = Completer<int>();
    final installed = _installed(plan);
    unawaited(() async {
      for (final e in script.events) {
        await Future<void>.delayed(delay);
        // Like the backend, the final line of an install names what it
        // installed.
        c.add(
          call == 'install' && e.isDone && e.rev == null
              ? InstallEvent(
                  stage: e.stage,
                  percent: e.percent,
                  level: e.level,
                  message: e.message,
                  code: e.code,
                  phase: e.phase,
                  failedApps: e.failedApps,
                  rev: installed.rev,
                  version: installed.version,
                )
              : e,
        );
      }
      await c.close();
      done.complete(script.exitCode);
    }());
    return InstallRun(c.stream, done.future);
  }

  @override
  InstallRun validate(InstallPlan plan) => _run(
    'validate',
    plan,
    _diskRefusal(plan) ??
        _keepRefusal(plan) ??
        validateScript ??
        FakeScript.validateOk,
  );

  @override
  InstallRun install(InstallPlan plan) {
    beforeInstall?.call();
    return _run(
      'install',
      plan,
      _diskRefusal(plan) ??
          _keepRefusal(plan) ??
          (plan.rev != null ? newerInstallScript : null) ??
          installScript ??
          (plan.keepData ? FakeScript.keepOk : null) ??
          installScriptFor?.call(plan) ??
          FakeScript.installOk,
    );
  }

  /// The reboot fails (systemctl refused it).
  bool rebootFails = false;

  @override
  Future<void> reboot() async {
    calls.add('reboot');
    if (rebootFails) {
      throw const InstallerException('systemctl failed (status 1).');
    }
  }
}

const _gib = 1024 * 1024 * 1024;

/// A machine with an internal NVMe disk, a second SATA disk with HinterOS on
/// it, a small one, the installer stick and a USB drive.
List<DiskInfo> mockDisks() => const [
  DiskInfo(
    path: '/dev/nvme0n1',
    name: 'nvme0n1',
    diskSeq: 1,
    sizeBytes: 512110190592,
    model: 'Example NVMe 512GB',
    transport: 'nvme',
  ),
  DiskInfo(
    path: '/dev/sda',
    name: 'sda',
    diskSeq: 2,
    sizeBytes: 1000204886016,
    model: 'Example SATA SSD 1TB',
    transport: 'sata',
    existing: ExistingInstall(
      schemaOk: true,
      version: '0.6.0',
      hostname: 'den',
      admin: 'alex',
    ),
  ),
  DiskInfo(
    path: '/dev/mmcblk0',
    name: 'mmcblk0',
    diskSeq: 3,
    sizeBytes: 8 * _gib,
    model: 'Example eMMC 8GB',
    transport: null,
  ),
  DiskInfo(
    path: '/dev/sdb',
    name: 'sdb',
    diskSeq: 4,
    sizeBytes: 32 * _gib,
    model: 'Example USB Stick',
    transport: 'usb',
    removable: true,
    mountpoints: ['/iso'],
  ),
  DiskInfo(
    path: '/dev/sdc',
    name: 'sdc',
    diskSeq: 5,
    sizeBytes: 2000398934016,
    model: 'Example USB Drive 2TB',
    transport: 'usb',
    removable: true,
  ),
];

List<WifiAp> mockWifi() => const [
  WifiAp(ssid: 'Living Room', signal: 82, secured: true),
  WifiAp(ssid: 'Neighbour 5G', signal: 55, secured: true),
  WifiAp(ssid: 'Cafe Guest', signal: 33, secured: false),
  WifiAp(ssid: 'Office (802.1X)', signal: 20, secured: true, supported: false),
];

/// The apps the installer offers: the real-format catalog fixture's
/// `installer` entries, with placeholder vendor terms (the real ones come from
/// the ISO's catalog index).
List<StoreApp> mockInstallerCatalog() => [
  for (final a in mockCatalog())
    if (a.installer) a,
];

/// Newer releases on both channels: a stable 0.7.1 and a beta 0.7.2 (each
/// release has its own version).
Map<InstallChannel, HinterRelease> mockNewer() => {
  InstallChannel.stable: const HinterRelease(
    rev: '9f8e7d6c5b4a39281706f5e4d3c2b1a098765432',
    version: '0.7.1',
  ),
  InstallChannel.beta: const HinterRelease(
    rev: '5e4d3c2b1a0918273645f5e4d3c2b1a098765abc',
    version: '0.7.2',
  ),
};
