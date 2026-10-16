import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart' hide TimeZoneInfo, TimeZoneEntry;
import '../data/launcher_data.dart';
import '../fps_overlay.dart';
import '../nav/key_map.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../osk/osk_control.dart';
import '../settings/launcher_settings.dart';
import '../system/models.dart';
import '../system/repositories.dart';
import '../updates/reminder.dart';
import '../theme/hinter_theme.dart';
import 'apps_screen.dart';
import 'auth_prompt.dart';
import 'common.dart';
import 'dialogs.dart' show Choice, showChoice, showFailureOn;
import 'profiles/first_launch_terms.dart';
import 'profiles/profile_loading.dart';
import 'profiles/profile_ui.dart' show withBoxAdminPin;
import 'profiles/session_profile.dart';
import 'games_screen.dart';
import 'home_screen.dart';
import 'jobs.dart';
import 'modal_host.dart';
import 'overlays.dart';
import 'launching.dart';
import 'settings_screen.dart';
import 'store_flows.dart';
import 'store_screen.dart';
import 'update_banner.dart';
import 'widgets.dart' show StatusLine;
import 'pages.dart';
import 'restart_countdown.dart';
import 'session_ending.dart';
import 'tab_bar.dart';

enum Section {
  home('Home'),
  games('Games'),
  apps('Apps'),
  store('Store'),
  // Phase 2: only shown with the server flag.
  server('Server'),
  settings('Settings');

  const Section(this.label);
  final String label;
}

/// The top-level layout: a top bar with the section tabs, the current section
/// below. Owns the [NavController] and every [NavRegion], and is the single
/// place where keyboard and `input_nav` become navigation.
///
/// Rules (also in the README):
/// - Left/right never leave a row; up/down move between rows, each row
///   remembering its column; running off the top goes to the tab bar, off the
///   bottom stays.
/// - On the tab bar left/right wrap and the section follows focus; down enters
///   the section where you left it. While Steam needs attention its banner sits
///   between the tab bar and the content and is part of that vertical order.
/// - Back (B/Circle) on a running app or game asks to close it; the
///   confirm dialog takes all input until answered (Back cancels).
///   Secondary (X) opens Steam when its banner shows.
/// - Back elsewhere: detail pane to its list, section content to the Home tab; on Home it
///   does nothing. The Home button always goes to Home with the first card
///   focused. Page left/right (L1/R1) switch tabs from anywhere.
class LauncherShell extends StatefulWidget {
  const LauncherShell({
    super.key,
    required this.data,
    required this.settings,
    required this.services,
    this.now,
    this.showFps = false,
    this.showServer = false,
    this.startup,
  });

  final LauncherData data;
  final SettingsController settings;
  final SystemServices services;

  /// Who this session is, as known before the daemon answers: the shell
  /// shows "Loading Sam…" over Home until Home has its data (the same
  /// page the picker and the console showed). Null: no loading page.
  final LoadingIdentity? startup;

  /// Clock source; null means the real clock, ticking. A fixed function is
  /// for tests and goldens (no timer).
  final DateTime Function()? now;
  final bool showFps;

  /// Phase 2: shows the Server tab (placeholder).
  final bool showServer;

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell> {
  final _nav = NavController();
  final _tabs = NavRegion('tabs', rememberPerRow: false, wrapHorizontal: true);
  final _home = NavRegion('home');
  final _games = NavRegion('games', rememberPerRow: false);
  final _apps = NavRegion('apps', rememberPerRow: false);
  final _store = NavRegion('store-cats');
  final _storeGrid = NavRegion('store-grid', rememberPerRow: false);
  final _updateBanner = NavRegion('update-banner', rememberPerRow: false);
  final _settingsList = NavRegion('settings-list');
  final _settingsDetail = NavRegion('settings-detail');
  late final _settingsRegions = SettingsRegions(
    _nav,
    list: _settingsList,
    detail: _settingsDetail,
  );
  final _server = NavRegion('server');
  final _banner = NavRegion('banner', rememberPerRow: false);
  final _dialog = NavRegion('dialog', rememberPerRow: false);
  late final _modals = ModalController(_nav);
  // The admin password prompt: shown over whatever is on screen whenever
  // polkit asks (a relayed call such as ssh.set is waiting for it).
  late final AuthPrompter _authPrompts;

  /// The job the person left running: the top bar shows it, a notice
  /// says when it ends.
  late final JobCenter _jobs = JobCenter(widget.services.jobs)
    ..onFinished = _jobFinished;

  /// The launcher is in front: a restart offer counts down only then.
  late final _front = ValueNotifier<bool>(widget.data.inFront);
  bool _bannerVisible = false;
  bool _updateBannerVisible = false;
  late final UpdateReminders _reminders = UpdateReminders(
    widget.services.updates,
  );
  bool _dialogOpen = false;
  NavRegion? _beforeDialog;

  /// A context under the modal scope (for pages the session raises itself).
  BuildContext? _scopeContext;

  /// The session is ending on purpose (see [SessionEndingController]).
  late final _ending = SessionEndingController(
    connected: () => widget.data.status is Connected,
  );

  /// The ending page is up: no input, no errors, nothing else shows.
  bool get _endingShown =>
      _ending.showsPage(connected: widget.data.status is Connected);

  /// The current profile, first-boot mode, the lock screen, switching.
  late final ProfileSession _profile = ProfileSession(
    services: widget.services,
    modals: _modals,
    context: () => _scopeContext ?? context,
    running: () => widget.data.running,
    ending: _ending,
  );

  late final List<Section> _sections = [
    for (final s in Section.values)
      if (s != Section.server || widget.showServer) s,
  ];
  Section _section = Section.home;
  late DateTime _time = (widget.now ?? DateTime.now)();
  Timer? _clock;

  /// The box's zone (`time_zone.get`): the clock is UTC plus its offset,
  /// not the process's own zone (glibc reads that once). Null until the
  /// daemon answers: the process's zone meanwhile.
  TimeZoneInfo? _zone;

  /// Gets the zone again at its next offset change.
  Timer? _zoneTimer;
  final _subs = <StreamSubscription<Object?>>[];

  NavRegion _contentOf(Section s) => switch (s) {
    Section.home => _home,
    Section.games => _games,
    Section.apps => _apps,
    Section.store => _store,
    Section.settings => _settingsList,
    Section.server => _server,
  };

  @override
  void initState() {
    super.initState();
    for (final r in [
      _tabs,
      _home,
      _games,
      _apps,
      _store,
      _storeGrid,
      _updateBanner,
      _settingsList,
      _settingsDetail,
      _server,
      _banner,
      _dialog,
    ]) {
      _nav.adopt(r);
    }
    _tabs.setRows([NavRow('tabs', _sections.length)]);
    _relink();
    _store.neighbors[NavDir.right] = _storeGrid;
    _storeGrid.neighbors[NavDir.left] = _store;
    _storeGrid.backTarget = _store;
    // Links the list and the stacked sections of the pane.
    _settingsRegions.reset();
    _dialog.onBack = () {
      widget.data.cancelClose();
      return true;
    };
    _tabs.onBack = () {
      if (_section == Section.home) return false;
      _goHome(reset: false);
      return true;
    };
    _nav.onBack = () {
      if (_section == Section.home) return false;
      _goHome(reset: false);
      return true;
    };
    _nav.onOther = (a) {
      if (_dialogOpen || _modals.isOpen) return;
      if (a == NavAction.secondary && _bannerVisible) {
        unawaited(widget.data.focusSteam());
      }
      final i = _sections.indexOf(_section);
      if (a == NavAction.pageLeft) _selectSection(i - 1);
      if (a == NavAction.pageRight) _selectSection(i + 1);
    };

    final d = widget.data;
    d.beforeLaunch = (app) {
      final c = _scopeContext;
      if (c == null) return Future.value(false);
      return firstLaunchTerms(c, widget.services, app, data: d);
    };
    d.chooseAppToClose = (name, running) {
      final c = _scopeContext;
      if (c == null) return Future.value(null);
      return showChoice<String>(
        c,
        title: 'Close an app to open $name',
        choices: [for (final r in running) Choice(r.name, r.id)],
      );
    };
    d.start();
    d.addListener(_onData);
    if (_grace) {
      _graceTimer = Timer(startupGrace, () {
        if (mounted) setState(() => _grace = false);
      });
    }
    if (_loading) {
      d.addListener(_checkLoading);
      _loadingCap = Timer(_loadingMax, _endLoading);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkLoading());
    }
    _profile.addListener(_onProfile);
    _jobs.addListener(_onJobs);
    _ending.addListener(_onEnding);
    widget.settings.addListener(_mirrorAppearance);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_profile.start()),
    );
    // A job that runs on the box (the launcher restarted during it).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_jobs.reattach()),
    );
    _subs.add(
      d.connection.statusChanges.listen((s) {
        if (s is! Connected) {
          // Ending on purpose: the service went with the session.
          _ending.connectionLost();
        } else if (_profile.current == null && _ending.ending == null) {
          unawaited(_profile.start());
        }
        if (s is Connected) unawaited(_jobs.reattach());
      }),
    );
    _subs.add(d.messages.listen(_toast));
    _subs.add(
      d.failures.listen((f) {
        if (_ending.ending != null) return;
        unawaited(
          showFailureOn(
            _modals,
            title: f.title,
            body: f.body,
            detail: f.detail,
          ),
        );
      }),
    );
    _subs.add(
      d.homePressed.listen((_) {
        if (_endingShown) return;
        d.cancelLaunching();
        // A modal (a security notice, a job in progress) is not dismissed by Home.
        if (!_modals.isOpen) _goHome(reset: true);
      }),
    );
    _subs.add(d.inputNav.listen((e) => _onAction(e.action, e.phase)));
    _authPrompts = AuthPrompter(widget.services.auth, _modals);
    _reminders.addListener(_onReminders);
    _reminders.onLateResult = _homeEntered;
    unawaited(_reminders.start().then((_) => _homeEntered()));
    _subs.add(widget.services.timeZone.changes.listen(_setZone));
    unawaited(_loadZone());
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() => _time = _clockTime());
      });
    }
    // First item focused, as soon as Home has items (the daemon answers later).
    _nav.fallback = () => _modals.topRegion ?? _contentOf(_section);
    _home.addListener(_initialFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialFocus());
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  /// The time the top bar shows: UTC plus the box's offset.
  DateTime _clockTime() {
    final z = _zone;
    return z == null ? _now() : z.wallClock(_now());
  }

  Future<void> _loadZone() async {
    try {
      _setZone(await widget.services.timeZone.get());
    } on SystemException {
      // No answer (yet): the clock stays as it is; a reconnect or
      // `time_zone_changed` brings the zone.
    }
  }

  void _setZone(TimeZoneInfo z) {
    if (!mounted) return;
    _zoneTimer?.cancel();
    _zoneTimer = null;
    final until = z.validUntil;
    if (until != null) {
      // Just after the change, the daemon has the new offset. A change
      // that is past already (a clock that moved): ask again in a minute.
      final left = until.difference(_now());
      final wait = left.isNegative
          ? const Duration(minutes: 1)
          : left + const Duration(seconds: 1);
      _zoneTimer = Timer(wait, () {
        if (mounted) unawaited(_loadZone());
      });
    }
    setState(() {
      _zone = z;
      _time = _clockTime();
    });
  }

  /// Where up and down lead between the tab bar, the banners (Steam, update;
  /// each only while visible) and the content.
  void _relink() {
    final content = _contentOf(_section);
    final chain = <NavRegion>[
      _tabs,
      if (_bannerVisible) _banner,
      if (_updateBannerVisible) _updateBanner,
      content,
    ];
    for (var i = 0; i < chain.length - 1; i++) {
      chain[i].neighbors[NavDir.down] = chain[i + 1];
      chain[i + 1].neighbors[NavDir.up] = chain[i];
    }
    final above = chain[chain.length - 2];
    for (final r in [
      _home,
      _games,
      _apps,
      _store,
      _storeGrid,
      _settingsList,
      _settingsDetail,
      _server,
    ]) {
      r.neighbors[NavDir.up] = above;
    }
  }

  /// The data layer changed: the banner and the close dialog follow it.
  bool _hidingConnection = false;

  void _onData() {
    if (!mounted) return;
    final d = widget.data;
    _front.value = d.inFront;
    if (_hideConnection != _hidingConnection) {
      _hidingConnection = _hideConnection;
      setState(() {});
    }
    if ((d.launching != null) != _launchShown) {
      _launchShown = d.launching != null;
      setState(() {});
    }
    final wantBanner = d.steamAttention.isNotEmpty && d.status is Connected;
    final wantDialog = d.closeRequest != null;
    if (wantBanner == _bannerVisible && wantDialog == _dialogOpen) return;
    if (wantBanner != _bannerVisible) {
      final wasActive = _nav.active == _banner;
      _bannerVisible = wantBanner;
      _banner.setRows(wantBanner ? [NavRow('banner', 1)] : const []);
      _relink();
      // The banner went away under the focus: back to the content.
      if (!wantBanner && wasActive && !_dialogOpen) {
        _nav.focusRegion(_contentOf(_section));
      }
    }
    if (wantDialog && !_dialogOpen) {
      _beforeDialog = _nav.active;
      _dialogOpen = true;
      _dialog.reset();
      _nav.focusRegion(_dialog);
    } else if (!wantDialog && _dialogOpen) {
      _dialogOpen = false;
      _dialog.setRows(const []);
      final back = _beforeDialog;
      _beforeDialog = null;
      _nav.focusRegion(
        back != null && back.hasItems ? back : _contentOf(_section),
      );
    }
    setState(() {});
  }

  bool _launchShown = false;

  /// The loading page is up (see [LauncherShell.startup]).
  late bool _loading = widget.startup != null;
  Timer? _loadingCap;

  /// How long the loading page waits for Home's data at most.
  static const _loadingMax = Duration(seconds: 20);

  /// The session's start (with [LauncherShell.startup]): until it is over,
  /// a connection that is not up (yet, or again: the session daemon is
  /// restarted once as a new session starts) shows the loading page, never
  /// "Can't reach the HinterOS service". After it, a real failure shows.
  static const startupGrace = Duration(seconds: 20);
  late bool _grace = widget.startup != null;
  Timer? _graceTimer;

  bool get _hideConnection => _grace && widget.data.status is! Connected;

  void _checkLoading() {
    if (!_loading || !mounted) return;
    final d = widget.data;
    final s = d.status;
    final ready =
        (s is Connected && (d.appList != null || d.appsError != null)) ||
        s is VersionMismatch;
    if (ready) _endLoading();
  }

  void _endLoading() {
    _loadingCap?.cancel();
    if (!_loading || !mounted) return;
    setState(() => _loading = false);
  }

  LoadingIdentity _loadingIdentity() {
    final c = _profile.current;
    if (c == null) return widget.startup ?? const LoadingIdentity();
    if (c.guest) return LoadingIdentity.guestIdentity;
    return LoadingIdentity(
      name: c.name ?? widget.startup?.name,
      color: c.color,
    );
  }

  bool _didInitialFocus = false;

  void _initialFocus() {
    if (_didInitialFocus || !mounted || !_home.hasItems) return;
    _didInitialFocus = true;
    _home.removeListener(_initialFocus);
    // A page the session raised first (first-boot mode, the lock) keeps it.
    _nav.focusRegion(_modals.topRegion ?? _home);
  }

  void _onEnding() {
    if (!mounted) return;
    if (_ending.ending != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    setState(() {});
  }

  /// The profile is known (or changed): the chip joins the tab row.
  void _onProfile() {
    if (!mounted) return;
    _mirrorAppearance();
    _syncTabRow();
    setState(() {});
  }

  /// The tab row: the sections, the job indicator, the profile chip.
  void _syncTabRow() {
    final job = _jobs.showsIndicator ? 1 : 0;
    final n = _sections.length + job + (_profile.current == null ? 0 : 1);
    if (_tabs.model.rows.firstOrNull?.length == n) return;
    // The indicator went away under the focus: back to the tab of this
    // section (moving to another tab would switch the section).
    final onExtra = _tabs.model.col >= _sections.length;
    _tabs.setRows([NavRow('tabs', n)]);
    if (onExtra && job == 0) {
      _tabs.model.goTo(0, _sections.indexOf(_section));
      _tabs.changed();
    }
  }

  void _onJobs() {
    if (!mounted) return;
    _syncTabRow();
    setState(() {});
  }

  /// A on the indicator: the job's page again.
  void _openJob() {
    final bg = _jobs.background;
    final c = _scopeContext;
    if (bg == null || c == null) return;
    unawaited(
      showJobProgress(
        c,
        widget.services,
        JobHandle(bg.jobId, bg.kind),
        name: _jobs.backgroundName,
        initial: bg,
      ),
    );
  }

  /// A job the person left ended: a short notice; an update that needs a
  /// new session asks to restart it.
  void _jobFinished(JobSnapshot s, String? name) {
    if (!mounted || _ending.ending != null) return;
    if (s.ok && s.sessionRestartRequired) {
      unawaited(_offerRestart(s, name));
      return;
    }
    _notice(
      jobNotice(s, name: name),
      ok: s.ok,
      error: s.failed,
    );
  }

  Future<void> _offerRestart(JobSnapshot s, String? name) async {
    final c = _scopeContext;
    if (c == null) return;
    // Shown at once; it counts down only while the launcher is in front.
    final r = await showRestartOffer(
      c,
      title: '${jobTitle(s, name: name)}: done',
    );
    if (!r || !mounted) return;
    _jobs.clear();
    try {
      await endSessionWith(
        _scopeContext ?? context,
        const SessionEnding(title: 'Restarting the session…'),
        widget.services.system.restartSession,
      );
    } on SystemException catch (e) {
      _toast("Can't restart the session: ${e.message}");
    }
  }

  (double, bool, bool)? _mirrored;

  /// The picker uses the most accessible of the profiles' text size, high
  /// contrast and reduced motion: tell the service this profile's.
  void _mirrorAppearance() {
    final c = _profile.current;
    if (c == null || c.guest || c.setupRequired) return;
    final s = widget.settings.value;
    final now = (s.textScale, s.highContrast, s.reduceMotion);
    if (now == _mirrored) return;
    _mirrored = now;
    unawaited(
      widget.services.profiles
          .mirrorAppearance(
            textScale: s.textScale,
            highContrast: s.highContrast,
            reduceMotion: s.reduceMotion,
          )
          .catchError((_) {}),
    );
  }

  /// A on the profile chip.
  Future<void> _profileMenu() async {
    final c = _scopeContext;
    final me = _profile.current;
    if (c == null || me == null) return;
    final choice = await showChoice<String>(
      c,
      title: me.displayName,
      choices: [
        const Choice('Switch profile', 'switch'),
        if (!me.guest) const Choice('Profile settings', 'settings'),
        if (me.guest) const Choice('End guest session', 'end', danger: true),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'switch':
        await _profile.switchProfile(_scopeContext ?? c);
      case 'settings':
        _openProfileSettings();
      case 'end':
        await _profile.endGuest(_scopeContext ?? c);
    }
  }

  /// Settings, on the Profiles entry.
  void _openProfileSettings() => _openSettings('profiles');

  /// Settings at [id], a list entry or a setting in one (see
  /// [SettingsRegions.select]).
  void _openSettings(String id) => _openSection(
    Section.settings,
    _settingsList,
    prepare: () => _settingsRegions.select(id),
  );

  @override
  void dispose() {
    _profile.removeListener(_onProfile);
    _jobs.removeListener(_onJobs);
    _jobs.dispose();
    _ending.removeListener(_onEnding);
    widget.settings.removeListener(_mirrorAppearance);
    _profile.dispose();
    _ending.dispose();
    _reminders.removeListener(_onReminders);
    _authPrompts.dispose();
    _reminders.dispose();
    _settingsRegions.dispose();
    widget.data.removeListener(_onData);
    widget.data.removeListener(_checkLoading);
    _front.dispose();
    _loadingCap?.cancel();
    _graceTimer?.cancel();
    _clock?.cancel();
    _zoneTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    for (final r in [
      _tabs,
      _home,
      _games,
      _apps,
      _store,
      _storeGrid,
      _updateBanner,
      _settingsList,
      _settingsDetail,
      _server,
      _banner,
      _dialog,
    ]) {
      r.dispose();
    }
    super.dispose();
  }

  bool _noticeOpen = false;

  /// The reminder banner shows on Home while the box is behind (not while the
  /// full-screen notice is up).
  void _syncUpdateBanner() {
    final want = _section == Section.home && _reminders.behind && !_noticeOpen;
    if (want == _updateBannerVisible) return;
    final wasActive = _nav.active == _updateBanner;
    _updateBannerVisible = want;
    _updateBanner.setRows(want ? [const NavRow('update-banner', 1)] : const []);
    _relink();
    if (!want && wasActive && !_modals.isOpen) {
      _nav.focusRegion(_contentOf(_section));
    }
  }

  void _onReminders() {
    if (!mounted) return;
    setState(_syncUpdateBanner);
  }

  /// Home was entered (startup, a return from another tab, the Home button):
  /// a security update that is due shows its full-screen notice.
  void _homeEntered() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _section != Section.home) return;
      if (_modals.isOpen || _dialogOpen || _noticeOpen) return;
      if (!_reminders.securityNoticeDue()) return;
      unawaited(_showSecurityNotice());
    });
  }

  Future<void> _showSecurityNotice() async {
    final u = _reminders.update;
    if (u == null) return;
    setState(() {
      _noticeOpen = true;
      _syncUpdateBanner();
    });
    final choice = await _modals.show<SecurityChoice>(
      (c, m) => SecurityNotice(modal: m, update: u),
    );
    if (!mounted) return;
    setState(() {
      _noticeOpen = false;
      _syncUpdateBanner();
    });
    if (choice != SecurityChoice.updateNow) return;
    try {
      // Every profile (the guest too) types the admin PIN first.
      final h = await withBoxAdminPin(
        _scopeContext ?? context,
        widget.services.profiles,
        title: 'Update HinterOS',
        action: (pin) => widget.services.updates.apply(u.rev, adminPin: pin),
      );
      if (h == null || !mounted) return;
      await _modals.show<JobSnapshot>(
        (c, m) =>
            JobProgressScreen(modal: m, services: widget.services, job: h),
      );
    } on SystemException catch (e) {
      _toast("Couldn't start the update: ${e.message}");
    }
  }

  /// Goes to [section] from a button of another one. The button disappears
  /// with its section and Flutter would hand focus to a tab (which switches
  /// the section back), so focus goes to the right tab first, and into the
  /// content once it exists.
  void _openSection(
    Section section,
    NavRegion content, {
    VoidCallback? prepare,
  }) {
    _pendingPrepare = prepare;
    _setSection(section);
    _tabs.changed();
    _nav.focusRegion(_tabs);
    _pendingContentFocus = content;
    WidgetsBinding.instance.addPostFrameCallback((_) => _contentReady());
  }

  NavRegion? _pendingContentFocus;
  VoidCallback? _pendingPrepare;

  /// The content of a section opened by [_openSection] has rows (also called
  /// by screens that fill their rows asynchronously).
  void _contentReady() {
    final c = _pendingContentFocus;
    if (c == null || !mounted || !c.hasItems) return;
    _pendingContentFocus = null;
    _pendingPrepare?.call();
    _pendingPrepare = null;
    if (_contentOf(_section) == c) _nav.focusRegion(c);
  }

  /// Banner "See update": Settings, on the Updates entry.
  void _openUpdates() => _openSettings('updates');

  /// Switches the visible section (tab focus, L1/R1, Back, Home).
  void _setSection(Section s) {
    if (s == _section) return;
    setState(() {
      _section = s;
      _syncUpdateBanner();
    });
    if (s == Section.home) _homeEntered();
    _relink();
    _tabs.model.goTo(0, _sections.indexOf(s));
  }

  /// L1/R1: switch tab, keeping focus where it is relative to the new section.
  void _selectSection(int i) {
    if (i < 0 || i >= _sections.length) return;
    final inTabs = _nav.active == _tabs;
    _setSection(_sections[i]);
    _tabs.changed();
    _nav.focusRegion(inTabs ? _tabs : _contentOf(_section));
  }

  /// Home tab. [reset] (the Home button) puts focus on the first card and
  /// forgets column memory; Back keeps where you were on Home.
  void _goHome({required bool reset}) {
    widget.data.cancelClose();
    _homeEntered();
    // Home is not built while another tab shows, so its rows are as old as the
    // last visit; drop them so the reset lands on the first item of the first
    // non-empty row once Home builds again (its build refills the rows).
    final onHome = _section == Section.home;
    _setSection(Section.home);
    if (reset) {
      if (!onHome) _home.setRows(const []);
      _home.reset();
      _settingsRegions.reset();
    }
    _tabs.changed();
    _nav.focusRegion(_home);
  }

  /// The one action layer: controller and keyboard both end up here.
  void _onAction(NavAction action, NavPhase phase) {
    // The session is ending: there is no way back.
    if (_endingShown) return;
    if (widget.data.launching != null) {
      // The "Starting ..." view has the screen: B stops waiting, nothing else
      // moves the (hidden) launcher.
      if (action == NavAction.back && phase == NavPhase.press) {
        widget.data.cancelLaunching();
      }
      return;
    }
    _nav.dispatch(action, phase);
  }

  bool _typingInField() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    // In a text field letters are letters (not Y/X) and Backspace deletes.
    final action = navActionForKey(e.logicalKey, inTextField: _typingInField());
    if (action == null) return KeyEventResult.ignored;
    _onAction(action, switch (e) {
      KeyDownEvent() => NavPhase.press,
      KeyRepeatEvent() => NavPhase.repeat,
      _ => NavPhase.release,
    });
    return KeyEventResult.handled;
  }

  void _toast(String message) {
    if (!mounted || _ending.ending != null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// A short notice with a mark (OK, !): a job the person left ended.
  void _notice(String message, {bool ok = false, bool error = false}) {
    if (!mounted || _ending.ending != null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('job-notice'),
          duration: const Duration(seconds: 6),
          content: StatusLine(message, ok: ok, error: error),
        ),
      );
  }

  Widget _content() => switch (_section) {
    Section.home => HomeScreen(data: widget.data, region: _home),
    Section.games => GamesScreen(
      data: widget.data,
      region: _games,
      onInstallSteam: (context) => installSteam(context, widget.services),
    ),
    Section.store => StoreScreen(
      services: widget.services,
      data: widget.data,
      cats: _store,
      grid: _storeGrid,
      onPopulated: _contentReady,
    ),
    Section.apps => AppsScreen(data: widget.data, region: _apps),
    Section.settings => SettingsScreen(
      settings: widget.settings,
      services: widget.services,
      regions: _settingsRegions,
      profileSession: _profile,
      now: widget.now,
    ),
    // Phase 2.
    Section.server => const Notice(
      title: 'Server',
      detail: 'Not available yet.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return OskScope(
      control: widget.data.osk,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: t.background,
          body: SessionEndingScope(
            controller: _ending,
            child: Stack(
              children: [
                Positioned.fill(child: _host()),
                // Over everything, modals included.
                if (_ending.ending case final e? when _endingShown)
                  Positioned.fill(child: SessionEndingPage(ending: e)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _host() => FrontScope(
    inFront: _front,
    child: JobCenterScope(
      center: _jobs,
      child: ModalHost(
        controller: _modals,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(
                  region: _tabs,
                  labels: [for (final s in _sections) s.label],
                  selected: _sections.indexOf(_section),
                  onFocusTab: (i) => _setSection(_sections[i]),
                  time: _time,
                  profile: _profile.current,
                  onProfile: () => unawaited(_profileMenu()),
                  job: _jobs.showsIndicator ? _jobs.background : null,
                  jobName: _jobs.backgroundName,
                  onJob: _openJob,
                ),
                if (_updateBannerVisible && _reminders.update != null)
                  UpdateBanner(
                    update: _reminders.update!,
                    region: _updateBanner,
                    onOpen: _openUpdates,
                  ),
                if (_bannerVisible)
                  SteamBanner(
                    windows: widget.data.steamAttention,
                    region: _banner,
                    onOpen: () => unawaited(widget.data.focusSteam()),
                  ),
                Expanded(child: _content()),
              ],
            ),
            if (_dialogOpen && widget.data.closeRequest != null)
              CloseConfirm(
                id: widget.data.closeRequest!.id,
                name: widget.data.closeRequest!.name,
                iconPath: widget.data.closeRequest!.iconPath,
                region: _dialog,
                onCancel: widget.data.cancelClose,
                onConfirm: () => unawaited(widget.data.confirmClose()),
              ),
            if (widget.data.launching case final l?)
              Positioned.fill(
                child: LaunchingScreen(
                  key: ValueKey('launching-${l.id}'),
                  id: l.id,
                  name: l.name,
                  iconPath: l.iconPath,
                ),
              ),
            if (_loading || _hideConnection)
              Positioned.fill(
                child: ProfileLoadingPage(identity: _loadingIdentity()),
              ),
            if (widget.showFps) const FpsOverlay(),
            Builder(
              builder: (c) {
                _scopeContext = c;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
