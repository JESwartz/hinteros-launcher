import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'src/api/api.dart';
import 'src/osk/osk_backend.dart';
import 'src/osk/osk_screen.dart';
import 'src/settings/launcher_settings.dart';

export 'src/osk/osk_screen.dart' show OskApp;

/// Entry point of the on-screen keyboard (`hinteros-osk`). The same binary as
/// the launcher; `lib/main.dart` calls [runOsk] for `--osk`, and the
/// `hinteros-osk` wrapper passes it. Also runnable on its own:
/// `flutter run -d linux -t lib/osk_main.dart --dart-entrypoint-args=--osk,--mock,--windowed`
/// (`--osk` is what makes the native window transparent).
///
/// `--mock` (or `HINTEROS_MOCK=1`) uses a fake backend that prints what it
/// would send; the keyboard keys stand in for the pad (arrows, Enter = accept,
/// Escape or Backspace = back, Y = context, X = secondary).
Future<void> main(List<String> args) => runOsk(args);

Future<void> runOsk(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final mock =
      args.contains('--mock') ||
      (Platform.environment['HINTEROS_MOCK'] ?? '').isNotEmpty;
  final OskBackend backend;
  if (mock) {
    backend = MockOskBackend()..onCall = (c) => debugPrint('osk: $c');
  } else {
    backend = DaemonOskBackend(DaemonClient(socketPath: defaultSocketPath()));
  }
  final storage = FileSettingsStorage.xdg();
  final settings = ValueNotifier(await storage.load());
  // The keyboard process stays resident, so pick up changes made in the
  // launcher's Settings every time it opens.
  backend.visibility.listen((visible) async {
    if (visible) settings.value = await storage.load();
  });
  runApp(OskApp(backend: backend, settings: settings));
}
