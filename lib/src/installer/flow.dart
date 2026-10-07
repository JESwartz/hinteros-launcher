import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ui/app_selection.dart';
import 'backend.dart';
import 'plan.dart';
import 'progress.dart';

enum InstallerStep {
  welcome('Welcome'),
  network('Internet'),
  disk('Disk'),
  account('Admin account'),
  options('Options'),
  apps('Apps'),
  summary('Summary'),
  install('Installing'),
  done('Done');

  const InstallerStep(this.title);
  final String title;

  /// "Step 3 of 6" for the question screens (Internet .. Summary).
  bool get isQuestion => index >= network.index && index <= summary.index;
  static int get questionCount => summary.index - network.index + 1;
  int get questionNumber => index - network.index + 1;
}

/// Where the install itself is.
enum InstallPhase {
  idle,
  validating,
  installing,
  succeeded,

  /// Exit 2: refused, nothing was touched.
  refused,

  /// Exit 1: failed part-way, the disk may have been changed.
  failed,
}

/// The installer's answers and its progress: everything the screens show
/// and change. Talks to the machine only through [backend].
class InstallerFlow extends ChangeNotifier {
  InstallerFlow(this.backend);

  final InstallerBackend backend;

  InstallerStep _step = InstallerStep.welcome;
  InstallerStep get step => _step;

  void go(InstallerStep s) {
    if (s == _step) return;
    _step = s;
    notifyListeners();
  }

  /// The step after the current one (apps are skipped never: they work
  /// offline too).
  void next() {
    if (_step.index < InstallerStep.done.index) {
      go(InstallerStep.values[_step.index + 1]);
    }
  }

  /// Whether Back does anything here.
  bool get canGoBack =>
      _step != InstallerStep.welcome &&
      _step != InstallerStep.install &&
      _step != InstallerStep.done;

  void back() {
    if (canGoBack) go(InstallerStep.values[_step.index - 1]);
  }

  // ------------------------------------------------------------- network

  NetworkState? net;
  List<WifiAp> wifi = const [];
  bool scanning = false;
  bool connecting = false;
  String? networkMessage;

  /// A Wi-Fi network this installer joined (kept on the installed box).
  String? joinedSsid;
  String? _joinedPsk;

  bool get online => net?.online ?? false;

  Future<void> refreshNetwork() async {
    try {
      net = await backend.network();
      networkMessage = null;
    } on InstallerException catch (e) {
      net = const NetworkState();
      networkMessage = e.message;
    }
    // Apps that need a download cannot stay ticked offline.
    if (!online) apps?.dropDownloads();
    notifyListeners();
  }

  Future<void> scanWifi() async {
    if (scanning) return;
    scanning = true;
    notifyListeners();
    try {
      wifi = await backend.scanWifi();
      networkMessage = null;
    } on InstallerException catch (e) {
      wifi = const [];
      networkMessage = e.message;
    }
    scanning = false;
    notifyListeners();
  }

  /// Joins [ap]; false (with [networkMessage]) when it did not work.
  Future<bool> joinWifi(WifiAp ap, {String? psk}) async {
    connecting = true;
    networkMessage = null;
    notifyListeners();
    var ok = false;
    try {
      await backend.connectWifi(ap.ssid, psk: psk);
      joinedSsid = ap.ssid;
      _joinedPsk = ap.secured ? psk : null;
      ok = true;
    } on InstallerException catch (e) {
      networkMessage = e.message;
    }
    connecting = false;
    final message = networkMessage;
    await refreshNetwork();
    // The refresh clears the message; a failed join keeps its reason.
    networkMessage = message;
    notifyListeners();
    return ok;
  }

  // ---------------------------------------------------------------- disk

  List<DiskInfo>? disks;
  String? disksMessage;
  DiskInfo? disk;

  Future<void> loadDisks() async {
    try {
      disks = await backend.disks();
      disksMessage = null;
    } on InstallerException catch (e) {
      disks = const [];
      disksMessage = e.message;
    } on FormatException {
      disks = const [];
      disksMessage = 'The list of disks could not be read.';
    }
    final d = disk;
    if (d != null && !disks!.any((x) => x.path == d.path && x.usable)) {
      disk = null;
    }
    notifyListeners();
  }

  void chooseDisk(DiskInfo? d) {
    disk = d;
    notifyListeners();
  }

  // ------------------------------------------------------------- account

  String username = '';
  String password = '';
  String repeat = '';

  void setUsername(String v) {
    username = v;
    notifyListeners();
  }

  void setPassword(String v) {
    password = v;
    notifyListeners();
  }

  void setRepeat(String v) {
    repeat = v;
    notifyListeners();
  }

  String? get usernameProblem => PlanChecks.username(username);
  String? get passwordProblem => PlanChecks.password(password);
  bool get passwordsMatch => password == repeat;

  /// What is wrong with the account so far, for the screen; null when fine.
  /// Silent about fields the person has not touched yet.
  String? get accountProblem {
    if (username.isNotEmpty && usernameProblem != null) return usernameProblem;
    if (password.isNotEmpty && passwordProblem != null) return passwordProblem;
    if (repeat.isNotEmpty && !passwordsMatch) {
      return 'The two passwords are not the same.';
    }
    return null;
  }

  bool get accountValid =>
      usernameProblem == null && passwordProblem == null && passwordsMatch;

  // ------------------------------------------------------------- options

  String hostname = 'hinteros';
  bool ssh = false;
  InstallChannel channel = InstallChannel.stable;

  void setHostname(String v) {
    hostname = v;
    notifyListeners();
  }

  void toggleSsh() {
    ssh = !ssh;
    notifyListeners();
  }

  void toggleChannel() {
    channel = channel == InstallChannel.stable
        ? InstallChannel.beta
        : InstallChannel.stable;
    notifyListeners();
  }

  String? get hostnameProblem => PlanChecks.hostname(hostname);

  // ---------------------------------------------------------------- apps

  AppSelectionController? apps;
  String? catalogMessage;

  Future<void> loadCatalog() async {
    if (apps != null) return;
    try {
      apps = AppSelectionController(await backend.catalog());
    } on InstallerException catch (e) {
      catalogMessage = e.message;
      apps = AppSelectionController(const []);
    }
    if (!online) apps!.dropDownloads();
    notifyListeners();
  }

  // ---------------------------------------------------------------- plan

  bool get ready =>
      disk != null && accountValid && hostnameProblem == null && apps != null;

  /// The plan, from the answers. Only call when [ready].
  InstallPlan buildPlan() {
    final a = apps!;
    final needsDownload = a.selectedApps.any((x) => !x.onIso);
    return InstallPlan(
      disk: disk!.path,
      hostname: hostname,
      adminUser: username,
      adminPassword: password,
      ssh: ssh,
      channel: channel,
      network: !online
          ? PlanNetwork.offline
          : (needsDownload ? PlanNetwork.online : PlanNetwork.auto),
      apps: [for (final x in a.selectedApps) x.id],
      wifiSsid: online ? joinedSsid : null,
      wifiPsk: online && joinedSsid != null ? _joinedPsk : null,
    );
  }

  // ------------------------------------------------------------- install

  InstallPhase phase = InstallPhase.idle;
  String progressStage = 'validate';
  int percent = 0;
  String progressMessage = '';
  List<InstallEvent> warnings = const [];
  InstallOutcome? outcome;

  bool get running =>
      phase == InstallPhase.validating || phase == InstallPhase.installing;

  /// Checks the plan (`--validate-only`), then installs. Ends in
  /// [InstallPhase.succeeded], [InstallPhase.refused] or
  /// [InstallPhase.failed]; the screens follow [phase].
  Future<void> startInstall() async {
    if (running || !ready) return;
    final plan = buildPlan();
    outcome = null;
    warnings = const [];
    percent = 0;
    progressStage = 'validate';
    progressMessage = '';
    phase = InstallPhase.validating;
    notifyListeners();

    void onEvent(InstallEvent e) {
      progressStage = e.stage;
      percent = e.percent;
      progressMessage = e.message;
      if (e.isWarning) warnings = [...warnings, e];
      notifyListeners();
    }

    var o = await followRun(backend.validate(plan), onEvent: onEvent);
    if (o.verdict == InstallVerdict.success) {
      warnings = const [];
      percent = 0;
      phase = InstallPhase.installing;
      notifyListeners();
      o = await followRun(backend.install(plan), onEvent: onEvent);
    }
    outcome = o;
    phase = switch (o.verdict) {
      InstallVerdict.success => InstallPhase.succeeded,
      InstallVerdict.refused => InstallPhase.refused,
      InstallVerdict.failed => InstallPhase.failed,
    };
    if (phase == InstallPhase.succeeded) {
      // Nothing needs the password any more.
      password = '';
      repeat = '';
      _joinedPsk = null;
      _step = InstallerStep.done;
    }
    notifyListeners();
  }

  /// Back from a failed run to the summary.
  void leaveFailure() {
    phase = InstallPhase.idle;
    outcome = null;
    go(InstallerStep.summary);
  }

  Future<void> reboot() => backend.reboot();
}
