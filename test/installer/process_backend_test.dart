import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/plan.dart';
import 'package:hinteros_launcher/src/installer/process_backend.dart';
import 'package:hinteros_launcher/src/installer/progress.dart';

import '../support/harness.dart' show tempDir;

/// The real backend class against a stand-in for `hinteros-install`: a shell
/// script in a temp directory that records how it was called. The real
/// installer is never run.
void main() {
  const plan = InstallPlan(
    disk: '/dev/nvme0n1',
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
      ['jellyfin', 'youtube', 'crunchyroll', 'firefox'],
    );
  });

  test('a catalog index on the ISO is read', () async {
    File('${dir.path}/catalog.json').writeAsStringSync(
      '{"indexVersion":1,"apps":[{"id":"firefox","name":"Firefox",'
      '"status":"available","sizeMiB":90}]}',
    );
    final apps = await ProcessInstallerBackend(
      catalogPath: '${dir.path}/catalog.json',
    ).catalog();
    expect(apps.single.id, 'firefox');
    // An index of another version falls back instead of failing.
    File('${dir.path}/catalog.json').writeAsStringSync('{"indexVersion":9}');
    expect(
      (await ProcessInstallerBackend(
        catalogPath: '${dir.path}/catalog.json',
      ).catalog()).length,
      4,
    );
  });
}
