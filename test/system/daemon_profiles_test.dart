import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart'
    show DaemonUnavailableException, MockDaemon;
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

      // The admin profile's PIN has no backoff: wrong stays only wrong.
      for (var i = 0; i < 6; i++) {
        final e = await p
            .setLocked(true, '0000')
            .then<Object?>((_) => null, onError: (Object e) => e);
        expect(PinRefusal.of(e!)!.retryAt, isNull);
      }
      await p.setLocked(true, '2468');
      // But 10 wrong tries a boot: then even the right PIN is refused until
      // the box restarts (session API 0.17).
      Future<Object?> lock(String pin) => p
          .setLocked(true, pin)
          .then<Object?>((_) => null, onError: (Object e) => e);
      for (var i = 0; i < 9; i++) {
        expect(PinRefusal.of((await lock('0000'))!)!.rebootRequired, isFalse);
      }
      for (final pin in ['0000', '2468']) {
        final e = await lock(pin);
        expect(PinRefusal.of(e!)!.rebootRequired, isTrue, reason: pin);
        expect(
          (e as SystemException).message,
          'Too many wrong PINs. Restart the box to try again.',
        );
      }
      m.profiles.reboot();
      await p.setLocked(true, '2468');

      // A locked target: its PIN before anything closes (a wrong one
      // starts nothing).
      await expectLater(
        p.switchTo('p3', pin: '0000'),
        throwsA(
          isA<SystemException>().having(
            (e) => PinRefusal.of(e)!.kind,
            'pin',
            PinKind.target,
          ),
        ),
      );
      expect(m.profiles.log, isNot(contains('switch:p3')));
      await p.switchTo('p3', pin: '1357');
      expect(m.profiles.log, contains('switch:p3'));
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
      final r = await p.remove('p4', adminPin: '2468');
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
      await p.switchTo('p3', pin: '1357');
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

    test('the admin profile: ten wrong PINs, then a restart', () async {
      final m = await connected();
      m.profiles.greeterMode = true;
      m.profiles.byId('p1')!.locked = true;
      final g = DaemonGreeter(m, DaemonJobs(m));
      await Future<void>.delayed(Duration.zero);
      Future<LoginRefused> refused(String pin) async {
        expect(await g.login('p1'), isA<LoginNeedsPin>());
        return await g.login('p1', pin: pin) as LoginRefused;
      }

      for (var i = 0; i < 9; i++) {
        final r = await refused('0000');
        expect((r.retryAt, r.rebootRequired), (null, false));
      }
      expect((await refused('0000')).rebootRequired, isTrue);
      expect((await refused('2468')).rebootRequired, isTrue);
    });

    test('a failed login call leaves no wait for its answer behind', () async {
      final m = _FailsLogin();
      m.start();
      await m.waitConnected();
      m.profiles.greeterMode = true;
      final g = DaemonGreeter(
        m,
        DaemonJobs(m),
        answerTimeout: const Duration(milliseconds: 10),
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(g.login('p1'), throwsA(isA<SystemException>()));
      // The answer's timeout passes: no uncaught TimeoutException.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

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

  test('names: what the service refuses is refused in the form', () {
    expect(nameProblem('  '), 'Type a name.');
    expect(nameProblem('Sam'), isNull);
    expect(nameProblem('Zoë 2'), isNull);
    expect(nameProblem('a' * 33), 'Use at most 32 characters.');
    for (final bad in [
      'Sa\tm',
      'Sa\u0085m',
      'Sa\u200Bm',
      '\u202ESam',
      'S\uFEFFam',
    ]) {
      expect(nameProblem(bad), 'Use letters, numbers and spaces.', reason: bad);
    }
  });
}

/// greeter.login fails (the session daemon went away).
class _FailsLogin extends MockDaemon {
  @override
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) {
    if (method == 'greeter.login') {
      return Future.error(const DaemonUnavailableException());
    }
    return super.rpc(method, params);
  }
}
