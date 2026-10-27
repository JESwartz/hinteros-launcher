/// Controller input without the session daemon. On the ISO nothing turns a
/// gamepad into `input_nav` events (the daemon does that on an installed
/// box), so the installer reads the kernel's evdev devices itself: it needs
/// read access to `/dev/input` (it runs as root there).
///
/// Mapping (Linux gamepad button codes, Xbox-style layout): A accepts, B
/// goes back, Y is context, X is secondary, the bumpers are page left/right,
/// View/Menu are `view`/`menu`. The D-pad (hat switch or `BTN_DPAD_*`) and
/// the left stick move; the right stick, triggers and the Guide button are
/// ignored. Held directions repeat like the daemon's (400 ms, then 120 ms).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../api/api.dart' show NavAction, NavPhase;
import 'evdev_ioctl.dart' if (dart.library.js_interop) 'evdev_ioctl_web.dart';

typedef PadEvent = (NavAction, NavPhase);

const _evKey = 0x01;
const _evAbs = 0x03;
const _absX = 0x00;
const _absY = 0x01;
const _absHat0X = 0x10;
const _absHat0Y = 0x11;
const _btnSouth = 0x130;

/// Size of `struct input_event` on 64-bit Linux.
const inputEventSize = 24;

/// How far the stick must be pushed (0..1 of its half range) to count as a
/// direction, and how far back it must come to let go (hysteresis, so a
/// stick resting near the edge does not flutter).
const stickPress = 0.5;
const stickRelease = 0.35;

/// The daemon's key repeat for a held direction.
const padRepeatDelay = Duration(milliseconds: 400);
const padRepeatEvery = Duration(milliseconds: 120);

/// The range an absolute axis reports (from `EVIOCGABS`).
class AxisRange {
  const AxisRange(this.min, this.max);
  final int min;
  final int max;

  /// A typical Xbox stick, used when the device cannot be asked.
  static const xbox = AxisRange(-32768, 32767);

  /// -1..1 (0 at rest) for a raw [value].
  double normalise(int value) {
    final half = (max - min) / 2;
    if (half <= 0) return 0;
    return ((value - (min + max) / 2) / half).clamp(-1.0, 1.0);
  }
}

const _dirs = [NavAction.up, NavAction.down, NavAction.left, NavAction.right];
const _srcHat = 1, _srcStick = 2, _srcButton = 4;

/// Turns raw `(type, code, value)` events into navigation presses and
/// releases. Pure, so it can be tested without a device. A direction is held
/// while any of the hat switch, the left stick or a `BTN_DPAD_*` button holds
/// it, so two sources never produce a double press.
class PadMapper {
  PadMapper({AxisRange? stickX, AxisRange? stickY})
    : _rangeX = stickX ?? AxisRange.xbox,
      _rangeY = stickY ?? AxisRange.xbox;

  final AxisRange _rangeX;
  final AxisRange _rangeY;
  final _held = <NavAction, int>{};
  double _nx = 0;
  double _ny = 0;
  NavAction? _stick;

  static NavAction? _button(int code) => switch (code) {
    0x130 => NavAction.accept, // BTN_SOUTH (A)
    0x131 => NavAction.back, // BTN_EAST (B)
    0x133 => NavAction.secondary, // BTN_NORTH, "X" on Xbox pads
    0x134 => NavAction.context, // BTN_WEST, "Y" on Xbox pads
    0x136 => NavAction.pageLeft, // BTN_TL
    0x137 => NavAction.pageRight, // BTN_TR
    0x13a => NavAction.view, // BTN_SELECT
    0x13b => NavAction.menu, // BTN_START
    _ => null,
  };

  static NavAction? _dpadButton(int code) => switch (code) {
    0x220 => NavAction.up, // BTN_DPAD_UP
    0x221 => NavAction.down,
    0x222 => NavAction.left,
    0x223 => NavAction.right,
    _ => null,
  };

  List<PadEvent> map(int type, int code, int value) {
    if (type == _evKey) {
      if (value == 2) return const []; // the kernel's own repeat
      final d = _dpadButton(code);
      if (d != null) {
        return _update(_srcButton, {d}, value != 0 ? {d} : const {});
      }
      final a = _button(code);
      if (a == null) return const [];
      return [(a, value == 0 ? NavPhase.release : NavPhase.press)];
    }
    if (type != _evAbs) return const [];
    switch (code) {
      case _absHat0X:
        return _update(
          _srcHat,
          {NavAction.left, NavAction.right},
          {if (value < 0) NavAction.left, if (value > 0) NavAction.right},
        );
      case _absHat0Y:
        return _update(
          _srcHat,
          {NavAction.up, NavAction.down},
          {if (value < 0) NavAction.up, if (value > 0) NavAction.down},
        );
      case _absX:
        _nx = _rangeX.normalise(value);
        return _updateStick();
      case _absY:
        _ny = _rangeY.normalise(value);
        return _updateStick();
    }
    return const [];
  }

  /// The one direction the stick says, with hysteresis; on a diagonal the
  /// axis that got there first holds, unless the other one is stronger.
  List<PadEvent> _updateStick() {
    NavAction pick(double v, NavAction neg, NavAction pos) => v < 0 ? neg : pos;
    final cur = _stick;
    NavAction? next;
    if (cur != null) {
      final horizontal = cur == NavAction.left || cur == NavAction.right;
      final negative = cur == NavAction.left || cur == NavAction.up;
      final mag = (horizontal ? _nx : _ny) * (negative ? -1 : 1);
      if (mag >= stickRelease) {
        next = cur;
        final other = horizontal ? _ny : _nx;
        if (other.abs() >= stickPress && other.abs() > mag) {
          next = horizontal
              ? pick(other, NavAction.up, NavAction.down)
              : pick(other, NavAction.left, NavAction.right);
        }
      }
    }
    if (next == null) {
      final ax = _nx.abs(), ay = _ny.abs();
      if (ax >= stickPress || ay >= stickPress) {
        next = ax >= ay
            ? pick(_nx, NavAction.left, NavAction.right)
            : pick(_ny, NavAction.up, NavAction.down);
      }
    }
    _stick = next;
    return _update(_srcStick, _dirs.toSet(), {?next});
  }

  /// Sets what [source] holds among [scope] to [active]; returns the events
  /// for the directions that really changed (releases first).
  List<PadEvent> _update(
    int source,
    Set<NavAction> scope,
    Set<NavAction> active,
  ) {
    final releases = <PadEvent>[], presses = <PadEvent>[];
    for (final d in scope) {
      final before = _held[d] ?? 0;
      final after = active.contains(d) ? before | source : before & ~source;
      if (after == 0) {
        _held.remove(d);
      } else {
        _held[d] = after;
      }
      if (before == 0 && after != 0) presses.add((d, NavPhase.press));
      if (before != 0 && after == 0) releases.add((d, NavPhase.release));
    }
    return [...releases, ...presses];
  }

  /// Lets go of everything (the device went away).
  List<PadEvent> releaseAll() {
    final out = <PadEvent>[
      for (final d in _dirs)
        if (_held.containsKey(d)) (d, NavPhase.release),
    ];
    _held.clear();
    _stick = null;
    _nx = _ny = 0;
    return out;
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

/// Gives held directions the daemon's key repeat: the first repeat after
/// [delay], then one every [every]. The most recently pressed direction that
/// is still held repeats. Feed it every event; it calls [emit] for the
/// repeats only.
class PadRepeater {
  PadRepeater(
    this.emit, {
    this.delay = padRepeatDelay,
    this.every = padRepeatEvery,
  });

  final void Function(PadEvent) emit;
  final Duration delay;
  final Duration every;

  final _held = <NavAction>[];
  Timer? _timer;

  void add(PadEvent e) {
    final (a, phase) = e;
    if (!_dirs.contains(a)) return;
    if (phase == NavPhase.press) {
      _held
        ..remove(a)
        ..add(a);
      _restart();
    } else if (phase == NavPhase.release && _held.remove(a)) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_held.isEmpty) return;
    _timer = Timer(delay, () {
      _timer = Timer.periodic(every, (_) {
        if (_held.isNotEmpty) emit((_held.last, NavPhase.repeat));
      });
      if (_held.isNotEmpty) emit((_held.last, NavPhase.repeat));
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _held.clear();
  }
}

/// What [EvdevPad] needs to know about one input device.
class PadDeviceInfo {
  const PadDeviceInfo({
    this.stickX,
    this.stickY,
    this.gamepad = true,
    this.label = '',
  });
  final AxisRange? stickX;
  final AxisRange? stickY;

  /// False for something that only looks like a pad (a keyboard or mouse
  /// with EV_KEY and EV_ABS): never read.
  final bool gamepad;

  /// The device's name, for the log.
  final String label;
}

/// The machine side of [EvdevPad], so tests can fake devices.
abstract class PadBackend {
  /// Names of the event nodes (`event3`). May throw [FileSystemException].
  List<String> list();

  /// What the device is: null if it is not a gamepad (or cannot be told).
  PadDeviceInfo? probe(String name);

  /// The device's name when it is a keyboard (EV_KEY with letters, Enter and
  /// Space), null when it is not or cannot be told.
  String? probeKeyboard(String name);

  /// The device's raw `input_event` bytes. Errors (permission denied, the
  /// device unplugged) arrive as stream errors or as the stream's end.
  Stream<List<int>> open(String name);
}

/// The real thing: sysfs for what a device is, `/dev/input` for its events,
/// `EVIOCGABS` for the stick ranges.
class LinuxPadBackend implements PadBackend {
  LinuxPadBackend({
    this.sysClassInput = '/sys/class/input',
    this.devInput = '/dev/input',
  });

  final String sysClassInput;
  final String devInput;

  static final _eventNode = RegExp(r'^event\d+$');

  @override
  List<String> list() => [
    for (final e in Directory(devInput).listSync())
      if (_eventNode.hasMatch(
        e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      ))
        e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ];

  String? _caps(String name, String file) {
    try {
      return File(
        file == _nameFile
            ? '$sysClassInput/$name/device/name'
            : '$sysClassInput/$name/device/capabilities/$file',
      ).readAsStringSync();
    } on Object {
      return null;
    }
  }

  @override
  PadDeviceInfo? probe(String name) {
    final ev = _caps(name, 'ev'), key = _caps(name, 'key');
    if (ev == null || key == null) return null;
    if (!sysfsBitSet(ev, _evKey) || !sysfsBitSet(ev, _evAbs)) return null;
    // BTN_GAMEPAD is BTN_SOUTH.
    if (!sysfsBitSet(key, _btnSouth)) return null;
    // A keyboard that reports stray BTN_* codes: it has letters, Enter and
    // Space, which no pad has.
    if (sysfsBitSet(key, 30) && sysfsBitSet(key, 28) && sysfsBitSet(key, 57)) {
      return null;
    }
    final abs = _caps(name, 'abs') ?? '';
    AxisRange? range(int code) {
      if (!sysfsBitSet(abs, code)) return null;
      final r = readAbsRange('$devInput/$name', code);
      return r == null ? null : AxisRange(r.$1, r.$2);
    }

    return PadDeviceInfo(
      stickX: range(_absX),
      stickY: range(_absY),
      label: (_caps(name, _nameFile) ?? '').trim(),
    );
  }

  /// A device with KEY_A, KEY_ENTER and KEY_SPACE that is not a pad (a pad
  /// has BTN_SOUTH and none of those).
  @override
  String? probeKeyboard(String name) {
    final ev = _caps(name, 'ev'), key = _caps(name, 'key');
    if (ev == null || key == null) return null;
    if (!sysfsBitSet(ev, _evKey)) return null;
    if (!sysfsBitSet(key, 30) ||
        !sysfsBitSet(key, 28) ||
        !sysfsBitSet(key, 57)) {
      return null;
    }
    return (_caps(name, _nameFile) ?? '').trim();
  }

  static const _nameFile = '<name>';

  @override
  Stream<List<int>> open(String name) => File('$devInput/$name').openRead();
}

/// Reads every gamepad it finds under `/dev/input` and emits their presses.
/// Devices plugged in later are picked up (a rescan every [rescan]); a device
/// that goes away, or that cannot be opened (no permission), never crashes
/// anything: its held directions are released and it is tried again at the
/// next scan.
///
/// Every device is handled on its own: a device that cannot be probed or
/// opened (a keyboard plugged in later, with whatever capabilities and
/// errors), or one whose event number changes, never touches a pad that is
/// already open. A pad is only closed when its own stream ends or fails, or
/// when its node is gone from the listing.
class EvdevPad {
  EvdevPad({
    PadBackend? backend,
    this.rescan = const Duration(seconds: 2),
    Duration repeatDelay = padRepeatDelay,
    Duration repeatEvery = padRepeatEvery,
    void Function(String)? log,
  }) : backend = backend ?? LinuxPadBackend(),
       _log = log ?? _stderrLog {
    _repeater = PadRepeater(_add, delay: repeatDelay, every: repeatEvery);
  }

  final PadBackend backend;
  final Duration rescan;
  final void Function(String) _log;

  static void _stderrLog(String m) {
    try {
      stderr.writeln('hinteros-evdev: $m');
    } on Object {
      // no stderr: nothing to tell
    }
  }

  final _out = StreamController<PadEvent>.broadcast();
  final _open = <String, _OpenPad>{};

  /// Nodes already looked at and not a pad, with why (to log them once).
  final _ignored = <String, String>{};
  late final PadRepeater _repeater;
  Timer? _scanTimer;

  Stream<PadEvent> get events => _out.stream;

  /// The event nodes currently being read.
  Set<String> get devices => _open.keys.toSet();

  void start() {
    _scan();
    _scanTimer = Timer.periodic(rescan, (_) => _scan());
  }

  void _scan() {
    if (_out.isClosed) return;
    try {
      _scanDevices();
    } on Object catch (e) {
      _log('scan failed: $e'); // never stops the timer
    }
  }

  void _scanDevices() {
    final List<String> names;
    try {
      names = backend.list();
    } on Object {
      return; // no /dev/input (yet), or not allowed: keep what is open
    }
    final present = names.toSet();
    // A node that left the listing is gone, even if its stream did not say
    // so: let go of it (releases its directions), so a later device that gets
    // the same event number is not mistaken for it.
    for (final name in _open.keys.toList()) {
      if (!present.contains(name)) {
        _log('$name disappeared');
        _lost(name, _open[name]!);
      }
    }
    _ignored.removeWhere((name, _) => !present.contains(name));
    for (final name in names) {
      if (_open.containsKey(name)) continue;
      try {
        _tryOpen(name);
      } on Object catch (e) {
        // Permission denied and the like: this device only, next scan.
        _open.remove(name);
        _note(name, 'error: $e');
      }
    }
  }

  void _note(String name, String why) {
    if (_ignored[name] == why) return;
    _ignored[name] = why;
    _log('ignoring $name ($why)');
  }

  void _tryOpen(String name) {
    final PadDeviceInfo? info;
    try {
      info = backend.probe(name);
    } on Object catch (e) {
      _note(name, 'cannot be probed: $e');
      return;
    }
    if (info == null || !info.gamepad) {
      _note(name, 'not a gamepad');
      return;
    }
    final pad = _OpenPad(PadMapper(stickX: info.stickX, stickY: info.stickY));
    _open[name] = pad;
    pad.sub = backend
        .open(name)
        .listen(
          (chunk) {
            try {
              pad.decoder.add(chunk).forEach(_emit);
            } on Object catch (e) {
              _log('$name: bad data: $e');
            }
          },
          onError: (Object _) => _lost(name, pad),
          onDone: () => _lost(name, pad),
          cancelOnError: true,
        );
    _ignored.remove(name);
    final label = info.label.isEmpty ? '' : ' "${info.label}"';
    _log('opened $name$label');
  }

  void _lost(String name, _OpenPad pad) {
    if (_open[name] != pad) return;
    _open.remove(name);
    try {
      pad.sub?.cancel();
    } on Object {
      // already gone
    }
    pad.mapper.releaseAll().forEach(_emit);
    _log('closed $name');
  }

  void _emit(PadEvent e) {
    if (_out.isClosed) return;
    _out.add(e);
    _repeater.add(e);
  }

  void _add(PadEvent e) {
    if (!_out.isClosed) _out.add(e);
  }

  Future<void> dispose() async {
    _scanTimer?.cancel();
    _repeater.dispose();
    for (final p in _open.values) {
      await p.sub?.cancel();
    }
    _open.clear();
    await _out.close();
  }
}

class _OpenPad {
  _OpenPad(this.mapper) : decoder = EvdevDecoder(mapper);
  final PadMapper mapper;
  final EvdevDecoder decoder;
  StreamSubscription<List<int>>? sub;
}
