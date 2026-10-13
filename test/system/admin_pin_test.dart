// The admin PIN of the box-wide actions (session API 0.13): rollback,
// channel and base ask for it on the admin-PIN pad before they run; a wrong
// PIN asks again, Back on the empty pad does nothing. Also the rollback's
// "turns on the parts your apps need" line.
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

const _askPin = "Type the admin profile's PIN.";

Harness harness({
  UpdateChannel channel = UpdateChannel.beta,
  String current = 'p1',
}) {
  final s = MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    currentProfile: current,
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
      expect(find.text('Rolling back'), findsOneWidget);
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
      expect(find.text('Rolling back'), findsNothing);
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
    /// Channel -> Stable (a downgrade from beta): the pad is up.
    Future<Harness> toPad(WidgetTester t) async {
      setView(t);
      final h = harness();
      await h.pump(t);
      await openRow(t, 1);
      await press(t, [kDown, kEnter]); // Stable
      expect(find.text('Switch to Stable'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      return h;
    }

    testWidgets('the right PIN, then the downgrade question', (t) async {
      final h = await toPad(t);
      await enterPin(t, '2468');
      expect(find.text('Switch to Stable?'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await press(t, [kRight, kEnter]); // Switch anyway: no second PIN
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started.single.kind, JobKind.channel);
    });

    testWidgets('a wrong PIN asks again', (t) async {
      final h = await toPad(t);
      await enterPin(t, '0000');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(find.text('Switch to Stable?'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      expect(find.text('Switch to Stable?'), findsOneWidget);
    });

    testWidgets('Back on the pad does nothing', (t) async {
      final h = await toPad(t);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(find.text('Switch to Stable?'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
      expect(h.services.mockUpdates.channel, UpdateChannel.beta);
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
