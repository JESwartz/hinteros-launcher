import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/gamepad.dart';
import 'package:hinteros_launcher/src/installer/ui/first_boot.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';

import '../support/harness.dart';

/// The first-boot wizard is a skeleton (see its TODOs): the steps that exist
/// work with the mock services, driven like a controller.
void main() {
  testWidgets('welcome, network, controllers, display, finish', (t) async {
    setView(t);
    final pad = StreamController<PadEvent>.broadcast();
    addTearDown(pad.close);
    var finished = 0;
    Future<void> press(NavAction a) async {
      pad.add((a, NavPhase.press));
      await t.pumpAndSettle();
    }

    await t.pumpWidget(
      FirstBootApp(
        services: MockSystemServices(),
        pad: pad.stream,
        onFinished: () => finished++,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);

    await press(NavAction.accept); // Start
    expect(find.text('Internet'), findsOneWidget);
    expect(find.textContaining('online'), findsWidgets);
    await press(NavAction.back);
    expect(find.text('Welcome'), findsOneWidget);
    await press(NavAction.accept);
    // Down to Continue, whatever the Wi-Fi list is.
    for (
      var i = 0;
      i < 20 && find.text('Controllers').evaluate().isEmpty;
      i++
    ) {
      await press(NavAction.down);
      if (focusLabel() == 'content/actions:0') await press(NavAction.accept);
    }
    expect(find.text('Controllers'), findsOneWidget);
    await press(NavAction.accept); // only item or first device; keep going
    for (var i = 0; i < 20 && find.text('Display').evaluate().isEmpty; i++) {
      await press(NavAction.down);
      if (focusLabel() == 'content/actions:0') await press(NavAction.accept);
    }
    expect(find.text('Display'), findsOneWidget);
    await press(NavAction.accept); // Looks good
    expect(find.text('All set'), findsOneWidget);
    expect(finished, 0);
    await press(NavAction.accept); // Finish
    expect(finished, 1);
  });
}
