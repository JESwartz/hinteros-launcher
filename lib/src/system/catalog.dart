/// The catalog index (`hinteros-catalog` `schema/index.schema.json`),
/// shared by the installer and the Store. One model ([StoreApp]), one parser.
library;

import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Where the system keeps the catalog index (the ISO has the same path). The
/// vendor terms are installed next to it, under `terms/`.
const catalogIndexPath = '/run/current-system/sw/share/hinteros/catalog.json';

/// The index versions this parser reads: 3 (catalog format 3: `type`,
/// `starter`) and 2 (`kind`, `installer`, `installerDefault`), the one of
/// older systems.
const catalogIndexVersions = {2, 3};

/// Reads a terms file named by an index entry (`terms/<id>-<version>.txt`,
/// relative to the index). Null when it is missing or unreadable.
typedef TermsReader = String? Function(String file);

/// A [TermsReader] for the terms files that sit next to the index at
/// [indexPath].
TermsReader termsReaderFor(String indexPath) {
  final dir = File(indexPath).parent.path;
  return (file) {
    // The schema only allows `terms/<name>.txt`; refuse anything else so a
    // damaged index cannot make us read arbitrary files.
    if (!RegExp(r'^terms/[A-Za-z0-9._-]+\.txt$').hasMatch(file) ||
        file.contains('..')) {
      return null;
    }
    try {
      return File('$dir/$file').readAsStringSync();
    } on FileSystemException {
      return null;
    }
  };
}

/// The apps of an index, in its order: `status` available only (retired and
/// removed entries are hidden), each with its terms text read through
/// [readTerms]. An unfree entry (`free: false`) whose terms are missing,
/// malformed or unreadable is left out: it could not be accepted, so it is
/// never offered. Unknown categories become Other, unknown fields are ignored.
/// Throws [FormatException] for another index version or shape.
List<StoreApp> parseCatalogIndex(
  String source, {
  required TermsReader readTerms,
}) {
  final j = jsonDecode(source);
  if (j is! Map ||
      !catalogIndexVersions.contains(j['indexVersion']) ||
      j['apps'] is! List) {
    throw const FormatException('unknown catalog index');
  }
  final apps = <StoreApp>[];
  for (final a in j['apps'] as List) {
    if (a is! Map<String, Object?>) continue;
    final app = _parseApp(a, readTerms);
    if (app != null) apps.add(app);
  }
  return apps;
}

/// Reads and parses the index at [path] with the terms next to it. Throws
/// [FileSystemException] or [FormatException].
List<StoreApp> loadCatalogIndex([String path = catalogIndexPath]) =>
    parseCatalogIndex(
      File(path).readAsStringSync(),
      readTerms: termsReaderFor(path),
    );

String? _str(Object? v) => v is String ? v : null;
List<String> _strs(Object? v) =>
    v is List ? v.whereType<String>().toList() : [];

StoreApp? _parseApp(Map<String, Object?> a, TermsReader readTerms) {
  final id = _str(a['id']);
  final name = _str(a['name']);
  if (id == null || name == null) return null;
  final status = a['status'];
  if (status != 'available') return null;
  // Services (index 3, `kind: service`) are not apps of a profile.
  if (a['kind'] == 'service') return null;

  VendorTerms? terms;
  final t = a['terms'];
  if (t is Map) {
    final file = _str(t['file']);
    final version = _str(t['version']);
    final text = file == null ? null : readTerms(file);
    if (file != null && version != null && text != null && text.isNotEmpty) {
      terms = VendorTerms(
        title: _str(t['title']) ?? '$name terms',
        version: version,
        url: _str(t['url']) ?? '',
        retrieved: _str(t['retrieved']) ?? '',
        file: file,
        text: text,
      );
    }
  }
  // The safety rule: unfree without readable terms is never offered.
  if (a['free'] != true && terms == null) return null;

  final icon = a['icon'];
  final dataPaths = _strs(a['dataPaths']);
  final size = a['sizeMiB'];
  return StoreApp(
    id: id,
    name: name,
    summary: _str(a['summary']) ?? '',
    description: _str(a['description']) ?? '',
    category: StoreCategory.parse(_str(a['category'])),
    sizeMiB: size is num ? size.toInt() : 0,
    homepage: _str(a['homepage']) ?? '',
    // Index 3 has `type` (web/native/service); index 2 had `kind`.
    isWeb: (a['type'] ?? a['kind']) == 'web',
    depends: _strs(a['depends']),
    conflicts: _strs(a['conflicts']),
    terms: terms,
    free: a['free'] == true,
    // Index 3: `starter` offered/ticked; index 2: installer/installerDefault.
    installer: a['starter'] != null || a['installer'] == true,
    installerDefault: a['starter'] == 'ticked' || a['installerDefault'] == true,
    onIso: a['onIso'] == true,
    buildsOnDevice: a['buildsOnDevice'] == true,
    dataPaths: dataPaths,
    icon: icon is Map
        ? StoreIcon(
            desktopId: _str(icon['desktopId']),
            iconUrl: _str(icon['iconUrl']),
            siteUrl: _str(icon['siteUrl']),
            firefoxProfile: icon['firefoxProfile'] == true,
          )
        : const StoreIcon(),
    // Index 3 (optional): `permissions`, name -> "required" / "optional".
    permissions: [
      if (a['permissions'] case final Map<String, Object?> perms)
        for (final e in perms.entries)
          AppPermission(name: e.key, required: e.value == 'required'),
    ],
    // Index 3 (optional, apps): `sandbox`, missing = true.
    fullAccess: a['sandbox'] == false,
    removeDataWarning: removeDataWarningFor(dataPaths),
  );
}

/// What removing an app together with its data costs beyond the app itself,
/// for the apps whose data paths hold more than settings (Steam: the games).
String? removeDataWarningFor(List<String> dataPaths) =>
    dataPaths.contains('.local/share/Steam')
    ? 'Games this profile installed through Steam are deleted too. They '
          'have to be downloaded again.'
    : null;
