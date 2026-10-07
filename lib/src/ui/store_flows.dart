import 'package:flutter/material.dart';

import '../system/models.dart';
import '../system/repositories.dart';
import 'dialogs.dart';
import 'pages.dart';
import 'system/common.dart';
import 'widgets.dart';

String _sizeLabel(int mib) =>
    mib >= 1000 ? '${(mib / 1024).toStringAsFixed(1)} GB' : '$mib MB';

/// The extra apps an install of [app] brings along (transitive depends are
/// resolved by the repository; the index lists direct ones, which is what is
/// shown) that are not installed yet.
List<StoreApp> missingDependencies(
  StoreApp app,
  List<StoreApp> catalog,
  Set<String> installed,
) => [
  for (final id in app.depends)
    if (!installed.contains(id)) ?catalog.where((a) => a.id == id).firstOrNull,
];

/// Install flow: confirm (size, dependencies) -> vendor terms in full when
/// there are any -> the install job with its progress page. Returns whether
/// the app got installed.
Future<bool> installFlow(
  BuildContext context,
  SystemServices services,
  StoreApp app,
  List<StoreApp> catalog,
) async {
  final deps = missingDependencies(app, catalog, services.store.installed);
  final total = app.sizeMiB + deps.fold<int>(0, (s, d) => s + d.sizeMiB);
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
      if (app.hasTerms)
        StatusLine(
          '${app.terms!.title} applies. You read it in full next, '
          'and accept it to install.',
        ),
    ],
    confirmLabel: app.hasTerms ? 'Continue' : 'Install',
  );
  if (ok == null || !context.mounted) return false;
  String? terms;
  if (app.hasTerms) {
    if (!await showTerms(context, app) || !context.mounted) return false;
    terms = app.terms!.version;
  }
  return runJob(
    context,
    services,
    () => services.store.install(app.id, acceptedTerms: terms),
    subtitle: app.name,
  );
}

/// Remove flow: confirm with the "also delete data" option; ticking it asks a
/// second time (naming Steam's games where they would go too).
Future<bool> removeFlow(
  BuildContext context,
  SystemServices services,
  StoreApp app,
) async {
  final warning = app.removeDataWarning;
  final first = await showConfirm(
    context,
    title: 'Remove ${app.name}?',
    body:
        'The app is removed from this box. Its settings and files stay, so '
        'installing it again picks up where you left off.',
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
  return runJob(
    context,
    services,
    () => services.store.remove(app.id, deleteData: first.checked),
    subtitle: app.name,
  );
}
