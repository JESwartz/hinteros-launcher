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
    expect(m.map(3, 0x00, 30000), isEmpty, reason: 'sticks are not mapped');
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
}
