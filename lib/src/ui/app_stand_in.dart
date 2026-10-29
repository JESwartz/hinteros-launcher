import 'package:flutter/material.dart';

import '../theme/hinter_theme.dart';
import 'app_icon_view.dart';

/// The browser demo only ([LauncherShell.leaveApp]): no app windows exist,
/// so this covers the launcher while an app has the focus, as the app's
/// window would on a box. B or a click go Home.
class AppStandIn extends StatelessWidget {
  const AppStandIn({
    super.key,
    required this.name,
    required this.iconPath,
    required this.onLeave,
  });

  final String name;
  final String? iconPath;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$name is open',
      child: ColoredBox(
        key: const ValueKey('stand-in'),
        color: t.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge(name: name, iconPath: iconPath, size: 160),
              const SizedBox(height: HinterTokens.s4),
              Text('$name is open', style: t.headline),
              const SizedBox(height: HinterTokens.s3),
              Text('The demo does not include apps.', style: t.bodyDim),
              const SizedBox(height: HinterTokens.s4),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: const ValueKey('stand-in-leave'),
                  onTap: onLeave,
                  child: Text('B Back to Home', style: t.caption),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
