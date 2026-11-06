// The Settings screens on the real repositories (Daemon*) over the mock
// daemon's system relay: what the user sees for each answer of the system
// service.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness harness() {
  final mock = api.MockDaemon(
    apps: appsWithIcons(),
    games: gamesWithArt(),
    now: fixedNow,
  );
  return Harness(
    mock: mock,
    realServices: daemonSystemServices(mock, now: fixedNow),
  );
}

/// The startup update check is a job on the service; the test ends it so
/// that it does not hold the "one job at a time" slot.
Future<void> endStartupCheck(WidgetTester t, Harness h) async {
  await t.pump();
  final id = h.mock.system.runningJobId;
  if (id != null) h.mock.system.finishJob(id);
  await t.pumpAndSettle();
  // A post-frame callback (the security notice) needs one more frame.
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

void main() {
  group('Remote access and the admin password (over the daemon)', () {
    testWidgets('Backspace deletes in the password field; it is not Back', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      expect(find.text('Admin password'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'abc');
      await press(t, [LogicalKeyboardKey.backspace]);
      expect(find.text('Admin password'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'ab',
      );
      // Escape is Back: the prompt is cancelled.
      await press(t, [kEscape]);
      expect(find.text('Admin password'), findsNothing);
    });

    testWidgets('the prompt appears, a wrong password then the right one', (
      t,
    ) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'ssh');
      expect(find.text('Needs the admin password.'), findsWidgets);
      await press(t, [kEnter]);
      // ssh.set waits at the daemon; authentication_requested shows the prompt.
      expect(find.text('Admin password'), findsOneWidget);
      expect(
        find.text('Enter the password for admin to turn on SSH.'),
        findsOneWidget,
      );
      expect(h.mock.system.log.last, 'ssh.set:on');
      expect(h.mock.system.runningJobId, isNull);
      await t.enterText(find.byType(TextField), 'wrong');
      await press(t, [kEnter]);
      expect(find.text('Wrong password. 2 tries left.'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'correct horse');
      await press(t, [kEnter]);
      // authorized: the dialog is gone and the job's progress shows.
      expect(find.text('Admin password'), findsNothing);
      expect(find.text('Turning on remote access'), findsOneWidget);
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Close
      expect(
        find.textContaining('Log in as the admin account at'),
        findsOneWidget,
      );
      expect(h.mock.auth.pendingCookies, isEmpty);
    });

    testWidgets('Back at the prompt: auth.cancel, SSH stays off', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      expect(h.mock.auth.pendingCookies, hasLength(1));
      await press(t, [kEscape]);
      expect(find.text('Admin password'), findsNothing);
      expect(h.mock.auth.pendingCookies, isEmpty);
      expect(find.textContaining('nothing was changed'), findsOneWidget);
      expect(h.mock.system.sshEnabled, isFalse);
      expect(h.mock.system.runningJobId, isNull);
    });

    testWidgets('no authentication agent: said plainly, no prompt', (t) async {
      setView(t);
      final h = harness();
      h.mock.auth.agentRegistered = false;
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      expect(find.text('Admin password'), findsNothing);
      expect(find.textContaining('nothing was changed'), findsOneWidget);
      await press(t, [kEnter]);
      expect(h.mock.system.sshEnabled, isFalse);
    });

    testWidgets('an authorised ssh.set shows the job and then SSH on', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.mock.system.adminAuthorized = true;
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'ssh');
      await press(t, [kEnter]);
      expect(find.text('Admin password'), findsNothing);
      expect(find.text('Turning on remote access'), findsOneWidget);
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Close
      expect(
        find.text(
          'Log in as the admin account at 192.168.1.20, with its password.',
        ),
        findsOneWidget,
      );
    });
  });

  group('settings unavailable', () {
    testWidgets('system_unavailable (down) says so, Try again recovers', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.mock.system.unavailable = api.SystemUnavailableDataReason.down;
      await h.pump(t);
      await enterSettingsEntry(t, 'about');
      expect(
        inSection('about', find.textContaining('Settings are unavailable')),
        findsOneWidget,
      );
      expect(
        inSection('about', find.textContaining('not running')),
        findsOneWidget,
      );
      h.mock.system.unavailable = null;
      await press(t, [kEnter]); // Try again
      expect(find.text('0.1.0 stable'), findsOneWidget);
      expect(
        inSection('about', find.textContaining('Settings are unavailable')),
        findsNothing,
      );
    });

    testWidgets('version_mismatch mentions the session restart', (t) async {
      setView(t);
      final h = harness();
      h.mock.system.unavailable =
          api.SystemUnavailableDataReason.versionMismatch;
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      expect(
        inSection('ssh', find.textContaining('Restart the session')),
        findsOneWidget,
      );
    });
  });

  group('About', () {
    testWidgets('DEV badge, version and SSH host key fingerprints', (t) async {
      setView(t);
      final h = harness();
      h.mock.system.dev = true;
      await h.pump(t);
      await enterSettingsEntry(t, 'about');
      expect(find.byType(DevBadge), findsOneWidget);
      expect(find.text('DEV'), findsOneWidget);
      expect(find.text('0.1.0 stable'), findsOneWidget);
      expect(find.text('192.168.1.20'), findsOneWidget);
      expect(find.textContaining('.local'), findsNothing);
      expect(
        find.text('SHA256:2CixtE95MNbZHanQGv6hP2D3qfguu9QZfjca2OaupKI'),
        findsOneWidget,
      );
    });

    testWidgets('no DEV badge on a normal build; no channel is "None"', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.mock.system.channel = null;
      h.mock.system.rev = null;
      await h.pump(t);
      await enterSettingsEntry(t, 'about');
      expect(find.byType(DevBadge), findsNothing);
      expect(find.text('None'), findsWidgets);
    });
  });

  group('Updates', () {
    testWidgets(
      'a channel switch: the verified version is confirmed, then switched to',
      (t) async {
        setView(t);
        final h = harness();
        h.mock.system.channel = api.Channel.beta;
        await h.pump(t);
        await endStartupCheck(t, h);
        await enterSettingsEntry(t, 'updates');
        await press(t, [kDown, kEnter]); // channel
        await press(t, [kDown, kEnter]); // Stable
        // The box checks stable first (a job, no PIN).
        expect(h.mock.system.log.last, 'channel.check');
        h.mock.system.finishJob(h.mock.system.runningJobId!);
        await t.pumpAndSettle();
        expect(find.text('Switch to Stable?'), findsOneWidget);
        expect(find.text('HinterOS 0.7.0 stable, 2026-10-06.'), findsOneWidget);
        expect(
          find.text('This version is older than the version on this box.'),
          findsOneWidget,
        );
        expect(h.mock.system.runningJobId, isNull);
        await press(t, [kRight, kEnter]); // Switch
        expect(find.text("Type the admin profile's PIN."), findsOneWidget);
        await enterPin(t, '2468');
        expect(h.mock.system.runningJobId, isNotNull);
        expect(h.mock.system.log.last, 'channel.set');
        expect(find.textContaining('Switching from'), findsOneWidget);
      },
    );

    testWidgets('a channel check that finds an older version: refused', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.mock.system.channel = api.Channel.beta;
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'updates');
      await press(t, [kDown, kEnter]); // channel
      await press(t, [kDown, kEnter]); // Stable
      h.mock.system.finishJob(
        h.mock.system.runningJobId!,
        ok: false,
        error: const api.ErrorObject(
          code: api.ApiErrorCode.updateVerificationFailed,
          message: 'the channel tip is older than a verified tip',
          data: {'reason': 'older_than_seen'},
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Switch to Stable?'), findsNothing);
      expect(
        find.text(
          'This version is older than one this box already saw. '
          'Try again later.',
        ),
        findsOneWidget,
      );
      expect(h.mock.system.log.last, 'channel.check');
    });

    testWidgets('check, security update, apply, progress and session restart', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.mock.system.nextUpdate = api.AvailableUpdate(
        rev: '9a8b7c6d5e4f30211a2b3c4d5e6f708192a3b4c5',
        date: 1791300000,
        summary: 'Fixes a flaw in the web engine.',
        signer: 'release@hinteros',
        security: api.Severity.high,
        commits: 3,
        newApps: null,
        removedApps: null,
      );
      await h.pump(t);
      // The startup check finds the update; the reminder shows the notice.
      await endStartupCheck(t, h);
      expect(find.text('Security update'), findsOneWidget);
      expect(find.text('Severity: High'), findsOneWidget);
      // Update now has the focus and works at once.
      h.mock.system.restartNext = true;
      await press(t, [kEnter]);
      await enterPin(t, '2468'); // the admin PIN
      final job = h.mock.system.runningJobId!;
      expect(h.mock.system.log.last, 'update.apply');
      h.mock.system.progressJob(
        job,
        api.Stage.downloading,
        percent: 40,
        bytesTotal: 500 << 20,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('200 MB of 500 MB'), findsOneWidget);
      h.mock.system.finishJob(job);
      await t.pumpAndSettle();
      expect(find.text('Restart session'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });
  });
}
