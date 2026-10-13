import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/models.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';
import 'session_test.dart' show frames, harness, keys, openChip, typePin;

/// Sam (p3, PIN 1357) removes Sam: Settings -> Profiles -> Sam -> Remove,
/// the PIN, Delete held.
Future<Harness> removeOwnProfile(WidgetTester t) async {
  setView(t);
  final h = harness(current: 'p3');
  await h.pump(t);
  await enterSettingsEntry(t, 'profiles');
  await keys(t, [kDown, kEnter]); // Sam, the own profile
  // Rename, Colour, Change PIN, Unlock this profile, App history, Remove.
  await keys(t, [kDown, kDown, kDown, kDown, kDown, kEnter]);
  expect(find.text('Remove Sam?'), findsOneWidget);
  await keys(t, [kRight, kEnter]);
  for (final c in '1357'.split('')) {
    await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
  }
  await t.pump();
  await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
  await t.pump();
  await t.pump(const Duration(milliseconds: 3100));
  await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
  await frames(t);
  expect(h.services.mockProfiles.log, contains('remove:p3'));
  return h;
}

/// A session that ends on purpose (its own profile removed, End guest
/// session, a switch under way): the service goes away with it, and the
/// launcher shows the ending page, never "Can't reach the HinterOS service".
void main() {
  final endingPage = find.byKey(const ValueKey('session-ending'));
  final connectionError = find
      .textContaining("Can't reach the HinterOS service")
      .hitTestable();

  testWidgets('removing your own profile: the Removing page, for good', (
    t,
  ) async {
    final h = await removeOwnProfile(t);
    expect(endingPage.hitTestable(), findsOneWidget);
    expect(find.text('Removing Sam…'), findsOneWidget);
    expect(find.text("You'll be taken to the profile picker."), findsNothing);
    // No way back: nav does nothing.
    await keys(t, [kEscape, kEscape, kUp, kEnter], settle: false);
    h.mock.pressHome();
    await frames(t);
    expect(endingPage.hitTestable(), findsOneWidget);
    // The session ends: the service goes away. Nothing but the page shows,
    // whatever comes after.
    h.mock.simulateDisconnect();
    await frames(t, 10);
    expect(endingPage.hitTestable(), findsOneWidget);
    expect(find.text('Removing Sam…'), findsOneWidget);
    expect(connectionError, findsNothing);
    expect(find.textContaining('Connecting to').hitTestable(), findsNothing);
    final job = h.services.mockJobs.started.last;
    h.services.mockJobs.finish(
      job.jobId,
      ok: false,
      error: const JobError(message: 'Lost track of it.'),
    );
    await frames(t, 10);
    expect(endingPage.hitTestable(), findsOneWidget);
    expect(find.text('Lost track of it.').hitTestable(), findsNothing);
  });

  testWidgets('removing your own profile fails: the page goes, the error '
      'shows', (t) async {
    final h = await removeOwnProfile(t);
    expect(endingPage.hitTestable(), findsOneWidget);
    final job = h.services.mockJobs.started.last;
    expect(job.kind, JobKind.profileRemove);
    h.services.mockJobs.finish(
      job.jobId,
      ok: false,
      error: const JobError(message: 'The disk was busy.'),
    );
    await frames(t, 10);
    expect(endingPage, findsNothing);
    expect(find.text("That didn't work").hitTestable(), findsOneWidget);
    expect(find.text('The disk was busy.').hitTestable(), findsOneWidget);
    await keys(t, [kEnter]); // Close
    expect(find.text("That didn't work"), findsNothing);
    expect(focusLabel(), 'settings-detail/p-p3:0');
    // The session goes on: input works, and a later lost connection is not
    // an ending (it shows as usual).
    await keys(t, [kEscape, kEscape]);
    expect(focusLabel(), 'home/apps:0');
    expect(find.text('Steam').hitTestable(), findsOneWidget);
    h.mock.simulateDisconnect();
    await frames(t);
    expect(endingPage, findsNothing);
    expect(find.byKey(const ValueKey('profile-loading')), findsNothing);
  });

  testWidgets('removing another profile ends nothing', (t) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await enterSettingsEntry(t, 'profiles');
    await keys(t, [kDown, kEnter]); // Sam
    await keys(t, [kDown, kDown, kDown, kEnter]); // Remove
    await keys(t, [kRight, kEnter]);
    for (final c in '2468'.split('')) {
      await t.sendKeyEvent(LogicalKeyboardKey(0x30 + int.parse(c)));
    }
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump(const Duration(milliseconds: 3100));
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await frames(t);
    expect(h.services.mockProfiles.log, contains('remove:p3'));
    expect(endingPage, findsNothing);
    expect(find.text('Removing the profile'), findsOneWidget);
  });

  testWidgets('End guest session: the service going away shows no error', (
    t,
  ) async {
    setView(t);
    final h = harness(current: 'guest');
    await h.pump(t);
    await openChip(t);
    await keys(t, [kDown, kEnter]); // End guest session
    await keys(t, [kRight, kEnter], settle: false);
    await frames(t, 20);
    expect(h.services.mockProfiles.log, contains('end_guest'));
    // While the service answers, the Switching page says what happens.
    expect(find.text('Leaving Guest').hitTestable(), findsOneWidget);
    expect(endingPage, findsNothing);
    h.mock.simulateDisconnect();
    await frames(t, 10);
    expect(endingPage.hitTestable(), findsOneWidget);
    expect(find.text('Ending the guest session…'), findsOneWidget);
    expect(connectionError, findsNothing);
    // Nothing moves it.
    await keys(t, [kEscape, kEnter], settle: false);
    await frames(t);
    expect(endingPage.hitTestable(), findsOneWidget);
  });

  testWidgets('a switch under way: the service going away shows no error', (
    t,
  ) async {
    setView(t);
    final h = harness();
    await h.pump(t);
    await openChip(t);
    await keys(t, [kEnter, kRight, kEnter]); // Switch profile, Sam
    await typePin(t, '1357', settle: false);
    await frames(t, 20);
    expect(find.text('Switching to Sam').hitTestable(), findsOneWidget);
    expect(find.text('Opening Sam...'), findsOneWidget);
    expect(endingPage, findsNothing);
    h.mock.simulateDisconnect();
    await frames(t, 10);
    expect(endingPage.hitTestable(), findsOneWidget);
    expect(find.text('Switching to Sam…'), findsOneWidget);
    expect(connectionError, findsNothing);
  });

  testWidgets('a cancelled switch: the session goes on, errors show again', (
    t,
  ) async {
    setView(t);
    final h = harness();
    h.services.mockProfiles.blockingApp = (id: 'youtube', name: 'YouTube');
    await h.pump(t);
    await openChip(t);
    await keys(t, [kEnter, kRight, kEnter]);
    await typePin(t, '1357', settle: false);
    await frames(t, 10);
    await keys(t, [kRight, kRight, kEnter], settle: false); // Cancel switch
    await frames(t, 10);
    expect(h.services.mockProfiles.log, contains('switch_cancel'));
    expect(find.textContaining('Switching to'), findsNothing);
    h.mock.pressHome();
    await t.pumpAndSettle();
    h.mock.simulateDisconnect();
    await frames(t);
    expect(endingPage, findsNothing);
    expect(connectionError, findsOneWidget);
  });
}
