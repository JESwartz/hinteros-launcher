import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show ChangeNotifier, listEquals, visibleForTesting;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_svg/flutter_svg.dart';

/// A decoded app icon: a raster image (SVGs are rasterised once, here) plus
/// the two numbers the tile needs to pick a backdrop.
class AppIcon {
  const AppIcon({
    required this.image,
    required this.tint,
    required this.luminance,
  });

  /// At most [AppIconCache.maxEdge] px on the long side.
  final ui.Image image;

  /// The icon's dominant colour (saturated colours count more than greys).
  final Color tint;

  /// Mean relative luminance (0 black .. 1 white) of the visible pixels.
  final double luminance;
}

/// What the cache knows about one path. [icon] is null when the file is
/// missing or not an image (the tile then falls back to the letter).
class AppIconEntry {
  const AppIconEntry(this.path, this.icon, this.revision, this._bytes);

  final String path;
  final AppIcon? icon;
  final int revision;
  final Uint8List? _bytes;
}

/// Loads, decodes and remembers app icons by path.
///
/// The daemon may replace the file behind a path (a web icon refreshed, an
/// icon theme updated), so an entry is only good for one [revision]: when
/// `apps.list` is queried again the launcher calls [invalidate], and the next
/// [load] of a path re-reads the file, keeping the decoded icon if the bytes
/// are the same. Until then the old icon stays on screen.
class AppIconCache extends ChangeNotifier {
  AppIconCache();

  static final AppIconCache instance = AppIconCache();

  /// Long side of the decoded image: enough for a 4K tile, small in memory.
  static const maxEdge = 512;

  int _revision = 0;
  int get revision => _revision;
  final _entries = <String, AppIconEntry>{};
  final _loading = <String, Future<AppIconEntry>>{};

  /// Forgets loads in flight. A load started inside a widget test's fake-async
  /// zone never finishes (no real file IO there); tests call this, then load
  /// again with real async.
  @visibleForTesting
  void debugForgetInFlight() => _loading.clear();

  /// Marks everything possibly stale.
  void invalidate() => _revision++;

  /// The entry for [path] if one was loaded (possibly for an older revision).
  AppIconEntry? peek(String path) => _entries[path];

  /// Whether [e] is current.
  bool isFresh(AppIconEntry? e) => e != null && e.revision == _revision;

  Future<AppIconEntry> load(String path) {
    final have = _entries[path];
    if (isFresh(have)) return Future.value(have);
    return _loading[path] ??= _load(path, have).whenComplete(() {
      _loading.remove(path);
    });
  }

  Future<AppIconEntry> _load(String path, AppIconEntry? old) async {
    final rev = _revision;
    AppIconEntry done(AppIcon? icon, Uint8List? bytes) {
      final e = _entries[path] = AppIconEntry(path, icon, rev, bytes);
      notifyListeners();
      return e;
    }

    Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      return done(null, null);
    }
    final oldBytes = old?._bytes;
    if (old != null && oldBytes != null && listEquals(oldBytes, bytes)) {
      return done(old.icon, bytes);
    }
    try {
      final image = looksLikeSvg(bytes)
          ? await _rasteriseSvg(bytes)
          : await _decodeRaster(bytes);
      final (tint, luma) = await analyse(image);
      return done(AppIcon(image: image, tint: tint, luminance: luma), bytes);
    } catch (_) {
      return done(null, bytes);
    }
  }

  /// SVG text (maybe after an XML prolog, BOM or comments) rather than a
  /// raster format.
  static bool looksLikeSvg(Uint8List bytes) {
    final head = String.fromCharCodes(
      bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes,
    );
    return head.contains('<svg');
  }

  static Future<ui.Image> _decodeRaster(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final d = await ui.ImageDescriptor.encoded(buffer);
      try {
        final wide = d.width >= d.height;
        final big = math.max(d.width, d.height) > maxEdge;
        final codec = await d.instantiateCodec(
          targetWidth: big && wide ? maxEdge : null,
          targetHeight: big && !wide ? maxEdge : null,
        );
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } finally {
        d.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  static Future<ui.Image> _rasteriseSvg(Uint8List bytes) async {
    final info = await vg.loadPicture(SvgBytesLoader(bytes), null);
    try {
      final s = info.size;
      if (s.isEmpty) throw const FormatException('empty svg');
      final k = maxEdge / math.max(s.width, s.height);
      final w = math.max(1, (s.width * k).round());
      final h = math.max(1, (s.height * k).round());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(w / s.width, h / s.height);
      canvas.drawPicture(info.picture);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(w, h);
      } finally {
        picture.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }

  /// Dominant colour and mean luminance from a coarse grid of samples (about
  /// 4000), cheap enough to do on the UI isolate once per icon.
  static Future<(Color, double)> analyse(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return (const Color(0xFF808080), 0.5);
    final w = image.width, h = image.height;
    final step = math.max(1, math.max(w, h) ~/ 64);
    var sr = 0.0, sg = 0.0, sb = 0.0, sw = 0.0, lum = 0.0, n = 0;
    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        final o = (y * w + x) * 4;
        final a = data.getUint8(o + 3);
        if (a < 128) continue;
        final r = data.getUint8(o) / 255;
        final g = data.getUint8(o + 1) / 255;
        final b = data.getUint8(o + 2) / 255;
        final mx = math.max(r, math.max(g, b));
        final mn = math.min(r, math.min(g, b));
        // Saturated pixels say more about "the" colour than greys do.
        final wt = 0.05 + (mx - mn) * (0.3 + mx);
        sr += r * wt;
        sg += g * wt;
        sb += b * wt;
        sw += wt;
        lum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
        n++;
      }
    }
    if (n == 0) return (const Color(0xFF808080), 0.5);
    return (
      Color.from(alpha: 1, red: sr / sw, green: sg / sw, blue: sb / sw),
      lum / n,
    );
  }
}
