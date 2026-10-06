import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shows frames per second (averaged over the last second) and the worst
/// frame build+raster time in that window, in the top-right corner.
class FpsOverlay extends StatefulWidget {
  const FpsOverlay({super.key});

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  final _timings = <FrameTiming>[];
  String _text = 'fps: --';
  Duration _windowStart = Duration.zero;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
    final now = timings.last.timestampInMicroseconds(FramePhase.rasterFinish);
    if (_windowStart == Duration.zero) {
      _windowStart = Duration(microseconds: now);
      return;
    }
    final elapsed = Duration(microseconds: now) - _windowStart;
    if (elapsed < const Duration(seconds: 1) || !mounted) return;
    final fps = _timings.length / (elapsed.inMicroseconds / 1e6);
    final worst = _timings
        .map((t) => t.totalSpan.inMicroseconds)
        .reduce((a, b) => a > b ? a : b);
    _timings.clear();
    _windowStart = Duration(microseconds: now);
    setState(
      () => _text =
          'fps: ${fps.toStringAsFixed(1)}  worst: ${(worst / 1000).toStringAsFixed(1)} ms',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 24,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xAA000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              _text,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Color(0xFF7CFC9A),
                fontSize: 18,
                fontFamily: 'monospace',
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
