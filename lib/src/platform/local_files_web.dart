import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

final _keys = <String>{};
final _texts = <String, String>{};

/// Loads the asset list, and the text of the assets under [textPrefixes],
/// so the synchronous calls below can answer. Call once before `runApp`.
Future<void> preloadLocalFiles({List<String> textPrefixes = const []}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  _keys.addAll(manifest.listAssets());
  for (final k in _keys) {
    if (textPrefixes.any(k.startsWith)) {
      _texts[k] = await rootBundle.loadString(k, cache: false);
    }
  }
}

bool localFileExists(String path) => _keys.contains(path);

String? readLocalText(String path, {int? maxBytes}) {
  final t = _texts[path];
  if (t == null || maxBytes == null) return t;
  return utf8.encode(t).length > maxBytes ? null : t;
}

Future<Uint8List> readLocalBytes(String path) async =>
    (await rootBundle.load(path)).buffer.asUint8List();

ImageProvider localImage(String path) => AssetImage(path);

String localAbsolute(String path) => path;

const localFilesAreAssets = true;
