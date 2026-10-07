import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show NavAction;
import 'package:hinteros_launcher/src/installer/gamepad.dart';

/// One synthetic `struct input_event` (the time stamp is zero).
Uint8List frame(int type, int code, int value) {
  final d = ByteData(inputEventSize);
  d.setUint16(16, type, Endian.little);
  d.setUint16(18, code, Endian.little);
  d.setInt32(20, value, Endian.little);
  return d.buffer.asUint8List();
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

/// An Xbox pad on a fake machine, driven like a person would: the left stick
/// for directions and the buttons for the rest, as raw evdev frames through
/// the real [EvdevPad] reader.
class PadRig {
  PadRig() {
    fs.plug('event0', stick: AxisRange.xbox);
    pad = EvdevPad(backend: fs)..start();
  }

  final fs = FakePads();
  late final EvdevPad pad;

  static const _btn = {
    NavAction.accept: 0x130, // A
    NavAction.back: 0x131, // B
    NavAction.secondary: 0x133, // X
    NavAction.context: 0x134, // Y
    NavAction.view: 0x13a,
    NavAction.menu: 0x13b,
  };

  void _send(List<Uint8List> f) => fs.send('event0', f);

  /// Pushes the stick one way (ABS_X = 0, ABS_Y = 1) and holds it.
  void deflect(NavAction dir) => _send([
    switch (dir) {
      NavAction.left => frame(3, 0, -32000),
      NavAction.right => frame(3, 0, 32000),
      NavAction.up => frame(3, 1, -32000),
      _ => frame(3, 1, 32000),
    },
    frame(0, 0, 0),
  ]);

  void center() => _send([frame(3, 0, 0), frame(3, 1, 0), frame(0, 0, 0)]);

  /// One press of [a]: the stick flicked for a direction, the button for
  /// anything else.
  Future<void> press(WidgetTester t, NavAction a) async {
    final code = _btn[a];
    if (code != null) {
      _send([frame(1, code, 1), frame(0, 0, 0)]);
      await t.pump();
      _send([frame(1, code, 0), frame(0, 0, 0)]);
    } else {
      deflect(a);
      await t.pump();
      center();
    }
    await t.pump();
  }

  Future<void> dispose(WidgetTester t) => t.runAsync(pad.dispose).then((_) {});
}
