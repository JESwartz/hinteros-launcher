import 'package:flutter/material.dart';

import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import 'cards.dart';
import 'common.dart';
import 'home_screen.dart' show connectionNotice;
import 'nav_grid_view.dart';

/// Games: a grid of 2:3 covers (placeholder art when there is none).
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
              // TODO(0.3): this wording assumes the Steam library is read by
              // the daemon; adjust once games.list exists.
              const Notice(
                title: 'No games yet',
                detail: 'Games you install in Steam will show up here.',
              );
        }
        const width = 256.0;
        return NavGridView(
          region: region,
          itemCount: games.length,
          cellWidth: width,
          cellHeight: width * 3 / 2 + GameCard.titleHeight(context),
          onSelect: (i) => data.launchGame(games[i]),
          itemBuilder: (_, i, focused) => GameCard(
            title: games[i].title,
            artworkPath: games[i].artworkPath,
            focused: focused,
            width: width,
          ),
        );
      },
    );
  }
}
