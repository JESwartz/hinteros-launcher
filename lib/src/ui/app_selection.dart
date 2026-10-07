import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../system/models.dart';
import '../theme/hinter_theme.dart';
import 'app_icon_view.dart';
import 'pages.dart';
import 'widgets.dart';

/// The state of the installer's "which apps do you want?" step (M9) and of
/// anything else that picks apps from the catalog: the selection, which
/// vendor terms were accepted, and what that adds up to.
///
/// The apps the catalog marks `installerDefault` are selected at first; the
/// others are opt-in.
class AppSelectionController extends ChangeNotifier {
  AppSelectionController(this.apps, {Set<String>? initial})
    : _selected = {
        for (final a in apps)
          if (initial == null ? a.installerDefault : initial.contains(a.id))
            a.id,
      };

  final List<StoreApp> apps;
  final Set<String> _selected;
  final Map<String, String> _accepted = {};

  Set<String> get selected => Set.unmodifiable(_selected);
  bool isSelected(String id) => _selected.contains(id);

  /// `id -> terms version` for the accepted terms of selected apps.
  Map<String, String> get acceptances => {
    for (final e in _accepted.entries)
      if (_selected.contains(e.key)) e.key: e.value,
  };

  void toggle(String id) {
    if (!_selected.remove(id)) {
      _selected.add(id);
    } else {
      // Unticking withdraws the acceptance: ticking again asks again.
      _accepted.remove(id);
    }
    notifyListeners();
  }

  void accept(StoreApp app) {
    final t = app.terms;
    if (t == null) return;
    _accepted[app.id] = t.version;
    notifyListeners();
  }

  List<StoreApp> get selectedApps => [
    for (final a in apps)
      if (_selected.contains(a.id)) a,
  ];

  /// Selected apps with vendor terms.
  List<StoreApp> get withTerms => [
    for (final a in selectedApps)
      if (a.hasTerms) a,
  ];

  bool termsAccepted(StoreApp a) => _accepted[a.id] == a.terms?.version;

  /// Every selected app with terms has had them accepted.
  bool get termsComplete => withTerms.every(termsAccepted);

  /// Apps (and what they depend on) that are not on the ISO: downloaded
  /// during install, so the box has to be online.
  int get downloadMiB {
    final ids = <String>{};
    for (final a in selectedApps) {
      ids.add(a.id);
      ids.addAll(a.depends);
    }
    return [
      for (final a in apps)
        if (ids.contains(a.id) && !a.onIso) a.sizeMiB,
    ].fold(0, (s, v) => s + v);
  }

  bool get needsNetwork => downloadMiB > 0;

  /// Unticks every app that is not on the ISO (the box is, or went,
  /// offline), withdrawing their terms acceptance.
  void dropDownloads() {
    var changed = false;
    for (final a in apps) {
      if (!a.onIso && _selected.remove(a.id)) {
        _accepted.remove(a.id);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}

/// The step's screen content: a checklist of apps (each saying whether it is
/// on the ISO or needs a download), terms acceptance for selected apps that
/// have terms, and Continue (inactive until the terms are accepted). Put it
/// in a [region] of its own; it scrolls itself and needs a modal host above it (the terms
/// page).
class AppSelectionView extends StatelessWidget {
  const AppSelectionView({
    super.key,
    required this.controller,
    required this.region,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.online = true,
  });

  final AppSelectionController controller;
  final NavRegion region;
  final VoidCallback onContinue;
  final String continueLabel;

  /// Whether the box has a network now. Offline, apps that need a download
  /// are flagged (they can be added later from the Store).
  final bool online;

  static String _size(int mib) =>
      mib >= 1000 ? '${(mib / 1024).toStringAsFixed(1)} GB' : '$mib MB';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = HinterTheme.of(context);
        final c = controller;
        final p = Pane(region);
        for (var i = 0; i < c.apps.length; i++) {
          final a = c.apps[i];
          // Offline, apps that need a download cannot be picked (they can be
          // added later from the Store). The row stays focusable so the
          // reason can be read.
          final blocked = !a.onIso && !online;
          p.item(
            'a$i',
            onSelect: blocked ? null : () => c.toggle(a.id),
            builder: (f) => SettingRow(
              title: a.name,
              focused: f,
              dim: blocked,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckMark(checked: c.isSelected(a.id)),
                  const SizedBox(width: HinterTokens.s2),
                  // No daemon on the ISO, so no resolved icon and no fetching:
                  // the letter tile. The Store gets the daemon's icons.
                  AppIconBadge(name: a.name, iconPath: null, size: 44),
                ],
              ),
              subtitle: [
                a.summary,
                if (a.hasTerms) 'Vendor terms apply.',
              ].join(' '),
              trailing: Text(
                a.onIso
                    ? 'On the installer'
                    : blocked
                    ? 'Needs internet'
                    : 'Download, ${_size(a.sizeMiB)}',
                style: t.caption.copyWith(
                  color: blocked ? t.danger : t.textDim,
                  fontWeight: blocked ? FontWeight.w700 : null,
                ),
              ),
            ),
          );
        }
        final terms = c.withTerms;
        if (terms.isNotEmpty) {
          p.add(
            Text('Terms of the apps you picked', style: t.label),
            gap: HinterTokens.s3,
          );
          for (var i = 0; i < terms.length; i++) {
            final a = terms[i];
            final done = c.termsAccepted(a);
            p.item(
              'terms$i',
              onSelect: () async {
                if (await showTerms(context, a)) c.accept(a);
              },
              builder: (f) => SettingRow(
                title: a.name,
                focused: f,
                subtitle: a.terms!.title,
                trailing: Text(
                  done ? 'Accepted' : 'Read and accept',
                  style: t.bodyDim.copyWith(
                    color: done ? t.positive : t.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }
        }
        p.add(
          Text(
            c.selected.isEmpty
                ? 'Nothing selected. You can add apps later from the Store.'
                : '${c.selected.length} selected. '
                      '${c.needsNetwork ? 'Download: ${_size(c.downloadMiB)}${online ? '' : ', and this box is not online. Apps that need a download can be added later from the Store.'}.' : 'Nothing to download.'}',
            style: t.bodyDim,
          ),
          gap: HinterTokens.s3,
        );
        if (!c.termsComplete) {
          p.add(
            const StatusLine(
              'Accept the terms above to continue, or untick those apps.',
            ),
          );
        }
        p.buttons('continue', [
          btn(
            continueLabel,
            onContinue,
            primary: true,
            enabled: c.termsComplete,
          ),
        ]);
        return SingleChildScrollView(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.all(HinterTokens.s2),
          child: p.build(),
        );
      },
    );
  }
}
