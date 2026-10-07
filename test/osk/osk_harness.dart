import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hinteros_launcher/src/nav/soft_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/osk/osk_backend.dart';
import 'package:hinteros_launcher/src/osk/osk_screen.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart';

/// The OSK with a mock backend, like `--mock` but without a window.
class OskHarness {
  OskHarness({LauncherSettings settings = const LauncherSettings()})
    : settings = ValueNotifier(settings);

  final backend = MockOskBackend();

  /// Physical key presses as the evdev reader would report them.
  final echo = StreamController<SoftKey>.broadcast();
  final ValueNotifier<LauncherSettings> settings;

  Widget get app =>
      OskApp(backend: backend, settings: settings, echoKeys: echo.stream);

  Future<void> pump(
    WidgetTester tester, {
    Widget Function(Widget)? wrap,
  }) async {
    await tester.pumpWidget(wrap == null ? app : wrap(app));
    await tester.pumpAndSettle();
  }

  /// As `input_nav` from the daemon.
  Future<void> nav(
    WidgetTester t,
    NavAction a, [
    NavPhase phase = NavPhase.press,
  ]) async {
    backend.emitNav(a, phase);
    await t.pumpAndSettle();
  }

  /// Moves the highlight to the key labelled [label] with D-pad presses only
  /// (up/down for the row, then left/right), checking after each press that
  /// focus moved. Does not accept.
  Future<void> moveTo(WidgetTester t, String label) async {
    final target = find.text(label);
    expect(target, findsOneWidget, reason: 'key "$label" on this page');
    final want = t.getCenter(target);
    for (var i = 0; i < 40; i++) {
      final have = _focusedCenter();
      final dy = want.dy - have.dy;
      final dx = want.dx - have.dx;
      if (dy.abs() < 10 && dx.abs() < 10) return;
      final before = focusLabel();
      await nav(
        t,
        dy.abs() >= 10
            ? (dy > 0 ? NavAction.down : NavAction.up)
            : (dx > 0 ? NavAction.right : NavAction.left),
      );
      expect(focusLabel(), isNot(before), reason: 'focus moved towards $label');
    }
    fail('could not reach "$label"');
  }

  Offset _focusedCenter() {
    final box =
        FocusManager.instance.primaryFocus!.context!.findRenderObject()!
            as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Highlight the key and press accept.
  Future<void> type(WidgetTester t, String label) async {
    await moveTo(t, label);
    await nav(t, NavAction.accept);
  }
}
