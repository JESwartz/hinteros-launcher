import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../system/models.dart';
import '../theme/hinter_theme.dart';
import 'nav_focusable.dart';
import 'widgets.dart';

/// "An update is available": a reminder at the top of Home. Not modal; one
/// step from the tab bar and the content, like the Steam banner.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.update,
    required this.region,
    required this.onOpen,
  });

  final AvailableUpdate update;
  final NavRegion region;
  final VoidCallback onOpen;

  static String message(AvailableUpdate u) => u.isSecurity
      ? 'Security update HinterOS ${u.version} is available '
            '(severity: ${u.severity!.label}).'
      : 'HinterOS ${u.version} is available.';

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HinterTokens.margin,
        HinterTokens.s1,
        HinterTokens.margin,
        HinterTokens.s2,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
          border: Border.all(
            color: update.isSecurity ? t.danger : t.accent,
            width: 3,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2 + 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message(update),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.body,
                ),
              ),
              const SizedBox(width: HinterTokens.s2),
              NavFocusable(
                region: region,
                rowKey: 'update-banner',
                col: 0,
                scrollIntoView: false,
                onSelect: onOpen,
                builder: (_, f) =>
                    HButton(label: 'See update', focused: f, primary: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
