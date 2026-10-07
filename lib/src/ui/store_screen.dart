import 'dart:async';

import 'package:flutter/material.dart';

import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../system/models.dart';
import '../system/repositories.dart';
import '../theme/hinter_theme.dart';
import 'app_icon_view.dart';
import 'common.dart';
import 'focus_frame.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'nav_grid_view.dart';
import 'pages.dart';
import 'store_flows.dart';
import 'system/common.dart';
import 'widgets.dart';

/// The Store tab: categories on the left, the apps of the highlighted
/// category on the right (the same list-detail shape as Settings). Accept on
/// an app opens its detail page; install and remove start there.
///
/// Icons are resolved at runtime (the app's own icon once installed, the
/// site's before; see catalog.md "Icons"), with placeholder art until then.
class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.services,
    required this.cats,
    required this.grid,
    this.data,
    this.onPopulated,
  });

  final SystemServices services;

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
  int _cat = 0;
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
  void didUpdateWidget(StoreScreen old) {
    super.didUpdateWidget(old);
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

  List<(String id, String label)> _categories(List<StoreApp> apps) => [
    (StoreScreen.all, 'All'),
    for (final c in StoreCategory.values)
      if (apps.any((a) => a.category == c)) (c.name, c.label),
    (StoreScreen.installedCat, 'Installed'),
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
    _cat = _cat.clamp(0, cats.length - 1);
    final shown = _appsIn(cats[_cat].$1, apps);
    widget.cats.setRows([
      for (var i = 0; i < cats.length; i++) NavRow('c$i', 1),
    ]);
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
                          region: widget.cats,
                          rowKey: 'c$i',
                          col: 0,
                          onFocused: () {
                            if (_cat != i) setState(() => _cat = i);
                          },
                          builder: (_, f) => _CategoryRow(
                            label: cats[i].$2,
                            count: _appsIn(cats[i].$1, apps).length,
                            focused: f,
                            selected: i == _cat,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? _emptyGrid(t, cats[_cat].$1)
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
    return 'More apps are available after the next update'
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
            ? 'Nothing from the Store is installed yet.'
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
      scale: 1.03,
      child: DecoratedBox(
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
        child: DecoratedBox(
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
/// Install or Remove.
class AppDetailPage extends StatefulWidget {
  const AppDetailPage({
    super.key,
    required this.modal,
    required this.services,
    required this.app,
    required this.catalog,
    this.iconPath,
    this.data,
  });

  final LauncherData? data;
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

  @override
  void initState() {
    super.initState();
    _sub = widget.services.store.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final app = widget.app;
    final store = widget.services.store;
    final state = store.stateOf(app.id);
    final installed = state.isInstalled;
    final deps = missingDependencies(app, widget.catalog, store.installed);
    final inTheWay = [
      for (final id in app.conflicts)
        if (store.installed.contains(id))
          widget.catalog.where((a) => a.id == id).firstOrNull?.name ?? id,
    ];
    final p = Pane(widget.modal.region);
    final about = app.description.isEmpty ? app.summary : app.description;
    if (about.isNotEmpty) p.add(Text(about, style: t.body));
    if (!installed && app.sizeMiB > 0) {
      p.add(
        Text(
          'Size: ${app.sizeLabel}. '
          '${app.onIso ? 'Included with the installer.' : 'Downloads when you install it.'}',
          style: t.bodyDim,
        ),
      );
    }
    if (!installed && deps.isNotEmpty) {
      p.add(
        Text(
          'Also installs: ${[for (final d in deps) d.name].join(', ')}.',
          style: t.bodyDim,
        ),
      );
    }
    if (!installed && inTheWay.isNotEmpty) {
      p.add(
        StatusLine(
          "Can't be installed together with ${inTheWay.join(', ')}, which "
          '${inTheWay.length == 1 ? 'is' : 'are'} installed.',
        ),
      );
    }
    if (app.hasTerms && !installed) {
      p.add(
        Text(
          '${app.terms!.title} applies (version ${app.terms!.version}).',
          style: t.bodyDim,
        ),
      );
    }
    p.add(
      Text(switch (state) {
        StoreState.available => 'Not installed.',
        StoreState.installing => 'Installing...',
        StoreState.removing => 'Removing...',
        _ => 'Installed.',
      }, style: t.label),
      gap: HinterTokens.s3,
    );
    if (state == StoreState.retired) {
      p.add(
        StatusLine(
          'This app is retired.${_reason(app)} It keeps working, and you '
          'can remove it.',
        ),
      );
    } else if (state == StoreState.unavailable) {
      p.add(
        StatusLine(
          'The next update takes this app away.${_reason(app)} You can '
          'remove it now.',
        ),
      );
    }
    final cat = widget.catalog;
    p.buttons('actions', [
      if (state.busy)
        btn('Back', widget.modal.close, primary: true)
      else if (installed) ...[
        btn('Back', widget.modal.close),
        btn(
          'Remove',
          () => removeFlow(context, widget.services, app, data: widget.data),
          danger: true,
        ),
      ] else ...[
        btn(
          'Install',
          () => installFlow(context, widget.services, app, cat),
          primary: true,
        ),
        btn('Back', widget.modal.close),
      ],
    ], gap: HinterTokens.s3);
    return FullPage(
      title: app.name,
      subtitle: app.summary.isEmpty
          ? app.category.label
          : '${app.category.label}: ${app.summary}',
      leading: AppIconBadge(
        name: app.name,
        iconPath: widget.iconPath,
        size: 128,
      ),
      child: SingleChildScrollView(clipBehavior: Clip.none, child: p.build()),
    );
  }

  /// The catalog's reason as a sentence (with a leading space), or nothing.
  static String _reason(StoreApp app) {
    final r = app.statusReason;
    if (r == null || r.isEmpty) return '';
    return r.endsWith('.') ? ' $r' : ' $r.';
  }
}
