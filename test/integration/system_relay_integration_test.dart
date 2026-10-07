// The system.* relay against the real hinteros-session (session API 0.7).
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
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
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

  Future<DaemonClient> session(String systemSocket) async {
    final sock = '${dir.path}/run-session/session.sock';
    await start(_sessionBin!, [
      '--socket',
      sock,
      '--no-gamescope',
      '--no-inputplumber',
      '--no-uinput',
      '--no-runtime',
      '--system-socket',
      systemSocket,
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
        expect((c.status as Connected).apiVersion, '0.7');

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
  });

  group('a real hinteros-system (read-only methods)', () {
    Future<DaemonClient> withSystem() async {
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
      ]);
      await waitSocket(sock);
      return session(sock);
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
  });
}
