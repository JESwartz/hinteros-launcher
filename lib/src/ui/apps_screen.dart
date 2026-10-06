import 'package:flutter/material.dart';

import '../data/launcher_data.dart';
import '../nav/nav_controller.dart';
import 'cards.dart';
import 'common.dart';
import 'home_screen.dart' show connectionNotice;
import 'nav_grid_view.dart';

/// Apps: a grid of TV apps.
class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key, required this.data, required this.region});

  final LauncherData data;
  final NavRegion region;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final notice = connectionNotice(data.status);
        final apps = data.appList ?? const [];
        if (notice != null || apps.isEmpty) {
          region.setRows(const []);
          return notice ??
              const Notice(
                title: 'No apps yet',
                detail: 'Apps from the Store will show up here.',
              );
        }
        const width = 320.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RowHeader('Apps'),
            Expanded(
              child: NavGridView(
                region: region,
                itemCount: apps.length,
                cellWidth: width,
                cellHeight: width * 9 / 16,
                onSelect: (i) => data.launchApp(apps[i].id, apps[i].name),
                onContext: (i) => data.isRunning(apps[i].id)
                    ? () => data.requestClose(apps[i].id, apps[i].name)
                    : null,
                itemBuilder: (_, i, focused) => AppTile(
                  name: apps[i].name,
                  iconPath: apps[i].icon,
                  focused: focused,
                  running: data.isRunning(apps[i].id),
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
