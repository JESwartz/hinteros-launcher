// The admin PIN of the box-wide actions (session API 0.13): an update (from
// Settings, the banner and the security notice, every profile), rollback,
// channel and base ask for it on the admin-PIN pad before they run; a wrong
// PIN asks again, Back on the empty pad does nothing. Also the rollback's
// "turns on the parts your apps need" line.
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/ui/profiles/profile_ui.dart'
    show rebootPinText;
import 'package:hinteros_launcher/src/ui/settings_screen.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

const _askPin = "Type the admin profile's PIN.";

Harness harness({
  UpdateChannel channel = UpdateChannel.beta,
  String current = 'p1',
  UpdateStatus? status,
}) {
  final s = MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    currentProfile: current,
    status: status,
  );
  s.mockUpdates.channel = channel;
  return Harness(services: s);
}

/// Settings > Updates, then down [downs] rows and A.
Future<void> openRow(WidgetTester t, int downs) async {
  await enterSettingsEntry(t, 'updates');
  await press(t, [for (var i = 0; i < downs; i++) kDown, kEnter]);
}

void main() {
  group('update', () {
    /// Settings > Updates with an update: Update now, confirmed: the pad.
    Future<Harness> settingsPad(WidgetTester t) async {
      setView(t);
      final h = harness(status: mockBehind(mockOrdinaryUpdate()));
      await h.pump(t);
      // Up twice: the update banner, then the tabs.
      await press(t, [kUp, kUp, kRight, kRight, kRight, kRight, kDown]);
      await press(t, [
        ...List.filled(settingsGroupIndexOf('updates'), kDown),
        kRight, // into the pane
        kDown, kEnter, // check, apply
      ]);
      expect(find.text('Update to HinterOS 0.6.1?'), findsOneWidget);
      await press(t, [kRight, kEnter]);
      expect(find.text('Update HinterOS'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      return h;
    }

    /// The security notice after its lock: Update now: the pad.
    Future<Harness> noticePad(WidgetTester t, {String current = 'p1'}) async {
      setView(t);
      final h = harness(
        current: current,
        status: mockBehind(mockSecurityUpdate()),
      );
      await h.pump(t);
      expect(find.text('Security update'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await press(t, [kRight, kEnter]); // Update now
      expect(find.text('Update HinterOS'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      return h;
    }

    testWidgets('Settings: the right PIN starts it', (t) async {
      final h = await settingsPad(t);
      await enterPin(t, '2468');
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
      expect(find.textContaining('Updating to HinterOS'), findsOneWidget);
    });

    testWidgets('Settings: a wrong PIN asks again', (t) async {
      final h = await settingsPad(t);
      await enterPin(t, '1357');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
    });

    testWidgets('Settings: ten wrong PINs, then a restart is needed', (
      t,
    ) async {
      final h = await settingsPad(t);
      for (var i = 0; i < 9; i++) {
        await enterPin(t, '1357');
        expect(find.text('Wrong PIN.'), findsOneWidget);
      }
      await enterPin(t, '1357');
      expect(find.text(rebootPinText), findsOneWidget);
      // The pad takes no more digits: the right PIN starts nothing.
      await enterPin(t, '2468');
      expect(find.text(rebootPinText), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('Settings: Back on the pad does nothing', (t) async {
      final h = await settingsPad(t);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(find.textContaining('Updating to HinterOS'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('the banner leads to Update now, which asks the PIN', (
      t,
    ) async {
      setView(t);
      final h = harness(status: mockBehind(mockOrdinaryUpdate()));
      await h.pump(t);
      await press(t, [kUp]);
      expect(focusLabel(), 'update-banner/update-banner:0');
      await press(t, [kEnter]); // See update: Settings > Updates
      expect(focusLabel(), 'settings-list/updates:0');
      await press(t, [kRight, kDown, kEnter, kRight, kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '0000');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
    });

    testWidgets('security notice: the right PIN starts it', (t) async {
      final h = await noticePad(t);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
      expect(find.textContaining('Updating to HinterOS'), findsOneWidget);
    });

    testWidgets('security notice: a wrong PIN asks again', (t) async {
      final h = await noticePad(t);
      await enterPin(t, '1111');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
    });

    testWidgets('security notice: Back on the pad does nothing', (t) async {
      final h = await noticePad(t);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(find.textContaining('Updating to HinterOS'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('the guest is asked too', (t) async {
      final h = await noticePad(t, current: 'guest');
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
    });

    test('the mock asks for the admin PIN like the service', () async {
      final s = MockSystemServices(
        now: fixedNow,
        status: mockBehind(mockOrdinaryUpdate()),
      );
      addTearDown(s.dispose);
      final rev = s.updates.status.available!.rev;
      await expectLater(
        s.updates.apply(rev),
        throwsA(
          isA<SystemException>().having(
            (e) => e.kind,
            'kind',
            SystemErrorKind.pinRequired,
          ),
        ),
      );
      final h = await s.updates.apply(rev, adminPin: '2468');
      expect(h.kind, JobKind.update);
    });
  });

  group('rollback', () {
    /// Roll back to the previous version, confirmed: the pad is up.
    Future<Harness> toPad(WidgetTester t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openRow(t, 2); // check, channel, rollback
      expect(find.text('Roll back to the previous version?'), findsOneWidget);
      await press(t, [kRight, kEnter]);
      expect(find.text('Roll back'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      return h;
    }

    testWidgets('the right PIN starts it', (t) async {
      final h = await toPad(t);
      await enterPin(t, '2468');
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started.single.kind, JobKind.rollback);
      expect(find.textContaining('Rolling back to generation'), findsOneWidget);
    });

    testWidgets('a wrong PIN asks again', (t) async {
      final h = await toPad(t);
      await enterPin(t, '1357'); // Sam's, not the admin's
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.rollback);
    });

    testWidgets('Back on the pad does nothing', (t) async {
      final h = await toPad(t);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(find.textContaining('Rolling back to generation'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('an admin profile without a PIN is not asked', (t) async {
      setView(t);
      final h = harness(current: 'p3'); // James sets his PIN first
      h.services.mockProfiles.box.admin.pin = null;
      await h.pump(t);
      await openRow(t, 2);
      await press(t, [kRight, kEnter]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started.single.kind, JobKind.rollback);
    });

    testWidgets('the parts your apps need: said before and after', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      // check, channel, rollback, generations 12, 11, 10.
      await openRow(t, 5);
      expect(find.text('Roll back to generation 10?'), findsOneWidget);
      expect(
        find.text('The box then turns on the parts that your apps need.'),
        findsOneWidget,
      );
      await press(t, [kRight, kEnter]);
      await enterPin(t, '2468');
      final job = h.services.mockJobs.started.single;
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(
        find.text('The parts your apps need are on again.'),
        findsOneWidget,
      );
    });

    testWidgets('the previous version needs nothing turned on', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openRow(t, 4); // generation 11
      expect(find.text('Roll back to generation 11?'), findsOneWidget);
      expect(
        find.text('The box then turns on the parts that your apps need.'),
        findsNothing,
      );
      await press(t, [kRight, kEnter]);
      await enterPin(t, '2468');
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
      expect(find.text('The parts your apps need are on again.'), findsNothing);
    });
  });

  group('channel', () {
    /// Channel -> Stable (from beta): the box checks stable, the owner
    /// confirms the verified version, then the pad is up.
    Future<Harness> toPad(WidgetTester t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openRow(t, 1);
      await press(t, [kDown, kEnter]); // Stable
      expect(find.text('Switch to Stable?'), findsOneWidget);
      expect(find.text('HinterOS 0.6.0 stable, 2026-10-01.'), findsOneWidget);
      expect(
        find.text('This version is older than the version on this box.'),
        findsOneWidget,
      );
      expect(h.services.mockJobs.started, isEmpty);
      await press(t, [kRight, kEnter]); // Switch
      expect(find.text('Switch to Stable'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      return h;
    }

    testWidgets('the verified version, then the right PIN', (t) async {
      final h = await toPad(t);
      await enterPin(t, '2468');
      expect(find.text(_askPin), findsNothing);
      final job = h.services.mockJobs.started.single;
      expect(job.kind, JobKind.channel);
      expect(
        h.services.mockUpdates.checkedChannel!.rev,
        '7e2d4f6a8b1c3e5d7f9a0b2c4d6e8f1a3b5c7d9e',
      );
    });

    testWidgets('a wrong PIN asks again', (t) async {
      final h = await toPad(t);
      await enterPin(t, '0000');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(h.services.mockJobs.started.single.kind, JobKind.channel);
    });

    testWidgets('Back on the pad does nothing', (t) async {
      final h = await toPad(t);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
      expect(h.services.mockUpdates.channel, UpdateChannel.beta);
    });

    testWidgets('Cancel on the version does nothing', (t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openRow(t, 1);
      await press(t, [kDown, kEnter]); // Stable
      expect(find.text('Switch to Stable?'), findsOneWidget);
      await press(t, [kEnter]); // Cancel
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('an older version than the box saw: refused, no switch', (
      t,
    ) async {
      setView(t);
      final h = harness();
      h.services.mockUpdates.failChannelCheckWith = const SystemException(
        SystemErrorKind.updateVerificationFailed,
        'This version is older than one this box already saw. '
        'Try again later.',
      );
      await h.pump(t);
      await openRow(t, 1);
      await press(t, [kDown, kEnter]); // Stable
      expect(find.text('Switch to Stable?'), findsNothing);
      expect(
        find.text(
          'This version is older than one this box already saw. '
          'Try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });
  });

  group('software base', () {
    /// On stable: Software base -> Stable (from unstable): the pad is up.
    Future<Harness> toPad(WidgetTester t) async {
      setView(t);
      final h = harness(channel: UpdateChannel.stable);
      await h.pump(t);
      await openRow(t, 2); // check, channel, base
      await press(t, [kDown, kEnter]); // Latest (current), Stable
      expect(find.text('Switch to the Stable base'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      return h;
    }

    testWidgets('the right PIN, then the downgrade question', (t) async {
      final h = await toPad(t);
      await enterPin(t, '2468');
      expect(find.text('Switch to the Stable base?'), findsOneWidget);
      await press(t, [kRight, kEnter]);
      expect(h.services.mockJobs.started.single.kind, JobKind.base);
    });

    testWidgets('a wrong PIN asks again', (t) async {
      final h = await toPad(t);
      await enterPin(t, '1111');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(find.text('Switch to the Stable base?'), findsOneWidget);
    });

    testWidgets('Back on the pad does nothing', (t) async {
      final h = await toPad(t);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
      expect(h.services.mockUpdates.base, NixBase.unstable);
    });
  });

  group('hardware (no screen yet: the repository)', () {
    test('the mock asks for the admin PIN like the service', () async {
      final s = MockSystemServices(now: fixedNow);
      addTearDown(s.dispose);
      await expectLater(
        s.system.redetectHardware(),
        throwsA(
          isA<SystemException>().having(
            (e) => e.kind,
            'kind',
            SystemErrorKind.pinRequired,
          ),
        ),
      );
      final h = await s.system.redetectHardware(adminPin: '2468');
      expect(h.kind, JobKind.hardwareRedetect);
    });
  });
}
