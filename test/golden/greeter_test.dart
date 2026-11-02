import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';

import '../profiles/greeter_test.dart' show Picker;

/// Golden screenshots of the profile picker (greeter mode) and its pages.
/// Regenerate with `nix run .#update-goldens`.
void main() {
  Future<void> shot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/greeter_${name}_1080p.png'),
  );

  testWidgets('picker', (t) async {
    final p = Picker(t);
    await p.pump();
    await shot(t, 'picker');
  });

  testWidgets('PIN pad, wrong PIN', (t) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    await p.press(NavAction.accept);
    await p.typePin('1111');
    await t.sendKeyEvent(LogicalKeyboardKey.digit4);
    await t.sendKeyEvent(LogicalKeyboardKey.digit2);
    await t.pumpAndSettle();
    await shot(t, 'pin_wrong');
  });

  testWidgets('PIN pad, locked out', (t) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    await p.press(NavAction.accept);
    for (final pin in ['1111', '1112', '1113', '1114']) {
      await p.typePin(pin);
    }
    await shot(t, 'pin_locked');
  });

  testWidgets('Add profile: colour', (t) async {
    final p = Picker(t);
    await p.pump();
    for (var i = 0; i < 3; i++) {
      await p.press(NavAction.right);
    }
    await p.press(NavAction.accept);
    await p.press(NavAction.accept);
    final kb = p.keyboard();
    await kb.type('Robin');
    kb.onDone!(kb.text.value);
    await t.pumpAndSettle();
    // The colours are below the name, on the same page.
    await p.press(NavAction.down);
    await p.press(NavAction.right);
    await p.press(NavAction.right);
    await shot(t, 'add_color');
  });

  testWidgets('Add profile: getting things ready', (t) async {
    final p = Picker(t);
    await p.pump();
    for (var i = 0; i < 3; i++) {
      await p.press(NavAction.right);
    }
    await p.press(NavAction.accept);
    await p.press(NavAction.accept);
    final kb = p.keyboard();
    await kb.type('Robin');
    kb.onDone!(kb.text.value);
    await t.pumpAndSettle();
    await p.press(NavAction.down);
    await p.press(NavAction.accept); // the first colour
    await p.typePin('2580');
    await p.typePin('2580');
    await p.press(NavAction.down);
    await p.press(NavAction.accept, settle: false);
    await shot(t, 'getting_ready');
  });

  testWidgets('loading the chosen profile', (t) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.accept, settle: false);
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'loading');
  });
}
