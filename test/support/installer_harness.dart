import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';
import 'package:hinteros_launcher/src/installer/gamepad.dart';
import 'package:hinteros_launcher/src/installer/ui/host.dart';
import 'package:hinteros_launcher/src/installer/ui/installer_app.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import 'harness.dart';

/// The installer with a fake backend, driven like a controller: every press
/// goes through the same stream the evdev gamepad feeds.
class InstallerHarness {
  InstallerHarness({
    FakeInstallerBackend? backend,
    this.settings = const LauncherSettings(),
    this.padStream,
    this.driver,
  }) : backend = backend ?? FakeInstallerBackend() {
    flow = InstallerFlow(this.backend);
  }

  final FakeInstallerBackend backend;
  final LauncherSettings settings;
  late final InstallerFlow flow;
  final _pad = StreamController<PadEvent>.broadcast();

  /// Another source of controller events (an [EvdevPad] over fake devices).
  final Stream<PadEvent>? padStream;

  /// How [press] reaches the app, instead of the pad stream: a keyboard or a
  /// stick. Gets the action to perform.
  final Future<void> Function(WidgetTester t, NavAction a)? driver;

  Future<void> pump(WidgetTester t) async {
    setView(t);
    addTearDown(_pad.close);
    await t.pumpWidget(
      InstallerApp(
        flow: flow,
        pad: padStream ?? _pad.stream,
        settings: settings,
      ),
    );
    await t.pumpAndSettle();
  }

  ConsoleController console(WidgetTester t) =>
      t.widget<InstallerScreen>(find.byType(InstallerScreen)).console;

  /// One controller press.
  Future<void> press(WidgetTester t, NavAction a) async {
    if (driver != null) {
      await driver!(t, a);
      await t.pumpAndSettle();
      return;
    }
    _pad.add((a, NavPhase.press));
    await t.pumpAndSettle();
  }

  Future<void> accept(WidgetTester t) => press(t, NavAction.accept);
  Future<void> back(WidgetTester t) => press(t, NavAction.back);

  /// Focus label `content/<row>:<col>` of the focused item.
  String? get focus => focusLabel();

  /// D-pad to the item `row:col` of the content region (down first, then
  /// up, then right).
  Future<void> moveTo(WidgetTester t, String row, [int col = 0]) async {
    final want = 'content/$row:0';
    for (final dir in [NavAction.down, NavAction.up]) {
      for (
        var i = 0;
        i < 40 && focus?.startsWith('content/$row:') != true;
        i++
      ) {
        await press(t, dir);
      }
      if (focus?.startsWith('content/$row:') == true) break;
    }
    expect(focus, startsWith('content/$row:'), reason: 'reach $want');
    for (var i = 0; i < col; i++) {
      await press(t, NavAction.right);
    }
    expect(focus, 'content/$row:$col');
  }

  /// Moves to the item and accepts it.
  Future<void> choose(WidgetTester t, String row, [int col = 0]) async {
    await moveTo(t, row, col);
    await accept(t);
  }

  /// Types [text] into the keyboard that is up and presses Done.
  Future<void> type(WidgetTester t, String text, {bool replace = true}) async {
    final kb = console(t).keyboard;
    expect(kb, isNotNull, reason: 'the on-screen keyboard is up');
    if (replace) kb!.text.value = '';
    await kb!.type(text);
    await kb.hide();
    await t.pumpAndSettle();
  }

  /// Walks through a Start press from Welcome.
  Future<void> start(WidgetTester t) async {
    await pump(t);
    await choose(t, 'start');
  }
}

/// Whether the button labelled [label] is enabled.
bool buttonEnabled(WidgetTester t, String label) =>
    t.widget<HButton>(find.widgetWithText(HButton, label)).enabled;
