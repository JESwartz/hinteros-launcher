import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/ui/settings_screen.dart';

const kUp = LogicalKeyboardKey.arrowUp;
const kDown = LogicalKeyboardKey.arrowDown;
const kLeft = LogicalKeyboardKey.arrowLeft;
const kRight = LogicalKeyboardKey.arrowRight;
const kEnter = LogicalKeyboardKey.enter;
const kEscape = LogicalKeyboardKey.escape;
const kPageUp = LogicalKeyboardKey.pageUp;
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

/// Settings with the list entry (group) of [id] focused: a group id, or a
/// setting id (its group).
Future<void> openSettingsEntry(WidgetTester t, String id) async {
  await openTab(t, 5);
  await press(t, List.filled(settingsGroupIndexOf(id), kDown));
}

/// The id of the region of the pane that shows setting [id].
String settingsRegionOf(String id) {
  final i = settingsSectionIndexOf(id);
  return i == 0 ? 'settings-detail' : 'settings-detail-$i';
}

/// Settings, setting [id], focus moved into its section (the first row; in
/// a group of several, Down walks there through the sections above it).
Future<void> enterSettingsEntry(WidgetTester t, String id) async {
  await openSettingsEntry(t, id);
  await press(t, [kRight]);
  await downToSection(t, id);
}

/// In a group's pane: Down until focus is in the section of setting [id].
Future<void> downToSection(WidgetTester t, String id) async {
  final region = '${settingsRegionOf(id)}/';
  for (var i = 0; i < 40; i++) {
    final label = FocusManager.instance.primaryFocus?.debugLabel ?? '';
    if (label.startsWith(region)) return;
    await press(t, [kDown]);
  }
  fail('no focus in the section of $id');
}

/// The Store tab (index 3).
Future<void> openStore(WidgetTester t) => openTab(t, 3);

/// The Server tab (index 4).
Future<void> openServer(WidgetTester t) => openTab(t, 4);

/// Types [pin] on an open PIN pad (digit keys) and submits it with Enter.
Future<void> enterPin(WidgetTester t, String pin) async {
  for (final c in pin.split('')) {
    await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
  }
  await t.sendKeyEvent(LogicalKeyboardKey.enter);
  await t.pumpAndSettle();
}

/// [finder] inside the section of setting [id] (a group's pane shows
/// several sections).
Finder inSection(String id, Finder finder) => find.descendant(
  of: find.byKey(ValueKey('settings-section-$id')),
  matching: finder,
);
