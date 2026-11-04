import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness harness({UpdateStatus? status}) => Harness(
  services: MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    status: status,
  ),
);

/// The enabled flag of the button labelled [label].
bool buttonEnabled(WidgetTester t, String label) =>
    t.widget<HButton>(find.widgetWithText(HButton, label)).enabled;

void main() {
  group('Settings > System sections', () {
    testWidgets(
      'Network: wrong Wi-Fi password is refused, the right one connects',
      (t) async {
        setView(t);
        final h = harness();
        await h.pump(t);
        await enterSettingsEntry(t, 'net');
        expect(focusLabel(), 'settings-detail/wifi:0');
        expect(find.text('Neighbour Net'), findsOneWidget);
        // wifi, scan, then the networks by signal: Hinter-Home, 5G, Neighbour.
        await press(t, [kDown, kDown, kDown, kDown, kEnter]);
        expect(find.text('Password for Neighbour Net'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'nope');
        await press(t, [kEnter]);
        expect(
          find.textContaining('Wrong password. Try again.'),
          findsOneWidget,
        );
        await t.enterText(find.byType(TextField), 'wifi-pass');
        await press(t, [kEnter]);
        expect(find.text('Password for Neighbour Net'), findsNothing);
        expect(h.services.mockNetwork.log, [
          'connect:Neighbour Net',
          'connect:Neighbour Net',
        ]);
        expect(
          find.textContaining('Connected to Neighbour Net'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Network: the password field is masked', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'net');
      await press(t, [kDown, kDown, kDown, kDown, kEnter]);
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('Bluetooth: scan, pair a controller, forget it', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'bt');
      await press(t, [kEnter]); // scan: nearby devices show up
      expect(find.text('Pad Two'), findsOneWidget);
      // scan, Pad One, Buds, Pad Two
      await press(t, [kDown, kDown, kDown, kEnter]);
      expect(find.text('Pair with Pad Two?'), findsOneWidget);
      await press(t, [kRight, kEnter]);
      expect(h.services.mockBluetooth.log, ['pair:BB:00:33']);
      await press(t, [kEnter]); // paired device: choices
      await press(t, [kDown, kEnter]); // forget
      expect(h.services.mockBluetooth.log.last, 'forget:BB:00:33');
    });

    bool modeListOpen() =>
        find.byKey(const ValueKey('display-mode-list')).evaluate().isNotEmpty;

    testWidgets('Display: a drop-down; its list opens at the current mode', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'display');
      // The closed field shows the current mode only.
      expect(find.text('1920 x 1080 at 60 Hz'), findsOneWidget);
      expect(find.text('3840 x 2160 at 60 Hz'), findsNothing);
      await press(t, [kDown]);
      expect(focusLabel(), 'settings-detail/mode:0');
      await press(t, [kEnter]);
      expect(modeListOpen(), isTrue);
      expect(find.text('3840 x 2160 at 60 Hz'), findsOneWidget);
      // 3840x2160@60, @30, 2560x1440, 1920x1080@120, @60 (current), 1280x720.
      expect(focusLabel(), endsWith('/c4:0'));
      // B closes it and changes nothing.
      await press(t, [kUp, kEscape]);
      expect(modeListOpen(), isFalse);
      expect(focusLabel(), 'settings-detail/mode:0');
      expect(find.text('1920 x 1080 at 60 Hz'), findsOneWidget);
      expect(h.services.mockDisplayAudio.log, isEmpty);
      // The current mode again: no change, no dialog.
      await press(t, [kEnter, kEnter]);
      expect(modeListOpen(), isFalse);
      expect(find.textContaining('Keep '), findsNothing);
      expect(h.services.mockDisplayAudio.log, isEmpty);
    });

    testWidgets('Display: a mode applies, and reverts when not kept in time', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'display');
      // guide, the drop-down; up from the current mode to 3840x2160@60
      await press(t, [kDown, kEnter, kUp, kUp, kUp, kUp, kEnter]);
      expect(modeListOpen(), isFalse);
      expect(find.textContaining('Keep 3840 x 2160'), findsOneWidget);
      await t.pump(const Duration(seconds: 16));
      await t.pumpAndSettle();
      expect(find.textContaining('Keep 3840'), findsNothing);
      final log = h.services.mockDisplayAudio.log;
      expect(log.first, startsWith('mode:3840x2160@60'));
      expect(log.last, 'revert', reason: 'went back');
      expect(find.text('1920 x 1080 at 60 Hz'), findsOneWidget);
    });

    testWidgets('Display: keeping a mode', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'display');
      await press(t, [kDown, kEnter, kDown, kEnter]); // 1280x720
      expect(find.textContaining('Keep 1280 x 720'), findsOneWidget);
      await press(t, [kRight, kEnter]);
      expect(h.services.mockDisplayAudio.log.last, 'keep');
      expect(h.services.mockDisplayAudio.log, hasLength(2));
      expect(find.text('1280 x 720 at 60 Hz'), findsOneWidget);
    });

    testWidgets('Audio: left and right change the volume on its row', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'audio');
      expect(find.text('55%'), findsOneWidget);
      await press(t, [kRight, kRight, kLeft]);
      expect(find.text('60%'), findsOneWidget);
      expect(h.services.mockDisplayAudio.log.last, 'volume:60');
      await press(t, [kDown, kDown, kEnter]); // second output
      expect(h.services.mockDisplayAudio.log.last, 'output:bt-buds');
    });

    testWidgets('Power: restart and shut down ask first, sleep does not', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'power');
      await press(t, [kEnter]);
      expect(h.services.mockSystem.log, ['power:sleep']);
      await press(t, [kDown, kEnter]);
      expect(find.text('Restart?'), findsOneWidget);
      await press(t, [kEnter]); // Cancel is focused first
      expect(h.services.mockSystem.log, ['power:sleep']);
      await press(t, [kEnter, kRight]);
      // The session ends with the box: the ending page (it never settles).
      await t.sendKeyEvent(kEnter);
      await t.pump();
      await t.pump();
      expect(h.services.mockSystem.log.last, 'power:restart');
      expect(find.text('Restarting…'), findsOneWidget);
      // Accepted, but the service still answers long after: it did not
      // work. The page goes, and the launcher takes input again.
      await t.pump(const Duration(minutes: 2));
      await t.pumpAndSettle();
      expect(find.text('Restarting…'), findsNothing);
      expect(find.text('Nothing happened. Try again.'), findsOneWidget);
      await press(t, [kEnter]);
      expect(find.text('Nothing happened. Try again.'), findsNothing);
    });

    testWidgets('About shows the version and identity', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'about');
      expect(find.text('0.6.0'), findsOneWidget);
      expect(find.text('hinteros-livingroom.local'), findsOneWidget);
    });
  });

  group('Remote access and the admin password prompt', () {
    TextEditingController field(WidgetTester t) =>
        t.widget<TextField>(find.byType(TextField)).controller!;

    testWidgets('turning SSH on asks for the admin password (masked, retried)', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      expect(find.text('Needs the admin password.'), findsWidgets);
      expect(find.text('Admin password'), findsNothing);
      await press(t, [kEnter]); // SSH: ssh.set waits for the prompt
      expect(find.text('Admin password'), findsOneWidget);
      expect(
        find.text('Enter the password for admin to turn on SSH.'),
        findsOneWidget,
      );
      expect(t.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
      // Nothing typed: refused before it is sent.
      await press(t, [kEnter]);
      expect(find.text('Type the password first.'), findsOneWidget);
      expect(h.services.mockAuth.attempts, 0);
      // A wrong password: the tries left, the dialog stays, the field is empty.
      await t.enterText(find.byType(TextField), 'wrong');
      await press(t, [kEnter]);
      expect(find.text('Admin password'), findsOneWidget);
      expect(find.text('Wrong password. 2 tries left.'), findsOneWidget);
      expect(field(t).text, isEmpty, reason: 'the password is not kept');
      expect(h.services.mockSystem.log, isNot(contains('ssh:on')));
      expect(h.services.mockJobs.started, isEmpty);
      await t.enterText(find.byType(TextField), 'correct horse');
      await press(t, [kEnter]);
      expect(h.services.mockAuth.attempts, 2);
      expect(find.text('Admin password'), findsNothing);
      expect(h.services.mockJobs.started, hasLength(1));
      // The apply job's progress page; finish it.
      expect(find.text('Turning on remote access'), findsOneWidget);
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Close
      expect(
        find.textContaining('Log in as the admin account at'),
        findsOneWidget,
      );
    });

    testWidgets('three wrong passwords: the prompt closes, nothing changes', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      for (final left in ['2 tries', '1 try']) {
        await t.enterText(find.byType(TextField), 'wrong');
        await press(t, [kEnter]);
        expect(find.text('Wrong password. $left left.'), findsOneWidget);
      }
      await t.enterText(find.byType(TextField), 'wrong');
      await press(t, [kEnter]);
      expect(find.text('Admin password'), findsNothing);
      expect(
        find.textContaining('too many times. Nothing was changed.'),
        findsOneWidget,
      );
      expect(h.services.mockAuth.attempts, 3);
      expect(h.services.mockJobs.started, isEmpty);
      await press(t, [kEnter]);
      expect(
        find.textContaining('too many times. Nothing was changed.'),
        findsNothing,
      );
    });

    testWidgets('Back cancels the request: auth.cancel, nothing changes', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter, kEscape]);
      expect(find.text('Admin password'), findsNothing);
      expect(h.services.mockAuth.cancels, 1);
      expect(h.services.mockAuth.pending, isEmpty);
      expect(h.services.mockAuth.attempts, 0);
      expect(find.textContaining('nothing was changed'), findsOneWidget);
      expect(h.services.mockSystem.log, isEmpty);
    });

    testWidgets('the Cancel button does the same', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      await press(t, [kDown, kDown, kEnter]); // the Cancel button
      expect(find.text('Admin password'), findsNothing);
      expect(h.services.mockAuth.cancels, 1);
    });

    testWidgets('the prompt goes away when polkit ends the request', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      expect(find.text('Admin password'), findsOneWidget);
      // Someone else cancels it (polkit's timeout): no auth.cancel from here.
      await h.services.mockAuth.cancel(h.services.mockAuth.pending.single);
      await t.pumpAndSettle();
      expect(find.text('Admin password'), findsNothing);
      expect(h.services.mockAuth.cancels, 1, reason: 'only the one above');
    });

    testWidgets('turning SSH off needs no password', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      await t.enterText(find.byType(TextField), 'correct horse');
      await press(t, [kEnter]);
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Close
      await press(t, [kEnter]); // SSH off again
      expect(find.text('Admin password'), findsNothing);
      expect(h.services.mockAuth.attempts, 1);
      expect(h.services.mockSystem.log.last, 'ssh:off');
    });
  });

  group('Updates and the progress screen', () {
    Future<void> toUpdateNow(WidgetTester t, Harness h) async {
      h.services.mockUpdates.nextAvailable = mockOrdinaryUpdate();
      await enterSettingsEntry(t, 'updates');
      await press(t, [kEnter]); // Check for updates
      expect(
        find.textContaining('Update available: HinterOS 0.6.1'),
        findsOneWidget,
      );
      await press(t, [kDown, kEnter, kRight, kEnter]); // Update now, confirm
      await enterPin(t, '2468'); // the admin PIN
    }

    testWidgets('check, update, progress with percentage, then failure', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      expect(find.textContaining('Updating to HinterOS'), findsOneWidget);
      expect(
        find.textContaining('The session restarts when this finishes'),
        findsOneWidget,
      );
      h.services.mockJobs.progress(
        job.jobId,
        JobStage.downloading,
        percent: 40,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('40%'), findsWidgets);
      expect(buttonEnabled(t, 'Cancel'), isTrue);
      h.services.mockJobs.finish(
        job.jobId,
        ok: false,
        error: const JobError(
          message: 'Not enough disk space.',
          stage: JobStage.downloading,
          logHint: 'hinteros-job@x.service',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Update failed'), findsOneWidget);
      expect(find.textContaining('Not enough disk space'), findsOneWidget);
      expect(find.textContaining('Nothing changed'), findsOneWidget);
      await press(t, [kEnter]); // Close
      expect(find.text('Update failed'), findsNothing);
      expect(h.services.mockUpdates.status.currentVersion, '0.6.0');
    });

    testWidgets('cancel works before activation, not after', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      final job = h.services.mockJobs.started.single;
      h.services.mockJobs.progress(job.jobId, JobStage.activating);
      await t.pumpAndSettle();
      expect(find.text("Can't cancel now"), findsOneWidget);
      expect(buttonEnabled(t, "Can't cancel now"), isFalse);
      await press(t, [kRight, kEnter]);
      expect(h.services.mockJobs.snapshot(job.jobId)!.finished, isFalse);
      // Back leaves the page: the job runs on, the top bar shows it.
      await press(t, [kEscape]);
      expect(find.byKey(const ValueKey('job-indicator')), findsOneWidget);
      expect(h.services.mockJobs.snapshot(job.jobId)!.finished, isFalse);
    });

    testWidgets('a cancelled job says nothing changed', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await toUpdateNow(t, h);
      h.services.mockJobs.progress(
        h.services.mockJobs.started.single.jobId,
        JobStage.downloading,
        percent: 10,
      );
      await t.pumpAndSettle();
      await press(t, [kRight, kEnter]); // Cancel (after Hide)
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('Nothing changed'), findsOneWidget);
    });

    testWidgets('a finished update that needs a session restart offers it', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      h.services.mockJobs.restartNext = true;
      await toUpdateNow(t, h);
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
      expect(find.text('Restart session'), findsOneWidget);
      await t.sendKeyEvent(kEnter);
      await t.pump();
      await t.pump();
      expect(h.services.mockSystem.log, ['session:restart']);
      expect(find.text('Restarting the session…'), findsOneWidget);
      expect(h.services.mockUpdates.status.currentVersion, '0.6.1');
    });

    testWidgets('an unreachable update server is said plainly', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      h.services.mockUpdates.failCheckWith = const SystemException(
        SystemErrorKind.updateUnreachable,
        'x',
      );
      await enterSettingsEntry(t, 'updates');
      await press(t, [kEnter]);
      expect(
        find.textContaining("Can't reach the update server"),
        findsOneWidget,
      );
    });

    testWidgets('a check that ends elsewhere shows on the open page', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'updates');
      expect(find.text('HinterOS 0.6.0'), findsOneWidget);
      expect(find.textContaining('Update available'), findsNothing);
      h.services.mockUpdates.setStatus(mockBehind(mockOrdinaryUpdate()));
      await t.pumpAndSettle();

      expect(
        find.textContaining('Update available: HinterOS 0.6.1'),
        findsOneWidget,
      );
    });

    testWidgets('rollback asks first and runs the job', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'updates');
      await press(t, [kDown, kDown]); // check, channel, rollback
      await press(t, [kEnter]);
      expect(find.text('Roll back to the previous version?'), findsOneWidget);
      await press(t, [kRight, kEnter]);
      expect(find.text("Type the admin profile's PIN."), findsOneWidget);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.rollback);
    });

    testWidgets('a channel switch shows the verified version first', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await enterSettingsEntry(t, 'updates');
      await press(t, [kDown, kEnter]); // channel
      await press(t, [kDown, kEnter]); // Stable
      // Checked first: the confirmation names the verified version.
      expect(find.text('Switch to Stable?'), findsOneWidget);
      expect(find.text('HinterOS 0.6.0 stable, 2026-10-01.'), findsOneWidget);
      expect(
        find.text('This version is older than the version on this box.'),
        findsOneWidget,
      );
      expect(h.services.mockJobs.started, isEmpty);
      await press(t, [kRight, kEnter]);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.channel);
    });
  });
}
