// The real StorageRepository over the mock daemon's relay (session API
// 0.14): the measurement and tree mapping, who may read which tree, the
// clean-up and cleanup.set jobs and their results.
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_storage.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/repositories.dart';

/// The mock box's admin PIN (James).
const _pin = '2468';

Future<(api.MockDaemon, SystemServices)> _setup() async {
  final mock = api.MockDaemon(now: () => DateTime(2026, 10, 6, 12));
  await mock.waitConnected();
  final services = daemonSystemServices(mock);
  addTearDown(mock.close);
  return (mock, services);
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
  test('no measurement yet, then measure: a job with progress', () async {
    final (mock, s) = await _setup();
    expect(await s.storage.get(), isNull);
    final h = await s.storage.measure();
    expect(h.kind, JobKind.storageMeasure);
    // A second measure while one runs: the same job.
    expect((await s.storage.measure()).jobId, h.jobId);
    final seen = <JobSnapshot>[];
    final sub = s.jobs.watch(h.jobId).listen(seen.add);
    mock.system.progressJob(h.jobId, api.Stage.measuring, percent: 40);
    await pumpEventQueue();
    expect(seen.last.stage, JobStage.measuring);
    expect(seen.last.percent, 40);
    expect(seen.last.canCancel, isTrue);
    mock.system.finishJob(h.jobId);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.last.ok, isTrue);
    expect(seen.last.result?['measured_at'], isA<int>());
    final m = (await s.storage.get())!;
    expect(m.measuredAt, DateTime(2026, 10, 6, 12));
    expect(m.disk.totalBytes, 512000000000);
    expect(m.disk.usedBytes, 21000000000);
    expect(m.disk.freeBytes, 491000000000);
    expect(m.garbageBytes, 1200000000);
    expect(
      [for (final c in m.root.children) c.kind],
      [
        StorageKind.system,
        StorageKind.apps,
        StorageKind.profile,
        StorageKind.profile,
        StorageKind.guest,
        StorageKind.other,
        StorageKind.free,
      ],
    );
    final gen = m.root.children.first.children.first;
    expect(gen.kind, StorageKind.generation);
    expect(gen.generation, 42);
    expect(gen.current, isTrue);
    expect(gen.booted, isFalse);
    expect(gen.date, DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000));
    final apps = m.root.children[1];
    expect(apps.children.first.kind, StorageKind.appEnv);
    expect(apps.children.first.id, 'p1');
    expect(apps.children.last.kind, StorageKind.shared);
    final home = m.root.children[2];
    expect(home.id, 'p1');
    expect(home.isHome, isTrue);
    expect(home.canOpen, isTrue);
    expect(home.children, isEmpty);
    expect(m.root.children[4].homeId, 'guest');
    expect(m.estimate(CleanupTarget.system, 1)!.generations, 2);
    expect(m.estimate(CleanupTarget.system, 1)!.bytes, 2400000000);
    expect(m.estimate(CleanupTarget.profiles, 1)!.bytes, 1500000000);
    expect(m.systemEstimates, hasLength(10));
  });

  test('a cancelled measurement keeps the old one', () async {
    final (mock, s) = await _setup();
    mock.system.measurement = api.mockWireMeasurement(1791000000);
    final h = await s.storage.measure();
    mock.system.progressJob(h.jobId, api.Stage.measuring, percent: 5);
    await s.jobs.cancel(h.jobId);
    final m = (await s.storage.get())!;
    expect(m.measuredAt.millisecondsSinceEpoch, 1791000000 * 1000);
  });

  group('trees', () {
    test('the own home: no PIN; names and Steam games', () async {
      final (mock, s) = await _setup();
      mock.system.measurement = api.mockWireMeasurement();
      final t = await s.storage.tree('p1');
      expect(t.id, 'p1');
      expect(t.root.kind, StorageKind.profile);
      expect(t.root.bytes, 3000000000);
      final steam = t.root.children.first;
      expect(steam.kind, StorageKind.steam);
      expect(steam.children.single.kind, StorageKind.steamGame);
      expect(steam.children.single.name, 'Portal 2');
      expect(steam.children.single.appId, 620);
      expect(t.root.children[1].kind, StorageKind.dir);
      expect(t.root.children[1].name, '.local');
      expect(t.root.children[2].kind, StorageKind.files);
    });

    test('another home: the admin PIN', () async {
      final (mock, s) = await _setup();
      mock.system.measurement = api.mockWireMeasurement();
      final e = await _fails(s.storage.tree('p3'));
      expect(e.kind, SystemErrorKind.pinRequired);
      expect(e.data['pin'], 'admin');
      final wrong = await _fails(s.storage.tree('p3', adminPin: '1111'));
      expect(wrong.kind, SystemErrorKind.pinRequired);
      final t = await s.storage.tree('p3', adminPin: _pin);
      expect(t.root.children.first.name, 'Music');
      expect(
        (await s.storage.tree('guest', adminPin: _pin)).root.kind,
        StorageKind.guest,
      );
    });

    test('not measured: not found', () async {
      final (_, s) = await _setup();
      final e = await _fails(s.storage.tree('p1'));
      expect(e.kind, SystemErrorKind.notFound);
    });

    test('a long name is cut to 128 characters, one line', () {
      final n = storageNode(
        api.StorageNode(
          kind: api.NodeKind.dir,
          bytes: -5,
          children: const [],
          name: 'a\nb${'x' * 200}',
        ),
      );
      expect(n.bytes, 0);
      expect(n.name!.length, 128);
      expect(n.name, startsWith('a b'));
      expect(storageKind(api.NodeKind.unknown), StorageKind.unknown);
    });
  });

  group('clean-up', () {
    test('the system: the admin PIN, a job, what it freed', () async {
      final (mock, s) = await _setup();
      final e = await _fails(s.storage.cleanup(CleanupTarget.system, 2));
      expect(e.kind, SystemErrorKind.pinRequired);
      final h = await s.storage.cleanup(
        CleanupTarget.system,
        2,
        adminPin: _pin,
      );
      expect(h.kind, JobKind.cleanupSystem);
      expect(mock.system.log, contains('cleanup_system:2'));
      final seen = <JobSnapshot>[];
      final sub = s.jobs.watch(h.jobId).listen(seen.add);
      mock.system.progressJob(h.jobId, api.Stage.cleaning);
      await pumpEventQueue();
      expect(seen.last.stage, JobStage.cleaning);
      expect(seen.last.canCancel, isFalse);
      mock.system.progressJob(h.jobId, api.Stage.collecting);
      mock.system.finishJob(h.jobId);
      await pumpEventQueue();
      await sub.cancel();
      final freed = cleanupFreed(seen.last)!;
      expect(freed.freedBytes, 3000000000);
      expect(freed.generationsRemoved, 4);
    });

    test('profiles: its own job kind', () async {
      final (mock, s) = await _setup();
      final h = await s.storage.cleanup(
        CleanupTarget.profiles,
        7,
        adminPin: _pin,
      );
      expect(h.kind, JobKind.cleanupProfiles);
      expect(mock.system.log, contains('cleanup_profiles:7'));
    });

    test('another job runs: busy', () async {
      final (mock, s) = await _setup();
      await s.storage.measure();
      final e = await _fails(
        s.storage.cleanup(CleanupTarget.system, 3, adminPin: _pin),
      );
      expect(e.kind, SystemErrorKind.jobBusy);
    });
  });

  group('automatic clean-up', () {
    test('defaults, then set: a rebuild job with the admin PIN', () async {
      final (mock, s) = await _setup();
      expect(await s.storage.cleanupSettings(), const CleanupSettings());
      const want = CleanupSettings(
        enable: true,
        frequency: CleanupFrequency.daily,
        keepSystem: 3,
        keepProfiles: 2,
      );
      final e = await _fails(s.storage.setCleanupSettings(want));
      expect(e.kind, SystemErrorKind.pinRequired);
      final h = await s.storage.setCleanupSettings(want, adminPin: _pin);
      expect(h.kind, JobKind.cleanupSet);
      mock.system.finishJob(h.jobId);
      expect(await s.storage.cleanupSettings(), want);
      expect(mock.system.cleanup.frequency, api.CleanupFrequency.daily);
    });

    test('nothing to change', () async {
      final (_, s) = await _setup();
      final e = await _fails(
        s.storage.setCleanupSettings(const CleanupSettings(), adminPin: _pin),
      );
      expect(e.kind, SystemErrorKind.nothingToDo);
    });
  });

  test('a job of a kind from the storage API maps to its own kind', () async {
    final (mock, s) = await _setup();
    final id = mock.system.startJob(api.JobKind.cleanupSet);
    final snap = await s.jobs.watch(id).first;
    expect(snap.kind, JobKind.cleanupSet);
  });
}
