import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
import '../data/launcher_data.dart';
import '../fps_overlay.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import 'apps_screen.dart';
import 'common.dart';
import 'games_screen.dart';
import 'home_screen.dart';
import 'overlays.dart';
import 'settings_screen.dart';
import 'tab_bar.dart';

enum Section {
  home('Home'),
  games('Games'),
  apps('Apps'),
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
    this.now,
    this.showFps = false,
    this.showServer = false,
  });

  final LauncherData data;
  final SettingsController settings;

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
  final _settingsList = NavRegion('settings-list');
  final _settingsDetail = NavRegion('settings-detail');
  final _server = NavRegion('server');
  final _banner = NavRegion('banner', rememberPerRow: false);
  final _dialog = NavRegion('dialog', rememberPerRow: false);
  bool _bannerVisible = false;
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
      if (_dialogOpen) return;
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
    _subs.add(d.homePressed.listen((_) => _goHome(reset: true)));
    _subs.add(d.inputNav.listen((e) => _onAction(e.action, e.phase)));
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() => _time = DateTime.now());
      });
    }
    // First item focused, as soon as Home has items (the daemon answers later).
    _nav.fallback = () => _contentOf(_section);
    _home.addListener(_initialFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialFocus());
  }

  /// Where up and down lead from and to the tab bar, which depends on the
  /// banner being there.
  void _relink() {
    final content = _contentOf(_section);
    final above = _bannerVisible ? _banner : _tabs;
    for (final r in [
      _home,
      _games,
      _apps,
      _settingsList,
      _settingsDetail,
      _server,
    ]) {
      r.neighbors[NavDir.up] = above;
    }
    _banner.neighbors[NavDir.up] = _tabs;
    _banner.neighbors[NavDir.down] = content;
    _tabs.neighbors[NavDir.down] = above == _banner ? _banner : content;
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

  /// Switches the visible section (tab focus, L1/R1, Back, Home).
  void _setSection(Section s) {
    if (s == _section) return;
    setState(() => _section = s);
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

  static NavAction? _actionForKey(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowLeft) return NavAction.left;
    if (k == LogicalKeyboardKey.arrowRight) return NavAction.right;
    if (k == LogicalKeyboardKey.arrowUp) return NavAction.up;
    if (k == LogicalKeyboardKey.arrowDown) return NavAction.down;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      return NavAction.accept;
    }
    if (k == LogicalKeyboardKey.escape) return NavAction.back;
    if (k == LogicalKeyboardKey.pageUp) return NavAction.pageLeft;
    if (k == LogicalKeyboardKey.pageDown) return NavAction.pageRight;
    // Gamepad Y / X stand-ins.
    if (k == LogicalKeyboardKey.keyY || k == LogicalKeyboardKey.contextMenu) {
      return NavAction.context;
    }
    if (k == LogicalKeyboardKey.keyX) return NavAction.secondary;
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final action = _actionForKey(e.logicalKey);
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
    Section.games => GamesScreen(data: widget.data, region: _games),
    Section.apps => AppsScreen(data: widget.data, region: _apps),
    Section.settings => SettingsScreen(
      settings: widget.settings,
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
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: t.background,
        body: Stack(
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
    );
  }
}
