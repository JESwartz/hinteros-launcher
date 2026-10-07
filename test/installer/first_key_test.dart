import 'package:flutter/widgets.dart' show FocusManager;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/ui/installer_app.dart';

import '../support/harness.dart';
import '../support/installer_harness.dart';

/// The keyboard before any other input: on the ISO nothing else has touched
/// the app yet, and the first key must already count.
void main() {
  Future<InstallerHarness> firstFrame(WidgetTester t) async {
    final h = InstallerHarness();
    setView(t);
    await t.pumpWidget(InstallerApp(flow: h.flow, pad: null));
    return h;
  }

  testWidgets('Enter on the very first frame of Welcome advances', (t) async {
    final h = await firstFrame(t);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(h.flow.step, InstallerStep.network);
  });

  testWidgets('Space and numpad Enter work on the first frame too', (t) async {
    final h = await firstFrame(t);
    await t.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await t.pump();
    expect(h.flow.step, InstallerStep.network);
  });

  testWidgets('an arrow then Enter on the first frame advances', (t) async {
    final h = await firstFrame(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(h.flow.step, InstallerStep.network);
  });

  testWidgets('the first screen has primary focus on the Start button', (
    t,
  ) async {
    final h = await firstFrame(t);
    await t.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(h.focus, 'content/start:0');
  });
}
