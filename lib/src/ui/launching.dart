import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/hinter_theme.dart';
import 'app_icon_view.dart';

/// How long the launcher waits before it says starting can take a while.
const launchingHintAfter = Duration(seconds: 10);

/// Full-screen "Starting App..." view, from the moment the launcher asks
/// the daemon to start an app until that app has the focus (or failed). The
/// last launcher frame would otherwise just sit there while Steam updates
/// itself. B or Home cancel the wait (the app keeps starting).
class LaunchingScreen extends StatefulWidget {
  const LaunchingScreen({
    super.key,
    required this.id,
    required this.name,
    this.iconPath,
  });

  final String id;
  final String name;
  final String? iconPath;

  @override
  State<LaunchingScreen> createState() => _LaunchingScreenState();
}

class _LaunchingScreenState extends State<LaunchingScreen> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(launchingHintAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final steam = widget.id == 'steam';
    final hint = steam
        ? 'Steam is updating itself. This can take a few minutes.'
        : 'The first start can take a minute.';
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Starting ${widget.name}',
      child: ColoredBox(
        key: const ValueKey('launching'),
        color: t.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge(
                name: widget.name,
                iconPath: widget.iconPath,
                size: 160,
              ),
              const SizedBox(height: HinterTokens.s4),
              Text(
                'Starting ${widget.name}…',
                key: const ValueKey('launching-title'),
                style: t.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HinterTokens.s3),
              _Spinner(still: t.reduceMotion, color: t.accent),
              const SizedBox(height: HinterTokens.s3),
              SizedBox(
                height: 48,
                child: _slow
                    ? Text(
                        hint,
                        key: const ValueKey('launching-hint'),
                        style: t.bodyDim,
                        textAlign: TextAlign.center,
                      )
                    : null,
              ),
              const SizedBox(height: HinterTokens.s2),
              Text('B Back to Home', style: t.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ring with a moving gap, or a still ring with reduce motion.
class _Spinner extends StatelessWidget {
  const _Spinner({required this.still, required this.color});

  final bool still;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: CircularProgressIndicator(
        key: const ValueKey('launching-spinner'),
        value: still ? 0.75 : null,
        strokeWidth: 6,
        color: color,
      ),
    );
  }
}
