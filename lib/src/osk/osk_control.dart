/// Shows and hides the on-screen keyboard for the launcher's own text fields.
///
/// A [NavTextField] that gains focus asks for the keyboard (`osk.show`) and
/// asks to hide it (`osk.hide`) when focus leaves it or the text is
/// submitted. The keyboard is a separate window (the `hinteros-osk` app, see
/// `osk_screen.dart`) that never takes focus, and what it types arrives as
/// ordinary key events (`keys.type`, `keys.action`) in the focused launcher
/// window, so the fields need nothing else.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/api.dart';

class OskControl {
  OskControl(this.connection);

  final DaemonConnection connection;

  /// Fields that have focus right now (normally none or one; a field going
  /// away after the next one took focus must not hide the keyboard).
  final _focused = <Object>{};

  /// Called when `osk.show` / `osk.hide` fail (the keyboard is disabled, no
  /// daemon). Typing then works with a physical keyboard only.
  void Function(Object error)? onError;

  void fieldFocused(Object owner) {
    if (_focused.add(owner)) _send(() => connection.oskShow());
  }

  void fieldLeft(Object owner) {
    if (_focused.remove(owner) && _focused.isEmpty) {
      _send(() => connection.oskHide());
    }
  }

  /// The text was submitted: hide, even though the field keeps focus.
  void submitted(Object owner) {
    if (_focused.contains(owner)) _send(() => connection.oskHide());
  }

  /// Show again while a field still has focus (after a rejected submit).
  void reshow() {
    if (_focused.isNotEmpty) _send(() => connection.oskShow());
  }

  void _send(Future<Object?> Function() call) {
    unawaited(
      call().then<void>((_) {}, onError: (Object e) => onError?.call(e)),
    );
  }
}

/// Makes the [OskControl] available to text fields below it.
class OskScope extends InheritedWidget {
  const OskScope({super.key, required this.control, required super.child});

  final OskControl control;

  static OskControl? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OskScope>()?.control;

  @override
  bool updateShouldNotify(OskScope old) => control != old.control;
}
