/// Controller input without the session daemon. On the ISO nothing turns a
/// gamepad into `input_nav` events (the daemon does that on an installed
/// box), so the installer reads the kernel's evdev devices itself: it needs
/// read access to `/dev/input` (it runs as root there).
///
/// Mapping (Linux gamepad button codes, Xbox-style layout): A accepts, B
/// goes back, Y is context, X is secondary, the bumpers are page left/right,
/// View/Menu are `view`/`menu`, the D-pad moves.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../api/api.dart' show NavAction, NavPhase;

typedef PadEvent = (NavAction, NavPhase);

const _evKey = 0x01;
const _evAbs = 0x03;
const _absHat0X = 0x10;
const _absHat0Y = 0x11;
const _btnSouth = 0x130;

/// Size of `struct input_event` on 64-bit Linux.
const inputEventSize = 24;

/// Turns raw `(type, code, value)` events into navigation presses and
/// releases. Pure, so it can be tested without a device.
class PadMapper {
  int _hatX = 0;
  int _hatY = 0;

  static NavAction? _button(int code) => switch (code) {
    0x130 => NavAction.accept, // BTN_SOUTH (A)
    0x131 => NavAction.back, // BTN_EAST (B)
    0x133 => NavAction.secondary, // BTN_NORTH, "X" on Xbox pads
    0x134 => NavAction.context, // BTN_WEST, "Y" on Xbox pads
    0x136 => NavAction.pageLeft, // BTN_TL
    0x137 => NavAction.pageRight, // BTN_TR
    0x13a => NavAction.view, // BTN_SELECT
    0x13b => NavAction.menu, // BTN_START
    0x220 => NavAction.up, // BTN_DPAD_UP
    0x221 => NavAction.down,
    0x222 => NavAction.left,
    0x223 => NavAction.right,
    _ => null,
  };

  List<PadEvent> map(int type, int code, int value) {
    if (type == _evKey) {
      final a = _button(code);
      if (a == null || value == 2) return const [];
      return [(a, value == 0 ? NavPhase.release : NavPhase.press)];
    }
    if (type == _evAbs && (code == _absHat0X || code == _absHat0Y)) {
      final out = <PadEvent>[];
      final v = value.sign;
      if (code == _absHat0X) {
        _edge(out, _hatX, v, NavAction.left, NavAction.right);
        _hatX = v;
      } else {
        _edge(out, _hatY, v, NavAction.up, NavAction.down);
        _hatY = v;
      }
      return out;
    }
    return const [];
  }

  static void _edge(
    List<PadEvent> out,
    int old,
    int now,
    NavAction neg,
    NavAction pos,
  ) {
    if (old == now) return;
    if (old < 0) out.add((neg, NavPhase.release));
    if (old > 0) out.add((pos, NavPhase.release));
    if (now < 0) out.add((neg, NavPhase.press));
    if (now > 0) out.add((pos, NavPhase.press));
  }
}

/// Cuts a byte stream into `input_event` frames and maps them.
class EvdevDecoder {
  EvdevDecoder([PadMapper? mapper]) : _mapper = mapper ?? PadMapper();

  final PadMapper _mapper;
  final _pending = BytesBuilder(copy: false);

  List<PadEvent> add(List<int> chunk) {
    _pending.add(chunk);
    final bytes = _pending.takeBytes();
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final out = <PadEvent>[];
    var i = 0;
    for (; i + inputEventSize <= bytes.length; i += inputEventSize) {
      final type = data.getUint16(i + 16, Endian.little);
      final code = data.getUint16(i + 18, Endian.little);
      final value = data.getInt32(i + 20, Endian.little);
      out.addAll(_mapper.map(type, code, value));
    }
    if (i < bytes.length) _pending.add(bytes.sublist(i));
    return out;
  }
}

/// Whether the `capabilities/key` bitmap of an input device (hex words,
/// most significant first, as sysfs prints it) has bit [bit] set.
bool sysfsBitSet(String bitmap, int bit) {
  final words = bitmap.trim().split(RegExp(r'\s+'));
  final word = bit ~/ 64;
  if (word >= words.length) return false;
  final w = BigInt.tryParse(words[words.length - 1 - word], radix: 16);
  if (w == null) return false;
  return (w >> (bit % 64)) & BigInt.one == BigInt.one;
}

/// Reads every gamepad it finds under `/dev/input` and emits their presses.
/// Devices plugged in later are picked up (a rescan every few seconds).
// TODO(hardware): untested against real controllers; analog sticks are not
// mapped (the D-pad is enough to drive the installer).
class EvdevPad {
  EvdevPad({
    this.sysClassInput = '/sys/class/input',
    this.devInput = '/dev/input',
    this.rescan = const Duration(seconds: 3),
    this.repeatDelay = const Duration(milliseconds: 420),
    this.repeatEvery = const Duration(milliseconds: 110),
  });

  final String sysClassInput;
  final String devInput;
  final Duration rescan;
  final Duration repeatDelay;
  final Duration repeatEvery;

  final _out = StreamController<PadEvent>.broadcast();
  final _open = <String, StreamSubscription<List<int>>>{};
  Timer? _scanTimer;
  Timer? _repeat;
  NavAction? _held;

  Stream<PadEvent> get events => _out.stream;

  void start() {
    _scan();
    _scanTimer = Timer.periodic(rescan, (_) => _scan());
  }

  bool _isGamepad(String name) {
    try {
      final caps = File('$sysClassInput/$name/device/capabilities/key')
          .readAsStringSync();
      return sysfsBitSet(caps, _btnSouth);
    } on FileSystemException {
      return false;
    }
  }

  void _scan() {
    final Iterable<FileSystemEntity> entries;
    try {
      entries = Directory(sysClassInput).listSync();
    } on FileSystemException {
      return;
    }
    for (final e in entries) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!RegExp(r'^event\d+$').hasMatch(name) || _open.containsKey(name)) {
        continue;
      }
      if (!_isGamepad(name)) continue;
      final dec = EvdevDecoder();
      _open[name] = File('$devInput/$name').openRead().listen(
        (chunk) => dec.add(chunk).forEach(_emit),
        onError: (_) => _open.remove(name),
        onDone: () => _open.remove(name),
        cancelOnError: true,
      );
    }
  }

  static bool _moves(NavAction a) =>
      a == NavAction.up ||
      a == NavAction.down ||
      a == NavAction.left ||
      a == NavAction.right;

  void _emit(PadEvent e) {
    if (_out.isClosed) return;
    _out.add(e);
    final (a, phase) = e;
    if (!_moves(a)) return;
    // Pads send no key repeat: hold a direction to keep moving.
    if (phase == NavPhase.press) {
      _held = a;
      _repeat?.cancel();
      _repeat = Timer(repeatDelay, () {
        _repeat = Timer.periodic(repeatEvery, (_) {
          final h = _held;
          if (h != null) _out.add((h, NavPhase.repeat));
        });
      });
    } else if (_held == a) {
      _held = null;
      _repeat?.cancel();
    }
  }

  Future<void> dispose() async {
    _scanTimer?.cancel();
    _repeat?.cancel();
    for (final s in _open.values) {
      await s.cancel();
    }
    _open.clear();
    await _out.close();
  }
}
