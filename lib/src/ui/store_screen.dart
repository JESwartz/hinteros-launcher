import 'dart:async';

import 'package:flutter/material.dart';

import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../api/api.dart' show NavAction;
import '../system/models.dart';
import '../system/repositories.dart';
import '../theme/hinter_theme.dart';
import 'app_icon_view.dart';
import 'common.dart';
import 'dialogs.dart';
import 'focus_frame.dart';
import 'markdown_view.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'nav_grid_view.dart';
import 'pages.dart';
import 'store_flows.dart';
import 'system/common.dart';
import 'visible_box.dart';
import 'widgets.dart';

/// The Store tab: categories on the left, the apps of the highlighted
/// category on the right (the same list-detail shape as Settings). Accept on
/// an app opens its detail page; install and remove start there.
///
/// Icons are resolved at runtime (the app's own icon once installed, the
/// site's before), with placeholder art until then.
class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.services,
    required this.cats,
    required this.grid,
    this.data,
    this.onPopulated,
    this.changes = true,
  });

  final SystemServices services;

  /// Install, Remove and Clear user data work (false: the browser demo).
  final bool changes;

  /// Which apps run (a running app is closed before it is removed).
  final LauncherData? data;
  final NavRegion cats;
  final NavRegion grid;

  /// Called once the catalog is loaded and the rows are in the regions (the
  /// shell then moves focus in, if it was asked to before they existed).
  final VoidCallback? onPopulated;

  /// Id of the pseudo categories.
  static const all = 'all';
  static const installedCat = 'installed';

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<StoreApp>? _catalog;
  Object? _error;
  final _icons = <String, String?>{};

  /// The chosen category, by id: the list can change under it (a
  /// category with no apps is left out).
  String _cat = StoreScreen.installedCat;
  final _subs = <StreamSubscription<void>>[];
  Timer? _retry;

  StoreRepository get _store => widget.services.store;

  @override
  void initState() {
    super.initState();
    // store_changed (an apps job started or finished, an update check found
    // new apps): the listing is already refreshed, show it.
    _subs.add(
      _store.changes.listen((_) {
        if (!mounted || !_store.loaded) return;
        setState(() {
          _catalog = _store.apps;
          _error = null;
        });
        _resolveIcons(_store.apps);
      }),
    );
    _subs.add(widget.services.updates.changes.listen((_) => _rebuild()));
    unawaited(_load());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _retry?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await _store.catalog();
      if (!mounted) return;
      setState(() {
        _catalog = c;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPopulated?.call();
      });
      _resolveIcons(c);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      // The system service or the catalog may only be late: look again.
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 5), () {
        if (mounted && _catalog == null) unawaited(_load());
      });
    }
  }

  void _resolveIcons(List<StoreApp> apps) {
    for (final a in apps) {
      unawaited(
        _store.resolveIcon(a).then((p) {
          if (mounted && _icons[a.id] != p) setState(() => _icons[a.id] = p);
        }),
      );
    }
  }

  /// The category order of the Store; a category without apps is left
  /// out.
  static const _order = [
    StoreCategory.video,
    StoreCategory.games,
    StoreCategory.music,
    StoreCategory.utilities,
    StoreCategory.photos,
    StoreCategory.other,
  ];

  List<(String id, String label)> _categories(List<StoreApp> apps) => [
    (StoreScreen.installedCat, 'Installed'),
    (StoreScreen.all, 'All'),
    for (final c in _order)
      if (apps.any((a) => a.category == c)) (c.name, c.label),
  ];

  List<StoreApp> _appsIn(String cat, List<StoreApp> apps) => switch (cat) {
    StoreScreen.all => apps,
    StoreScreen.installedCat => [
      for (final a in apps)
        if (_store.installed.contains(a.id)) a,
    ],
    _ => [
      for (final a in apps)
        if (a.category.name == cat) a,
    ],
  };

  /// A category's row, by id: the focus stays on it when a category before
  /// it comes or goes.
  static String _catKey(String id) => 'c-$id';

  /// The category rows, with the position on the chosen one.
  void _syncCats(List<(String id, String label)> cats) {
    final r = widget.cats;
    final before = r.model.currentRow?.key;
    final hadFocus = before != null && r.nodeAt(before, 0).hasFocus;
    r.setRows([for (final c in cats) NavRow(_catKey(c.$1), 1)]);
    final want = _catKey(_cat);
    if (r.model.currentRow?.key == want) return;
    r.model.goTo(cats.indexWhere((c) => c.$1 == _cat), 0);
    // The focused row went: the focus goes to the chosen one.
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(r.focusCurrent());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final apps = _catalog;
    if (_error != null || apps == null) {
      widget.cats.setRows(const []);
      widget.grid.setRows(const []);
      return Notice(
        title: _error == null
            ? 'Loading the Store...'
            : "The Store isn't available",
        detail: _error == null ? '' : describeError(_error!),
      );
    }
    final cats = _categories(apps);
    // A category left out now (its last app went): All instead.
    if (!cats.any((c) => c.$1 == _cat)) _cat = StoreScreen.all;
    final shown = _appsIn(_cat, apps);
    _syncCats(cats);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RowHeader('Store'),
        if (_moreAfterUpdate)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HinterTokens.margin,
              0,
              HinterTokens.margin,
              HinterTokens.s1,
            ),
            child: Text(
              _moreAfterUpdateText,
              key: const ValueKey('more-apps'),
              style: t.caption,
            ),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: HinterTokens.margin + 380,
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(
                    HinterTokens.margin,
                    HinterTokens.s2,
                    HinterTokens.s2,
                    HinterTokens.s2,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < cats.length; i++) ...[
                        if (i > 0) const SizedBox(height: HinterTokens.s1 + 4),
                        NavFocusable(
                          key: ValueKey(cats[i].$1),
                          region: widget.cats,
                          rowKey: _catKey(cats[i].$1),
                          col: 0,
                          onFocused: () {
                            final id = cats[i].$1;
                            if (_cat != id) setState(() => _cat = id);
                          },
                          builder: (_, f) => _CategoryRow(
                            label: cats[i].$2,
                            count: _appsIn(cats[i].$1, apps).length,
                            focused: f,
                            selected: cats[i].$1 == _cat,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? _emptyGrid(t, _cat)
                    : NavGridView(
                        region: widget.grid,
                        itemCount: shown.length,
                        cellWidth: 520,
                        cellHeight: _cardHeight(context),
                        gap: HinterTokens.s3,
                        onSelect: (i) => _open(context, shown[i], apps),
                        itemBuilder: (_, i, f) => StoreCard(
                          app: shown[i],
                          iconPath: _icons[shown[i].id],
                          state: _store.stateOf(shown[i].id),
                          focused: f,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// More apps come with the next update: the Store listing says so, or
  /// the update that was found does.
  bool get _moreAfterUpdate =>
      _store.moreAfterUpdate ||
      (widget.services.updates.status.available?.catalogChanged ?? false);

  String get _moreAfterUpdateText {
    final names = [
      for (final a
          in widget.services.updates.status.available?.newApps ??
              const <CatalogChange>[])
        a.name,
    ];
    return 'More apps come with the next update'
        '${names.isEmpty ? '' : ': ${names.join(', ')}'}.';
  }

  /// Cards grow with the text size.
  static double _cardHeight(BuildContext c) =>
      150 * MediaQuery.textScalerOf(c).scale(1).clamp(1.0, 1.6);

  Widget _emptyGrid(HinterTokens t, String cat) {
    widget.grid.setRows(const []);
    return Padding(
      padding: const EdgeInsets.all(HinterTokens.s4),
      child: Text(
        cat == StoreScreen.installedCat
            ? 'Nothing installed yet.'
            : 'Nothing here yet.',
        style: t.bodyDim,
      ),
    );
  }

  void _open(BuildContext context, StoreApp app, List<StoreApp> catalog) {
    ModalScope.of(context).show<void>(
      (c, modal) => AppDetailPage(
        modal: modal,
        services: widget.services,
        app: app,
        catalog: catalog,
        iconPath: _icons[app.id],
        data: widget.data,
        changes: widget.changes,
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.count,
    required this.focused,
    required this.selected,
  });

  final String label;
  final int count;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: VisibleDecoratedBox(
        decoration: BoxDecoration(
          color: selected ? t.surfaceHigh : t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          border: t.highContrast
              ? Border.all(color: t.textDim, width: selected ? 4 : 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: t.label.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Text('$count', style: t.bodyDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// An app in the grid: icon, name, one line, and whether it is installed.
class StoreCard extends StatelessWidget {
  const StoreCard({
    super.key,
    required this.app,
    required this.iconPath,
    required this.state,
    required this.focused,
  });

  final StoreApp app;
  final String? iconPath;
  final StoreState state;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusCard,
      child: SizedBox(
        width: 520,
        height: _StoreScreenState._cardHeight(context),
        child: VisibleDecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
            border: t.highContrast
                ? Border.all(color: t.textDim, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(HinterTokens.s2),
            child: Row(
              children: [
                AppIconBadge(name: app.name, iconPath: iconPath, size: 112),
                const SizedBox(width: HinterTokens.s2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.label,
                      ),
                      Text(
                        app.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption,
                      ),
                      Text(
                        switch (state) {
                          StoreState.installed => 'Installed',
                          StoreState.installing => 'Installing...',
                          StoreState.removing => 'Removing...',
                          StoreState.retired => 'Installed, no longer offered',
                          StoreState.unavailable => 'Installed, going away',
                          StoreState.leftover => 'Removed, data stays',
                          StoreState.unknown => 'Not available',
                          StoreState.available => app.sizeLabel,
                        },
                        maxLines: 1,
                        style: t.caption.copyWith(
                          color: state == StoreState.installed
                              ? t.positive
                              : t.textDim,
                          fontWeight: state == StoreState.installed
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An app's detail page: what it is, size, what it brings along, terms, and
/// Install or Remove; for an installed app, its permissions as switches.
class AppDetailPage extends StatefulWidget {
  const AppDetailPage({
    super.key,
    required this.modal,
    required this.services,
    required this.app,
    required this.catalog,
    this.iconPath,
    this.data,
    this.changes = true,
  });

  final LauncherData? data;

  /// See [StoreScreen.changes].
  final bool changes;
  final ModalHandle<void> modal;
  final SystemServices services;
  final StoreApp app;
  final List<StoreApp> catalog;
  final String? iconPath;

  @override
  State<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  StreamSubscription<void>? _sub;
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _readmeKey = GlobalKey();
  static const _line = 96.0;

  @override
  void initState() {
    super.initState();
    _sub = widget.services.store.changes.listen((_) {
      if (mounted) setState(() {});
    });
    widget.data?.addListener(_rebuild);
    final r = widget.modal.region;
    r.interceptMove = _onMove;
    r.onAction = _onAction;
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.data?.removeListener(_rebuild);
    _scroll.dispose();
    super.dispose();
  }

  /// Which apps run changed ("Restart the app to apply.").
  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _scrollBy(double d) {
    final p = _scroll.position;
    final target = (p.pixels + d).clamp(0.0, p.maxScrollExtent);
    if (HinterTheme.of(context).fast == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: HinterTheme.of(context).fast,
        curve: Curves.easeOut,
      );
    }
  }

  /// The README box's top and bottom, relative to the top of the visible
  /// page area.
  (double, double)? _readmeBounds() {
    final box = _readmeKey.currentContext?.findRenderObject() as RenderBox?;
    final view = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || view == null || !box.attached) return null;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    return (top, top + box.size.height);
  }

  /// The page is one long column. Up and down scroll through the README
  /// while it has the focus, and on to what is below the last item (the
  /// permissions of an app that is not installed); otherwise they move the
  /// focus.
  bool _onMove(NavDir dir) {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) {
      return false;
    }
    final p = _scroll.position;
    final model = widget.modal.region.model;
    final key = model.currentRow?.key;
    final down = dir == NavDir.down;
    if (dir != NavDir.up && !down) return false;
    if (key == 'readme') {
      final b = _readmeBounds();
      if (b != null) {
        final (top, bottom) = b;
        final view = p.viewportDimension;
        if (down && bottom > view + 1 && p.pixels < p.maxScrollExtent - 1) {
          _scrollBy(_line.clamp(0.0, bottom - view));
          return true;
        }
        if (!down && top < -1 && p.pixels > 1) {
          _scrollBy(-_line.clamp(0.0, -top));
          return true;
        }
      }
    }
    final last = model.row == model.rows.length - 1;
    if (down && last && p.pixels < p.maxScrollExtent - 1) {
      _scrollBy(_line);
      return true;
    }
    if (!down && model.row == 0 && p.pixels > 1) {
      _scrollBy(-p.pixels);
      return true;
    }
    return false;
  }

  bool _onAction(NavAction a) {
    if (!_scroll.hasClients) return false;
    final page = _scroll.position.viewportDimension - _line;
    if (a == NavAction.pageRight) {
      _scrollBy(page);
      return true;
    }
    if (a == NavAction.pageLeft) {
      _scrollBy(-page);
      return true;
    }
    return false;
  }

  /// Permissions with a change on the way: [p.granted] is the value from
  /// before it, so a second press would send the same value again.
  final _togglingPermissions = <String>{};

  /// Turns optional permission [p] of [app] on or off for this profile.
  Future<void> _togglePermission(StoreApp app, AppPermission p) async {
    if (!_togglingPermissions.add(p.name)) return;
    try {
      await widget.services.store.setPermission(app.id, p.name, !p.granted);
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    } finally {
      _togglingPermissions.remove(p.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final store = widget.services.store;
    // The listing follows `store_changed` (a permission changed, for one).
    final listed = store.apps.where((a) => a.id == widget.app.id).firstOrNull;
    final app = listed ?? widget.app;
    // Left-over data goes from the listing once it is cleared: the page
    // stays as it was until it closes.
    final state = listed == null && widget.app.state == StoreState.leftover
        ? StoreState.leftover
        : store.stateOf(app.id);
    final installed = state.isInstalled;
    // Not installed and still in the catalog: it can be installed.
    final offered =
        !installed &&
        state != StoreState.leftover &&
        state != StoreState.unknown;
    final deps = missingDependencies(app, widget.catalog, store.installed);
    final inTheWay = [
      for (final id in app.conflicts)
        if (store.installed.contains(id))
          widget.catalog.where((a) => a.id == id).firstOrNull?.name ?? id,
    ];
    final p = Pane(widget.modal.region);
    p.add(
      Text(switch (state) {
        StoreState.available => 'Not installed.',
        StoreState.leftover => 'Removed. Its data stays on the box.',
        StoreState.unknown => 'Not available.',
        StoreState.installing => 'Installing...',
        StoreState.removing => 'Removing...',
        _ => 'Installed.',
      }, style: t.label),
    );
    if (offered && app.sizeMiB > 0) {
      p.add(Text('Size: ${app.sizeLabel}.', style: t.bodyDim));
    }
    if (offered && deps.isNotEmpty) {
      p.add(
        Text(
          'Also installs: ${[for (final d in deps) d.name].join(', ')}.',
          style: t.bodyDim,
        ),
      );
    }
    if (offered && inTheWay.isNotEmpty) {
      p.add(
        StatusLine(
          "Can't be installed with ${inTheWay.join(', ')}. Remove "
          '${inTheWay.length == 1 ? 'it' : 'them'} first.',
        ),
      );
    }
    if (state == StoreState.retired) {
      p.add(StatusLine('This app is retired.${_reason(app)} It still works.'));
    } else if (state == StoreState.unavailable) {
      p.add(StatusLine('The next update removes this app.${_reason(app)}'));
    }
    // An app that needs a service the box does not run cannot be installed
    // here; only the admin profile can add the service (owner answer).
    final needs = !offered
        ? const <String>[]
        : [for (final s in app.missingServices) s.name];
    if (needs.isNotEmpty) {
      // Red text, in words (owner answer).
      p.add(
        Text(
          '${app.name} needs ${needs.join(' and ')}. The admin profile can '
          'install ${needs.length == 1 ? 'it' : 'them'} in Server.',
          style: t.body.copyWith(color: t.danger, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (!widget.changes) {
      p.add(Text('The demo cannot install or remove apps.', style: t.bodyDim));
    }
    final cat = widget.catalog;
    final data = widget.data;
    final running = data?.isRunning(app.id) ?? false;
    final clear = btn(
      'Clear user data',
      () => clearDataFlow(context, widget.services, app, data: data),
      enabled: app.hasData && widget.changes,
    );
    p.buttons('actions', [
      if (state.busy || state == StoreState.unknown)
        btn('Back', widget.modal.close, primary: true)
      else if (state == StoreState.leftover) ...[
        // Only its data is left: once cleared, there is nothing to show.
        btn(
          'Clear user data',
          () async {
            final ok = await clearDataFlow(
              context,
              widget.services,
              app,
              data: data,
            );
            if (ok && mounted) widget.modal.close();
          },
          primary: true,
          enabled: app.hasData && widget.changes,
        ),
        btn('Back', widget.modal.close),
      ] else if (installed) ...[
        btn('Back', widget.modal.close),
        btn(
          'Force stop',
          data == null ? null : () => forceStopFlow(context, data, app),
          enabled: running,
        ),
        clear,
        btn(
          'Remove',
          () => removeFlow(context, widget.services, app, data: data),
          danger: true,
          enabled: widget.changes,
        ),
      ] else ...[
        btn(
          'Install',
          () => installFlow(context, widget.services, app, cat),
          primary: true,
          enabled: needs.isEmpty && widget.changes,
        ),
        // Data a remove left behind.
        if (app.hasData) clear,
        btn('Back', widget.modal.close),
      ],
    ], gap: HinterTokens.s3);

    // Permissions: switches once installed, a list before.
    final perms = app.permissions;
    if (app.fullAccess || perms.isNotEmpty) {
      p.add(Text('Permissions', style: t.label), gap: HinterTokens.s4);
    }
    if (app.fullAccess && installed && !state.busy) {
      p.item(
        'perm-full',
        onSelect: null,
        builder: (f) => SettingRow(
          title: fullAccessLabel,
          focused: f,
          trailing: const ToggleMark(on: true, locked: true, note: 'Required'),
        ),
      );
    } else if (app.fullAccess) {
      p.add(
        SettingRow(
          title: fullAccessLabel,
          focused: false,
          trailing: Text('Required', style: t.bodyDim),
        ),
      );
    } else if (perms.isNotEmpty && installed && !state.busy) {
      if (widget.data?.isRunning(app.id) ?? false) {
        p.add(Text('Restart the app to apply.', style: t.bodyDim));
      }
      for (final perm in perms) {
        p.item(
          'perm-${perm.name}',
          onSelect: perm.required ? null : () => _togglePermission(app, perm),
          builder: (f) => SettingRow(
            title: perm.label,
            focused: f,
            trailing: ToggleMark(
              on: perm.granted,
              locked: perm.required,
              note: perm.required ? 'Required' : null,
            ),
          ),
        );
      }
    } else {
      for (final perm in perms) {
        p.add(
          SettingRow(
            title: perm.label,
            focused: false,
            trailing: Text(
              perm.required ? 'Required' : 'Optional',
              style: t.bodyDim,
            ),
          ),
          gap: HinterTokens.s1 + 4,
        );
      }
    }

    // About: the upstream README, else the catalog's description.
    final readme = app.readme;
    final about = app.description.isEmpty ? app.summary : app.description;
    if (readme != null || about.isNotEmpty) {
      p.add(Text('About', style: t.label), gap: HinterTokens.s4);
    }
    if (readme != null) {
      p.row(
        'readme',
        1,
        NavFocusableBox(
          key: _readmeKey,
          region: widget.modal.region,
          rowKey: 'readme',
          child: Padding(
            padding: const EdgeInsets.all(HinterTokens.s3),
            child: MarkdownView(readme.text),
          ),
        ),
      );
      p.add(Text('From ${readme.url}', style: t.caption));
    } else if (about.isNotEmpty) {
      p.add(Text(about, style: t.body));
    }

    // Terms: the vendor's agreement, to read here at any time.
    final terms = app.terms;
    if (terms != null) {
      p.add(Text('Terms', style: t.label), gap: HinterTokens.s4);
      p.add(Text('${terms.title}, version ${terms.version}.', style: t.body));
      p.buttons('terms', [btn('Read', () => showTermsToRead(context, app))]);
    }

    final subtitle = app.summary.isEmpty
        ? app.category.label
        : '${app.category.label}: ${app.summary}';
    // A modal card over the dimmed Store: the header stays, the rest
    // scrolls under it.
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440, maxHeight: 960),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
              border: Border.all(
                color: t.highContrast ? t.text : t.surfaceHigh,
                width: t.highContrast ? 3 : 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HinterTokens.s5,
                HinterTokens.s5,
                HinterTokens.s5,
                HinterTokens.s4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppIconBadge(
                        name: app.name,
                        iconPath: widget.iconPath,
                        size: 96,
                      ),
                      const SizedBox(width: HinterTokens.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.name, style: t.title),
                            Text(subtitle, style: t.bodyDim),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HinterTokens.s2),
                  // Clipped above and below only: focus frames may still
                  // reach past the sides.
                  Flexible(
                    child: ClipRect(
                      clipper: const SideBleed(),
                      child: SingleChildScrollView(
                        key: _viewportKey,
                        controller: _scroll,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(
                          vertical: HinterTokens.s1,
                        ),
                        child: p.build(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The catalog's reason as a sentence (with a leading space), or nothing.
  static String _reason(StoreApp app) {
    final r = app.statusReason;
    if (r == null || r.isEmpty) return '';
    return r.endsWith('.') ? ' $r' : ' $r.';
  }
}
