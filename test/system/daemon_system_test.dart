// The real SystemRepository, UpdatesRepository and JobsRepository, over the
// mock daemon's relay of the system API (session API 0.6).
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/log.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/repositories.dart';

const _rev = '9a8b7c6d5e4f30211a2b3c4d5e6f708192a3b4c5';

api.AvailableUpdate _update({
  api.Severity? security,
  String? version,
  String? securitySummary,
}) => api.AvailableUpdate(
  rev: _rev,
  version: version,
  securitySummary: securitySummary,
  date: 1791300000,
  summary: 'Fixes a flaw in the web engine.',
  signer: 'release@hinteros',
  security: security,
  commits: 3,
  newApps: null,
  removedApps: null,
);

Future<(api.MockDaemon, SystemServices)> _setup() async {
  final mock = api.MockDaemon(now: () => DateTime(2026, 10, 6, 12));
  await mock.waitConnected();
  final services = daemonSystemServices(mock);
  addTearDown(() async {
    await mock.close();
  });
  return (mock, services);
}

/// A daemon whose connection ends when it answers session.restart.
class _DropsOnRestart extends api.MockDaemon {
  @override
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (method == 'session.restart') {
      throw const api.DaemonUnavailableException('connection closed');
    }
    return super.rpc(method, params);
  }
}

/// A connection that is not there (the real client throws this).
class _Offline extends api.MockDaemon {
  @override
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, dynamic> params,
  ) => Future.error(const api.DaemonUnavailableException());
}

Future<SystemException> _fails(Future<Object?> f) async {
  try {
    await f;
  } on SystemException catch (e) {
    return e;
  }
  fail('expected a SystemException');
}

void main() {
  group('system.info', () {
    test('maps the box, the DEV flag and the host key fingerprints', () async {
      final (mock, s) = await _setup();
      mock.system
        ..dev = true
        ..channel = null
        ..rev = null
        ..generation = null;
      final i = await s.system.info();
      expect(i.version, '0.1.0');
      expect(i.channel, isNull);
      expect(i.base, NixBase.unstable);
      expect(i.rev, isNull);
      expect(i.dev, isTrue);
      expect(i.hostname, 'hinteros');
      expect(i.hostKeyFingerprints, [
        'SHA256:2CixtE95MNbZHanQGv6hP2D3qfguu9QZfjca2OaupKI',
      ]);
      expect((await s.system.ssh()).enabled, isFalse);
    });

    test('system_unavailable (down) is "settings unavailable"', () async {
      final (mock, s) = await _setup();
      mock.system.unavailable = api.SystemUnavailableDataReason.down;
      final e = await _fails(s.system.info());
      expect(e.kind, SystemErrorKind.unavailable);
      expect(e.message, contains('unavailable'));
      expect(e.data['reason'], 'down');
      expect(
        (await _fails(s.updates.check())).kind,
        SystemErrorKind.unavailable,
      );
    });

    test('version_mismatch says the session has to restart', () async {
      final (mock, s) = await _setup();
      mock.system.unavailable = api.SystemUnavailableDataReason.versionMismatch;
      final e = await _fails(s.system.info());
      expect(e.kind, SystemErrorKind.unavailable);
      expect(e.message, contains('restarts'));
    });

    test('not connected is unavailable too', () async {
      final mock = _Offline();
      final s = daemonSystemServices(mock);
      addTearDown(mock.close);
      expect((await _fails(s.system.info())).kind, SystemErrorKind.unavailable);
    });
  });

  group('ssh.set and the admin password', () {
    test(
      'no authentication agent: authentication_required, with the action',
      () async {
        final (mock, s) = await _setup();
        mock.auth.agentRegistered = false;
        final e = await _fails(s.system.setSsh(true));
        expect(e.kind, SystemErrorKind.authenticationRequired);
        expect(e.data['action'], 'org.hinteros.system.ssh');
        expect(mock.system.log, ['ssh.set:on']);
        expect(mock.system.sshEnabled, isFalse);
      },
    );

    test('the prompt: wrong password (tries left), then the right one starts the job', () async {
      final (mock, s) = await _setup();
      final asked = s.auth.requests.first;
      final finished = s.auth.finished.first;
      var done = false;
      final call = s.system.setSsh(true)..then((_) => done = true);
      final r = await asked;
      expect(r.action, 'org.hinteros.system.ssh');
      expect(r.account, 'admin');
      expect(r.message, contains('remote login'));
      // The call waits; the answers to auth.respond come meanwhile (out of
      // order with the waiting call's response).
      final wrong = await s.auth.respond(r.cookie, 'nope');
      expect((wrong.ok, wrong.attemptsLeft), (false, 2));
      expect(done, isFalse);
      final right = await s.auth.respond(r.cookie, 'correct horse');
      expect(right.ok, isTrue);
      expect((await finished).outcome, AuthOutcome.authorized);
      final h = await call;
      expect(h.kind, JobKind.ssh);
      mock.system.finishJob(h.jobId);
      expect(mock.auth.pendingCookies, isEmpty);
      // The password reached nobody but auth.respond: not the relayed call.
      expect(mock.system.log, ['ssh.set:on']);
      expect(mock.auth.attempts, 2);
    });

    test('three wrong passwords: permission_denied, outcome failed', () async {
      final (mock, s) = await _setup();
      final asked = s.auth.requests.first;
      final outcome = s.auth.finished.first;
      final call = _fails(s.system.setSsh(true));
      final r = await asked;
      expect((await s.auth.respond(r.cookie, 'a')).attemptsLeft, 2);
      expect((await s.auth.respond(r.cookie, 'b')).attemptsLeft, 1);
      final last = await s.auth.respond(r.cookie, 'c');
      expect((last.ok, last.attemptsLeft), (false, 0));
      expect((await outcome).outcome, AuthOutcome.failed);
      final e = await call;
      expect(e.kind, SystemErrorKind.permissionDenied);
      expect(e.message, contains('wrong too many times'));
      expect(mock.system.sshEnabled, isFalse);
    });

    test('cancelling: authentication_required, outcome cancelled', () async {
      final (_, s) = await _setup();
      final asked = s.auth.requests.first;
      final outcome = s.auth.finished.first;
      final call = _fails(s.system.setSsh(true));
      final r = await asked;
      await s.auth.cancel(r.cookie);
      expect((await outcome).outcome, AuthOutcome.cancelled);
      final e = await call;
      expect(e.kind, SystemErrorKind.authenticationRequired);
      expect(e.message, contains('nothing was changed'));
      // A request that is over is not an error to cancel again, and not
      // something to answer.
      await s.auth.cancel(r.cookie);
      expect(
        (await _fails(s.auth.respond(r.cookie, 'x'))).kind,
        SystemErrorKind.notFound,
      );
    });

    test('only the launcher may answer', () async {
      final mock = api.MockDaemon(clientName: 'someone-else');
      await mock.waitConnected();
      final s = daemonSystemServices(mock);
      addTearDown(mock.close);
      final call = _fails(s.system.setSsh(true));
      await Future<void>.delayed(Duration.zero);
      final e = await _fails(
        s.auth.respond(mock.auth.pendingCookies.single, 'correct horse'),
      );
      expect(e.kind, SystemErrorKind.notAuthorized);
      mock.auth.cancelFromPolkit(mock.auth.pendingCookies.single);
      expect((await call).kind, SystemErrorKind.authenticationRequired);
    });

    test('an authorised caller gets a job that ends with SSH on', () async {
      final (mock, s) = await _setup();
      mock.system.adminAuthorized = true;
      final h = await s.system.setSsh(true);
      expect(h.kind, JobKind.ssh);
      final done = s.jobs.watch(h.jobId).firstWhere((x) => x.finished);
      mock.system.finishJob(h.jobId);
      expect((await done).ok, isTrue);
      expect((await s.system.ssh()).enabled, isTrue);
      // Off needs no password; already off: nothing to do.
      mock.system.adminAuthorized = false;
      final off = await s.system.setSsh(false);
      mock.system.finishJob(off.jobId);
      expect(
        (await _fails(s.system.setSsh(false))).kind,
        SystemErrorKind.nothingToDo,
      );
    });
  });

  group('settings.set', () {
    test('passes the revision it read, and retries once when stale', () async {
      final (mock, s) = await _setup();
      expect(await s.system.applySettings(), isNull);
      mock.system.failNext = const api.ApiException(
        api.ApiErrorCode.stateConflict,
        'state.json changed since settings.get',
        {'reason': 'revision'},
      );
      expect(await s.system.applySettings(), isNull);
      expect(mock.system.log, ['settings.set', 'settings.set', 'settings.set']);
    });
  });

  group('jobs', () {
    test('events drive the snapshots through to the end', () async {
      final (mock, s) = await _setup();
      final h = await s.updates.rollback();
      expect(h.kind, JobKind.rollback);
      final all = s.jobs.watch(h.jobId).toList();
      await pumpEventQueue();
      mock.system.progressJob(h.jobId, api.Stage.activating);
      await pumpEventQueue();
      mock.system.finishJob(h.jobId, sessionRestartRequired: true);
      final seen = await all;
      expect(seen.first.stage, JobStage.preparing);
      expect(seen.map((x) => x.stage), contains(JobStage.activating));
      expect(seen.last.finished, isTrue);
      expect(seen.last.ok, isTrue);
      expect(seen.last.sessionRestartRequired, isTrue);
      expect(seen.last.canCancel, isFalse);
    });

    test('download progress shows percent and bytes', () async {
      final (mock, s) = await _setup();
      mock.system.nextUpdate = _update();
      final check = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(mock.system.runningJobId!);
      await check;
      final h = await s.updates.apply(_rev);
      final all = s.jobs.watch(h.jobId).toList();
      await pumpEventQueue();
      mock.system.progressJob(
        h.jobId,
        api.Stage.downloading,
        percent: 40,
        bytesTotal: 500 << 20,
      );
      await pumpEventQueue();
      mock.system.finishJob(h.jobId);
      final seen = await all;
      final mid = seen.firstWhere((x) => x.percent == 40);
      expect(mid.detail, '200 MB of 500 MB');
    });

    test('a failure carries its stage and log hint', () async {
      final (mock, s) = await _setup();
      mock.system.adminAuthorized = true;
      final job = await s.system.setSsh(true);
      mock.system.progressJob(job.jobId, api.Stage.building);
      mock.system.finishJob(
        job.jobId,
        ok: false,
        error: const api.ErrorObject(
          code: api.ApiErrorCode.jobFailed,
          message: 'the job failed while building',
          data: {'stage': 'building', 'log_hint': 'error: builder failed'},
        ),
      );
      final last = await s.jobs.watch(job.jobId).last;
      expect(last.failed, isTrue);
      expect(last.error!.stage, JobStage.building);
      expect(last.error!.logHint, 'error: builder failed');
    });

    test('a failed job is logged with its code and message', () async {
      final log = <String>[];
      final old = logSink;
      logSink = log.add;
      addTearDown(() => logSink = old);
      final (mock, s) = await _setup();
      mock.system.adminAuthorized = true;
      final job = await s.system.setSsh(true);
      mock.system.finishJob(
        job.jobId,
        ok: false,
        error: const api.ErrorObject(
          code: api.ApiErrorCode.jobFailed,
          message: 'the job failed while building',
        ),
      );
      await s.jobs.watch(job.jobId).last;
      expect(log, hasLength(1));
      expect(
        log.single,
        contains('${api.ApiErrorCode.jobFailed} the job failed while building'),
      );
    });

    test('cancel works before activating, then job_busy', () async {
      final (mock, s) = await _setup();
      mock.system.adminAuthorized = true;
      final a = await s.system.setSsh(true);
      await s.jobs.cancel(a.jobId);
      final last = await s.jobs.watch(a.jobId).last;
      expect(last.cancelled, isTrue);
      expect(last.failed, isFalse);

      final b = await s.updates.rollback();
      mock.system.progressJob(b.jobId, api.Stage.activating);
      expect(
        (await _fails(s.jobs.cancel(b.jobId))).kind,
        SystemErrorKind.jobBusy,
      );
    });

    test('one mutating job at a time', () async {
      final (_, s) = await _setup();
      await s.updates.rollback();
      final e = await _fails(s.updates.rollback());
      expect(e.kind, SystemErrorKind.jobBusy);
      expect(e.data['job_id'], isA<String>());
    });

    test('a job the launcher did not start is found with jobs.get', () async {
      final (mock, s) = await _setup();
      // Started before the repositories looked (another client).
      mock.system.jobIdQueue.add('aaaaaaaaaaaaaaaa');
      await mock.rpc('system.rebuild', {});
      final jobs2 = DaemonJobs(mock);
      final first = await jobs2.watch('aaaaaaaaaaaaaaaa').first;
      expect(first.kind, JobKind.rebuild);
      expect(first.running, isTrue);
      await jobs2.dispose();
    });

    test('an unknown job is not_found', () async {
      final (_, s) = await _setup();
      await expectLater(
        s.jobs.watch('0000000000000000').first,
        throwsA(
          isA<SystemException>().having(
            (e) => e.kind,
            'kind',
            SystemErrorKind.notFound,
          ),
        ),
      );
    });
  });

  group('updates', () {
    test('check waits for the job and reads its result', () async {
      final (mock, s) = await _setup();
      mock.system.nextUpdate = _update(security: api.Severity.high);
      final f = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(mock.system.runningJobId!);
      final st = await f;
      expect(st.currentVersion, '0.1.0');
      expect(st.available!.rev, _rev);
      expect(st.available!.isSecurity, isTrue);
      expect(st.available!.severity, SecuritySeverity.high);
      expect(st.available!.summary, 'Fixes a flaw in the web engine.');
      expect(s.updates.status.available, isNotNull);
    });

    test('a second check within 60 s uses the cached result', () async {
      final (mock, s) = await _setup();
      mock.system.nextUpdate = _update();
      final f = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(mock.system.runningJobId!);
      await f;
      // No job to wait for this time.
      final again = await s.updates.check();
      expect(again.available!.rev, _rev);
      expect(mock.system.runningJobId, isNull);
      expect(again.available!.isSecurity, isFalse);
    });

    test('the release version and the security summary', () async {
      final (mock, s) = await _setup();
      mock.system.nextUpdate = _update(
        security: api.Severity.high,
        version: '0.6.1',
        securitySummary: 'A website could take over the browser.',
      );
      final f = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(mock.system.runningJobId!);
      final a = (await f).available!;
      expect(a.version, '0.6.1');
      expect(a.securitySummary, 'A website could take over the browser.');
    });

    test('without a release version the update is named by its date', () async {
      for (final v in [null, '9a8b7c6d5e4f', 'v0.6']) {
        final (mock, s) = await _setup();
        mock.system.nextUpdate = _update(version: v, securitySummary: '  ');
        final f = s.updates.check();
        await pumpEventQueue();
        mock.system.finishJob(mock.system.runningJobId!);
        final a = (await f).available!;
        final d = DateTime.fromMillisecondsSinceEpoch(1791300000 * 1000);
        expect(
          a.version,
          '${d.year}.${d.month.toString().padLeft(2, '0')}.'
          '${d.day.toString().padLeft(2, '0')}',
          reason: '$v',
        );
        expect(a.securitySummary, isNull);
      }
    });

    test('releaseVersion accepts only release versions', () {
      expect(releaseVersion('0.6.1'), '0.6.1');
      expect(releaseVersion('1.0.0-rc.1'), '1.0.0-rc.1');
      for (final v in [null, '', '9a8b7c6d5e4f', '0.6', '0.6.1+b', 'x0.6.1']) {
        expect(releaseVersion(v), isNull, reason: '$v');
      }
    });

    test('severities map: medium is moderate', () async {
      final (mock, s) = await _setup();
      mock.system.nextUpdate = _update(security: api.Severity.medium);
      final f = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(mock.system.runningJobId!);
      expect((await f).available!.severity, SecuritySeverity.moderate);
    });

    test('a failed check maps the job error', () async {
      final (mock, s) = await _setup();
      final f = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(
        mock.system.runningJobId!,
        ok: false,
        error: const api.ErrorObject(
          code: api.ApiErrorCode.updateUnreachable,
          message: 'cannot reach the update server',
          data: {'host': 'justsomeshed.com'},
        ),
      );
      final e = await _fails(f);
      expect(e.kind, SystemErrorKind.updateUnreachable);
    });

    test('apply takes only the checked rev; the job updates the box', () async {
      final (mock, s) = await _setup();
      expect(
        (await _fails(s.updates.apply(_rev))).kind,
        SystemErrorKind.stateConflict,
      );
      mock.system.nextUpdate = _update();
      final f = s.updates.check();
      await pumpEventQueue();
      mock.system.finishJob(mock.system.runningJobId!);
      await f;
      mock.system.restartNext = true;
      final h = await s.updates.apply(_rev);
      expect(h.kind, JobKind.update);
      mock.system.finishJob(h.jobId);
      final done = await s.jobs.watch(h.jobId).last;
      expect(done.ok, isTrue);
      expect(done.sessionRestartRequired, isTrue);
      final gens = await s.updates.generations();
      expect(gens.first.generation, 43);
      expect(gens.first.current, isTrue);
      expect(gens.last.rev, isNull);
    });

    test('a downgrade needs the acknowledgement, then goes through', () async {
      final (mock, s) = await _setup();
      mock.system.channel = api.Channel.beta;
      final e = await _fails(s.updates.setChannel(UpdateChannel.stable));
      expect(e.kind, SystemErrorKind.needsAcknowledgement);
      final h = await s.updates.setChannel(
        UpdateChannel.stable,
        acknowledgeDowngrade: true,
      );
      expect(h.kind, JobKind.channel);
      mock.system.finishJob(h.jobId);
      expect((await s.system.info()).channel, UpdateChannel.stable);

      final b = await _fails(s.updates.setBase(NixBase.stable));
      expect(b.kind, SystemErrorKind.needsAcknowledgement);
      final hb = await s.updates.setBase(
        NixBase.stable,
        acknowledgeDowngrade: true,
      );
      expect(hb.kind, JobKind.base);
      expect(
        (await _fails(s.updates.rollback())).kind,
        SystemErrorKind.jobBusy,
      );
    });

    test('same channel: nothing to do', () async {
      final (_, s) = await _setup();
      expect(
        (await _fails(s.updates.setChannel(UpdateChannel.stable))).kind,
        SystemErrorKind.nothingToDo,
      );
    });

    test('rollback to an unknown generation is not_found', () async {
      final (_, s) = await _setup();
      expect(
        (await _fails(s.updates.rollback(generation: 7))).kind,
        SystemErrorKind.notFound,
      );
    });

    test('rate limit and low memory get readable messages', () async {
      final (mock, s) = await _setup();
      mock.system.failNext = const api.ApiException(
        api.ApiErrorCode.rateLimited,
        'too many requests',
        {'retry_after_ms': 4000},
      );
      expect(
        (await _fails(s.updates.rollback())).kind,
        SystemErrorKind.rateLimited,
      );
      mock.system.failNext = const api.ApiException(
        api.ApiErrorCode.insufficientResources,
        'not enough memory',
        {'kind': 'memory', 'needed_bytes': 2147483648, 'available_bytes': 1},
      );
      final e = await _fails(s.updates.rollback());
      expect(e.kind, SystemErrorKind.insufficientResources);
      expect(e.message, contains('memory'));
    });
  });

  group('session.restart', () {
    test('asks the daemon to restart the session', () async {
      final (mock, s) = await _setup();
      await s.system.restartSession();
      expect(mock.sessionRestarts, 1);
    });

    test(
      'the launcher going away with the session is the restart working',
      () async {
        final mock = _DropsOnRestart();
        await mock.waitConnected();
        final s = daemonSystemServices(mock);
        addTearDown(mock.close);
        await s.system.restartSession();
      },
    );

    test('a desktop session is refused with a plain message', () async {
      final (mock, s) = await _setup();
      mock.sessionRestartAvailable = false;
      final e = await _fails(s.system.restartSession());
      expect(e.kind, SystemErrorKind.unavailable);
      expect(e.message, contains('not a TV session'));
      expect(mock.sessionRestarts, 0);
    });

    test('without a connection it is unavailable', () async {
      final mock = _Offline();
      final s = daemonSystemServices(mock);
      addTearDown(mock.close);
      expect(
        (await _fails(s.system.restartSession())).kind,
        SystemErrorKind.unavailable,
      );
    });
  });
}
