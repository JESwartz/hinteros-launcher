import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('the list: profiles with storage, Add, Switch, admin rows', (
    t,
  ) async {
    await open(t);
    expect(focusLabel(), 'settings-detail/p-p1:0');
    expect(find.text('You · Admin · 52 GB used'), findsOneWidget);
    expect(find.text('Locked · 34 GB used'), findsOneWidget);
    expect(find.text('Add profile'), findsOneWidget);
    expect(find.text('Starter apps'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
  });

  testWidgets('renaming another profile asks for the admin PIN', (t) async {
    final h = await open(t);
    await keys(t, [kDown, kEnter]); // Sam
    expect(
      find.text("Changing another profile needs the admin profile's PIN."),
      findsOneWidget,
    );
    await keys(t, [kEnter]); // Rename
    await t.enterText(find.byType(EditableText), 'Samantha');
    await keys(t, [kEnter]);
    expect(find.text("This needs the admin profile's PIN."), findsOneWidget);
    await typePin(t, '1357'); // Sam's own PIN is not the admin PIN
    expect(find.text("That PIN didn't match."), findsOneWidget);
    await typePin(t, '2468');
    expect(h.services.mockProfiles.log, contains('rename:p3:Samantha'));
    expect(find.text('Samantha'), findsOneWidget);
  });

  testWidgets('removing a profile: two confirmations, then the PIN', (t) async {
    final h = await open(t);
    await keys(t, [kDown, kEnter]); // Sam
    // Rename, Give it a new PIN, Remove.
    await keys(t, [kDown, kDown, kEnter]);
    expect(find.text('Remove Sam?'), findsOneWidget);
    expect(
      find.textContaining("This deletes Sam's games (31 GB)"),
      findsOneWidget,
    );
    await keys(t, [kRight, kEnter]);
    expect(find.text('Hold A for 3 seconds to remove Sam.'), findsOneWidget);
    // A short press is not enough.
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump(const Duration(seconds: 1));
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Hold A for 3 seconds to remove Sam.'), findsOneWidget);
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(milliseconds: 3100));
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(
      find.text("Type the admin profile's PIN to remove Sam."),
      findsOneWidget,
    );
    await typePin(t, '2468', settle: false);
    expect(h.services.mockProfiles.log, contains('remove:p3'));
    expect(find.text('Removing the profile'), findsOneWidget);
    final job = h.services.mockJobs.started.last;
    expect(job.kind, JobKind.profileRemove);
    h.services.mockJobs.finish(job.jobId);
    await frames(t);
    await keys(t, [kEnter]); // Continue
    expect(find.text('Sam'), findsNothing);
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
    await keys(t, [kEnter]);
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
    await keys(t, [kDown, kDown, kDown, kDown, kEnter]); // Starter apps
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
