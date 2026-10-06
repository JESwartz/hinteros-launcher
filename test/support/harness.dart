import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/app.dart';
import 'package:hinteros_launcher/src/data/app_icons.dart';
import 'package:hinteros_launcher/src/data/launcher_data.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';

/// Directory of the committed placeholder artwork (tool/gen_mock_art.dart).
String artDir() => '${Directory.current.path}/test/fixtures/art';

/// Directory of the committed generic app icons (tool/gen_mock_icons.dart).
String iconDir() => '${Directory.current.path}/test/fixtures/icons';

/// The mock apps with local icons; Plex has none (the letter tile).
List<App> appsWithIcons() => mockAppsWithIcons(iconDir(), without: {'plex'});

/// The mock library with local artwork for a few games.
List<Game> gamesWithArt() => mockGames(artDir: artDir());

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
    LauncherSettings settings = const LauncherSettings(),
    MockSystemServices? services,
    this.showServer = false,
  }) : services =
           services ?? MockSystemServices(iconDir: iconDir(), now: fixedNow),
       mock = mock ?? MockDaemon(apps: appsWithIcons(), games: gamesWithArt()),
       storage = MemorySettingsStorage(settings) {
    this.settings = SettingsController(storage, settings);
    data = buildData(this.mock);
  }

  final MockDaemon mock;
  final MockSystemServices services;
  final MemorySettingsStorage storage;
  late final SettingsController settings;
  final bool showServer;
  late final LauncherData data;

  Widget get app => LauncherApp(
    data: data,
    settings: settings,
    services: services,
    now: fixedNow,
    showServer: showServer,
  );

  /// Pumps the app and lets everything settle.
  Future<void> pump(WidgetTester tester) async {
    await precacheArt(tester);
    await precacheIcons(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// Loads the icon files of the mock apps into [AppIconCache] before the first
  /// frame (the fake-async test zone has no real file IO), so tiles paint
  /// their icons at once.
  Future<void> precacheIcons(WidgetTester tester) =>
      loadIcons(tester, [for (final a in mock.apps) ?a.icon]);

  /// Decodes the artwork files of the mock library into the image cache
  /// before the first frame asks for them (file IO needs real async, which
  /// the fake-async test zone does not give), so the frame paints them.
  Future<void> precacheArt(WidgetTester tester) async {
    final paths = {
      for (final g in mock.games)
        for (final p in [g.artwork.portrait, g.artwork.header]) ?p,
    };
    await tester.runAsync(() async {
      for (final p in paths) {
        final done = Completer<void>();
        FileImage(File(p))
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (_, _) => done.isCompleted ? null : done.complete(),
                onError: (e, _) => done.completeError(e),
              ),
            );
        await done.future;
      }
    });
  }
}

/// Loads [paths] into the icon cache with real async (and again after
/// [AppIconCache.invalidate], as `apps_changed` does).
Future<void> loadIcons(WidgetTester tester, Iterable<String> paths) =>
    tester.runAsync(() async {
      AppIconCache.instance.debugForgetInFlight();
      for (final p in paths) {
        await AppIconCache.instance.load(p);
      }
    });

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
