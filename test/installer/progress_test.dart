import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/progress.dart';

InstallRun run(List<String> lines, int exit) => InstallRun(
  Stream.fromIterable(lines)
      .map(parseProgressLine)
      .where((e) => e != null)
      .cast<InstallEvent>(),
  Future.value(exit),
);

void main() {
  group('progress lines', () {
    test('a normal line', () {
      final e = parseProgressLine(
        '{"stage":"install","percent":57,"level":"info","message":"Installing: 5 of 9 steps"}',
      )!;
      expect(e.stage, 'install');
      expect(e.percent, 57);
      expect(e.level, InstallLevel.info);
      expect(e.message, 'Installing: 5 of 9 steps');
      expect(e.code, isNull);
    });

    test('per-step and per-app progress', () {
      final e = parseProgressLine(
        '{"phase":"apps","stage":"apps","percent":80,"level":"info",'
        '"message":"m","step_percent":42,"app":"steam",'
        '"app_index":2,"app_total":3}',
      )!;
      expect(e.stepPercent, 42);
      expect(e.app, 'steam');
      expect(e.appIndex, 2);
      expect(e.appTotal, 3);
      final old = parseProgressLine(
        '{"stage":"install","percent":57,"level":"info","message":"m"}',
      )!;
      expect(old.stepPercent, isNull, reason: 'unmeasurable: indeterminate');
      expect(old.appIndex, isNull);
      final odd = parseProgressLine(
        '{"stage":"install","percent":5,"level":"info","message":"m",'
        '"step_percent":140,"app_index":0}',
      )!;
      expect(odd.stepPercent, 100);
      expect(odd.appIndex, isNull);
    });

    test('an error line has a code', () {
      final e = parseProgressLine(
        '{"stage":"validate","percent":0,"level":"error","message":"x","code":"disk-too-small"}',
      )!;
      expect(e.isError, isTrue);
      expect(e.code, 'disk-too-small');
    });

    test('warnings, odd percents, unknown levels', () {
      expect(
        parseProgressLine(
          '{"stage":"facter","percent":26,"level":"warn","message":"m","code":"facter-failed"}',
        )!.isWarning,
        isTrue,
      );
      expect(
        parseProgressLine('{"stage":"a","percent":250,"message":"m"}')!.percent,
        100,
      );
      expect(
        parseProgressLine('{"stage":"a","percent":-4,"message":"m"}')!.percent,
        0,
      );
      expect(
        parseProgressLine('{"stage":"a","percent":12.6,"message":"m"}')!
            .percent,
        13,
      );
      expect(
        parseProgressLine(
          '{"stage":"a","percent":1,"level":"loud","message":"m"}',
        )!.level,
        InstallLevel.info,
      );
    });

    test('anything else is ignored', () {
      for (final l in [
        '',
        '   ',
        'nixos-install: copying path',
        '{not json',
        '[1,2]',
        '{"stage":"x"}',
        '{"message":"x"}',
        '{"stage":3,"message":"x"}',
      ]) {
        expect(parseProgressLine(l), isNull, reason: l);
      }
    });

    test('bytes split anywhere still make lines', () async {
      const text =
          '{"stage":"a","percent":1,"level":"info","message":"one"}\n'
          'junk\n'
          '{"stage":"b","percent":2,"level":"info","message":"two ünï"}\n';
      final bytes = utf8.encode(text);
      // Split in the middle of a line (ASCII keeps the test simple).
      final events = await progressEvents(
        Stream.fromIterable([bytes.sublist(0, 20), bytes.sublist(20)]),
      ).toList();
      expect([for (final e in events) e.stage], ['a', 'b']);
    });
  });

  group('outcome and exit status', () {
    const done =
        '{"stage":"done","percent":100,"level":"info","message":"fine"}';
    const err2 =
        '{"stage":"validate","percent":0,"level":"error","message":"in use","code":"disk-in-use"}';
    const err1 =
        '{"stage":"install","percent":57,"level":"error","message":"boom","code":"install-failed"}';
    const warn =
        '{"stage":"facter","percent":26,"level":"warn","message":"w","code":"facter-failed"}';

    test('exit 0 with a done line is success, warnings are kept', () async {
      final o = await followRun(run([warn, done], 0));
      expect(o.verdict, InstallVerdict.success);
      expect(o.warnings.single.code, 'facter-failed');
      expect(o.error, isNull);
    });

    test('exit 2 is refused (nothing touched)', () async {
      final o = await followRun(run([err2], 2));
      expect(o.verdict, InstallVerdict.refused);
      expect(o.exitCode, 2);
      expect(o.error!.code, 'disk-in-use');
    });

    test('exit 1 is failed part-way', () async {
      final o = await followRun(run([err1], 1));
      expect(o.verdict, InstallVerdict.failed);
      expect(o.exitCode, 1);
      expect(o.error!.code, 'install-failed');
      expect(o.error!.percent, 57);
    });

    test(
      'exit 0 with an error line, or without done, is not success',
      () async {
        expect(
          (await followRun(run([err1], 0))).verdict,
          InstallVerdict.failed,
        );
        final o = await followRun(run([warn], 0));
        expect(o.verdict, InstallVerdict.failed);
        expect(o.error!.code, 'internal');
      },
    );

    test('a crash without an error line gets one', () async {
      final o = await followRun(run([], 137));
      expect(o.verdict, InstallVerdict.failed);
      expect(o.error!.code, 'internal');
      expect(o.error!.message, contains('137'));
      final o2 = await followRun(run([], 2));
      expect(o2.verdict, InstallVerdict.refused);
    });

    test('events are passed on as they come', () async {
      final seen = <int>[];
      await followRun(
        run([warn, done], 0),
        onEvent: (e) => seen.add(e.percent),
      );
      expect(seen, [26, 100]);
    });
  });

  group('plain words', () {
    test('every stage has a label', () {
      for (final s in installStages) {
        expect(stageLabel(s), isNot('Working'), reason: s);
      }
      expect(stageLabel('mystery'), 'Working');
    });

    test('the backend codes are explained', () {
      const codes = [
        'not-root',
        'disk-not-found',
        'disk-in-use',
        'disk-too-small',
        'not-uefi',
        'app-needs-network',
        'no-network',
        'hostname-invalid',
        'admin-password-missing',
        'admin-user-reserved',
        'install-failed',
        'copy-failed',
        'mount-failed',
        'internal',
        'facter-failed',
        'unmount-failed',
        'wifi-failed',
      ];
      final generic = explainCode('unheard-of');
      for (final c in codes) {
        expect(explainCode(c), isNot(generic), reason: c);
      }
      expect(explainCode(null), generic);
    });
  });
}
