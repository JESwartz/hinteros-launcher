import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show NavAction, NavPhase;
import 'package:hinteros_launcher/src/system/models.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';
import 'session_test.dart' show frames, harness, keys, typePin;

/// Settings -> Profiles against the mock repositories.
void main() {
  /// Into the Profiles pane: the first row is James.
  Future<Harness> open(WidgetTester t, {String current = 'p1'}) async {
    setView(t);
    final h = harness(current: current);
    await h.pump(t);
    await enterSettingsEntry(t, 'profiles');
    return h;
  }

  testWidgets('the list: profiles with storage, Add, admin rows; no Switch', (
    t,
  ) async {
    await open(t);
    expect(focusLabel(), 'settings-detail/p-p1:0');
    expect(find.text('You · Admin · 52 GB used'), findsOneWidget);
    expect(find.text('Locked · 34 GB used'), findsOneWidget);
    expect(find.text('Add profile'), findsOneWidget);
    expect(find.text('Starter apps'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    // Switching is an option of the profile itself.
    expect(find.text('Switch profile'), findsNothing);
  });

  testWidgets('renaming another profile asks for the admin PIN', (t) async {
    final h = await open(t);
    await keys(t, [kDown, kEnter]); // Sam
    expect(find.text("Changes need the admin profile's PIN."), findsOneWidget);
    expect(find.text('Switch to this profile'), findsOneWidget);
    await keys(t, [kDown, kEnter]); // Rename
    await t.enterText(find.byType(EditableText), 'Samantha');
    // Enter only closes the keyboard (focus on Done); Done renames.
    await keys(t, [kEnter]);
    expect(find.byType(EditableText), findsOneWidget);
    await keys(t, [kEnter]);
    expect(find.text("Type the admin profile's PIN."), findsOneWidget);
    await typePin(t, '1357'); // Sam's own PIN is not the admin PIN
    expect(find.text('Wrong PIN.'), findsOneWidget);
    await typePin(t, '2468');
    expect(h.services.mockProfiles.log, contains('rename:p3:Samantha'));
    expect(find.text('Samantha'), findsOneWidget);
  });

  /// Sam's options -> Remove -> Remove: the PIN page whose OK is Delete.
  Future<void> toDeletePin(WidgetTester t) async {
    await keys(t, [kDown, kEnter]); // Sam
    // Switch to this profile, Rename, Give it a new PIN, Remove.
    await keys(t, [kDown, kDown, kDown, kEnter]);
    expect(find.text('Remove Sam?'), findsOneWidget);
    expect(
      find.textContaining("This deletes Sam's games (31 GB)"),
      findsOneWidget,
    );
    await keys(t, [kRight, kEnter]);
    // No "hold A" page: straight to the PIN, Delete instead of OK.
    expect(find.textContaining('Hold A for 3 seconds'), findsNothing);
    expect(find.text("Type the admin profile's PIN."), findsOneWidget);
    expect(
      find.textContaining('Hold A on Delete for 3 seconds.'),
      findsOneWidget,
    );
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
    expect(find.text('Erase'), findsOneWidget);
  }

  Future<void> digits(WidgetTester t, String pin) async {
    for (final c in pin.split('')) {
      await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
    }
    await t.pump();
  }

  /// How far the Delete key is filled with red (null: not held).
  double? fill() {
    final f = find.byType(FractionallySizedBox);
    if (f.evaluate().isEmpty) return null;
    return (f.evaluate().single.widget as FractionallySizedBox).widthFactor;
  }

  testWidgets('removing a profile: the PIN, then Delete held for 3 s', (
    t,
  ) async {
    final h = await open(t);
    await toDeletePin(t);
    await digits(t, '2468');
    expect(fill(), isNull);
    // Pressed: red at once, filling; let go after 1 s: empty, nothing runs.
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(fill(), closeTo(1 / 3, 0.05));
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(fill(), isNull, reason: 'released early: reset');
    expect(h.services.mockProfiles.log, isNot(contains('remove:p3')));
    await t.pump(const Duration(seconds: 3));
    expect(h.services.mockProfiles.log, isNot(contains('remove:p3')));
    // Held the whole 3 s: full, then removed.
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(milliseconds: 2900));
    expect(fill(), greaterThan(0.9));
    expect(h.services.mockProfiles.log, isNot(contains('remove:p3')));
    await t.pump(const Duration(milliseconds: 200));
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await frames(t);
    expect(h.services.mockProfiles.log, contains('remove:p3'));
    expect(find.text('Removing the profile'), findsOneWidget);
    final job = h.services.mockJobs.started.last;
    expect(job.kind, JobKind.profileRemove);
    h.services.mockJobs.finish(job.jobId);
    await frames(t);
    await keys(t, [kEnter]); // Continue
    expect(find.text('Sam'), findsNothing);
  });

  testWidgets('removing with a wrong PIN: the usual message, nothing deleted', (
    t,
  ) async {
    final h = await open(t);
    await toDeletePin(t);
    await digits(t, '1357'); // Sam's own PIN is not the admin PIN
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(milliseconds: 3100));
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Wrong PIN.'), findsOneWidget);
    expect(h.services.mockProfiles.log, isNot(contains('remove:p3')));
    expect(fill(), isNull);
  });

  testWidgets('Delete is held with A on the controller too', (t) async {
    final h = await open(t);
    await toDeletePin(t);
    await digits(t, '2468');
    // Onto Delete (bottom right of the pad).
    await keys(t, [kDown, kDown, kDown, kRight, kRight]);
    expect(focusLabel(), endsWith('/pin3:2'));
    h.mock.emitNav(NavAction.accept, NavPhase.press);
    // The event arrives, then the fill starts with the next frame.
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    expect(fill(), closeTo(0.5, 0.05));
    h.mock.emitNav(NavAction.accept, NavPhase.release);
    await t.pumpAndSettle();
    expect(fill(), isNull);
    expect(h.services.mockProfiles.log, isNot(contains('remove:p3')));
    h.mock.emitNav(NavAction.accept, NavPhase.press);
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 3100));
    h.mock.emitNav(NavAction.accept, NavPhase.release);
    await frames(t);
    expect(h.services.mockProfiles.log, contains('remove:p3'));
  });

  testWidgets('Switch to this profile: its PIN first, then the switch', (
    t,
  ) async {
    final h = await open(t);
    await keys(t, [kDown, kEnter]); // Sam
    await keys(t, [kEnter]); // Switch to this profile
    expect(find.text('Switch to Sam'), findsOneWidget);
    await typePin(t, '2468'); // the admin PIN is not Sam's
    expect(find.text('Wrong PIN.'), findsOneWidget);
    expect(h.services.mockProfiles.log, isNot(contains('switch:p3')));
    await typePin(t, '1357', settle: false);
    expect(h.services.mockProfiles.log, contains('switch:p3'));
    expect(find.text('Switching to Sam'), findsOneWidget);
    await frames(t, 20);
  });

  testWidgets('Lock and Unlock this profile say the same thing', (t) async {
    final h = await open(t, current: 'p3');
    await keys(t, [kDown, kEnter]); // Sam, the own, locked profile
    expect(find.text('Unlock this profile'), findsOneWidget);
    expect(find.text('Stop asking for the PIN'), findsNothing);
    // Rename, Colour, Change PIN, Unlock this profile.
    await keys(t, [kDown, kDown, kDown, kEnter]);
    expect(find.text('Unlock this profile'), findsOneWidget);
    await typePin(t, '1357');
    expect(h.services.mockProfiles.log, contains('set_locked:p3:false'));
  });

  testWidgets('the admin profile cannot be removed from here', (t) async {
    await open(t);
    await keys(t, [kEnter]); // James
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Lock this profile'), findsOneWidget);
  });

  testWidgets('locking the own profile needs its PIN', (t) async {
    final h = await open(t);
    await keys(t, [kEnter]); // James
    // Rename, Colour, Change PIN, Lock this profile.
    await keys(t, [kDown, kDown, kDown, kEnter]);
    expect(find.textContaining('Type your PIN to confirm'), findsOneWidget);
    await typePin(t, '2468');
    expect(h.services.mockProfiles.log, contains('set_locked:p1:true'));
    expect(find.text('You · Admin · Locked · 52 GB used'), findsOneWidget);
  });

  testWidgets('Add profile runs the form and Getting things ready', (t) async {
    final h = await open(t);
    await keys(t, [kDown, kDown, kEnter]); // Add profile
    await keys(t, [kEnter]);
    await t.enterText(find.byType(EditableText), 'Robin');
    await keys(t, [kEnter, kEnter]); // closes the keyboard, then Done
    await keys(t, [kDown, kEnter, kEnter]); // Continue, first colour
    await typePin(t, '2580');
    await typePin(t, '2580');
    await keys(t, [kDown]);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await frames(t);
    expect(find.text('Getting things ready'), findsOneWidget);
    h.services.mockJobs.finish(h.services.mockJobs.started.last.jobId);
    await frames(t);
    await keys(t, [kEnter]);
    expect(find.text('Robin'), findsOneWidget);
  });

  testWidgets('starter apps: chosen from the admin profile, admin PIN', (
    t,
  ) async {
    final h = await open(t);
    await keys(t, [kDown, kDown, kDown, kEnter]); // Starter apps
    expect(find.text('Starter apps'), findsWidgets);
    expect(find.text('2 chosen'), findsOneWidget);
    // Tick or untick the first app in the list, then Save.
    await keys(t, [kEnter]);
    expect(find.text('2 chosen'), findsNothing);
    for (var i = 0; i < 10; i++) {
      await keys(t, [kDown]);
    }
    await keys(t, [kRight, kEnter]); // Save
    await typePin(t, '2468', settle: false);
    expect(
      h.services.mockProfiles.log.where((l) => l.startsWith('starter:')),
      hasLength(1),
    );
  });

  testWidgets('the guest sees only switch and end', (t) async {
    setView(t);
    final h = harness(current: 'guest');
    await h.pump(t);
    await enterSettingsEntry(t, 'profiles');
    expect(find.text('Switch profile'), findsOneWidget);
    expect(find.text('End guest session'), findsOneWidget);
    expect(find.text('Add profile'), findsNothing);
  });

  testWidgets('app history: back to before a change', (t) async {
    final h = await open(t);
    await keys(t, [kEnter]); // James
    await keys(t, [kDown, kDown, kDown, kDown, kEnter]); // App history
    expect(find.text('App history'), findsOneWidget);
    expect(find.textContaining('Before installing'), findsWidgets);
    await keys(t, [kEnter]);
    expect(find.text('Put your apps back?'), findsOneWidget);
    await keys(t, [kRight, kEnter]);
    final job = h.services.mockJobs.started.last;
    expect(job.kind, JobKind.appsRollback);
    expect(h.services.mockStore.log, contains('rollback_apps:2'));
  });
}
