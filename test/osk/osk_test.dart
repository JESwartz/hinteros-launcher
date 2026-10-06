import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/osk/osk_layout.dart';

import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart';
import 'osk_harness.dart';

Finder _preview(String s) => find.byWidgetPredicate(
  (w) => w is Text && w.key == const ValueKey('osk-preview') && w.data == s,
);

const _showTyped = LauncherSettings(showTypedOnOsk: true);

void main() {
  Future<OskHarness> start(WidgetTester t, {OskHarness? h}) async {
    setView(t);
    h ??= OskHarness();
    await h.pump(t);
    return h;
  }

  group('layout', () {
    test('every row adds up to the grid', () {
      for (final page in OskPage.values) {
        for (final shift in ShiftState.values) {
          for (final r in oskLayout(page, shift)) {
            if (r.id == 'r3' && page == OskPage.symbols2) continue;
            expect(
              r.spans.fold<int>(0, (a, b) => a + b),
              oskGridUnits,
              reason: '$page ${r.id}',
            );
          }
        }
      }
    });

    test('every printable ASCII character can be typed', () {
      final typeable = {
        for (final page in OskPage.values)
          for (final shift in ShiftState.values)
            for (final r in oskLayout(page, shift))
              for (final k in r.keys)
                if (k.kind == KeyKind.char) k.value!,
      };
      for (var c = 0x21; c < 0x7f; c++) {
        expect(typeable, contains(String.fromCharCode(c)));
      }
    });
  });

  testWidgets('starts on q, transparent: nothing but the panel is painted', (
    t,
  ) async {
    await start(t);
    expect(focusLabel(), 'osk/r1:0');
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TextField), findsNothing);
    final panel = t.getRect(find.byKey(const ValueKey('osk-panel')));
    expect(panel.height, closeTo(1080 * 0.4, 0.5));
    expect(panel.bottom, 1080);
    expect(panel.width, 1920);
  });

  group('navigation', () {
    testWidgets('left and right wrap within a row', (t) async {
      final h = await start(t);
      await h.nav(t, NavAction.left);
      expect(focusLabel(), 'osk/r1:9'); // p
      await h.nav(t, NavAction.right);
      expect(focusLabel(), 'osk/r1:0');
    });

    testWidgets('up and down follow the keys, not the column index', (t) async {
      final h = await start(t);
      for (final dir in [NavAction.right, NavAction.right, NavAction.right]) {
        await h.nav(t, dir);
      }
      expect(focusLabel(), 'osk/r1:3'); // r
      await h.nav(t, NavAction.down);
      await h.nav(t, NavAction.down);
      expect(focusLabel(), 'osk/r3:2'); // x: r is above it, Shift is wide
      await h.nav(t, NavAction.down);
      expect(focusLabel(), 'osk/bottom:2', reason: 'the wide Space bar');
      await h.nav(t, NavAction.up);
      expect(focusLabel(), 'osk/r3:2', reason: 'back where we came from');
      await h.nav(t, NavAction.down);
      await h.nav(t, NavAction.down);
      expect(focusLabel(), 'osk/bottom:2', reason: 'stays on the bottom row');
    });

    testWidgets('up from the top row stays', (t) async {
      final h = await start(t);
      await h.nav(t, NavAction.up);
      await h.nav(t, NavAction.up);
      expect(focusLabel(), 'osk/r0:0');
    });

    testWidgets('the keyboard works like the pad', (t) async {
      final h = await start(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(h.backend.calls, ['type:w']);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(h.backend.calls.last, 'action:backspace');
    });

    testWidgets('release never acts', (t) async {
      final h = await start(t);
      await h.nav(t, NavAction.accept, NavPhase.release);
      await h.nav(t, NavAction.back, NavPhase.release);
      expect(h.backend.calls, isEmpty);
    });
  });

  group('output', () {
    testWidgets(r'types P@ss-w0rd! with the D-pad', (t) async {
      final h = await start(t, h: OskHarness(settings: _showTyped));
      // Shift (Y), then the keys.
      await h.nav(t, NavAction.context);
      await h.type(t, 'P');
      await h.type(t, '?123');
      await h.type(t, '@');
      await h.type(t, 'abc');
      await h.type(t, 's');
      await h.type(t, 's');
      await h.type(t, '?123');
      await h.type(t, '-');
      await h.type(t, 'abc');
      await h.type(t, 'w');
      await h.type(t, '0');
      await h.type(t, 'r');
      await h.type(t, 'd');
      await h.type(t, '?123');
      await h.type(t, '!');
      expect(h.backend.calls, [
        'type:P',
        'type:@',
        'type:s',
        'type:s',
        'type:-',
        'type:w',
        'type:0',
        'type:r',
        'type:d',
        'type:!',
      ]);
      expect(h.backend.typedText, r'P@ss-w0rd!');
      // Only the daemon types; the preview echoes it.
      expect(find.text(r'P@ss-w0rd!'), findsOneWidget);
    });

    testWidgets('backspace, enter, tab are actions; space is text', (t) async {
      final h = await start(t);
      await h.type(t, 'Tab');
      await h.type(t, 'Space');
      await h.type(t, 'Backspace');
      await h.type(t, 'Enter');
      expect(h.backend.calls, [
        'action:tab',
        'type: ',
        'action:backspace',
        'action:enter',
      ]);
    });

    testWidgets('back is backspace, also while held; X is space', (t) async {
      final h = await start(t);
      await h.type(t, 'q');
      await h.nav(t, NavAction.back);
      await h.nav(t, NavAction.back, NavPhase.repeat);
      await h.nav(t, NavAction.back, NavPhase.release);
      await h.nav(t, NavAction.secondary);
      expect(h.backend.calls, [
        'type:q',
        'action:backspace',
        'action:backspace',
        'type: ',
      ]);
      expect(find.text('Typed text appears here'), findsNothing);
    });

    testWidgets('the preview follows backspace', (t) async {
      final h = await start(t, h: OskHarness(settings: _showTyped));
      await h.type(t, 'q');
      await h.type(t, 'w');
      expect(_preview('qw'), findsOneWidget);
      await h.nav(t, NavAction.back);
      expect(_preview('q'), findsOneWidget);
    });

    testWidgets('Done hides and the next opening starts fresh', (t) async {
      final h = await start(t);
      await h.type(t, 'q');
      await h.type(t, '?123');
      expect(find.text('abc'), findsOneWidget);
      await h.type(t, 'Done');
      expect(h.backend.calls.last, 'hide');
      expect(find.text('?123'), findsOneWidget, reason: 'back on letters');
      expect(find.text('Typed text appears here'), findsOneWidget);
      h.backend.setVisible(true);
      await t.pumpAndSettle();
      expect(focusLabel(), 'osk/r1:0');
    });

    testWidgets('a failing backend shows why, and the next key clears it', (
      t,
    ) async {
      final h = await start(t);
      h.backend.failWith = UnsupportedError('keys.type needs session API 0.4');
      await h.type(t, 'q');
      await t.pumpAndSettle();
      expect(find.textContaining('needs session API 0.4'), findsOneWidget);
      h.backend.failWith = null;
      await h.type(t, 'w');
      await t.pumpAndSettle();
      expect(find.textContaining('needs session API 0.4'), findsNothing);
    });
  });

  group('shift and pages', () {
    testWidgets('one-shot shift, then caps lock, then off', (t) async {
      final h = await start(t);
      await h.nav(t, NavAction.context); // once
      await h.type(t, 'Q');
      await h.type(t, 'w'); // used up
      await h.nav(t, NavAction.context);
      await h.nav(t, NavAction.context); // caps
      expect(find.text('Caps'), findsOneWidget);
      await h.type(t, 'E');
      await h.type(t, 'R');
      await h.nav(t, NavAction.context); // off
      await h.type(t, 't');
      expect(h.backend.typedText, 'QwERt');
    });

    testWidgets('the Shift key does the same as context', (t) async {
      final h = await start(t);
      await h.type(t, 'Shift');
      await h.type(t, 'Shift');
      expect(find.text('Caps'), findsOneWidget);
      await h.type(t, 'Caps');
      expect(find.text('Shift'), findsOneWidget);
      expect(h.backend.calls, isEmpty, reason: 'shift types nothing');
    });

    testWidgets('context flips the symbol pages; L1/R1 pick letters/symbols', (
      t,
    ) async {
      final h = await start(t);
      await h.nav(t, NavAction.pageRight);
      expect(find.text('More 1/2'), findsOneWidget);
      await h.nav(t, NavAction.context);
      expect(find.text('More 2/2'), findsOneWidget);
      await h.type(t, '{');
      await h.nav(t, NavAction.pageLeft);
      expect(find.text('?123'), findsOneWidget);
      expect(h.backend.calls, ['type:{']);
    });

    testWidgets('focus stays on the same key when the page changes', (t) async {
      final h = await start(t);
      await h.moveTo(t, '?123');
      expect(focusLabel(), 'osk/bottom:0');
      await h.nav(t, NavAction.accept);
      expect(find.text('abc'), findsOneWidget);
      expect(focusLabel(), 'osk/bottom:0');
      await h.moveTo(t, 'More 1/2');
      await h.nav(t, NavAction.accept);
      expect(focusLabel(), 'osk/r3:0');
      expect(find.text('More 2/2'), findsOneWidget);
    });
  });

  group('privacy: the preview is masked', () {
    testWidgets('dots, the newest character readable for about a second', (
      t,
    ) async {
      final h = await start(t);
      await h.type(t, 'h');
      await h.type(t, 'u');
      await h.type(t, 'n');
      // Right after typing: dots, then the last character.
      expect(find.textContaining('hu'), findsNothing);
      expect(_preview('\u2022\u2022n'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1100));
      expect(_preview('\u2022\u2022\u2022'), findsOneWidget);
      expect(find.text('hun'), findsNothing);
      // The daemon still got the real text.
      expect(h.backend.typedText, 'hun');
    });

    testWidgets('backspace removes a dot; the setting shows the text', (
      t,
    ) async {
      final h = await start(t);
      await h.type(t, 'a');
      await h.type(t, 'b');
      await h.nav(t, NavAction.back);
      await t.pump(const Duration(seconds: 2));
      expect(_preview('\u2022'), findsOneWidget);
      h.settings.value = _showTyped;
      await t.pumpAndSettle();
      expect(_preview('a'), findsOneWidget);
    });

    testWidgets('untypeable characters and keyboard_unavailable show briefly', (
      t,
    ) async {
      final h = await start(t);
      h.backend.untypeable = {'q'};
      await h.type(t, 'q');
      await t.pump(const Duration(milliseconds: 100));
      // Masked: only the count, not the character.
      expect(find.text('1 character(s) cannot be typed'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      expect(find.textContaining('cannot be typed'), findsNothing);

      h.backend.failWith = const ApiException(
        ApiErrorCode.keyboardUnavailable,
        'no virtual keyboard',
      );
      await h.type(t, 'w');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('No keyboard available'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      expect(find.textContaining('No keyboard available'), findsNothing);
    });

    testWidgets('with the setting on, untypeable characters are named', (
      t,
    ) async {
      final h = await start(t, h: OskHarness(settings: _showTyped));
      h.backend.untypeable = {'q'};
      await h.type(t, 'q');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Cannot type: q'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
