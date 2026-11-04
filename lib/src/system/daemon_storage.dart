/// [StorageRepository] over the session daemon's relayed `system.storage.*`
/// and `system.cleanup.*` methods (session API 0.14, system API 0.6).
library;

import '../api/api.dart' as api;
import 'daemon_errors.dart';
import 'daemon_system.dart' show DaemonJobs;
import 'daemon_util.dart';
import 'models.dart';
import 'storage.dart';

StorageKind storageKind(api.NodeKind k) => switch (k) {
  api.NodeKind.disk => StorageKind.disk,
  api.NodeKind.system => StorageKind.system,
  api.NodeKind.apps => StorageKind.apps,
  api.NodeKind.profile => StorageKind.profile,
  api.NodeKind.guest => StorageKind.guest,
  api.NodeKind.media => StorageKind.media,
  api.NodeKind.other => StorageKind.other,
  api.NodeKind.free => StorageKind.free,
  api.NodeKind.generation => StorageKind.generation,
  api.NodeKind.common => StorageKind.common,
  api.NodeKind.appEnv => StorageKind.appEnv,
  api.NodeKind.shared => StorageKind.shared,
  api.NodeKind.dir => StorageKind.dir,
  api.NodeKind.files => StorageKind.files,
  api.NodeKind.steam => StorageKind.steam,
  api.NodeKind.steamGame => StorageKind.steamGame,
  api.NodeKind.unknown => StorageKind.unknown,
};

/// A wire node as the ring draws it. A name is data (a folder, a game): it
/// is kept to one line of at most 128 characters.
StorageNode storageNode(api.StorageNode n) => StorageNode(
  kind: storageKind(n.kind),
  bytes: n.bytes < 0 ? 0 : n.bytes,
  children: [for (final c in n.children) storageNode(c)],
  id: n.id,
  name: oneLine(n.name),
  generation: n.generation,
  date: n.date == null ? null : unixTime(n.date!),
  current: n.current ?? false,
  booted: n.booted ?? false,
  appId: n.appId,
);

List<CleanupEstimate> _estimates(List<api.CleanupEstimate> l) => [
  for (final e in l)
    CleanupEstimate(keep: e.keep, generations: e.generations, bytes: e.bytes),
];

StorageMeasurement storageMeasurement(api.Measurement m) => StorageMeasurement(
  measuredAt: unixTime(m.measuredAt),
  disk: DiskSpace(
    totalBytes: m.disk.totalBytes,
    usedBytes: m.disk.usedBytes,
    freeBytes: m.disk.freeBytes,
  ),
  root: storageNode(m.root),
  garbageBytes: m.garbageBytes,
  systemEstimates: _estimates(m.estimates.system),
  profileEstimates: _estimates(m.estimates.profiles),
);

CleanupFrequency _frequency(api.CleanupFrequency f) => switch (f) {
  api.CleanupFrequency.daily => CleanupFrequency.daily,
  api.CleanupFrequency.monthly => CleanupFrequency.monthly,
  // weekly, and a value from a newer daemon: today's policy.
  _ => CleanupFrequency.weekly,
};

api.CleanupFrequency _wireFrequency(CleanupFrequency f) => switch (f) {
  CleanupFrequency.daily => api.CleanupFrequency.daily,
  CleanupFrequency.weekly => api.CleanupFrequency.weekly,
  CleanupFrequency.monthly => api.CleanupFrequency.monthly,
};

class DaemonStorage implements StorageRepository {
  DaemonStorage(this._conn, this._jobs);

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;

  @override
  Future<StorageMeasurement?> get() => guardCall(() async {
    final m = (await _conn.systemStorageGet()).measurement;
    return m == null ? null : storageMeasurement(m);
  });

  @override
  Future<JobHandle> measure() => _jobs.start(
    JobKind.storageMeasure,
    () async => (await _conn.systemStorageMeasure()).jobId,
  );

  @override
  Future<StorageTree> tree(String id, {String? adminPin}) =>
      guardCall(() async {
        final r = await _conn.systemStorageTree(
          api.SystemStorageTreeParams(id: id, adminPin: adminPin),
        );
        return StorageTree(
          id: r.id,
          measuredAt: unixTime(r.measuredAt),
          root: storageNode(r.root),
        );
      });

  @override
  Future<JobHandle> cleanup(
    CleanupTarget target,
    int keep, {
    String? adminPin,
  }) => switch (target) {
    CleanupTarget.system => _jobs.start(
      JobKind.cleanupSystem,
      () async => (await _conn.systemStorageCleanupSystem(
        api.SystemStorageCleanupSystemParams(keep: keep, adminPin: adminPin),
      )).jobId,
    ),
    CleanupTarget.profiles => _jobs.start(
      JobKind.cleanupProfiles,
      () async => (await _conn.systemStorageCleanupProfiles(
        api.SystemStorageCleanupProfilesParams(keep: keep, adminPin: adminPin),
      )).jobId,
    ),
  };

  @override
  Future<CleanupSettings> cleanupSettings() => guardCall(() async {
    final r = await _conn.systemCleanupGet();
    return CleanupSettings(
      enable: r.enabled,
      frequency: _frequency(r.frequency),
      keepSystem: r.keepSystem,
      keepProfiles: r.keepProfiles,
    );
  });

  @override
  Future<JobHandle> setCleanupSettings(CleanupSettings s, {String? adminPin}) =>
      _jobs.start(
        JobKind.cleanupSet,
        () async => (await _conn.systemCleanupSet(
          api.SystemCleanupSetParams(
            enabled: s.enable,
            frequency: _wireFrequency(s.frequency),
            keepSystem: s.keepSystem,
            keepProfiles: s.keepProfiles,
            adminPin: adminPin,
          ),
        )).jobId,
        nothingToDo: 'Nothing to change.',
      );
}
