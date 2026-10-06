// The Settings screens on the real repositories (Daemon*) over the mock
// daemon's system relay: what the user sees for each answer of the system
// service.
import 'package:flutter/material.dart';
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
  return Harness(mock: mock, realServices: daemonSystemServices(mock));
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
  group('Remote access without a polkit agent', () {
    testWidgets('SSH on explains that an admin has to do it', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'ssh');
      expect(find.textContaining('needs an admin'), findsOneWidget);
      await press(t, [kEnter]);
      expect(find.text('An admin has to turn on SSH'), findsOneWidget);
      expect(find.textContaining('"Enable SSH"'), findsOneWidget);
      expect(find.textContaining('admin account'), findsWidgets);
      // No password field: the launcher cannot pass one on.
      expect(find.byType(TextField), findsNothing);
      expect(h.mock.system.log.last, 'ssh.set:on');
      await press(t, [kEnter]);
      expect(find.text('An admin has to turn on SSH'), findsNothing);
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
      expect(find.text('Changing remote access'), findsOneWidget);
      h.mock.system.finishJob(h.mock.system.runningJobId!);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Close
      expect(
        find.textContaining('On. Log in as the admin account'),
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
      expect(find.textContaining('Settings are unavailable'), findsOneWidget);
      expect(find.textContaining('not running'), findsOneWidget);
      h.mock.system.unavailable = null;
      await press(t, [kEnter]); // Try again
      expect(find.text('0.1.0'), findsOneWidget);
      expect(find.textContaining('Settings are unavailable'), findsNothing);
    });

    testWidgets('version_mismatch mentions the session restart', (t) async {
      setView(t);
      final h = harness();
      h.mock.system.unavailable =
          api.SystemUnavailableDataReason.versionMismatch;
      await h.pump(t);
      await enterSettingsEntry(t, 'ssh');
      expect(find.textContaining('until the session restarts'), findsOneWidget);
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
      expect(find.text('0.1.0'), findsOneWidget);
      expect(find.text('hinteros.local'), findsOneWidget);
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
      'a downgrade is confirmed, then retried with the acknowledgement',
      (t) async {
        setView(t);
        final h = harness();
        h.mock.system.channel = api.Channel.beta;
        await h.pump(t);
        await endStartupCheck(t, h);
        await enterSettingsEntry(t, 'updates');
        await press(t, [kDown, kEnter]); // channel
        await press(t, [kDown, kEnter]); // Stable
        expect(find.text('Switch to Stable?'), findsOneWidget);
        expect(h.mock.system.runningJobId, isNull);
        await press(t, [kRight, kEnter]); // Switch anyway
        expect(h.mock.system.runningJobId, isNotNull);
        expect(h.mock.system.log.sublist(h.mock.system.log.length - 2), [
          'channel.set',
          'channel.set',
        ]);
        expect(find.text('Switching channel'), findsOneWidget);
      },
    );

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
      );
      await h.pump(t);
      // The startup check finds the update; the reminder shows the notice.
      await endStartupCheck(t, h);
      expect(find.text('Security update'), findsOneWidget);
      expect(find.text('Severity: High'), findsOneWidget);
      // Wait out the 5 s lock, then Update now (the second button).
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      h.mock.system.restartNext = true;
      await press(t, [kRight, kEnter]);
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
