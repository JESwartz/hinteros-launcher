import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/updates/reminder.dart';

void main() {
  test('a security notice is due at startup and on every return', () async {
    final jobs = MockJobs();
    final ups = MockUpdates(jobs)..nextAvailable = mockSecurityUpdate();
    final r = UpdateReminders(ups);
    expect(r.securityNoticeDue(), isFalse, reason: 'nothing known yet');
    await r.start();
    expect(r.behind, isTrue);
    expect(r.securityNoticeDue(), isTrue);
    expect(r.securityNoticeDue(), isTrue);
    expect(r.securityNoticeDue(), isTrue);
    expect(jobs.started, isEmpty, reason: 'never installs by itself');
    r.dispose();
  });

  test('an ordinary update never asks for the full-screen notice', () async {
    final ups = MockUpdates(MockJobs())..nextAvailable = mockOrdinaryUpdate();
    final r = UpdateReminders(ups);
    await r.start();
    expect(r.behind, isTrue);
    expect(r.securityNoticeDue(), isFalse);
    r.dispose();
  });

  test('an unreachable update server is not an error at startup', () async {
    final ups = MockUpdates(MockJobs())
      ..failCheckWith = const SystemException(
        SystemErrorKind.updateUnreachable,
        'x',
      );
    final r = UpdateReminders(ups);
    await r.start();
    expect(r.behind, isFalse);
    r.dispose();
  });

  test('a system service that starts late is tried again', () async {
    final ups = MockUpdates(MockJobs())
      ..nextAvailable = mockSecurityUpdate()
      ..failCheckWith = const SystemException(
        SystemErrorKind.unavailable,
        'down',
      );
    final r = UpdateReminders(
      ups,
      retryDelays: const [Duration(milliseconds: 10)],
    );
    var late = 0;
    r.onLateResult = () => late++;
    await r.start();
    expect(r.behind, isFalse);
    expect(ups.checks, 1);
    // The service comes up; the retry after the first delay finds the update.
    ups.failCheckWith = null;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ups.checks, 2);
    expect(r.behind, isTrue);
    expect(late, 1);
    r.dispose();
  });

  test('up to date: no reminder', () async {
    final r = UpdateReminders(MockUpdates(MockJobs()));
    await r.start();
    expect(r.behind, isFalse);
    r.dispose();
  });

  test('a check that failed offline is tried again when online', () async {
    final net = StreamController<NetworkStatus>.broadcast();
    final ups = MockUpdates(MockJobs())
      ..nextAvailable = mockSecurityUpdate()
      ..failCheckWith = _unreachable;
    final r = UpdateReminders(ups, network: net.stream);
    var late = 0;
    r.onLateResult = () => late++;
    await r.start();
    expect(r.behind, isFalse);
    expect(ups.checks, 1);
    ups.failCheckWith = null;
    // Not online yet: nothing.
    net.add(const NetworkStatus(connectivity: Connectivity.limited));
    await pumpEventQueue();
    expect(ups.checks, 1);
    net.add(_online);
    await pumpEventQueue();
    expect(ups.checks, 2);
    expect(r.securityNoticeDue(), isTrue);
    expect(late, 1);
    // Checked: a reconnect does not check again.
    net
      ..add(const NetworkStatus(connectivity: Connectivity.none))
      ..add(_online);
    await pumpEventQueue();
    expect(ups.checks, 2);
    r.dispose();
    await net.close();
  });

  test('the network comes up during the failing startup check', () async {
    final net = StreamController<NetworkStatus>.broadcast();
    final gate = Completer<void>();
    final ups = _GatedUpdates(MockJobs(), gate.future, failFirst: true)
      ..nextAvailable = mockOrdinaryUpdate();
    final r = UpdateReminders(ups, network: net.stream);
    final started = r.start();
    await pumpEventQueue();
    // NetworkManager does not check: a connection is enough.
    net.add(const NetworkStatus(ethernet: true));
    await pumpEventQueue();
    gate.complete();
    await started;
    await pumpEventQueue();
    expect(ups.calls, 2);
    expect(r.behind, isTrue);
    r.dispose();
    await net.close();
  });

  test('a long session checks again every day', () async {
    var now = DateTime(2026, 11, 3, 8);
    const tick = Duration(milliseconds: 5);
    final ups = MockUpdates(MockJobs());
    final r = UpdateReminders(ups, tick: tick, now: () => now);
    await r.start();
    expect(ups.checks, 1);
    now = now.add(const Duration(hours: 23));
    await Future<void>.delayed(tick * 4);
    expect(ups.checks, 1);
    // The box slept: the timer did not count it, the clock did.
    now = now.add(const Duration(hours: 2));
    await Future<void>.delayed(tick * 4);
    expect(ups.checks, 2);
    ups.nextAvailable = mockSecurityUpdate();
    now = now.add(const Duration(days: 1));
    await Future<void>.delayed(tick * 4);
    expect(ups.checks, 3);
    expect(r.securityNoticeDue(), isTrue);
    r.dispose();
  });

  test('offline: no hourly retry; the network coming up checks', () async {
    const tick = Duration(milliseconds: 5);
    final net = StreamController<NetworkStatus>.broadcast();
    final ups = MockUpdates(MockJobs())..failCheckWith = _unreachable;
    final r = UpdateReminders(ups, network: net.stream, tick: tick);
    await r.start();
    expect(ups.checks, 1);
    net.add(const NetworkStatus(connectivity: Connectivity.none));
    await Future<void>.delayed(tick * 4);
    expect(ups.checks, 1);
    ups.failCheckWith = null;
    net.add(_online);
    await pumpEventQueue();
    expect(ups.checks, 2);
    r.dispose();
    await net.close();
  });

  test('disposed during the startup check: no notify after dispose', () async {
    final gate = Completer<void>();
    final ups = _GatedUpdates(MockJobs(), gate.future);
    final r = UpdateReminders(ups);
    final started = r.start();
    await pumpEventQueue();
    r.dispose();
    gate.complete();
    await started;
  });
}

const _unreachable = SystemException(SystemErrorKind.updateUnreachable, 'x');
const _online = NetworkStatus(
  wifiSsid: 'home',
  connectivity: Connectivity.full,
);

/// A check that waits for [gate]; with [failFirst] the first one finds the
/// update server unreachable.
class _GatedUpdates extends MockUpdates {
  _GatedUpdates(super.jobs, this.gate, {this.failFirst = false});

  final Future<void> gate;
  final bool failFirst;
  int calls = 0;

  @override
  Future<UpdateStatus> check() async {
    final n = ++calls;
    await gate;
    if (failFirst && n == 1) throw _unreachable;
    return super.check();
  }
}
