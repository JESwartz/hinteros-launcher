import 'package:flutter/material.dart' show Focus;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/main.dart';
import 'package:hinteros_launcher/src/api/api.dart';

/// A connection stuck in a fixed state, for the error screens.
class _StuckConnection extends MockDaemon {
  _StuckConnection(this._fixed);

  final ConnectionStatus _fixed;

  @override
  ConnectionStatus get status => _fixed;

  @override
  void start() {}
}

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

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders title and arrow-right moves focus to the next app', (
    tester,
  ) async {
    _bigView(tester);
    final mock = MockDaemon();
    await tester.pumpWidget(LauncherApp(connection: mock));
    await tester.pumpAndSettle();

    expect(find.text('HinterOS'), findsOneWidget);

    final first = mockApps[0].name;
    final second = mockApps[1].name;
    expect(find.text(first), findsOneWidget);
    Finder focusedCard() => find.byWidgetPredicate(
      (w) => w is Focus && w.focusNode?.hasPrimaryFocus == true,
    );
    expect(focusedCard(), findsOneWidget);
    expect(
      find.descendant(of: focusedCard(), matching: find.text(first)),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: focusedCard(), matching: find.text(second)),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: focusedCard(), matching: find.text(first)),
      findsOneWidget,
    );

    // Home from the daemon resets focus to the first card.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    mock.pressHome();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: focusedCard(), matching: find.text(first)),
      findsOneWidget,
    );
  });

  group('actions', () {
    Finder focusedCard() => find.byWidgetPredicate(
      (w) => w is Focus && w.focusNode?.hasPrimaryFocus == true,
    );
    Finder focusedIs(String name) =>
        find.descendant(of: focusedCard(), matching: find.text(name));

    testWidgets('input_nav press and repeat move focus, release does not', (
      tester,
    ) async {
      _bigView(tester);
      final mock = MockDaemon();
      await tester.pumpWidget(LauncherApp(connection: mock));
      await tester.pumpAndSettle();

      mock.emitNav(NavAction.right, NavPhase.press);
      await tester.pumpAndSettle();
      expect(focusedIs(mockApps[1].name), findsOneWidget);
      mock.emitNav(NavAction.right, NavPhase.repeat);
      await tester.pumpAndSettle();
      expect(focusedIs(mockApps[2].name), findsOneWidget);
      mock.emitNav(NavAction.right, NavPhase.release);
      await tester.pumpAndSettle();
      expect(focusedIs(mockApps[2].name), findsOneWidget);
      mock.emitNav(NavAction.left);
      await tester.pumpAndSettle();
      expect(focusedIs(mockApps[1].name), findsOneWidget);
      // Unrelated actions do nothing.
      mock.emitNav(NavAction.context);
      await tester.pumpAndSettle();
      expect(focusedIs(mockApps[1].name), findsOneWidget);
    });

    testWidgets('accept launches the focused app, once per press', (
      tester,
    ) async {
      _bigView(tester);
      final mock = MockDaemon();
      await tester.pumpWidget(LauncherApp(connection: mock));
      await tester.pumpAndSettle();
      mock.emitNav(NavAction.right);
      await tester.pumpAndSettle();

      mock.emitNav(NavAction.accept, NavPhase.repeat);
      mock.emitNav(NavAction.accept, NavPhase.release);
      await tester.pumpAndSettle();
      expect(mock.running, isEmpty);

      mock.emitNav(NavAction.accept, NavPhase.press);
      await tester.pumpAndSettle();
      expect(mock.running.map((a) => a.id), [mockApps[1].id]);
      expect(find.text('Running'), findsOneWidget);

      // The app quits; the card is no longer marked.
      mock.simulateExit(mockApps[1].id);
      await tester.pumpAndSettle();
      expect(find.text('Running'), findsNothing);
    });

    testWidgets('Enter on the keyboard launches too; Home resets', (
      tester,
    ) async {
      _bigView(tester);
      final mock = MockDaemon();
      await tester.pumpWidget(LauncherApp(connection: mock));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(mock.running.map((a) => a.id), [mockApps[1].id]);

      mock.pressHome();
      await tester.pumpAndSettle();
      expect(focusedIs(mockApps[0].name), findsOneWidget);
    });

    testWidgets('a failed launch shows a message', (tester) async {
      _bigView(tester);
      final mock = _FailingLaunch();
      await tester.pumpWidget(LauncherApp(connection: mock));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't start Steam"), findsOneWidget);
      expect(find.textContaining('spawn went wrong'), findsOneWidget);
    });
  });

  testWidgets('shows the apps the daemon lists', (tester) async {
    _bigView(tester);
    final mock = MockDaemon(
      apps: const [App(id: 'only', name: 'Only App', kind: AppKind.web)],
    );
    await tester.pumpWidget(LauncherApp(connection: mock));
    await tester.pumpAndSettle();
    expect(find.text('Only App'), findsOneWidget);
    expect(find.text('Steam'), findsNothing);
  });

  testWidgets('says so when the daemon is unreachable', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(
      LauncherApp(
        connection: _StuckConnection(const Unreachable('no such file')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HinterOS'), findsOneWidget);
    expect(find.textContaining("Can't reach"), findsOneWidget);
    expect(find.textContaining('no such file'), findsOneWidget);
  });

  testWidgets('says so on a version mismatch', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(
      LauncherApp(
        connection: _StuckConnection(
          const VersionMismatch(
            clientApiVersion: '0.2',
            serverApiVersion: '0.3',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("versions don't match"), findsOneWidget);
    expect(find.textContaining('0.3'), findsOneWidget);
  });

  testWidgets('--fps shows the overlay', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(
      LauncherApp(connection: MockDaemon(), showFps: true),
    );
    expect(find.textContaining('fps:'), findsOneWidget);
  });
}
