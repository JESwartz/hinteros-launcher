import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/plan.dart';
import 'package:hinteros_launcher/src/installer/process_backend.dart';
import 'package:hinteros_launcher/src/installer/progress.dart';

import '../support/harness.dart' show tempDir;
import '../support/installer_fixtures.dart' show catalogFixtureDir;

/// The real backend class against a stand-in for `hinteros-install`: a shell
/// script in a temp directory that records how it was called. The real
/// installer is never run.
void main() {
  const plan = InstallPlan(
    disk: '/dev/nvme0n1',
    diskSeq: 1,
    hostname: 'hinteros',
    adminUser: 'james',
    adminPassword: 'pa55 w0rd; rm -rf / \$(x)',
    apps: ['youtube'],
  );

  late Directory dir;
  late String script;

  void write(String body) {
    File(script)
      ..writeAsStringSync('#!/bin/sh\nOUT="${dir.path}"\n$body')
      ..createSync();
    Process.runSync('chmod', ['+x', script]);
  }

  setUp(() {
    dir = tempDir();
    script = '${dir.path}/hinteros-install';
  });

  test('the plan goes in on stdin, never in the arguments', () async {
    write(r'''
printf '%s\n' "$@" > "$OUT/argv"
cat > "$OUT/stdin"
echo '{"stage":"validate","percent":0,"level":"info","message":"Checking the plan"}'
echo 'tool noise that is not json'
echo '{"stage":"done","percent":100,"level":"info","message":"fine"}'
''');
    final backend = ProcessInstallerBackend(installBinary: script);
    final o = await followRun(backend.validate(plan));
    expect(o.verdict, InstallVerdict.success);

    final argv = File('${dir.path}/argv').readAsLinesSync();
    expect(argv, ['--plan', '-', '--validate-only']);
    expect(argv.join(' '), isNot(contains('pa55')));
    final stdin = File('${dir.path}/stdin').readAsStringSync();
    expect(jsonDecode(stdin), plan.toJson());
    expect((jsonDecode(stdin) as Map)['admin'], {
      'user': 'james',
      'password': plan.adminPassword,
    }, reason: 'special characters survive untouched (no shell is involved)');
  });

  test(
    'install: same call without --validate-only; exit 1 is a failure',
    () async {
      write(r'''
printf '%s\n' "$@" > "$OUT/argv"
cat > /dev/null
echo '{"stage":"install","percent":57,"level":"error","message":"boom","code":"install-failed"}'
echo "stderr output stays out of the way" >&2
exit 1
''');
      final backend = ProcessInstallerBackend(installBinary: script);
      final o = await followRun(backend.install(plan));
      expect(File('${dir.path}/argv').readAsLinesSync(), ['--plan', '-']);
      expect(o.verdict, InstallVerdict.failed);
      expect(o.error!.code, 'install-failed');
    },
  );

  test('exit 2 is a refusal', () async {
    write(r'''
cat > /dev/null
echo '{"stage":"validate","percent":0,"level":"error","message":"in use","code":"disk-in-use"}'
exit 2
''');
    final o = await followRun(
      ProcessInstallerBackend(installBinary: script).install(plan),
    );
    expect(o.verdict, InstallVerdict.refused);
    expect(o.error!.code, 'disk-in-use');
  });

  test('a missing binary is reported as an error line, not a crash', () async {
    final o = await followRun(
      ProcessInstallerBackend(installBinary: '${dir.path}/does-not-exist')
          .validate(plan),
    );
    expect(o.verdict, InstallVerdict.failed);
    expect(o.error!.code, 'internal');
  });

  test('without a catalog index the fallback is offered', () async {
    final apps = await ProcessInstallerBackend(
      catalogPath: '${dir.path}/none.json',
    ).catalog();
    expect(
      [for (final a in apps) a.id],
      ['jellyfin-desktop', 'youtube', 'firefox'],
    );
  });

  test('a catalog index on the ISO is read, with its terms', () async {
    final terms = Directory('${dir.path}/terms')..createSync();
    for (final f in Directory('$catalogFixtureDir/terms').listSync()) {
      File('${terms.path}/${f.uri.pathSegments.last}')
          .writeAsStringSync(File(f.path).readAsStringSync());
    }
    File('${dir.path}/catalog.json').writeAsStringSync(
      File('$catalogFixtureDir/catalog.json').readAsStringSync(),
    );
    ProcessInstallerBackend backend() =>
        ProcessInstallerBackend(catalogPath: '${dir.path}/catalog.json');
    final apps = await backend().catalog();
    expect(apps.every((a) => a.installer), isTrue);
    expect(
      apps.firstWhere((a) => a.id == 'steam').terms!.text,
      startsWith('PLACEHOLDER TERMS FOR STEAM'),
    );
    // Without the terms files the unfree apps are not offered.
    terms.deleteSync(recursive: true);
    final ids = [for (final a in await backend().catalog()) a.id];
    expect(ids, isNot(contains('steam')));
    expect(ids, isNot(contains('plex-htpc')));
    expect(ids, contains('firefox'));
    // An index of another version falls back instead of failing.
    File('${dir.path}/catalog.json').writeAsStringSync('{"indexVersion":9}');
    expect((await backend().catalog()).length, 3);
  });

  group('the disks', () {
    const answer =
        '{"blockdevices":[{"name":"vdc","path":"/dev/vdc","size":34359738368,'
        '"type":"disk","rm":false,"mountpoints":[null],"disk-seq":3,'
        '"existing":{"profiles":1,"schemaOk":true,"version":"0.7.0"}}]}';
    const plain =
        '{"blockdevices":[{"name":"vdc","path":"/dev/vdc","size":34359738368,'
        '"type":"disk","rm":false,"mountpoints":[null],"disk-seq":3}]}';
    late String lsblk;

    /// A stand-in for lsblk that records its arguments.
    setUp(() {
      lsblk = '${dir.path}/lsblk';
      File(lsblk).writeAsStringSync(
        '#!/bin/sh\nprintf \'%s\\n\' "\$@" > "${dir.path}/lsblk-argv"\n'
        "echo '$plain'\n",
      );
      Process.runSync('chmod', ['+x', lsblk]);
    });

    ProcessInstallerBackend backend({
      Duration timeout = const Duration(seconds: 20),
    }) => ProcessInstallerBackend(
      installBinary: script,
      lsblkBinary: lsblk,
      listDisksTimeout: timeout,
    );

    bool usedLsblk() => File('${dir.path}/lsblk-argv').existsSync();

    test('hinteros-install --list-disks says what is on them', () async {
      write('''
printf '%s\\n' "\$@" > "\$OUT/argv"
echo "tool noise" >&2
echo '$answer'
''');
      final d = (await backend().disks()).single;
      expect(File('${dir.path}/argv').readAsLinesSync(), ['--list-disks']);
      expect(d.existing!.schemaOk, isTrue);
      expect(d.existing!.version, '0.7.0');
      expect(usedLsblk(), isFalse);
    });

    test('it fails: plain lsblk', () async {
      write('echo usage >&2\nexit 2\n');
      final d = (await backend().disks()).single;
      expect(d.path, '/dev/vdc');
      expect(d.existing, isNull);
      expect(File('${dir.path}/lsblk-argv').readAsLinesSync().length, 4);
    });

    test('its answer cannot be read: plain lsblk', () async {
      write('echo not json\n');
      expect((await backend().disks()).single.existing, isNull);
      expect(usedLsblk(), isTrue);
    });

    test('it is not there: plain lsblk', () async {
      final d = await ProcessInstallerBackend(
        installBinary: '${dir.path}/does-not-exist',
        lsblkBinary: lsblk,
      ).disks();
      expect(d.single.existing, isNull);
    });

    test('a hung disk: it is stopped, and plain lsblk answers', () async {
      write(r'''
echo $$ > "$OUT/pid"
exec sleep 300
''');
      final d = await backend(timeout: const Duration(milliseconds: 500))
          .disks();
      expect(d.single.existing, isNull);
      expect(usedLsblk(), isTrue);
      final pid = File('${dir.path}/pid').readAsStringSync().trim();
      for (var i = 0; i < 100 && Directory('/proc/$pid').existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(Directory('/proc/$pid').existsSync(), isFalse);
    });

    test('neither answers: the error of lsblk', () async {
      write('exit 1\n');
      await expectLater(
        ProcessInstallerBackend(
          installBinary: script,
          lsblkBinary: '${dir.path}/does-not-exist',
        ).disks(),
        throwsA(isA<InstallerException>()),
      );
    });
  });

  group('--check-newer', () {
    const iso = '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d';
    const tip = '9f8e7d6c5b4a39281706f5e4d3c2b1a098765432';

    test('a newer release: the channel is passed, the JSON read', () async {
      write('''
printf '%s\\n' "\$@" > "\$OUT/argv"
echo "human text on stderr" >&2
echo '{"channel":"beta","iso":{"rev":"$iso","version":"0.7.0"},"newer":{"rev":"$tip","version":"0.7.0","date":1767225600,"signer":"release"}}'
''');
      final r = await ProcessInstallerBackend(installBinary: script)
          .checkNewer(channel: InstallChannel.beta);
      expect(File('${dir.path}/argv').readAsLinesSync(), [
        '--check-newer',
        '--channel',
        'beta',
      ]);
      expect(r.channel, InstallChannel.beta);
      expect(r.iso.rev, iso);
      expect(r.iso.version, '0.7.0');
      expect(r.newer!.rev, tip);
      expect(r.newer!.version, '0.7.0', reason: 'equal versions on beta');
    });

    test('nothing newer; no channel: the installer default', () async {
      write('''
printf '%s\\n' "\$@" > "\$OUT/argv"
echo '{"channel":"stable","iso":{"rev":"$iso","version":"0.7.0"},"newer":null}'
''');
      final r = await ProcessInstallerBackend(installBinary: script)
          .checkNewer();
      expect(File('${dir.path}/argv').readAsLinesSync(), ['--check-newer']);
      expect(r.channel, InstallChannel.stable);
      expect(r.newer, isNull);
    });

    test('a failed check throws with the backend code and message', () async {
      write(r'''
echo '{"phase":"check","stage":"check","percent":0,"level":"error","code":"unsigned","message":"the tip is not signed"}'
exit 1
''');
      await expectLater(
        ProcessInstallerBackend(installBinary: script).checkNewer(),
        throwsA(
          isA<InstallerException>()
              .having((e) => e.code, 'code', 'unsigned')
              .having((e) => e.message, 'message', 'the tip is not signed'),
        ),
      );
    });

    test('an answer it cannot read, or no binary, throws too', () async {
      write("echo '{\"channel\":\"stable\"}'\n");
      await expectLater(
        ProcessInstallerBackend(installBinary: script).checkNewer(),
        throwsA(isA<InstallerException>()),
      );
      await expectLater(
        ProcessInstallerBackend(installBinary: '${dir.path}/does-not-exist')
            .checkNewer(),
        throwsA(
          isA<InstallerException>().having((e) => e.code, 'code', 'internal'),
        ),
      );
    });
  });

  group('--info', () {
    const iso = '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d';

    test('the installer version and channel, from one JSON line', () async {
      write('''
printf '%s\\n' "\$@" > "\$OUT/argv"
echo '{"iso":{"rev":"$iso","version":"0.7.0"},"channel":"beta"}'
''');
      final r = await ProcessInstallerBackend(installBinary: script).info();
      expect(File('${dir.path}/argv').readAsLinesSync(), ['--info']);
      expect(r.channel, InstallChannel.beta);
      expect(r.iso.rev, iso);
      expect(r.iso.version, '0.7.0');
    });

    test(
      'an older installer without --info, or a bad answer, throws',
      () async {
        write('echo usage >&2\nexit 2\n');
        await expectLater(
          ProcessInstallerBackend(installBinary: script).info(),
          throwsA(isA<InstallerException>()),
        );
        write("echo '{\"channel\":\"stable\"}'\n");
        await expectLater(
          ProcessInstallerBackend(installBinary: script).info(),
          throwsA(
            isA<InstallerException>().having((e) => e.code, 'code', 'internal'),
          ),
        );
      },
    );
  });
}
