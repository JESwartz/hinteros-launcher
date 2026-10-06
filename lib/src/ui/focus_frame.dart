import 'package:flutter/material.dart';

import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';

/// Wraps a card with the focus indicator: scale-up (unless reducing motion)
/// and a [FocusStyle]-dependent marker drawn outside the card. The indicator
/// is a shape (thick ring, ring plus glow, or a bar), never only a colour, so
/// it survives colour blindness.
class FocusFrame extends StatelessWidget {
  const FocusFrame({
    super.key,
    required this.focused,
    required this.child,
    this.radius = HinterTokens.radiusCard,
    this.style,
    this.scale = HinterTokens.focusScale,
  });

  final bool focused;
  final Widget child;
  final double radius;

  /// Overrides the style from the theme (settings preview).
  final FocusStyle? style;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final style = this.style ?? t.focusStyle;
    return AnimatedScale(
      scale: focused && !t.reduceMotion ? scale : 1,
      duration: t.fast,
      curve: Curves.easeOut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (style == FocusStyle.glow)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: focused ? 1 : 0,
                  duration: t.fast,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.75),
                          blurRadius: 44,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: focused ? 1 : 0,
                duration: t.fast,
                child: _indicator(t, style),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator(HinterTokens t, FocusStyle style) {
    switch (style) {
      case FocusStyle.ring:
        // White ring, dark gap: reads on light and dark art alike.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -9,
              top: -9,
              right: -9,
              bottom: -9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 9),
                  border: Border.all(color: t.focusRing, width: 6),
                ),
              ),
            ),
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 3),
                  border: Border.all(color: t.focusGap, width: 3),
                ),
              ),
            ),
          ],
        );
      case FocusStyle.glow:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 3),
                  border: Border.all(color: t.focusRing, width: 3),
                ),
              ),
            ),
          ],
        );
      case FocusStyle.bar:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              right: 8,
              bottom: -14,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.focusRing,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        );
    }
  }
}
