import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/log.dart';

import 'support/harness.dart';

/// A daemon whose launches always fail.
class _FailingLaunch extends MockDaemon {
  @override
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) {
    if (method == 'apps.launch') {
      throw const ApiException(
        ApiErrorCode.appLaunchFailed,
        'spawn went wrong',
      );
    }
    return super.rpc(method, params);
  }
}

/// A daemon that no longer knows the app.
class _GoneLaunch extends MockDaemon {
  @override
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) {
    if (method == 'apps.launch') {
      throw const ApiException(ApiErrorCode.appNotFound, 'no such app: steam');
    }
    return super.rpc(method, params);
  }
}

void main() {
  const up = LogicalKeyboardKey.arrowUp;
  const down = LogicalKeyboardKey.arrowDown;
  const right = LogicalKeyboardKey.arrowRight;
  const enter = LogicalKeyboardKey.enter;
  const escape = LogicalKeyboardKey.escape;

  Future<void> keys(WidgetTester t, List<LogicalKeyboardKey> ks) async {
    for (final k in ks) {
      await t.sendKeyEvent(k);
      await t.pumpAndSettle();
    }
  }

  testWidgets('shows title, tabs and the first card focused', (t) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    for (final s in ['Home', 'Games', 'Apps', 'Settings']) {
      expect(find.text(s), findsWidgets);
    }
    expect(find.text('Server'), findsNothing);
    expect(find.text('20:30'), findsOneWidget);
    expect(focusLabel(), 'home/apps:0');
  });

  testWidgets('server tab only behind the flag', (t) async {
    setView(t);
    await Harness(showServer: true).pump(t);
    expect(find.text('Server'), findsOneWidget);
  });

  testWidgets('input_nav press and repeat move focus, release does not', (
    t,
  ) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    h.mock.emitNav(NavAction.right, NavPhase.press);
    await t.pumpAndSettle();
    expect(focusLabel(), 'home/apps:1');
    h.mock.emitNav(NavAction.right, NavPhase.repeat);
    await t.pumpAndSettle();
    expect(focusLabel(), 'home/apps:2');
    h.mock.emitNav(NavAction.right, NavPhase.release);
    await t.pumpAndSettle();
    expect(focusLabel(), 'home/apps:2');
    h.mock.emitNav(NavAction.context);
    await t.pumpAndSettle();
    expect(focusLabel(), 'home/apps:2');
  });

  testWidgets('accept launches once per press; Running mark follows', (
    t,
  ) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    h.mock.emitNav(NavAction.right);
    await t.pumpAndSettle();
    h.mock.emitNav(NavAction.accept, NavPhase.repeat);
    h.mock.emitNav(NavAction.accept, NavPhase.release);
    await t.pumpAndSettle();
    expect(h.mock.running, isEmpty);
    h.mock.emitNav(NavAction.accept, NavPhase.press);
    await t.pumpAndSettle();
    expect(h.mock.running.map((a) => a.id), [mockApps[1].id]);
    // Continue row plus the Apps tile.
    expect(find.text('Running'), findsNWidgets(2));
    h.mock.simulateExit(mockApps[1].id);
    await t.pumpAndSettle();
    expect(find.text('Running'), findsNothing);
  });

  testWidgets('Enter and arrows work from the keyboard', (t) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    await keys(t, [right, enter]);
    expect(h.mock.running.map((a) => a.id), [mockApps[1].id]);
  });

  testWidgets('Home button returns to Home with the first card focused', (
    t,
  ) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    await keys(t, [right, right, up, right, down]); // now in Games
    expect(focusLabel(), startsWith('games/'));
    h.mock.pressHome();
    await t.pumpAndSettle();
    expect(focusLabel(), 'home/apps:0');
  });

  testWidgets('a failed launch says what and which app, and is logged', (
    t,
  ) async {
    setView(t);
    final log = <String>[];
    final old = logSink;
    logSink = log.add;
    addTearDown(() => logSink = old);
    final h = Harness(mock: _FailingLaunch());
    await h.pump(t);
    await keys(t, [enter]);
    expect(find.text("Couldn't start Steam"), findsOneWidget);
    expect(
      find.textContaining("Steam, but its program wouldn't run"),
      findsOneWidget,
    );
    expect(find.text('Error 2002: spawn went wrong'), findsOneWidget);
    expect(
      log,
      contains(
        'hinteros-launcher: start Steam failed: error 2002: spawn went wrong',
      ),
    );
    // A dialog, not a toast: it stays until dismissed.
    expect(find.byType(SnackBar), findsNothing);
    await keys(t, [enter]);
    expect(find.text("Couldn't start Steam"), findsNothing);
  });

  testWidgets('launching an app the daemon does not know (2001) is explained', (
    t,
  ) async {
    setView(t);
    final log = <String>[];
    final old = logSink;
    logSink = log.add;
    addTearDown(() => logSink = old);
    final h = Harness(mock: _GoneLaunch());
    await h.pump(t);
    await keys(t, [enter]);
    expect(find.text("Couldn't start Steam"), findsOneWidget);
    expect(find.textContaining("isn't in HinterOS's app list"), findsOneWidget);
    expect(log.single, contains('error 2001'));
  });

  testWidgets('shows the apps the daemon lists', (t) async {
    setView(t);
    final h = Harness(
      mock: MockDaemon(
        apps: const [App(id: 'only', name: 'Only App', kind: AppKind.web)],
      ),
    );
    await h.pump(t);
    expect(find.text('Only App'), findsOneWidget);
    expect(find.text('Steam'), findsNothing);
  });

  testWidgets(
    'without a steam app Games offers to install it, Home and Apps show no tile',
    (t) async {
      setView(t);
      final h = Harness(
        mock: MockDaemon(
          apps: const [App(id: 'only', name: 'Only App', kind: AppKind.web)],
        ),
      );
      await h.pump(t);
      await keys(t, [up, right, down]); // Games
      expect(find.text('Steam is not installed'), findsOneWidget);
      expect(find.text('Install Steam'), findsOneWidget);
      await keys(t, [up, right, down]); // Apps
      expect(find.text('Only App'), findsOneWidget);
      expect(find.text('Steam'), findsNothing);
    },
  );

  testWidgets('Steam in apps.list means no prompt in Games', (t) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    await keys(t, [up, right, down]);
    expect(find.text('Steam is not installed'), findsNothing);
  });

  testWidgets('says so when the daemon is unreachable', (t) async {
    setView(t);
    await Harness(mock: StuckConnection(const Unreachable('no such file')))
        .pump(t);
    expect(find.text('HinterOS'), findsOneWidget);
    expect(find.textContaining("Can't reach"), findsOneWidget);
    expect(find.textContaining('no such file'), findsOneWidget);
  });

  testWidgets('says so on a version mismatch', (t) async {
    setView(t);
    await Harness(
      mock: StuckConnection(
        const VersionMismatch(clientApiVersion: '0.2', serverApiVersion: '0.3'),
      ),
    ).pump(t);
    expect(find.textContaining("versions don't match"), findsOneWidget);
  });

  testWidgets('keys with nothing to focus do not throw', (t) async {
    setView(t);
    final h = Harness(mock: StuckConnection(const Unreachable('x')));
    await h.pump(t);
    await keys(t, [down, escape]);
  });
}
