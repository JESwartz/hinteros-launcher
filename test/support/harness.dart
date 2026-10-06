import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/app.dart';
import 'package:hinteros_launcher/src/data/games_repository.dart';
import 'package:hinteros_launcher/src/data/launcher_data.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

/// Fixed clock for widget tests and goldens.
DateTime fixedNow() => DateTime(2026, 10, 6, 20, 30);

/// A connection stuck in a fixed state, for the error screens.
class StuckConnection extends MockDaemon {
  StuckConnection(this._fixed);

  final ConnectionStatus _fixed;

  @override
  ConnectionStatus get status => _fixed;

  @override
  void start() {}
}

/// Everything a launcher test needs, wired like `main` but with fakes.
class Harness {
  Harness({
    MockDaemon? mock,
    GamesRepository? games,
    LauncherSettings settings = const LauncherSettings(),
    this.showServer = false,
  }) : mock = mock ?? MockDaemon(),
       games = games ?? MockGamesRepository(),
       storage = MemorySettingsStorage(settings) {
    this.settings = SettingsController(storage, settings);
    data = buildData(this.mock, this.games);
  }

  final MockDaemon mock;
  final GamesRepository games;
  final MemorySettingsStorage storage;
  late final SettingsController settings;
  final bool showServer;
  late final LauncherData data;

  Widget get app => LauncherApp(
    data: data,
    settings: settings,
    now: fixedNow,
    showServer: showServer,
  );

  /// Pumps the app and lets everything settle.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }
}

/// Logical [size] at [dpr] (4K is 1920x1080 logical at 2.0).
void setView(
  WidgetTester tester, {
  Size size = const Size(1920, 1080),
  double dpr = 1.0,
}) {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Label of the focused node: `region/rowKey:col`.
String? focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;

/// A temporary directory removed after the test.
Directory tempDir() {
  final d = Directory.systemTemp.createTempSync('hinteros-launcher-test');
  addTearDown(() => d.deleteSync(recursive: true));
  return d;
}

extension HarnessLaunch on Harness {
  /// Starts app [id] in the mock (after [Harness.pump] so the handshake is done).
  Future<void> launch(WidgetTester tester, String id) async {
    await mock.appsLaunch(AppsLaunchParams(id: id));
    await tester.pumpAndSettle();
  }
}
