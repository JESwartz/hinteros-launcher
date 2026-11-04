/// The catalog index (`hinteros-catalog` `schema/index.schema.json`),
/// shared by the installer and the Store. One model ([StoreApp]), one parser.
library;

import 'dart:convert';
import 'dart:io';

import '../platform/local_files.dart';
import 'models.dart';

/// Where the system keeps the catalog index (the ISO has the same path). The
/// vendor terms are installed next to it, under `terms/`.
const catalogIndexPath = '/run/current-system/sw/share/hinteros/catalog.json';

/// The index version this parser reads.
const catalogIndexVersion = 4;

/// Reads a terms file named by an index entry (`terms/<id>-<version>.txt`,
/// relative to the index). Null when it is missing or unreadable.
typedef TermsReader = String? Function(String file);

/// A [TermsReader] for the terms files that sit next to the index at
/// [indexPath].
TermsReader termsReaderFor(String indexPath) {
  final dir = _dirOf(indexPath);
  return (file) {
    // The schema only allows `terms/<name>.txt`; refuse anything else so a
    // damaged index cannot make us read arbitrary files.
    if (!RegExp(r'^terms/[A-Za-z0-9._-]+\.txt$').hasMatch(file) ||
        file.contains('..')) {
      return null;
    }
    return readLocalText('$dir/$file');
  };
}

/// The directory part of [path] (by string: in the browser demo a path is
/// an asset key).
String _dirOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? '.' : path.substring(0, slash);
}

/// A [TermsReader] for the READMEs next to the index at [indexPath]
/// (`readme/<id>.md`).
TermsReader readmeReaderFor(String indexPath) {
  final dir = _dirOf(indexPath);
  return (file) {
    if (!RegExp(r'^readme/[A-Za-z0-9._-]+\.md$').hasMatch(file) ||
        file.contains('..')) {
      return null;
    }
    return readReadmeFile('$dir/$file');
  };
}

/// The README at [path], or null when it is missing, empty, unreadable or
/// over 64 KiB (the catalog's limit).
String? readReadmeFile(String path) {
  final t = readLocalText(path, maxBytes: 64 * 1024);
  return t == null || t.trim().isEmpty ? null : t;
}

/// The apps of an index, in its order: `status` available only (retired and
/// removed entries are hidden), each with its terms text read through
/// [readTerms]. An unfree entry (not `unfree: false`) whose terms are missing,
/// malformed or unreadable is left out: it could not be accepted, so it is
/// never offered. Unknown categories become Other, unknown fields are ignored.
/// Throws [FormatException] for another index version or shape.
List<StoreApp> parseCatalogIndex(
  String source, {
  required TermsReader readTerms,
  TermsReader? readReadme,
}) {
  final j = jsonDecode(source);
  if (j is! Map ||
      j['indexVersion'] != catalogIndexVersion ||
      j['entries'] is! List) {
    throw const FormatException('unknown catalog index');
  }
  final apps = <StoreApp>[];
  for (final a in j['entries'] as List) {
    if (a is! Map<String, Object?>) continue;
    final app = _parseApp(a, readTerms, readReadme);
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
      readReadme: readmeReaderFor(path),
    );

String? _str(Object? v) => v is String ? v : null;
List<String> _strs(Object? v) =>
    v is List ? v.whereType<String>().toList() : [];

StoreApp? _parseApp(
  Map<String, Object?> a,
  TermsReader readTerms,
  TermsReader? readReadme,
) {
  final id = _str(a['id']);
  final name = _str(a['name']);
  if (id == null || name == null) return null;
  final status = a['status'];
  if (status != 'available') return null;
  // Only apps (a missing kind is one): services are box-wide, and a kind
  // of a newer catalog is ignored (the schema's rule).
  if (a['kind'] case final k? when k != 'app') return null;

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
  final unfree = a['unfree'] != false;
  if (unfree && terms == null) return null;

  StoreReadme? readme;
  if (a['readme'] case {'file': final String file} && final r) {
    final text = readReadme?.call(file);
    if (text != null) {
      readme = StoreReadme(url: _str(r['url']) ?? '', text: text);
    }
  }

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
    depends: _strs(a['depends']),
    conflicts: _strs(a['conflicts']),
    terms: terms,
    readme: readme,
    unfree: unfree,
    installer: a['starter'] == 'offered' || a['starter'] == 'ticked',
    installerDefault: a['starter'] == 'ticked',
    onIso: a['onIso'] == true,
    delivery: a['delivery'] == 'download' || a['delivery'] == null
        ? AppDelivery.download
        : AppDelivery.build,
    dataPaths: dataPaths,
    icon: icon is Map
        ? StoreIcon(
            desktopId: _str(icon['desktopId']),
            iconUrl: _str(icon['iconUrl']),
            siteUrl: _str(icon['siteUrl']),
            firefoxProfile: icon['firefoxProfile'] == true,
          )
        : const StoreIcon(),
    // Optional: `permissions`, name -> "required" / "optional". Like the
    // system: an unknown name is ignored (not enforced), an unknown level
    // is required (it cannot be switched off).
    permissions: [
      if (a['permissions'] case final Map<String, Object?> perms)
        for (final e in perms.entries)
          if (knownPermissions.contains(e.key))
            AppPermission(name: e.key, required: e.value != 'optional'),
    ],
    // Optional (apps): `sandbox`, missing = true.
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
