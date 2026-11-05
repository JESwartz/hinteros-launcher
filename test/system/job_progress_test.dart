// The job progress page and the jobs the person left running: building
// with count, name and time, the bar that moves, the heartbeat gap, titles
// per kind, the top bar indicator, the notice when a job ends, the session
// restart offer with its countdown, and a launcher restart during a job.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/storage.dart'
    show CleanupFrequency;
import 'package:hinteros_launcher/src/ui/jobs.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

/// A harness whose job clock the test moves on.
(Harness, void Function(Duration)) harness() {
  final h = Harness(
    services: MockSystemServices(iconDir: iconDir(), now: fixedNow),
  );
  var now = fixedNow();
  h.services.mockJobs.clock = () => now;
  return (h, (d) => now = now.add(d));
}

Future<void> toUpdateNow(WidgetTester t, Harness h) async {
  h.services.mockUpdates.nextAvailable = mockOrdinaryUpdate();
  await enterSettingsEntry(t, 'updates');
  await press(t, [kEnter]); // Check for updates
  await press(t, [kDown, kEnter, kRight, kEnter]); // Update now, confirm
  await enterPin(t, '2468'); // the admin PIN
}

BuildProgress build(
  int done, {
  int total = 12,
  String? phase = 'build',
  int? percent,
}) => BuildProgress(
  done: done,
  total: total,
  running: 1,
  name: 'hinteros-daemon',
  version: '0.7.1',
  phase: phase,
  percent: percent,
);

Alignment barAlignment(WidgetTester t) => t
    .widget<AnimatedAlign>(
      find.descendant(
        of: find.byKey(const ValueKey('job-bar')),
        matching: find.byType(AnimatedAlign),
      ),
    )
    .alignment
    .resolve(TextDirection.ltr);

final indicator = find.byKey(const ValueKey('job-indicator'));

/// From a settings pane up to the tab row, right onto the indicator (after
/// the Settings tab), and A.
Future<void> openIndicatorFromSettings(WidgetTester t) async {
  for (var i = 0; i < 20 && !(focusLabel() ?? '').startsWith('tabs'); i++) {
    await press(t, [kUp]);
  }
  // Settings is the sixth tab; the indicator comes next.
  for (var i = 0; i < 7 && focusLabel() != 'tabs/tabs:6'; i++) {
    await press(t, [kRight]);
  }
  expect(focusLabel(), 'tabs/tabs:6');
  await press(t, [kEnter]);
}

void main() {
  mockScript();
  group('the page', () {
    testWidgets('a job another profile started: Cancel asks for the admin '
        'PIN', (t) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      h.services.mockJobs.startedByOther.add(job.jobId);
      await press(t, [kRight, kEnter]); // Cancel (after Hide)
      expect(find.text("Type the admin profile's PIN."), findsOneWidget);
      await enterPin(t, '1111');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.snapshot(job.jobId)!.running, isTrue);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.snapshot(job.jobId)!.cancelled, isTrue);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('building: the count, the name, the time, and it moves', (
      t,
    ) async {
      setView(t);
      final (h, advance) = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      expect(find.text('Updating to HinterOS 0.6.1'), findsOneWidget);
      expect(find.text('Now on HinterOS 0.6.0.'), findsOneWidget);
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.building,
        percent: 20,
        build: build(2),
      );
      await t.pumpAndSettle();
      expect(find.text('3 of 12'), findsOneWidget);
      expect(find.text('hinteros-daemon 0.7.1, compiling'), findsOneWidget);
      expect(find.textContaining('Time elapsed: 00:0'), findsOneWidget);
      expect(find.textContaining('20% in all'), findsOneWidget);
      // Nothing new from the job for a second: the bar moves anyway.
      final before = barAlignment(t);
      await t.pump(const Duration(seconds: 1));
      expect(barAlignment(t), isNot(before));
      await t.pumpAndSettle();
      // Twelve minutes on, the next one builds.
      advance(const Duration(minutes: 12));
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.building,
        percent: 30,
        build: build(3, phase: 'install'),
      );
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.text('4 of 12'), findsOneWidget);
      expect(find.text('hinteros-daemon 0.7.1, installing'), findsOneWidget);
      expect(find.textContaining('Time elapsed: 12:0'), findsOneWidget);
      // Session API 0.18: the build's own percent from its phase.
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.building,
        percent: 32,
        build: build(3, phase: 'install', percent: 88),
      );
      await t.pumpAndSettle();
      expect(
        find.text('hinteros-daemon 0.7.1: 88%, installing'),
        findsOneWidget,
      );
      expect(find.textContaining('32% in all'), findsOneWidget);
      // No estimate of the time left.
      expect(find.textContaining('left'), findsNothing);
    });

    testWidgets('no heartbeat for a while: it says the job still runs', (
      t,
    ) async {
      setView(t);
      final (h, advance) = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.building,
        build: build(0),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('job-quiet')), findsNothing);
      // Heartbeats every 2 s: nothing to say.
      for (var i = 0; i < 5; i++) {
        advance(const Duration(seconds: 2));
        h.services.mockJobs.heartbeat(job.jobId);
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const ValueKey('job-quiet')), findsNothing);
      // Then 30 s without one.
      advance(const Duration(seconds: 30));
      await t.pump(const Duration(seconds: 1));
      expect(
        find.text('No news for 30 s. The job is still running.'),
        findsOneWidget,
      );
      expect(find.textContaining('failed'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      // A heartbeat again: the note goes.
      h.services.mockJobs.heartbeat(job.jobId);
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('job-quiet')), findsNothing);
      // Heartbeats but no output for 4 min: some steps take long.
      for (var i = 0; i < 24; i++) {
        advance(const Duration(seconds: 10));
        h.services.mockJobs.heartbeat(job.jobId);
      }
      await t.pump(const Duration(seconds: 1));
      expect(find.text('No new output for 4 min.'), findsOneWidget);
      await t.pumpAndSettle();
    });
  });

  group('titles', () {
    JobSnapshot snap(JobKind kind, JobSubject subject) =>
        JobSnapshot(jobId: 'j', kind: kind, subject: subject);
    const moonlight = (id: 'moonlight', name: 'Moonlight');
    const steam = (id: 'steam', name: 'Steam');
    final cases = <(JobKind, JobSubject, String, String?)>[
      (
        JobKind.update,
        const JobSubject(
          version: '0.7.1.c6b69ce beta',
          fromVersion: '0.7.1.1a2b3c4 beta',
        ),
        'Updating to HinterOS 0.7.1.c6b69ce beta',
        'Now on HinterOS 0.7.1.1a2b3c4 beta.',
      ),
      (JobKind.update, const JobSubject(), 'Updating HinterOS', null),
      (
        JobKind.install,
        const JobSubject(apps: [moonlight], profileName: 'Sam'),
        'Installing Moonlight',
        'For Sam.',
      ),
      (
        JobKind.install,
        const JobSubject(apps: [moonlight, steam], owner: 'guest'),
        'Installing Moonlight and Steam',
        'For the guest.',
      ),
      (
        JobKind.install,
        const JobSubject(fromOwner: 'starter', profileName: 'Robin'),
        'Adding the starter apps',
        'For Robin.',
      ),
      (
        JobKind.remove,
        const JobSubject(apps: [steam], deleteData: true),
        'Removing Steam',
        'The app data is deleted too.',
      ),
      (
        JobKind.rollback,
        const JobSubject(generation: 10, fromGeneration: 12),
        'Rolling back to generation 10',
        'Now on generation 12.',
      ),
      (
        JobKind.channel,
        const JobSubject(
          fromChannel: UpdateChannel.beta,
          channel: UpdateChannel.stable,
          version: '0.7.0 stable',
        ),
        'Switching from Beta to Stable',
        'New version: HinterOS 0.7.0 stable.',
      ),
      (
        JobKind.base,
        const JobSubject(fromBase: NixBase.unstable, base: NixBase.stable),
        'Switching the base from Latest to Stable',
        null,
      ),
      (
        JobKind.ssh,
        const JobSubject(enabled: true),
        'Turning on remote access',
        null,
      ),
      (
        JobKind.appsRollback,
        const JobSubject(generation: 4, profileName: 'Sam'),
        'Rolling back apps to generation 4',
        'For Sam.',
      ),
      (
        JobKind.profileCreate,
        const JobSubject(profileName: 'Robin'),
        'Creating the profile Robin',
        null,
      ),
      (
        JobKind.profileRemove,
        const JobSubject(profileName: 'Alex'),
        'Removing the profile Alex',
        null,
      ),
      (
        JobKind.guest,
        const JobSubject(enabled: false),
        'Turning off Guest',
        null,
      ),
      (
        JobKind.starterSet,
        const JobSubject(owner: 'starter', apps: [moonlight, steam]),
        'Saving the starter apps',
        '2 apps.',
      ),
      (
        JobKind.guestEnd,
        const JobSubject(owner: 'guest'),
        'Ending the guest session',
        null,
      ),
      (JobKind.storageMeasure, const JobSubject(), 'Scanning the disk', null),
      (
        JobKind.cleanupSystem,
        const JobSubject(keep: 3),
        'Cleaning up the system',
        'Keeps the 3 newest versions.',
      ),
      (
        JobKind.cleanupProfiles,
        const JobSubject(keep: 1),
        'Cleaning up profiles',
        'Keeps the newest version.',
      ),
      (
        JobKind.cleanupSet,
        const JobSubject(
          enabled: true,
          frequency: CleanupFrequency.weekly,
          keepSystem: 5,
          keepProfiles: 5,
        ),
        'Saving the automatic clean-up',
        'Every week.',
      ),
      (
        JobKind.cleanupSet,
        const JobSubject(enabled: false),
        'Turning off automatic clean-up',
        null,
      ),
      (
        JobKind.hardwareRedetect,
        const JobSubject(),
        'Detecting hardware',
        null,
      ),
      (JobKind.updateCheck, const JobSubject(), 'Checking for updates', null),
      (JobKind.rebuild, const JobSubject(), 'Applying changes', null),
    ];
    for (final (kind, subject, title, sub) in cases) {
      test('${kind.name}: $title', () {
        final s = snap(kind, subject);
        expect(jobTitle(s), title);
        expect(jobSubtitle(s), sub);
      });
    }

    test('every kind has a title', () {
      for (final k in JobKind.values) {
        expect(jobTitle(snap(k, const JobSubject())), isNotEmpty);
      }
    });

    test('the caller names a Store job when the service does not', () {
      expect(
        jobTitle(snap(JobKind.install, const JobSubject()), name: 'Kodi'),
        'Installing Kodi',
      );
    });

    test('the elapsed time and the build phases in words', () {
      expect(elapsedText(const Duration(seconds: 40)), '00:40');
      expect(elapsedText(const Duration(minutes: 12, seconds: 5)), '12:05');
      expect(elapsedText(const Duration(minutes: 65)), '1:05:00');
      expect(elapsedText(const Duration(seconds: -3)), '00:00');
      expect(buildCount(build(11)), '12 of 12');
      // Nix found more than it said: the count never passes the total.
      expect(buildCount(build(12)), '12 of 12');
      expect(
        buildName(
          const BuildProgress(name: 'mesa', version: '25.2.3', running: 3),
        ),
        'mesa 25.2.3 (and 2 more)',
      );
      expect(
        buildName(build(2, percent: 20)),
        'hinteros-daemon 0.7.1: 20%, compiling',
      );
      expect(
        buildName(const BuildProgress(name: 'etc', percent: 0)),
        'etc: 0%',
      );
    });
  });

  group('leaving the page', () {
    testWidgets('Hide: the indicator shows the job; A on it opens the page', (
      t,
    ) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.building,
        percent: 20,
        build: build(2),
      );
      await t.pumpAndSettle();
      expect(indicator, findsNothing, reason: 'the page shows it');
      await press(t, [kEnter]); // Hide (focused first)
      expect(find.text('Hide'), findsNothing);
      expect(indicator, findsOneWidget);
      expect(
        find.descendant(of: indicator, matching: find.text('Building 3 of 12')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: indicator,
          matching: find.text('Updating to HinterOS 0.6.1'),
        ),
        findsOneWidget,
      );
      // The box can be used: the Settings list is there and moves.
      expect(find.text('Updates'), findsWidgets);
      // The indicator follows the job.
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.building,
        percent: 30,
        build: build(3),
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(of: indicator, matching: find.text('Building 4 of 12')),
        findsOneWidget,
      );
      await openIndicatorFromSettings(t);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('4 of 12'), findsOneWidget);
      expect(indicator, findsNothing);
      // Back leaves it again.
      await press(t, [kEscape]);
      expect(indicator, findsOneWidget);
      expect(h.services.mockJobs.snapshot(job.jobId)!.running, isTrue);
    });

    testWidgets('it ends while hidden: a notice says done, the bar clears', (
      t,
    ) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      await press(t, [kEnter]); // Hide
      expect(indicator, findsOneWidget);
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      expect(
        find.text('Updating to HinterOS 0.6.1: done.'),
        findsOneWidget,
        reason: 'the notice',
      );
      expect(indicator, findsNothing);
      await t.pump(const Duration(seconds: 7));
      await t.pumpAndSettle();
      expect(find.text('Updating to HinterOS 0.6.1: done.'), findsNothing);
    });

    testWidgets('it fails while hidden: a notice, the indicator stays', (
      t,
    ) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      await press(t, [kEnter]); // Hide
      h.services.mockJobs.finish(
        job.jobId,
        ok: false,
        error: const JobError(
          message: 'The build failed.',
          stage: JobStage.building,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Updating to HinterOS 0.6.1: failed.'), findsOneWidget);
      expect(
        find.descendant(of: indicator, matching: find.text('Failed')),
        findsOneWidget,
      );
      await openIndicatorFromSettings(t);
      expect(find.text('Update failed'), findsOneWidget);
      expect(find.text('The build failed.'), findsOneWidget);
      await press(t, [kEnter]); // Close
      expect(indicator, findsNothing);
    });

    testWidgets('an update that needs a new session offers the restart', (
      t,
    ) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      h.services.mockJobs.restartNext = true;
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      await press(t, [kEnter]); // Hide
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      // The notice asks.
      expect(find.text('Updating to HinterOS 0.6.1: done'), findsOneWidget);
      expect(find.text('Restart session'), findsOneWidget);
      await press(t, [kEnter]); // Later (focused first)
      expect(find.text('Restart session'), findsNothing);
      expect(
        find.descendant(of: indicator, matching: find.text('Restart needed')),
        findsOneWidget,
      );
      // The page opened again offers it too.
      await openIndicatorFromSettings(t);
      expect(
        find.text('Restart the session to use the change.'),
        findsOneWidget,
      );
      await t.sendKeyEvent(kEnter); // Restart session
      await t.pump();
      await t.pump();
      expect(h.services.mockSystem.log, ['session:restart']);
      expect(find.text('Restarting the session…'), findsOneWidget);
    });

    testWidgets('Restart session from the notice', (t) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      h.services.mockJobs.restartNext = true;
      await toUpdateNow(t, h);
      await press(t, [kEnter]); // Hide
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
      await t.sendKeyEvent(kRight);
      await t.pumpAndSettle();
      await t.sendKeyEvent(kEnter); // Restart session
      await t.pump();
      await t.pump();
      expect(h.services.mockSystem.log, ['session:restart']);
    });
  });

  group('restart countdown', () {
    Finder restartsIn(int n) => find.text(
      'The session restarts in $n ${n == 1 ? 'second' : 'seconds'}.',
    );
    final countdown = find.byKey(const ValueKey('restart-countdown'));

    /// An update that needs a new session, its page open; [hide]: the
    /// person left the page before it ended.
    Future<Harness> updateNeedsRestart(
      WidgetTester t, {
      bool hide = false,
    }) async {
      setView(t);
      final (h, _) = harness();
      await h.pump(t);
      h.services.mockJobs.restartNext = true;
      await toUpdateNow(t, h);
      if (hide) await press(t, [kEnter]); // Hide
      return h;
    }

    Future<void> finish(WidgetTester t, Harness h) async {
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
    }

    group('the page', () {
      testWidgets('counts down and restarts at 0', (t) async {
        final h = await updateNeedsRestart(t);
        await finish(t, h);
        expect(restartsIn(30), findsOneWidget);
        await press(t, [kRight]); // focus moves to Later: it goes on
        await t.pump(const Duration(seconds: 1));
        expect(restartsIn(29), findsOneWidget);
        await t.pump(const Duration(seconds: 28));
        expect(restartsIn(1), findsOneWidget);
        expect(h.services.mockSystem.log, isEmpty);
        await t.pump(const Duration(seconds: 1));
        await t.pump();
        expect(h.services.mockSystem.log, ['session:restart']);
        expect(find.text('Restarting the session…'), findsOneWidget);
      });

      testWidgets('Later stops it', (t) async {
        final h = await updateNeedsRestart(t);
        await finish(t, h);
        await t.pump(const Duration(seconds: 5));
        await press(t, [kRight, kEnter]); // Later
        expect(find.text('Done'), findsNothing);
        await t.pump(const Duration(seconds: 40));
        expect(h.services.mockSystem.log, isEmpty);
      });

      testWidgets('Restart session restarts at once, one time', (t) async {
        final h = await updateNeedsRestart(t);
        await finish(t, h);
        await t.sendKeyEvent(kEnter); // Restart session (focused first)
        await t.pump();
        await t.pump();
        expect(h.services.mockSystem.log, ['session:restart']);
        await t.pump(const Duration(seconds: 40));
        expect(h.services.mockSystem.log, ['session:restart']);
      });

      testWidgets('it waits while an app is in front', (t) async {
        final h = await updateNeedsRestart(t);
        await h.launch(t, 'jellyfin-desktop');
        await finish(t, h);
        expect(find.text('Done'), findsOneWidget);
        expect(countdown, findsNothing);
        await t.pump(const Duration(minutes: 2));
        expect(h.services.mockSystem.log, isEmpty);
        // Home: it starts.
        h.mock.pressHome();
        await t.pumpAndSettle();
        expect(restartsIn(30), findsOneWidget);
        await t.pump(const Duration(seconds: 10));
        expect(restartsIn(20), findsOneWidget);
        // An app in front again: it stops, and starts again from 30.
        await h.launch(t, 'jellyfin-desktop');
        expect(countdown, findsNothing);
        await t.pump(const Duration(minutes: 1));
        expect(h.services.mockSystem.log, isEmpty);
        h.mock.pressHome();
        await t.pumpAndSettle();
        expect(restartsIn(30), findsOneWidget);
        await t.pump(const Duration(seconds: 30));
        await t.pump();
        expect(h.services.mockSystem.log, ['session:restart']);
      });
    });

    group('the notice of a job that was left', () {
      testWidgets('counts down and restarts at 0', (t) async {
        final h = await updateNeedsRestart(t, hide: true);
        await finish(t, h);
        expect(find.text('Updating to HinterOS 0.6.1: done'), findsOneWidget);
        expect(restartsIn(30), findsOneWidget);
        await press(t, [kRight]); // focus moves to Restart session
        await t.pump(const Duration(seconds: 1));
        expect(restartsIn(29), findsOneWidget);
        await t.pump(const Duration(seconds: 28));
        expect(restartsIn(1), findsOneWidget);
        expect(h.services.mockSystem.log, isEmpty);
        await t.pump(const Duration(seconds: 1));
        await t.pump();
        await t.pump();
        expect(h.services.mockSystem.log, ['session:restart']);
        expect(find.text('Restarting the session…'), findsOneWidget);
      });

      testWidgets('Later stops it', (t) async {
        final h = await updateNeedsRestart(t, hide: true);
        await finish(t, h);
        await t.pump(const Duration(seconds: 5));
        await press(t, [kEnter]); // Later (focused first)
        expect(countdown, findsNothing);
        expect(
          find.descendant(of: indicator, matching: find.text('Restart needed')),
          findsOneWidget,
        );
        await t.pump(const Duration(seconds: 40));
        expect(h.services.mockSystem.log, isEmpty);
      });

      testWidgets('Restart session restarts at once, one time', (t) async {
        final h = await updateNeedsRestart(t, hide: true);
        await finish(t, h);
        await press(t, [kRight]);
        await t.sendKeyEvent(kEnter); // Restart session
        await t.pump();
        await t.pump();
        expect(h.services.mockSystem.log, ['session:restart']);
        await t.pump(const Duration(seconds: 40));
        expect(h.services.mockSystem.log, ['session:restart']);
      });

      testWidgets('it waits while an app is in front', (t) async {
        final h = await updateNeedsRestart(t, hide: true);
        await h.launch(t, 'jellyfin-desktop');
        await finish(t, h);
        expect(countdown, findsNothing);
        await t.pump(const Duration(minutes: 2));
        expect(h.services.mockSystem.log, isEmpty);
        // Home: the notice is there and counts.
        h.mock.pressHome();
        await t.pumpAndSettle();
        expect(find.text('Updating to HinterOS 0.6.1: done'), findsOneWidget);
        expect(restartsIn(30), findsOneWidget);
        await t.pump(const Duration(seconds: 30));
        await t.pump();
        await t.pump();
        expect(h.services.mockSystem.log, ['session:restart']);
      });
    });
  });

  group('launcher restart', () {
    testWidgets('a running job shows in the top bar and its page opens', (
      t,
    ) async {
      setView(t);
      final (h, _) = harness();
      // The job started before this launcher (it restarted meanwhile).
      final job = h.services.mockJobs.start(
        JobKind.install,
        subject: const JobSubject(
          apps: [(id: 'moonlight', name: 'Moonlight')],
          profileName: 'Sam',
        ),
      );
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.downloading,
        percent: 40,
        detail: '120 MB of 300 MB',
      );
      await h.pump(t);
      expect(indicator, findsOneWidget);
      expect(
        find.descendant(of: indicator, matching: find.text('40%')),
        findsOneWidget,
      );
      // Up to the tab row; left wraps to the profile chip, then the job.
      await press(t, [kUp, kLeft, kLeft, kEnter]);
      expect(find.text('Installing Moonlight'), findsOneWidget);
      expect(find.text('For Sam.'), findsOneWidget);
      expect(find.text('120 MB of 300 MB'), findsOneWidget);
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      // Its page is open: no notice on top.
      expect(find.text('Installing Moonlight: done.'), findsNothing);
      await press(t, [kEnter]); // Close
      expect(indicator, findsNothing);
    });

    testWidgets('the indicator goes while the chip has the focus: the focus '
        'stays on the chip', (t) async {
      setView(t);
      final (h, _) = harness();
      final job = h.services.mockJobs.start(JobKind.rebuild);
      await h.pump(t);
      expect(indicator, findsOneWidget);
      // Up to the tab row; left wraps to the profile chip (after the job).
      await press(t, [kUp, kLeft]);
      expect(focusLabel(), 'tabs/tabs:7');
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      expect(indicator, findsNothing);
      expect(focusLabel(), 'tabs/tabs:6');
      await press(t, [kEnter]);
      expect(find.text('Who is watching?'), findsOneWidget);
    });
  });
}

void mockScript() {
  test('--mock: a long build with counts, names and phases', () async {
    final jobs = MockJobs(autoRun: true, stepDelay: Duration.zero);
    addTearDown(jobs.dispose);
    final h = jobs.start(JobKind.rebuild);
    final seen = await jobs.watch(h.jobId).toList();
    final builds = [
      for (final s in seen)
        if (s.build != null) s.build!,
    ];
    expect(builds.map((b) => b.name).toSet(), hasLength(12));
    expect(builds.first.total, 9);
    expect(builds.last.total, 12);
    expect(builds.last.current, 12);
    expect(builds.map((b) => b.phase).toSet(), {
      'unpack',
      'configure',
      'build',
      'install',
    });
    expect(seen.where((s) => s.percent != null), isNotEmpty);
    expect(seen.last.ok, isTrue);
  });
}
