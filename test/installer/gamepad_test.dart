import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/gamepad.dart';

Uint8List frame(int type, int code, int value) {
  final d = ByteData(inputEventSize);
  d.setUint16(16, type, Endian.little);
  d.setUint16(18, code, Endian.little);
  d.setInt32(20, value, Endian.little);
  return d.buffer.asUint8List();
}

void main() {
  test('buttons map to the controller actions', () {
    final m = PadMapper();
    expect(m.map(1, 0x130, 1), [(NavAction.accept, NavPhase.press)]);
    expect(m.map(1, 0x130, 0), [(NavAction.accept, NavPhase.release)]);
    expect(m.map(1, 0x131, 1), [(NavAction.back, NavPhase.press)]);
    expect(m.map(1, 0x133, 1), [(NavAction.secondary, NavPhase.press)]);
    expect(m.map(1, 0x134, 1), [(NavAction.context, NavPhase.press)]);
    expect(m.map(1, 0x136, 1), [(NavAction.pageLeft, NavPhase.press)]);
    expect(m.map(1, 0x137, 1), [(NavAction.pageRight, NavPhase.press)]);
    expect(m.map(1, 0x13a, 1), [(NavAction.view, NavPhase.press)]);
    expect(m.map(1, 0x220, 1), [(NavAction.up, NavPhase.press)]);
    expect(m.map(1, 0x223, 1), [(NavAction.right, NavPhase.press)]);
    expect(m.map(1, 0x223, 0), [(NavAction.right, NavPhase.release)]);
    expect(m.map(1, 0x130, 2), isEmpty, reason: 'kernel key repeat is ignored');
    expect(m.map(1, 0x999, 1), isEmpty);
    expect(m.map(0, 0, 0), isEmpty, reason: 'sync events');
  });

  test('the hat switch presses and releases directions, switching cleanly', () {
    final m = PadMapper();
    expect(m.map(3, 0x10, -1), [(NavAction.left, NavPhase.press)]);
    expect(m.map(3, 0x10, 1), [
      (NavAction.left, NavPhase.release),
      (NavAction.right, NavPhase.press),
    ]);
    expect(m.map(3, 0x10, 0), [(NavAction.right, NavPhase.release)]);
    expect(m.map(3, 0x11, -1), [(NavAction.up, NavPhase.press)]);
    expect(m.map(3, 0x11, 1), [
      (NavAction.up, NavPhase.release),
      (NavAction.down, NavPhase.press),
    ]);
    expect(m.map(3, 0x11, 1), isEmpty, reason: 'no change');
  });

  test('frames are cut out of a byte stream, split anywhere', () {
    final d = EvdevDecoder();
    final bytes = [
      ...frame(1, 0x130, 1),
      ...frame(0, 0, 0),
      ...frame(1, 0x130, 0),
    ];
    final out = [
      ...d.add(bytes.sublist(0, 30)),
      ...d.add(bytes.sublist(30, 31)),
      ...d.add(bytes.sublist(31)),
    ];
    expect(out, [
      (NavAction.accept, NavPhase.press),
      (NavAction.accept, NavPhase.release),
    ]);
  });

  test('sysfs capability bitmaps', () {
    // A pad: BTN_SOUTH (0x130 = 304) is bit 48 of word 4 (from the right).
    const pad = '1 0 0 0 ffff000000000000';
    expect(sysfsBitSet('0 0 0 0 0', 0x130), isFalse);
    // Word index 4 from the right is the 5th last: construct explicitly.
    final words = ['0', '0', '0', '0', '0', '0', '0'];
    words[words.length - 1 - 4] = '10000'; // bit 16 of word 4 = 4*64+16 = 272
    expect(sysfsBitSet(words.join(' '), 272), isTrue);
    expect(sysfsBitSet(words.join(' '), 273), isFalse);
    expect(sysfsBitSet(pad, 0x130), isFalse, reason: 'word 4 is missing');
    expect(sysfsBitSet('ffffffffffffffff', 63), isTrue);
    expect(sysfsBitSet('nonsense', 3), isFalse);
  });

  group('left stick', () {
    // ABS_X = 0, ABS_Y = 1; a symmetric -1000..1000 range, so 500 is the
    // deadzone edge (0.5) and 350 the release point (0.35).
    PadMapper pad() => PadMapper(
      stickX: const AxisRange(-1000, 1000),
      stickY: const AxisRange(-1000, 1000),
    );

    test('deadzone: small deflection does nothing', () {
      final m = pad();
      expect(m.map(3, 0, 499), isEmpty);
      expect(m.map(3, 0, -499), isEmpty);
      expect(m.map(3, 1, 300), isEmpty);
    });

    test('press past half range, release only below the hysteresis point', () {
      final m = pad();
      expect(m.map(3, 0, 600), [(NavAction.right, NavPhase.press)]);
      expect(m.map(3, 0, 800), isEmpty);
      expect(m.map(3, 0, 400), isEmpty, reason: 'between 0.35 and 0.5: held');
      expect(m.map(3, 0, 360), isEmpty);
      expect(m.map(3, 0, 340), [(NavAction.right, NavPhase.release)]);
      expect(m.map(3, 0, 450), isEmpty, reason: 'must pass 0.5 again');
      expect(m.map(3, 0, 500), [(NavAction.right, NavPhase.press)]);
      expect(m.map(3, 0, 0), [(NavAction.right, NavPhase.release)]);
    });

    test('Y axis: up is negative, and each direction works', () {
      final m = pad();
      expect(m.map(3, 1, -900), [(NavAction.up, NavPhase.press)]);
      expect(m.map(3, 1, 0), [(NavAction.up, NavPhase.release)]);
      expect(m.map(3, 1, 900), [(NavAction.down, NavPhase.press)]);
      expect(m.map(3, 1, 0), [(NavAction.down, NavPhase.release)]);
      expect(m.map(3, 0, -900), [(NavAction.left, NavPhase.press)]);
    });

    test('flicking straight across switches direction cleanly', () {
      final m = pad();
      m.map(3, 0, 900);
      expect(m.map(3, 0, -900), [
        (NavAction.right, NavPhase.release),
        (NavAction.left, NavPhase.press),
      ]);
    });

    test('a diagonal is one direction: the first, unless the other wins', () {
      final m = pad();
      expect(m.map(3, 0, 700), [(NavAction.right, NavPhase.press)]);
      expect(m.map(3, 1, 600), isEmpty, reason: 'weaker than the held axis');
      expect(m.map(3, 1, 900), [
        (NavAction.right, NavPhase.release),
        (NavAction.down, NavPhase.press),
      ]);
    });

    test('uses the device range, also asymmetric ones (0..255 sticks)', () {
      final m = PadMapper(
        stickX: const AxisRange(0, 255),
        stickY: const AxisRange(0, 255),
      );
      expect(m.map(3, 0, 128), isEmpty, reason: 'centre');
      expect(m.map(3, 0, 180), isEmpty, reason: '0.41');
      expect(m.map(3, 0, 200), [(NavAction.right, NavPhase.press)]);
      expect(m.map(3, 0, 10), [
        (NavAction.right, NavPhase.release),
        (NavAction.left, NavPhase.press),
      ]);
    });

    test('defaults to the Xbox range without absinfo; right stick ignored', () {
      final m = PadMapper();
      expect(m.map(3, 0, 20000), [(NavAction.right, NavPhase.press)]);
      expect(m.map(3, 3, 30000), isEmpty, reason: 'ABS_RX');
      expect(m.map(3, 4, -30000), isEmpty, reason: 'ABS_RY');
      expect(m.map(3, 2, 1023), isEmpty, reason: 'trigger');
    });

    test('stick, hat and D-pad buttons share a direction without doubling', () {
      final m = pad();
      expect(m.map(3, 0, 900), [(NavAction.right, NavPhase.press)]);
      expect(m.map(3, 0x10, 1), isEmpty, reason: 'already right');
      expect(m.map(3, 0, 0), isEmpty, reason: 'the hat still holds it');
      expect(m.map(1, 0x223, 1), isEmpty);
      expect(m.map(3, 0x10, 0), isEmpty, reason: 'the button still holds it');
      expect(m.map(1, 0x223, 0), [(NavAction.right, NavPhase.release)]);
    });

    test('releaseAll lets go of what is held', () {
      final m = pad();
      m.map(3, 0, 900);
      m.map(3, 0x11, 1);
      expect(m.releaseAll().toSet(), {
        (NavAction.right, NavPhase.release),
        (NavAction.down, NavPhase.release),
      });
      expect(m.releaseAll(), isEmpty);
    });
  });

  group('key repeat', () {
    padTest('400 ms, then every 120 ms, until released', (t) async {
      final out = <PadEvent>[];
      final r = PadRepeater(out.add);
      _cleanups.add(r.dispose);
      r.add((NavAction.down, NavPhase.press));
      await t.pump(const Duration(milliseconds: 399));
      expect(out, isEmpty);
      await t.pump(const Duration(milliseconds: 1));
      expect(out, [(NavAction.down, NavPhase.repeat)]);
      await t.pump(const Duration(milliseconds: 120));
      await t.pump(const Duration(milliseconds: 120));
      expect(out.length, 3);
      r.add((NavAction.down, NavPhase.release));
      await t.pump(const Duration(seconds: 2));
      expect(out.length, 3);
    });

    padTest('a quick tap never repeats; buttons never repeat', (t) async {
      final out = <PadEvent>[];
      final r = PadRepeater(out.add);
      _cleanups.add(r.dispose);
      r.add((NavAction.left, NavPhase.press));
      await t.pump(const Duration(milliseconds: 200));
      r.add((NavAction.left, NavPhase.release));
      r.add((NavAction.accept, NavPhase.press));
      await t.pump(const Duration(seconds: 2));
      expect(out, isEmpty);
    });

    padTest('the newest held direction repeats; the older takes over', (
      t,
    ) async {
      final out = <PadEvent>[];
      final r = PadRepeater(out.add);
      _cleanups.add(r.dispose);
      r.add((NavAction.left, NavPhase.press));
      r.add((NavAction.up, NavPhase.press));
      await t.pump(const Duration(milliseconds: 400));
      expect(out.last, (NavAction.up, NavPhase.repeat));
      r.add((NavAction.up, NavPhase.release));
      out.clear();
      await t.pump(const Duration(milliseconds: 400));
      expect(out.single, (NavAction.left, NavPhase.repeat));
    });
  });

  group('devices', () {
    padTest('stick and D-pad through a device repeat like the daemon', (
      t,
    ) async {
      final fs = FakePads()
        ..plug('event5', stick: const AxisRange(-1000, 1000));
      final pad = EvdevPad(backend: fs)..start();
      final got = <PadEvent>[];
      pad.events.listen(got.add);
      _cleanups.add(pad.dispose);

      fs.send('event5', [frame(3, 0, 900)]);
      await t.pump();
      expect(got, [(NavAction.right, NavPhase.press)]);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 120));
      expect(got.skip(1), everyElement((NavAction.right, NavPhase.repeat)));
      expect(got.length, 3);
      fs.send('event5', [frame(3, 0, 0)]);
      await t.pump();
      expect(got.last, (NavAction.right, NavPhase.release));
      final n = got.length;
      await t.pump(const Duration(seconds: 1));
      expect(got.length, n);

      fs.send('event5', [frame(3, 0x11, 1)]);
      await t.pump(const Duration(milliseconds: 400));
      expect(got.last, (NavAction.down, NavPhase.repeat));
      fs.send('event5', [frame(3, 0x11, 0)]);
      await t.pump();
    });

    padTest('hotplug: a pad plugged in later is found at the next scan', (
      t,
    ) async {
      final fs = FakePads();
      final pad = EvdevPad(backend: fs)..start();
      final got = <PadEvent>[];
      pad.events.listen(got.add);
      _cleanups.add(pad.dispose);
      expect(pad.devices, isEmpty);

      fs.plug('event7');
      fs.plugOther('event8'); // a keyboard or mouse: not read
      await t.pump(const Duration(seconds: 1));
      expect(pad.devices, isEmpty, reason: 'not before the 2 s rescan');
      await t.pump(const Duration(seconds: 1));
      expect(pad.devices, {'event7'});
      expect(fs.opened, ['event7']);

      fs.send('event7', [frame(1, 0x130, 1)]);
      await t.pump();
      expect(got, [(NavAction.accept, NavPhase.press)]);
    });

    padTest('disconnect releases held directions and the pad returns', (
      t,
    ) async {
      final fs = FakePads()..plug('event5');
      final pad = EvdevPad(backend: fs)..start();
      final got = <PadEvent>[];
      pad.events.listen(got.add);
      _cleanups.add(pad.dispose);

      fs.send('event5', [frame(3, 0x10, -1)]);
      await t.pump(const Duration(milliseconds: 400));
      expect(got.last, (NavAction.left, NavPhase.repeat));

      fs.unplug('event5', withError: true);
      await t.pump();
      expect(pad.devices, isEmpty);
      expect(got.last, (NavAction.left, NavPhase.release));
      final n = got.length;
      await t.pump(const Duration(milliseconds: 1500));
      expect(got.length, n, reason: 'no repeat after the disconnect');

      fs.plug('event5');
      await t.pump(const Duration(seconds: 2));
      expect(pad.devices, {'event5'});
      fs.send('event5', [frame(1, 0x131, 1)]);
      await t.pump();
      expect(got.last, (NavAction.back, NavPhase.press));
    });

    padTest('a device that ends cleanly is dropped too', (t) async {
      final fs = FakePads()..plug('event5');
      final pad = EvdevPad(backend: fs)..start();
      _cleanups.add(pad.dispose);
      fs.unplug('event5');
      await t.pump();
      expect(pad.devices, isEmpty);
    });

    padTest('permission errors never crash and are retried', (t) async {
      final fs = FakePads()
        ..plug('event5')
        ..denyOpen = true;
      final pad = EvdevPad(backend: fs)..start();
      final got = <PadEvent>[];
      pad.events.listen(got.add);
      _cleanups.add(pad.dispose);
      await t.pump(const Duration(seconds: 5));
      expect(pad.devices, isEmpty);
      expect(fs.openAttempts, greaterThanOrEqualTo(2), reason: 'retried');

      fs.denyOpen = false;
      await t.pump(const Duration(seconds: 2));
      expect(pad.devices, {'event5'});

      // The stream itself failing (EACCES on first read) is handled too.
      fs.unplug('event5', withError: true);
      await t.pump();
      expect(pad.devices, isEmpty);
    });

    padTest('an unreadable or missing /dev/input is not fatal', (t) async {
      final fs = FakePads()..listFails = true;
      final pad = EvdevPad(backend: fs)..start();
      _cleanups.add(pad.dispose);
      await t.pump(const Duration(seconds: 5));
      expect(pad.devices, isEmpty);
      fs
        ..listFails = false
        ..plug('event1');
      await t.pump(const Duration(seconds: 2));
      expect(pad.devices, {'event1'});
    });

    padTest('two pads at once; dispose stops everything', (t) async {
      final fs = FakePads()
        ..plug('event1')
        ..plug('event2');
      final pad = EvdevPad(backend: fs)..start();
      expect(pad.devices, {'event1', 'event2'});
      await t.runAsync(pad.dispose);
      expect(pad.devices, isEmpty);
      expect(fs.hasListeners, isFalse);
    });
  });
}

/// A fake machine: event nodes with synthetic evdev byte streams. Nothing
/// here opens a real device.
class FakePads implements PadBackend {
  final _pads = <String, PadDeviceInfo?>{};
  final _streams = <String, StreamController<List<int>>>{};
  bool denyOpen = false;
  bool listFails = false;
  int openAttempts = 0;
  final opened = <String>[];

  void plug(String name, {AxisRange? stick}) =>
      _pads[name] = PadDeviceInfo(stickX: stick, stickY: stick);

  void plugOther(String name) => _pads[name] = null;

  void unplug(String name, {bool withError = false}) {
    _pads.remove(name);
    final c = _streams.remove(name);
    if (c == null) return;
    if (withError) c.addError(FileSystemException('No such device'));
    c.close();
  }

  void send(String name, List<Uint8List> frames) {
    final c = _streams[name]!;
    for (final f in frames) {
      c.add(f);
    }
  }

  bool get hasListeners => _streams.values.any((c) => c.hasListener);

  @override
  List<String> list() {
    if (listFails) throw FileSystemException('No such directory');
    return _pads.keys.toList();
  }

  @override
  PadDeviceInfo? probe(String name) => _pads[name];

  @override
  Stream<List<int>> open(String name) {
    openAttempts++;
    if (denyOpen) throw FileSystemException('Permission denied');
    opened.add(name);
    return (_streams[name] = StreamController<List<int>>(
      onCancel: () {},
    )).stream;
  }
}

final _cleanups = <FutureOr<void> Function()>[];

/// A widget test (for fake time) that stops what it started before the
/// framework checks for pending timers.
void padTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    try {
      await body(t);
    } finally {
      for (final c in _cleanups.reversed) {
        await t.runAsync(() async => c());
      }
      _cleanups.clear();
    }
  });
}
