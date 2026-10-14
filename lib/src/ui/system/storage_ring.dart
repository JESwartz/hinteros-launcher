import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../settings/launcher_settings.dart';
import '../../theme/hinter_theme.dart';

/// One segment of the ring as drawn: where it starts and how far it goes
/// (radians, clockwise from the top), and its colour.
class RingSegment {
  const RingSegment(
    this.start,
    this.sweep,
    this.color, {
    this.openable = false,
  });

  final double start;
  final double sweep;
  final Color color;

  /// A opens it: it carries a chevron.
  final bool openable;

  double get mid => start + sweep / 2;
}

/// The angles of [bytes] around a full circle, clockwise from the top. Every
/// segment gets at least [minSweep] (so a small one can still be seen and
/// selected); the others share the rest by size.
List<(double start, double sweep)> ringAngles(
  List<int> bytes, {
  double minSweep = 5 * math.pi / 180,
}) {
  final n = bytes.length;
  if (n == 0) return const [];
  const full = 2 * math.pi;
  final min = math.min(minSweep, full / n);
  final total = bytes.fold<int>(0, (a, b) => a + math.max(0, b));
  final raw = [
    for (final b in bytes)
      total == 0 ? full / n : full * math.max(0, b) / total,
  ];
  // Raise the small ones to the minimum, take it from the large ones.
  final small = {
    for (var i = 0; i < n; i++)
      if (raw[i] < min) i,
  };
  final room = full - small.length * min;
  final largeTotal = [
    for (var i = 0; i < n; i++)
      if (!small.contains(i)) raw[i],
  ].fold<double>(0, (a, b) => a + b);
  final sweeps = [
    for (var i = 0; i < n; i++)
      small.contains(i)
          ? min
          : (largeTotal == 0
                ? room / (n - small.length)
                : raw[i] * room / largeTotal),
  ];
  final out = <(double, double)>[];
  var a = -math.pi / 2;
  for (final s in sweeps) {
    out.add((a, s));
    a += s;
  }
  return out;
}

/// The storage ring (a sunburst level, like Filelight): the [segments] of
/// the current level around a hole that names the level ([centerTitle],
/// [centerSize]). The [selected] segment sticks out further than the others
/// (a shape, not only a colour); while the ring has the focus it also gets
/// the focus marker of the person's focus style. Everything is drawn inside
/// the widget's square, focus marker included, so nothing next to it is
/// covered and nothing is cut off.
class StorageRing extends StatelessWidget {
  const StorageRing({
    super.key,
    required this.segments,
    required this.selected,
    required this.focused,
    required this.centerTitle,
    required this.centerSize,
    this.diameter = ringDiameter,
    this.busy = false,
  });

  /// The square's side: the ring and the room for the selected segment and
  /// its focus marker.
  static const ringDiameter = 520.0;

  final List<RingSegment> segments;
  final int selected;
  final bool focused;
  final String centerTitle;
  final String centerSize;
  final double diameter;

  /// A home's folders are being loaded: the ring is dimmed.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: RingPainter(
                segments: segments,
                selected: selected,
                focused: focused,
                style: t.focusStyle,
                focusRing: t.focusRing,
                focusGap: t.focusGap,
                background: t.background,
                outline: t.highContrast ? t.text : t.textDim,
                highContrast: t.highContrast,
                dim: busy,
              ),
            ),
          ),
          // The level's name and size in the hole.
          SizedBox(
            // Inside the hole, clear of the focus marker on its edge.
            width: diameter * RingPainter.inner * 0.86 - 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTitle,
                  key: const ValueKey('storage-ring-level'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.label,
                ),
                Text(
                  centerSize,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: t.bodyDim,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  RingPainter({
    required this.segments,
    required this.selected,
    required this.focused,
    required this.style,
    required this.focusRing,
    required this.focusGap,
    required this.background,
    required this.outline,
    required this.highContrast,
    this.dim = false,
  });

  /// Radii as parts of half the square: the hole, the ring, the selected
  /// segment. The rest (to 1.0) is the room for the focus marker.
  static const inner = 0.46;
  static const outer = 0.82;
  static const raised = 0.90;

  final List<RingSegment> segments;
  final int selected;
  final bool focused;
  final FocusStyle style;
  final Color focusRing;
  final Color focusGap;
  final Color background;
  final Color outline;
  final bool highContrast;
  final bool dim;

  Path _arc(Offset c, double r0, double r1, double start, double sweep) {
    if (sweep >= 2 * math.pi - 1e-6) {
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: r1))
        ..addOval(Rect.fromCircle(center: c, radius: r0));
    }
    return Path()
      ..arcTo(Rect.fromCircle(center: c, radius: r1), start, sweep, true)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r0),
        start + sweep,
        -sweep,
        false,
      )
      ..close();
  }

  /// A segment that opens: an upright chevron in it (the mark beside the
  /// selected name), where the segment is wide enough to hold it.
  void _cue(Canvas canvas, Offset c, RingSegment s, double r) {
    if (!s.openable || s.sweep * r < 40) return;
    const h = 9.0;
    final m = c + Offset(math.cos(s.mid), math.sin(s.mid)) * r;
    final ink = s.color.computeLuminance() > 0.35
        ? const Color(0xFF101418)
        : const Color(0xFFFFFFFF);
    canvas.drawPath(
      Path()
        ..moveTo(m.dx - h * 0.45, m.dy - h)
        ..lineTo(m.dx + h * 0.55, m.dy)
        ..lineTo(m.dx - h * 0.45, m.dy + h),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = dim ? ink.withValues(alpha: 0.4) : ink,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    final r0 = half * inner;
    final r1 = half * outer;
    final rSel = half * raised;
    // Lines between segments: the background colour, wider in high
    // contrast, so neighbours never run into each other.
    final sep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highContrast ? 4 : 2
      ..color = background;
    for (var i = 0; i < segments.length; i++) {
      if (i == selected) continue;
      final s = segments[i];
      final p = _arc(c, r0, r1, s.start, s.sweep);
      canvas.drawPath(
        p,
        Paint()..color = dim ? s.color.withValues(alpha: 0.4) : s.color,
      );
      canvas.drawPath(p, sep);
      _cue(canvas, c, s, (r0 + r1) / 2);
    }
    if (selected < 0 || selected >= segments.length) return;
    final s = segments[selected];
    // The selected one reaches further out: its outer edge marks it.
    final p = _arc(c, r0, rSel, s.start, s.sweep);
    canvas.drawPath(p, Paint()..color = s.color);
    canvas.drawPath(p, sep);
    _cue(canvas, c, s, (r0 + rSel) / 2);
    if (!focused) {
      // Without focus: a thin outline on the raised shape.
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = outline,
      );
      return;
    }
    switch (style) {
      case FocusStyle.ring:
        // A dark gap, then the thick ring (like FocusFrame's).
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeJoin = StrokeJoin.round
            ..color = focusGap,
        );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeJoin = StrokeJoin.round
            ..color = focusRing,
        );
      case FocusStyle.glow:
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..color = focusRing.withValues(alpha: 0.6),
        );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = StrokeJoin.round
            ..color = focusRing,
        );
      case FocusStyle.bar:
        // A bar along the outer edge, outside the segment; at least
        // 12 degrees long, so a thin segment's bar is still easy to see.
        final rBar = rSel + 12;
        final sweep = math.max(s.sweep, 12 * math.pi / 180);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: rBar),
          s.mid - sweep / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..color = focusRing,
        );
    }
  }

  @override
  bool shouldRepaint(RingPainter o) =>
      o.segments != segments ||
      o.selected != selected ||
      o.focused != focused ||
      o.style != style ||
      o.focusRing != focusRing ||
      o.dim != dim ||
      o.highContrast != highContrast;
}

/// "This opens": a chevron in a ring, beside the selected segment's name
/// (the same mark its segment carries).
class OpenCue extends StatelessWidget {
  const OpenCue({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _CuePainter(t.accent, t.text),
    );
  }
}

class _CuePainter extends CustomPainter {
  _CuePainter(this.ring, this.ink);

  final Color ring;
  final Color ink;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    canvas.drawCircle(
      c,
      s.width / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring,
    );
    final h = s.width * 0.18;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - h * 0.5, c.dy - h)
        ..lineTo(c.dx + h * 0.6, c.dy)
        ..lineTo(c.dx - h * 0.5, c.dy + h),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_CuePainter o) => o.ring != ring || o.ink != ink;
}
