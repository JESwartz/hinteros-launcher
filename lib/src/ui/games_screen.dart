import 'package:flutter/material.dart';

import '../data/games_repository.dart';
import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import 'cards.dart';
import 'common.dart';
import 'home_screen.dart' show connectionNotice;
import 'nav_grid_view.dart';

/// Games: a grid of 2:3 covers from the Steam library (placeholder art when
/// there is none, a badge and a dimmed cover when the game cannot be started).
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key, required this.data, required this.region});

  final LauncherData data;
  final NavRegion region;

  @override
  Widget build(BuildContext context) {
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
