import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/nav/nav_model.dart';

NavGridModel home() =>
    NavGridModel()
      ..setRows(const [NavRow('a', 5), NavRow('b', 3), NavRow('c', 8)]);

void main() {
  group('horizontal', () {
    test('moves within a row and clamps at both ends', () {
      final m = home();
      expect(m.move(NavDir.left).edge, NavDir.left);
      expect((m.row, m.col), (0, 0));
      for (var i = 0; i < 4; i++) {
        expect(m.move(NavDir.right).moved, isTrue);
      }
      expect(m.col, 4);
      expect(m.move(NavDir.right).edge, NavDir.right);
      expect((m.row, m.col), (0, 4), reason: 'never jumps to another row');
    });

    test('wraps when asked (tab bars)', () {
      final m = NavGridModel(wrapHorizontal: true)
        ..setRows(const [NavRow('t', 4)]);
      expect(m.move(NavDir.left).moved, isTrue);
      expect(m.col, 3);
      expect(m.move(NavDir.right).moved, isTrue);
      expect(m.col, 0);
    });

    test('a single item does not wrap onto itself', () {
      final m = NavGridModel(wrapHorizontal: true)
        ..setRows(const [NavRow('t', 1)]);
      expect(m.move(NavDir.right).edge, NavDir.right);
    });
  });

  group('vertical with per-row memory', () {
    test('first visit enters at the current column, clamped', () {
      final m = home();
      m.goTo(0, 4);
      m.move(NavDir.down); // b has 3 items
      expect((m.row, m.col), (1, 2));
    });

    test('each row remembers the column last focused in it', () {
      final m = home();
      m.goTo(0, 3);
      m.move(NavDir.down); // b, clamped to 2
      m.move(NavDir.right); // stays 2 (end of b)
      m.goTo(1, 1);
      m.move(NavDir.down); // c entered at 1
      m.goTo(2, 6);
      m.move(NavDir.up); // back in b: remembered 1
      expect((m.row, m.col), (1, 1));
      m.move(NavDir.up); // a: remembered 3
      expect((m.row, m.col), (0, 3));
      m.move(NavDir.down);
      m.move(NavDir.down); // c: remembered 6
      expect((m.row, m.col), (2, 6));
    });

    test('top and bottom are edges, not wraps', () {
      final m = home();
      expect(m.move(NavDir.up).edge, NavDir.up);
      m.goTo(2, 0);
      expect(m.move(NavDir.down).edge, NavDir.down);
      expect(m.row, 2);
    });

    test('empty rows are skipped', () {
      final m = NavGridModel()
        ..setRows(const [NavRow('a', 2), NavRow('b', 0), NavRow('c', 2)]);
      m.move(NavDir.down);
      expect(m.row, 2);
      m.move(NavDir.up);
      expect(m.row, 0);
    });
  });

  group('vertical in grids (sticky column)', () {
    NavGridModel grid() =>
        NavGridModel(rememberPerRow: false)
          ..setRows(const [NavRow('r0', 6), NavRow('r1', 6), NavRow('r2', 2)]);

    test('keeps the wanted column across a short last row', () {
      final m = grid();
      m.goTo(0, 5);
      m.move(NavDir.down);
      m.move(NavDir.down);
      expect((m.row, m.col), (2, 1));
      m.move(NavDir.up);
      m.move(NavDir.up);
      expect((m.row, m.col), (0, 5), reason: 'down then up returns home');
    });

    test('a horizontal move on the short row changes the wanted column', () {
      final m = grid();
      m.goTo(0, 5);
      m.move(NavDir.down);
      m.move(NavDir.down);
      m.move(NavDir.left);
      m.move(NavDir.up);
      expect((m.row, m.col), (1, 0));
    });
  });

  group('changing rows', () {
    test('the focused row is followed by key when rows are inserted above', () {
      final m = home()..goTo(1, 2);
      m.setRows(const [
        NavRow('new', 4),
        NavRow('a', 5),
        NavRow('b', 3),
        NavRow('c', 8),
      ]);
      expect((m.row, m.col), (2, 2));
    });

    test('position is clamped when a row shrinks or goes away', () {
      final m = home()..goTo(2, 7);
      m.setRows(const [NavRow('a', 5), NavRow('b', 3), NavRow('c', 4)]);
      expect((m.row, m.col), (2, 3));
      m.setRows(const [NavRow('a', 5)]);
      expect(m.row, 0);
    });

    test('reset goes to the first item and forgets memory', () {
      final m = home()
        ..goTo(0, 3)
        ..move(NavDir.down)
        ..goTo(2, 6);
      m.reset();
      expect((m.row, m.col), (0, 0));
      m.move(NavDir.right);
      m.move(NavDir.right);
      m.move(NavDir.down);
      expect(m.col, 2, reason: 'row b has no memory after reset');
    });

    test('an empty model reports edges', () {
      final m = NavGridModel();
      expect(m.isEmpty, isTrue);
      expect(m.move(NavDir.down).edge, NavDir.down);
    });
  });
}
