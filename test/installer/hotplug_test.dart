import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/gamepad.dart';

import '../support/fake_pads.dart';

/// Adding or removing any other input device never affects a pad that
/// already works (a USB keyboard plugged in after the controller).
void main() {
  late FakePads fs;
  late EvdevPad pad;
  late List<PadEvent> got;
  late List<String> logs;

  Future<void> setUp(WidgetTester t, {String padNode = 'event3'}) async {
    fs = FakePads()..plug(padNode);
    logs = [];
    pad = EvdevPad(backend: fs, log: logs.add)..start();
    got = [];
    pad.events.listen(got.add);
    await t.pump();
  }

  Future<void> pressA(WidgetTester t, String node) async {
    got.clear();
    fs.send(node, [frame(1, 0x130, 1), frame(0, 0, 0)]);
    await t.pump();
    expect(got, [(NavAction.accept, NavPhase.press)], reason: 'pad on $node');
    fs.send(node, [frame(1, 0x130, 0), frame(0, 0, 0)]);
    await t.pump();
  }

  const scan = Duration(seconds: 2);

  /// A widget test (fake time) that stops the reader before the framework
  /// checks for pending timers.
  void hot(String name, Future<void> Function(WidgetTester t) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.runAsync(() async => pad.dispose());
      }
    });
  }

  hot('keyboards of every kind arriving leave the pad working', (t) async {
    await setUp(t);
    await pressA(t, 'event3');

    fs.plugOther('event4'); // plain keyboard: EV_KEY only
    fs.plugLookalike('event5'); // keyboard/mouse with EV_KEY + EV_ABS
    fs
      ..plugOther('event6')
      ..probeThrows.add('event6'); // sysfs read fails
    fs
      ..plug('event7')
      ..openThrows.add('event7'); // looks like a pad, open is refused
    fs
      ..plug('event8')
      ..streamFails.add('event8'); // looks like a pad, first read fails
    await t.pump(scan);
    await t.pump(scan);
    expect(pad.devices, contains('event3'));
    expect(pad.devices, isNot(contains('event4')));
    expect(pad.devices, isNot(contains('event5')));
    expect(pad.devices, isNot(contains('event6')));
    expect(fs.opened, isNot(contains('event5')), reason: 'lookalike unread');
    await pressA(t, 'event3');

    // The pad keeps working through many more rescans, and its stick too.
    await t.pump(scan * 5);
    expect(pad.devices, contains('event3'));
    got.clear();
    fs.send('event3', [frame(3, 0x10, -1)]);
    await t.pump();
    expect(got, [(NavAction.left, NavPhase.press)]);
    fs.send('event3', [frame(3, 0x10, 0)]);
    await t.pump();
  });

  hot('a held direction survives a keyboard plugged in meanwhile', (t) async {
    await setUp(t);
    fs.send('event3', [frame(3, 0x11, 1)]);
    await t.pump(const Duration(milliseconds: 400));
    expect(got.last, (NavAction.down, NavPhase.repeat));
    fs.plugOther('event4');
    fs.plugLookalike('event9');
    await t.pump(scan);
    got.clear();
    await t.pump(const Duration(milliseconds: 240));
    expect(got, everyElement((NavAction.down, NavPhase.repeat)));
    expect(got, isNotEmpty, reason: 'still repeating');
    fs.send('event3', [frame(3, 0x11, 0)]);
    await t.pump();
    expect(got.last, (NavAction.down, NavPhase.release));
  });

  hot('the listing failing for one scan keeps the open pad', (t) async {
    await setUp(t);
    fs.listFails = true;
    await t.pump(scan * 2);
    expect(pad.devices, {'event3'});
    fs.listFails = false;
    await t.pump(scan);
    await pressA(t, 'event3');
  });

  hot('removing a keyboard does not matter either', (t) async {
    await setUp(t);
    fs.plugOther('event4');
    await t.pump(scan);
    fs.unplug('event4', withError: true);
    await t.pump(scan);
    await pressA(t, 'event3');
  });

  hot('the pad is unplugged and replugged under another eventN', (t) async {
    await setUp(t, padNode: 'event3');
    await pressA(t, 'event3');
    fs.plugOther('event4'); // the keyboard

    fs.unplug('event3', withError: true);
    await t.pump();
    expect(pad.devices, isEmpty);
    fs.plug('event5'); // back, with a new number
    await t.pump(scan);
    expect(pad.devices, {'event5'});
    await pressA(t, 'event5');

    // And again, this time with the old node disappearing silently while a
    // new one appears: only the new one is read.
    fs.vanish('event5');
    fs.plug('event2');
    await t.pump(scan);
    expect(pad.devices, {'event2'});
    await pressA(t, 'event2');
  });

  hot('a node reused by a keyboard drops the stale pad cleanly', (t) async {
    await setUp(t, padNode: 'event3');
    fs.send('event3', [frame(3, 0x10, 1)]);
    await t.pump();
    expect(got.last, (NavAction.right, NavPhase.press));
    fs.vanish('event3'); // pad gone without an error on its stream
    await t.pump(scan);
    fs.plugOther('event3'); // a keyboard takes the number
    await t.pump(scan);
    expect(pad.devices, isEmpty);
    expect(got.last, (NavAction.right, NavPhase.release));
    fs.plug('event6');
    await t.pump(scan);
    await pressA(t, 'event6');
  });

  hot('the pad is not opened twice by rescans', (t) async {
    await setUp(t);
    await t.pump(scan * 6);
    expect(fs.opened, ['event3']);
  });

  hot('what it opens and ignores goes to the log', (t) async {
    await setUp(t);
    fs.plugOther('event4');
    fs.plugLookalike('event5');
    await t.pump(scan * 3);
    expect(logs, contains(contains('opened event3')));
    expect(logs.where((l) => l.contains('event4')), hasLength(1));
    expect(logs, contains(contains('ignoring event4')));
    expect(logs, contains(contains('ignoring event5')));
  });
}
