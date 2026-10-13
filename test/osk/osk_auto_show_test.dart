// The launcher's own text fields open the on-screen keyboard when they gain
// focus and close it when focus leaves or the text is submitted.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Future<Harness> _passwordDialog(WidgetTester t) async {
  setView(t);
  final h = Harness();
  await h.pump(t);
  await enterSettingsEntry(t, 'net');
  // wifi, scan, then Hinter-Home, 5G, Neighbour Net (needs a password).
  await press(t, [kDown, kDown, kDown, kDown, kEnter]);
  expect(find.text('Password for Neighbour Net'), findsOneWidget);
  return h;
}

void main() {
  testWidgets('the keyboard opens with the dialog and the hint is gone', (
    t,
  ) async {
    final h = await _passwordDialog(t);
    expect(h.mock.oskVisible, isTrue);
    expect(find.textContaining('Hold Guide'), findsNothing);
  });

  testWidgets('moving off the field hides it, back onto it shows it', (
    t,
  ) async {
    final h = await _passwordDialog(t);
    await press(t, [kDown]); // "Show what I type"
    expect(h.mock.oskVisible, isFalse);
    await press(t, [kUp]);
    expect(h.mock.oskVisible, isTrue);
    await press(t, [kDown, kDown]); // buttons
    expect(h.mock.oskVisible, isFalse);
  });

  testWidgets('submitting hides it; a refused password brings it back', (
    t,
  ) async {
    final h = await _passwordDialog(t);
    await t.enterText(find.byType(TextField), 'nope');
    await press(t, [kEnter]); // Enter on the field submits
    expect(find.textContaining('Wrong password. Try again.'), findsOneWidget);
    expect(h.mock.oskVisible, isTrue, reason: 'back for the retry');
    await t.enterText(find.byType(TextField), 'wifi-pass');
    await press(t, [kEnter]);
    expect(find.text('Password for Neighbour Net'), findsNothing);
    expect(h.mock.oskVisible, isFalse);
  });

  testWidgets('cancelling the dialog hides it', (t) async {
    final h = await _passwordDialog(t);
    expect(h.mock.oskVisible, isTrue);
    await press(t, [kEscape]);
    expect(find.text('Password for Neighbour Net'), findsNothing);
    expect(h.mock.oskVisible, isFalse);
  });

  testWidgets('every text entry does it, the admin password too', (t) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    await enterSettingsEntry(t, 'ssh');
    await press(t, [kEnter]);
    expect(find.text('Admin password'), findsOneWidget);
    expect(h.mock.oskVisible, isTrue);
    await press(t, [kEscape]);
    expect(h.mock.oskVisible, isFalse);
  });

  testWidgets('a disabled keyboard (2005) does not break the field', (t) async {
    setView(t);
    final h = Harness();
    h.mock.oskEnabled = false;
    await h.pump(t);
    await enterSettingsEntry(t, 'net');
    await press(t, [kDown, kDown, kDown, kDown, kEnter]);
    expect(find.text('Password for Neighbour Net'), findsOneWidget);
    expect(h.mock.oskVisible, isFalse);
    await t.enterText(find.byType(TextField), 'wifi-pass');
    await press(t, [kEnter]);
    expect(find.text('Password for Neighbour Net'), findsNothing);
  });

  group('what the keyboard types reaches the field', () {
    // The keyboard sends keys.type (text) and keys.action (Backspace, Enter)
    // to the compositor, which delivers them to the focused launcher window
    // as key events and, for text, through the input method. Here: text
    // through the text input channel (what GTK's input method does with a
    // key), Backspace and Enter as key events.
    testWidgets('text, Backspace and Enter', (t) async {
      final h = await _passwordDialog(t);
      final field = find.byType(TextField);
      await t.enterText(field, 'wifi-pasz');
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pump();
      expect(t.widget<TextField>(field).controller!.text, 'wifi-pas');
      await t.enterText(field, 'wifi-pass');
      await press(t, [kEnter]);
      expect(find.text('Password for Neighbour Net'), findsNothing);
      expect(h.services.mockNetwork.log.last, 'connect:Neighbour Net');
    });

    testWidgets('typing Y or X into the field is text, not a button', (
      t,
    ) async {
      await _passwordDialog(t);
      final field = find.byType(TextField);
      await t.enterText(field, 'xyxy');
      expect(t.widget<TextField>(field).controller!.text, 'xyxy');
      expect(find.text('Password for Neighbour Net'), findsOneWidget);
    });
  });
}
