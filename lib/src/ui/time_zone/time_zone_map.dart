/// The world map of the time zone picker: land outlines and the time zone
/// bands of Natural Earth (public domain), from the bundled asset
/// `assets/maps/time_zones.bin` (made by `tool/gen_time_zone_map.dart`, which
/// documents the format). Equirectangular; it only shows, nothing on it is
/// focusable.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../log.dart';
import '../../theme/hinter_theme.dart';

/// The parsed asset: the land and one path per standard offset, in the
/// asset's units (x: longitude, y: minus latitude, [unitsPerDegree] each).
class TimeZoneMapData {
  TimeZoneMapData._(this.unitsPerDegree, this.land, this.bands);

  static const asset = 'assets/maps/time_zones.bin';

  final int unitsPerDegree;
  final ui.Path land;

  /// By standard offset in seconds (Natural Earth's `zone` times 3600).
  final Map<int, ui.Path> bands;

  /// The data once loaded (then the map draws at once).
  static TimeZoneMapData? cached;
  static Future<TimeZoneMapData?>? _loading;

  /// Loads the asset once; null when it cannot be read (the map then
  /// stays empty, the picker works without it).
  static Future<TimeZoneMapData?> load([AssetBundle? bundle]) {
    final c = cached;
    if (c != null) return Future.value(c);
    return _loading ??= (bundle ?? rootBundle)
        .load(asset)
        .then((b) => cached = parse(b.buffer.asUint8List()))
        .then<TimeZoneMapData?>(
          (d) => d,
          onError: (Object e) {
            logFailure('the time zone map', e);
            _loading = null;
            return null;
          },
        );
  }

  /// Reads the format of `tool/gen_time_zone_map.dart`.
  static TimeZoneMapData parse(Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    var o = 0;
    int u8() => d.getUint8(o++);
    int u16() {
      final v = d.getUint16(o, Endian.little);
      o += 2;
      return v;
    }

    int i16() {
      final v = d.getInt16(o, Endian.little);
      o += 2;
      return v;
    }

    int i32() {
      final v = d.getInt32(o, Endian.little);
      o += 4;
      return v;
    }

    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'HTZM') {
      throw const FormatException('not a time zone map');
    }
    o = 4;
    final version = u8();
    if (version != 1) throw FormatException('map version $version');
    u8();
    final units = u16();

    void rings(ui.Path path, int count) {
      for (var r = 0; r < count; r++) {
        final n = u16();
        var x = 0, y = 0;
        for (var i = 0; i < n; i++) {
          x += i16();
          y += i16();
          if (i == 0) {
            path.moveTo(x.toDouble(), -y.toDouble());
          } else {
            path.lineTo(x.toDouble(), -y.toDouble());
          }
        }
        path.close();
      }
    }

    final land = ui.Path();
    rings(land, u16());
    final bands = <int, ui.Path>{};
    final n = u16();
    for (var b = 0; b < n; b++) {
      final offset = i32();
      final path = ui.Path()..fillType = ui.PathFillType.evenOdd;
      rings(path, u16());
      bands[offset] = path;
    }
    return TimeZoneMapData._(units, land, bands);
  }
}

/// The map with the band of [standardOffset] highlighted (every area with
/// that standard offset, not only the zone's own). Land outlines give
/// context. Sized by its parent's width.
class TimeZoneMap extends StatefulWidget {
  const TimeZoneMap({super.key, required this.standardOffset});

  final Duration? standardOffset;

  /// The latitudes shown: the inhabited world, without most of Antarctica.
  static const north = 84.0, south = -58.0;
  static const aspect = 360 / (north - south);

  @override
  State<TimeZoneMap> createState() => _TimeZoneMapState();
}

class _TimeZoneMapState extends State<TimeZoneMap> {
  TimeZoneMapData? _data = TimeZoneMapData.cached;

  @override
  void initState() {
    super.initState();
    if (_data == null) {
      unawaited(
        TimeZoneMapData.load().then((d) {
          if (mounted && d != null) setState(() => _data = d);
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return AspectRatio(
      aspectRatio: TimeZoneMap.aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
        child: CustomPaint(
          key: const ValueKey('time-zone-map'),
          painter: _MapPainter(
            data: _data,
            band: widget.standardOffset?.inSeconds,
            sea: t.surface,
            land: t.surfaceHigh,
            coast: t.textDim.withValues(alpha: t.highContrast ? 0.9 : 0.55),
            highlight: t.accent,
            edge: t.highContrast ? t.text : t.surfaceHigh,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.data,
    required this.band,
    required this.sea,
    required this.land,
    required this.coast,
    required this.highlight,
    required this.edge,
  });

  final TimeZoneMapData? data;
  final int? band;
  final Color sea;
  final Color land;
  final Color coast;
  final Color highlight;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = sea);
    final d = data;
    if (d != null) {
      final u = d.unitsPerDegree;
      final scale = size.width / (360 * u);
      canvas.save();
      canvas.clipRect(rect);
      canvas.scale(scale);
      // x from -180, y from the northern edge (y is minus the latitude).
      canvas.translate(180.0 * u, TimeZoneMap.north * u);
      canvas.drawPath(d.land, Paint()..color = land);
      final b = band == null ? null : d.bands[band];
      if (b != null) {
        canvas.drawPath(b, Paint()..color = highlight.withValues(alpha: 0.42));
      }
      canvas.drawPath(
        d.land,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / scale
          ..strokeJoin = StrokeJoin.round
          ..color = coast,
      );
      if (b != null) {
        canvas.drawPath(
          b,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / scale
            ..strokeJoin = StrokeJoin.round
            ..color = highlight,
        );
      }
      canvas.restore();
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1),
        const Radius.circular(HinterTokens.radiusSmall),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_MapPainter o) =>
      o.data != data ||
      o.band != band ||
      o.sea != sea ||
      o.land != land ||
      o.coast != coast ||
      o.highlight != highlight ||
      o.edge != edge;
}
