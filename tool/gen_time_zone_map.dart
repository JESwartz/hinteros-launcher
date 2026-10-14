// Makes the world map asset of the time zone picker
// (assets/maps/time_zones.bin) from Natural Earth data: the time zone bands
// (`ne_10m_time_zones`, polygons by standard offset, field `zone`) and the land
// (`ne_50m_land`) for the outlines. Simplified (Douglas-Peucker), quantized to
// 0.1 degree and written in a small binary format. Run it again only to change
// the map; the asset is committed and the app needs no network.
//
// Source: Natural Earth (public domain, https://www.naturalearthdata.com),
// release v5.1.2, GeoJSON from the natural-earth-vector repository:
//   https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_time_zones.geojson
//   https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_50m_land.geojson
// sha256 of the files used:
//   aa52ab97e5f906693f31fe2e625c9d6be78a4e74fcd4142a7261235b355cacfe  ne_10m_time_zones.geojson
//   e874b27a51d146452be360cafb3cc50c86001074a67d534113e6534682f9826b  ne_50m_land.geojson
//
//   dir=$(mktemp -d)   # downloaded data: keep it out of the repo
//   for f in ne_10m_time_zones ne_50m_land; do
//     curl -sSfL -o "$dir/$f.geojson" \
//       https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/$f.geojson
//   done
//   dart tool/gen_time_zone_map.dart "$dir/ne_10m_time_zones.geojson" "$dir/ne_50m_land.geojson"
//
// Format (little-endian), read by lib/src/ui/time_zone/time_zone_map.dart:
//   "HTZM", u8 version (1), u8 0, u16 units per degree (10)
//   u16 land rings, then the rings
//   u16 bands; per band: i32 standard offset in seconds, u16 rings, the rings
//   ring: u16 points, then per point i16 x (longitude), i16 y (latitude), in
//   units; the first point absolute, the rest as differences to the previous.
// A band's rings are its outer rings and holes together (even-odd fill).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _unitsPerDegree = 10;

/// Douglas-Peucker tolerance in degrees.
const _bandTolerance = 0.12;
const _landTolerance = 0.1;

/// Rings smaller than this (square degrees) are left out; every band keeps at
/// least its largest ring.
const _bandMinArea = 0.05;
const _landMinArea = 0.15;

typedef Pt = (double, double);

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart tool/gen_time_zone_map.dart '
      '<ne_10m_time_zones.geojson> <ne_50m_land.geojson>',
    );
    exit(2);
  }
  final zones = _features(args[0]);
  final land = _features(args[1]);

  final bands = <int, List<List<Pt>>>{};
  for (final f in zones) {
    final zone = (f['properties'] as Map)['zone'];
    if (zone is! num) continue;
    final seconds = (zone * 3600).round();
    bands.putIfAbsent(seconds, () => []).addAll(_rings(f['geometry']));
  }

  final out = BytesBuilder();
  void u8(int v) => out.addByte(v);
  void u16(int v) => out.add(
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
  );
  void i16(int v) => out.add(
    (ByteData(2)..setInt16(0, v, Endian.little)).buffer.asUint8List(),
  );
  void i32(int v) => out.add(
    (ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List(),
  );
  void ring(List<(int, int)> r) {
    u16(r.length);
    var px = 0, py = 0;
    for (final (x, y) in r) {
      i16(x - px);
      i16(y - py);
      px = x;
      py = y;
    }
  }

  out.add(ascii.encode('HTZM'));
  u8(1);
  u8(0);
  u16(_unitsPerDegree);

  final landRings = _prepare(
    [for (final f in land) ..._rings(f['geometry'])],
    _landTolerance,
    _landMinArea,
    keepLargest: false,
  );
  u16(landRings.length);
  landRings.forEach(ring);
  var points = landRings.fold(0, (n, r) => n + r.length);

  final offsets = bands.keys.toList()..sort();
  u16(offsets.length);
  for (final o in offsets) {
    final rings = _prepare(
      bands[o]!,
      _bandTolerance,
      _bandMinArea,
      keepLargest: true,
    );
    i32(o);
    u16(rings.length);
    rings.forEach(ring);
    points += rings.fold(0, (n, r) => n + r.length);
  }

  final file = File('assets/maps/time_zones.bin');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(out.toBytes());
  stdout.writeln(
    'wrote ${file.path}: ${out.length} bytes, ${landRings.length} land rings, '
    '${offsets.length} bands, $points points',
  );
}

List<Map<String, dynamic>> _features(String path) {
  final doc = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (doc['features'] as List).cast<Map<String, dynamic>>();
}

/// Every ring (outer and holes) of a Polygon or MultiPolygon.
List<List<Pt>> _rings(Object? geometry) {
  if (geometry is! Map) return const [];
  List<Pt> ring(Object? r) => [
    for (final p in r as List)
      (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];
  final c = geometry['coordinates'] as List;
  return switch (geometry['type']) {
    'Polygon' => [for (final r in c) ring(r)],
    'MultiPolygon' => [
      for (final poly in c)
        for (final r in poly as List) ring(r),
    ],
    _ => const [],
  };
}

List<List<(int, int)>> _prepare(
  List<List<Pt>> rings,
  double tolerance,
  double minArea, {
  required bool keepLargest,
}) {
  final scored = [for (final r in rings) (r, _area(r).abs())]
    ..sort((a, b) => b.$2.compareTo(a.$2));
  final out = <List<(int, int)>>[];
  for (final (i, (r, area)) in scored.indexed) {
    if (area < minArea && !(keepLargest && i == 0)) continue;
    final q = _quantize(_simplify(r, tolerance));
    if (q.length >= 4) {
      out.add(q);
    } else if (keepLargest && i == 0) {
      // A tiny island band: keep it as it is.
      final full = _quantize(r);
      if (full.length >= 4) out.add(full);
    }
  }
  return out;
}

double _area(List<Pt> r) {
  var a = 0.0;
  for (var i = 0; i < r.length; i++) {
    final (x1, y1) = r[i];
    final (x2, y2) = r[(i + 1) % r.length];
    a += x1 * y2 - x2 * y1;
  }
  return a / 2;
}

List<(int, int)> _quantize(List<Pt> r) {
  final out = <(int, int)>[];
  for (final (x, y) in r) {
    final p = (
      (x * _unitsPerDegree).round().clamp(-1800, 1800),
      (y * _unitsPerDegree).round().clamp(-900, 900),
    );
    if (out.isEmpty || out.last != p) out.add(p);
  }
  return out;
}

/// Douglas-Peucker on a closed ring (first point == last point).
List<Pt> _simplify(List<Pt> r, double tolerance) {
  if (r.length <= 4) return r;
  final keep = List<bool>.filled(r.length, false);
  keep[0] = keep[r.length - 1] = true;
  // A closed ring has no good first segment: split it at the point farthest
  // from the start as well.
  var far = 0;
  var farD = -1.0;
  for (var i = 1; i < r.length - 1; i++) {
    final d = _dist2(r[i], r[0]);
    if (d > farD) {
      farD = d;
      far = i;
    }
  }
  keep[far] = true;
  final stack = <(int, int)>[(0, far), (far, r.length - 1)];
  final tol2 = tolerance * tolerance;
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var best = -1;
    var bestD = tol2;
    for (var i = a + 1; i < b; i++) {
      final d = _segDist2(r[i], r[a], r[b]);
      if (d > bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) {
      keep[best] = true;
      stack
        ..add((a, best))
        ..add((best, b));
    }
  }
  return [
    for (var i = 0; i < r.length; i++)
      if (keep[i]) r[i],
  ];
}

double _dist2(Pt a, Pt b) =>
    math.pow(a.$1 - b.$1, 2).toDouble() + math.pow(a.$2 - b.$2, 2).toDouble();

double _segDist2(Pt p, Pt a, Pt b) {
  final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return _dist2(p, a);
  final t = (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / len2).clamp(0.0, 1.0);
  return _dist2(p, (a.$1 + t * dx, a.$2 + t * dy));
}
