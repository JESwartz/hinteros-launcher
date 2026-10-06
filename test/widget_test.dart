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
            clientApiVersion: '0.1',
            serverApiVersion: '0.2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("versions don't match"), findsOneWidget);
    expect(find.textContaining('0.2'), findsOneWidget);
  });

  testWidgets('--fps shows the overlay', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(
      LauncherApp(connection: MockDaemon(), showFps: true),
    );
    expect(find.textContaining('fps:'), findsOneWidget);
  });
}
