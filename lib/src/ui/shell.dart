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
///   the section where you left it.
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
    ]) {
      _nav.adopt(r);
    }
    _tabs.setRows([NavRow('tabs', _sections.length)]);
    for (final r in [_home, _games, _apps, _settingsList, _server]) {
      r.neighbors[NavDir.up] = _tabs;
    }
    _settingsDetail.neighbors[NavDir.up] = _tabs;
    _settingsList.neighbors[NavDir.right] = _settingsDetail;
    _settingsDetail.neighbors[NavDir.left] = _settingsList;
    _settingsDetail.backTarget = _settingsList;
    _tabs.neighbors[NavDir.down] = _contentOf(_section);
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
      final i = _sections.indexOf(_section);
      if (a == NavAction.pageLeft) _selectSection(i - 1);
      if (a == NavAction.pageRight) _selectSection(i + 1);
    };

    final d = widget.data;
    d.start();
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

  bool _didInitialFocus = false;

  void _initialFocus() {
    if (_didInitialFocus || !mounted || !_home.hasItems) return;
    _didInitialFocus = true;
    _home.removeListener(_initialFocus);
    _nav.focusRegion(_home);
  }

  @override
  void dispose() {
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
    ]) {
      r.dispose();
    }
    super.dispose();
  }

  /// Switches the visible section (tab focus, L1/R1, Back, Home).
  void _setSection(Section s) {
    if (s == _section) return;
    setState(() => _section = s);
    _tabs.neighbors[NavDir.down] = _contentOf(s);
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
    _setSection(Section.home);
    if (reset) {
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
                Expanded(child: _content()),
              ],
            ),
            if (widget.showFps) const FpsOverlay(),
          ],
        ),
      ),
    );
  }
}
