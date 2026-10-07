import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../api/api.dart' show NavPhase;

/// One key press, repeat or release, as the keyboard layer sees it: the same
/// information a Flutter `KeyEvent` carries that the installer uses.
class SoftKey {
  const SoftKey(this.key, this.phase, {this.character, this.shift = false});

  final LogicalKeyboardKey key;

  /// [NavPhase.press], [NavPhase.repeat] or [NavPhase.release].
  final NavPhase phase;

  /// The text the key types (null: not a printable key, or a shortcut with
  /// Ctrl/Alt/Meta held).
  final String? character;

  /// Shift was held (Shift+Tab goes backwards).
  final bool shift;

  bool get down => phase != NavPhase.release;

  @override
  String toString() => 'SoftKey(${key.keyLabel} $phase ${character ?? ''})';

  @override
  bool operator ==(Object other) =>
      other is SoftKey &&
      other.key == key &&
      other.phase == phase &&
      other.character == character &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(key, phase, character, shift);
}

/// Where a screen that types (the on-screen keyboard) takes [SoftKey]s from:
/// it sets [handler] while it is up. The handler says whether it used the key.
class SoftKeySink {
  bool Function(SoftKey key)? handler;
}
