import 'package:flutter/material.dart';

import '../data/games_repository.dart';
import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'nav_focusable.dart';
import 'widgets.dart';
import 'cards.dart';
import 'common.dart';
import 'home_screen.dart' show connectionNotice;
import 'nav_grid_view.dart';

/// Games: a grid of 2:3 covers from the Steam library (placeholder art when
/// there is none, a badge and a dimmed cover when the game cannot be started).
class GamesScreen extends StatelessWidget {
  const GamesScreen({
    super.key,
    required this.data,
    required this.region,
    this.onInstallSteam,
  });

  final LauncherData data;
  final NavRegion region;

  /// The install flow for Steam (confirm, terms, progress), through the Store.
  final Future<void> Function(BuildContext context)? onInstallSteam;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        // The daemon leaves `steam` out of apps.list while Steam is not
        // installed (and lists it again after an install: apps_changed).
        final list = data.appList;
        if (list != null && !list.any((a) => a.id == 'steam')) {
          return _SteamPrompt(region: region, onInstall: onInstallSteam);
        }
        final notice = connectionNotice(data.status);
        final games = data.gameList;
        if (notice != null || games.isEmpty) {
          region.setRows(const []);
          return notice ??
              const Notice(
                title: 'No games yet',
                detail: 'Games you install in Steam will show up here.',
              );
        }
        const width = 256.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RowHeader('Games'),
            Expanded(
              child: NavGridView(
                region: region,
                itemCount: games.length,
                cellWidth: width,
                cellHeight: width * 3 / 2 + GameCard.titleHeight(context),
                onSelect: (i) => data.launchGame(games[i]),
                onContext: (i) => data.isGameRunning(games[i])
                    ? () => data.requestClose(games[i].runningId, games[i].name)
                    : null,
                itemBuilder: (_, i, focused) => GameCard(
                  game: games[i],
                  running: data.isGameRunning(games[i]),
                  focused: focused,
                  width: width,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Steam is not installed: say so and install it from here.
class _SteamPrompt extends StatelessWidget {
  const _SteamPrompt({required this.region, required this.onInstall});

  final NavRegion region;
  final Future<void> Function(BuildContext context)? onInstall;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    region.setRows(const [NavRow('install-steam', 1)]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HinterTokens.margin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Steam is not installed', style: t.headline),
          const SizedBox(height: HinterTokens.s4),
          NavFocusable(
            region: region,
            rowKey: 'install-steam',
            col: 0,
            onSelect: onInstall == null ? null : () => onInstall!(context),
            builder: (_, f) =>
                HButton(label: 'Install Steam', focused: f, primary: true),
          ),
        ],
      ),
    );
  }
}
