/// A keyboard read straight from the kernel's evdev devices: the fallback for
/// when the compositor does not give the window keyboard focus (seen on real
/// hardware under cage: the pad works because it is read here, the USB
/// keyboard does not because its keys go through the compositor).
///
/// Only a US layout is known here. The devices are only ever read, never
/// grabbed, so the compositor and the kernel console see the same keys.
/// See `keyboard_fallback.dart` for when these keys are used at all.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../api/api.dart' show NavPhase;
import '../nav/soft_key.dart';
import 'gamepad.dart';

export '../nav/soft_key.dart' show SoftKey;

class _K {
  const _K(this.key, [this.normal, this.shifted, this.letter = false]);
  final LogicalKeyboardKey key;
  final String? normal;
  final String? shifted;
  final bool letter;
}

const _shiftCodes = {42, 54};
const _ctrlCodes = {29, 97};
const _altCodes = {56, 100};
const _metaCodes = {125, 126};
const _capsLock = 58;

final Map<int, _K> _table = () {
  final m = <int, _K>{};
  const digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
    LogicalKeyboardKey.digit0,
  ];
  const digitChars = '1234567890';
  const digitShift = '!@#\$%^&*()';
  for (var i = 0; i < 10; i++) {
    m[2 + i] = _K(digits[i], digitChars[i], digitShift[i]);
  }
  void letters(int first, String row, List<LogicalKeyboardKey> keys) {
    for (var i = 0; i < row.length; i++) {
      m[first + i] = _K(keys[i], row[i], row[i].toUpperCase(), true);
    }
  }

  letters(16, 'qwertyuiop', [
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.keyR,
    LogicalKeyboardKey.keyT,
    LogicalKeyboardKey.keyY,
    LogicalKeyboardKey.keyU,
    LogicalKeyboardKey.keyI,
    LogicalKeyboardKey.keyO,
    LogicalKeyboardKey.keyP,
  ]);
  letters(30, 'asdfghjkl', [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyG,
    LogicalKeyboardKey.keyH,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyL,
  ]);
  letters(44, 'zxcvbnm', [
    LogicalKeyboardKey.keyZ,
    LogicalKeyboardKey.keyX,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyV,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyN,
    LogicalKeyboardKey.keyM,
  ]);
  m[12] = const _K(LogicalKeyboardKey.minus, '-', '_');
  m[13] = const _K(LogicalKeyboardKey.equal, '=', '+');
  m[26] = const _K(LogicalKeyboardKey.bracketLeft, '[', '{');
  m[27] = const _K(LogicalKeyboardKey.bracketRight, ']', '}');
  m[39] = const _K(LogicalKeyboardKey.semicolon, ';', ':');
  m[40] = const _K(LogicalKeyboardKey.quote, "'", '"');
  m[41] = const _K(LogicalKeyboardKey.backquote, '`', '~');
  m[43] = const _K(LogicalKeyboardKey.backslash, '\\', '|');
  m[51] = const _K(LogicalKeyboardKey.comma, ',', '<');
  m[52] = const _K(LogicalKeyboardKey.period, '.', '>');
  m[53] = const _K(LogicalKeyboardKey.slash, '/', '?');
  m[57] = const _K(LogicalKeyboardKey.space, ' ', ' ');
  // Keypad (Num Lock assumed on).
  const pad = {
    71: ('7', LogicalKeyboardKey.numpad7),
    72: ('8', LogicalKeyboardKey.numpad8),
    73: ('9', LogicalKeyboardKey.numpad9),
    75: ('4', LogicalKeyboardKey.numpad4),
    76: ('5', LogicalKeyboardKey.numpad5),
    77: ('6', LogicalKeyboardKey.numpad6),
    79: ('1', LogicalKeyboardKey.numpad1),
    80: ('2', LogicalKeyboardKey.numpad2),
    81: ('3', LogicalKeyboardKey.numpad3),
    82: ('0', LogicalKeyboardKey.numpad0),
    83: ('.', LogicalKeyboardKey.numpadDecimal),
    74: ('-', LogicalKeyboardKey.numpadSubtract),
    78: ('+', LogicalKeyboardKey.numpadAdd),
    55: ('*', LogicalKeyboardKey.numpadMultiply),
    98: ('/', LogicalKeyboardKey.numpadDivide),
  };
  pad.forEach((code, v) => m[code] = _K(v.$2, v.$1, v.$1));
  // Keys without text.
  m[1] = const _K(LogicalKeyboardKey.escape);
  m[14] = const _K(LogicalKeyboardKey.backspace);
  m[15] = const _K(LogicalKeyboardKey.tab);
  m[28] = const _K(LogicalKeyboardKey.enter);
  m[96] = const _K(LogicalKeyboardKey.numpadEnter);
  m[59] = const _K(LogicalKeyboardKey.f1);
  m[103] = const _K(LogicalKeyboardKey.arrowUp);
  m[108] = const _K(LogicalKeyboardKey.arrowDown);
  m[105] = const _K(LogicalKeyboardKey.arrowLeft);
  m[106] = const _K(LogicalKeyboardKey.arrowRight);
  m[104] = const _K(LogicalKeyboardKey.pageUp);
  m[109] = const _K(LogicalKeyboardKey.pageDown);
  m[127] = const _K(LogicalKeyboardKey.contextMenu);
  return m;
}();

/// Turns `EV_KEY` events of one keyboard into [SoftKey]s. Pure, so it can be
/// tested without a device.
///
/// Shift (and Caps Lock for letters) pick the character; Ctrl, Alt and Meta
/// take it away (a shortcut is not text). The kernel's own repeat (value 2)
/// becomes a [NavPhase.repeat] for a key that is held, and nothing for a key
/// this mapper never saw go down (a stray repeat).
class KeyboardMapper {
  final _held = <int>{};
  final _shifts = <int>{};
  final _mods = <int>{};
  bool _caps = false;

  /// Codes currently held.
  Set<int> get held => Set.unmodifiable(_held);

  bool get _shift => _shifts.isNotEmpty;

  List<SoftKey> map(int type, int code, int value) {
    if (type != 0x01) return const [];
    final down = value != 0;
    if (_shiftCodes.contains(code)) {
      down ? _shifts.add(code) : _shifts.remove(code);
      return const [];
    }
    if (_ctrlCodes.contains(code) ||
        _altCodes.contains(code) ||
        _metaCodes.contains(code)) {
      down ? _mods.add(code) : _mods.remove(code);
      return const [];
    }
    if (code == _capsLock) {
      if (value == 1) _caps = !_caps;
      return const [];
    }
    final k = _table[code];
    if (k == null) return const [];
    final phase = switch (value) {
      0 => NavPhase.release,
      1 => NavPhase.press,
      _ => NavPhase.repeat,
    };
    if (phase == NavPhase.release) {
      if (!_held.remove(code)) return const [];
    } else if (phase == NavPhase.press) {
      if (!_held.add(code)) {
        // A second "press" without a release: treat it as a repeat.
        return [_event(k, NavPhase.repeat)];
      }
    } else if (!_held.contains(code)) {
      return const [];
    }
    return [_event(k, phase)];
  }

  SoftKey _event(_K k, NavPhase phase) {
    String? c;
    if (_mods.isEmpty) {
      final upper = k.letter ? (_shift != _caps) : _shift;
      c = upper ? k.shifted : k.normal;
    }
    return SoftKey(k.key, phase, character: c, shift: _shift);
  }

  /// Forgets everything (the device went away, or the fallback was turned
  /// off), so no key stays held.
  void reset() {
    _held.clear();
    _shifts.clear();
    _mods.clear();
  }
}

/// Cuts a byte stream into `input_event` frames and maps them.
class KeyboardDecoder {
  KeyboardDecoder(this.mapper);

  final KeyboardMapper mapper;
  final _pending = BytesBuilder(copy: false);

  List<SoftKey> add(List<int> chunk) {
    _pending.add(chunk);
    final bytes = _pending.takeBytes();
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final out = <SoftKey>[];
    var i = 0;
    for (; i + inputEventSize <= bytes.length; i += inputEventSize) {
      out.addAll(
        mapper.map(
          data.getUint16(i + 16, Endian.little),
          data.getUint16(i + 18, Endian.little),
          data.getInt32(i + 20, Endian.little),
        ),
      );
    }
    if (i < bytes.length) _pending.add(bytes.sublist(i));
    return out;
  }
}

/// Reads every keyboard it finds (hotplug included: a rescan every [rescan],
/// each device on its own, a device that cannot be opened is tried again at
/// the next scan, none of it ever throws) and emits their keys, whether or
/// not anyone wants them: [KeyboardFallback] decides.
///
/// Two nodes of one physical keyboard that both report the same key (some
/// keyboards have a second, full-size interface) must not type twice: a key
/// that one device holds is ignored on the others until it is released.
class EvdevKeyboard {
  EvdevKeyboard({
    PadBackend? backend,
    this.rescan = const Duration(seconds: 2),
    void Function(String)? log,
  }) : backend = backend ?? LinuxPadBackend(),
       _log = log ?? _stderrLog;

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

  final _out = StreamController<SoftKey>.broadcast();
  final _open = <String, _OpenKeyboard>{};
  final _ignored = <String, String>{};

  /// Which device holds each key code.
  final _owner = <int, String>{};
  Timer? _timer;

  Stream<SoftKey> get keys => _out.stream;

  /// The event nodes currently being read.
  Set<String> get devices => _open.keys.toSet();

  void start() {
    _scan();
    _timer = Timer.periodic(rescan, (_) => _scan());
  }

  void _scan() {
    if (_out.isClosed) return;
    try {
      _scanDevices();
    } on Object catch (e) {
      _log('keyboard scan failed: $e');
    }
  }

  void _scanDevices() {
    final List<String> names;
    try {
      names = backend.list();
    } on Object {
      return;
    }
    final present = names.toSet();
    for (final name in _open.keys.toList()) {
      if (!present.contains(name)) {
        _log('keyboard $name disappeared');
        _lost(name, _open[name]!);
      }
    }
    _ignored.removeWhere((name, _) => !present.contains(name));
    for (final name in names) {
      if (_open.containsKey(name)) continue;
      try {
        _tryOpen(name);
      } on Object catch (e) {
        _open.remove(name);
        _note(name, 'error: $e');
      }
    }
  }

  void _note(String name, String why) {
    if (_ignored[name] == why) return;
    _ignored[name] = why;
    _log('keyboard: ignoring $name ($why)');
  }

  void _tryOpen(String name) {
    final String? label;
    try {
      label = backend.probeKeyboard(name);
    } on Object catch (e) {
      _note(name, 'cannot be probed: $e');
      return;
    }
    if (label == null) {
      _note(name, 'not a keyboard');
      return;
    }
    final kb = _OpenKeyboard();
    _open[name] = kb;
    kb.sub = backend
        .open(name)
        .listen(
          (chunk) {
            try {
              for (final k in kb.decoder.add(chunk)) {
                _emit(name, k);
              }
            } on Object catch (e) {
              _log('keyboard $name: bad data: $e');
            }
          },
          onError: (Object _) => _lost(name, kb),
          onDone: () => _lost(name, kb),
          cancelOnError: true,
        );
    _ignored.remove(name);
    _log('keyboard opened $name${label.isEmpty ? '' : ' "$label"'}');
  }

  void _emit(String name, SoftKey k) {
    if (_out.isClosed) return;
    final code = _codeOf(k);
    final owner = _owner[code];
    switch (k.phase) {
      case NavPhase.press:
        if (owner != null && owner != name) return; // the twin node
        _owner[code] = name;
      case NavPhase.repeat:
        if (owner != name) return;
      case NavPhase.release:
        if (owner != name) return;
        _owner.remove(code);
      default:
        return;
    }
    _out.add(k);
  }

  // The logical key id stands for the code: unique per physical key here.
  int _codeOf(SoftKey k) => k.key.keyId;

  void _lost(String name, _OpenKeyboard kb) {
    if (_open[name] != kb) return;
    _open.remove(name);
    try {
      kb.sub?.cancel();
    } on Object {
      // already gone
    }
    // Let go of what that device held.
    for (final code in kb.decoder.mapper.held) {
      // (codes are evdev codes in the mapper; owners are by logical key)
      final k = _table[code];
      if (k != null && _owner[k.key.keyId] == name) {
        _owner.remove(k.key.keyId);
        if (!_out.isClosed) {
          _out.add(SoftKey(k.key, NavPhase.release));
        }
      }
    }
    kb.decoder.mapper.reset();
    _log('keyboard closed $name');
  }

  Future<void> dispose() async {
    _timer?.cancel();
    for (final k in _open.values) {
      await k.sub?.cancel();
    }
    _open.clear();
    await _out.close();
  }
}

class _OpenKeyboard {
  _OpenKeyboard() : decoder = KeyboardDecoder(KeyboardMapper());
  final KeyboardDecoder decoder;
  StreamSubscription<List<int>>? sub;
}
