import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';

const _none = NetworkState(wifiAvailable: true);
const _plugged = NetworkState(wifiAvailable: true, cableWaiting: true);
const _connecting = NetworkState(wifiAvailable: true, connecting: true);
const _up = NetworkState(
  wifiAvailable: true,
  wiredConnected: true,
  online: true,
);

InstallerFlow _flow(FakeInstallerBackend b, {int retries = 3}) => InstallerFlow(
  b,
  pollInterval: const Duration(milliseconds: 5),
  connectTimeout: const Duration(milliseconds: 200),
  plugGrace: const Duration(milliseconds: 40),
  probeRetries: retries,
);

int _checks(FakeInstallerBackend b) =>
    b.calls.where((c) => c == 'network').length;

void main() {
  test('Check again waits for a cable that is connecting', () async {
    final b = FakeInstallerBackend(state: _none)
      ..networkQueue.addAll([_none, _plugged, _connecting, _connecting, _up]);
    final f = _flow(b);
    final seen = <bool>[];
    f.addListener(() => seen.add(f.waitingForLink));
    await f.refreshNetwork(force: true, plugWait: true);
    expect(f.online, isTrue);
    expect(f.net!.wiredConnected, isTrue);
    expect(seen, contains(true), reason: 'showed "Connecting..." meanwhile');
    expect(f.waitingForLink, isFalse);
    expect(f.checking, isFalse);
  });

  test('nothing appears within the grace period: not connected', () async {
    final b = FakeInstallerBackend(state: _none);
    final f = _flow(b);
    final t0 = DateTime.now();
    await f.refreshNetwork(force: true, plugWait: true);
    expect(f.online, isFalse);
    expect(f.net!.linkUp, isFalse);
    expect(
      DateTime.now().difference(t0),
      greaterThanOrEqualTo(const Duration(milliseconds: 40)),
    );
    expect(_checks(b), greaterThan(2), reason: 'it watched, not once');
  });

  test(
    'a live (quiet) check does not wait without a connection coming',
    () async {
      final b = FakeInstallerBackend(state: _none);
      await _flow(b).refreshNetwork(quiet: true);
      expect(_checks(b), 1);
    },
  );

  test('a live check waits for a connection that is coming up', () async {
    final b = FakeInstallerBackend(state: _none)
      ..networkQueue.addAll([_connecting, _connecting, _up]);
    final f = _flow(b);
    await f.refreshNetwork(quiet: true);
    expect(f.online, isTrue);
    expect(_checks(b), 3);
  });

  test('a connection that never finishes gives up after the timeout', () async {
    final b = FakeInstallerBackend(state: _connecting);
    final f = _flow(b);
    final t0 = DateTime.now();
    await f.refreshNetwork(force: true, plugWait: true);
    expect(f.online, isFalse);
    expect(
      DateTime.now().difference(t0),
      greaterThanOrEqualTo(const Duration(milliseconds: 200)),
    );
  });

  test('link up but the probe lags: it is retried', () async {
    const noProbe = NetworkState(wiredConnected: true, wifiAvailable: true);
    final b = FakeInstallerBackend(state: _none)
      ..networkQueue.addAll([noProbe, noProbe, _up]);
    final f = _flow(b);
    await f.refreshNetwork(force: true, plugWait: true);
    expect(f.online, isTrue);
    expect(_checks(b), 3);
  });

  test(
    'link up and the probe keeps failing: retried a few times only',
    () async {
      const noProbe = NetworkState(wiredConnected: true, wifiAvailable: true);
      final b = FakeInstallerBackend(state: noProbe);
      final f = _flow(b, retries: 2);
      await f.refreshNetwork(force: true, plugWait: true);
      expect(f.online, isFalse);
      expect(f.net!.linkUp, isTrue);
      expect(_checks(b), 3);
    },
  );
}
