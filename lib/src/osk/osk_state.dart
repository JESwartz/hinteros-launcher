import 'dart:async';

import 'package:flutter/foundation.dart';

import 'osk_backend.dart';
import 'osk_layout.dart';

/// What the keyboard is showing and what pressing a key does. All output goes
/// through the [OskBackend], in order; the OSK never has a text field of its
/// own, [typed] is only a preview.
class OskState extends ChangeNotifier {
  OskState(this.backend) {
    _visibility = backend.visibility.listen((visible) {
      if (!visible) reset();
    });
  }

  final OskBackend backend;
  late final StreamSubscription<bool> _visibility;

  OskPage _page = OskPage.letters;
  ShiftState _shift = ShiftState.off;
  String _typed = '';
  String? _error;
  Future<void> _queue = Future.value();

  OskPage get page => _page;
  ShiftState get shift => _shift;

  /// What was typed since the keyboard last opened (backspace takes characters
  /// off). Preview only.
  String get typed => _typed;

  /// Why the last key did not arrive (the daemon said no, or is too old).
  String? get error => _error;

  List<OskRow> get rows => oskLayout(_page, _shift);

  /// Back to letters, shift off, empty preview: the keyboard was closed.
  void reset() {
    _page = OskPage.letters;
    _shift = ShiftState.off;
    _typed = '';
    _error = null;
    notifyListeners();
  }

  void _send(Future<void> Function() call) {
    _queue = _queue
        .then((_) => call())
        .then(
          (_) {
            if (_error != null) {
              _error = null;
              notifyListeners();
            }
          },
          onError: (Object e) {
            _error = e is UnsupportedError ? '${e.message}' : '$e';
            notifyListeners();
          },
        );
  }

  /// Completes when every key pressed so far has been sent.
  Future<void> get idle => _queue;

  void press(OskKey key) {
    switch (key.kind) {
      case KeyKind.char:
        _text(key.value!);
      case KeyKind.space:
        _text(' ');
      case KeyKind.shift:
        _shift = _shift.next;
        notifyListeners();
      case KeyKind.page:
        setPage(_page == OskPage.letters ? OskPage.symbols : OskPage.letters);
      case KeyKind.more:
        setPage(_page == OskPage.symbols ? OskPage.symbols2 : OskPage.symbols);
      case KeyKind.backspace:
        backspace();
      case KeyKind.enter:
        _send(() => backend.action(OskAction.enter));
      case KeyKind.tab:
        _send(() => backend.action(OskAction.tab));
      case KeyKind.done:
        _send(backend.hide);
    }
  }

  void _text(String s) {
    _send(() => backend.type(s));
    _typed += s;
    // A one-shot shift is used up by the next character.
    if (_shift == ShiftState.once) _shift = ShiftState.off;
    notifyListeners();
  }

  void space() => _text(' ');

  void backspace() {
    _send(() => backend.action(OskAction.backspace));
    if (_typed.isNotEmpty) {
      _typed = String.fromCharCodes(_typed.runes.toList()..removeLast());
      notifyListeners();
    }
  }

  void setPage(OskPage page) {
    if (page == _page) return;
    _page = page;
    notifyListeners();
  }

  /// The `context` button: Shift (one-shot, then caps lock, then off) on the
  /// letters page; on the symbol pages it flips between symbols 1 and 2.
  void context() {
    switch (_page) {
      case OskPage.letters:
        _shift = _shift.next;
        notifyListeners();
      case OskPage.symbols:
        setPage(OskPage.symbols2);
      case OskPage.symbols2:
        setPage(OskPage.symbols);
    }
  }

  @override
  void dispose() {
    _visibility.cancel();
    super.dispose();
  }
}
