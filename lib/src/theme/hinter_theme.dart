import 'package:flutter/material.dart';

import '../settings/launcher_settings.dart';

/// Bundled font family (Atkinson Hyperlegible, OFL; see assets/fonts/OFL.txt).
const hinterFontFamily = 'AtkinsonHyperlegible';

/// Design tokens for the 10-foot UI. All sizes are logical pixels laid out for
/// a 1920x1080 logical screen; a 4K display runs the same layout at
/// devicePixelRatio 2, so nothing here depends on the physical resolution.
///
/// Spacing and radii follow a 8px grid. The overscan-safe margin is 5%.
class HinterTokens {
  const HinterTokens({
    required this.highContrast,
    required this.focusStyle,
    required this.reduceMotion,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.onAccent,
    required this.focusRing,
    required this.focusGap,
    required this.positive,
    required this.danger,
  });

  factory HinterTokens.fromSettings(LauncherSettings s) => s.highContrast
      ? HinterTokens._highContrast(s)
      : HinterTokens._standard(s);

  factory HinterTokens._standard(LauncherSettings s) => HinterTokens(
    highContrast: false,
    focusStyle: s.focusStyle,
    reduceMotion: s.reduceMotion,
    background: const Color(0xFF0E1118),
    surface: const Color(0xFF1B2030),
    surfaceHigh: const Color(0xFF2A3147),
    text: const Color(0xFFF4F6FB),
    textDim: const Color(0xFFB4BBCC),
    accent: const Color(0xFF7AA2FF),
    onAccent: const Color(0xFF0B1020),
    focusRing: const Color(0xFFFFFFFF),
    focusGap: const Color(0xFF0E1118),
    positive: const Color(0xFF6EE0A0),
    danger: const Color(0xFFFF8A80),
  );

  // Pure black, pure white, yellow focus (yellow on black is distinguishable
  // for all common colour-vision deficiencies and has maximum luminance).
  factory HinterTokens._highContrast(LauncherSettings s) => HinterTokens(
    highContrast: true,
    focusStyle: s.focusStyle,
    reduceMotion: s.reduceMotion,
    background: const Color(0xFF000000),
    surface: const Color(0xFF14141A),
    surfaceHigh: const Color(0xFF2E2E38),
    text: const Color(0xFFFFFFFF),
    textDim: const Color(0xFFFFFFFF),
    accent: const Color(0xFFFFE14D),
    onAccent: const Color(0xFF000000),
    focusRing: const Color(0xFFFFE14D),
    focusGap: const Color(0xFF000000),
    positive: const Color(0xFF7DFFB0),
    danger: const Color(0xFFFF9C94),
  );

  final bool highContrast;
  final FocusStyle focusStyle;
  final bool reduceMotion;

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color text;
  final Color textDim;
  final Color accent;
  final Color onAccent;
  final Color focusRing;

  /// Colour between the card and the focus ring, so the ring reads on any art.
  final Color focusGap;
  final Color positive;
  final Color danger;

  // Spacing (8px grid).
  static const double s1 = 8;
  static const double s2 = 16;
  static const double s3 = 24;
  static const double s4 = 32;
  static const double s5 = 48;
  static const double s6 = 64;

  /// Horizontal screen margin (5% of 1920 is 96).
  static const double margin = 96;

  // Radii.
  static const double radiusSmall = 12;
  static const double radiusCard = 20;
  static const double radiusPill = 999;

  // Type scale. Nothing at 1080p is smaller than 24 logical px.
  static const double fsCaption = 24;
  static const double fsBody = 28;
  static const double fsLabel = 32;
  static const double fsTitle = 40;
  static const double fsHeadline = 56;

  /// Focus scale-up (skipped when reducing motion).
  static const double focusScale = 1.08;

  Duration get fast => reduceMotion ? Duration.zero : _fast;
  Duration get medium => reduceMotion ? Duration.zero : _medium;
  static const _fast = Duration(milliseconds: 140);
  static const _medium = Duration(milliseconds: 260);

  TextStyle _t(double size, FontWeight w, Color c, {double? height}) =>
      TextStyle(
        fontFamily: hinterFontFamily,
        fontSize: size,
        fontWeight: w,
        color: c,
        height: height ?? 1.25,
      );

  TextStyle get caption => _t(fsCaption, FontWeight.w400, textDim);
  TextStyle get body => _t(fsBody, FontWeight.w400, text);
  TextStyle get bodyDim => _t(fsBody, FontWeight.w400, textDim);
  TextStyle get label => _t(fsLabel, FontWeight.w700, text);
  TextStyle get title => _t(fsTitle, FontWeight.w700, text);
  TextStyle get headline => _t(fsHeadline, FontWeight.w700, text);
}

/// Provides [HinterTokens] below the app and builds the Material theme from
/// them. Use `HinterTheme.of(context)` in widgets.
class HinterTheme extends InheritedWidget {
  const HinterTheme({super.key, required this.tokens, required super.child});

  final HinterTokens tokens;

  static HinterTokens of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<HinterTheme>();
    assert(t != null, 'No HinterTheme above this context');
    return t!.tokens;
  }

  /// Material theme matching [t] (for the few Material widgets we use).
  static ThemeData material(HinterTokens t) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: hinterFontFamily,
    scaffoldBackgroundColor: t.background,
    colorScheme: ColorScheme.dark(
      primary: t.accent,
      onPrimary: t.onAccent,
      surface: t.surface,
      onSurface: t.text,
    ),
    splashFactory: NoSplash.splashFactory,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.surfaceHigh,
      contentTextStyle: t.body,
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  bool updateShouldNotify(HinterTheme old) =>
      old.tokens.highContrast != tokens.highContrast ||
      old.tokens.focusStyle != tokens.focusStyle ||
      old.tokens.reduceMotion != tokens.reduceMotion;
}
