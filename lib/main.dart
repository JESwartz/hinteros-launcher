import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/api/api.dart';
import 'src/home_screen.dart';

bool _flag(List<String> args, String flag, String env) =>
    args.contains(flag) || (Platform.environment[env] ?? '').isNotEmpty;

/// Entry point.
///
/// `--fps` (or `HINTEROS_FPS=1`) shows a frame-rate overlay. `--mock` (or
/// `HINTEROS_MOCK=1`) uses an in-process fake daemon instead of the session
/// socket; the Home key then stands in for the controller's Home button.
void main(List<String> args) {
  final showFps = _flag(args, '--fps', 'HINTEROS_FPS');
  final DaemonConnection connection = _flag(args, '--mock', 'HINTEROS_MOCK')
      ? MockDaemon()
      : DaemonClient(socketPath: defaultSocketPath());
  runApp(LauncherApp(connection: connection, showFps: showFps));
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({
    super.key,
    required this.connection,
    this.showFps = false,
  });

  final DaemonConnection connection;
  final bool showFps;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    return MaterialApp(
      title: 'HinterOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0D12),
        colorSchemeSeed: const Color(0xFF5B8CFF),
        useMaterial3: true,
      ),
      home: c is MockDaemon
          ? CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.home): c.pressHome,
              },
              child: Focus(
                canRequestFocus: false,
                child: HomeScreen(connection: c, showFps: showFps),
              ),
            )
          : HomeScreen(connection: c, showFps: showFps),
    );
  }
}
