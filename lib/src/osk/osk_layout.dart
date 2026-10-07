/// The key layouts of the on-screen keyboard (US, see spike 5): data only.
library;

enum OskPage { letters, symbols, symbols2 }

/// Shift: one key (one-shot) or caps lock.
enum ShiftState {
  off,
  once,
  caps;

  /// Shift key press: off, one-shot, caps lock, off.
  ShiftState get next => switch (this) {
    off => once,
    once => caps,
    caps => off,
  };
}

enum KeyKind {
  /// Types [OskKey.value].
  char,
  space,
  shift,

  /// Letters <-> symbols.
  page,

  /// Symbols 1 <-> 2.
  more,
  backspace,
  enter,
  tab,

  /// Hides the keyboard.
  done,
}

class OskKey {
  const OskKey(this.kind, this.label, {this.value, this.span = 2});

  const OskKey.char(String c, {int span = 2})
    : this(KeyKind.char, c, value: c, span: span);

  final KeyKind kind;
  final String label;

  /// The text for [KeyKind.char].
  final String? value;

  /// Width in grid units; every row adds up to [oskGridUnits].
  final int span;
}

/// Grid units per row.
const oskGridUnits = 20;

List<OskKey> _chars(String s, {int span = 2}) => [
  for (final c in s.split('')) OskKey.char(c, span: span),
];

/// A row of keys. The [id] is the navigation row key: the control row is
/// always `bottom`, and the "more" key of both symbol pages is in `r3`, so
/// focus stays on the same key when a page changes under it.
class OskRow {
  const OskRow(this.id, this.keys);

  final String id;
  final List<OskKey> keys;

  List<int> get spans => [for (final k in keys) k.span];
}

List<OskRow> oskLayout(OskPage page, ShiftState shift) {
  final upper = shift != ShiftState.off;
  String l(String s) => upper ? s.toUpperCase() : s;
  final digits = _chars('1234567890');
  OskKey control(KeyKind k, String label, int span) =>
      OskKey(k, label, span: span);
  List<OskKey> bottom(String pageLabel) => [
    control(KeyKind.page, pageLabel, 3),
    control(KeyKind.tab, 'Tab', 2),
    control(KeyKind.space, 'Space', 7),
    control(KeyKind.backspace, 'Backspace', 3),
    control(KeyKind.enter, 'Enter', 3),
    control(KeyKind.done, 'Done', 2),
  ];
  switch (page) {
    case OskPage.letters:
      return [
        OskRow('r0', digits),
        OskRow('r1', _chars(l('qwertyuiop'))),
        OskRow('r2', _chars(l("asdfghjkl'"))),
        OskRow('r3', [
          OskKey(KeyKind.shift, switch (shift) {
            ShiftState.off || ShiftState.once => 'Shift',
            ShiftState.caps => 'Caps',
          }, span: 4),
          ..._chars(l('zxcvbnm')),
          const OskKey.char('.'),
        ]),
        OskRow('bottom', bottom('?123')),
      ];
    case OskPage.symbols:
      return [
        OskRow('r0', digits),
        OskRow('r1', _chars('!@#\$%^&*()')),
        OskRow('r2', _chars('-_=+/\\|?:;')),
        OskRow('r3', [
          control(KeyKind.more, 'More 1/2', 6),
          ..._chars('\'",.<>~'),
        ]),
        OskRow('bottom', bottom('abc')),
      ];
    case OskPage.symbols2:
      return [
        OskRow('r0', digits),
        OskRow('r1', _chars('[]{}`', span: 4)),
        OskRow('r3', [control(KeyKind.more, 'More 2/2', 6)]),
        OskRow('bottom', bottom('abc')),
      ];
  }
}

/// Where a key sits: the page it is on and its row (index into
/// [oskLayout]) and column.
typedef OskKeyPos = ({OskPage page, int row, int col});

/// The key a physical key press corresponds to, for visual feedback only:
/// a printable [char] (case ignored for letters, so a capital finds the same
/// key), or else a [kind] (Space, Backspace, Enter, Tab). The current [page]
/// is preferred, so a key that is on this page stays where it is; otherwise
/// the first page that has it. Null when the keyboard has no such key.
OskKeyPos? oskLocate({
  String? char,
  KeyKind? kind,
  required OskPage page,
  required ShiftState shift,
}) {
  final pages = [page, ...OskPage.values.where((p) => p != page)];
  for (final p in pages) {
    final rows = oskLayout(p, shift);
    for (var r = 0; r < rows.length; r++) {
      final keys = rows[r].keys;
      for (var c = 0; c < keys.length; c++) {
        final k = keys[c];
        final hit = kind != null
            ? k.kind == kind
            : k.kind == KeyKind.char &&
                  char != null &&
                  k.value!.toLowerCase() == char.toLowerCase();
        if (hit) return (page: p, row: r, col: c);
      }
    }
  }
  return null;
}
