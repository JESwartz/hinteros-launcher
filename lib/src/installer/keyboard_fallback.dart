/// Decides when the evdev keyboard ([EvdevKeyboard]) may type, so a key is
/// never handled twice.
///
/// The compositor normally delivers keys to the window and Flutter turns them
/// into key events. On real hardware under cage the window sometimes does
/// not get keyboard focus at first, and then nothing arrives. The fallback
/// is active only when the window does not have keyboard focus:
///
///  - the runner (GTK) tells us about focus changes over the
///    `hinteros/window` channel (`focus` with a bool; `isActive` asks);
///  - any Flutter key event is proof that the compositor delivers keys: from
///    then on the evdev keys are ignored, until the window loses focus;
///  - when GTK says the window is focused (or says nothing) but no Flutter
///    key arrived, an evdev key waits [grace] for its Flutter twin; if none
///    comes the compositor is not delivering keys after all and the evdev
///    keys are used until a Flutter key arrives.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'evdev_keyboard.dart';

class KeyboardFallback extends ChangeNotifier {
  KeyboardFallback({
    required Stream<SoftKey> source,
    this.grace = const Duration(milliseconds: 300),
    void Function(String)? log,
    bool listenToFlutterKeys = true,
  }) : _log = log ?? _stderrLog,
       _listenToFlutterKeys = listenToFlutterKeys {
    _sub = source.listen(_onEvdev);
    if (listenToFlutterKeys) {
      HardwareKeyboard.instance.addHandler(_onFlutterKey);
    }
  }

  final Duration grace;
  final void Function(String) _log;
  final bool _listenToFlutterKeys;
  StreamSubscription<SoftKey>? _sub;

  static void _stderrLog(String m) {
    try {
      stderr.writeln('hinteros-focus: $m');
    } on Object {
      // no stderr: nothing to tell
    }
  }

  final _out = StreamController<SoftKey>.broadcast();

  /// The keys to act on: the evdev keys, while the fallback is active.
  Stream<SoftKey> get keys => _out.stream;

  /// What GTK last said about keyboard focus: null before it said anything.
  bool? _windowFocused;
  bool? get windowFocused => _windowFocused;

  /// A Flutter key event arrived since the window last lost focus.
  bool _flutterKeys = false;
  bool get flutterKeysWork => _flutterKeys;

  /// GTK said "focused" but no Flutter key came in time for an evdev key.
  bool _deaf = false;
  bool _wasActive = false;

  final _pending = <SoftKey>[];
  Timer? _graceTimer;

  /// Whether the window is known to have the compositor's keyboard focus (so
  /// the app should take its own focus, e.g. highlight the first button).
  bool get hasFocus => _flutterKeys || _windowFocused == true;

  /// The evdev keys are being used.
  bool get active => !_flutterKeys && (_windowFocused == false || _deaf);

  /// The runner's report (`focus-in`, `focus-out`, `is-active`).
  void setWindowFocus(bool focused, {String source = 'window'}) {
    if (_windowFocused != focused) {
      _log('$source: keyboard focus ${focused ? 'gained' : 'lost'}');
    }
    _windowFocused = focused;
    if (!focused) {
      _flutterKeys = false;
      _deaf = false;
      _dropPending();
    }
    _changed();
  }

  bool _firstFlutterKey = true;

  bool _onFlutterKey(KeyEvent e) {
    flutterKeyArrived(e.logicalKey.keyLabel);
    return false; // never handles anything
  }

  /// A key event reached Flutter: the compositor delivers keys.
  @visibleForTesting
  void flutterKeyArrived([String what = 'key']) {
    if (_firstFlutterKey) {
      _firstFlutterKey = false;
      _log('first Flutter key event ($what)');
    }
    _dropPending();
    _deaf = false;
    if (!_flutterKeys) {
      _flutterKeys = true;
      _log('Flutter receives keys: the evdev keyboard is ignored');
    }
    _changed();
  }

  void _dropPending() {
    _pending.clear();
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  void _onEvdev(SoftKey k) {
    if (_out.isClosed || _flutterKeys) return;
    if (_windowFocused == false || _deaf) {
      _emit(k);
      return;
    }
    // Focused (or unknown) but silent so far: give Flutter's own event a
    // moment to prove that the compositor delivers keys.
    _pending.add(k);
    _graceTimer ??= Timer(grace, () {
      _graceTimer = null;
      if (_flutterKeys || _out.isClosed) {
        _pending.clear();
        return;
      }
      _deaf = true;
      _log(
        'window reports keyboard focus but no key reached Flutter: '
        'using the evdev keyboard',
      );
      final keys = List.of(_pending);
      _pending.clear();
      _changed();
      keys.forEach(_emit);
    });
  }

  void _emit(SoftKey k) {
    if (!_out.isClosed) _out.add(k);
  }

  void _changed() {
    final now = active;
    if (now != _wasActive) {
      _wasActive = now;
      _log(
        now
            ? 'evdev keyboard fallback ACTIVE (window has no keyboard focus)'
            : 'evdev keyboard fallback inactive',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _sub?.cancel();
    if (_listenToFlutterKeys) {
      HardwareKeyboard.instance.removeHandler(_onFlutterKey);
    }
    _out.close();
    super.dispose();
  }
}

/// Connects [fallback] to the runner's `hinteros/window` channel. Silent
/// when there is no runner behind it (tests, other embedders).
class WindowFocusChannel {
  WindowFocusChannel(this.fallback, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('hinteros/window') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'focus' && call.arguments is bool) {
        fallback.setWindowFocus(call.arguments as bool);
      }
      return null;
    });
    // Messages sent before this handler existed are lost: ask.
    unawaited(_ask());
  }

  final KeyboardFallback fallback;
  final MethodChannel _channel;

  Future<void> _ask() async {
    try {
      final v = await _channel.invokeMethod<bool>('isActive');
      if (v != null) fallback.setWindowFocus(v, source: 'startup');
    } on MissingPluginException {
      // no runner
    } on Object {
      // not worth failing for
    }
  }

  void dispose() => _channel.setMethodCallHandler(null);
}

/// What the app needs of the keyboard layer, in one place.
class InstallerKeyboard {
  InstallerKeyboard._(this.reader, this.fallback, this.channel);

  /// The real thing: evdev keyboards + focus tracking + runner channel.
  factory InstallerKeyboard.start() {
    final reader = EvdevKeyboard()..start();
    final fallback = KeyboardFallback(source: reader.keys);
    return InstallerKeyboard._(reader, fallback, WindowFocusChannel(fallback));
  }

  final EvdevKeyboard reader;
  final KeyboardFallback fallback;
  final WindowFocusChannel channel;

  Future<void> dispose() async {
    channel.dispose();
    fallback.dispose();
    await reader.dispose();
  }
}
