import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/api.dart';
import 'nav_model.dart';

/// A group of focusable items navigated as one unit (a row of cards, a grid,
/// a tab bar, a list). It binds a pure [NavGridModel] to real [FocusNode]s, so
/// Flutter's focus system still decides what is focused; the model only
/// decides where D-pad moves go.
///
/// Regions are linked with [neighbors]: when a move runs off the edge of a
/// region, focus is handed to the neighbour on that side (entering at that
/// region's remembered position). [backTarget] is where Back goes.
class NavRegion extends ChangeNotifier {
  NavRegion(this.id, {bool rememberPerRow = true, bool wrapHorizontal = false})
    : model = NavGridModel(
        rememberPerRow: rememberPerRow,
        wrapHorizontal: wrapHorizontal,
      );

  final String id;
  final NavGridModel model;

  /// Called before focusing an item that is not built (lazy lists): scroll it
  /// into existence.
  FutureOr<void> Function(int row, int col)? onRevealHook;

  /// Region to move to when a move leaves this region in that direction.
  final Map<NavDir, NavRegion> neighbors = {};

  /// Region Back moves to, if any. If null, Back falls through to
  /// [NavController.onBack].
  NavRegion? backTarget;

  /// Back handler for this region; takes precedence over [backTarget].
  bool Function()? onBack;

  /// Asked first on every direction press or repeat while this region holds
  /// focus; return true to consume it (a scroll area scrolling, a slider
  /// stepping) instead of moving focus.
  bool Function(NavDir dir)? interceptMove;

  /// Asked first on other actions (page left/right, secondary, ...) while
  /// this region holds focus; return true to consume them.
  bool Function(NavAction action)? onAction;

  final Map<String, FocusNode> _nodes = {};
  final Map<String, VoidCallback?> _selects = {};
  final Map<String, VoidCallback?> _contexts = {};
  bool _pendingFocus = false;
  bool _awaitingRows = false;
  NavController? _controller;

  FocusNode nodeAt(String rowKey, int col) => _nodes.putIfAbsent(
    '$rowKey:$col',
    () => FocusNode(debugLabel: '$id/$rowKey:$col'),
  );

  bool get hasItems => !model.isEmpty;

  /// Replaces the rows. Notifies listeners when the shape changes.
  void setRows(List<NavRow> rows) {
    final before = model.rows;
    final pos = (model.row, model.col);
    model.setRows(rows);
    if (_awaitingRows && hasItems) {
      _awaitingRows = false;
      scheduleMicrotask(focusCurrent);
    }
    if (!_listEq(before, model.rows) || pos != (model.row, model.col)) {
      scheduleMicrotask(notifyListeners);
    }
  }

  static bool _listEq(List<NavRow> a, List<NavRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Registered by items: what accept does on them.
  void registerSelect(String rowKey, int col, VoidCallback? onSelect) =>
      _selects['$rowKey:$col'] = onSelect;

  void unregisterSelect(String rowKey, int col) =>
      _selects.remove('$rowKey:$col');

  /// Registered by items that have a context action (the `context` button,
  /// Y/Triangle): what it does on them.
  void registerContext(String rowKey, int col, VoidCallback? onContext) {
    if (onContext == null) {
      _contexts.remove('$rowKey:$col');
    } else {
      _contexts['$rowKey:$col'] = onContext;
    }
  }

  /// An item received focus (by us or otherwise): the model follows.
  void noteFocused(String rowKey, int col) {
    final r = model.rows.indexWhere((x) => x.key == rowKey);
    if (r < 0) return;
    final changed = model.row != r || model.col != col;
    // Only when focus moved by other means; our own moves already updated the
    // model (and goTo would overwrite the sticky column).
    if (changed) model.goTo(r, col);
    _controller?.active = this;
    if (changed) notifyListeners();
  }

  /// If focus was requested before the item was built, the item calls this
  /// after its first build.
  void itemBuilt(String rowKey, int col) {
    if (!_pendingFocus) return;
    final cur = model.currentRow;
    if (cur != null && cur.key == rowKey && model.col == col) {
      _pendingFocus = false;
      nodeAt(rowKey, col).requestFocus();
    }
  }

  /// Moves focus to the model's current item.
  Future<void> focusCurrent() async {
    final cur = model.currentRow;
    if (cur == null || cur.length == 0) return;
    _controller?.active = this;
    final row = model.row, col = model.col;
    final node = nodeAt(cur.key, col);
    if (node.context == null) {
      await onRevealHook?.call(row, col);
      if (model.row != row || model.col != col) return; // superseded
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (node.context == null) {
        _pendingFocus = true;
        return;
      }
    }
    node.requestFocus();
  }

  /// Tells listeners the model position changed (the controller moved it).
  void changed() => notifyListeners();

  /// Focus this region as soon as it has items, if that happens within the
  /// current frame (a section that was just switched to and is still building).
  void focusWhenPopulated() {
    _awaitingRows = true;
    _controller?.active = this;
    WidgetsBinding.instance.endOfFrame.then((_) => _awaitingRows = false);
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Back to the first item.
  void reset() {
    model.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }
}

/// Routes [NavAction]s (from the keyboard or the daemon's `input_nav`) over a
/// set of linked [NavRegion]s. This is the single action layer; screens never
/// handle keys themselves, they only declare regions and items.
///
/// Presses and repeats move focus; only a press accepts or goes back; releases
/// never act. Other actions go to [onOther].
class NavController {
  NavController({this.onBack, this.onOther});

  /// The region that holds (or last held) focus.
  NavRegion? active;

  /// Back with nowhere left to go inside the current region tree: the shell
  /// returns to the Home tab. Return false if nothing was done.
  bool Function()? onBack;

  /// Where focus goes when a direction is pressed while nothing in a region
  /// holds it (no items yet, or the focused item was removed).
  NavRegion? Function()? fallback;

  /// Actions the controller does not interpret (page left/right, menu, ...).
  void Function(NavAction action)? onOther;

  /// Attach [region] to this controller. Call once per region.
  void adopt(NavRegion region) => region._controller = this;

  /// Focuses [region] at its remembered position.
  void focusRegion(NavRegion region) {
    if (!region.hasItems) {
      region.focusWhenPopulated();
      return;
    }
    active = region;
    unawaited(region.focusCurrent());
  }

  /// Returns true if the action was consumed.
  bool dispatch(NavAction action, NavPhase phase) {
    if (phase == NavPhase.release || phase == NavPhase.unknown) return false;
    final region = active;
    switch (action) {
      case NavAction.up || NavAction.down || NavAction.left || NavAction.right:
        if (region == null || !region.hasItems) {
          final f = fallback?.call();
          if (f == null) return false;
          focusRegion(f);
          return true;
        }
        final dir = NavDir.values.byName(action.name);
        if (region.interceptMove?.call(dir) ?? false) return true;
        final r = region.model.move(dir);
        if (r.moved) {
          region.changed();
          unawaited(region.focusCurrent());
        } else {
          final n = region.neighbors[dir];
          if (n != null && n.hasItems) focusRegion(n);
        }
        return true;
      case NavAction.accept:
        if (phase != NavPhase.press || region == null) return false;
        final cur = region.model.currentRow;
        if (cur == null) return false;
        final cb = region._selects['${cur.key}:${region.model.col}'];
        cb?.call();
        return cb != null;
      case NavAction.context:
        if (phase != NavPhase.press || region == null) return false;
        final cur = region.model.currentRow;
        if (cur == null) return false;
        final cb = region._contexts['${cur.key}:${region.model.col}'];
        cb?.call();
        return cb != null;
      case NavAction.back:
        if (phase != NavPhase.press) return false;
        if (region?.onBack != null && region!.onBack!()) return true;
        final t = region?.backTarget;
        if (t != null && t.hasItems) {
          focusRegion(t);
          return true;
        }
        return onBack?.call() ?? false;
      default:
        if (phase != NavPhase.press) return false;
        if (region?.onAction?.call(action) ?? false) return true;
        onOther?.call(action);
        return false;
    }
  }
}
