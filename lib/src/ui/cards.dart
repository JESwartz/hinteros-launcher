import 'dart:io';

import 'package:flutter/material.dart';

import '../api/api.dart' show Game;
import '../data/games_repository.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';

/// Stable hue from a string (Dart's String.hashCode is not stable across runs;
/// goldens need the same colours every time).
double hueFor(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  return (h % 360).toDouble();
}

/// Art for something without an image (or whose image failed to load): a
/// gradient in a hue derived from [seed] and a big initial. Drawn locally; no
/// asset files, no network.
class PlaceholderArt extends StatelessWidget {
  const PlaceholderArt({
    super.key,
    required this.seed,
    this.initialSize = 96,
    this.alignment = Alignment.center,
    this.showInitial = true,
  });

  final Alignment alignment;

  final String seed;
  final double initialSize;

  /// False when the caller lays out its own initial (the app tile does, so
  /// the letter can make room for the name and the badge).
  final bool showInitial;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final hue = hueFor(seed);
    final a = t.highContrast
        ? t.surfaceHigh
        : HSLColor.fromAHSL(1, hue, 0.45, 0.30).toColor();
    final b = t.highContrast
        ? t.surface
        : HSLColor.fromAHSL(1, (hue + 40) % 360, 0.50, 0.16).toColor();
    final initial = seed.trim().isEmpty ? '?' : seed.trim()[0].toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
      child: showInitial
          ? Align(
              alignment: alignment,
              child: Text(
                initial,
                style: t.headline.copyWith(
                  fontSize: initialSize,
                  color: t.text.withValues(alpha: 0.3),
                ),
              ),
            )
          : null,
    );
  }
}

/// Cover art from a file path, with the placeholder when there is no path or
/// the file cannot be read.
class ArtImage extends StatelessWidget {
  const ArtImage({
    super.key,
    required this.path,
    required this.seed,
    this.initialSize = 96,
    this.alignment = Alignment.center,
    this.showInitial = true,
  });

  final Alignment alignment;
  final bool showInitial;
  final String? path;
  final String seed;
  final double initialSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = PlaceholderArt(
      seed: seed,
      initialSize: initialSize,
      alignment: alignment,
      showInitial: showInitial,
    );
    final p = path;
    if (p == null || p.isEmpty) return placeholder;
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Landscape (16:9) tile for an app or a running game: art (or a placeholder
/// with the initial), the name along the bottom and an optional Running mark.
/// Mark, initial and name are laid out in a column, so they cannot overlap at
/// any text size; the initial gives way when there is no room left.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.name,
    required this.focused,
    this.iconPath,
    this.running = false,
    this.width = 320,
    this.large = false,
  });

  final String name;
  final String? iconPath;
  final bool focused;
  final bool running;
  final double width;

  /// Bigger type (Continue row).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final height = width * 9 / 16;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return FocusFrame(
      focused: focused,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArtImage(path: iconPath, seed: name, showInitial: false),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (running)
                    Padding(
                      padding: const EdgeInsets.all(HinterTokens.s1),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const RunningPill(),
                        ),
                      ),
                    ),
                  // What is left between mark and name: the initial, if it
                  // fits at a useful size.
                  Expanded(
                    child: iconPath == null || iconPath!.isEmpty
                        ? LayoutBuilder(
                            builder: (context, c) {
                              final size = (c.maxHeight * 0.8).clamp(
                                0.0,
                                height * 0.5,
                              );
                              if (size < 32) return const SizedBox.shrink();
                              return Center(
                                child: Text(
                                  initial,
                                  maxLines: 1,
                                  style: t.headline.copyWith(
                                    fontSize: size,
                                    height: 1.0,
                                    color: t.text.withValues(alpha: 0.3),
                                  ),
                                ),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Scrim so the name reads on any art. Mark and name take
                  // the room they need first; the initial gets the rest.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HinterTokens.s2 + 4,
                        HinterTokens.s1,
                        HinterTokens.s2 + 4,
                        HinterTokens.s1 + 4,
                      ),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (large ? t.label : t.body).copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (t.highContrast)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      HinterTokens.radiusCard,
                    ),
                    border: Border.all(color: t.textDim, width: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small status mark on a card: a shape plus text, not colour alone.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.filled});

  final String text;

  /// Filled dot on the accent colour (Running) or a hollow ring on a dark
  /// pill (install states).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final fg = filled ? t.onAccent : t.text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? t.accent : t.surface.withValues(alpha: 0.94),
        border: filled ? null : Border.all(color: t.textDim, width: 2),
        borderRadius: BorderRadius.circular(
          text.contains('\n')
              ? HinterTokens.radiusSmall
              : HinterTokens.radiusPill,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HinterTokens.s2,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: filled ? fg : null,
                border: filled ? null : Border.all(color: fg, width: 2.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              maxLines: 1,
              style: t.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Running" mark: a dot shape plus text, not colour alone.
class RunningPill extends StatelessWidget {
  const RunningPill({super.key});

  @override
  Widget build(BuildContext context) =>
      const _Pill(text: 'Running', filled: true);
}

/// Portrait (2:3) game cover with the title underneath. A game that cannot be
/// started (update, install...) is dimmed and says why in a badge.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.focused,
    this.running = false,
    this.width = 256,
  });

  /// Height of the title area for [lines] lines at the current text scale.
  static double titleHeight(BuildContext context, {int lines = 2}) =>
      MediaQuery.textScalerOf(context).scale(HinterTokens.fsCaption) *
          1.25 *
          lines +
      titleGap;

  /// Space between art and title, enough for the scaled-up focus ring.
  static const titleGap = 28.0;

  final Game game;
  final bool running;
  final bool focused;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final height = width * 3 / 2;
    // Narrow covers break the label over two lines ("Update" / "required")
    // instead of cutting a word; the pill still scales down if it must.
    final badge = width < 200
        ? game.badge?.replaceFirst(' ', '\n')
        : game.badge;
    final unavailable = !game.canLaunch;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusFrame(
            focused: focused,
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ArtImage(
                      path: game.artwork.portrait,
                      seed: game.name,
                      initialSize: width * 0.45,
                    ),
                    if (unavailable)
                      ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
                    if (running || badge != null)
                      Positioned(
                        top: HinterTokens.s1,
                        left: HinterTokens.s1,
                        right: HinterTokens.s1,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: running
                                ? const RunningPill()
                                : _Pill(text: badge!, filled: false),
                          ),
                        ),
                      ),
                    if (t.highContrast)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            HinterTokens.radiusCard,
                          ),
                          border: Border.all(color: t.textDim, width: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: titleGap),
          SizedBox(
            height: titleHeight(context) - titleGap,
            child: Text(
              game.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(
                color: focused ? t.text : t.textDim,
                fontWeight: focused ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
