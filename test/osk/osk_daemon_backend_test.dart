import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/osk/osk_backend.dart';
import 'package:hinteros_launcher/src/osk/osk_screen.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart';

Finder _preview(String s) => find.byWidgetPredicate(
  (w) => w is Text && w.key == const ValueKey('osk-preview') && w.data == s,
);

/// The keyboard with [DaemonOskBackend] over the mock daemon (client
/// `hinteros-osk`), as `hinteros-osk` runs on the box.
void main() {
  Future<MockDaemon> start(WidgetTester t) async {
    setView(t);
    final daemon = MockDaemon(clientName: 'hinteros-osk');
    final backend = DaemonOskBackend(daemon);
    await t.pumpWidget(
      OskApp(
        backend: backend,
        settings: ValueNotifier(const LauncherSettings()),
      ),
    );
    await t.pumpAndSettle();
    await daemon.rpc('osk.show', {});
    await t.pumpAndSettle();
    expect(daemon.oskVisible, isTrue);
    return daemon;
  }

  Future<void> press(WidgetTester t, MockDaemon d, NavAction a) async {
    d.emitNav(a);
    d.emitNav(a, NavPhase.release);
    await t.pumpAndSettle();
  }

  testWidgets('Done hides the keyboard', (t) async {
    final d = await start(t);
    for (final a in [
      NavAction.down,
      NavAction.down,
      NavAction.down,
      NavAction.left,
    ]) {
      await press(t, d, a);
    }
    expect(focusLabel(), 'osk/bottom:5');
    await press(t, d, NavAction.accept);
    expect(d.oskVisible, isFalse);
  });

  testWidgets('osk_visibility.password masks; a repeat keeps the focus', (
    t,
  ) async {
    final d = await start(t);
    await press(t, d, NavAction.right); // w
    await press(t, d, NavAction.accept);
    await t.pump(const Duration(seconds: 2));
    expect(_preview('w'), findsOneWidget, reason: 'not a password: plain');
    // A password field gets focus while the keyboard is up.
    d.emitRaw('osk_visibility', {'visible': true, 'password': true});
    await t.pumpAndSettle();
    expect(focusLabel(), 'osk/r1:1', reason: 'still visible: no fresh start');
    await press(t, d, NavAction.accept);
    await t.pump(const Duration(seconds: 2));
    expect(
      _preview('\u2022'),
      findsOneWidget,
      reason: 'masked, started afresh',
    );
  });
}
