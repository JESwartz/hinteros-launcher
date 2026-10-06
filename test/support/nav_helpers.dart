import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/ui/settings_screen.dart';

const kUp = LogicalKeyboardKey.arrowUp;
const kDown = LogicalKeyboardKey.arrowDown;
const kLeft = LogicalKeyboardKey.arrowLeft;
const kRight = LogicalKeyboardKey.arrowRight;
const kEnter = LogicalKeyboardKey.enter;
const kEscape = LogicalKeyboardKey.escape;
const kPageDown = LogicalKeyboardKey.pageDown;

/// Presses [ks] one by one, settling after each.
Future<void> press(WidgetTester t, List<LogicalKeyboardKey> ks) async {
  for (final k in ks) {
    await t.sendKeyEvent(k);
    await t.pumpAndSettle();
  }
}

/// From Home: the tab bar, [tabIndex] tabs to the right, into the content.
Future<void> openTab(WidgetTester t, int tabIndex) =>
    press(t, [kUp, for (var i = 0; i < tabIndex; i++) kRight, kDown]);

/// Settings with the list entry [id] focused.
Future<void> openSettingsEntry(WidgetTester t, String id) async {
  await openTab(t, 4);
  await press(t, List.filled(settingsEntryIds.indexOf(id), kDown));
}

/// Settings, entry [id], focus moved into its pane.
Future<void> enterSettingsEntry(WidgetTester t, String id) async {
  await openSettingsEntry(t, id);
  await press(t, [kRight]);
}

/// The Store tab (index 3).
Future<void> openStore(WidgetTester t) => openTab(t, 3);
