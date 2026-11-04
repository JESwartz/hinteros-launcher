import 'dart:async';

import 'package:flutter/foundation.dart';

import '../system/models.dart';
import '../system/repositories.dart';

/// Decides when to remind about an update (ROADMAP M6, threat-model
/// decision 2). Never installs anything.
///
/// - At startup the box checks. A check that fails (no network yet, the
///   update server down) is tried again when the network comes up, and
///   every day the session lasts the box checks again.
/// - When it is behind its channel, an ordinary update shows a non-modal
///   reminder on Home, again on every return to Home (the shell's
///   `_homeEntered`).
/// - A security update (a severity) shows the full-screen notice instead,
///   at startup and on every return to Home, until it is installed (the
///   owner's decision: no throttling).
class UpdateReminders extends ChangeNotifier {
  UpdateReminders(
    this.updates, {
    this.network,
    this.retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 45),
      Duration(seconds: 120),
    ],
    this.recheckAfter = const Duration(hours: 24),
    this.tick = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final UpdatesRepository updates;

  /// `network_changed`: a check that failed is tried again when the
  /// connection reaches the internet.
  final Stream<NetworkStatus>? network;

  /// Waits before each retry of a startup check that found the system service
  /// missing.
  final List<Duration> retryDelays;

  /// How old the last good check may be before the box checks again.
  final Duration recheckAfter;

  /// How often the age of the last good check is looked at. A timer does
  /// not count the time the box sleeps, so a long [recheckAfter] is measured
  /// on the clock instead.
  final Duration tick;
  final DateTime Function() _now;

  bool _started = false;
  StreamSubscription<UpdateStatus>? _sub;
  StreamSubscription<NetworkStatus>? _netSub;
  Timer? _ticker;

  /// When the last check worked; null: none has yet.
  DateTime? _checkedAt;
  bool _checking = false;
  bool _wasOnline = false;

  /// The network came up during a check: check again if that one failed.
  bool _againAfter = false;

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
    _netSub = network?.listen((s) {
      // `unknown`: NetworkManager does not check; a connection is enough.
      final online =
          s.connectivity == Connectivity.full ||
          (s.connectivity == Connectivity.unknown && s.online);
      final up = online && !_wasOnline;
      _wasOnline = online;
      if (!up || _checkedAt != null) return;
      if (_checking) {
        _againAfter = true;
      } else {
        unawaited(_again());
      }
    });
    _ticker = Timer.periodic(tick, (_) {
      final at = _checkedAt;
      if (at == null) return unawaited(_again());
      // A clock set back counts as old too.
      final age = _now().difference(at);
      if (age.isNegative || age >= recheckAfter) unawaited(_again());
    });
    await _check(0);
    if (_disposed) return;
    notifyListeners();
  }

  Timer? _retry;
  bool _disposed = false;

  /// A check after startup; the shell shows the notice if it is due.
  Future<void> _again() async {
    if (_checking || _disposed || (_retry?.isActive ?? false)) return;
    await _check(retryDelays.length);
    if (!_disposed) {
      notifyListeners();
      onLateResult?.call();
    }
  }

  Future<void> _check(int attempt) async {
    _checking = true;
    try {
      await updates.check();
      _checkedAt = _now();
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
    } finally {
      _checking = false;
    }
    if (_againAfter) {
      _againAfter = false;
      if (_checkedAt == null) unawaited(Future(_again));
    }
  }

  /// A check after startup finished (the shell shows the notice if due).
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
    _ticker?.cancel();
    _sub?.cancel();
    _netSub?.cancel();
    super.dispose();
  }
}
