import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart'
    show mockDisks;
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/ui/steps.dart' show eraseHold;

import '../support/fake_pads.dart';
import '../support/harness.dart' show pumpFor;
import '../support/installer_harness.dart';

/// The installer driven by a physical keyboard, and by a stick, nothing else.
void main() {
  const keyFor = {
    NavAction.up: LogicalKeyboardKey.arrowUp,
    NavAction.down: LogicalKeyboardKey.arrowDown,
    NavAction.left: LogicalKeyboardKey.arrowLeft,
    NavAction.right: LogicalKeyboardKey.arrowRight,
    NavAction.accept: LogicalKeyboardKey.enter, // A
    NavAction.back: LogicalKeyboardKey.backspace, // B
  };

  Future<void> sendKey(WidgetTester t, LogicalKeyboardKey k) async {
    await t.sendKeyEvent(k);
    await t.pump();
  }

  /// Types [s] on the physical keyboard (a key id is the character code for
  /// lowercase letters, digits, space and minus).
  Future<void> typeKeys(WidgetTester t, String s) async {
    for (final c in s.split('')) {
      final key = LogicalKeyboardKey.findKeyByKeyId(c.codeUnitAt(0))!;
      await t.sendKeyEvent(key, character: c);
    }
    await t.pump();
  }

  InstallerHarness keyboardHarness() => InstallerHarness(
    driver: (t, a) => sendKey(t, keyFor[a] ?? (throw ArgumentError('$a'))),
  );

  group('keyboard in the installer', () {
    testWidgets('arrows move, Enter accepts, Backspace and Escape go back', (
      t,
    ) async {
      final h = keyboardHarness();
      await h.pump(t);
      expect(h.focus, 'content/start:0');
      await sendKey(t, LogicalKeyboardKey.enter);
      expect(h.flow.step, InstallerStep.network);
      await sendKey(t, LogicalKeyboardKey.backspace);
      expect(h.flow.step, InstallerStep.welcome);
      await sendKey(t, LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      await sendKey(t, LogicalKeyboardKey.escape);
      expect(h.flow.step, InstallerStep.welcome);
      await sendKey(t, LogicalKeyboardKey.backspace);
      expect(h.flow.step, InstallerStep.welcome, reason: 'nowhere to go');
    });

    testWidgets('Tab and Shift+Tab move the focus', (t) async {
      final h = keyboardHarness();
      await h.start(t);
      h.flow.go(InstallerStep.options);
      await t.pumpAndSettle();
      final first = h.focus;
      await sendKey(t, LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      final second = h.focus;
      expect(second, isNot(first));
      await sendKey(t, LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(h.focus, isNot(second));
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await sendKey(t, LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(h.focus, second);
    });

    testWidgets(
      'in the text entry: letters type, Backspace deletes, Enter submits, '
      'Escape cancels',
      (t) async {
        final h = keyboardHarness();
        await h.start(t);
        h.flow.chooseDisk(mockDisks().first);
        h.flow.go(InstallerStep.account);
        await t.pumpAndSettle();
        await h.choose(t, 'user');
        expect(h.console(t).typing, isTrue);

        // X and Y are letters here, not buttons.
        await typeKeys(t, 'jxyam');
        final kb = h.console(t).keyboard!;
        expect(kb.text.value, 'jxyam');
        await sendKey(t, LogicalKeyboardKey.backspace);
        await sendKey(t, LogicalKeyboardKey.backspace);
        expect(kb.text.value, 'jxy');
        expect(h.console(t).typing, isTrue, reason: 'Backspace is not Back');
        await sendKey(t, LogicalKeyboardKey.backspace);
        await sendKey(t, LogicalKeyboardKey.backspace);
        await typeKeys(t, 'ames');
        await sendKey(t, LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(h.console(t).typing, isFalse);
        expect(h.flow.username, 'james');

        // Escape throws the edit away and does not leave the screen.
        await h.choose(t, 'user');
        expect(h.console(t).keyboard!.text.value, 'james');
        await typeKeys(t, 'zzz');
        await sendKey(t, LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(h.console(t).typing, isFalse);
        expect(h.flow.username, 'james');
        expect(h.flow.step, InstallerStep.account);

        // Outside the field Backspace is Back again.
        await sendKey(t, LogicalKeyboardKey.backspace);
        await t.pumpAndSettle();
        expect(h.flow.step, isNot(InstallerStep.account));
      },
    );

    testWidgets('the whole install with the keyboard alone', (t) async {
      final h = keyboardHarness();
      await _walk(
        t,
        h,
        typeText: (t, h, s) async {
          await typeKeys(t, s);
          await sendKey(t, LogicalKeyboardKey.enter);
          await t.pumpAndSettle();
        },
        typed: (s) => s,
        holdAccept: (t, h) async {
          await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
          await pumpFor(t, eraseHold + const Duration(milliseconds: 100));
          await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
          await t.pumpAndSettle();
        },
      );
    });
  });

  group('stick in the installer', () {
    testWidgets('the whole install with the stick and buttons alone', (
      t,
    ) async {
      final rig = PadRig();
      try {
        final h = InstallerHarness(
          padStream: rig.pad.events,
          driver: (t, a) => rig.press(t, a),
        );
        await _walk(
          t,
          h,
          typeText: (t, h, s) async {
            // The on-screen keyboard starts on Q: A types it, Menu is Done.
            for (final _ in s.split('')) {
              await h.accept(t);
            }
            await h.press(t, NavAction.menu);
          },
          typed: (s) => 'q' * s.length,
          holdAccept: (t, h) async {
            await rig.hold(t, NavAction.accept, eraseHold);
            await t.pumpAndSettle();
          },
        );
      } finally {
        await rig.dispose(t);
      }
    });

    testWidgets('a held stick keeps moving the focus, at the daemon\'s pace', (
      t,
    ) async {
      final rig = PadRig();
      try {
        final h = InstallerHarness(
          padStream: rig.pad.events,
          driver: (t, a) => rig.press(t, a),
        );
        await h.start(t);
        await h.choose(t, 'actions', 1); // Continue without internet
        expect(h.flow.step, InstallerStep.disk);
        await t.pumpAndSettle();
        expect(h.focus, startsWith('content/d'));
        final start = h.focus;
        rig.deflect(NavAction.down);
        await t.pump();
        final one = h.focus;
        expect(one, isNot(start), reason: 'the press moved once');
        await t.pump(const Duration(milliseconds: 399));
        expect(h.focus, one, reason: 'nothing before 400 ms');
        await t.pump(const Duration(milliseconds: 1));
        final two = h.focus;
        expect(two, isNot(one));
        await t.pump(const Duration(milliseconds: 120));
        expect(h.focus, isNot(two), reason: 'then every 120 ms');
        rig.center();
        await t.pump();
        final stopped = h.focus;
        await t.pump(const Duration(seconds: 1));
        expect(h.focus, stopped);
      } finally {
        await rig.dispose(t);
      }
    });
  });
}

/// Welcome to the restart, using only [InstallerHarness.press] and
/// [typeText] for the three fields. [typed] says what a typed string comes
/// out as (the stick can only press the key it starts on).
Future<void> _walk(
  WidgetTester t,
  InstallerHarness h, {
  required Future<void> Function(WidgetTester, InstallerHarness, String)
  typeText,
  required String Function(String) typed,
  required Future<void> Function(WidgetTester, InstallerHarness) holdAccept,
}) async {
  await h.pump(t);
  await h.choose(t, 'start');
  expect(h.flow.step, InstallerStep.network);
  await h.choose(t, 'actions', 1); // Continue without internet
  expect(h.flow.step, InstallerStep.disk);
  await h.choose(t, 'd0');
  await h.choose(t, 'actions', 1);
  expect(h.flow.step, InstallerStep.account);

  await h.choose(t, 'user');
  await typeText(t, h, 'james');
  await h.choose(t, 'pw');
  await typeText(t, h, 'long-password');
  await h.choose(t, 'pw2');
  await typeText(t, h, 'long-password');
  expect(h.flow.username, typed('james'));
  expect(h.flow.password, typed('long-password'));
  await h.choose(t, 'actions');
  expect(h.flow.step, InstallerStep.options);

  await h.choose(t, 'ssh');
  expect(h.flow.ssh, isTrue);
  await h.choose(t, 'actions');
  expect(h.flow.step, InstallerStep.apps);
  await h.choose(t, 'continue');
  expect(h.flow.step, InstallerStep.summary);
  await h.moveTo(t, 'actions', 1);
  await holdAccept(t, h); // Erase and install

  expect(h.flow.step, InstallerStep.done);
  final plan = h.backend.plans.last;
  expect(plan['admin'], {
    'user': typed('james'),
    'password': typed('long-password'),
  });
  expect(plan['ssh'], {'enable': true});
  expect(h.backend.rebooted, isFalse);
  await h.accept(t); // Restart now
  expect(h.backend.rebooted, isTrue);
}
