import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'src/home_screen.dart';

/// Entry point. Pass `--fps` (or set `HINTEROS_FPS=1`) to show a frame-rate overlay.
void main(List<String> args) {
  final showFps =
      args.contains('--fps') ||
      (Platform.environment['HINTEROS_FPS'] ?? '').isNotEmpty;
  runApp(LauncherApp(showFps: showFps));
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key, this.showFps = false});

  final bool showFps;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HinterOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0D12),
        colorSchemeSeed: const Color(0xFF5B8CFF),
        useMaterial3: true,
      ),
      home: HomeScreen(showFps: showFps),
    );
  }
}
