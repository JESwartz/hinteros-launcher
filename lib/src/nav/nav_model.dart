/// Pure rules of spatial D-pad navigation, with no Flutter dependency so they
/// can be unit tested exhaustively. [NavRegion] binds a model to focus nodes.
library;

enum NavDir { up, down, left, right }

/// One row of a region: [length] focusable items in a line. A grid is a list
/// of equal rows with a shorter last one.
class NavRow {
  const NavRow(this.key, this.length, {this.spans});

  /// Stable identity, so memory survives rows appearing and disappearing.
  final String key;
  final int length;

  /// For rows of unequal items (a keyboard: wide space bar, narrow letters):
  /// the width of each item in grid units, [length] entries. Up/down then
  /// move to the item above or below, not to the same index (see
  /// [NavGridModel]). Null means all items have width 1.
  final List<int>? spans;

  /// Horizontal centre of item [col] in grid units.
  double centerOf(int col) {
    final s = spans;
    if (s == null) return col + 0.5;
    var x = 0;
    for (var i = 0; i < col; i++) {
      x += s[i];
    }
    return x + s[col] / 2;
  }

  @override
  bool operator ==(Object other) =>
      other is NavRow &&
      other.key == key &&
      other.length == length &&
      _spansEq(other.spans, spans);

  static bool _spansEq(List<int>? a, List<int>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(key, length, Object.hashAll(spans ?? const []));
}

/// Result of [NavGridModel.move]: either the position changed, or the move
/// ran into the [edge] of the region (the caller may hand over to a neighbour).
class NavMoveResult {
  const NavMoveResult.moved() : edge = null;
  const NavMoveResult.edge(NavDir this.edge);

  final NavDir? edge;
  bool get moved => edge == null;
}

/// Position and rules inside one region.
///
/// - Left/right move within the row and stop at its ends (clamp). With
///   [wrapHorizontal] (tab bars) they wrap. They never change row, so a
///   press at the end of a row cannot jump somewhere unexpected.
/// - Up/down move to the neighbouring non-empty row and stop at the first and
///   last row (reported as an edge, so the shell can leave the region).
/// - Column on vertical moves: with [rememberPerRow] (Home: rows of different
///   content) every row remembers the column last focused in it, and a row not
///   visited yet is entered at the current column (clamped). Without it
///   (grids) the column is sticky: the column you aimed for is kept across
///   short rows, so down then up returns to where you started.
/// - Rows with [NavRow.spans] (unequal item widths) move spatially instead: up
///   and down go to the item nearest the horizontal position you aimed for,
///   which is kept across rows like the sticky column.
class NavGridModel {
  NavGridModel({this.rememberPerRow = true, this.wrapHorizontal = false});

  final bool rememberPerRow;
  final bool wrapHorizontal;

  List<NavRow> _rows = const [];
  int _row = 0;
  int _col = 0;
  int _wantedCol = 0;
  double _wantedX = 0.5;
  final Map<String, int> _cols = {};

  List<NavRow> get rows => _rows;
  int get row => _row;
  int get col => _col;
  bool get isEmpty => _rows.every((r) => r.length == 0);
  NavRow? get currentRow => _row < _rows.length ? _rows[_row] : null;

  /// Replaces the rows. The focused row is followed by key (so a row inserted
  /// above does not shift focus); the position is clamped to what exists.
  void setRows(List<NavRow> rows) {
    final currentKey = currentRow?.key;
    _rows = List.unmodifiable(rows);
    final i = currentKey == null
        ? -1
        : _rows.indexWhere((r) => r.key == currentKey);
    _row = i >= 0 ? i : _row.clamp(0, _rows.isEmpty ? 0 : _rows.length - 1);
    if (_rows.isNotEmpty && _rows[_row].length == 0) {
      final first = _rows.indexWhere((r) => r.length > 0);
      if (first >= 0) _row = first;
    }
    _clampCol();
  }

  void _clampCol() {
    final len = currentRow?.length ?? 0;
    _col = len == 0 ? 0 : _col.clamp(0, len - 1);
  }

  /// Puts the position at ([row], [col]) (clamped), as a focus change does.
  void goTo(int row, int col) {
    if (_rows.isEmpty) return;
    _row = row.clamp(0, _rows.length - 1);
    final len = _rows[_row].length;
    _col = len == 0 ? 0 : col.clamp(0, len - 1);
    _wantedCol = _col;
    _wantedX = _rows[_row].centerOf(_col);
    _cols[_rows[_row].key] = _col;
  }

  /// Back to the first item and forget all column memory.
  void reset() {
    _cols.clear();
    _wantedCol = 0;
    _wantedX = _rows.isEmpty ? 0.5 : _rows[0].centerOf(0);
    _col = 0;
    final first = _rows.indexWhere((r) => r.length > 0);
    _row = first < 0 ? 0 : first;
  }

  /// The item of [row] under position [x]; past either end, the end item.
  static int _nearest(NavRow row, double x) {
    var start = 0;
    for (var i = 0; i < row.length; i++) {
      final end = start + (row.spans?[i] ?? 1);
      if (x < end) return i;
      start = end;
    }
    return row.length - 1;
  }

  NavMoveResult move(NavDir dir) {
    final cur = currentRow;
    if (cur == null || cur.length == 0) return NavMoveResult.edge(dir);
    switch (dir) {
      case NavDir.left:
      case NavDir.right:
        final d = dir == NavDir.left ? -1 : 1;
        var next = _col + d;
        if (next < 0 || next >= cur.length) {
          if (!wrapHorizontal || cur.length < 2) return NavMoveResult.edge(dir);
          next = next < 0 ? cur.length - 1 : 0;
        }
        goTo(_row, next);
        return const NavMoveResult.moved();
      case NavDir.up:
      case NavDir.down:
        final d = dir == NavDir.up ? -1 : 1;
        var r = _row + d;
        while (r >= 0 && r < _rows.length && _rows[r].length == 0) {
          r += d;
        }
        if (r < 0 || r >= _rows.length) return NavMoveResult.edge(dir);
        _cols[cur.key] = _col;
        final target = _rows[r];
        final int c;
        if (cur.spans != null || target.spans != null) {
          c = _nearest(target, _wantedX);
        } else if (rememberPerRow) {
          c = (_cols[target.key] ?? _col).clamp(0, target.length - 1);
        } else {
          c = _wantedCol.clamp(0, target.length - 1);
        }
        _row = r;
        _col = c;
        if (rememberPerRow) _wantedCol = c;
        if (cur.spans != null || target.spans != null) _cols[target.key] = c;
        return const NavMoveResult.moved();
    }
  }
}
