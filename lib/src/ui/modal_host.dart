import 'dart:async';

import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';

/// What a modal sees of itself: its own [NavRegion] (put the buttons in it),
/// a way to close with a result, and whether Back may close it.
class ModalHandle<T> {
  ModalHandle._(this.region, this._close);

  /// The region that holds focus while this modal is on top. It has no
  /// neighbours, so focus never leaves the modal. Keep at least one item in it.
  final NavRegion region;
  final void Function(T? result) _close;

  /// Whether Back closes the modal (with a null result). Null means yes.
  /// The security notice says no for its first five seconds.
  bool Function()? canBack;

  void close([T? result]) => _close(result);
}

typedef ModalBuilder<T> = Widget Function(
  BuildContext context,
  ModalHandle<T> modal,
);

class _Entry {
  _Entry(this.id, this.region, this.build, this.completer, this.previous);

  final int id;
  final NavRegion region;
  final Widget Function(BuildContext) build;
  final Completer<Object?> completer;

  /// The region that held focus before the modal opened.
  final NavRegion? previous;
}

/// A stack of full-screen pages and dialogs drawn over a screen, each with its
/// own [NavRegion]. The one on top takes all input; Back closes it (unless it
/// says otherwise). Used by the shell, and reusable by any host with a
/// [NavController] (the installer, later).
class ModalController extends ChangeNotifier {
  ModalController(this.nav);

  final NavController nav;
  final _stack = <_Entry>[];
  int _nextId = 0;

  bool get isOpen => _stack.isNotEmpty;
  int get depth => _stack.length;

  /// The region of the modal on top, if any.
  NavRegion? get topRegion => _stack.isEmpty ? null : _stack.last.region;

  /// Shows [builder] over everything, resolving with what the modal passes to
  /// [ModalHandle.close] (null when closed with Back).
  Future<T?> show<T>(ModalBuilder<T> builder) => open(builder).result;

  /// Like [show], and also gives the handle, so the host can close the modal
  /// itself (an event said it is over).
  ({ModalHandle<T> handle, Future<T?> result}) open<T>(
    ModalBuilder<T> builder,
  ) {
    final id = _nextId++;
    final region = NavRegion('modal-$id', rememberPerRow: false)
      ..holdsBack = true;
    nav.adopt(region);
    final completer = Completer<Object?>();
    late final _Entry entry;
    final handle = ModalHandle<T>._(region, (r) => _close(entry, r));
    region.onBack = () {
      if (handle.canBack?.call() ?? true) handle.close();
      return true;
    };
    entry = _Entry(
      id,
      region,
      (c) => builder(c, handle),
      completer,
      nav.active,
    );
    _stack.add(entry);
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stack.contains(entry) && _stack.last == entry) {
        nav.focusRegion(region);
      }
    });
    return (handle: handle, result: completer.future.then((v) => v as T?));
  }

  void _close(_Entry e, Object? result) {
    if (!_stack.remove(e) || e.completer.isCompleted) return;
    e.completer.complete(result);
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Decided now, not at close time: the caller may have opened the next
      // page (a progress page after a form) in between.
      final next = _stack.isEmpty ? null : _stack.last.region;
      var back = next ?? e.previous;
      // Nothing was focused before it opened: where the host starts.
      if (back == null || back == e.region) back = nav.fallback?.call();
      if (back != null) {
        if (back.hasItems || next != null) nav.focusRegion(back);
      }
      if (nav.active == e.region) nav.active = null;
      // The nodes are no longer in the tree after this frame.
      e.region.dispose();
    });
  }

  /// Closes every modal (the Home button).
  void closeAll() {
    for (final e in _stack.toList().reversed) {
      _close(e, null);
    }
  }
}

/// Gives descendants access to the [ModalController].
class ModalScope extends InheritedWidget {
  const ModalScope({super.key, required this.controller, required super.child});

  final ModalController controller;

  static ModalController of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<ModalScope>();
    assert(s != null, 'No ModalScope above this context');
    return s!.controller;
  }

  @override
  bool updateShouldNotify(ModalScope old) => controller != old.controller;
}

/// Draws [child] with the modals of [controller] stacked over it.
class ModalHost extends StatelessWidget {
  const ModalHost({super.key, required this.controller, required this.child});

  final ModalController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ModalScope(
      controller: controller,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Stack(
              children: [
                for (final e in controller._stack)
                  Positioned.fill(key: ValueKey(e.id), child: e.build(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
