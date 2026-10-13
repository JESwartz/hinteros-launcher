import 'package:flutter/material.dart';

import '../api/api.dart';
import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'app_icon_view.dart';
import 'focus_frame.dart';
import 'nav_focusable.dart';

/// A button for the banner and the confirm dialog: a pill with a label, focus
/// shown by [FocusFrame].
class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.focused,
    this.primary = false,
  });

  final String label;
  final bool focused;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusPill,
      scale: 1.05,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary ? t.accent : t.surface,
          border: primary ? null : Border.all(color: t.textDim, width: 2),
          borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s4,
            vertical: HinterTokens.s1 + 4,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: t.label.copyWith(color: primary ? t.onAccent : t.text),
          ),
        ),
      ),
    );
  }
}

/// "Steam needs your attention: <title>" with an action that brings Steam's
/// windows forward. Not modal: it sits between the tab bar and the content,
/// and its button is one step from the tab bar and the content.
class SteamBanner extends StatelessWidget {
  const SteamBanner({
    super.key,
    required this.windows,
    required this.region,
    required this.onOpen,
  });

  final List<SteamWindow> windows;
  final NavRegion region;
  final VoidCallback onOpen;

  /// Text for [windows]: the first title, and how many more there are.
  static String message(List<SteamWindow> windows) {
    final first = windows.first.title.trim();
    final title = first.isEmpty ? 'a window' : first;
    final more = windows.length - 1;
    return 'Steam needs your attention: $title'
        '${more > 0 ? ' (and $more more)' : ''}';
  }

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
          border: Border.all(color: t.accent, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2 + 4,
          ),
          child: Row(
            children: [
              // A mark that is not just a colour: an exclamation in a disc.
              Builder(
                builder: (context) {
                  // The disc grows with the text so the mark always fits.
                  final d = MediaQuery.textScalerOf(context).scale(40);
                  return Container(
                    width: d,
                    height: d,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '!',
                      textScaler: TextScaler.noScaling,
                      style: t.label.copyWith(
                        color: t.onAccent,
                        fontSize: d * 0.7,
                        height: 1,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: HinterTokens.s2),
              Expanded(
                child: Text(
                  message(windows),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.body,
                ),
              ),
              const SizedBox(width: HinterTokens.s2),
              NavFocusable(
                region: region,
                rowKey: 'banner',
                col: 0,
                scrollIntoView: false,
                onSelect: onOpen,
                builder: (_, f) =>
                    _Button(label: 'Open Steam', focused: f, primary: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The confirm step before closing a running app: a modal card over a dimmed
/// screen. Cancel is focused first so a stray accept does not close anything.
class CloseConfirm extends StatelessWidget {
  const CloseConfirm({
    super.key,
    required this.id,
    required this.name,
    this.iconPath,
    required this.region,
    required this.onCancel,
    required this.onConfirm,
  });

  final String id;
  final String name;

  /// The app's icon, if it has one.
  final String? iconPath;
  final NavRegion region;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    region.setRows([NavRow('buttons', 2)]);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
                border: Border.all(
                  color: t.highContrast ? t.text : t.surfaceHigh,
                  width: t.highContrast ? 3 : 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(HinterTokens.s5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIconBadge(name: name, iconPath: iconPath),
                        const SizedBox(width: HinterTokens.s3),
                        Expanded(
                          child: Text(
                            'Close $name?',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.title,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HinterTokens.s2),
                    Text(
                      id == 'steam'
                          ? 'This closes Big Picture. Steam keeps running.'
                          : 'Unsaved work may be lost.',
                      style: t.bodyDim,
                    ),
                    const SizedBox(height: HinterTokens.s4),
                    Wrap(
                      spacing: HinterTokens.s3,
                      runSpacing: HinterTokens.s2,
                      children: [
                        NavFocusable(
                          region: region,
                          rowKey: 'buttons',
                          col: 0,
                          scrollIntoView: false,
                          onSelect: onCancel,
                          builder: (_, f) =>
                              _Button(label: 'Cancel', focused: f),
                        ),
                        NavFocusable(
                          region: region,
                          rowKey: 'buttons',
                          col: 1,
                          scrollIntoView: false,
                          onSelect: onConfirm,
                          builder: (_, f) => _Button(
                            label: 'Close',
                            focused: f,
                            primary: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
