import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/soft_key.dart';
import 'package:hinteros_launcher/src/ui/nav_focusable.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart';
import 'osk_harness.dart';

SoftKey _down(LogicalKeyboardKey k, [String? c, bool shift = false]) =>
    SoftKey(k, NavPhase.press, character: c, shift: shift);

/// The scale of the key cap with this label (below 1: drawn pressed in).
AnimatedScale _cap(WidgetTester t, String label) => t.widget<AnimatedScale>(
  find
      .descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(NavFocusable),
        ),
        matching: find.byType(AnimatedScale),
      )
      .first,
);

double _scale(WidgetTester t, String label) => _cap(t, label).scale;

void main() {
  testWidgets('a physical letter lights its key and focus follows', (t) async {
    final h = OskHarness();
    await h.pump(t);
    h.echo.add(_down(LogicalKeyboardKey.keyG, 'g'));
    await t.pump();
    await t.pump();
    expect(focusLabel(), 'osk/r2:4'); // g is the fifth of "asdfghjkl'"
    expect(_scale(t, 'g'), lessThan(1));
    expect(_scale(t, 'h'), 1);
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(_scale(t, 'g'), 1);
    expect(focusLabel(), 'osk/r2:4'); // the focus stays
    expect(h.backend.calls, isEmpty, reason: 'nothing is typed');
  });

  testWidgets('a symbol switches to the symbols page', (t) async {
    final h = OskHarness();
    await h.pump(t);
    expect(find.text('@'), findsNothing);
    h.echo.add(_down(LogicalKeyboardKey.digit2, '@', true));
    await t.pump();
    await t.pump();
    expect(find.text('@'), findsOneWidget);
    expect(_scale(t, '@'), lessThan(1));
    expect(focusLabel(), 'osk/r1:1');
    expect(h.backend.calls, isEmpty);
  });

  testWidgets('a capital also presses Shift', (t) async {
    final h = OskHarness();
    await h.pump(t);
    h.echo.add(_down(LogicalKeyboardKey.keyQ, 'Q', true));
    await t.pump();
    await t.pump();
    expect(_scale(t, 'q'), lessThan(1));
    expect(_scale(t, 'Shift'), lessThan(1));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(_scale(t, 'Shift'), 1);
    expect(h.backend.calls, isEmpty);
  });

  testWidgets('Space, Backspace, Enter and Tab', (t) async {
    final h = OskHarness();
    await h.pump(t);
    for (final (k, label) in [
      (LogicalKeyboardKey.space, 'Space'),
      (LogicalKeyboardKey.backspace, 'Backspace'),
      (LogicalKeyboardKey.enter, 'Enter'),
      (LogicalKeyboardKey.tab, 'Tab'),
    ]) {
      h.echo.add(_down(k, k == LogicalKeyboardKey.space ? ' ' : null));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(_scale(t, label), lessThan(1), reason: label);
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
    }
    expect(h.backend.calls, isEmpty);
  });

  testWidgets('releases, arrows and shortcuts do nothing', (t) async {
    final h = OskHarness();
    await h.pump(t);
    final before = focusLabel();
    h.echo.add(const SoftKey(LogicalKeyboardKey.keyG, NavPhase.release));
    h.echo.add(_down(LogicalKeyboardKey.arrowDown));
    h.echo.add(_down(LogicalKeyboardKey.keyC)); // Ctrl+C: no character
    await t.pump();
    expect(focusLabel(), before);
    expect(_scale(t, 'g'), 1);
  });

  testWidgets('reduce motion: no scale animation, still highlighted', (
    t,
  ) async {
    final h = OskHarness(settings: const LauncherSettings(reduceMotion: true));
    await h.pump(t);
    h.echo.add(_down(LogicalKeyboardKey.keyG, 'g'));
    await t.pump();
    await t.pump();
    final cap = _cap(t, 'g');
    expect(cap.duration, Duration.zero);
    expect(cap.scale, lessThan(1));
  });
}
