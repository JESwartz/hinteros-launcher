import 'package:flutter/material.dart';

import 'api/api.dart';
import 'data/apps_repository.dart';
import 'data/games_repository.dart';
import 'data/launcher_data.dart';
import 'system/repositories.dart';
import 'settings/launcher_settings.dart';
import 'theme/hinter_theme.dart';
import 'ui/profiles/profile_loading.dart';
import 'ui/shell.dart';

/// The layout is designed for 1920x1080 logical pixels. A 4K screen under
/// native Wayland reports devicePixelRatio 2 and so the same 1920x1080; other
/// sizes (a 720p TV, a desktop window) are scaled uniformly to fit.
const designSize = Size(1920, 1080);

class LauncherApp extends StatelessWidget {
  const LauncherApp({
    super.key,
    required this.data,
    required this.settings,
    required this.services,
    this.now,
    this.showFps = false,
    this.startup,
    this.showServer = true,
    this.gamesNeedSteam = true,
  });

  final LauncherData data;
  final SettingsController settings;
  final SystemServices services;
  final DateTime Function()? now;
  final bool showFps;

  /// See [LauncherShell.showServer].
  final bool showServer;

  /// See [LauncherShell.gamesNeedSteam].
  final bool gamesNeedSteam;

  /// See [LauncherShell.startup].
  final LoadingIdentity? startup;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.value;
        final tokens = HinterTokens.fromSettings(s);
        return MaterialApp(
          title: 'HinterOS',
          debugShowCheckedModeBanner: false,
          theme: HinterTheme.material(tokens),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(s.textScale),
              disableAnimations: s.reduceMotion,
            ),
            child: HinterTheme(
              tokens: tokens,
              child: DesignScale(child: child!),
            ),
          ),
          home: LauncherShell(
            data: data,
            settings: settings,
            services: services,
            now: now,
            showFps: showFps,
            startup: startup,
            showServer: showServer,
            gamesNeedSteam: gamesNeedSteam,
          ),
        );
      },
    );
  }
}

/// Lays the 1920x1080 design out on any screen size (also used by the
/// installer).
class DesignScale extends StatelessWidget {
  const DesignScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size == designSize) return child;
    return ColoredBox(
      color: HinterTheme.of(context).background,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: designSize,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: designSize),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Builds the data layer on top of [connection].
LauncherData buildData(DaemonConnection connection) => LauncherData(
  connection: connection,
  apps: AppsRepository(connection),
  games: GamesRepository(connection),
);
