import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show AppsLaunchParams;
import 'package:hinteros_launcher/src/system/mock_system.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// Profiles inside a session, against the mock repositories: the chip and
/// its menu, switching (and the not-responding pop-up), the sleep lock,
/// first-boot mode, the first PIN of a migrated profile, ending the guest
/// session.
Future<void> frames(WidgetTester t, [int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

const up = kUp, down = kDown, left = kLeft, right = kRight;
const enter = kEnter, escape = kEscape;

Future<void> keys(
  WidgetTester t,
  List<LogicalKeyboardKey> ks, {
  bool settle = true,
}) async {
  for (final k in ks) {
    await t.sendKeyEvent(k);
    settle ? await t.pumpAndSettle() : await t.pump();
  }
}

Future<void> typePin(WidgetTester t, String pin, {bool settle = true}) async {
  for (final c in pin.split('')) {
    await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
  }
  await t.sendKeyEvent(LogicalKeyboardKey.enter);
  settle ? await t.pumpAndSettle() : await frames(t);
}

Harness harness({
  String current = 'p1',
  bool setupRequired = false,
  MockProfileBox? box,
}) => Harness(
  services: MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    currentProfile: current,
    setupRequired: setupRequired,
    profileBox: box,
  ),
);

/// Up to the tabs, left onto the chip (the tab row wraps), A.
Future<void> openChip(WidgetTester t) async {
  await keys(t, [up, left]);
  expect(focusLabel(), 'tabs/tabs:5');
  await keys(t, [enter]);
}

void main() {
  appearanceTests();
  pickerRefreshTests();
  testWidgets('the chip opens Switch profile and Profile settings', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    expect(find.text('J'), findsOneWidget);
    await openChip(t);
    expect(find.text('James'), findsOneWidget);
    expect(find.text('Switch profile'), findsOneWidget);
    expect(find.text('Profile settings'), findsOneWidget);
    await keys(t, [down, enter]); // Profile settings
    expect(focusLabel(), 'settings-list/profiles:0');
  });

  testWidgets('switching: what closes, then the Switching page', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await h.launch(t, 'youtube');
    h.mock.pressHome();
    await t.pumpAndSettle();
    await openChip(t);
    await keys(t, [enter]); // Switch profile
    // The boot picker's screen, James marked open and focused.
    expect(find.text('Who is watching?'), findsOneWidget);
    for (final n in ['James', 'Sam', 'Guest', 'Add profile', 'Power']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(find.byKey(const ValueKey('current-badge')), findsOneWidget);
    expect(focusLabel(), endsWith('/tiles:0'));
    // Sam is locked: Sam's PIN first, in this session (YouTube is not a
    // game: no other question). A wrong one changes nothing; B goes back.
    await keys(t, [right, enter]);
    expect(find.text('Switch to Sam'), findsOneWidget);
    expect(
      find.textContaining('Nothing in this profile closes until'),
      findsOneWidget,
    );
    await typePin(t, '0000');
    expect(find.text("That PIN didn't match."), findsOneWidget);
    expect(h.services.mockProfiles.log, isNot(contains('switch:p3')));
    await keys(t, [escape]);
    expect(find.text('Switch to Sam'), findsNothing);
    expect(find.textContaining('Switching'), findsNothing);
    expect(h.mock.running.map((a) => a.id), contains('youtube'));
    // Back on the chip. Again, with the right PIN: then the switch.
    expect(focusLabel(), 'tabs/tabs:5');
    await keys(t, [enter, enter, right, enter]);
    await typePin(t, '1357', settle: false);
    expect(h.services.mockProfiles.log, contains('switch:p3'));
    expect(find.text('Switching to Sam'), findsOneWidget);
    await frames(t, 20);
    expect(find.text('Opening Sam...'), findsOneWidget);
    expect(h.services.mockProfiles.switchedTo, 'p3');
  });

  testWidgets('an app that does not close: keep waiting, force close', (
    t,
  ) async {
    setView(t);
    final h = harness();
    h.services.mockProfiles.blockingApp = (id: 'youtube', name: 'YouTube');
    await h.pump(t);
    await openChip(t);
    await keys(t, [enter, right, enter]); // Switch profile, Sam
    await typePin(t, '1357', settle: false);
    await frames(t, 10);
    expect(find.textContaining("YouTube isn't responding ("), findsOneWidget);
    // The time keeps counting from the daemon's waited_s, a second a second.
    int shown() {
      final w = t.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains("isn't responding"),
        ),
      );
      return int.parse(RegExp(r'\((\d+) s\)').firstMatch(w.data!)!.group(1)!);
    }

    final first = shown();
    expect(first, inInclusiveRange(10, 11));
    await t.pump(const Duration(seconds: 3));
    expect(shown(), first + 3);
    expect(
      find.text('Force-closing it may lose unsaved data.'),
      findsOneWidget,
    );
    expect(focusLabel(), endsWith('/buttons:0'));
    await keys(t, [enter], settle: false); // Keep waiting
    await t.pump(const Duration(milliseconds: 1050));
    expect(find.textContaining("YouTube isn't responding (2"), findsOneWidget);
    await keys(t, [right, enter], settle: false); // Force close
    await frames(t, 20);
    expect(h.services.mockProfiles.log, contains('force_close:youtube'));
    expect(h.services.mockProfiles.switchedTo, 'p3');
  });

  testWidgets('Cancel switch keeps the profile', (t) async {
    setView(t);
    final h = harness();
    h.services.mockProfiles.blockingApp = (id: 'youtube', name: 'YouTube');
    await h.pump(t);
    await openChip(t);
    await keys(t, [enter, right, enter]);
    await typePin(t, '1357', settle: false);
    await frames(t, 10);
    await keys(t, [right, right, enter], settle: false);
    await frames(t, 10);
    expect(h.services.mockProfiles.log, contains('switch_cancel'));
    expect(find.textContaining('Switching to'), findsNothing);
    expect(h.services.mockProfiles.switchedTo, isNull);
  });

  testWidgets('the sleep lock asks for the PIN', (t) async {
    setView(t);
    final h = harness(current: 'p3');
    await h.pump(t);
    h.services.mockProfiles.sleep();
    await t.pumpAndSettle();
    expect(
      find.text('This profile is locked. Type its PIN to go on.'),
      findsOneWidget,
    );
    // B on the empty pad does not leave.
    await keys(t, [escape]);
    expect(
      find.text('This profile is locked. Type its PIN to go on.'),
      findsOneWidget,
    );
    // How a forgotten PIN is removed (root, in a terminal).
    expect(find.text('Forgot your PIN?'), findsOneWidget);
    expect(
      find.textContaining('sudo hinteros-system reset-pin Sam'),
      findsOneWidget,
    );
    await typePin(t, '2468');
    expect(find.text("That PIN didn't match."), findsOneWidget);
    await typePin(t, '1357');
    expect(find.textContaining('This profile is locked'), findsNothing);
    expect(h.services.mockProfiles.log, contains('unlock'));
  });

  testWidgets('first-boot mode creates the admin profile', (t) async {
    setView(t);
    final box = MockProfileBox(profiles: [], now: fixedNow);
    final h = harness(current: 'p1', setupRequired: true, box: box);
    await h.pump(t);
    expect(find.text('Welcome'), findsOneWidget);
    await keys(t, [enter]); // Start
    expect(find.text('Controllers'), findsOneWidget);
    // Continue through controllers, network and display; the last Continue
    // opens the profile form itself.
    for (final title in ['Internet', 'Display', 'Step 1 of 5']) {
      for (var i = 0; i < 20 && find.text(title).evaluate().isEmpty; i++) {
        await keys(t, [down]);
        if (focusLabel()?.endsWith('/actions:0') ?? false) {
          await keys(t, [enter]);
        }
      }
      expect(find.text(title), findsWidgets, reason: title);
    }
    // B in the form comes back to Display; Continue opens it again.
    await keys(t, [escape]);
    expect(find.text('Step 1 of 5'), findsNothing);
    expect(find.text('Display'), findsOneWidget);
    for (
      var i = 0;
      i < 20 && find.text('Step 1 of 5').evaluate().isEmpty;
      i++
    ) {
      await keys(t, [down]);
      if (focusLabel()?.endsWith('/actions:0') ?? false) {
        await keys(t, [enter]);
      }
    }
    expect(find.text('Step 1 of 5'), findsOneWidget);
    await keys(t, [enter]); // the name field: the text dialog
    await t.enterText(find.byType(EditableText), 'James');
    // Enter only closes the keyboard (focus on Done); Done takes the name.
    await keys(t, [enter]);
    expect(find.byType(EditableText), findsOneWidget);
    await keys(t, [enter]);
    await keys(t, [down, enter]); // Continue
    await keys(t, [enter]); // the first colour
    await typePin(t, '2468');
    await typePin(t, '2468');
    await keys(t, [down, enter]); // Create my profile
    expect(find.text('All set'), findsOneWidget);
    expect(h.services.mockProfiles.log, contains('setup_admin:p1:James'));
    await keys(t, [enter]); // Go to Home
    expect(find.text('All set'), findsNothing);
    expect(find.text('J'), findsOneWidget);
    expect(box.admin.pin, '2468');
  });

  testWidgets('a migrated profile without a PIN sets one first', (t) async {
    setView(t);
    final box = MockProfileBox(now: fixedNow);
    box.byId('p1')!.pin = null;
    final h = harness(box: box);
    await h.pump(t);
    expect(find.text('Set your PIN'), findsOneWidget);
    // A new PIN is chosen here: no "Forgot your PIN?".
    expect(find.text('Forgot your PIN?'), findsNothing);
    await keys(t, [escape]);
    expect(find.text('Set your PIN'), findsOneWidget, reason: 'unskippable');
    await typePin(t, '1234');
    expect(find.text('Type the PIN again.'), findsOneWidget);
    await typePin(t, '1234');
    expect(find.text('Set your PIN'), findsNothing);
    expect(box.byId('p1')!.pin, '1234');
  });

  testWidgets('the guest ends its session from the chip', (t) async {
    setView(t);
    final h = harness(current: 'guest');
    await h.pump(t);
    await openChip(t);
    expect(find.text('End guest session'), findsOneWidget);
    expect(find.text('Profile settings'), findsNothing);
    await keys(t, [down, enter]);
    expect(find.text('End the guest session?'), findsOneWidget);
    await keys(t, [right, enter], settle: false);
    await frames(t, 20);
    expect(h.services.mockProfiles.log, contains('end_guest'));
    expect(find.text('Leaving Guest'), findsOneWidget);
  });

  testWidgets('Switch profile: the open profile (or B) goes back to it, '
      'nothing is called', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await h.launch(t, 'youtube');
    h.mock.pressHome();
    await t.pumpAndSettle();
    await openChip(t);
    await keys(t, [enter]); // Switch profile
    expect(find.text('Who is watching?'), findsOneWidget);
    await keys(t, [enter]); // James, the open one
    expect(find.text('Who is watching?'), findsNothing);
    expect(find.textContaining('Switching'), findsNothing);
    expect(
      h.services.mockProfiles.log.where((l) => l.startsWith('switch')),
      isEmpty,
    );
    expect(h.mock.running.map((a) => a.id), contains('youtube'));
    // B: the same (the focus is back on the chip).
    expect(focusLabel(), 'tabs/tabs:5');
    await keys(t, [enter, enter, right]);
    await keys(t, [escape]);
    expect(find.text('Who is watching?'), findsNothing);
    expect(
      h.services.mockProfiles.log.where((l) => l.startsWith('switch')),
      isEmpty,
    );
  });

  testWidgets('a running game is the one question before a switch', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await h.mock.appsLaunch(
      const AppsLaunchParams(url: 'steam://rungameid/504230'),
    );
    await t.pumpAndSettle();
    h.mock.pressHome();
    await t.pumpAndSettle();
    await openChip(t);
    await keys(t, [enter, right, enter]); // Switch profile, Sam
    expect(find.text('Celeste is still running'), findsOneWidget);
    expect(h.services.mockProfiles.log, isNot(contains('switch:p3')));
    await keys(t, [right, enter]); // Close it and switch
    await typePin(t, '1357', settle: false); // Sam is locked
    expect(h.services.mockProfiles.log, contains('switch:p3'));
    expect(find.text('Switching to Sam'), findsOneWidget);
    await frames(t, 20);
  });

  testWidgets('Guest from the in-session picker switches to the guest', (
    t,
  ) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openChip(t);
    await keys(t, [enter, right, right, enter], settle: false);
    await frames(t);
    expect(h.services.mockProfiles.log, contains('switch:guest'));
    await frames(t, 20);
  });
}

void appearanceTests() {
  testWidgets('the picker gets the profile\'s text size and contrast', (
    t,
  ) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    expect(h.services.mockProfiles.appearance, (
      textScale: 1.0,
      highContrast: false,
      reduceMotion: false,
    ));
    h.settings.update(
      h.settings.value.copyWith(textScale: 1.4, highContrast: true),
    );
    await t.pumpAndSettle();
    expect(h.services.mockProfiles.appearance, (
      textScale: 1.4,
      highContrast: true,
      reduceMotion: false,
    ));
  });
}

void pickerRefreshTests() {
  testWidgets('the in-session picker follows profiles_changed', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openChip(t);
    await keys(t, [enter]); // Switch profile
    expect(find.text('Sam'), findsOneWidget);
    // Removed meanwhile (from another session, or a job that just ended).
    final job = await h.services.mockProfiles.remove('p3', '2468');
    h.services.mockJobs.finish(job.jobId);
    await t.pumpAndSettle();
    expect(find.text('Who is watching?'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);
    expect(find.text('James'), findsOneWidget);
  });
}
