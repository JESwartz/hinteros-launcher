import 'dart:io';

import 'package:flutter/material.dart';

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
  });

  final Alignment alignment;

  final String seed;
  final double initialSize;

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
      child: Align(
        alignment: alignment,
        child: Text(
          initial,
          style: t.headline.copyWith(
            fontSize: initialSize,
            color: t.text.withValues(alpha: 0.3),
          ),
        ),
      ),
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
  });

  final Alignment alignment;
  final String? path;
  final String seed;
  final double initialSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = PlaceholderArt(
      seed: seed,
      initialSize: initialSize,
      alignment: alignment,
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

/// Landscape (16:9) tile for an app, with its name over the art and an
/// optional Running mark.
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
              ArtImage(path: iconPath, seed: name, initialSize: height * 0.5),
              // Scrim so the name reads on any art.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
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
                      HinterTokens.s4,
                      HinterTokens.s2 + 4,
                      HinterTokens.s2,
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
              ),
              if (running)
                Positioned(
                  top: HinterTokens.s2,
                  left: HinterTokens.s2,
                  child: RunningPill(),
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

/// "Running" mark: a dot shape plus text, not colour alone.
class RunningPill extends StatelessWidget {
  const RunningPill({super.key});

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
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
                color: t.onAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Running',
              style: t.caption.copyWith(
                color: t.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portrait (2:3) game cover with the title underneath.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.title,
    required this.focused,
    this.artworkPath,
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

  final String title;
  final String? artworkPath;
  final bool focused;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final height = width * 3 / 2;
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
                      path: artworkPath,
                      seed: title,
                      initialSize: width * 0.45,
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
              title,
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
