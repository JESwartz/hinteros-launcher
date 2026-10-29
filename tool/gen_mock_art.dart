// Draws the placeholder game artwork used by the mock daemon in tests and
// goldens (test/fixtures/art/*.png): sky, sun and mountain layers, no text, no
// network, no third-party pictures. Deterministic; the PNGs are committed.
// With --demo: the browser demo's games instead (assets/demo/art/*.png, on the
// web-demo branch).
//
//   dart tool/gen_mock_art.dart [--demo]
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

typedef Rgb = (int, int, int);

class Palette {
  const Palette(this.skyTop, this.skyBottom, this.sun, this.ranges, this.seed);
  final Rgb skyTop;
  final Rgb skyBottom;
  final Rgb sun;
  final List<Rgb> ranges;
  final double seed;
}

Rgb _mix(Rgb a, Rgb b, double t) => (
  (a.$1 + (b.$1 - a.$1) * t).round().clamp(0, 255),
  (a.$2 + (b.$2 - a.$2) * t).round().clamp(0, 255),
  (a.$3 + (b.$3 - a.$3) * t).round().clamp(0, 255),
);

Uint8List render(int w, int h, Palette p) {
  final rgb = Uint8List(w * h * 3);
  final unit = math.min(w, h).toDouble();
  final sunX = w * 0.64, sunY = h * 0.40, sunR = unit * 0.16;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = y / h;
      var c = _mix(p.skyTop, p.skyBottom, math.pow(v, 1.4).toDouble());
      // Sun with a soft glow.
      final d = math.sqrt(math.pow(x - sunX, 2) + math.pow(y - sunY, 2));
      if (d < sunR) {
        c = _mix(c, p.sun, 0.95);
      } else if (d < sunR * 2.6) {
        c = _mix(c, p.sun, 0.35 * (1 - (d - sunR) / (sunR * 1.6)));
      }
      // Mountain ranges, far to near.
      for (var i = 0; i < p.ranges.length; i++) {
        final base = h * (0.52 + 0.15 * i);
        final amp = h * (0.10 - 0.012 * i);
        final u = x / w * (3 + i * 1.7) + p.seed + i * 2.3;
        final ridge =
            base -
            amp *
                (0.6 * math.sin(u) +
                    0.3 * math.sin(2.7 * u + 1) +
                    0.1 * math.sin(7 * u));
        if (y > ridge) c = p.ranges[i];
      }
      final o = (y * w + x) * 3;
      rgb[o] = c.$1;
      rgb[o + 1] = c.$2;
      rgb[o + 2] = c.$3;
    }
  }
  return rgb;
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List png(int w, int h, Uint8List rgb) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    raw.add(Uint8List.sublistView(rgb, y * w * 3, (y + 1) * w * 3));
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(body)
      ..add((ByteData(4)..setUint32(0, _crc(body))).buffer.asUint8List());
  }

  chunk(
    'IHDR',
    (ByteData(13)
          ..setUint32(0, w)
          ..setUint32(4, h)
          ..setUint8(8, 8)
          ..setUint8(9, 2))
        .buffer
        .asUint8List(),
  );
  chunk('IDAT', zlib.encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

const games = <String, Palette>{
  'celeste': Palette(
    (0x1b, 0x2a, 0x6b),
    (0xe8, 0x79, 0x8a),
    (0xff, 0xd9, 0xa0),
    [
      (0x5a, 0x3f, 0x7a),
      (0x3b, 0x2a, 0x5c),
      (0x24, 0x1a, 0x3d),
      (0x15, 0x0f, 0x26),
    ],
    0.3,
  ),
  'hades': Palette(
    (0x3a, 0x0d, 0x12),
    (0xd1, 0x45, 0x1f),
    (0xff, 0xb3, 0x47),
    [
      (0x6b, 0x1a, 0x16),
      (0x4a, 0x10, 0x12),
      (0x2a, 0x0a, 0x0f),
      (0x14, 0x05, 0x08),
    ],
    1.7,
  ),
  'hollow': Palette(
    (0x0b, 0x1a, 0x24),
    (0x4a, 0x7a, 0x8c),
    (0xd9, 0xee, 0xf2),
    [
      (0x2b, 0x50, 0x60),
      (0x1b, 0x38, 0x46),
      (0x10, 0x26, 0x30),
      (0x08, 0x14, 0x1a),
    ],
    4.1,
  ),
  'portal': Palette(
    (0x10, 0x18, 0x20),
    (0xe3, 0xa0, 0x2b),
    (0xff, 0xf2, 0xc9),
    [
      (0x4a, 0x58, 0x66),
      (0x30, 0x3c, 0x48),
      (0x1c, 0x26, 0x30),
      (0x0c, 0x12, 0x18),
    ],
    2.6,
  ),
};

/// The browser demo's games (lib/web_main.dart on the web-demo branch), by
/// catalog id.
const demoGames = <String, Palette>{
  'supertuxkart': Palette(
    (0x0d, 0x3b, 0x66),
    (0x6c, 0xc4, 0xe8),
    (0xff, 0xf4, 0xb8),
    [
      (0x3f, 0x8f, 0x4a),
      (0x2c, 0x6e, 0x38),
      (0x1d, 0x4f, 0x28),
      (0x10, 0x30, 0x18),
    ],
    0.9,
  ),
  'openarena': Palette(
    (0x12, 0x10, 0x1e),
    (0x8a, 0x2b, 0x5e),
    (0xff, 0x8a, 0x5c),
    [
      (0x4a, 0x24, 0x48),
      (0x33, 0x1a, 0x36),
      (0x21, 0x11, 0x24),
      (0x10, 0x08, 0x12),
    ],
    3.3,
  ),
  'neverball': Palette(
    (0x1e, 0x50, 0x3c),
    (0xd8, 0xe8, 0x9a),
    (0xff, 0xff, 0xe0),
    [
      (0x5c, 0x8a, 0x3a),
      (0x44, 0x6c, 0x2c),
      (0x2e, 0x4c, 0x1e),
      (0x18, 0x2a, 0x10),
    ],
    5.2,
  ),
  'shattered-pixel-dungeon': Palette(
    (0x08, 0x0c, 0x14),
    (0x2e, 0x3e, 0x5a),
    (0xc8, 0xd4, 0xe8),
    [
      (0x3a, 0x40, 0x4c),
      (0x28, 0x2c, 0x36),
      (0x18, 0x1b, 0x22),
      (0x0a, 0x0b, 0x0e),
    ],
    2.1,
  ),
  'freedoom-phase1': Palette(
    (0x26, 0x08, 0x06),
    (0xb8, 0x3a, 0x12),
    (0xff, 0xd0, 0x6a),
    [
      (0x5e, 0x2a, 0x1a),
      (0x44, 0x1c, 0x12),
      (0x2c, 0x10, 0x0a),
      (0x16, 0x07, 0x04),
    ],
    4.6,
  ),
};

void main(List<String> args) {
  if (args.contains('--demo')) {
    final dir = Directory('assets/demo/art')..createSync(recursive: true);
    for (final e in demoGames.entries) {
      for (final (kind, w, h) in [
        ('portrait', 400, 600),
        ('header', 460, 215),
      ]) {
        File('${dir.path}/${e.key}_$kind.png')
            .writeAsBytesSync(png(w, h, render(w, h, e.value)));
      }
    }
    stdout.writeln('wrote ${dir.path}');
    return;
  }
  final dir = Directory('test/fixtures/art')..createSync(recursive: true);
  for (final e in games.entries) {
    for (final (kind, w, h) in [('portrait', 400, 600), ('header', 460, 215)]) {
      // Hollow Knight has no header in the mock (a game without all art).
      if (e.key == 'hollow' && kind == 'header') continue;
      File('${dir.path}/${e.key}_$kind.png')
          .writeAsBytesSync(png(w, h, render(w, h, e.value)));
    }
  }
  stdout.writeln('wrote ${dir.path}');
}
