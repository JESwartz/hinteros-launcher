import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';

import '../support/installer_harness.dart';

const _wired = NetworkState(
  wiredConnected: true,
  wifiAvailable: true,
  wifiSsid: 'Home',
  online: true,
);

/// On the Internet step with a first (instant) check done, then a slow
/// second one started by "Check again".
Future<(InstallerHarness, Completer<void>)> _slowCheck(WidgetTester t) async {
  final gate = Completer<void>();
  final h = InstallerHarness(backend: FakeInstallerBackend(state: _wired));
  await h.pump(t);
  h.flow.go(InstallerStep.network);
  await h.flow.refreshNetwork();
  await t.pumpAndSettle();
  h.backend.networkHold = gate.future;
  unawaited(h.flow.refreshNetwork());
  await t.pump();
  return (h, gate);
}

void main() {
  testWidgets('while checking: spinner rows, Search again disabled', (t) async {
    final (h, gate) = await _slowCheck(t);
    expect(h.flow.checking, isTrue);
    expect(find.byKey(const ValueKey('spinner')), findsNWidgets(3));
    expect(find.text('Network cable: Checking…'), findsOneWidget);
    expect(find.text('This computer: Checking…'), findsOneWidget);
    expect(find.text('Wi-Fi: Checking…'), findsOneWidget);
    expect(find.text('Network cable: connected.'), findsNothing);
    expect(find.text('This computer is online.'), findsNothing);
    expect(buttonEnabled(t, 'Search again'), isFalse);

    // A second request while one runs is ignored.
    final before = h.backend.calls.where((c) => c == 'network').length;
    await h.flow.refreshNetwork();
    expect(h.backend.calls.where((c) => c == 'network').length, before);
    gate.complete();
    await t.pumpAndSettle();
  });

  testWidgets('after the result: rows and button are back', (t) async {
    final (h, gate) = await _slowCheck(t);
    h.backend.state = const NetworkState(wifiAvailable: true);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('spinner')), findsNothing);
    expect(find.text('Network cable: not connected.'), findsOneWidget);
    expect(find.text('This computer is not online.'), findsOneWidget);
    expect(find.text('Wi-Fi: not connected.'), findsOneWidget);
    expect(buttonEnabled(t, 'Search again'), isTrue);
  });

  testWidgets('a check that never answers times out after 10 s', (t) async {
    final (h, _) = await _slowCheck(t);
    await t.pump(const Duration(seconds: 9));
    expect(h.flow.checking, isTrue);
    await t.pump(const Duration(seconds: 2));
    expect(h.flow.checking, isFalse);
    expect(find.byKey(const ValueKey('spinner')), findsNothing);
    expect(find.textContaining('took longer than 10 seconds'), findsOneWidget);
    expect(find.text('This computer is not online.'), findsOneWidget);
    expect(buttonEnabled(t, 'Check again'), isTrue);
  });

  testWidgets('Check again (no Wi-Fi adapter) is disabled while checking', (
    t,
  ) async {
    final gate = Completer<void>();
    final h = InstallerHarness(backend: FakeInstallerBackend());
    await h.pump(t);
    h.flow.go(InstallerStep.network);
    await h.flow.refreshNetwork();
    await t.pumpAndSettle();
    expect(buttonEnabled(t, 'Check again'), isTrue);
    h.backend.networkHold = gate.future;
    unawaited(h.flow.refreshNetwork());
    await t.pump();
    expect(buttonEnabled(t, 'Check again'), isFalse);
    expect(find.text('Wi-Fi: Checking…'), findsNothing);
    gate.complete();
    await t.pumpAndSettle();
    expect(buttonEnabled(t, 'Check again'), isTrue);
  });

  testWidgets('Wi-Fi scan: spinner, then timeout message', (t) async {
    final h = InstallerHarness(
      backend: FakeInstallerBackend(state: _wired, wifi: const []),
    );
    await h.pump(t);
    h.flow.go(InstallerStep.network);
    await h.flow.refreshNetwork();
    await t.pumpAndSettle();
    h.backend.scanHold = Completer<void>().future;
    unawaited(h.flow.scanWifi());
    await t.pump();
    expect(find.text('Searching…'), findsOneWidget);
    expect(buttonEnabled(t, 'Search again'), isFalse);
    await t.pump(const Duration(seconds: 11));
    expect(h.flow.scanning, isFalse);
    expect(
      find.textContaining('Searching for Wi-Fi took longer'),
      findsOneWidget,
    );
    expect(buttonEnabled(t, 'Search again'), isTrue);
  });
}
