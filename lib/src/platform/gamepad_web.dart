/// A gamepad in the browser demo (`lib/web_main.dart`): the Gamepad API
/// (`navigator.getGamepads`, standard mapping only) polled every 16 ms and
/// fed into the current session (the mock daemon's `input_nav`, or the
/// profile picker), as the session daemon does with a real controller.
/// Browser only (`dart:js_interop`).
library;

import 'dart:async';
import 'dart:js_interop';

import '../api/api.dart' show NavAction, NavPhase;

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external JSArray<_Gamepad?> getGamepads();
}

extension type _Gamepad._(JSObject _) implements JSObject {
  external String get mapping;
  external JSArray<_Button> get buttons;
  external JSArray<JSNumber> get axes;
}

extension type _Button._(JSObject _) implements JSObject {
  external bool get pressed;
}

/// Standard mapping button index -> action.
const _actions = {
  0: NavAction.accept,
  1: NavAction.back,
  2: NavAction.secondary,
  3: NavAction.context,
  4: NavAction.pageLeft,
  5: NavAction.pageRight,
  12: NavAction.up,
  13: NavAction.down,
  14: NavAction.left,
  15: NavAction.right,
};

/// View (8) and Guide (16, which the browser often keeps): Home. Without it
/// a pad cannot leave a "running" app.
const _home = [8, 16];

/// The left stick past this counts as the D-pad.
const _stick = 0.5;

/// The session daemon's key repeat: the last pressed direction repeats
/// after [_delay], then every [_interval].
const _delay = Duration(milliseconds: 400);
const _interval = Duration(milliseconds: 100);

const _directions = {
  NavAction.up,
  NavAction.down,
  NavAction.left,
  NavAction.right,
};

class WebGamepad {
  WebGamepad({required this.nav, required this.home});

  /// A button: its action and phase.
  final void Function(NavAction action, NavPhase phase) nav;

  /// View or Guide.
  final void Function() home;
  final _clock = Stopwatch()..start();
  Timer? _timer;
  Set<NavAction> _held = {};
  bool _homeHeld = false;
  NavAction? _repeating;
  Duration _next = Duration.zero;

  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _poll() {
    final List<_Gamepad?> pads;
    try {
      pads = _navigator.getGamepads().toDart;
    } catch (_) {
      // No Gamepad API (or not allowed in this frame): nothing to poll.
      stop();
      return;
    }
    final now = <NavAction>{};
    var homeDown = false;
    for (final p in pads) {
      if (p == null || p.mapping != 'standard') continue;
      final b = p.buttons.toDart;
      for (final MapEntry(key: i, value: a) in _actions.entries) {
        if (i < b.length && b[i].pressed) now.add(a);
      }
      for (final i in _home) {
        if (i < b.length && b[i].pressed) homeDown = true;
      }
      final axes = p.axes.toDart;
      if (axes.length >= 2) {
        final x = axes[0].toDartDouble, y = axes[1].toDartDouble;
        if (x < -_stick) now.add(NavAction.left);
        if (x > _stick) now.add(NavAction.right);
        if (y < -_stick) now.add(NavAction.up);
        if (y > _stick) now.add(NavAction.down);
      }
    }

    if (homeDown && !_homeHeld) home();
    _homeHeld = homeDown;

    final t = _clock.elapsed;
    for (final a in _held.difference(now)) {
      nav(a, NavPhase.release);
      if (a == _repeating) _repeating = null;
    }
    for (final a in now.difference(_held)) {
      nav(a, NavPhase.press);
      if (_directions.contains(a)) {
        _repeating = a;
        _next = t + _delay;
      }
    }
    _held = now;

    final r = _repeating;
    if (r != null && t >= _next) {
      nav(r, NavPhase.repeat);
      // A late tick gives one repeat, not a burst.
      final soonest = t + _interval ~/ 2;
      _next = _next + _interval;
      if (_next < soonest) _next = soonest;
    }
  }
}
