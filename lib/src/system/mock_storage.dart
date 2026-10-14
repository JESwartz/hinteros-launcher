/// A fake [StorageRepository] with the service's rules: `storage.get` holds
/// no names, a home's tree is open to its own profile and needs the admin
/// PIN for anyone else's, the clean-ups need the admin PIN every time and
/// run as jobs with a result, `cleanup.set` is a rebuild job. Placeholder
/// numbers on a 500 GB disk: three profiles' homes with folders and Steam
/// games (named like the mock Steam library), the guest, system and app
/// generations.
library;

import 'mock_profiles.dart';
import 'mock_system.dart' show MockJobs;
import 'models.dart';
import 'profiles.dart';
import 'storage.dart';

const _mb = 1000 * 1000;
const _gb = 1000 * _mb;

int _g(double gb) => (gb * _gb).round();

/// A node whose bytes are its children's.
StorageNode _sum(
  StorageKind kind,
  List<StorageNode> children, {
  String? id,
  String? name,
}) => StorageNode(
  kind: kind,
  bytes: children.fold<int>(0, (a, c) => a + c.bytes),
  children: children,
  id: id,
  name: name,
);

StorageNode _leaf(StorageKind kind, double gb, {String? name, int? appId}) =>
    StorageNode(kind: kind, bytes: _g(gb), name: name, appId: appId);

StorageNode _dir(String name, List<StorageNode> children) =>
    _sum(StorageKind.dir, children, name: name);

StorageNode _game(String name, int appId, double gb) =>
    _leaf(StorageKind.steamGame, gb, name: name, appId: appId);

StorageNode _files(double gb) => _leaf(StorageKind.files, gb);

/// The folders and games of each mock home (profile id or `guest`).
StorageNode mockHome(String id) {
  final kind = id == 'guest' ? StorageKind.guest : StorageKind.profile;
  final pid = id == 'guest' ? null : id;
  final children = switch (id) {
    'p1' => [
      _sum(StorageKind.steam, [
        _game('Disco Elysium', 632470, 21.4),
        _game('Rocket League', 252950, 20.2),
        _game('Hades', 1145360, 15.1),
        _game('Portal 2', 620, 12.9),
        _game('Hollow Knight', 367520, 9.0),
        _game('Cuphead', 268910, 3.5),
        _game('Celeste', 504230, 1.2),
      ]),
      _dir('Videos', [
        _dir('Holiday 2026', [_files(6.8)]),
        _files(2.3),
      ]),
      _dir('.local', [
        _dir('share', [
          _dir('Steam', [_files(4.1)]),
          _files(0.9),
        ]),
        _files(0.2),
      ]),
      _dir('.cache', [_files(3.4)]),
      _dir('Downloads', [_files(1.6)]),
      _dir('.config', [_files(0.4)]),
      _files(0.3),
    ],
    'p3' => [
      _sum(StorageKind.steam, [
        _game('Factorio', 427520, 2.1),
        _game('Stardew Valley', 413150, 0.7),
        _game('Slay the Spire', 646570, 0.6),
        _game('Dead Cells', 588650, 0.5),
      ]),
      _dir('Music', [_files(8.2)]),
      _dir('.local', [
        _dir('share', [_files(2.6)]),
        _files(0.1),
      ]),
      _dir('.cache', [_files(1.9)]),
      _files(0.2),
    ],
    'p4' => [
      _sum(StorageKind.steam, [
        _game('Terraria', 105600, 0.3),
        _game('Vampire Survivors', 1794680, 0.2),
        _game('Balatro', 2379780, 0.1),
      ]),
      _dir('.local', [_files(1.1)]),
      _dir('.cache', [_files(0.6)]),
      _files(0.1),
    ],
    'guest' => [
      _dir('.cache', [_files(0.3)]),
      _files(0.1),
    ],
    _ => [
      _dir('.local', [_files(0.5)]),
      _files(0.1),
    ],
  };
  return _sum(kind, children, id: pid);
}

/// Robin, a third profile (no PIN): with [MockProfileBox.defaultProfiles]
/// the box the Storage screen's mock data is made for.
MockProfile mockRobin() =>
    MockProfile(id: 'p4', name: 'Robin', color: ProfileColor.purple, pin: null);

class MockStorage implements StorageRepository {
  MockStorage(
    this.jobs, {
    required this.box,
    required this.currentId,
    DateTime Function()? now,
    this.measured = true,
  }) : _now = now ?? DateTime.now {
    if (measured) _measurement = _measure(_now().subtract(_age));
  }

  final MockJobs jobs;
  final MockProfileBox box;

  /// Whose session this is: a profile id or `guest`.
  final String Function() currentId;
  final DateTime Function() _now;

  /// There is a measurement from the start (2 hours old).
  final bool measured;
  static const _age = Duration(hours: 2);

  StorageMeasurement? _measurement;
  CleanupSettings settings = const CleanupSettings();

  /// Every tree asked for, with whether a PIN came along: `p3:pin`, `p1`.
  final List<String> treeLog = [];

  /// System generations on the box (the newest first), app generations of
  /// each profile.
  int systemGenerations = 6;
  int appGenerations = 5;

  /// The next call fails with this.
  SystemException? failNext;

  void _fail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  static const _total = 500 * _gb;

  List<StorageNode> _systemGens() => [
    for (var i = 0; i < systemGenerations; i++)
      StorageNode(
        kind: StorageKind.generation,
        bytes: _g(1.2 - i * 0.15),
        generation: 12 - i,
        date: DateTime(2026, 10, 6 - i * 3, 9),
        current: i == 0,
        booted: i == 0,
      ),
  ];

  List<StorageNode> _appGens(double newest) => [
    for (var i = 0; i < appGenerations; i++)
      StorageNode(
        kind: StorageKind.generation,
        bytes: _g(newest * (1 - i * 0.15)),
        generation: 9 - i,
        date: DateTime(2026, 10, 5 - i * 2, 18),
        current: i == 0,
      ),
  ];

  StorageMeasurement _measure(DateTime at) {
    final homes = [
      for (final p in box.profiles)
        StorageNode(
          kind: StorageKind.profile,
          id: p.id,
          bytes: mockHome(p.id).bytes,
        ),
      if (box.guestEnabled)
        StorageNode(kind: StorageKind.guest, bytes: mockHome('guest').bytes),
    ];
    final system = _sum(StorageKind.system, [
      ..._systemGens(),
      _leaf(StorageKind.common, 10.6),
    ]);
    final apps = _sum(StorageKind.apps, [
      for (final p in box.profiles)
        _sum(StorageKind.appEnv, [
          ..._appGens(p.admin ? 0.3 : 0.12),
          _leaf(StorageKind.common, p.admin ? 0.9 : 0.4),
        ], id: p.id),
      _sum(StorageKind.appEnv, [
        ..._appGens(0.05),
        _leaf(StorageKind.common, 0.2),
      ], id: 'starter'),
      _leaf(StorageKind.shared, 4.4),
    ]);
    final garbage = _g(2.4);
    final used =
        system.bytes +
        apps.bytes +
        homes.fold<int>(0, (a, h) => a + h.bytes) +
        garbage +
        _g(6.2);
    final free = _total - used;
    int sysFreed(int keep) {
      final gens = _systemGens();
      var b = garbage;
      for (final g in gens.skip(keep)) {
        if (!g.current && !g.booted) b += g.bytes;
      }
      return b;
    }

    int appsFreed(int keep) {
      var b = garbage;
      for (final p in box.profiles) {
        for (final g in _appGens(p.admin ? 0.3 : 0.12).skip(keep)) {
          b += g.bytes;
        }
      }
      return b;
    }

    return StorageMeasurement(
      measuredAt: at,
      disk: DiskSpace(totalBytes: _total, usedBytes: used, freeBytes: free),
      root: StorageNode(
        kind: StorageKind.disk,
        bytes: _total,
        children: [
          system,
          apps,
          ...homes,
          StorageNode(kind: StorageKind.other, bytes: garbage + _g(6.2)),
          StorageNode(kind: StorageKind.free, bytes: free),
        ],
      ),
      garbageBytes: garbage,
      systemEstimates: [
        for (var k = minKeep; k <= maxKeep; k++)
          CleanupEstimate(
            keep: k,
            generations: (systemGenerations - k).clamp(0, 99),
            bytes: sysFreed(k),
          ),
      ],
      profileEstimates: [
        for (var k = minKeep; k <= maxKeep; k++)
          CleanupEstimate(
            keep: k,
            generations:
                (appGenerations - k).clamp(0, 99) * box.profiles.length,
            bytes: appsFreed(k),
          ),
      ],
    );
  }

  @override
  Future<StorageMeasurement?> get() async {
    _fail();
    return _measurement;
  }

  @override
  Future<JobHandle> measure() async {
    _fail();
    final r = jobs.running;
    if (r != null && r.kind == JobKind.storageMeasure) return r;
    final at = _now();
    return jobs.start(
      JobKind.storageMeasure,
      result: {'measured_at': at.millisecondsSinceEpoch ~/ 1000},
      onSuccess: () => _measurement = _measure(at),
    );
  }

  @override
  Future<StorageTree> tree(String id, {String? adminPin}) async {
    _fail();
    final own = id == currentId();
    if (!own) box.checkBoxAdmin(adminPin);
    treeLog.add(adminPin == null ? id : '$id:pin');
    final m = _measurement;
    final known = id == 'guest' ? box.guestEnabled : box.byId(id) != null;
    if (m == null || !known) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'That is not there any more.',
      );
    }
    return StorageTree(id: id, measuredAt: m.measuredAt, root: mockHome(id));
  }

  @override
  Future<JobHandle> cleanup(
    CleanupTarget target,
    int keep, {
    String? adminPin,
  }) async {
    _fail();
    box.checkBoxAdmin(adminPin);
    final e = _measurement?.estimate(target, keep);
    final removed = e?.generations ?? 0;
    return jobs.start(
      target == CleanupTarget.system
          ? JobKind.cleanupSystem
          : JobKind.cleanupProfiles,
      // A little less than the estimate, like the real thing.
      result: {
        'freed_bytes': ((e?.bytes ?? 0) * 0.94).round(),
        'generations_removed': removed,
      },
      onSuccess: () {
        if (target == CleanupTarget.system) {
          systemGenerations = keep.clamp(1, systemGenerations);
        } else {
          appGenerations = keep.clamp(1, appGenerations);
        }
      },
    );
  }

  @override
  Future<CleanupSettings> cleanupSettings() async {
    _fail();
    return settings;
  }

  @override
  Future<JobHandle> setCleanupSettings(
    CleanupSettings s, {
    String? adminPin,
  }) async {
    _fail();
    box.checkBoxAdmin(adminPin);
    if (s == settings) {
      throw const SystemException(
        SystemErrorKind.nothingToDo,
        'Nothing to change.',
      );
    }
    return jobs.start(JobKind.cleanupSet, onSuccess: () => settings = s);
  }
}
