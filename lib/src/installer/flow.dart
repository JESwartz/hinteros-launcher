import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ui/app_selection.dart';
import 'backend.dart';
import 'plan.dart';
import 'progress.dart';

/// One app in the second stage of the install.
enum AppInstallState { waiting, installing, done, failed }

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
  InstallerFlow(
    this.backend, {
    this.checkTimeout = const Duration(seconds: 10),
  });

  /// How long a network check or Wi-Fi scan may take before it is given up.
  final Duration checkTimeout;

  final InstallerBackend backend;

  InstallerStep _step = InstallerStep.welcome;
  InstallerStep get step => _step;

  void go(InstallerStep s) {
    if (s == _step) return;
    _step = s;
    _syncWatch();
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

  /// A network check (cable, internet) is running.
  bool checking = false;
  bool connecting = false;
  String? networkMessage;

  /// A Wi-Fi network this installer joined (kept on the installed box).
  String? joinedSsid;
  String? _joinedPsk;

  bool get online => net?.online ?? false;

  // Steps that show the network state follow it live.
  bool get _watching =>
      _step == InstallerStep.network || _step == InstallerStep.apps;

  StreamSubscription<void>? _netSub;
  Timer? _netDebounce;
  bool _refreshAgain = false;

  void _syncWatch() {
    if (_watching) {
      _netSub ??= backend.watchNetwork().listen(
        _onNetworkEvent,
        onError: (_) {},
      );
    } else {
      _netSub?.cancel();
      _netSub = null;
      _netDebounce?.cancel();
      _netDebounce = null;
    }
  }

  Future<void> _onNetworkEvent(void _) async {
    // Losing the link means offline right now, without waiting for a probe.
    try {
      final link = await backend.networkLink().timeout(checkTimeout);
      if (!link.linkUp && _netSub != null) {
        net = link;
        apps?.dropDownloads();
        notifyListeners();
      }
    } catch (_) {}
    _netDebounce?.cancel();
    _netDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_netSub != null) refreshNetwork(quiet: true);
    });
  }

  @override
  void dispose() {
    _netSub?.cancel();
    _netDebounce?.cancel();
    super.dispose();
  }

  /// Reads the network afresh. [force] also makes NetworkManager check its
  /// connectivity again ("Check again"). [quiet]: no spinner (live updates).
  Future<void> refreshNetwork({bool force = false, bool quiet = false}) async {
    if (checking) {
      _refreshAgain = true;
      return;
    }
    checking = true;
    if (!quiet) notifyListeners();
    try {
      net = await backend.network(force: force).timeout(checkTimeout);
      networkMessage = null;
    } on InstallerException catch (e) {
      net = const NetworkState();
      networkMessage = e.message;
    } on TimeoutException {
      net = const NetworkState();
      networkMessage =
          'Checking took longer than ${checkTimeout.inSeconds} seconds. '
          'Choose "Check again" to try once more.';
    }
    checking = false;
    if (_refreshAgain) {
      _refreshAgain = false;
      unawaited(refreshNetwork(quiet: true));
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
      wifi = await backend.scanWifi().timeout(checkTimeout);
      networkMessage = null;
    } on InstallerException catch (e) {
      wifi = const [];
      networkMessage = e.message;
    } on TimeoutException {
      wifi = const [];
      networkMessage =
          'Searching for Wi-Fi took longer than ${checkTimeout.inSeconds} '
          'seconds. Choose "Search again" to try once more.';
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
      acceptedTerms: a.acceptances,
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

  /// Which of the two stages the install is in.
  InstallSection section = InstallSection.system;

  /// Progress of the system stage (0..100; 100 once the apps stage began).
  int get systemPercent =>
      section == InstallSection.apps || phase == InstallPhase.succeeded
      ? 100
      : percent;

  /// The apps stage, one entry per selected app (in the order of the plan).
  List<({String id, String name, AppInstallState state})> get appProgress => [
    for (final a in _planApps)
      (
        id: a.id,
        name: a.name,
        state: _appStates[a.id] ?? AppInstallState.waiting,
      ),
  ];

  List<({String id, String name})> _planApps = const [];
  final _appStates = <String, AppInstallState>{};

  /// Progress of the apps stage (0..100): apps finished or failed of those
  /// picked; with none picked, what the backend says.
  int get appsPercent {
    if (phase == InstallPhase.succeeded) return 100;
    if (section != InstallSection.apps) return 0;
    if (_planApps.isEmpty) return percent;
    final finished = _planApps.where((a) {
      final s = _appStates[a.id];
      return s == AppInstallState.done || s == AppInstallState.failed;
    }).length;
    return (finished * 100 / _planApps.length).round();
  }

  /// "Installing default apps [1/3]: Firefox" while the apps stage runs.
  String? get appsLine {
    if (section != InstallSection.apps || _planApps.isEmpty) return null;
    var i = _planApps.indexWhere(
      (a) => _appStates[a.id] == AppInstallState.installing,
    );
    if (i < 0) {
      i = _planApps.indexWhere((a) {
        final s = _appStates[a.id];
        return s != AppInstallState.done && s != AppInstallState.failed;
      });
    }
    if (i < 0) i = _planApps.length - 1;
    return 'Installing default apps [${i + 1}/${_planApps.length}]: '
        '${_planApps[i].name}';
  }

  /// Names of the apps that could not be installed.
  List<String> get failedAppNames => [
    for (final id in _failedIds) _appName(id),
  ];
  final _failedIds = <String>[];

  String _appName(String id) {
    for (final a in _planApps) {
      if (a.id == id) return a.name;
    }
    return id;
  }

  void _noteApps(InstallEvent e) {
    if (e.phase != InstallSection.apps) return;
    section = InstallSection.apps;
    final id = e.app;
    if (id != null) {
      if (e.code == 'app-failed') {
        _fail(id);
      } else if (_appStates[id] != AppInstallState.failed) {
        // The previous app is over when the next one starts.
        for (final k in _appStates.keys.toList()) {
          if (k != id && _appStates[k] == AppInstallState.installing) {
            _appStates[k] = AppInstallState.done;
          }
        }
        _appStates[id] = AppInstallState.installing;
      }
    }
    if (e.stage == 'done' && e.level != InstallLevel.error) {
      e.failedApps.forEach(_fail);
      for (final k in _appStates.keys.toList()) {
        if (_appStates[k] != AppInstallState.failed) {
          _appStates[k] = AppInstallState.done;
        }
      }
    }
  }

  void _fail(String id) {
    _appStates[id] = AppInstallState.failed;
    if (!_failedIds.contains(id)) _failedIds.add(id);
  }

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
    section = InstallSection.system;
    _failedIds.clear();
    _appStates.clear();
    _planApps = [for (final a in apps!.selectedApps) (id: a.id, name: a.name)];
    phase = InstallPhase.validating;
    notifyListeners();

    void onEvent(InstallEvent e) {
      _noteApps(e);
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
      section = InstallSection.system;
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
