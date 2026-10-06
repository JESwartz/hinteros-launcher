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
    this.steamMissing = false,
    this.onOpenStore,
  });

  final LauncherData data;
  final NavRegion region;

  /// Steam is not installed (Store state): offer to install it.
  final bool steamMissing;
  final VoidCallback? onOpenStore;

  @override
  Widget build(BuildContext context) {
    if (steamMissing) {
      return _SteamPrompt(region: region, onOpenStore: onOpenStore);
    }
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
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

/// Steam is not installed: say so and lead to the Store.
class _SteamPrompt extends StatelessWidget {
  const _SteamPrompt({required this.region, required this.onOpenStore});

  final NavRegion region;
  final VoidCallback? onOpenStore;

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
          const SizedBox(height: HinterTokens.s2),
          Text(
            'Your games come from Steam. Install it from the Store and they '
            'will show up here.',
            style: t.bodyDim,
          ),
          const SizedBox(height: HinterTokens.s4),
          NavFocusable(
            region: region,
            rowKey: 'install-steam',
            col: 0,
            onSelect: onOpenStore,
            builder: (_, f) => HButton(
              label: 'Install Steam from the Store',
              focused: f,
              primary: true,
            ),
          ),
        ],
      ),
    );
  }
}
