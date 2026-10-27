import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Whether the file at [path] exists.
bool localFileExists(String path) => File(path).existsSync();

/// The text of the file at [path]; null when it is missing, unreadable or
/// longer than [maxBytes].
String? readLocalText(String path, {int? maxBytes}) {
  try {
    final f = File(path);
    if (maxBytes != null && f.lengthSync() > maxBytes) return null;
    return f.readAsStringSync();
  } on FileSystemException {
    return null;
  }
}

/// The bytes of the file at [path]. Throws when it cannot be read.
Future<Uint8List> readLocalBytes(String path) => File(path).readAsBytes();

/// An image from the file at [path].
ImageProvider localImage(String path) => FileImage(File(path));

/// [path] made absolute.
String localAbsolute(String path) => File(path).absolute.path;

/// Whether paths are asset keys (the browser) rather than files.
const localFilesAreAssets = false;
