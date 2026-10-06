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
/// - A security update (a severity) shows the full-screen notice instead,
///   at startup and on every return to Home, until it is installed (the
///   owner's decision: no throttling).
class UpdateReminders extends ChangeNotifier {
  UpdateReminders(
    this.updates, {
    this.retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 45),
      Duration(seconds: 120),
    ],
  });

  final UpdatesRepository updates;

  /// Waits before each retry of a startup check that found the system service
  /// missing.
  final List<Duration> retryDelays;

  bool _started = false;
  StreamSubscription<UpdateStatus>? _sub;

  /// The update the box is behind by, if any.
  AvailableUpdate? get update => updates.status.available;
  bool get behind => update != null;

  /// Startup check; failures (offline, the update server down) are not shown
  /// here: Settings -> Updates says so when asked.
  /// When the system service is not there yet (it can start after the
  /// session) the check is tried again after a few seconds, a few times.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = updates.changes.listen((_) => notifyListeners());
    await _check(0);
    notifyListeners();
  }

  Timer? _retry;
  bool _disposed = false;

  Future<void> _check(int attempt) async {
    try {
      await updates.check();
    } on SystemException catch (e) {
      if (e.kind == SystemErrorKind.unavailable &&
          attempt < retryDelays.length &&
          !_disposed) {
        _retry = Timer(retryDelays[attempt], () async {
          await _check(attempt + 1);
          if (!_disposed) {
            notifyListeners();
            onLateResult?.call();
          }
        });
      }
    } catch (_) {
      // Nothing else depends on the update server.
    }
  }

  /// A retry after startup finished (the shell shows the notice if due).
  VoidCallback? onLateResult;

  /// The Home screen is entered (or startup finished): true when the
  /// full-screen security notice is due, which is every time while a
  /// security update is pending.
  bool securityNoticeDue() {
    final u = update;
    return u != null && u.isSecurity;
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
