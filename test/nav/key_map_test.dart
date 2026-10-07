import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/key_map.dart';

void main() {
  test('outside text fields: arrows, Enter = A, Backspace and Escape = B', () {
    NavAction? f(LogicalKeyboardKey key) => navActionForKey(key);
    expect(f(LogicalKeyboardKey.arrowUp), NavAction.up);
    expect(f(LogicalKeyboardKey.arrowDown), NavAction.down);
    expect(f(LogicalKeyboardKey.arrowLeft), NavAction.left);
    expect(f(LogicalKeyboardKey.arrowRight), NavAction.right);
    expect(f(LogicalKeyboardKey.enter), NavAction.accept);
    expect(f(LogicalKeyboardKey.numpadEnter), NavAction.accept);
    expect(f(LogicalKeyboardKey.escape), NavAction.back);
    expect(f(LogicalKeyboardKey.backspace), NavAction.back);
    expect(f(LogicalKeyboardKey.pageUp), NavAction.pageLeft);
    expect(f(LogicalKeyboardKey.pageDown), NavAction.pageRight);
    expect(f(LogicalKeyboardKey.keyY), NavAction.context);
    expect(f(LogicalKeyboardKey.keyX), NavAction.secondary);
    expect(f(LogicalKeyboardKey.contextMenu), NavAction.context);
    expect(f(LogicalKeyboardKey.keyQ), isNull);
    expect(f(LogicalKeyboardKey.tab), isNull, reason: 'Tab is focus traversal');
  });

  test('F1 is the View button only where asked for', () {
    expect(navActionForKey(LogicalKeyboardKey.f1), isNull);
    expect(navActionForKey(LogicalKeyboardKey.f1, view: true), NavAction.view);
  });

  test('in a text field: Backspace and letters are the field\'s', () {
    NavAction? f(LogicalKeyboardKey key) =>
        navActionForKey(key, inTextField: true);
    expect(f(LogicalKeyboardKey.backspace), isNull);
    expect(f(LogicalKeyboardKey.keyY), isNull);
    expect(f(LogicalKeyboardKey.keyX), isNull);
    // Enter submits, Escape is back, the arrows still move.
    expect(f(LogicalKeyboardKey.enter), NavAction.accept);
    expect(f(LogicalKeyboardKey.escape), NavAction.back);
    expect(f(LogicalKeyboardKey.arrowDown), NavAction.down);
  });
}
