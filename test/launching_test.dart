import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/ui/launching.dart';

import 'support/harness.dart';

/// The "Starting App..." view between `apps.launch` and `focus_changed`.
/// The spinner never settles, so these pump explicitly.
void main() {
  Future<Harness> start(WidgetTester t, {bool slow = true}) async {
    setView(t);
    final h = Harness();
    h.mock.slowStart = slow;
    await h.pump(t);
    return h;
  }

  Future<void> frames(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  final view = find.byKey(const ValueKey('launching'));
  final hint = find.byKey(const ValueKey('launching-hint'));

  testWidgets('shows from the launch until focus_changed hides it', (t) async {
    final h = await start(t);
    expect(view, findsNothing);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    expect(view, findsOneWidget);
    expect(find.text('Starting Jellyfin…'), findsOneWidget);
    expect(hint, findsNothing);
    h.mock.finishStart('jellyfin');
    await frames(t);
    expect(view, findsNothing);
  });

  testWidgets('no flash when the focus event beats the answer', (t) async {
    final h = await start(t, slow: false);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    expect(view, findsNothing);
  });

  testWidgets('launching the app that has the focus does not wait', (t) async {
    final h = await start(t, slow: false);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    expect(h.data.focusedApp, 'jellyfin');
    // Already focused: the daemon sends no focus_changed this time.
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    expect(h.data.launching, isNull);
    expect(view, findsNothing);
  });

  group('the browser demo stand-in for the focused app', () {
    final standIn = find.byKey(const ValueKey('stand-in'));

    Future<(Harness, List<String>)> demo(WidgetTester t) async {
      setView(t);
      final left = <String>[];
      late final Harness h;
      h = Harness(
        leaveApp: () {
          left.add('home');
          h.mock.pressHome();
        },
      );
      await h.pump(t);
      return (h, left);
    }

    testWidgets('covers the launcher while the app has the focus', (t) async {
      final (h, _) = await demo(t);
      expect(standIn, findsNothing);
      await h.data.launchApp('jellyfin', 'Jellyfin');
      await frames(t);
      expect(standIn, findsOneWidget);
      expect(find.text('Jellyfin is open'), findsOneWidget);
      h.mock.pressHome();
      await frames(t);
      expect(standIn, findsNothing);
    });

    testWidgets('B goes Home; Enter does not start the app again', (t) async {
      final (h, left) = await demo(t);
      await h.data.launchApp('jellyfin', 'Jellyfin');
      await frames(t);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await frames(t);
      expect(view, findsNothing);
      expect(left, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t);
      expect(left, hasLength(1));
      expect(standIn, findsNothing);
      expect(h.mock.running.map((a) => a.id), contains('jellyfin'));
    });

    testWidgets('a click goes Home', (t) async {
      final (h, left) = await demo(t);
      await h.data.launchApp('jellyfin', 'Jellyfin');
      await frames(t);
      await t.tap(find.byKey(const ValueKey('stand-in-leave')));
      await frames(t);
      expect(left, hasLength(1));
      expect(standIn, findsNothing);
    });

    testWidgets('none on a box', (t) async {
      final h = await start(t, slow: false);
      await h.data.launchApp('jellyfin', 'Jellyfin');
      await frames(t);
      expect(standIn, findsNothing);
    });
  });

  testWidgets('after 10 s it says it can take a while; Steam says why', (
    t,
  ) async {
    final h = await start(t);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    await t.pump(launchingHintAfter - const Duration(seconds: 1));
    expect(hint, findsNothing);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('The first start can take a minute.'), findsOneWidget);
    h.mock.finishStart('jellyfin');
    await frames(t);

    await h.data.launchApp('steam', 'Steam');
    await frames(t);
    await t.pump(launchingHintAfter + const Duration(seconds: 1));
    expect(find.textContaining('Steam is updating itself'), findsOneWidget);
  });

  testWidgets('B cancels the wait; the app keeps starting', (t) async {
    final h = await start(t);
    await h.data.launchApp('steam', 'Steam');
    await frames(t);
    expect(view, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(t);
    expect(view, findsNothing);
    expect(h.mock.running.map((a) => a.id), contains('steam'));
    // Its window shows up later: nothing comes back.
    h.mock.finishStart('steam');
    await frames(t);
    expect(view, findsNothing);
  });

  testWidgets('Home cancels the wait', (t) async {
    final h = await start(t);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    h.mock.pressHome();
    await frames(t);
    expect(view, findsNothing);
  });

  testWidgets('a launch that fails shows the error dialog, no view', (t) async {
    final h = await start(t);
    await h.data.launchApp('no-such-app', 'Nothing');
    await frames(t);
    expect(view, findsNothing);
    expect(find.text("Couldn't start Nothing"), findsOneWidget);
  });

  testWidgets('an app that crashes while starting shows the error', (t) async {
    final h = await start(t);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await frames(t);
    h.mock.simulateExit('jellyfin', reason: ExitReason.crashed, exitCode: 1);
    await frames(t);
    await frames(t);
    expect(view, findsNothing);
    expect(find.text("Couldn't start Jellyfin"), findsOneWidget);
  });

  testWidgets('reduce motion: a still ring', (t) async {
    setView(t);
    final h = Harness(settings: const LauncherSettings(reduceMotion: true));
    h.mock.slowStart = true;
    await h.pump(t);
    await h.data.launchApp('jellyfin', 'Jellyfin');
    await t.pumpAndSettle();
    expect(view, findsOneWidget);
  });
}
