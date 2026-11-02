import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/data/app_icons.dart';
import 'package:hinteros_launcher/src/ui/app_icon_view.dart';

import 'support/harness.dart';

/// App icons: decoding (PNG and SVG), the fallback for files that are not
/// images, refreshing when the daemon says `apps_changed`.
void main() {
  Future<AppIconEntry> load(WidgetTester t, AppIconCache c, String p) async =>
      (await t.runAsync(() => c.load(p)))!;

  group('AppIconCache', () {
    testWidgets('decodes a PNG and finds its colours', (t) async {
      final e = await load(
        t,
        AppIconCache(),
        '${iconDir()}/jellyfin-desktop.png',
      );
      final icon = e.icon!;
      expect(icon.image.width, 256);
      // Green square: the tint is green, the icon is not dark.
      final hsl = HSLColor.fromColor(icon.tint);
      expect(hsl.hue, inInclusiveRange(100, 160));
      expect(icon.luminance, greaterThan(0.2));
    });

    testWidgets('rasterises an SVG', (t) async {
      final e = await load(t, AppIconCache(), '${iconDir()}/crunchyroll.svg');
      expect(e.icon, isNotNull);
      expect(e.icon!.image.width, AppIconCache.maxEdge);
      expect(HSLColor.fromColor(e.icon!.tint).saturation, greaterThan(0.4));
    });

    testWidgets('a dark icon is recognised as dark', (t) async {
      final e = await load(t, AppIconCache(), '${iconDir()}/firefox.png');
      expect(e.icon!.luminance, lessThan(0.2));
    });

    testWidgets('missing and broken files give no icon, not an error', (
      t,
    ) async {
      final c = AppIconCache();
      expect((await load(t, c, '${iconDir()}/nope.png')).icon, isNull);
      expect((await load(t, c, '${iconDir()}/broken.png')).icon, isNull);
    });

    testWidgets('a changed file behind the same path is picked up', (t) async {
      final dir = tempDir();
      final f = File('${dir.path}/app.png');
      f.writeAsBytesSync(
        File('${iconDir()}/jellyfin-desktop.png').readAsBytesSync(),
      );
      final c = AppIconCache();
      final a = await load(t, c, f.path);
      // Same revision: served from memory.
      expect(identical(await load(t, c, f.path), a), isTrue);
      // Same bytes after an invalidate: the decoded icon is kept.
      c.invalidate();
      final same = await load(t, c, f.path);
      expect(identical(same.icon, a.icon), isTrue);
      // New bytes: decoded again.
      f.writeAsBytesSync(File('${iconDir()}/youtube.png').readAsBytesSync());
      c.invalidate();
      final b = await load(t, c, f.path);
      expect(identical(b.icon, a.icon), isFalse);
      expect(
        HSLColor.fromColor(b.icon!.tint).hue,
        isNot(closeTo(HSLColor.fromColor(a.icon!.tint).hue, 20)),
      );
    });
  });

  group('tiles', () {
    // Every app tile with a usable icon paints it; Plex has none.
    testWidgets('Apps tiles show their icons, Plex the letter', (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      // Home shows the Apps row: five icons, one letter tile.
      expect(find.byType(AppIconImage), findsNWidgets(5));
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets(
      'apps_changed: an icon that arrives later replaces the letter',
      (t) async {
        setView(t);
        final h = Harness();
        await h.pump(t);
        expect(find.byType(AppIconImage), findsNWidgets(5));
        h.mock.setAppIcon('plex', '${iconDir()}/plex.png');
        await t.pumpAndSettle();
        // Let the file load (real async), then the tile picks it up.
        await loadIcons(t, ['${iconDir()}/plex.png']);
        await t.pumpAndSettle();
        expect(find.byType(AppIconImage), findsNWidgets(6));
        expect(find.text('P'), findsNothing);
      },
    );

    testWidgets('a broken icon file falls back to the letter tile', (t) async {
      setView(t);
      final h = Harness(
        mock: MockDaemon(
          apps: [
            App(
              id: 'jellyfin-desktop',
              name: 'Jellyfin',
              kind: AppKind.native,
              permissions: const [],
              icon: '${iconDir()}/broken.png',
            ),
            App(
              id: 'plex',
              name: 'Plex',
              kind: AppKind.native,
              permissions: const [],
              icon: '${iconDir()}/missing.png',
            ),
          ],
        ),
      );
      await loadIcons(t, [
        '${iconDir()}/broken.png',
        '${iconDir()}/missing.png',
      ]);
      await h.pump(t);
      expect(find.byType(AppIconImage), findsNothing);
      for (final (i, letter) in [(0, 'J'), (1, 'P')]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('apps:$i')),
            matching: find.text(letter),
          ),
          findsOneWidget,
        );
      }
    });
  });
}
