import 'dart:async';

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/evdev_keyboard.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/keyboard_fallback.dart';

import '../support/fake_pads.dart';
import '../support/installer_harness.dart';

/// evdev key codes used below.
const kEnter = 28, kSpace = 57, kShift = 42, kA = 30, k1 = 2, kTab = 15;
const kBackspace = 14, kEsc = 1, kLeft = 105, kCtrl = 29, kCaps = 58;
const kSemicolon = 39, kMinus = 12, kDown = 108, kUp = 103;

List<SoftKey> feed(KeyboardMapper m, List<(int, int)> keys) => [
  for (final (code, value) in keys) ...m.map(1, code, value),
];

void main() {
  group('KeyboardMapper', () {
    test('letters, digits, space; press and release', () {
      final m = KeyboardMapper();
      expect(m.map(1, kA, 1), [
        const SoftKey(LogicalKeyboardKey.keyA, NavPhase.press, character: 'a'),
      ]);
      expect(m.map(1, kA, 0), [
        const SoftKey(
          LogicalKeyboardKey.keyA,
          NavPhase.release,
          character: 'a',
        ),
      ]);
      expect(m.map(1, k1, 1).single.character, '1');
      expect(m.map(1, kSpace, 1).single.character, ' ');
      expect(m.map(0, 0, 0), isEmpty, reason: 'sync events');
    });

    test('shift gives capitals and the US symbols', () {
      final m = KeyboardMapper();
      expect(feed(m, [(kShift, 1), (kA, 1)]).single.character, 'A');
      expect(m.map(1, k1, 1).single.character, '!');
      expect(m.map(1, kSemicolon, 1).single.character, ':');
      expect(m.map(1, kMinus, 1).single.character, '_');
      expect(m.map(1, 3, 1).single.character, '@');
      expect(m.map(1, 11, 1).single.character, ')');
      expect(m.map(1, 41, 1).single.character, '~');
      expect(m.map(1, 43, 1).single.character, '|');
      expect(m.map(1, 53, 1).single.character, '?');
      expect(m.map(1, 40, 1).single.character, '"');
      m.map(1, kShift, 0);
      expect(m.map(1, kA, 0).single.character, 'a', reason: 'shift let go');
      expect(m.map(1, 54, 1), isEmpty, reason: 'right shift is a modifier');
      expect(m.map(1, 16, 1).single.character, 'Q');
    });

    test('caps lock flips letters only; shift flips it back', () {
      final m = KeyboardMapper();
      m.map(1, kCaps, 1);
      m.map(1, kCaps, 0);
      expect(m.map(1, kA, 1).single.character, 'A');
      expect(m.map(1, k1, 1).single.character, '1');
      m.map(1, kShift, 1);
      expect(m.map(1, 31, 1).single.character, 's');
      expect(m.map(1, 2, 1).single.character, '!');
    });

    test('Ctrl takes the text away (a shortcut is not typing)', () {
      final m = KeyboardMapper();
      m.map(1, kCtrl, 1);
      expect(m.map(1, kA, 1).single.character, isNull);
      m.map(1, kCtrl, 0);
      expect(m.map(1, 31, 1).single.character, 's');
    });

    test('arrows, Enter, Backspace, Escape, Tab, Shift+Tab', () {
      final m = KeyboardMapper();
      expect(m.map(1, kEnter, 1).single.key, LogicalKeyboardKey.enter);
      expect(m.map(1, kBackspace, 1).single.key, LogicalKeyboardKey.backspace);
      expect(m.map(1, kEsc, 1).single.key, LogicalKeyboardKey.escape);
      expect(m.map(1, kLeft, 1).single.key, LogicalKeyboardKey.arrowLeft);
      expect(m.map(1, kDown, 1).single.key, LogicalKeyboardKey.arrowDown);
      expect(m.map(1, 59, 1).single.key, LogicalKeyboardKey.f1);
      expect(m.map(1, kTab, 1).single.shift, isFalse);
      m.map(1, kTab, 0);
      m.map(1, kShift, 1);
      final back = m.map(1, kTab, 1).single;
      expect(back.key, LogicalKeyboardKey.tab);
      expect(back.shift, isTrue);
      expect(back.character, isNull);
    });

    test('key repeat (value 2) repeats a held key, nothing else', () {
      final m = KeyboardMapper();
      expect(m.map(1, kDown, 2), isEmpty, reason: 'never saw it go down');
      m.map(1, kDown, 1);
      final r = m.map(1, kDown, 2).single;
      expect(r.phase, NavPhase.repeat);
      expect(r.key, LogicalKeyboardKey.arrowDown);
      m.map(1, kA, 1);
      expect(m.map(1, kA, 2).single.character, 'a');
      expect(m.map(1, kA, 0).single.phase, NavPhase.release);
      expect(m.map(1, kA, 2), isEmpty, reason: 'a repeat after the release');
      expect(m.map(1, kA, 0), isEmpty, reason: 'a second release');
    });

    test('unknown keys and non-key events are ignored', () {
      final m = KeyboardMapper();
      expect(m.map(1, 0x2ff, 1), isEmpty);
      expect(m.map(3, 0, 5), isEmpty);
    });
  });

  group('EvdevKeyboard (synthetic devices)', () {
    late FakePads fs;
    late EvdevKeyboard kb;
    late List<SoftKey> got;

    Future<void> setUp(WidgetTester t) async {
      fs = FakePads()
        ..plug('event3')
        ..plugKeyboard('event4');
      kb = EvdevKeyboard(backend: fs, log: (_) {})..start();
      got = [];
      kb.keys.listen(got.add);
      await t.pump();
    }

    void hot(String name, Future<void> Function(WidgetTester t) body) {
      testWidgets(name, (t) async {
        try {
          await body(t);
        } finally {
          await t.runAsync(() async => kb.dispose());
        }
      });
    }

    void tap(String node, int code) {
      fs.send(node, [frame(1, code, 1), frame(0, 0, 0)]);
      fs.send(node, [frame(1, code, 0), frame(0, 0, 0)]);
    }

    hot('reads keyboards only, never a pad', (t) async {
      await setUp(t);
      expect(kb.devices, {'event4'});
      expect(fs.opened, ['event4']);
      expect(fs.opened, isNot(contains('event3')), reason: 'the pad');
    });

    hot('stop lets go of the devices, start reads them again', (t) async {
      await setUp(t);
      kb.stop();
      expect(kb.devices, isEmpty);
      kb.start();
      expect(kb.devices, {'event4'});
      kb.start(); // twice is harmless
      expect(kb.devices, {'event4'});
    });

    hot('keys come through, typed with shift', (t) async {
      await setUp(t);
      fs.send('event4', [
        frame(1, kShift, 1),
        frame(1, k1, 1),
        frame(1, k1, 0),
        frame(1, kShift, 0),
      ]);
      await t.pump();
      expect(got.map((k) => k.character), ['!', '!']);
    });

    hot('a keyboard plugged in later is picked up, one that goes is let go', (
      t,
    ) async {
      await setUp(t);
      fs.plugKeyboard('event7');
      await t.pump(const Duration(seconds: 2));
      expect(kb.devices, {'event4', 'event7'});
      fs.send('event7', [frame(1, kA, 1)]);
      await t.pump();
      expect(got.single.character, 'a');
      fs.unplug('event7');
      await t.pump(const Duration(seconds: 2));
      expect(kb.devices, {'event4'});
      expect(got.last.phase, NavPhase.release, reason: 'held key let go');
    });

    hot('two nodes of one keyboard do not type twice', (t) async {
      await setUp(t);
      fs.plugKeyboard('event5');
      await t.pump(const Duration(seconds: 2));
      fs.send('event4', [frame(1, kA, 1)]);
      fs.send('event5', [frame(1, kA, 1)]);
      await t.pump();
      expect(got.where((k) => k.phase == NavPhase.press), hasLength(1));
      fs.send('event5', [frame(1, kA, 0)]);
      await t.pump();
      expect(got.where((k) => k.phase == NavPhase.release), isEmpty);
      fs.send('event4', [frame(1, kA, 0)]);
      await t.pump();
      expect(got.where((k) => k.phase == NavPhase.release), hasLength(1));
    });

    hot('a broken device never stops the others', (t) async {
      await setUp(t);
      fs
        ..plugKeyboard('event8')
        ..openThrows.add('event8');
      fs
        ..plugKeyboard('event9')
        ..probeThrows.add('event9');
      await t.pump(const Duration(seconds: 4));
      tap('event4', kA);
      await t.pump();
      expect(got, hasLength(2));
    });
  });

  group('KeyboardFallback', () {
    late StreamController<SoftKey> src;
    late KeyboardFallback fb;
    late List<SoftKey> got;
    late List<String> logs;

    const press = SoftKey(LogicalKeyboardKey.enter, NavPhase.press);

    void make({Duration grace = const Duration(milliseconds: 300)}) {
      src = StreamController<SoftKey>.broadcast();
      logs = [];
      fb = KeyboardFallback(
        source: src.stream,
        grace: grace,
        log: logs.add,
        listenToFlutterKeys: false,
      );
      got = [];
      fb.keys.listen(got.add);
    }

    Future<void> send(WidgetTester t, SoftKey k) async {
      src.add(k);
      await t.pump();
    }

    testWidgets('active while the window has no focus; logs it', (t) async {
      make();
      fb.setWindowFocus(false);
      expect(fb.active, isTrue);
      await send(t, press);
      expect(got, [press]);
      expect(logs.join('\n'), contains('keyboard focus lost'));
      expect(logs.join('\n'), contains('fallback ACTIVE'));
      fb.dispose();
    });

    testWidgets('focus arriving turns it off; losing it turns it on', (
      t,
    ) async {
      make();
      fb.setWindowFocus(false);
      await send(t, press);
      fb.setWindowFocus(true);
      expect(fb.active, isFalse);
      fb.flutterKeyArrived();
      await send(t, press); // the evdev copy of a key Flutter has
      await t.pump(const Duration(seconds: 1));
      expect(got, hasLength(1), reason: 'the second one was a duplicate');
      expect(logs.join('\n'), contains('fallback inactive'));
      fb.setWindowFocus(false);
      await send(t, press);
      expect(got, hasLength(2));
      fb.dispose();
    });

    testWidgets('a Flutter key proves focus: evdev ignored from then on', (
      t,
    ) async {
      make();
      fb.setWindowFocus(false);
      fb.flutterKeyArrived('Enter');
      expect(fb.active, isFalse);
      await send(t, press);
      await t.pump(const Duration(seconds: 1));
      expect(got, isEmpty);
      expect(logs.join('\n'), contains('first Flutter key event (Enter)'));
      fb.dispose();
    });

    testWidgets('a key held when Flutter keys start still gets its release', (
      t,
    ) async {
      make();
      fb.setWindowFocus(false);
      await send(t, press);
      fb.flutterKeyArrived();
      const release = SoftKey(LogicalKeyboardKey.enter, NavPhase.release);
      await send(t, release);
      expect(got, [press, release]);
      await send(t, release);
      expect(got, hasLength(2), reason: 'only the one held key');
      fb.dispose();
    });

    testWidgets('focused and Flutter delivers: the evdev twin is dropped', (
      t,
    ) async {
      make();
      fb.setWindowFocus(true);
      await send(t, press); // evdev first ...
      fb.flutterKeyArrived(); // ... then the compositor's copy
      await t.pump(const Duration(seconds: 1));
      expect(got, isEmpty);
      await send(t, press);
      expect(got, isEmpty);
      fb.dispose();
    });

    testWidgets('focused but Flutter silent: used after the grace period', (
      t,
    ) async {
      make();
      fb.setWindowFocus(true);
      await send(t, press);
      expect(got, isEmpty, reason: 'waiting for the Flutter twin');
      await t.pump(const Duration(milliseconds: 350));
      expect(got, [press]);
      expect(fb.active, isTrue);
      await send(t, press);
      expect(got, hasLength(2), reason: 'no more waiting');
      fb.flutterKeyArrived(); // the compositor starts delivering
      await send(t, press);
      expect(got, hasLength(2));
      fb.dispose();
    });

    testWidgets('losing focus after Flutter keys worked re-enables it', (
      t,
    ) async {
      make();
      fb.setWindowFocus(true);
      fb.flutterKeyArrived();
      fb.setWindowFocus(false);
      await send(t, press);
      expect(got, [press]);
      fb.dispose();
    });
  });

  group('in the installer', () {
    late FakePads fs;
    late EvdevKeyboard reader;
    late KeyboardFallback fb;

    Future<InstallerHarness> start(WidgetTester t, {bool? focused}) async {
      fs = FakePads()..plugKeyboard('event4');
      reader = EvdevKeyboard(backend: fs, log: (_) {})..start();
      fb = KeyboardFallback(
        source: reader.keys,
        log: (_) {},
        grace: const Duration(milliseconds: 100),
      );
      if (focused != null) fb.setWindowFocus(focused);
      final h = InstallerHarness(keyboard: fb);
      await h.pump(t);
      return h;
    }

    Future<void> stop(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      fb.dispose();
      await t.runAsync(reader.dispose);
    }

    Future<void> tap(WidgetTester t, int code, {int? shift}) async {
      if (shift != null) fs.send('event4', [frame(1, shift, 1)]);
      fs.send('event4', [frame(1, code, 1), frame(0, 0, 0)]);
      await t.pump();
      fs.send('event4', [frame(1, code, 0), frame(0, 0, 0)]);
      if (shift != null) fs.send('event4', [frame(1, shift, 0)]);
      await t.pump();
    }

    testWidgets('unfocused: evdev Enter activates Start', (t) async {
      final h = await start(t, focused: false);
      expect(h.flow.step, InstallerStep.welcome);
      await tap(t, kEnter);
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.network);
      // And Backspace goes back, arrows and Tab move.
      await tap(t, kBackspace);
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.welcome);
      await stop(t);
    });

    testWidgets(
      'focus arrives: evdev ignored, Flutter keys used, no doubling',
      (t) async {
        final h = await start(t, focused: false);
        h.flow.go(InstallerStep.options);
        await t.pumpAndSettle();
        final first = h.focus;
        await tap(t, kDown); // unfocused: evdev moves the focus
        await t.pumpAndSettle();
        final second = h.focus;
        expect(second, isNot(first));
        fb.setWindowFocus(true);
        await t.pumpAndSettle();
        // Flutter keys work; the same key seen by evdev too is not doubled.
        fs.send('event4', [frame(1, kUp, 1), frame(0, 0, 0)]);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await t.pumpAndSettle();
        fs.send('event4', [frame(1, kUp, 0), frame(0, 0, 0)]);
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(h.focus, first, reason: 'one row up, not two');
        await stop(t);
      },
    );

    testWidgets('a first Flutter key while GTK said nothing stops evdev', (
      t,
    ) async {
      final h = await start(t); // focus unknown
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.network);
      await tap(t, kEnter);
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.network, reason: 'evdev ignored');
      await stop(t);
    });

    testWidgets('unknown focus and a silent compositor: evdev after grace', (
      t,
    ) async {
      final h = await start(t);
      fs.send('event4', [frame(1, kEnter, 1), frame(0, 0, 0)]);
      await t.pump(const Duration(milliseconds: 150));
      await t.pumpAndSettle();
      fs.send('event4', [frame(1, kEnter, 0), frame(0, 0, 0)]);
      await t.pump();
      expect(h.flow.step, InstallerStep.network);
      await stop(t);
    });

    testWidgets('gaining focus highlights Start (first row focused)', (
      t,
    ) async {
      final h = await start(t, focused: false);
      fb.setWindowFocus(true);
      await t.pumpAndSettle();
      expect(h.focus, 'content/start:0');
      await stop(t);
    });

    testWidgets(
      'typing on the in-app keyboard: text, shift, Backspace, Enter',
      (t) async {
        final h = await start(t, focused: false);
        h.flow.go(InstallerStep.account);
        await t.pumpAndSettle();
        await h.choose(t, 'user');
        final ctl = h.console(t);
        expect(ctl.typing, isTrue);
        await tap(t, kA);
        await tap(t, 48); // b
        await tap(t, k1, shift: kShift); // !
        await tap(t, kSemicolon, shift: kShift); // :
        await tap(t, kMinus, shift: kShift); // _
        await tap(t, kA, shift: kShift); // A
        await tap(t, kSpace);
        expect(ctl.keyboard!.text.value, 'ab!:_A ');
        await tap(t, kBackspace);
        expect(ctl.keyboard!.text.value, 'ab!:_A');
        // Held key: the kernel repeats it.
        fs.send('event4', [frame(1, kA, 1), frame(1, kA, 2), frame(1, kA, 2)]);
        await t.pump();
        fs.send('event4', [frame(1, kA, 0)]);
        await t.pump();
        expect(ctl.keyboard!.text.value, 'ab!:_Aaaa');
        await tap(t, kEnter);
        await t.pumpAndSettle();
        expect(ctl.typing, isFalse);
        expect(h.flow.username, 'ab!:_Aaaa');
        await stop(t);
      },
    );

    testWidgets('Escape cancels the in-app keyboard', (t) async {
      final h = await start(t, focused: false);
      h.flow.go(InstallerStep.account);
      await t.pumpAndSettle();
      await h.choose(t, 'user');
      await tap(t, kA);
      await tap(t, kEsc);
      await t.pumpAndSettle();
      expect(h.console(t).typing, isFalse);
      expect(h.flow.username, isEmpty);
      await stop(t);
    });

    testWidgets('no doubling while typing once focus arrived', (t) async {
      final h = await start(t, focused: false);
      h.flow.go(InstallerStep.account);
      await t.pumpAndSettle();
      await h.choose(t, 'user');
      fb.setWindowFocus(true);
      await t.pumpAndSettle();
      fs.send('event4', [frame(1, kA, 1)]);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      fs.send('event4', [frame(1, kA, 0)]);
      await t.pump(const Duration(seconds: 1));
      expect(h.console(t).keyboard!.text.value, 'a');
      await stop(t);
    });
  });
}
