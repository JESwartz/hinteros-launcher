/// The first launch of an app that came with the starter set and has vendor
/// terms (Steam): the terms in full before it starts (apps.md "Starter set",
/// owner answer: terms on first launch). Accepting records them for this
/// profile (`apps.accept_terms`); declining leaves the app installed and
/// unlaunched, with Remove offered next to it.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../api/api.dart' show App;
import '../../data/launcher_data.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../dialogs.dart';
import '../pages.dart' show showTerms;
import '../store_flows.dart' show removeFlow;

/// Reads the terms text the daemon names; null when it cannot be read.
typedef TermsReader = String? Function(String path);

String? _read(String path) {
  try {
    final t = File(path).readAsStringSync();
    return t.isEmpty ? null : t;
  } on FileSystemException {
    return null;
  }
}

/// Shows [app]'s terms and records the answer. True: accepted, start it.
Future<bool> firstLaunchTerms(
  BuildContext context,
  SystemServices services,
  App app, {
  LauncherData? data,
  TermsReader read = _read,
}) async {
  final t = app.needsTerms;
  if (t == null) return true;
  final text = read(t.file);
  if (text == null) {
    await showMessage(
      context,
      title: "${app.name} can't start yet",
      body:
          "Can't read the terms (${t.title}). Try again after the next "
          'update.',
    );
    return false;
  }
  final asStoreApp = StoreApp(
    id: app.id,
    name: app.name,
    summary: '',
    category: StoreCategory.other,
    sizeMiB: 0,
    terms: VendorTerms(
      title: t.title,
      version: t.version,
      url: t.url,
      retrieved: '',
      file: t.file,
      text: text,
    ),
  );
  if (!context.mounted) return false;
  final ok = await showTerms(
    context,
    asStoreApp,
    acceptLabel: 'Accept and open',
  );
  if (!context.mounted) return false;
  if (!ok) {
    final store = services.store;
    final listed = store.apps.where((a) => a.id == app.id).firstOrNull;
    final choice = await showChoice<String>(
      context,
      title: "${app.name} won't open",
      body:
          '${app.name} stays installed. It opens only after you accept its '
          'terms.',
      choices: [
        const Choice('Keep', 'keep'),
        if (listed != null)
          Choice('Remove ${app.name}', 'remove', danger: true),
      ],
    );
    if (choice == 'remove' && listed != null && context.mounted) {
      await removeFlow(context, services, listed, data: data);
    }
    return false;
  }
  try {
    await services.store.acceptTerms(app.id, t.version);
    return true;
  } on SystemException catch (e) {
    if (context.mounted) {
      await showMessage(
        context,
        title: "${app.name} can't start yet",
        body: e.message,
      );
    }
    return false;
  }
}
