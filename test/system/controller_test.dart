// Settings > Controller (session API 0.20): buttons set by pressing them
// (`input.capture`; a button another action has swaps), the pointer (speed
// with left and right, swap sticks, the click buttons, which swap), the keys
// of keyboard apps (the key picker) and per app, and the resets.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/system/controller.dart';
import 'package:hinteros_launcher/src/system/daemon_controller.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/mock_controller.dart';
import 'package:hinteros_launcher/src/ui/system/controller_sections.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Down (or up) until the item [key] of the focused region has focus.
Future<void> moveTo(WidgetTester t, String key, {bool up = false}) async {
  for (var i = 0; i < 40; i++) {
    if ((focusLabel() ?? '').endsWith('/$key:0')) return;
    await press(t, [up ? kUp : kDown]);
  }
  fail('no focus on $key (at ${focusLabel()})');
}

/// The text on the right of the row [key] in the section of setting [id].
String rowValue(WidgetTester t, String id, String title) {
  final row = find.ancestor(
    of: inSection(id, find.text(title)),
    matching: find.byType(Row),
  );
  final texts = find.descendant(of: row.first, matching: find.byType(Text));
  return t.widget<Text>(texts.last).data!;
}

void main() {
  late ControllerState s;
  setUp(() async => s = await MockController().get());

  group('model', () {
    test('a button another action has: the two swap', () {
      expect(s.withButton('accept', 'b').general, {'accept': 'b', 'back': 'a'});
      expect(s.withButton('menu', 'x').general, {
        'menu': 'x',
        'secondary': 'menu',
      });
    });

    test('only changes are stored; the default again stores nothing', () {
      expect(s.withButton('accept', 'a').general, isEmpty);
      expect(s.withSpeed(100).pointer.isEmpty, isTrue);
      expect(s.withSpeed(1000).pointer.speed, 400);
      expect(s.withKey('back', 'escape').keyboard, isEmpty);
      expect(s.withKey('context', 'none').keyboard, isEmpty);
      expect(s.withKey('back', 'backspace').keyboard, {'back': 'backspace'});
    });

    test('the click buttons swap', () {
      final p = s.withClick(left: true, button: 'lt').pointer;
      expect((p.leftClick, p.rightClick), ('lt', 'rt'));
      final q = s.withClick(left: false, button: 'a').pointer;
      expect((q.leftClick, q.rightClick), (null, 'a'));
    });

    test("an app's keys: defaults, shared, the app's own, then per app", () {
      expect(s.keyOf('page_left', 'firefox'), 'alt+left');
      expect(s.keyOf('page_left'), 'none');
      final per = s.withKey('page_left', 'alt+left', appId: 'firefox');
      expect(per.apps, isEmpty);
      final up = s.withKey('up', 'w', appId: 'firefox');
      expect(up.apps, {
        'firefox': {'up': 'w'},
      });
      expect(up.keyboard, isEmpty);
    });

    test('labels', () {
      expect(keyLabel('alt+left'), 'Alt+Left');
      expect(keyLabel('ctrl+shift+t'), 'Ctrl+Shift+T');
      expect(keyLabel('page_up'), 'Page up');
      expect(keyLabel('f11'), 'F11');
      expect(keyLabel('none'), 'None');
      expect(buttonLabel('lb'), 'LB');
      expect(buttonLabel('view'), 'View');
      expect(actionLabel('trigger_left'), 'Left trigger');
      expect(actionLabel('page_right'), 'Page right');
      expect(keyActionTitle(s, 'accept'), 'A (Accept)');
      expect(keyActionTitle(s, 'up'), 'Up');
    });

    test('the wire mock refuses two actions on one button', () async {
      final m = MockInputSettings(emit: (_, _) {});
      expect(
        () => m.call('input.settings.set', {
          'settings': {
            'general': {'accept': 'b'},
          },
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.invalidParams)
              .having((e) => e.data, 'data', {
                'field': 'settings.general',
                'reason': 'not_bijective',
              }),
        ),
      );
    });
  });

  group('Settings > Controller', () {
    late Harness h;
    MockController ctl() => h.services.mockController;

    Future<void> open(WidgetTester t, String id) async {
      setView(t);
      h = Harness();
      await h.pump(t);
      await enterSettingsEntry(t, id);
    }

    testWidgets('a button: press the new one; the other action swaps', (
      t,
    ) async {
      await open(t, 'buttons');
      expect(focusLabel(), 'settings-detail/b-accept:0');
      expect(rowValue(t, 'buttons', 'Accept'), 'A');
      await press(t, [kEnter]);
      expect(find.text('Press a button'), findsOneWidget);
      expect(ctl().capturing, isTrue);
      ctl().press('b');
      await t.pumpAndSettle();
      expect(find.text('Press a button'), findsNothing);
      expect(ctl().stored.general, {'accept': 'b', 'back': 'a'});
      expect(rowValue(t, 'buttons', 'Accept'), 'B');
      expect(rowValue(t, 'buttons', 'Back'), 'A');
      // The keyboard apps rows follow.
      expect(
        inSection('keyboard_keys', find.text('B (Accept)')),
        findsOneWidget,
      );
      expect(focusLabel(), 'settings-detail/b-accept:0');
    });

    testWidgets('a direction, Guide or Cancel changes nothing', (t) async {
      await open(t, 'buttons');
      await press(t, [kEnter]);
      ctl().press('up');
      await t.pumpAndSettle();
      expect(find.text('Press a button'), findsNothing);
      await press(t, [kEnter]);
      ctl().press(null);
      await t.pumpAndSettle();
      expect(find.text('Press a button'), findsNothing);
      // Cancel (a keyboard; the pad's presses go to the capture).
      await press(t, [kEnter]);
      await press(t, [kEnter]);
      expect(find.text('Press a button'), findsNothing);
      expect(ctl().input.log, isEmpty);
      expect(rowValue(t, 'buttons', 'Accept'), 'A');
    });

    testWidgets('reset gives back the defaults', (t) async {
      await open(t, 'buttons');
      await ctl().set(s.withButton('accept', 'x'));
      await t.pumpAndSettle();
      expect(rowValue(t, 'buttons', 'Accept'), 'X');
      await moveTo(t, 'reset');
      await press(t, [kEnter]);
      expect(ctl().stored.general, isEmpty);
      expect(rowValue(t, 'buttons', 'Accept'), 'A');
      expect(rowValue(t, 'buttons', 'Secondary'), 'X');
    });

    testWidgets('pointer speed: left and right in steps', (t) async {
      await open(t, 'pointer');
      expect(focusLabel(), 'settings-detail-1/speed:0');
      expect(inSection('pointer', find.text('100%')), findsOneWidget);
      await press(t, [kRight, kRight]);
      expect(ctl().stored.pointer.speed, 150);
      expect(inSection('pointer', find.text('150%')), findsOneWidget);
      await press(t, [kLeft, kLeft, kLeft]);
      expect(ctl().stored.pointer.speed, 75);
      expect(inSection('pointer', find.text('75%')), findsOneWidget);
      // Focus stayed on the row.
      expect(focusLabel(), 'settings-detail-1/speed:0');
    });

    testWidgets('swap sticks; a click on the other click button swaps', (
      t,
    ) async {
      await open(t, 'pointer');
      await moveTo(t, 'swap');
      await press(t, [kEnter]);
      expect(ctl().stored.pointer.swapSticks, isTrue);
      await moveTo(t, 'left_click');
      expect(rowValue(t, 'pointer', 'Left click'), 'RT');
      await press(t, [kEnter]);
      ctl().press('lt');
      await t.pumpAndSettle();
      final p = ctl().stored.pointer;
      expect((p.leftClick, p.rightClick), ('lt', 'rt'));
      expect(rowValue(t, 'pointer', 'Left click'), 'LT');
      expect(rowValue(t, 'pointer', 'Right click'), 'RT');
      await moveTo(t, 'reset');
      await press(t, [kEnter]);
      expect(ctl().stored.pointer.isEmpty, isTrue);
      expect(rowValue(t, 'pointer', 'Left click'), 'RT');
    });

    testWidgets('the key picker: modifiers, a key, None', (t) async {
      await open(t, 'keyboard_keys');
      expect(focusLabel(), 'settings-detail-2/k-up:0');
      await moveTo(t, 'k-back');
      expect(rowValue(t, 'keyboard_keys', 'B (Back)'), 'Escape');
      await press(t, [kEnter]);
      // Ctrl, Alt, Shift, Meta, then None, then the keys (a, b, ...); focus
      // starts on the current key (Escape).
      expect(focusLabel(), endsWith('/k6:1'));
      await press(t, List.filled(8, kUp));
      expect(focusLabel(), endsWith('/mods:1'));
      await press(t, [kEnter]);
      await press(t, [kDown, kDown]);
      // The column stays: Alt is over b.
      expect(focusLabel(), endsWith('/k0:1'));
      await press(t, [kEnter]);
      expect(ctl().stored.keyboard, {'back': 'alt+b'});
      expect(rowValue(t, 'keyboard_keys', 'B (Back)'), 'Alt+B');
      // Back in the picker changes nothing.
      await press(t, [kEnter, kEscape]);
      expect(ctl().stored.keyboard, {'back': 'alt+b'});
      // None.
      await moveTo(t, 'k-accept', up: true);
      await press(t, [kEnter]);
      expect(focusLabel(), endsWith('/k6:0'));
      await press(t, List.filled(7, kUp));
      expect(focusLabel(), endsWith('/none:0'));
      await press(t, [kEnter]);
      expect(ctl().stored.keyboard, {'back': 'alt+b', 'accept': 'none'});
      expect(rowValue(t, 'keyboard_keys', 'A (Accept)'), 'None');
      await moveTo(t, 'reset');
      await press(t, [kEnter]);
      expect(ctl().stored.keyboard, isEmpty);
    });

    testWidgets('an app: its keys now; a change is for it only; reset', (
      t,
    ) async {
      await open(t, 'app_keys');
      expect(focusLabel(), 'settings-detail-3/app-firefox:0');
      await press(t, [kEnter]);
      expect(find.text('Firefox'), findsWidgets);
      Finder value(String title, String v) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Row)),
        matching: find.text(v),
      );
      expect(value('LB (Page left)', 'Alt+Left'), findsWidgets);
      expect(focusLabel(), endsWith('/k-up:0'));
      await press(t, [kEnter, ...List.filled(8, kUp), kEnter]);
      expect(ctl().stored.apps, {
        'firefox': {'up': 'none'},
      });
      expect(ctl().stored.keyboard, isEmpty);
      expect(value('Up', 'None'), findsWidgets);
      await moveTo(t, 'reset');
      await press(t, [kEnter]);
      expect(ctl().stored.apps, isEmpty);
      expect(value('Up', 'Up'), findsWidgets);
      await moveTo(t, 'done');
      await press(t, [kEnter]);
      expect(focusLabel(), 'settings-detail-3/app-firefox:0');
      // The shared section did not change.
      expect(rowValue(t, 'keyboard_keys', 'Up'), 'Up');
    });
  });

  test('a save keeps what a newer daemon stored', () async {
    final mock = _NewerInput();
    await mock.waitConnected();
    addTearDown(mock.close);
    final c = DaemonController(mock);
    final got = await c.get();
    expect(got.stored.pointer.speed, 150);
    final st = got.stored;
    await c.set(
      StoredController(
        general: const {'accept': 'b', 'back': 'a'},
        keyboard: st.keyboard,
        apps: st.apps,
        pointer: const PointerPrefs(speed: 200),
      ),
    );
    expect(mock.sent, {
      'general': {'accept': 'b', 'back': 'a', 'hold': 2},
      'apps': {
        'firefox': {'up': 'w', 'hold': 2},
        'kodi': 'future',
      },
      'pointer': {'speed': 200, 'acceleration': 3},
      'rumble': {'strength': 50},
    });
  });

  testWidgets('over the daemon: capture, swap, stored', (t) async {
    setView(t);
    final mock = MockDaemon(apps: appsWithIcons(), games: gamesWithArt());
    final h = Harness(mock: mock, realServices: daemonSystemServices(mock));
    await h.pump(t);
    await enterSettingsEntry(t, 'buttons');
    await moveTo(t, 'b-page_left');
    await press(t, [kEnter]);
    expect(mock.input.capturing, isTrue);
    mock.input.press('rb');
    await t.pumpAndSettle();
    expect(mock.input.settings.general, {
      'page_left': 'rb',
      'page_right': 'lb',
    });
    expect(rowValue(t, 'buttons', 'Page left'), 'RB');
    expect(
      controllerStateFrom(mock.input.state()).buttonMap['page_right'],
      'lb',
    );
  });
}

/// A newer daemon: a stored form with a part, a pointer field and values
/// this launcher does not know. Remembers the form of the last save.
class _NewerInput extends MockDaemon {
  Map<String, dynamic>? sent;

  @override
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (method == 'input.settings.set') {
      sent = (params['settings'] as Map).cast<String, dynamic>();
      return input.state().toJson();
    }
    final r = await super.rpc(method, params);
    if (method != 'input.settings.get') return r;
    return {
      ...r,
      'settings': {
        'general': {'hold': 2},
        'apps': {
          'firefox': {'up': 'w', 'hold': 2},
          'kodi': 'future',
        },
        'pointer': {'speed': 150, 'acceleration': 3},
        'rumble': {'strength': 50},
      },
    };
  }
}
