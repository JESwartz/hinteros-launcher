import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/api/api.dart';
import 'src/app.dart';
import 'src/data/apps_repository.dart';
import 'src/data/games_repository.dart';
import 'src/settings/launcher_settings.dart';

export 'src/app.dart' show LauncherApp;

bool _flag(List<String> args, String flag, String env) =>
    args.contains(flag) || (Platform.environment[env] ?? '').isNotEmpty;

/// Entry point.
///
/// `--fps` (or `HINTEROS_FPS=1`) shows a frame-rate overlay. `--mock` (or
/// `HINTEROS_MOCK=1`) uses an in-process fake daemon (and fake games) instead
/// of the session socket; the Home key then stands in for the controller's
/// Home button, A/D/W/S, Space and Q for the D-pad, accept and back (as
/// `input_nav` events), and F2 quits the last app that was started.
/// `--server` (or `HINTEROS_SERVER=1`) shows the phase 2 Server tab.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final showFps = _flag(args, '--fps', 'HINTEROS_FPS');
  final mock = _flag(args, '--mock', 'HINTEROS_MOCK');
  final DaemonConnection connection = mock
      ? MockDaemon()
      : DaemonClient(socketPath: defaultSocketPath());
  final settings = await SettingsController.load(FileSettingsStorage.xdg());
  final data = buildData(
    connection,
    // TODO(0.3): the real games.list repository replaces both.
    mock
        ? MockGamesRepository()
        : AppsBackedGamesRepository(AppsRepository(connection)),
  );
  Widget app = LauncherApp(
    data: data,
    settings: settings,
    showFps: showFps,
    showServer: _flag(args, '--server', 'HINTEROS_SERVER'),
  );
  if (connection is MockDaemon) app = _DevKeys(mock: connection, child: app);
  runApp(app);
}

/// Dev-only keys that emit `input_nav` from the mock daemon.
final _devPad = [
  (LogicalKeyboardKey.keyA, NavAction.left),
  (LogicalKeyboardKey.keyD, NavAction.right),
  (LogicalKeyboardKey.keyW, NavAction.up),
  (LogicalKeyboardKey.keyS, NavAction.down),
  (LogicalKeyboardKey.space, NavAction.accept),
  (LogicalKeyboardKey.keyQ, NavAction.back),
];

class _DevKeys extends StatelessWidget {
  const _DevKeys({required this.mock, required this.child});

  final MockDaemon mock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = mock;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.home): c.pressHome,
        // Fake controller, through the event path (arrows/Enter/Escape work
        // directly, like on the real thing).
        for (final (key, action) in _devPad)
          SingleActivator(key): () => c
            ..emitNav(action)
            ..emitNav(action, NavPhase.release),
        // Fake the last app that was started quitting.
        const SingleActivator(LogicalKeyboardKey.f2): () {
          final r = c.running;
          if (r.isNotEmpty) c.simulateExit(r.last.id);
        },
      },
      child: Focus(canRequestFocus: false, child: child),
    );
  }
}
