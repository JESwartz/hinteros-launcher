import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final SystemServices services;
  final NavRegion cats;
  final NavRegion grid;

  /// Id of the pseudo categories.
  static const featured = 'featured';
  static const installedCat = 'installed';

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<StoreApp>? _catalog;
  Object? _error;
  final _icons = <String, String?>{};
  int _cat = 0;
  StreamSubscription<void>? _sub;

  StoreRepository get _store => widget.services.store;

  @override
  void initState() {
    super.initState();
    _sub = _store.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(StoreScreen old) {
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await _store.catalog();
      if (!mounted) return;
      setState(() => _catalog = c);
      for (final a in c) {
        unawaited(
          _store.resolveIcon(a).then((p) {
            if (mounted) setState(() => _icons[a.id] = p);
          }),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<(String id, String label)> _categories(List<StoreApp> apps) => [
    (StoreScreen.featured, 'Featured'),
    for (final c in StoreCategory.values)
      if (apps.any((a) => a.category == c)) (c.name, c.label),
    (StoreScreen.installedCat, 'Installed'),
  ];

  List<StoreApp> _appsIn(String cat, List<StoreApp> apps) => switch (cat) {
    StoreScreen.featured => [
      for (final a in apps)
        if (a.featured) a,
    ],
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
        if (_store.moreAfterUpdate)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HinterTokens.margin,
              0,
              HinterTokens.margin,
              HinterTokens.s1,
            ),
            child: Text(
              'More apps are available after the next update.',
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
                          installed: _store.installed.contains(shown[i].id),
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
    required this.installed,
    required this.focused,
  });

  final StoreApp app;
  final String? iconPath;
  final bool installed;
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
                        installed ? 'Installed' : app.sizeLabel,
                        maxLines: 1,
                        style: t.caption.copyWith(
                          color: installed ? t.positive : t.textDim,
                          fontWeight: installed ? FontWeight.w700 : null,
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
  });

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
    final installed = widget.services.store.installed.contains(app.id);
    final deps = missingDependencies(
      app,
      widget.catalog,
      widget.services.store.installed,
    );
    final p = Pane(widget.modal.region);
    p.add(
      Text(
        app.description.isEmpty ? app.summary : app.description,
        style: t.body,
      ),
    );
    p.add(
      Text(
        'Size: ${app.sizeLabel}. '
        '${app.onIso ? 'Included with the installer.' : 'Downloads when you install it.'}',
        style: t.bodyDim,
      ),
    );
    if (deps.isNotEmpty) {
      p.add(
        Text(
          'Also installs: ${[for (final d in deps) d.name].join(', ')}.',
          style: t.bodyDim,
        ),
      );
    }
    if (app.hasTerms) {
      p.add(
        Text(
          "${app.terms!.vendor}'s terms apply (version ${app.terms!.version}).",
          style: t.bodyDim,
        ),
      );
    }
    p.add(
      Text(installed ? 'Installed.' : 'Not installed.', style: t.label),
      gap: HinterTokens.s3,
    );
    final cat = widget.catalog;
    p.buttons('actions', [
      if (installed) ...[
        btn('Back', widget.modal.close),
        btn(
          'Remove',
          () => removeFlow(context, widget.services, app),
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
      subtitle: '${app.category.label}: ${app.summary}',
      leading: AppIconBadge(
        name: app.name,
        iconPath: widget.iconPath,
        size: 128,
      ),
      child: SingleChildScrollView(clipBehavior: Clip.none, child: p.build()),
    );
  }
}
