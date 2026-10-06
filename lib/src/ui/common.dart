import 'package:flutter/material.dart';

import '../theme/hinter_theme.dart';

/// Small heading above a row.
class RowHeader extends StatelessWidget {
  const RowHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HinterTokens.margin,
        0,
        HinterTokens.margin,
        HinterTokens.s1,
      ),
      child: Text(text, style: t.title),
    );
  }
}

/// A message in place of content (daemon unreachable, nothing here yet).
class Notice extends StatelessWidget {
  const Notice({super.key, required this.title, this.detail = ''});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HinterTokens.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.title),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: HinterTokens.s2),
              Text(detail, style: t.bodyDim),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades the edges of scrolling [child] into the screen background, so
/// content that scrolls under the tab bar (or off the bottom) dissolves
/// instead of being cut off by the viewport edge. [top] and [bottom] are the
/// fade heights; keep the first row's padding at least as tall as [top] so a
/// row scrolled to the top is untouched.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.child,
    this.top = 56,
    this.bottom = 32,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final bg = HinterTheme.of(context).background;
    Widget fade(bool atTop, double height) => Positioned(
      left: 0,
      right: 0,
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
              // Solid for the first part: the cut edge is never visible.
              colors: [bg, bg, bg.withValues(alpha: 0)],
              stops: const [0, 0.3, 1],
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (top > 0) fade(true, top),
        if (bottom > 0) fade(false, bottom),
      ],
    );
  }
}
