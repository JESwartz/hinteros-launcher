import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'cards.dart';
import 'common.dart';
import 'nav_focusable.dart';

/// Shows [Notice]s for connection problems; null when connected.
Widget? connectionNotice(ConnectionStatus s) => switch (s) {
  Connected() => null,
  VersionMismatch() => Notice(
    title: "Launcher and system service versions don't match",
    detail:
        'This launcher speaks API ${s.clientApiVersion}, the service '
        'speaks ${s.serverApiVersion}. Retrying; an update may be half applied.',
  ),
  Unreachable() => Notice(
    title: "Can't reach the HinterOS service",
    detail: '${s.reason}. Retrying.',
  ),
  Connecting() => const Notice(title: 'Connecting to the HinterOS service'),
};

/// Home: Continue (running and recent apps), Apps and Games rows, in one
/// vertically scrolling page. All rows live in [region]; each remembers its
/// own column.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.data, required this.region});

  /// Most games on the Home row; the Games section has the rest.
  static const maxGames = 12;

  final LauncherData data;
  final NavRegion region;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final notice = connectionNotice(data.status);
        if (notice != null) {
          region.setRows(const []);
          return notice;
        }
        final cont = data.continueEntries;
        final apps = data.appList ?? const <App>[];
        final games = data.gameList.take(maxGames).toList();
        region.setRows([
          NavRow('continue', cont.length),
          NavRow('apps', apps.length),
          NavRow('games', games.length),
        ]);
        if (data.appList == null && data.appsError != null) {
          return const Notice(
            title: "Couldn't load apps",
            detail:
                'The HinterOS service did not answer. Retrying on reconnect.',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: HinterTokens.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cont.isNotEmpty) ...[
                RowHeader('Continue', key: const ValueKey('h-continue')),
                _HRow(
                  key: const ValueKey('continue'),
                  children: [
                    for (var i = 0; i < cont.length; i++)
                      NavFocusable(
                        key: ValueKey('continue:$i'),
                        region: region,
                        rowKey: 'continue',
                        col: i,
                        onSelect: () =>
                            data.launchApp(cont[i].id, cont[i].name),
                        builder: (_, f) => AppTile(
                          name: cont[i].name,
                          focused: f,
                          running: cont[i].isRunning,
                          width: 384,
                          large: true,
                          iconPath: _iconOf(apps, cont[i].id),
                        ),
                      ),
                  ],
                ),
              ],
              RowHeader('Apps', key: const ValueKey('h-apps')),
              _HRow(
                key: const ValueKey('apps'),
                children: [
                  for (var i = 0; i < apps.length; i++)
                    NavFocusable(
                      key: ValueKey('apps:$i'),
                      region: region,
                      rowKey: 'apps',
                      col: i,
                      onSelect: () => data.launchApp(apps[i].id, apps[i].name),
                      builder: (_, f) => AppTile(
                        name: apps[i].name,
                        focused: f,
                        iconPath: apps[i].icon,
                        running: data.isRunning(apps[i].id),
                        width: 288,
                      ),
                    ),
                ],
              ),
              if (games.isNotEmpty) ...[
                RowHeader('Games', key: const ValueKey('h-games')),
                _HRow(
                  key: const ValueKey('games'),
                  children: [
                    for (var i = 0; i < games.length; i++)
                      NavFocusable(
                        key: ValueKey('games:$i'),
                        region: region,
                        rowKey: 'games',
                        col: i,
                        onSelect: () => data.launchGame(games[i]),
                        builder: (_, f) => GameCard(
                          title: games[i].title,
                          artworkPath: games[i].artworkPath,
                          focused: f,
                          width: 176,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String? _iconOf(List<App> apps, String id) =>
      apps.where((a) => a.id == id).firstOrNull?.icon;
}

/// A horizontally scrolling row with room around it for the focus ring and
/// scale-up.
class _HRow extends StatelessWidget {
  const _HRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(
        HinterTokens.margin,
        HinterTokens.s2 + 4,
        HinterTokens.margin,
        HinterTokens.s3 + 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: HinterTokens.s4),
            children[i],
          ],
        ],
      ),
    );
  }
}
