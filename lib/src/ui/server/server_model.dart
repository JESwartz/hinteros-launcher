import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../system/repositories.dart';

/// The Server tab's data: the last `services.list` and the icons, read again
/// when a job of the section ends, the connection comes back, or a page
/// asks. The shell owns it, so a service page and the tab under it show the
/// same list.
class ServerModel extends ChangeNotifier {
  ServerModel(this.repo);

  final ServerRepository repo;

  /// The last list; null until the first answer.
  ServerList? list;

  /// Why the last read failed (null after one that worked).
  Object? error;

  /// Icon paths by service id (null: the letter tile).
  final icons = <String, String?>{};

  StreamSubscription<void>? _sub;
  int _requested = 0;
  bool _disposed = false;

  /// Reads the list the first time the tab shows, and from then on follows
  /// [ServerRepository.changes].
  void start() {
    if (_sub != null) return;
    _sub = repo.changes.listen((_) => unawaited(reload()));
    unawaited(reload());
  }

  ServerService? byId(String id) => list?.byId(id);

  /// `services.list`; an answer older than one already shown is dropped.
  Future<void> reload() async {
    final seq = ++_requested;
    try {
      final l = await repo.list();
      if (_disposed || seq != _requested) return;
      list = l;
      error = null;
      _resolveIcons(l);
    } catch (e) {
      if (_disposed || seq != _requested) return;
      error = e;
    }
    notifyListeners();
  }

  void _resolveIcons(ServerList l) {
    for (final s in l.services) {
      if (icons.containsKey(s.id)) continue;
      icons[s.id] = null;
      unawaited(
        repo.resolveIcon(s).then((p) {
          if (_disposed || p == null) return;
          icons[s.id] = p;
          notifyListeners();
        }, onError: (_) {}),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
