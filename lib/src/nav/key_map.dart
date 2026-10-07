import 'package:flutter/services.dart';

import '../api/api.dart' show NavAction;

/// The keyboard as a controller: one table for the launcher shell and the
/// installer, so the two cannot drift apart.
///
/// Arrows move, Enter accepts (A), Escape and Backspace go back (B), PageUp
/// and PageDown are the bumpers, Y and X are context and secondary, F1 is the
/// View button ([view], installer only).
///
/// [inTextField]: a text field has the focus. Then letters and Backspace are
/// text (Y, X and Backspace map to nothing and the field gets them); Enter,
/// Escape and the arrows stay what they are.
NavAction? navActionForKey(
  LogicalKeyboardKey k, {
  bool inTextField = false,
  bool view = false,
}) {
  if (k == LogicalKeyboardKey.arrowLeft) return NavAction.left;
  if (k == LogicalKeyboardKey.arrowRight) return NavAction.right;
  if (k == LogicalKeyboardKey.arrowUp) return NavAction.up;
  if (k == LogicalKeyboardKey.arrowDown) return NavAction.down;
  if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
    return NavAction.accept;
  }
  if (k == LogicalKeyboardKey.escape) return NavAction.back;
  if (k == LogicalKeyboardKey.backspace) {
    return inTextField ? null : NavAction.back;
  }
  if (k == LogicalKeyboardKey.pageUp) return NavAction.pageLeft;
  if (k == LogicalKeyboardKey.pageDown) return NavAction.pageRight;
  if (view && k == LogicalKeyboardKey.f1) return NavAction.view;
  if (inTextField) return null;
  if (k == LogicalKeyboardKey.contextMenu) return NavAction.context;
  if (k == LogicalKeyboardKey.keyY) return NavAction.context;
  if (k == LogicalKeyboardKey.keyX) return NavAction.secondary;
  return null;
}
