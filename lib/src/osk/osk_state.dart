import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'osk_backend.dart';
import 'osk_layout.dart';

/// The bullet that stands for a typed character in the masked preview.
const oskMaskChar = '•';

/// What the keyboard is showing and what pressing a key does. All output goes
/// through the [OskBackend], in order; the OSK never has a text field of its
/// own, [typed] is only a preview (masked unless [showTyped]).
class OskState extends ChangeNotifier {
  OskState(
    this.backend, {
    this.revealFor = const Duration(seconds: 1),
    this.noticeFor = const Duration(seconds: 4),
  }) {
    _visibility = backend.visibility.listen((visible) {
      if (!visible) reset();
    });
  }

  final OskBackend backend;

  /// How long the newest typed character stays readable in the masked preview.
  final Duration revealFor;

  /// How long a notice or an error stays in the strip.
  final Duration noticeFor;

  late final StreamSubscription<bool> _visibility;

  OskPage _page = OskPage.letters;
  ShiftState _shift = ShiftState.off;
  String _typed = '';
  String? _error;
  String? _notice;
  bool _showTyped = false;
  bool _reveal = false;
  Timer? _revealTimer;
  Timer? _noticeTimer;
  Future<void> _queue = Future.value();

  OskPage get page => _page;
  ShiftState get shift => _shift;

  /// What was typed since the keyboard last opened (backspace takes characters
  /// off). Never put this on screen without checking [showTyped]: it may be a
  /// password.
  String get typed => _typed;

  /// Why the last key did not arrive (the daemon said no, or is too old).
  /// Goes away by itself after [noticeFor], or with the next key that works.
  String? get error => _error;

  /// A short note that is not a failure (characters the daemon could not
  /// type). Goes away by itself.
  String? get notice => _notice;

  /// Whether the preview shows the typed text (the setting "Show typed text
  /// on the on-screen keyboard"). Off: dots, apart from the newest character
  /// for [revealFor].
  bool get showTyped => _showTyped;
  set showTyped(bool v) {
    if (v == _showTyped) return;
    _showTyped = v;
    notifyListeners();
  }

  /// What the preview strip shows.
  String get preview {
    if (_showTyped) return _typed;
    final chars = _typed.runes.map(String.fromCharCode).toList();
    return [
      for (var i = 0; i < chars.length; i++)
        (_reveal && i == chars.length - 1) ? chars[i] : oskMaskChar,
    ].join();
  }

  List<OskRow> get rows => oskLayout(_page, _shift);

  /// Back to letters, shift off, empty preview: the keyboard was closed.
  void reset() {
    _page = OskPage.letters;
    _shift = ShiftState.off;
    _typed = '';
    _error = null;
    _notice = null;
    _reveal = false;
    _revealTimer?.cancel();
    _noticeTimer?.cancel();
    notifyListeners();
  }

  void _flash({String? error, String? notice}) {
    _error = error;
    _notice = notice;
    _noticeTimer?.cancel();
    if (error != null || notice != null) {
      _noticeTimer = Timer(noticeFor, () {
        _error = null;
        _notice = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  static String _describe(Object e) {
    if (e is UnsupportedError) return '${e.message}';
    if (e is ApiException) {
      return e.code == ApiErrorCode.keyboardUnavailable
          ? 'No keyboard available: keys cannot be sent'
          : e.message;
    }
    return '$e';
  }

  void _send(Future<void> Function() call) {
    _queue = _queue.then((_) => call()).then((_) {
      if (_error != null) _flash();
    }, onError: (Object e) => _flash(error: _describe(e)));
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
    _queue = _queue.then((_) => backend.type(s)).then((untypeable) {
      if (_error != null) _flash();
      if (untypeable.isNotEmpty) {
        // The characters stay secret unless the preview is switched on.
        _flash(
          notice: _showTyped
              ? 'Cannot type: ${untypeable.join(' ')}'
              : '${untypeable.length} character(s) cannot be typed',
        );
      }
    }, onError: (Object e) => _flash(error: _describe(e)));
    _typed += s;
    _reveal = true;
    _revealTimer?.cancel();
    _revealTimer = Timer(revealFor, () {
      _reveal = false;
      notifyListeners();
    });
    // A one-shot shift is used up by the next character.
    if (_shift == ShiftState.once) _shift = ShiftState.off;
    notifyListeners();
  }

  void space() => _text(' ');

  /// Starts the preview with text that is already in the field (the in-app
  /// keyboard of the installer edits existing values), so Backspace and the
  /// preview agree with the field.
  void seed(String text) {
    _typed = text;
    notifyListeners();
  }

  void backspace() {
    _send(() => backend.action(OskAction.backspace));
    _reveal = false;
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
    _revealTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}
