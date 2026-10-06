import 'package:flutter/material.dart';

import '../data/app_icons.dart';
import '../theme/hinter_theme.dart';
import 'cards.dart' show PlaceholderArt;

/// Resolves the icon file at [path] through [AppIconCache] and builds with the
/// result: `null` while it loads for the first time, an entry whose `icon` is
/// null when the file is unusable. A changed file shows the old icon until
/// the new one is decoded.
class AppIconLoader extends StatefulWidget {
  const AppIconLoader({
    super.key,
    required this.path,
    required this.builder,
    this.cache,
  });

  final String path;
  final Widget Function(BuildContext context, AppIconEntry? entry) builder;
  final AppIconCache? cache;

  @override
  State<AppIconLoader> createState() => _AppIconLoaderState();
}

class _AppIconLoaderState extends State<AppIconLoader> {
  AppIconEntry? _entry;
  late AppIconCache _cache;

  @override
  void initState() {
    super.initState();
    _cache = (widget.cache ?? AppIconCache.instance)..addListener(_changed);
    _resolve();
  }

  @override
  void dispose() {
    _cache.removeListener(_changed);
    super.dispose();
  }

  @override
  void didUpdateWidget(AppIconLoader old) {
    super.didUpdateWidget(old);
    _resolve();
  }

  /// Some load finished: take the entry for our path if it is a new one.
  void _changed() {
    final e = _cache.peek(widget.path);
    if (mounted && !identical(e, _entry)) setState(() => _entry = e);
  }

  void _resolve() {
    final have = _cache.peek(widget.path);
    _entry = have;
    if (!_cache.isFresh(have)) _cache.load(widget.path);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _entry);
}

/// Backdrop colours for an icon: a dark tint of its dominant colour, so the
/// tile belongs to the app; a light neutral for icons so dark that they would
/// vanish on a dark tile.
({Color top, Color bottom, Color glow}) iconBackdrop(
  AppIcon icon,
  HinterTokens t,
) {
  final hsl = HSLColor.fromColor(icon.tint);
  if (icon.luminance < 0.2) {
    return (
      top: HSLColor.fromAHSL(1, hsl.hue, 0.12, 0.86).toColor(),
      bottom: HSLColor.fromAHSL(1, hsl.hue, 0.14, 0.70).toColor(),
      glow: Colors.white.withValues(alpha: 0.5),
    );
  }
  final s = (hsl.saturation * 0.8).clamp(0.12, 0.62);
  return (
    top: HSLColor.fromAHSL(
      1,
      hsl.hue,
      s,
      t.highContrast ? 0.22 : 0.27,
    ).toColor(),
    bottom: HSLColor.fromAHSL(
      1,
      hsl.hue,
      s,
      t.highContrast ? 0.10 : 0.13,
    ).toColor(),
    glow: HSLColor.fromAHSL(
      1,
      hsl.hue,
      s,
      0.5,
    ).toColor().withValues(alpha: 0.28),
  );
}

/// The icon on its tinted backdrop, filling the available space: the icon
/// centred (contained, never cropped), [inset] clear space around it.
class AppIconBackdrop extends StatelessWidget {
  const AppIconBackdrop({
    super.key,
    required this.icon,
    this.iconAlignment = Alignment.center,
  });

  final AppIcon icon;
  final Alignment iconAlignment;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final c = iconBackdrop(icon, t);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.top, c.bottom],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(iconAlignment.x, iconAlignment.y),
            radius: 0.75,
            colors: [c.glow, c.glow.withValues(alpha: 0)],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The icon image itself, contained in its box.
class AppIconImage extends StatelessWidget {
  const AppIconImage({super.key, required this.icon, required this.size});

  final AppIcon icon;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: RawImage(
      image: icon.image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// A small square badge for an app: its icon on the tinted backdrop, or the
/// letter placeholder when there is no usable icon. For dialogs.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.name,
    required this.iconPath,
    this.size = 96,
  });

  final String name;
  final String? iconPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = iconPath;
    Widget body(AppIconEntry? e) {
      final icon = e?.icon;
      if (icon != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AppIconBackdrop(icon: icon),
            Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: AppIconImage(icon: icon, size: size),
            ),
          ],
        );
      }
      return PlaceholderArt(
        seed: name,
        initialSize: size * 0.55,
        showInitial: e != null || p == null || p.isEmpty,
      );
    }

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HinterTokens.radiusSmall + 4),
        child: p == null || p.isEmpty
            ? body(null)
            : AppIconLoader(path: p, builder: (_, e) => body(e)),
      ),
    );
  }
}
