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
import 'package:hinteros_launcher/src/system/repositories.dart';
import 'package:hinteros_launcher/src/ui/time_zone/time_zone_map.dart';

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
    this.realServices,
    this.now = fixedNow,
    this.leaveApp,
  }) : services =
           services ?? MockSystemServices(iconDir: iconDir(), now: fixedNow),
       mock = mock ?? MockDaemon(apps: appsWithIcons(), games: gamesWithArt()),
       storage = MemorySettingsStorage(settings) {
    this.settings = SettingsController(storage, settings);
    data = buildData(this.mock);
  }

  final MockDaemon mock;
  final MockSystemServices services;

  /// When set, the app runs on these instead (the Daemon* repositories over
  /// [mock]); [services] is then unused.
  final SystemServices? realServices;
  final MemorySettingsStorage storage;
  late final SettingsController settings;
  late final LauncherData data;

  /// The clock of the app (the top bar, job times).
  final DateTime Function() now;

  /// See [LauncherShell.leaveApp] (the browser demo).
  final VoidCallback? leaveApp;

  Widget get app => LauncherApp(
    data: data,
    settings: settings,
    services: realServices ?? services,
    now: now,
    leaveApp: leaveApp,
  );

  /// Pumps the app and lets everything settle.
  Future<void> pump(WidgetTester tester) async {
    await precacheArt(tester);
    loadTimeZoneMap();
    await precacheIcons(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// Loads the icon files of the mock apps into [AppIconCache] before the first
  /// frame (the fake-async test zone has no real file IO), so tiles paint
  /// their icons at once.
  Future<void> precacheIcons(WidgetTester tester) => loadIcons(tester, [
    for (final a in mock.apps) ?a.icon,
    // The Store resolves icons for the whole catalog.
    for (final f in Directory(iconDir()).listSync())
      if (f is File && f.path.endsWith('.png')) f.path,
  ]);

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

/// Reads the committed map asset (sync file IO: the fake-async test zone
/// has no real async), so the time zone map draws in the first frame.
void loadTimeZoneMap() => TimeZoneMapData.cached ??= TimeZoneMapData.parse(
  File(TimeZoneMapData.asset).readAsBytesSync(),
);

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

/// Frames every 100 ms for [d] (after one to start), as a held button sees
/// them: an animation started by the first frame runs its whole length.
Future<void> pumpFor(WidgetTester t, Duration d) async {
  await t.pump();
  const step = Duration(milliseconds: 100);
  var left = d;
  while (left > Duration.zero) {
    final s = left < step ? left : step;
    await t.pump(s);
    left -= s;
  }
}
