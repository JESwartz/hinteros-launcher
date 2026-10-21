import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../system/repositories.dart';

/// The Server tab's data: the last `services.list` (icons included), read again
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

  /// The box's time zone, from the shell (the top bar clock's): dates on
  /// the pages are in it. Null: the process's own zone.
  TimeZoneInfo? zone;

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
    } catch (e) {
      if (_disposed || seq != _requested) return;
      error = e;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
