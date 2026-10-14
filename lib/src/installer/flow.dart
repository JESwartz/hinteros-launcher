import 'dart:async';

import 'package:flutter/foundation.dart';

import '../log.dart';
import '../system/daemon_system.dart' show releaseName;
import '../system/models.dart' show UpdateChannel;
import '../ui/app_selection.dart';
import '../ui/jobs.dart' show elapsedText;
import 'backend.dart';
import 'plan.dart';
import 'progress.dart';

/// "HinterOS 0.7.0 stable (1a2b3c4)": a release named the way the launcher
/// names it on a box of [channel] (a beta is the next patch plus the
/// commit, "HinterOS 0.7.1.1a2b3c4 beta"), with the short commit unless
/// the name already has it.
String installVersionLabel(String version, String rev, InstallChannel channel) {
  final name = releaseName(
    version,
    rev,
    channel == InstallChannel.beta ? UpdateChannel.beta : UpdateChannel.stable,
  );
  final short = rev.length >= 7 ? rev.substring(0, 7) : rev;
  return name.contains(short) ? 'HinterOS $name' : 'HinterOS $name ($short)';
}

/// One app in the second stage of the install.
enum AppInstallState { waiting, installing, done, failed }

enum InstallerStep {
  welcome('Welcome'),
  network('Internet'),

  /// Only when a newer HinterOS than the installer's is on the channel.
  version('HinterOS version'),
  disk('Disk'),
  account('Admin account'),
  options('Options'),
  apps('Apps'),
  summary('Summary'),
  install('Installing'),
  done('Done');

  const InstallerStep(this.title);
  final String title;

  /// The question screens (Internet .. Summary) show "Step 3 of 6": see
  /// [InstallerFlow.questionNumber].
  bool get isQuestion => index >= network.index && index <= summary.index;
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
    this.pollInterval = const Duration(seconds: 1),
    this.connectTimeout = const Duration(seconds: 30),
    this.plugGrace = const Duration(seconds: 5),
    this.probeRetries = 3,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// The time now (tests fix it): how long a package has been building.
  final DateTime Function() clock;

  /// How long a network check or Wi-Fi scan may take before it is given up.
  final Duration checkTimeout;

  /// While a connection is coming up: how often the network is looked at
  /// again, and how long to wait for it before saying "not connected".
  final Duration pollInterval;
  final Duration connectTimeout;

  /// After "Check again" with nothing connected: how long to watch for a
  /// just-plugged cable to start connecting.
  final Duration plugGrace;

  /// Extra tries of the internet probe when the link is up but the probe
  /// fails (DNS and the route can lag a moment behind "connected").
  final int probeRetries;

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
  /// offline too). After the internet step, and after the options when the
  /// channel changed, comes the version step if a newer HinterOS is there.
  void next() {
    switch (_step) {
      case InstallerStep.network:
        unawaited(
          _askVersion(
            after: InstallerStep.disk,
            before: InstallerStep.network,
            fromNetwork: true,
          ),
        );
      case InstallerStep.version:
        go(_versionNext);
      case InstallerStep.options:
        // Asks again for another channel, or when the offer was not answered.
        if (online &&
            (_checkedChannel != channel ||
                (versionOffered && _answeredRev != newer!.rev))) {
          unawaited(
            _askVersion(
              after: InstallerStep.apps,
              before: InstallerStep.options,
            ),
          );
        } else {
          go(InstallerStep.apps);
        }
      case InstallerStep.done:
        break;
      default:
        go(InstallerStep.values[_step.index + 1]);
    }
  }

  /// Whether Back does anything here.
  bool get canGoBack =>
      _step != InstallerStep.welcome &&
      _step != InstallerStep.install &&
      _step != InstallerStep.done;

  void back() {
    if (!canGoBack) return;
    switch (_step) {
      case InstallerStep.version:
        _askToken++; // a check still running no longer moves on
        go(_versionBack);
      case InstallerStep.disk:
        go(versionOffered ? InstallerStep.version : InstallerStep.network);
      default:
        go(InstallerStep.values[_step.index - 1]);
    }
  }

  /// "Step n of N" on the question screens: the version step counts only
  /// when a newer HinterOS is offered.
  int get questionCount =>
      InstallerStep.summary.index -
      InstallerStep.network.index +
      (versionOffered ? 1 : 0);

  int questionNumber(InstallerStep s) {
    final n = s.index - InstallerStep.network.index + 1;
    return !versionOffered && s.index > InstallerStep.version.index ? n - 1 : n;
  }

  // ------------------------------------------------------------- version

  /// How long a check for a newer HinterOS may take before it is given up
  /// (the backend stops its own network steps after 120 s).
  static const checkNewerTimeout = Duration(seconds: 150);

  /// A check for a newer HinterOS is running.
  bool checkingNewer = false;

  /// The last check that worked; null before one did, or when the last
  /// one failed.
  NewerCheck? newerCheck;

  /// The installer's own release, once `--info` or a check reported it.
  HinterRelease? isoRelease;

  /// Reads the installer's own release and channel (`--info`, offline) at
  /// the start. The channel becomes the default of the Options step unless
  /// the person already chose one. When it fails: logged, and the version
  /// and channel come from the first check, as before.
  Future<void> loadInfo() async {
    try {
      final r = await backend.info().timeout(checkTimeout);
      if (_disposed) return;
      isoRelease ??= r.iso;
      if (!_channelTouched && !_defaultKnown) channel = r.channel;
    } catch (e) {
      logFailure('reading the installer version', e);
      return;
    }
    notifyListeners();
  }

  /// The channel the last check (good or failed) was for; null: none yet.
  InstallChannel? _checkedChannel;
  bool _lastCheckOk = false;
  bool _defaultKnown = false;
  bool _channelTouched = false;
  Future<void>? _checkRun;
  int _askToken = 0;

  /// Where the version step goes on to, and back to.
  InstallerStep _versionNext = InstallerStep.disk;
  InstallerStep _versionBack = InstallerStep.network;

  /// The newer revision the person chose; null: the installer's own.
  String? chosenRev;

  /// The newer revision the person last answered about (either way).
  String? _answeredRev;

  /// The newer HinterOS of the chosen channel, when one is offered (only
  /// while online).
  HinterRelease? get newer {
    final c = newerCheck;
    return online && c != null && c.channel == channel ? c.newer : null;
  }

  bool get versionOffered => newer != null;

  /// Whether the plan installs the newer HinterOS.
  bool get installsNewer => chosenRev != null && newer?.rev == chosenRev;

  /// "HinterOS 0.7.0 stable (1a2b3c4)" for a release on the chosen channel.
  String releaseLabel(HinterRelease r) =>
      installVersionLabel(r.version, r.rev, channel);

  /// The version the plan installs, for the summary.
  String get planVersionLabel {
    final n = newer;
    if (installsNewer && n != null) return releaseLabel(n);
    final iso = isoRelease;
    return iso == null ? 'HinterOS from this USB stick' : releaseLabel(iso);
  }

  /// Shows the version step when the internet is there and a newer
  /// HinterOS is on the channel; otherwise goes straight to [after]. Checks
  /// the channel first unless the last check already answered for it.
  Future<void> _askVersion({
    required InstallerStep after,
    required InstallerStep before,
    bool fromNetwork = false,
    bool force = false,
  }) async {
    final token = ++_askToken;
    _versionNext = after;
    _versionBack = before;
    if (!online) {
      go(after);
      return;
    }
    final known = !force && _checkedChannel == channel;
    if (known && (_lastCheckOk || !fromNetwork)) {
      go(versionOffered ? InstallerStep.version : after);
      return;
    }
    go(InstallerStep.version);
    // A check already running may be for another channel: then once more.
    for (var i = 0; i < 2; i++) {
      await _checkNewer(adoptDefault: fromNetwork);
      if (_disposed || token != _askToken) return;
      if (_checkedChannel == channel) break;
    }
    if (_step == InstallerStep.version && !versionOffered) go(after);
  }

  Future<void> _checkNewer({required bool adoptDefault}) =>
      _checkRun ??= _check(adoptDefault).whenComplete(() => _checkRun = null);

  Future<void> _check(bool adoptDefault) async {
    checkingNewer = true;
    notifyListeners();
    // The first check asks for the installer's own channel and takes it as
    // the default, unless the person already chose one.
    final useDefault = adoptDefault && !_channelTouched && !_defaultKnown;
    final asked = channel;
    try {
      final r = await backend
          .checkNewer(channel: useDefault ? null : asked)
          .timeout(checkNewerTimeout);
      isoRelease = r.iso;
      newerCheck = r;
      if (useDefault && !_channelTouched) channel = r.channel;
      _defaultKnown = true;
      _checkedChannel = r.channel;
      _lastCheckOk = true;
    } catch (e) {
      // Not offered, then: the installer's own version is installed.
      logFailure('checking for a newer HinterOS', e);
      newerCheck = null;
      _checkedChannel = asked;
      _lastCheckOk = false;
    }
    if (chosenRev != null && newer?.rev != chosenRev) chosenRev = null;
    checkingNewer = false;
    if (!_disposed) notifyListeners();
  }

  /// The person's answer on the version step.
  void chooseVersion({required bool newer}) {
    _answeredRev = this.newer?.rev;
    chosenRev = newer ? this.newer?.rev : null;
    go(_versionNext);
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
  bool _refreshAgainForce = false;
  bool _disposed = false;

  /// A check is waiting for a connection that is still coming up.
  bool waitingForLink = false;

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
    _disposed = true;
    _pollTimer?.cancel();
    _pollWake?.complete();
    _netSub?.cancel();
    _netDebounce?.cancel();
    super.dispose();
  }

  /// Reads the network afresh. [force] also makes NetworkManager check its
  /// connectivity again ("Check again"). [quiet]: no spinner (live updates).
  /// [plugWait]: the person asked ("Check again"), so a cable that was only
  /// just plugged in gets [plugGrace] to start connecting.
  Future<void> refreshNetwork({
    bool force = false,
    bool quiet = false,
    bool plugWait = false,
  }) async {
    if (checking) {
      _refreshAgain = true;
      _refreshAgainForce |= force;
      return;
    }
    checking = true;
    if (!quiet) notifyListeners();
    try {
      net = await _settledNetwork(force: force, plugWait: plugWait);
      networkMessage = null;
    } on InstallerException catch (e) {
      net = const NetworkState();
      networkMessage = e.message;
    } on TimeoutException {
      net = const NetworkState();
      networkMessage = 'The check took too long. Choose "Check again".';
    }
    checking = false;
    waitingForLink = false;
    if (_refreshAgain) {
      final again = _refreshAgainForce;
      _refreshAgain = false;
      _refreshAgainForce = false;
      unawaited(refreshNetwork(force: again, quiet: true));
    }
    // Apps that need a download cannot stay ticked offline.
    if (!online) apps?.dropDownloads();
    notifyListeners();
  }

  Timer? _pollTimer;
  Completer<void>? _pollWake;

  /// A pause that [dispose] cuts short.
  Future<void> _pause(Duration d) {
    final c = _pollWake = Completer<void>();
    _pollTimer = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  /// Looks at the network until it has settled: online, or nothing is coming
  /// up any more. A connection NetworkManager is bringing up is waited for
  /// (up to [connectTimeout]); after "Check again" a cable that was just
  /// plugged in gets [plugGrace] to start connecting; and when the link is up
  /// but the probe fails, the probe is tried [probeRetries] more times.
  Future<NetworkState> _settledNetwork({
    required bool force,
    required bool plugWait,
  }) async {
    // Counted in poll intervals, not read from the clock (tests fake time).
    var elapsed = Duration.zero;
    var probes = 0;
    var forceNow = force;
    while (true) {
      final s = await backend.network(force: forceNow).timeout(checkTimeout);
      forceNow = false;
      if (s.online || _disposed) return s;
      final wait = s.linkUp
          ? probes++ < probeRetries
          : (s.connecting
                ? elapsed < connectTimeout
                : ((plugWait || s.cableWaiting) && elapsed < plugGrace));
      if (!wait) return s;
      // Show "Connecting..." instead of a verdict while it goes on.
      net = s;
      waitingForLink = !s.linkUp;
      notifyListeners();
      await _pause(pollInterval);
      elapsed += pollInterval;
      if (_disposed) return s;
    }
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
      networkMessage = 'The Wi-Fi search took too long. Choose "Search again".';
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
      return 'The passwords do not match.';
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
    _channelTouched = true;
    // A newer version of the other channel is not this one's.
    if (chosenRev != null && newer?.rev != chosenRev) chosenRev = null;
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
      rev: installsNewer ? chosenRev : null,
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

  List<({String id, String name, bool onIso})> _planApps = const [];
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

  /// Progress of the stage or app being worked on, on its own (0..100); null
  /// when the backend cannot measure it (an indeterminate bar).
  int? stepPercent;
  String _stepKey = '';

  /// The app the apps stage is working on now; null before the first one and
  /// while the finished apps are being activated.
  String? _currentAppId;
  int? _currentAppIndex;
  int? _currentAppTotal;
  bool _appsBegun = false;

  void _noteStep(InstallEvent e) {
    final key = '${e.phase.name}/${e.stage}/${e.app ?? ''}';
    if (key != _stepKey) {
      _stepKey = key;
      stepPercent = null;
    }
    if (e.stepPercent != null) stepPercent = e.stepPercent;
  }

  /// "Downloading Steam · 2 of 3" while an app is being installed (apps that
  /// come with the installer are "Installing"); other words between apps.
  String? get appsLine {
    if (section != InstallSection.apps) return null;
    final id = _currentAppId;
    if (id != null) {
      final total = _currentAppTotal ?? _planApps.length;
      final plan = _planApps.indexWhere((a) => a.id == id);
      final index = _currentAppIndex ?? (plan < 0 ? 1 : plan + 1);
      final onIso = plan < 0 || _planApps[plan].onIso;
      return '${onIso ? 'Installing' : 'Downloading'} ${_appName(id)}'
          '${total > 1 ? ' · $index of $total' : ''}';
    }
    if (_planApps.isEmpty) return null;
    return _appsBegun ? 'Finishing the apps' : 'Preparing the apps';
  }

  /// The package the `build` stage is building now (null when nothing is
  /// building, or in another stage), its 1-based position and the count.
  String? buildName;
  int? buildIndex;
  int? buildTotal;

  /// When [buildName] was first seen.
  DateTime? buildSince;

  void _noteBuild(InstallEvent e) {
    final name = e.phase == InstallSection.system && e.stage == 'build'
        ? e.build
        : null;
    if (name != buildName) buildSince = name == null ? null : clock();
    buildName = name;
    buildIndex = name == null ? null : e.buildIndex;
    buildTotal = name == null ? null : e.buildTotal;
  }

  /// "Building hinteros-launcher (3 of 12). Time elapsed: 06:12": the package
  /// being built and the time since it started (mm:ss); null when nothing is
  /// building.
  String? get buildLine {
    final name = buildName;
    if (name == null) return null;
    final since = buildSince;
    final elapsed = since == null ? Duration.zero : clock().difference(since);
    final i = buildIndex;
    final n = buildTotal;
    final count = i != null && n != null ? ' ($i of $n)' : '';
    return 'Building $name$count. Time elapsed: ${elapsedText(elapsed)}';
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
      _currentAppId = id;
      _currentAppIndex = e.appIndex;
      _currentAppTotal = e.appTotal;
      _appsBegun = true;
    } else if (e.stage != 'done') {
      _currentAppId = null;
    }
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
    runRev = plan.rev;
    runLabel = planVersionLabel;
    _runChannel = plan.channel;
    _doneEvent = null;
    outcome = null;
    warnings = const [];
    percent = 0;
    progressStage = 'validate';
    progressMessage = '';
    section = InstallSection.system;
    _failedIds.clear();
    _appStates.clear();
    _planApps = [
      for (final a in apps!.selectedApps)
        (id: a.id, name: a.name, onIso: a.onIso),
    ];
    stepPercent = null;
    _stepKey = '';
    _currentAppId = null;
    _currentAppIndex = null;
    _currentAppTotal = null;
    _appsBegun = false;
    buildName = null;
    buildIndex = null;
    buildTotal = null;
    buildSince = null;
    phase = InstallPhase.validating;
    notifyListeners();

    void onEvent(InstallEvent e) {
      _noteApps(e);
      _noteStep(e);
      _noteBuild(e);
      progressStage = e.stage;
      percent = e.percent;
      progressMessage = e.message;
      if (e.isDone) _doneEvent = e;
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

  /// The newer revision the last run installed or tried to (null: the
  /// installer's own).
  String? runRev;

  /// The version the last run installed or tried to, for the screens.
  String runLabel = '';
  InstallChannel _runChannel = InstallChannel.stable;
  InstallEvent? _doneEvent;

  /// The stages of the current run, in order.
  List<String> get stages =>
      runRev != null ? newerInstallStages : installStages;

  /// [stage] in plain words for the current run (a newer HinterOS downloads
  /// its packages; the installer's own copies them from the USB stick).
  String stageName(String stage) => stageLabel(stage, download: runRev != null);

  /// The last run with a newer HinterOS was refused or failed.
  bool get newerFailed =>
      runRev != null &&
      (phase == InstallPhase.failed || phase == InstallPhase.refused);

  /// Whether the failed run stopped before it touched the disk: refused,
  /// or the newer HinterOS did not download.
  bool get diskUntouched =>
      phase == InstallPhase.refused || outcome?.error?.code == 'fetch-failed';

  /// From a failed newer install back to the version step (the channel is
  /// checked again); the choice then goes on to the summary.
  void chooseVersionAgain() {
    phase = InstallPhase.idle;
    outcome = null;
    unawaited(
      _askVersion(
        after: InstallerStep.summary,
        before: InstallerStep.summary,
        force: true,
      ),
    );
  }

  /// "HinterOS 0.7.1 stable (9f8e7d6)": what the finished install put on
  /// the disk, from the backend's last line; null when it did not say.
  String? get installedLabel {
    final e = _doneEvent;
    final v = e?.version;
    final r = e?.rev;
    if (v == null || r == null) return null;
    return installVersionLabel(v, r, _runChannel);
  }

  Future<void> reboot() => backend.reboot();
}
