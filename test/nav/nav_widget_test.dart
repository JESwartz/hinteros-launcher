import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';

import '../support/harness.dart';

/// Navigation rules end to end: shell, regions, focus nodes.
void main() {
  const up = LogicalKeyboardKey.arrowUp;
  const down = LogicalKeyboardKey.arrowDown;
  const left = LogicalKeyboardKey.arrowLeft;
  const right = LogicalKeyboardKey.arrowRight;
  const enter = LogicalKeyboardKey.enter;
  const escape = LogicalKeyboardKey.escape;

  Future<Harness> start(WidgetTester t, {Harness? h}) async {
    setView(t);
    h ??= Harness();
    await h.pump(t);
    return h;
  }

  Future<void> keys(WidgetTester t, List<LogicalKeyboardKey> ks) async {
    for (final k in ks) {
      await t.sendKeyEvent(k);
      await t.pumpAndSettle();
    }
  }

  testWidgets('home rows remember their column', (t) async {
    final h = await start(t);
    await h.launch(t, 'jellyfin'); // Continue row appears (1 item)
    await h.launch(t, 'steam'); // and a second
    await keys(t, [right, right, right]); // apps:3
    expect(focusLabel(), 'home/apps:3');
    await keys(t, [up]); // continue, entered at col 1 (clamped)
    expect(focusLabel(), 'home/continue:1');
    await keys(t, [down]); // back to apps at the remembered 3
    expect(focusLabel(), 'home/apps:3');
    await keys(t, [down]);
    expect(focusLabel(), 'home/games:3');
    await keys(t, [right, right, up]);
    expect(focusLabel(), 'home/apps:3');
    await keys(t, [down]);
    expect(focusLabel(), 'home/games:5');
  });

  testWidgets('left/right stop at row ends', (t) async {
    await start(t);
    await keys(t, [left, left]);
    expect(focusLabel(), 'home/apps:0');
    await keys(t, List.filled(20, right));
    expect(focusLabel(), 'home/apps:7');
  });

  testWidgets('up from the top row goes to the tabs; tabs wrap', (t) async {
    await start(t);
    await keys(t, [up]);
    expect(focusLabel(), 'tabs/tabs:0');
    await keys(t, [left]);
    expect(focusLabel(), 'tabs/tabs:3', reason: 'wraps to Settings');
    expect(find.text('System'), findsOneWidget);
    await keys(t, [right]);
    expect(focusLabel(), 'tabs/tabs:0');
    await keys(t, [down]);
    expect(focusLabel(), 'home/apps:0');
  });

  testWidgets('the section follows tab focus and is remembered', (t) async {
    await start(t);
    await keys(t, [up, right, down, right, right, down]);
    expect(focusLabel(), 'games/r0:2'.replaceFirst('r0:2', 'r1:2'));
    await keys(t, [up, up]); // r0, then tabs
    expect(focusLabel(), 'tabs/tabs:1');
    await keys(t, [right, left, down]);
    expect(focusLabel(), 'games/r0:2', reason: 'section keeps its position');
  });

  testWidgets('grid column is sticky across a short last row', (t) async {
    await start(t);
    // 14 games, 6 columns: rows of 6, 6, 2.
    await keys(t, [up, right, down, right, right, right, right, right]);
    expect(focusLabel(), 'games/r0:5');
    await keys(t, [down, down]);
    expect(focusLabel(), 'games/r2:1');
    await keys(t, [down]);
    expect(focusLabel(), 'games/r2:1', reason: 'bottom is an edge');
    await keys(t, [up, up]);
    expect(focusLabel(), 'games/r0:5');
  });

  testWidgets('Back: section to Home, Home stays; Home button resets', (
    t,
  ) async {
    final h = await start(t);
    await keys(t, [right, right, down]); // home games row, col 2
    await keys(t, [up, up, up, right, down]); // tabs, Games, into grid
    expect(focusLabel(), startsWith('games/'));
    await keys(t, [escape]);
    expect(focusLabel(), 'home/apps:2');
    await keys(t, [escape]); // on Home: nothing
    expect(focusLabel(), 'home/apps:2');
    h.mock.pressHome();
    await t.pumpAndSettle();
    expect(focusLabel(), 'home/apps:0');
  });

  testWidgets('Back from the tab bar goes Home', (t) async {
    await start(t);
    await keys(t, [up, right, right]);
    expect(focusLabel(), 'tabs/tabs:2');
    await keys(t, [escape]);
    expect(focusLabel(), 'home/apps:0');
  });

  testWidgets('settings: list to detail and Back one level at a time', (
    t,
  ) async {
    final h = await start(t);
    await keys(t, [up, right, right, right, down]);
    expect(focusLabel(), 'settings-list/text:0');
    await keys(t, [right]);
    expect(focusLabel(), 'settings-detail/o0:0');
    await keys(t, [down, enter]); // 120%
    expect(h.settings.value.textScale, 1.2);
    await keys(t, [left]);
    expect(focusLabel(), 'settings-list/text:0');
    await keys(t, [right, escape]); // detail -> list
    expect(focusLabel(), 'settings-list/text:0');
    await keys(t, [escape]); // section -> Home
    expect(focusLabel(), startsWith('home/'));
  });

  testWidgets('system placeholder has no detail to enter', (t) async {
    await start(t);
    await keys(t, [up, right, right, right, down, down, down, down, down]);
    expect(focusLabel(), 'settings-list/system:0');
    await keys(t, [right, enter]);
    expect(focusLabel(), 'settings-list/system:0');
    expect(find.textContaining('M5'), findsOneWidget);
  });

  testWidgets('page right/left switch tabs from anywhere', (t) async {
    await start(t);
    await keys(t, [LogicalKeyboardKey.pageDown]);
    expect(find.text('Hollow Knight'), findsOneWidget);
    expect(focusLabel(), startsWith('games/'));
    await keys(t, [LogicalKeyboardKey.pageUp]);
    expect(focusLabel(), startsWith('home/'));
  });

  testWidgets('works through input_nav too, with a 720p window scaled', (
    t,
  ) async {
    setView(t, size: const Size(1280, 720));
    final h = Harness();
    await h.pump(t);
    h.mock.emitNav(NavAction.up);
    await t.pumpAndSettle();
    h.mock.emitNav(NavAction.right);
    await t.pumpAndSettle();
    expect(focusLabel(), 'tabs/tabs:1');
  });

  testWidgets('reduce motion: no scale, same navigation', (t) async {
    await start(
      t,
      h: Harness(settings: const LauncherSettings(reduceMotion: true)),
    );
    await keys(t, [right]);
    expect(focusLabel(), 'home/apps:1');
  });
}
