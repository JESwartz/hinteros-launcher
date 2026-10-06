import 'package:flutter/material.dart' show Focus;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/main.dart';

void main() {
  testWidgets('renders title and arrow-right moves focus to the next card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LauncherApp());
    await tester.pumpAndSettle();

    expect(find.text('HinterOS'), findsOneWidget);

    expect(find.text('Card 1'), findsOneWidget);
    Finder focusedCard() => find.byWidgetPredicate(
      (w) => w is Focus && w.focusNode?.hasPrimaryFocus == true,
    );
    expect(focusedCard(), findsOneWidget);
    expect(
      find.descendant(of: focusedCard(), matching: find.text('Card 1')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: focusedCard(), matching: find.text('Card 2')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: focusedCard(), matching: find.text('Card 1')),
      findsOneWidget,
    );
  });

  testWidgets('--fps shows the overlay', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LauncherApp(showFps: true));
    expect(find.textContaining('fps:'), findsOneWidget);
  });
}
