import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
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
import 'games_screen.dart';
import 'home_screen.dart';
import 'modal_host.dart';
import 'overlays.dart';
import 'settings_screen.dart';
import 'store_flows.dart';
import 'store_screen.dart';
import 'update_banner.dart';
import 'pages.dart';
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
/// - Context (Y/Triangle) on a running app or game asks to close it; the
///   confirm dialog takes all input until answered (Back cancels).
///   Secondary (X) opens Steam when its banner shows.
/// - Back: detail pane to its list, section content to the Home tab; on Home it
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
  });

  final LauncherData data;
  final SettingsController settings;
  final SystemServices services;

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
  final _server = NavRegion('server');
  final _banner = NavRegion('banner', rememberPerRow: false);
  final _dialog = NavRegion('dialog', rememberPerRow: false);
  late final _modals = ModalController(_nav);
  // The admin password prompt: shown over whatever is on screen whenever
  // polkit asks (a relayed call such as ssh.set is waiting for it).
  late final AuthPrompter _authPrompts;
  bool _bannerVisible = false;
  bool _updateBannerVisible = false;
  late final UpdateReminders _reminders = UpdateReminders(
    widget.services.updates,
  );
  bool _dialogOpen = false;
  NavRegion? _beforeDialog;

  late final List<Section> _sections = [
    for (final s in Section.values)
      if (s != Section.server || widget.showServer) s,
  ];
  Section _section = Section.home;
  late DateTime _time = (widget.now ?? DateTime.now)();
  Timer? _clock;
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
    _settingsList.neighbors[NavDir.right] = _settingsDetail;
    _settingsDetail.neighbors[NavDir.left] = _settingsList;
    _settingsDetail.backTarget = _settingsList;
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
    d.start();
    d.addListener(_onData);
    _subs.add(d.messages.listen(_toast));
    _subs.add(
      d.homePressed.listen((_) {
        // A modal (a security notice, a job in progress) is not dismissed by Home.
        if (!_modals.isOpen) _goHome(reset: true);
      }),
    );
    _subs.add(d.inputNav.listen((e) => _onAction(e.action, e.phase)));
    _subs.add(
      widget.services.store.changes.listen((_) {
        if (mounted) setState(() {});
      }),
    );
    _authPrompts = AuthPrompter(widget.services.auth, _modals);
    _reminders.addListener(_onReminders);
    _reminders.onLateResult = _homeEntered;
    unawaited(_reminders.start().then((_) => _homeEntered()));
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() => _time = DateTime.now());
      });
    }
    // First item focused, as soon as Home has items (the daemon answers later).
    _nav.fallback = () => _modals.topRegion ?? _contentOf(_section);
    _home.addListener(_initialFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialFocus());
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
  void _onData() {
    if (!mounted) return;
    final d = widget.data;
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

  bool _didInitialFocus = false;

  void _initialFocus() {
    if (_didInitialFocus || !mounted || !_home.hasItems) return;
    _didInitialFocus = true;
    _home.removeListener(_initialFocus);
    _nav.focusRegion(_home);
  }

  @override
  void dispose() {
    _reminders.removeListener(_onReminders);
    _authPrompts.dispose();
    _reminders.dispose();
    widget.data.removeListener(_onData);
    _clock?.cancel();
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
      final h = await widget.services.updates.apply(u.rev);
      if (!mounted) return;
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
  void _openUpdates() => _openSection(
    Section.settings,
    _settingsList,
    prepare: () {
      _settingsList.model.goTo(settingsEntryIds.indexOf('updates'), 0);
      _settingsList.changed();
    },
  );

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
      _settingsList.reset();
      _settingsDetail.reset();
    }
    _tabs.changed();
    _nav.focusRegion(_home);
  }

  /// The one action layer: controller and keyboard both end up here.
  void _onAction(NavAction action, NavPhase phase) =>
      _nav.dispatch(action, phase);

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
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _content() => switch (_section) {
    Section.home => HomeScreen(data: widget.data, region: _home),
    Section.games => GamesScreen(
      data: widget.data,
      region: _games,
      steamMissing:
          widget.services.store.loaded &&
          !widget.services.store.installed.contains('steam'),
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
      list: _settingsList,
      detail: _settingsDetail,
      onEnterDetail: () => _nav.focusRegion(_settingsDetail),
    ),
    // Phase 2.
    Section.server => const Notice(
      title: 'Server',
      detail: 'Jellyfin, Plex and file sharing arrive in phase 2.',
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
          body: ModalHost(
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
                if (widget.showFps) const FpsOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
