import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/gamepad.dart';
import 'package:hinteros_launcher/src/installer/ui/text_entry.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/ui/profiles/greeter_screen.dart';

import '../support/harness.dart';

/// A clock the tests move.
class Clock {
  DateTime t = DateTime(2026, 10, 8, 20);
  DateTime now() => t;
}

class Picker {
  Picker(this.t) {
    services = MockSystemServices(now: clock.now);
    box = MockProfileBox(now: clock.now);
    greeter = MockGreeter(services.mockJobs, box: box);
  }

  final WidgetTester t;
  final clock = Clock();
  late final MockSystemServices services;
  late final MockProfileBox box;
  late final MockGreeter greeter;
  final pad = StreamController<PadEvent>.broadcast();

  Future<void> pump() async {
    setView(t);
    addTearDown(pad.close);
    await t.pumpWidget(
      GreeterApp(
        greeter: greeter,
        jobs: services.mockJobs,
        system: services.mockSystem,
        pad: pad.stream,
        now: clock.now,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> press(NavAction a, {bool settle = true}) async {
    pad.add((a, NavPhase.press));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await frames();
    }
  }

  /// A few frames, for screens with a spinner (which never settle).
  Future<void> frames() async {
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  /// The picker's own keyboard, while it is up.
  InProcessKeyboard keyboard() =>
      t.widget<GreeterScreen>(find.byType(GreeterScreen)).console.keyboard!;

  Future<void> typePin(String pin, {bool settle = true}) async {
    for (final c in pin.split('')) {
      await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
    }
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await frames();
    }
  }
}

void main() {
  refreshTests();
  testWidgets('at boot the picker waits for its daemon: Starting..., never '
      '"not connected"; a failure that outlasts the start shows', (t) async {
    final p = Picker(t);
    p.greeter.failLoads = 3;
    setView(t);
    await t.pumpWidget(
      GreeterApp(
        greeter: p.greeter,
        jobs: p.services.mockJobs,
        system: p.services.mockSystem,
        now: p.clock.now,
      ),
    );
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('not connected'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Starting...'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 500));
    }
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Starting...'), findsNothing);
    expect(find.text('Guest'), findsOneWidget);

    // Long after the start: the failure shows, with Try again.
    final late = Picker(t);
    late.greeter.failLoads = 1;
    late.clock.t = late.clock.t.add(greeterStartupGrace);
    await t.pumpWidget(const SizedBox());
    var calls = 0;
    await t.pumpWidget(
      GreeterApp(
        greeter: late.greeter,
        jobs: late.services.mockJobs,
        system: late.services.mockSystem,
        now: () => calls++ == 0 ? p.clock.now() : late.clock.now(),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('not connected'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('the picker lists the profiles, Guest and Add profile; '
      'an unlocked profile opens at once', (t) async {
    final p = Picker(t);
    await p.pump();
    expect(find.text('Who is watching?'), findsOneWidget);
    for (final n in ['James', 'Sam', 'Guest', 'Add profile', 'Admin']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(focusLabel(), 'content/tiles:0');
    await p.press(NavAction.accept, settle: false);
    expect(p.greeter.entered, 'p1');
    expect(find.text('Loading James…'), findsOneWidget);
    expect(find.text('Who is watching?'), findsNothing);
  });

  testWidgets('a locked profile asks for its PIN; wrong PINs back off', (
    t,
  ) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    expect(focusLabel(), 'content/tiles:1');
    await p.press(NavAction.accept);
    expect(find.text("Type Sam's PIN."), findsOneWidget);
    expect(focusLabel(), 'modal-0/pin0:0');

    await p.typePin('1111');
    expect(find.text("That PIN didn't match."), findsOneWidget);
    await p.typePin('1112');
    await p.typePin('1113');
    await p.typePin('1114');
    expect(
      find.text('Too many tries. Try again in 30 seconds.'),
      findsOneWidget,
    );
    // The right PIN does nothing while the lock lasts.
    await p.typePin('1357');
    expect(p.greeter.entered, isNull);

    p.clock.t = p.clock.t.add(const Duration(seconds: 31));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.textContaining('Too many tries'), findsNothing);
    await p.typePin('1357', settle: false);
    expect(p.greeter.entered, 'p3');
  });

  testWidgets('B deletes a digit, then goes back to the picker', (t) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    await p.press(NavAction.accept);
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.pumpAndSettle();
    await p.press(NavAction.back); // deletes the 1
    expect(find.text("Type Sam's PIN."), findsOneWidget);
    await p.press(NavAction.back); // empty: back
    expect(find.text("Type Sam's PIN."), findsNothing);
    expect(p.greeter.log, contains('cancel'));
    expect(focusLabel(), 'content/tiles:1');
  });

  testWidgets('the D-pad presses the keys of the pad', (t) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    await p.press(NavAction.accept);
    // 1, 3, 5, 7 on the pad: 1 (0,0), 3 (0,2), 5 (1,1), 7 (2,0).
    await p.press(NavAction.accept);
    await p.press(NavAction.right);
    await p.press(NavAction.right);
    await p.press(NavAction.accept);
    await p.press(NavAction.down);
    await p.press(NavAction.left);
    await p.press(NavAction.accept);
    await p.press(NavAction.down);
    await p.press(NavAction.left);
    await p.press(NavAction.accept);
    // OK: bottom right.
    await p.press(NavAction.down);
    await p.press(NavAction.right);
    await p.press(NavAction.right);
    expect(focusLabel(), 'modal-0/pin3:2');
    await p.press(NavAction.accept, settle: false);
    expect(p.greeter.entered, 'p3');
  });

  testWidgets('Add profile: form, Getting things ready, then into it', (
    t,
  ) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    await p.press(NavAction.right);
    await p.press(NavAction.right);
    expect(focusLabel(), 'content/tiles:3');
    await p.press(NavAction.accept);
    expect(find.text('Add profile'), findsWidgets);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    // Name, with the picker's own keyboard.
    await p.press(NavAction.accept);
    final screen = t.widget<GreeterScreen>(find.byType(GreeterScreen));
    final kb = screen.console.keyboard!;
    await kb.type('Robin');
    kb.onDone!(kb.text.value);
    await t.pumpAndSettle();
    expect(find.text('Robin'), findsOneWidget);
    await p.press(NavAction.down);
    await p.press(NavAction.accept); // Continue
    expect(find.text('Pick a colour for Robin.'), findsOneWidget);
    await p.press(NavAction.right); // blue
    await p.press(NavAction.accept);
    expect(find.text('Choose a PIN for Robin: 4 to 8 digits.'), findsOneWidget);
    await p.typePin('2580');
    expect(find.text('Type the PIN again.'), findsOneWidget);
    await p.typePin('2581');
    expect(
      find.text("The two PINs didn't match. Choose it again."),
      findsOneWidget,
    );
    await p.typePin('2580');
    await p.typePin('2580');
    expect(find.text('Lock this profile'), findsOneWidget);
    await p.press(NavAction.accept); // lock it
    await p.press(NavAction.down);
    await p.press(NavAction.accept, settle: false); // Create profile
    expect(find.text('Getting things ready'), findsOneWidget);
    expect(
      find.text("Creating Robin's profile... (about a minute)"),
      findsOneWidget,
    );
    final job = p.services.mockJobs.started.single;
    p.services.mockJobs.finish(job.jobId, ok: true);
    await p.frames();
    expect(find.text('Ready'), findsOneWidget);
    await p.press(NavAction.accept, settle: false);
    // The token lets the creator in without the PIN.
    expect(p.greeter.entered, 'p4');
    final robin = p.box.byId('p4')!;
    expect(robin.name, 'Robin');
    expect(robin.locked, isTrue);
    expect(robin.pin, '2580');
  });

  testWidgets('the PIN pad says how a forgotten PIN is removed', (t) async {
    final p = Picker(t);
    await p.pump();
    await p.press(NavAction.right);
    await p.press(NavAction.accept);
    expect(find.text('Forgot your PIN?'), findsOneWidget);
    expect(
      find.textContaining('sudo hinteros-system reset-pin Sam'),
      findsOneWidget,
    );
  });

  testWidgets('a pending switch to a locked profile goes straight to its PIN '
      'pad, never the bare tiles', (t) async {
    final p = Picker(t);
    p.greeter.switchTo = 'p3';
    p.greeter.focus = 'p3';
    setView(t);
    addTearDown(p.pad.close);
    await t.pumpWidget(
      GreeterApp(
        greeter: p.greeter,
        jobs: p.services.mockJobs,
        system: p.services.mockSystem,
        pad: p.pad.stream,
        now: p.clock.now,
      ),
    );
    // Every frame on the way: no tiles.
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 20));
      if (find.text("Type Sam's PIN.").evaluate().isNotEmpty) break;
      expect(find.text('Who is watching?'), findsNothing);
    }
    await t.pumpAndSettle();
    expect(find.text("Type Sam's PIN."), findsOneWidget);
    expect(p.greeter.log.first, 'login:p3');
    await p.typePin('1357', settle: false);
    expect(p.greeter.entered, 'p3');
    expect(find.text('Loading Sam…'), findsOneWidget);
  });

  testWidgets("backing out of the pending switch's PIN pad shows the tiles", (
    t,
  ) async {
    final p = Picker(t);
    p.greeter.switchTo = 'p3';
    await p.pump();
    expect(find.text("Type Sam's PIN."), findsOneWidget);
    await p.press(NavAction.back);
    expect(find.text('Who is watching?'), findsOneWidget);
    expect(p.greeter.log, contains('cancel'));
  });
}

void refreshTests() {
  testWidgets('the tiles follow the public view: a removed profile goes', (
    t,
  ) async {
    final p = Picker(t);
    await p.pump();
    expect(find.text('Sam'), findsOneWidget);
    // Removed meanwhile (its removal job ended after the picker came up).
    p.box.profiles.removeWhere((x) => x.id == 'p3');
    await t.pump(greeterRefreshEvery);
    await t.pumpAndSettle();
    expect(find.text('Sam'), findsNothing);
    expect(find.text('James'), findsOneWidget);
  });
}
