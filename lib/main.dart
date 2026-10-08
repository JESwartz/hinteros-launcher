import 'dart:io' show Directory, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'osk_main.dart';
import 'src/installer/installer_main.dart';
import 'src/api/api.dart';
import 'src/app.dart';
import 'src/settings/launcher_settings.dart';
import 'src/system/daemon_system.dart';
import 'src/system/home_relaunch.dart';
import 'src/system/mock_system.dart';

export 'src/app.dart' show LauncherApp;

bool _flag(List<String> args, String flag, String env) =>
    args.contains(flag) || (Platform.environment[env] ?? '').isNotEmpty;

/// Entry point.
///
/// `--fps` (or `HINTEROS_FPS=1`) shows a frame-rate overlay. `--mock` (or
/// `HINTEROS_MOCK=1`) uses an in-process fake daemon (with a fake Steam
/// library) instead of the session socket; the Home key then stands in for
/// the controller's Home button, A/D/W/S, Space, Q and E for the D-pad,
/// accept, back and context (as `input_nav` events), F2 quits the last app
/// that was started, F3/F4 make Steam ask for attention / stop, F5 finishes
/// or restarts a game update, F6 makes the next missing app icon arrive
/// (`apps_changed`).
/// `--server` (or `HINTEROS_SERVER=1`) shows the phase 2 Server tab.
Future<void> main(List<String> args) async {
  // One binary, two apps: `--osk` (the hinteros-osk wrapper) is the keyboard.
  if (args.contains('--osk')) return runOsk(args);
  // The installer (ISO) and the first-boot wizard are modes of the same
  // binary too: controller-only, no session daemon needed for the installer.
  if (wantsInstaller(args) || wantsFirstBoot(args)) {
    return runInstallerMode(args);
  }
  WidgetsFlutterBinding.ensureInitialized();
  final showFps = _flag(args, '--fps', 'HINTEROS_FPS');
  final mock = _flag(args, '--mock', 'HINTEROS_MOCK');
  final iconDir = mock ? _mockIconDir() : null;
  final DaemonConnection connection = mock
      ? MockDaemon(
          apps: iconDir == null
              ? mockApps
              : mockAppsWithIcons(iconDir, without: {'youtube', 'plex'}),
        )
      : DaemonClient(socketPath: defaultSocketPath());
  // After a system switch replaced the daemon: hand over to the new launcher
  // (only under the session's home loop).
  if (!mock) {
    HomeRelaunch.fromEnvironment().watch(
      connection.status,
      connection.statusChanges,
    );
  }
  final settings = await SettingsController.load(FileSettingsStorage.xdg());
  final data = buildData(connection);
  Widget app = LauncherApp(
    data: data,
    settings: settings,
    // Real: system info, SSH, updates and jobs over the session API 0.6 relay,
    // Wi-Fi, Bluetooth, display, audio and power over the 0.7 runtime
    // settings, and the admin password prompt, session restart and the Store
    // of 0.8. The mock asks for the admin password like the real daemon.
    services: mock
        ? MockSystemServices(autoRunJobs: true, iconDir: iconDir)
        : daemonSystemServices(connection),
    showFps: showFps,
    showServer: _flag(args, '--server', 'HINTEROS_SERVER'),
  );
  if (connection is MockDaemon) {
    app = _DevKeys(mock: connection, iconDir: iconDir, child: app);
  }
  // Console mode: no pointer (the GTK runner blanks its own cursor; this
  // keeps Flutter from putting one back).
  if (!_flag(args, '--windowed', 'HINTEROS_WINDOWED')) {
    app = MouseRegion(cursor: SystemMouseCursors.none, child: app);
  }
  runApp(app);
}

/// Where the mock finds its generic icons (`HINTEROS_MOCK_ICONS`, else the
/// repo fixtures when run from the repo root); null: no icons.
String? _mockIconDir() {
  final d =
      Platform.environment['HINTEROS_MOCK_ICONS'] ?? 'test/fixtures/icons';
  return Directory(d).existsSync() ? Directory(d).absolute.path : null;
}

/// Dev-only keys that emit `input_nav` from the mock daemon.
final _devPad = [
  (LogicalKeyboardKey.keyA, NavAction.left),
  (LogicalKeyboardKey.keyD, NavAction.right),
  (LogicalKeyboardKey.keyW, NavAction.up),
  (LogicalKeyboardKey.keyS, NavAction.down),
  (LogicalKeyboardKey.space, NavAction.accept),
  (LogicalKeyboardKey.keyQ, NavAction.back),
  (LogicalKeyboardKey.keyE, NavAction.context),
];

class _DevKeys extends StatelessWidget {
  const _DevKeys({required this.mock, required this.child, this.iconDir});

  final MockDaemon mock;
  final String? iconDir;
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
        // Steam pops up a dialog while something else has focus / it goes.
        const SingleActivator(LogicalKeyboardKey.f3): () => c.setSteamAttention(
          const [SteamWindow(window: 6291459, title: 'Steam Guard', pid: 2412)],
        ),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            c.setSteamAttention(const []),
        // A game update finishes (or starts again): games_changed.
        const SingleActivator(LogicalKeyboardKey.f5): c.toggleFirstUpdate,
        // An app's icon arrives (YouTube, then Plex): apps_changed.
        if (iconDir != null)
          const SingleActivator(LogicalKeyboardKey.f6): () =>
              c.iconArrives(iconDir!),
      },
      child: Focus(canRequestFocus: false, child: child),
    );
  }
}
