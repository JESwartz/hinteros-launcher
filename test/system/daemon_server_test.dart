// The real ServerRepository over the mock daemon's relay (session API 0.19):
// services.list as the tab's model, the admin PIN, Plex's terms, the jobs
// and their sign-in address, and the service's refusals as short messages.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_server.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/server.dart';

/// The mock box's admin PIN (James).
const _pin = '2468';

typedef _Box = ({api.MockDaemon mock, DaemonJobs jobs, DaemonServer server});

Future<_Box> _setup({String? Function(String path)? readTerms}) async {
  final mock = api.MockDaemon(now: () => DateTime(2026, 10, 20, 12));
  await mock.waitConnected();
  final jobs = DaemonJobs(mock);
  final server = DaemonServer(
    mock,
    jobs,
    readTerms: readTerms ?? (_) => 'Placeholder terms.',
  );
  addTearDown(() async {
    await server.dispose();
    await jobs.dispose();
    await mock.close();
  });
  return (mock: mock, jobs: jobs, server: server);
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
  test('services.list: the services, their state and detail', () async {
    final b = await _setup();
    final l = await b.server.list();
    expect(l.revision, b.mock.system.revision);
    expect(
      [for (final s in l.services) s.id],
      [
        'cloudflare-tunnel',
        'jellyfin-server',
        'plex-media-server',
        'tailscale',
      ],
    );
    final j = l.byId('jellyfin-server')!;
    expect(j.state, ServiceState.running);
    expect(j.setup, ServiceSetup.jellyfinServer);
    final d = j.detail! as JellyfinDetail;
    expect(d.url, 'http://192.168.1.42:8096');
    expect(
      [for (final x in d.libraries) (x.name, x.kind, x.folder)],
      [
        ('Movies', LibraryKind.movies, 'Movies'),
        ('Books', LibraryKind.other, null),
      ],
    );
    expect(d.users['p1'], isNotNull);
    final p = l.byId('plex-media-server')!;
    expect(p.state, ServiceState.off);
    expect(p.detail, isNull);
    expect(p.terms!.version, '2025-10-30');
    expect(p.terms!.text, 'Placeholder terms.');
    expect(p.termsMissing, isFalse);
    // Icons: the path the session daemon resolved, else the letter tile.
    expect(j.iconPath, '/home/tv/.cache/hinteros/icons/jellyfin-server.svg');
    expect(p.iconPath, isNull);
    expect([for (final s in l.services) s.hasData], everyElement(isTrue));
  });

  test('has_data false: no data to delete', () async {
    final b = await _setup();
    b.mock.system.server.cloudflare.hasData = false;
    final l = await b.server.list();
    expect(l.byId('cloudflare-tunnel')!.hasData, isFalse);
    expect(l.byId('tailscale')!.hasData, isTrue);
  });

  test(
    'store_changed reads the list again while an icon is not there',
    () async {
      final b = await _setup();
      var n = 0;
      final sub = b.server.changes.listen((_) => n++);
      addTearDown(sub.cancel);
      final srv = b.mock.system.server;
      await b.server.list();
      srv.setServiceIcon(
        srv.plex,
        '/home/tv/.cache/hinteros/icons/plex-media-server.png',
      );
      await pumpEventQueue();
      expect(n, 1);
      var l = await b.server.list();
      expect(
        l.byId('plex-media-server')!.iconPath,
        '/home/tv/.cache/hinteros/icons/plex-media-server.png',
      );
      srv.setServiceIcon(
        srv.cloudflare,
        '/home/tv/.cache/hinteros/icons/c.png',
      );
      await pumpEventQueue();
      expect(n, 2);
      l = await b.server.list();
      // Every icon is there: another Store change does not read the list.
      srv.setServiceIcon(
        srv.cloudflare,
        '/home/tv/.cache/hinteros/icons/c.png',
      );
      await pumpEventQueue();
      expect(n, 2);
    },
  );

  test('terms whose text cannot be read: it cannot be turned on', () async {
    final b = await _setup(readTerms: (_) => null);
    final p = (await b.server.list()).byId('plex-media-server')!;
    expect(p.terms, isNull);
    expect(p.termsMissing, isTrue);
  });

  test('enable: the admin PIN, then the terms, then the job', () async {
    final b = await _setup();
    final none = await _fails(b.server.enable('tailscale'));
    expect(none.kind, SystemErrorKind.pinRequired);
    expect(b.mock.system.log, isEmpty, reason: 'no PIN, no call');
    final wrong = await _fails(b.server.enable('tailscale', pin: '1111'));
    expect(wrong.kind, SystemErrorKind.pinRequired);
    expect(wrong.data['pin'], 'admin');
    final terms = await _fails(b.server.enable('plex-media-server', pin: _pin));
    expect(terms.kind, SystemErrorKind.termsRequired);
    expect(terms.data, {'id': 'plex-media-server', 'version': '2025-10-30'});
    final h = await b.server.enable(
      'plex-media-server',
      pin: _pin,
      acceptedTerms: {'plex-media-server': '2025-10-30'},
    );
    expect(h.kind, JobKind.servicesEnable);
    expect(b.mock.system.server.acceptances, ['plex-media-server=2025-10-30']);
    final changed = b.server.changes.first;
    b.mock.system.finishJob(h.jobId);
    await changed;
    final p = (await b.server.list()).byId('plex-media-server')!;
    expect(p.enabled, isTrue);
    expect(p.state, ServiceState.needsSetup);
    final on = await _fails(b.server.enable('jellyfin-server', pin: _pin));
    expect(on.kind, SystemErrorKind.nothingToDo);
  });

  test('disable sends delete_data with the revision', () async {
    final b = await _setup();
    final h = await b.server.disable(
      'jellyfin-server',
      pin: _pin,
      deleteData: true,
    );
    expect(h.kind, JobKind.servicesDisable);
    expect(
      b.mock.system.log.last,
      'services.disable:jellyfin-server:data=true',
    );
    final s = await b.jobs.watch(h.jobId).first;
    expect(s.subject.services, [
      (id: 'jellyfin-server', name: 'Jellyfin server'),
    ]);
    expect(s.subject.deleteData, isTrue);
  });

  test(
    'Tailscale: the sign-in address on the job, kept by heartbeats',
    () async {
      final b = await _setup();
      b.mock.system.server.tailscale.enabled = true;
      final h = await b.server.tailscaleLogin(pin: _pin);
      expect(h.kind, JobKind.tailscaleLogin);
      final seen = <JobSnapshot>[];
      final sub = b.jobs.watch(h.jobId).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      b.mock.system.progressJob(
        h.jobId,
        api.Stage.signingIn,
        authUrl: 'https://login.tailscale.com/a/1a2b3c4d5e6f',
      );
      await pumpEventQueue();
      expect(seen.last.stage, JobStage.signingIn);
      expect(seen.last.authUrl, 'https://login.tailscale.com/a/1a2b3c4d5e6f');
      expect(seen.last.canCancel, isTrue);
      // A progress without the address (a heartbeat) keeps it.
      b.mock.system.progressJob(h.jobId, api.Stage.signingIn);
      await pumpEventQueue();
      expect(seen.last.authUrl, 'https://login.tailscale.com/a/1a2b3c4d5e6f');
      b.mock.system.progressJob(h.jobId, api.Stage.finishing);
      await pumpEventQueue();
      expect(seen.last.authUrl, isNull);
      b.mock.system.finishJob(h.jobId);
      await pumpEventQueue();
      final t = (await b.server.list()).byId('tailscale')!;
      final d = t.detail! as TailscaleDetail;
      expect(d.state, TailscaleState.running);
      expect(d.ip4, '100.101.102.103');
      expect(d.keyExpiry, DateTime.fromMillisecondsSinceEpoch(1808042400000));
      final again = await _fails(b.server.tailscaleLogin(pin: _pin));
      expect(again.kind, SystemErrorKind.nothingToDo);
    },
  );

  test('a job that fails says why (job_failed.data.reason)', () async {
    final b = await _setup();
    b.mock.system.server.plex.enabled = true;
    final h = await b.server.claimPlex('claim-AbCdEfGhIjKlMnOpQrSt', pin: _pin);
    final done = b.jobs.finished(h.jobId);
    b.mock.system.finishJob(
      h.jobId,
      ok: false,
      error: const api.ErrorObject(
        code: api.ApiErrorCode.jobFailed,
        message: 'plex refused the claim',
        data: {'stage': 'configuring', 'log_hint': '', 'reason': 'refused'},
      ),
    );
    final s = await done;
    expect(s.failed, isTrue);
    expect(s.error!.message, 'The service did not accept it.');
    expect(s.error!.stage, JobStage.configuring);
  });

  test('refusals: off, not ready, a taken name, not a token', () async {
    final b = await _setup();
    b.mock.system.server.jellyfin.enabled = false;
    final off = await _fails(b.server.revealAccounts(pin: _pin));
    expect(off.kind, SystemErrorKind.unavailable);
    expect(off.message, 'Jellyfin is off.');
    b.mock.system.server.jellyfin
      ..enabled = true
      ..setupDone = false;
    final ready = await _fails(
      b.server.addLibrary(
        name: 'TV',
        kind: LibraryKind.shows,
        folder: 'TV',
        pin: _pin,
      ),
    );
    expect(ready.message, 'Jellyfin is not ready. Try again in a moment.');
    b.mock.system.server.jellyfin.setupDone = true;
    final taken = await _fails(
      b.server.addLibrary(
        name: 'movies',
        kind: LibraryKind.movies,
        folder: 'Movies',
        pin: _pin,
      ),
    );
    expect(taken.kind, SystemErrorKind.invalidParams);
    expect(taken.message, 'A library has this name.');
    b.mock.system.server.cloudflare.enabled = true;
    final token = await _fails(
      b.server.setCloudflareToken('eyJhIjoiYiJ9', pin: _pin),
    );
    expect(token.message, 'This is not a tunnel token.');
  });

  test('libraries: add with the kind and folder, remove by id', () async {
    final b = await _setup();
    final h = await b.server.addLibrary(
      name: 'Kids',
      kind: LibraryKind.mixed,
      folder: 'Movies/Kids',
      pin: _pin,
    );
    expect(h.kind, JobKind.libraryAdd);
    expect(
      b.mock.system.log.last,
      'jellyfin.libraries.add:Kids:mixed:Movies/Kids',
    );
    final s = await b.jobs.watch(h.jobId).first;
    expect(s.subject.library, 'Kids');
    b.mock.system.finishJob(h.jobId);
    await pumpEventQueue();
    final r = await b.server.removeLibrary(
      'f137a2dd21bbc1b99aa5c0f6bf02a805',
      pin: _pin,
    );
    expect(r.kind, JobKind.libraryRemove);
  });

  test('accounts: the admin and every profile, with passwords', () async {
    final b = await _setup();
    final a = await b.server.revealAccounts(pin: _pin);
    expect(a.admin!.name, 'admin');
    expect(a.admin!.password, 'k3v9q2m7x4p8w6t5');
    expect(a.users, isNotEmpty);
    expect(a.users.first.profileName, a.users.first.name);
    expect(b.mock.system.log, ['jellyfin.users.reveal']);
  });

  test('media.folders: one level at a time', () async {
    final b = await _setup();
    final top = await b.server.folders();
    expect(
      [for (final f in top) (f.id, f.hasChildren)],
      [('Movies', true), ('Music', false), ('Photos', true), ('TV', true)],
    );
    final movies = await b.server.folders('Movies');
    expect([for (final f in movies) f.id], ['Movies/Films', 'Movies/Kids']);
    final gone = await _fails(b.server.folders('Elsewhere'));
    expect(gone.kind, SystemErrorKind.notFound);
  });

  test('changes: a job of the section ends, the connection is back', () async {
    final b = await _setup();
    var n = 0;
    final sub = b.server.changes.listen((_) => n++);
    addTearDown(sub.cancel);
    final h = await b.server.disable('jellyfin-server', pin: _pin);
    b.mock.system.finishJob(h.jobId);
    await pumpEventQueue();
    expect(n, 1);
    // Another kind of job: nothing.
    unawaited(
      b.mock.rpc('system.rebuild', {}).then((r) {
        b.mock.system.finishJob(r['job_id'] as String);
      }),
    );
    await pumpEventQueue();
    expect(n, 1);
  });
}
