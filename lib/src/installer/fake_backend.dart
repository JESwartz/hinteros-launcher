import 'dart:async';
import 'dart:convert';

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
  ]) => InstallEvent(
    stage: stage,
    percent: percent,
    level: level,
    message: message,
    code: code,
  );

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
    _e('install', 32, 'Copying flake inputs to the new system'),
    _e('install', 36, 'Building and installing the system'),
    _e('install', 57, 'Installing: 57 of 100 steps'),
    _e('install', 90, 'System installed, boot loader written'),
    _e('snapshot', 92, 'Checking the config snapshot'),
    _e('snapshot', 95, '/etc/hinteros matches the installed generation'),
    _e('finalize', 97, 'Flushing to disk'),
    _e('done', 100, 'HinterOS is installed. Remove the installer medium.'),
  ], 0);

  /// A whole two-stage install: the system, then each of [apps]; the ones
  /// in [failing] end with an `app-failed` warning (the exit status stays 0).
  static FakeScript twoStage(
    List<String> apps, {
    List<String> failing = const [],
  }) {
    InstallEvent sys(String stage, int pct, String m) => InstallEvent(
      stage: stage,
      percent: pct,
      level: InstallLevel.info,
      message: m,
    );
    InstallEvent app(int pct, String m, String id, [String? code]) =>
        InstallEvent(
          stage: 'install',
          percent: pct,
          level: code == null ? InstallLevel.info : InstallLevel.warn,
          message: m,
          code: code,
          phase: InstallSection.apps,
          app: id,
        );
    final n = apps.length;
    return FakeScript([
      sys('validate', 0, 'Checking the plan'),
      sys('validate', 8, 'Plan accepted'),
      sys('partition', 20, 'Disk is partitioned and mounted'),
      sys('config', 30, 'Device configuration written'),
      sys('install', 57, 'Installing the system'),
      sys('snapshot', 90, 'Checking the config snapshot'),
      sys('finalize', 97, 'System installed'),
      for (var i = 0; i < n; i++) ...[
        app(97 + 3 * i ~/ n, 'Installing ${apps[i]}', apps[i]),
        if (failing.contains(apps[i]))
          app(
            97 + 3 * (i + 1) ~/ n,
            '${apps[i]} could not be installed',
            apps[i],
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
    _e('install', percent, 'Installing', InstallLevel.info),
    _e('install', percent, message, InstallLevel.error, code),
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
  }) : _wifi = wifi ?? mockWifi(),
       _disks = disks ?? mockDisks(),
       _catalog = catalog ?? mockInstallerCatalog();

  /// What `network()` reports; joining Wi-Fi changes it.
  NetworkState state;

  /// When set, `network()` / `scanWifi()` wait for these before answering
  /// (a slow check, for tests).
  Future<void>? networkHold;
  Future<void>? scanHold;
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

  /// Every call, in order: `network`, `scanWifi`, `connectWifi:<ssid>`,
  /// `disks`, `catalog`, `validate`, `install`, `reboot`.
  final calls = <String>[];

  /// The plan of every `validate` / `install` call as the backend would get
  /// it on stdin (UTF-8 JSON). Contains the password: this is a fake.
  final stdinPlans = <String>[];

  /// `stdinPlans` decoded.
  List<Map<String, Object?>> get plans => [
    for (final p in stdinPlans) jsonDecode(p) as Map<String, Object?>,
  ];

  bool get rebooted => calls.contains('reboot');

  @override
  Future<NetworkState> network() async {
    calls.add('network');
    await networkHold;
    return state;
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

  @override
  Future<List<DiskInfo>> disks() async {
    calls.add('disks');
    return List.of(_disks);
  }

  @override
  Future<List<StoreApp>> catalog() async {
    calls.add('catalog');
    return List.of(_catalog);
  }

  InstallRun _run(String call, InstallPlan plan, FakeScript script) {
    calls.add(call);
    stdinPlans.add(utf8.decode(plan.encode()));
    final c = StreamController<InstallEvent>();
    final done = Completer<int>();
    unawaited(() async {
      for (final e in script.events) {
        await Future<void>.delayed(delay);
        c.add(e);
      }
      await c.close();
      done.complete(script.exitCode);
    }());
    return InstallRun(c.stream, done.future);
  }

  @override
  InstallRun validate(InstallPlan plan) =>
      _run('validate', plan, validateScript ?? FakeScript.validateOk);

  @override
  InstallRun install(InstallPlan plan) => _run(
    'install',
    plan,
    installScript ?? installScriptFor?.call(plan) ?? FakeScript.installOk,
  );

  @override
  Future<void> reboot() async => calls.add('reboot');
}

const _gib = 1024 * 1024 * 1024;

/// A machine with an internal NVMe disk, a second SATA disk, a small one,
/// the installer stick and a USB drive.
List<DiskInfo> mockDisks() => const [
  DiskInfo(
    path: '/dev/nvme0n1',
    name: 'nvme0n1',
    sizeBytes: 512110190592,
    model: 'Example NVMe 512GB',
    transport: 'nvme',
  ),
  DiskInfo(
    path: '/dev/sda',
    name: 'sda',
    sizeBytes: 1000204886016,
    model: 'Example SATA SSD 1TB',
    transport: 'sata',
  ),
  DiskInfo(
    path: '/dev/mmcblk0',
    name: 'mmcblk0',
    sizeBytes: 8 * _gib,
    model: 'Example eMMC 8GB',
    transport: null,
  ),
  DiskInfo(
    path: '/dev/sdb',
    name: 'sdb',
    sizeBytes: 32 * _gib,
    model: 'Example USB Stick',
    transport: 'usb',
    removable: true,
    mountpoints: ['/iso'],
  ),
  DiskInfo(
    path: '/dev/sdc',
    name: 'sdc',
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
