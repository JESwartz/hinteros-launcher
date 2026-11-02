import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/nav/soft_key.dart';
import 'package:hinteros_launcher/src/ui/nav_focusable.dart';

import '../support/harness.dart';
import '../support/installer_harness.dart';

double _scale(WidgetTester t, String label) => t
    .widget<AnimatedScale>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text(label),
              matching: find.byType(NavFocusable),
            ),
            matching: find.byType(AnimatedScale),
          )
          .first,
    )
    .scale;

/// The installer's own keyboard (the Wi-Fi password) up, as on the ISO.
Future<InstallerHarness> _keyboardUp(WidgetTester t) async {
  final h = InstallerHarness(
    backend: FakeInstallerBackend(
      state: const NetworkState(wifiAvailable: true),
      wifiPasswords: {'Living Room': 'pw'},
    ),
  );
  await h.pump(t);
  h.flow.go(InstallerStep.network);
  await t.pumpAndSettle();
  await h.choose(t, 'w:Living Room');
  expect(h.console(t).keyboard, isNotNull);
  return h;
}

void main() {
  testWidgets('a key on the real keyboard shows on the in-app keyboard once', (
    t,
  ) async {
    final h = await _keyboardUp(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK, character: 'k');
    await t.pump();
    expect(focusLabel(), 'osk/r2:7'); // k
    expect(_scale(t, 'k'), lessThan(1));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(_scale(t, 'k'), 1);
    expect(h.console(t).keyboard!.text.value, 'k', reason: 'typed once');
  });

  testWidgets('a key from the evdev fallback shows too, and Tab', (t) async {
    final h = await _keyboardUp(t);
    final sink = h.console(t).softKeys;
    sink.handler!(
      const SoftKey(
        LogicalKeyboardKey.digit1,
        NavPhase.press,
        character: '!',
        shift: true,
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.text('!'), findsNWidgets(2)); // key + preview
    expect(_scale(t, '!'), lessThan(1));
    expect(h.console(t).keyboard!.text.value, '!');
    await t.pump(const Duration(milliseconds: 200));
    sink.handler!(const SoftKey(LogicalKeyboardKey.tab, NavPhase.press));
    await t.pump();
    await t.pump();
    expect(_scale(t, 'Tab'), lessThan(1));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(h.console(t).keyboard!.text.value, '!');
  });
}
