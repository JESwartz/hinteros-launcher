import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/demo/web_demo.dart';
import 'src/log.dart';
import 'src/platform/gamepad_web.dart';
import 'src/platform/local_files_web.dart';
import 'src/settings/launcher_settings.dart';

/// Entry point of the browser demo (`flutter build web -t
/// lib/web_main.dart`): the launcher against the in-process mock daemon, as
/// `--mock --windowed` on the desktop, with its own free content bundled as
/// web-only assets (`lib/src/demo/web_demo.dart`). No Server tab, no dev
/// keys. Settings and the mock live for the page only.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logSink = debugPrint;
  await preloadLocalFiles(textPrefixes: demoTextPrefixes);
  final demo = WebDemo();
  WebGamepad(demo.daemon).start();
  runApp(
    CallbackShortcuts(
      bindings: {
        // The Home button: back to Home, also from a "running" app.
        const SingleActivator(LogicalKeyboardKey.home): demo.daemon.pressHome,
      },
      child: Focus(
        canRequestFocus: false,
        child: LauncherApp(
          data: buildData(demo.daemon),
          settings: SettingsController(MemorySettingsStorage()),
          services: demo.services,
          showServer: false,
          gamesNeedSteam: false,
        ),
      ),
    ),
  );
}
