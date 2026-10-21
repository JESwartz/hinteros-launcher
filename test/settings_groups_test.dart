// Settings in groups: the list order, the stacked sections of each group's
// pane, and deep links to a group and to a setting inside one.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/ui/settings_screen.dart';

import 'support/harness.dart';
import 'support/nav_helpers.dart';

const _groups = <(String, String, List<(String, String)>)>[
  ('profiles', 'Profiles', [('profiles', 'Profiles')]),
  ('updates', 'Updates', [('updates', 'Updates')]),
  ('storage', 'Storage', [('storage', 'Storage')]),
  ('network', 'Network', [('net', 'Network'), ('bt', 'Bluetooth')]),
  (
    'display_sound',
    'Display and sound',
    [
      ('display', 'Display'),
      ('audio', 'Audio'),
      ('screensaver', 'Screen saver'),
    ],
  ),
  (
    'accessibility',
    'Accessibility',
    [
      ('text', 'Text size'),
      ('contrast', 'High contrast'),
      ('focus', 'Focus marker'),
      ('motion', 'Reduce motion'),
      ('osk_text', 'Show typed passwords on the on-screen keyboard'),
    ],
  ),
  (
    'system',
    'System',
    [
      ('time', 'Time zone'),
      ('power', 'Power'),
      ('app_displays', 'Apps open at once'),
      ('ssh', 'Remote access'),
      ('about', 'About'),
    ],
  ),
];

Finder _section(String id) => find.byKey(ValueKey('settings-section-$id'));

void main() {
  test('the groups and their settings, in order', () {
    expect(settingsGroupIds, [for (final g in _groups) g.$1]);
    expect(settingsEntryIds, [
      for (final g in _groups)
        for (final e in g.$3) e.$1,
    ]);
    expect(settingsGroupIndexOf('bt'), 3);
    expect(settingsGroupIndexOf('network'), 3);
    expect(settingsSectionIndexOf('about'), 4);
    expect(settingsSectionIndexOf('updates'), 0);
  });

  testWidgets('the list shows the seven groups in order', (t) async {
    setView(t);
    await Harness().pump(t);
    await openTab(t, 5);
    expect(focusLabel(), 'settings-list/profiles:0');
    for (final g in _groups.skip(1)) {
      await press(t, [kDown]);
      expect(focusLabel(), 'settings-list/${g.$1}:0');
    }
    double y(String text) => t.getTopLeft(find.text(text).first).dy;
    for (var i = 1; i < _groups.length; i++) {
      expect(y(_groups[i].$2), greaterThan(y(_groups[i - 1].$2)));
    }
  });

  testWidgets('each group stacks its settings under their headings', (t) async {
    setView(t);
    await Harness().pump(t);
    await openTab(t, 5);
    for (final (i, g) in _groups.indexed) {
      if (i > 0) await press(t, [kDown]);
      final ids = [for (final e in g.$3) e.$1];
      for (final id in settingsEntryIds) {
        expect(
          _section(id),
          ids.contains(id) ? findsOneWidget : findsNothing,
          reason: '${g.$2}: $id',
        );
      }
      // One under the other, each under its heading.
      for (final (j, e) in g.$3.indexed) {
        if (g.$3.length > 1) {
          final heading = find.text(e.$2).last;
          expect(
            t.getTopLeft(heading).dy,
            lessThan(t.getTopLeft(_section(e.$1)).dy),
            reason: e.$2,
          );
        }
        if (j > 0) {
          expect(
            t.getTopLeft(_section(e.$1)).dy,
            greaterThan(t.getBottomLeft(_section(g.$3[j - 1].$1)).dy),
          );
        }
      }
    }
  });

  testWidgets('the update banner opens Updates', (t) async {
    setView(t);
    final h = Harness(
      services: MockSystemServices(
        iconDir: iconDir(),
        now: fixedNow,
        status: mockBehind(mockOrdinaryUpdate()),
      ),
    );
    await h.pump(t);
    await press(t, [kUp]);
    expect(focusLabel(), 'update-banner/update-banner:0');
    await press(t, [kEnter]);
    expect(focusLabel(), 'settings-list/updates:0');
    expect(_section('updates'), findsOneWidget);
  });

  testWidgets('a deep link to a setting inside a group opens the group with '
      'focus on that section', (t) async {
    setView(t);
    await Harness().pump(t);
    await openSettingsEntry(t, 'accessibility');
    SettingsRegions regions() =>
        t.widget<SettingsScreen>(find.byType(SettingsScreen)).regions;

    regions().select('time');
    await t.pumpAndSettle();
    expect(_section('time'), findsOneWidget);
    expect(focusLabel(), startsWith('settings-detail/'));
    expect(regions().list.model.row, settingsGroupIndexOf('system'));

    // The last section of the group: the pane scrolls to it.
    await press(t, [kLeft, kUp]); // another group
    regions().select('about');
    await t.pumpAndSettle();
    expect(focusLabel(), startsWith('settings-detail-4/'));
    final focused = FocusManager.instance.primaryFocus!.context!;
    final box = focused.findRenderObject()! as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    expect(top, greaterThan(0));
    expect(top + box.size.height, lessThan(1080));
    // Back returns to the list, on System.
    await press(t, [kEscape]);
    expect(focusLabel(), 'settings-list/system:0');
  });
}
