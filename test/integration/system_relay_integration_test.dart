// The system.* relay, the Store and the admin password calls against the real
// hinteros-session (session API 0.8).
//
// 1. No system service running: every system.* method is `system_unavailable`
//    {reason: down}, the session API keeps working, and the real repositories
//    show "settings unavailable". Needs HINTEROS_SESSION_BIN.
// 2. A real `hinteros-system` on a temporary root (fake /etc/hinteros, profile
//    links, release.json, an SSH host key): the read-only methods through the
//    relay and the real repositories. Needs HINTEROS_SYSTEM_BIN and
//    `ssh-keygen`. The mutating methods are not covered: the service checks
//    the caller against logind (seat0) and polkit on D-Bus, and the fakes for
//    those live in the daemon repo's Rust test helpers
//    (`crates/hinteros-system/tests/common`), so they cannot be reused from
//    here. That part (ssh.set -> authentication_required, jobs) is covered
//    against the mock daemon's relay instead.
// 3. The 0.8 Store: `store.list` over a real `hinteros-system` and the real
//    session daemon, both reading the fixture catalog
//    (`test/fixtures/catalog`, the real index format) : the daemon's merge of
//    the index with the installed apps, the terms paths, and the launcher's
//    `DaemonStore` reading them. `auth.respond` and `auth.cancel` with no
//    pending request are `not_found`. `session.restart` runs with logind
//    pointed at a bus that does not exist: it must never reach this machine's
//    real logind (a greetd session would be ended). NOT covered: the polkit
//    agent with a real polkit and PAM (`auth.respond` with a password, the
//    prompt end to end), `session.restart` ending a real greetd session, and
//    `system.apps.install` / `remove` on a real service (they need logind and
//    polkit like the other mutating methods); the daemon repo's VM tests
//    (`polkit-agent`, `session-restart`, `store-install`) are the ones for that.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' hide StoreState;
import 'package:hinteros_launcher/src/api/api.dart' as wire show StoreState;
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';

final _sessionBin = Platform.environment['HINTEROS_SESSION_BIN'];
final _systemBin = Platform.environment['HINTEROS_SYSTEM_BIN'];

String? _skipNoSession() =>
    _sessionBin == null ? 'HINTEROS_SESSION_BIN not set' : null;

bool _hasSshKeygen() {
  try {
    Process.runSync('ssh-keygen', ['-V']);
    return true;
  } on ProcessException {
    return false;
  }
}

String? _skipNoSystem() => _sessionBin == null
    ? 'HINTEROS_SESSION_BIN not set'
    : _systemBin == null
    ? 'HINTEROS_SYSTEM_BIN not set'
    : !_hasSshKeygen()
    ? 'ssh-keygen not found'
    : null;

/// The catalog fixture in the real index format (placeholder terms text).
final _catalogIndex = File('test/fixtures/catalog/catalog.json').absolute.path;

/// Flags that keep the daemon off this machine's buses: logind, the user's
/// systemd and polkit. `session.restart` must never reach a real greetd session.
List<String> _isolated(String root) => [
  '--runtime-bus',
  'unix:path=$root/no-bus',
  '--session-user-bus',
  'unix:path=$root/no-bus',
];

const _rev = '0f3c5a9e2b7d4c1a8e6f9b0d2c4e6a8b1d3f5a7c';

/// A fake root the real service can read: the layout of the daemon repo's
/// system test helpers (`Root::create`), without the fake `nix` scripts.
void _writeRoot(Directory root) {
  void write(String rel, String content) {
    final f = File('${root.path}/$rel')..createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  final lock =
      '{"nodes":{"hinteros":{"locked":{"rev":"$_rev","type":"git"},'
      '"original":{"ref":"stable","type":"git"}},"root":{"inputs":'
      '{"hinteros":"hinteros"}}},"root":"root","version":7}';
  const flake =
      '{\n  inputs.hinteros.url = "git+file:///nonexistent?ref=stable";\n'
      '  outputs = { hinteros, ... }: {};\n}\n';
  const state =
      '{\n  "schemaVersion": 1,\n  "base": "unstable",\n  "settings": '
      '{ "ssh": { "enable": false } },\n  "apps": ["steam"],\n  '
      '"profiles": [{ "id": "p1", "name": "Dev", "user": "hinteros" }]\n}\n';
  for (final base in ['etc/hinteros', 'store/gen1/hinteros']) {
    write('$base/flake.nix', flake);
    write('$base/flake.lock', lock);
    write('$base/state.json', state);
  }
  for (final d in ['var/lib/hinteros', 'run', 'profiles', 'policy/update']) {
    Directory('${root.path}/$d').createSync(recursive: true);
  }
  write('policy/release.json', '{"version":"0.1.0-test","dev":true}');
  write(
    'ssh/ssh_host_ed25519_key.pub',
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINraSens892Rb1jPRy00F9HKBgAjXCmwsXHmcTtlB7ep root@box\n',
  );
  Link('${root.path}/profiles/system-1-link')
      .createSync('${root.path}/store/gen1');
  Link('${root.path}/profiles/system').createSync('system-1-link');
  Link('${root.path}/current').createSync('${root.path}/store/gen1');
  Link('${root.path}/booted').createSync('${root.path}/store/gen1');
}

void main() {
  late Directory dir;
  final log = StringBuffer();
  final procs = <Process>[];
  DaemonClient? client;

  Future<void> waitSocket(String path) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      if (DateTime.now().isAfter(deadline)) fail('no socket $path: $log');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<Process> start(String bin, List<String> args) async {
    final p = await Process.start(bin, args);
    procs.add(p);
    for (final s in [p.stdout, p.stderr]) {
      s.transform(utf8.decoder).listen(log.write);
    }
    return p;
  }

  Future<DaemonClient> session(
    String systemSocket, {
    List<String> extra = const [],
  }) async {
    final sock = '${dir.path}/run-session/session.sock';
    await start(_sessionBin!, [
      '--socket',
      sock,
      '--no-gamescope',
      '--no-inputplumber',
      '--no-uinput',
      '--no-runtime',
      '--no-auth-agent',
      '--system-socket',
      systemSocket,
      ...extra,
    ]);
    await waitSocket(sock);
    return client = DaemonClient(socketPath: sock);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('system_it');
  });

  tearDown(() async {
    await client?.close();
    client = null;
    for (final p in procs) {
      p.kill(ProcessSignal.sigterm);
      await p.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          p.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    procs.clear();
    dir.deleteSync(recursive: true);
    log.clear();
  });

  group('no system service', () {
    test(
      'system.* is system_unavailable (down); the session API works',
      () async {
        final c = await session('${dir.path}/no-such-system.sock');
        await c.waitConnected();
        expect(c.status, isA<Connected>());
        expect((c.status as Connected).apiVersion, '0.10');

        final e = await c.systemInfo().then<ApiException?>(
          (_) => null,
          onError: (Object e) => e as ApiException,
        );
        expect(e, isNotNull);
        expect(e!.code, ApiErrorCode.systemUnavailable);
        expect(
          SystemUnavailableData.fromJson(
            (e.data! as Map).cast<String, dynamic>(),
          ).reason,
          SystemUnavailableDataReason.down,
        );
        // Mutating and job methods too.
        for (final f in [
          () => c.systemSshSet(const SystemSshSetParams(enabled: true)),
          () => c.systemUpdateCheck(),
          () => c.systemJobsList(),
        ]) {
          final err = await f().then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );
          expect(err?.code, ApiErrorCode.systemUnavailable);
        }
        // Unrelated methods are unaffected.
        expect((await c.ping(const PingParams(nonce: 'x'))).nonce, 'x');
        expect((await c.appsList()).apps, isNotNull);
      },
      skip: _skipNoSession(),
    );

    test('the real repositories say "settings unavailable"', () async {
      final c = await session('${dir.path}/no-such-system.sock');
      await c.waitConnected();
      final s = daemonSystemServices(c);
      Future<SystemException> fails(Future<Object?> f) async {
        try {
          await f;
        } on SystemException catch (e) {
          return e;
        }
        fail('expected a SystemException');
      }

      for (final f in <Future<Object?> Function()>[
        s.system.info,
        s.system.ssh,
        s.updates.check,
        s.updates.generations,
        () => s.system.setSsh(true),
      ]) {
        final e = await fails(f());
        expect(e.kind, SystemErrorKind.unavailable);
        expect(e.message, contains('Settings are unavailable'));
        expect(e.data['reason'], 'down');
      }
      // Unrelated: the job subscription (relayed) did not break the session.
      expect((await c.appsList()).apps, isNotNull);
    }, skip: _skipNoSession());

    test('store.list without the system service: system_unavailable', () async {
      final c = await session(
        '${dir.path}/no-such-system.sock',
        extra: ['--catalog-index', _catalogIndex],
      );
      await c.waitConnected();
      final e = await c.storeList().then<ApiException?>(
        (_) => null,
        onError: (Object e) => e as ApiException,
      );
      expect(e?.code, ApiErrorCode.systemUnavailable);
      final s = daemonSystemServices(c);
      expect(s.store.loaded, isFalse);
    }, skip: _skipNoSession());

    test('auth.respond and auth.cancel with no pending request are not_found', () async {
      final c = await session('${dir.path}/no-such-system.sock');
      await c.waitConnected();
      Future<ApiException?> err(Future<Object?> f) => f.then<ApiException?>(
        (_) => null,
        onError: (Object e) => e as ApiException,
      );
      final respond = await err(
        c.authRespond(const AuthRespondParams(cookie: 'nope-1', password: 'x')),
      );
      expect(respond?.code, ApiErrorCode.notFound);
      expect(respond?.message, contains('no authentication request'));
      final cancel = await err(
        c.authCancel(const AuthCancelParams(cookie: 'nope-1')),
      );
      expect(cancel?.code, ApiErrorCode.notFound);
      // The repository: cancelling what is over is not an error; answering is.
      final s = daemonSystemServices(c);
      await s.auth.cancel('nope-1');
      await expectLater(
        s.auth.respond('nope-1', 'x'),
        throwsA(
          isA<SystemException>().having(
            (e) => e.kind,
            'kind',
            SystemErrorKind.notFound,
          ),
        ),
      );
    }, skip: _skipNoSession());

    test(
      'a client that is not the launcher may not answer (not_authorized)',
      () async {
        await session('${dir.path}/no-such-system.sock');
        final other = DaemonClient(
          socketPath: '${dir.path}/run-session/session.sock',
          clientInfo: const Peer(name: 'someone-else', version: '0'),
        );
        addTearDown(other.close);
        await other.waitConnected();
        final e = await other
            .authCancel(const AuthCancelParams(cookie: 'x-1'))
            .then<ApiException?>(
              (_) => null,
              onError: (Object e) => e as ApiException,
            );
        expect(e?.code, ApiErrorCode.notAuthorized);
      },
      skip: _skipNoSession(),
    );

    test(
      'session.restart with logind out of reach is unavailable {logind}',
      () async {
        final c = await session(
          '${dir.path}/no-such-system.sock',
          extra: _isolated(dir.path),
        );
        await c.waitConnected();
        final e = await c.sessionRestart().then<ApiException?>(
          (_) => null,
          onError: (Object e) => e as ApiException,
        );
        expect(e?.code, ApiErrorCode.unavailable);
        expect((e!.data! as Map)['service'], 'logind');
        // The real repository: a plain refusal, the session still there.
        final s = daemonSystemServices(c);
        final r = await s.system.restartSession().then<SystemException?>(
          (_) => null,
          onError: (Object e) => e as SystemException,
        );
        expect(r?.kind, SystemErrorKind.unavailable);
        expect((await c.ping(const PingParams(nonce: 'alive'))).nonce, 'alive');
      },
      skip: _skipNoSession(),
    );
  });

  group('a real hinteros-system (read-only methods)', () {
    Future<DaemonClient> withSystem({bool catalog = false}) async {
      final root = Directory('${dir.path}/root')..createSync();
      _writeRoot(root);
      final r = root.path;
      final sock = '$r/run/system.sock';
      await start(_systemBin!, [
        '--socket', sock,
        '--config-dir', '$r/etc/hinteros',
        '--state-dir', '$r/var/lib/hinteros',
        '--run-dir', '$r/run',
        '--profile', '$r/profiles/system',
        '--current-system', '$r/current',
        '--booted-system', '$r/booted',
        '--policy-dir', '$r/policy',
        '--ssh-host-key-dir', '$r/ssh',
        // Mutating methods would need logind and polkit on this bus.
        '--bus', 'unix:path=$r/no-bus',
        '--journal-socket', '$r/journal.sock',
        if (catalog) ...['--catalog-index', _catalogIndex],
      ]);
      await waitSocket(sock);
      return session(
        sock,
        extra: [
          if (catalog) ...['--catalog-index', _catalogIndex],
          ..._isolated(r),
        ],
      );
    }

    test(
      'system.info, settings.get and generations.list through the relay',
      () async {
        final c = await withSystem();
        await c.waitConnected();
        final i = await c.systemInfo();
        expect(i.version, '0.1.0-test');
        expect(i.dev, isTrue);
        expect(i.channel, Channel.stable);
        expect(i.base, Base.unstable);
        expect(i.rev, _rev);
        expect(i.generation, 1);
        expect(i.ssh.enabled, isFalse);
        expect(i.ssh.hostKeyFingerprints, hasLength(1));
        expect(i.ssh.hostKeyFingerprints.single, startsWith('SHA256:'));

        final g = await c.systemSettingsGet();
        expect(g.revision, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(g.settings.ssh.enabled, isFalse);

        final gens = (await c.systemGenerationsList()).generations;
        expect(gens.single.generation, 1);
        expect(gens.single.current, isTrue);
        expect(gens.single.booted, isTrue);
        expect(gens.single.rev, _rev);
      },
      skip: _skipNoSystem(),
    );

    test('the real repositories map it', () async {
      final c = await withSystem();
      await c.waitConnected();
      final s = daemonSystemServices(c);
      final info = await s.system.info();
      expect(info.version, '0.1.0-test');
      expect(info.dev, isTrue);
      expect(info.channel, UpdateChannel.stable);
      expect(info.base, NixBase.unstable);
      expect(info.generation, 1);
      expect(info.hostKeyFingerprints.single, startsWith('SHA256:'));
      expect((await s.system.ssh()).enabled, isFalse);
      final gens = await s.updates.generations();
      expect(gens.single.current, isTrue);
      expect(gens.single.rev, _rev);
      // jobs.list through the relay: nothing has run.
      expect((await c.systemJobsList()).jobs, isEmpty);
    }, skip: _skipNoSystem());

    test('an unknown job is not_found through the real service', () async {
      final c = await withSystem();
      await c.waitConnected();
      final s = daemonSystemServices(c);
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
    }, skip: _skipNoSystem());

    test('store.list: the index merged with the installed apps', () async {
      final c = await withSystem(catalog: true);
      await c.waitConnected();
      expect((c.status as Connected).apiVersion, '0.10');
      // state.json of the fake root lists steam as installed.
      expect((await c.systemSettingsGet()).settings.apps, ['steam']);
      final l = await c.storeList();
      expect(l.indexVersion, 2);
      expect(l.moreAfterUpdate, isFalse);
      final names = l.apps.map((a) => a.name).toList();
      expect(
        names,
        [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
        reason: 'by name',
      );
      expect(l.apps.map((a) => a.id), contains('moonlight'));
      final steam = l.apps.firstWhere((a) => a.id == 'steam');
      expect(steam.state, wire.StoreState.installed);
      expect(l.apps.where((a) => a.id != 'steam').map((a) => a.state).toSet(), {
        wire.StoreState.available,
      });
      // The terms: the version, and the absolute path of the text.
      expect(steam.terms!.version, '2026-09-10');
      expect(steam.terms!.file, startsWith('/'));
      expect(steam.terms!.file, endsWith('terms/steam-2026-09-10.txt'));
      expect(
        File(steam.terms!.file).readAsStringSync(),
        contains('PLACEHOLDER TERMS'),
      );
      expect(l.apps.firstWhere((a) => a.id == 'youtube').kind, AppKind.web);
    }, skip: _skipNoSystem());

    test('the real DaemonStore reads it, terms text included', () async {
      final c = await withSystem(catalog: true);
      await c.waitConnected();
      final store = daemonSystemServices(c).store;
      final apps = await store.catalog();
      expect(store.loaded, isTrue);
      expect(store.installed, {'steam'});
      expect(store.moreAfterUpdate, isFalse);
      final steam = apps.firstWhere((a) => a.id == 'steam');
      expect(steam.terms!.text, contains('PLACEHOLDER TERMS'));
      expect(steam.removeDataWarning, contains('Games this profile installed'));
      final plex = apps.firstWhere((a) => a.id == 'plex-htpc');
      expect(plex.terms!.version, '2025-10-30');
      expect(plex.free, isFalse);
      expect(store.stateOf('plex-htpc'), StoreState.available);
    }, skip: _skipNoSystem());

    test(
      'without the catalog index store.list is unavailable {catalog}',
      () async {
        final c = await withSystem();
        await c.waitConnected();
        final e = await c.storeList().then<ApiException?>(
          (_) => null,
          onError: (Object e) => e as ApiException,
        );
        expect(e?.code, ApiErrorCode.unavailable);
        expect((e!.data! as Map)['service'], 'catalog');
        final s = daemonSystemServices(c);
        expect(
          (await s.store.catalog().then<SystemException?>(
            (_) => null,
            onError: (Object e) => e as SystemException,
          ))?.kind,
          SystemErrorKind.unavailable,
        );
      },
      skip: _skipNoSystem(),
    );
  });
}
