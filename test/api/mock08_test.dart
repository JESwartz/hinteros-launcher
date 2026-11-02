// Behaviour of the mock daemon's 0.8 parts that the schema examples do not
// show: the order of events and answers around the admin password prompt
// (the waiting call answers last), who gets the events, the Store's states
// while a job runs, and store_changed.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';

final _hello = HelloParams(
  apiVersion: apiVersion,
  client: const Peer(name: 'test', version: '0'),
).toJson();

Future<MockDaemon> _mock({String clientName = 'hinteros-launcher'}) async {
  final m = MockDaemon(clientName: clientName);
  await m.rpc('hello', _hello);
  await m.subscribeTo([
    EventName.authenticationRequested,
    EventName.authenticationFinished,
    EventName.storeChanged,
    EventName.jobStarted,
    EventName.jobFinished,
  ]);
  return m;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('the admin password prompt', () {
    test('ssh.set waits; auth.respond answers first, the call last', () async {
      final m = await _mock();
      final seen = <String>[];
      m.events.listen((e) => seen.add(e.name));
      var order = <String>[];
      final call = m
          .rpc('system.ssh.set', {'enabled': true})
          .then((_) => order.add('ssh.set'));
      await _settle();
      expect(seen, ['authentication_requested']);
      final cookie = m.auth.pendingCookies.single;
      final r = await m.rpc('auth.respond', {
        'cookie': cookie,
        'password': 'correct horse',
      });
      order.add('auth.respond');
      expect(r, {'ok': true, 'attempts_left': 2});
      await call;
      expect(order, ['auth.respond', 'ssh.set']);
      await _settle();
      expect(seen, [
        'authentication_requested',
        'authentication_finished',
        'job_started',
      ]);
    });

    test('three wrong passwords end the request: permission_denied', () async {
      final m = await _mock();
      final call = m
          .rpc('system.ssh.set', {'enabled': true})
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );
      await _settle();
      final cookie = m.auth.pendingCookies.single;
      final left = <int>[];
      for (var i = 0; i < 3; i++) {
        final r = await m.rpc('auth.respond', {
          'cookie': cookie,
          'password': 'x',
        });
        expect(r['ok'], isFalse);
        left.add(r['attempts_left'] as int);
      }
      expect(left, [2, 1, 0]);
      final e = await call;
      expect(e!.code, ApiErrorCode.permissionDenied);
      expect((e.data as Map)['reason'], 'polkit');
      // The request is over.
      await expectLater(
        m.rpc('auth.respond', {'cookie': cookie, 'password': 'x'}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.notFound,
          ),
        ),
      );
    });

    test(
      'auth.cancel: authentication_required for the call, event cancelled',
      () async {
        final m = await _mock();
        final outcomes = <AuthOutcome>[];
        m.events.listen((e) {
          if (e is AuthenticationFinishedEvent) outcomes.add(e.outcome);
        });
        final call = m
            .rpc('system.ssh.set', {'enabled': true})
            .then<ApiException?>(
              (_) => null,
              onError: (Object e) => e as ApiException,
            );
        await _settle();
        await m.rpc('auth.cancel', {'cookie': m.auth.pendingCookies.single});
        expect((await call)!.code, ApiErrorCode.authenticationRequired);
        expect(outcomes, [AuthOutcome.cancelled]);
      },
    );

    test('only the launcher gets the events and may answer', () async {
      final other = await _mock(clientName: 'hinteros-osk');
      final seen = <String>[];
      other.events.listen((e) => seen.add(e.name));
      unawaited(
        other
            .rpc('system.ssh.set', {'enabled': true})
            .then((_) {}, onError: (_) {}),
      );
      await _settle();
      expect(seen, isEmpty);
      await expectLater(
        other.rpc('auth.respond', {
          'cookie': other.auth.pendingCookies.single,
          'password': 'correct horse',
        }),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.notAuthorized,
          ),
        ),
      );
      other.auth.cancelFromPolkit(other.auth.pendingCookies.single);
    });

    test('the password is not kept anywhere the mock logs', () async {
      final m = await _mock();
      unawaited(
        m
            .rpc('system.ssh.set', {'enabled': true})
            .then((_) {}, onError: (_) {}),
      );
      await _settle();
      await m.rpc('auth.respond', {
        'cookie': m.auth.pendingCookies.single,
        'password': 'hunter2-hunter2',
      });
      expect(m.system.log.join(), isNot(contains('hunter2')));
      expect(m.keyLog.join(), isNot(contains('hunter2')));
    });
  });

  group('the Store', () {
    Future<List<StoreApp>> list(MockDaemon m) async =>
        (await m.storeList()).apps;

    test(
      'states follow an apps job; store_changed marks start and end',
      () async {
        final m = await _mock();
        final changed = <String>[];
        m.events.listen((e) {
          if (e is StoreChangedEvent) changed.add('changed');
          if (e is JobFinishedEvent) changed.add('finished');
        });
        final rev = (await m.systemSettingsGet()).revision;
        final job = (await m.systemAppsInstall(
          SystemAppsInstallParams(ids: const ['moonlight'], revision: rev),
        )).jobId!;
        await _settle();
        expect(changed, ['changed']);
        expect(
          (await list(m)).firstWhere((a) => a.id == 'moonlight').state,
          StoreState.installing,
        );
        m.system.finishJob(job);
        await _settle();
        expect(changed, ['changed', 'finished', 'changed']);
        expect(
          (await list(m)).firstWhere((a) => a.id == 'moonlight').state,
          StoreState.installed,
        );
        expect(m.system.installedApps, ['steam', 'moonlight']);
        // The revision moved on with the change: the old one is stale.
        await expectLater(
          m.systemAppsRemove(
            SystemAppsRemoveParams(
              ids: const ['moonlight'],
              revision: rev,
              deleteData: false,
            ),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.stateConflict,
            ),
          ),
        );
      },
    );

    test(
      'dependencies come along; a conflict with either side is refused',
      () async {
        final m = await _mock();
        final rev = (await m.systemSettingsGet()).revision;
        final job = (await m.systemAppsInstall(
          SystemAppsInstallParams(ids: const ['retroarch'], revision: rev),
        )).jobId!;
        m.system.finishJob(job);
        expect(
          m.system.installedApps,
          containsAll(['retroarch', 'retroarch-cores']),
        );
        // Jellyfin conflicts with the installed Kodi the other way round.
        m.system.installedApps.add('kodi');
        final rev2 = (await m.systemSettingsGet()).revision;
        await expectLater(
          m.systemAppsInstall(
            SystemAppsInstallParams(
              ids: const ['jellyfin-desktop'],
              revision: rev2,
            ),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.appConflict,
            ),
          ),
        );
      },
    );

    test('more_after_update comes with the update check', () async {
      final m = await _mock();
      expect((await m.storeList()).moreAfterUpdate, isFalse);
      m.system.nextUpdate = const AvailableUpdate(
        rev: '9a8b7c6d5e4f30211a2b3c4d5e6f708192a3b4c5',
        date: 1791300000,
        summary: 'New apps.',
        signer: 'release@hinteros',
        security: null,
        commits: 1,
        newApps: [CatalogApp(id: 'x', name: 'X')],
        removedApps: null,
      );
      final id = (await m.rpc('system.update.check', {}))['job_id'] as String;
      m.system.finishJob(id);
      await _settle();
      expect((await m.storeList()).moreAfterUpdate, isTrue);
    });

    test('terms texts exist where the listing says', () async {
      final m = await _mock();
      final steam = (await list(m)).firstWhere((a) => a.id == 'steam');
      expect(steam.terms!.file, startsWith('/'));
      expect(steam.terms!.file, endsWith('terms/steam-2026-09-10.txt'));
    });
  });

  test('session.restart counts, and a desktop session refuses', () async {
    final m = await _mock();
    await m.sessionRestart();
    expect(m.sessionRestarts, 1);
    m.sessionRestartAvailable = false;
    await expectLater(
      m.sessionRestart(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.unavailable,
        ),
      ),
    );
  });
}
