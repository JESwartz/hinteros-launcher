import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../osk/osk_harness.dart';
import '../support/harness.dart';

/// Golden screenshots of the on-screen keyboard at 1920x1080 over a
/// checkerboard, so that the transparent area and the panel's corners show:
/// everything outside the panel must be the checkerboard, unchanged.
void main() {
  const shotKey = ValueKey('osk-shot');

  Widget overCheckerboard(Widget osk) => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: shotKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Checkerboard()),
          osk,
        ],
      ),
    ),
  );

  Future<void> shot(
    WidgetTester t,
    String name, {
    LauncherSettings settings = const LauncherSettings(),
    Future<void> Function(WidgetTester, OskHarness)? setup,
  }) async {
    setView(t);
    final h = OskHarness(settings: settings);
    await h.pump(t, wrap: overCheckerboard);
    await setup?.call(t, h);
    await expectLater(
      find.byKey(shotKey),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('osk letters', (t) async {
    await shot(t, 'osk_letters_1080p');
  });

  testWidgets('osk symbols, typed text in the preview', (t) async {
    await shot(
      t,
      'osk_symbols_1080p',
      setup: (t, h) async {
        await h.type(t, 'h');
        await h.type(t, 'i');
        await h.nav(t, NavAction.pageRight);
        await h.moveTo(t, '@');
      },
    );
  });

  testWidgets('osk high contrast, text 1.6x, caps lock', (t) async {
    await shot(
      t,
      'osk_highcontrast_text160_1080p',
      settings: const LauncherSettings(textScale: 1.6, highContrast: true),
      setup: (t, h) async {
        await h.nav(t, NavAction.context);
        await h.nav(t, NavAction.context);
        await h.type(t, 'K');
        await h.moveTo(t, 'Backspace');
      },
    );
  });

  testWidgets('osk bar focus, one-shot shift', (t) async {
    await shot(
      t,
      'osk_bar_focus_shift_1080p',
      settings: const LauncherSettings(focusStyle: FocusStyle.bar),
      setup: (t, h) async {
        await h.nav(t, NavAction.context);
        await h.moveTo(t, 'Space');
      },
    );
  });
}

class _Checkerboard extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 40.0;
    final a = Paint()..color = const Color(0xFF8A8F99);
    final b = Paint()..color = const Color(0xFFC9CDD6);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          (x + y).isEven ? a : b,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
