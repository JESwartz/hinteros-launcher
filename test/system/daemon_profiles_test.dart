import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' show MockDaemon;
import 'package:hinteros_launcher/src/system/daemon_profiles.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/profiles.dart';

/// The profile repositories over the session API (0.12), against the wire
/// mock: what goes out, what the screens get back.
void main() {
  Future<MockDaemon> connected() async {
    final m = MockDaemon();
    m.start();
    await m.waitConnected();
    return m;
  }

  group('session side', () {
    test('current, list and the PIN refusals', () async {
      final m = await connected();
      final jobs = DaemonJobs(m);
      final p = DaemonProfiles(m, jobs);
      final me = await p.current();
      expect(me.id, 'p1');
      expect(me.name, 'James');
      expect(me.color, ProfileColor.teal);
      expect(me.admin, isTrue);
      final s = await p.list();
      expect(s.profiles.map((x) => x.name), ['James', 'Sam']);
      expect(s.profiles[1].locked, isTrue);

      // Another profile: the admin PIN.
      await expectLater(
        p.rename('p3', 'Samantha'),
        throwsA(
          isA<SystemException>()
              .having((e) => e.kind, 'kind', SystemErrorKind.pinRequired)
              .having((e) => PinRefusal.of(e)!.kind, 'pin', PinKind.admin),
        ),
      );
      await p.rename('p3', 'Samantha', adminPin: '2468');
      expect(m.profiles.byId('p3')!.name, 'Samantha');

      // The backoff: the 4th wrong PIN locks.
      for (var i = 0; i < 3; i++) {
        await expectLater(p.setLocked(true, '0000'), throwsA(anything));
      }
      final e = await p
          .setLocked(true, '0000')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(PinRefusal.of(e!)!.retryAt, isNotNull);
    });

    test('create and remove are jobs with their kinds', () async {
      final m = await connected();
      final jobs = DaemonJobs(m);
      final p = DaemonProfiles(m, jobs);
      final job = await p.create(
        name: ' Robin ',
        color: ProfileColor.green,
        pin: '1357',
        locked: true,
      );
      expect(job.id, 'p4');
      expect(job.job.kind, JobKind.profileCreate);
      m.system.finishJob(job.job.jobId);
      expect(m.profiles.byId('p4')!.name, 'Robin');
      final r = await p.remove('p4', '2468');
      expect(r.kind, JobKind.profileRemove);
      expect(m.profiles.log, contains('remove:p4'));
    });

    test('switch events and the lock become typed events', () async {
      final m = await connected();
      final p = DaemonProfiles(m, DaemonJobs(m));
      await Future<void>.delayed(Duration.zero);
      m.profiles.blockingApp = (id: 'youtube', name: 'YouTube');
      final events = <SwitchEvent>[];
      final sub = p.switchEvents.listen(events.add);
      await p.switchTo('p3');
      await Future<void>.delayed(Duration.zero);
      expect(events.first, isA<SwitchProgress>());
      final b = events.whereType<SwitchBlocked>().single;
      expect(
        (b.appId, b.appName, b.waited.inSeconds),
        ('youtube', 'YouTube', 10),
      );
      await p.forceClose('youtube');
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<SwitchProgress>().last.stage, SwitchStage.ending);
      await sub.cancel();

      final locks = <bool>[];
      final ls = p.lockChanges.listen(locks.add);
      m.profiles.byId('p1')!.locked = true;
      m.profiles.sleep();
      await Future<void>.delayed(Duration.zero);
      await p.unlock('2468');
      await Future<void>.delayed(Duration.zero);
      expect(locks, [true, false]);
      await ls.cancel();
    });
  });

  group('greeter side', () {
    test(
      'an unlocked profile starts at once; a locked one asks for its PIN',
      () async {
        final m = await connected();
        m.profiles.greeterMode = true;
        final g = DaemonGreeter(m, DaemonJobs(m));
        await Future<void>.delayed(Duration.zero);
        final v = await g.load();
        expect(v.profiles.map((p) => p.id), ['p1', 'p3']);
        expect(v.guest, isTrue);
        expect(await g.login('p1'), isA<LoginStarted>());
        expect(await g.login('p3'), isA<LoginNeedsPin>());
        expect(await g.login('p3', pin: '0000'), isA<LoginRefused>());
        // Refused: greetd's session is gone, the next try starts over.
        expect(await g.login('p3', pin: '1357'), isA<LoginStarted>());
        expect(m.profiles.log, contains('greeter_pin:p3:ok'));
      },
    );

    test('Add profile, then in with the one-time token', () async {
      final m = await connected();
      m.profiles.greeterMode = true;
      final jobs = DaemonJobs(m);
      final g = DaemonGreeter(m, jobs);
      await Future<void>.delayed(Duration.zero);
      final job = await g.create(
        name: 'Robin',
        color: ProfileColor.green,
        pin: '1357',
        locked: true,
      );
      m.system.finishJob(job.job.jobId);
      expect(await g.login(job.id), isA<LoginStarted>());
    });
  });
}
