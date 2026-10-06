// Draws the generic placeholder app icons used by the mock daemon in tests and
// goldens (test/fixtures/icons/<app-id>.png|svg): plain geometric shapes on a
// transparent background, no text, no logos, no network. Deterministic; the
// files are committed.
//
//   dart tool/gen_mock_icons.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

typedef Rgb = (int, int, int);

const size = 256;
const ss = 3; // supersampling per axis

/// One shape: coverage test in unit coordinates (0..1) and its colour at a point.
class Shape {
  const Shape(this.inside, this.color);
  final bool Function(double x, double y) inside;
  final Rgb Function(double x, double y) color;
}

Rgb Function(double, double) flat(Rgb c) =>
    (_, _) => c;

Rgb _mix(Rgb a, Rgb b, double t) => (
  (a.$1 + (b.$1 - a.$1) * t).round().clamp(0, 255),
  (a.$2 + (b.$2 - a.$2) * t).round().clamp(0, 255),
  (a.$3 + (b.$3 - a.$3) * t).round().clamp(0, 255),
);

/// Vertical gradient from [a] (top) to [b] (bottom).
Rgb Function(double, double) vgrad(Rgb a, Rgb b) =>
    (_, y) => _mix(a, b, y);

bool Function(double, double) disc(double cx, double cy, double r) =>
    (x, y) => math.pow(x - cx, 2) + math.pow(y - cy, 2) <= r * r;

bool Function(double, double) ring(
  double cx,
  double cy,
  double r0,
  double r1,
) => (x, y) {
  final d2 = math.pow(x - cx, 2) + math.pow(y - cy, 2);
  return d2 <= r1 * r1 && d2 >= r0 * r0;
};

bool Function(double, double) roundRect(
  double x0,
  double y0,
  double x1,
  double y1,
  double r,
) => (x, y) {
  final cx = x.clamp(x0 + r, x1 - r);
  final cy = y.clamp(y0 + r, y1 - r);
  return x >= x0 &&
      x <= x1 &&
      y >= y0 &&
      y <= y1 &&
      math.pow(x - cx, 2) + math.pow(y - cy, 2) <= r * r;
};

bool Function(double, double) polygon(List<(double, double)> p) => (x, y) {
  var inside = false;
  for (var i = 0, j = p.length - 1; i < p.length; j = i++) {
    final (xi, yi) = p[i];
    final (xj, yj) = p[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
};

List<(double, double)> regular(int n, double r, {double rot = -math.pi / 2}) =>
    [
      for (var i = 0; i < n; i++)
        (
          0.5 + r * math.cos(rot + 2 * math.pi * i / n),
          0.5 + r * math.sin(rot + 2 * math.pi * i / n),
        ),
    ];

List<(double, double)> star(int n, double r0, double r1) => [
  for (var i = 0; i < 2 * n; i++)
    (
      0.5 + (i.isEven ? r1 : r0) * math.cos(-math.pi / 2 + math.pi * i / n),
      0.5 + (i.isEven ? r1 : r0) * math.sin(-math.pi / 2 + math.pi * i / n),
    ),
];

Uint8List render(List<Shape> shapes) {
  final rgba = Uint8List(size * size * 4);
  for (var py = 0; py < size; py++) {
    for (var px = 0; px < size; px++) {
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final x = (px + (sx + 0.5) / ss) / size;
          final y = (py + (sy + 0.5) / ss) / size;
          Rgb? c;
          for (final s in shapes) {
            if (s.inside(x, y)) c = s.color(x, y);
          }
          if (c != null) {
            r += c.$1;
            g += c.$2;
            b += c.$3;
            a += 1;
          }
        }
      }
      final o = (py * size + px) * 4;
      if (a > 0) {
        rgba[o] = (r / a).round();
        rgba[o + 1] = (g / a).round();
        rgba[o + 2] = (b / a).round();
        rgba[o + 3] = (255 * a / (ss * ss)).round();
      }
    }
  }
  return rgba;
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

Uint8List png(Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0);
    raw.add(Uint8List.sublistView(rgba, y * size * 4, (y + 1) * size * 4));
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
          ..setUint32(0, size)
          ..setUint32(4, size)
          ..setUint8(8, 8)
          ..setUint8(9, 6) // RGBA
          ..setUint8(10, 0)
          ..setUint8(11, 0)
          ..setUint8(12, 0))
        .buffer
        .asUint8List(),
  );
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

const white = (0xf6, 0xf7, 0xfb);

final icons = <String, List<Shape>>{
  // Teal ring around a dot: no background.
  'steam': [
    Shape(
      ring(0.5, 0.5, 0.27, 0.43),
      vgrad((0x3f, 0xd0, 0xc6), (0x1c, 0x86, 0xa8)),
    ),
    Shape(disc(0.5, 0.5, 0.13), flat((0x3f, 0xd0, 0xc6))),
  ],
  // Green rounded square with a white ring.
  'jellyfin': [
    Shape(
      roundRect(0.08, 0.08, 0.92, 0.92, 0.2),
      vgrad((0x5c, 0xc4, 0x6a), (0x2a, 0x8a, 0x46)),
    ),
    Shape(ring(0.5, 0.5, 0.12, 0.24), flat(white)),
  ],
  // Orange hexagon with a white disc.
  'youtube': [
    Shape(
      polygon(regular(6, 0.46)),
      vgrad((0xff, 0x9a, 0x3c), (0xe0, 0x4a, 0x1f)),
    ),
    Shape(disc(0.5, 0.5, 0.16), flat(white)),
  ],
  // Very dark star: needs a light tile background to be seen.
  'firefox': [
    Shape(
      polygon(star(7, 0.24, 0.46)),
      vgrad((0x2a, 0x2d, 0x3a), (0x12, 0x14, 0x1c)),
    ),
    Shape(disc(0.5, 0.5, 0.1), flat((0x6b, 0x72, 0x88))),
  ],
  // Magenta diamond (a rotated square): deliberately nothing that looks like
  // a real brand mark.
  'plex': [
    Shape(
      polygon([(0.5, 0.1), (0.9, 0.5), (0.5, 0.9), (0.1, 0.5)]),
      vgrad((0xe8, 0x6a, 0xb0), (0xa0, 0x2f, 0x72)),
    ),
  ],
};

/// A vector icon, for the SVG path: a blue disc with a white diamond.
const svgCrunchyroll = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#5aa9ff"/>
      <stop offset="1" stop-color="#2b5fd6"/>
    </linearGradient>
  </defs>
  <circle cx="128" cy="128" r="116" fill="url(#g)"/>
  <polygon points="128,64 192,128 128,192 64,128" fill="#f6f7fb"/>
</svg>
''';

void main() {
  final dir = Directory('test/fixtures/icons')..createSync(recursive: true);
  for (final e in icons.entries) {
    File('${dir.path}/${e.key}.png').writeAsBytesSync(png(render(e.value)));
  }
  File('${dir.path}/crunchyroll.svg').writeAsStringSync(svgCrunchyroll);
  // A file that is not an image, for the broken-icon fallback.
  File('${dir.path}/broken.png').writeAsStringSync('not an image\n');
  stdout.writeln('wrote ${dir.path}');
}
