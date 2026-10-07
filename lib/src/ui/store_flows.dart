import 'package:flutter/material.dart';

import '../data/launcher_data.dart';
import '../system/models.dart';
import '../system/repositories.dart';
import 'dialogs.dart';
import 'pages.dart';
import 'system/common.dart';
import 'widgets.dart';

String _sizeLabel(int mib) =>
    mib >= 1000 ? '${(mib / 1024).toStringAsFixed(1)} GB' : '$mib MB';

/// The extra apps an install of [app] brings along (its depends, transitively,
/// as the service resolves them) that are not installed yet.
List<StoreApp> missingDependencies(
  StoreApp app,
  List<StoreApp> catalog,
  Set<String> installed,
) {
  final out = <StoreApp>[];
  void visit(StoreApp a) {
    for (final id in a.depends) {
      if (installed.contains(id) || out.any((o) => o.id == id)) continue;
      final dep = catalog.where((c) => c.id == id).firstOrNull;
      if (dep == null) continue;
      out.add(dep);
      visit(dep);
    }
  }

  visit(app);
  return out;
}

/// Install flow: confirm (size, dependencies) -> the vendor terms of the app
/// and of every app that comes with it, each in full -> the install job with
/// its progress page. Returns whether the app got installed.
///
/// What the service says is handled here: `terms_required` shows the named
/// terms again (a newer version than the list had), `app_conflict` names the
/// app in the way, `insufficient_resources` asks for free space.
Future<bool> installFlow(
  BuildContext context,
  SystemServices services,
  StoreApp app,
  List<StoreApp> catalog,
) async {
  final store = services.store;
  final deps = missingDependencies(app, catalog, store.installed);
  final total = app.sizeMiB + deps.fold<int>(0, (s, d) => s + d.sizeMiB);
  final withTerms = [
    for (final a in [app, ...deps])
      if (a.hasTerms) a,
  ];
  final ok = await showConfirm(
    context,
    title: 'Install ${app.name}?',
    body:
        'Download and disk space: about ${_sizeLabel(total)}.'
        '${app.onIso ? '' : ' It downloads from the internet, so this box has to be online.'}',
    extra: [
      if (deps.isNotEmpty)
        StatusLine(
          'Also installs: ${[for (final d in deps) '${d.name} (${_sizeLabel(d.sizeMiB)})'].join(', ')}.',
        ),
      for (final a in withTerms)
        StatusLine(
          '${a.terms!.title} applies. You read it in full next, '
          'and accept it to install.',
        ),
    ],
    confirmLabel: withTerms.isNotEmpty ? 'Continue' : 'Install',
  );
  if (ok == null || !context.mounted) return false;
  // The exact version the user read, per app.
  final accepted = <String, String>{};
  for (final a in withTerms) {
    if (!await showTerms(context, a) || !context.mounted) return false;
    accepted[a.id] = a.terms!.version;
  }
  final JobHandle? job = await _startInstall(
    context,
    services,
    app,
    catalog,
    accepted,
  );
  if (job == null || !context.mounted) return false;
  final r = await showJobProgress(context, services, job, subtitle: app.name);
  return r?.ok ?? false;
}

String _nameOf(String id, List<StoreApp> catalog) =>
    catalog.where((a) => a.id == id).firstOrNull?.name ?? id;

/// Starts the install, answering what the service asks for. Null: it did not
/// start (a message says why, or the user declined the terms again).
Future<JobHandle?> _startInstall(
  BuildContext context,
  SystemServices services,
  StoreApp app,
  List<StoreApp> catalog,
  Map<String, String> accepted,
) async {
  // terms_required is answered by showing the named terms, a few times at
  // most (once per app that has terms).
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      return await services.store.install(app.id, acceptedTerms: accepted);
    } on SystemException catch (e) {
      if (!context.mounted) return null;
      switch (e.kind) {
        case SystemErrorKind.termsRequired:
          final id = e.data['id'] as String?;
          // The list on screen may be older than the box's catalog.
          final fresh = await services.store.catalog().then(
            (c) => c,
            onError: (_) => catalog,
          );
          final named = fresh.where((a) => a.id == id).firstOrNull;
          if (!context.mounted) return null;
          if (named == null || !named.hasTerms) {
            await showMessage(
              context,
              title: "That didn't work",
              body: describeError(e),
            );
            return null;
          }
          if (!await showTerms(context, named) || !context.mounted) {
            return null;
          }
          accepted = {...accepted, named.id: named.terms!.version};
        case SystemErrorKind.appConflict:
          await showMessage(
            context,
            title: "${app.name} can't be installed",
            body: _conflictText(app, e, catalog),
          );
          return null;
        case SystemErrorKind.insufficientResources:
          await showMessage(
            context,
            title: 'Not enough space',
            body: _spaceText(app, e),
          );
          return null;
        case SystemErrorKind.nothingToDo:
          await showMessage(
            context,
            title: '${app.name} is already installed',
            body: 'Nothing was changed.',
          );
          return null;
        default:
          await showMessage(
            context,
            title: "That didn't work",
            body: describeError(e),
          );
          return null;
      }
    }
  }
  return null;
}

/// `app_conflict` on install: [id] cannot be on the box with
/// [conflicts_with]. Names the apps, and says what to do.
String _conflictText(StoreApp app, SystemException e, List<StoreApp> catalog) {
  final a = _nameOf(e.data['id'] as String? ?? app.id, catalog);
  final b = _nameOf(e.data['conflicts_with'] as String? ?? '', catalog);
  if ((e.data['id'] as String? ?? app.id) == app.id) {
    return '$a cannot be installed together with $b. Remove $b first if you '
        'want $a.';
  }
  return '$a, which comes with ${app.name}, cannot be installed together '
      'with $b. Remove $b first if you want ${app.name}.';
}

String _spaceText(StoreApp app, SystemException e) {
  String size(Object? bytes) =>
      bytes is num ? _sizeLabel((bytes / (1 << 20)).ceil()) : '';
  final need = size(e.data['needed_bytes']);
  final have = size(e.data['available_bytes']);
  final disk = e.data['kind'] != 'memory';
  if (!disk) {
    return 'There is not enough free memory to install ${app.name} right '
        'now. Close apps and games that are running and try again.';
  }
  return 'There is not enough free space to install ${app.name}'
      '${need.isEmpty ? '' : ' (it needs about $need${have.isEmpty ? '' : ', $have are free'})'}. '
      'Remove an app you do not use or delete files, then try again.';
}

/// "Install Steam" on the Games tab: the same flow as in the Store.
Future<void> installSteam(BuildContext context, SystemServices services) async {
  final List<StoreApp> catalog;
  try {
    catalog = services.store.loaded
        ? services.store.apps
        : await services.store.catalog();
  } on SystemException catch (e) {
    if (!context.mounted) return;
    await showMessage(
      context,
      title: "The Store isn't available",
      body: describeError(e),
    );
    return;
  }
  if (!context.mounted) return;
  final steam = catalog.where((a) => a.id == 'steam').firstOrNull;
  if (steam == null) {
    await showMessage(
      context,
      title: "Steam isn't in the Store",
      body: 'This version of HinterOS does not offer Steam.',
    );
    return;
  }
  await installFlow(context, services, steam, catalog);
}

/// Remove flow: confirm with the "also delete data" option; ticking it asks a
/// second time (naming Steam's games where they would go too). A running app
/// is closed first ([data] knows which run).
Future<bool> removeFlow(
  BuildContext context,
  SystemServices services,
  StoreApp app, {
  LauncherData? data,
}) async {
  final warning = app.removeDataWarning;
  final running = data?.isRunning(app.id) ?? false;
  final first = await showConfirm(
    context,
    title: 'Remove ${app.name}?',
    body:
        'The app is removed from this box. Its settings and files stay, so '
        'installing it again picks up where you left off.'
        '${running ? ' ${app.name} is running now and is closed first.' : ''}',
    checkbox: "Also delete this app's data in all profiles",
    checkboxHint:
        warning ?? 'Logins, settings and saved files, in every profile.',
    confirmLabel: 'Remove',
    danger: true,
  );
  if (first == null || !context.mounted) return false;
  if (first.checked) {
    final second = await showConfirm(
      context,
      title: 'Delete all data of ${app.name}?',
      body:
          "This deletes ${app.name}'s data in every profile. It cannot be "
          'undone.',
      extra: [if (warning != null) StatusLine(warning, error: true)],
      confirmLabel: 'Delete data and remove',
      danger: true,
    );
    if (second == null || !context.mounted) return false;
  }
  final catalog = services.store.apps;
  final JobHandle job;
  try {
    if (running) await data!.closeApp(app.id);
    job = await services.store.remove(app.id, deleteData: first.checked);
  } on SystemException catch (e) {
    if (!context.mounted) return false;
    await showMessage(
      context,
      title: "${app.name} can't be removed",
      body: e.kind == SystemErrorKind.appConflict
          ? '${_nameOf(e.data['conflicts_with'] as String? ?? '', catalog)} '
                'needs ${app.name}. Remove ${_nameOf(e.data['conflicts_with'] as String? ?? '', catalog)} first.'
          : describeError(e),
    );
    return false;
  }
  if (!context.mounted) return false;
  final r = await showJobProgress(context, services, job, subtitle: app.name);
  return r?.ok ?? false;
}
