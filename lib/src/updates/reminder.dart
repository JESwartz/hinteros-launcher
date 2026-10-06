import 'dart:async';

import 'package:flutter/foundation.dart';

import '../system/models.dart';
import '../system/repositories.dart';

/// Decides when to remind about an update (ROADMAP M6, threat-model
/// decision 2). Never installs anything.
///
/// - At startup the box checks once. When it is behind its channel, an
///   ordinary update shows a non-modal reminder on Home, again on every
///   return to Home ([enteredHome] resets it).
/// - A security update (a severity) shows the full-screen notice instead:
///   at startup, and after that on a return to Home once at least
///   [securityInterval] has passed since the last notice (Home is visited
///   after every game; a lockout each time would punish the user for
///   closing a game). Between notices it shows as the reminder, marked as
///   a security update.
class UpdateReminders extends ChangeNotifier {
  UpdateReminders(
    this.updates, {
    DateTime Function()? now,
    this.securityInterval = const Duration(minutes: 30),
  }) : _now = now ?? DateTime.now;

  final UpdatesRepository updates;
  final DateTime Function() _now;
  final Duration securityInterval;

  DateTime? _lastNotice;
  bool _started = false;
  StreamSubscription<UpdateStatus>? _sub;

  /// The update the box is behind by, if any.
  AvailableUpdate? get update => updates.status.available;
  bool get behind => update != null;

  /// Startup check; failures (offline, the update server down) are not shown
  /// here: Settings -> Updates says so when asked.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = updates.changes.listen((_) => notifyListeners());
    try {
      await updates.check();
    } catch (_) {
      // Nothing else depends on the update server.
    }
    notifyListeners();
  }

  /// The Home screen is entered (or startup finished): true when the
  /// full-screen security notice is due now. Marks it as shown.
  bool securityNoticeDue() {
    final u = update;
    if (u == null || !u.isSecurity) return false;
    final last = _lastNotice;
    if (last != null && _now().difference(last) < securityInterval) {
      return false;
    }
    _lastNotice = _now();
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
