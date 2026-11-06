/// Storage (session API 0.14): what uses
/// the disk, the two clean-ups and the automatic clean-up. The data types
/// and [StorageRepository]; `daemon_storage.dart` implements it over the
/// relayed `system.storage.*` / `system.cleanup.*` methods,
/// `mock_storage.dart` with placeholder data.
///
/// Read-only by design: nothing here deletes a file, removes an app or
/// uninstalls a game. The clean-ups only remove old generations and the
/// files nothing uses any more.
library;

import 'package:flutter/foundation.dart';

import 'models.dart';

/// What a node of the storage tree stands for. The launcher names it; the
/// daemon sends no text (only folder and Steam game names, which are data).
enum StorageKind {
  /// The whole filesystem: the top level's root.
  disk,

  /// HinterOS system generations.
  system,

  /// The profiles' apps.
  apps,

  /// A profile's home ([StorageNode.id]).
  profile,

  /// The guest's home.
  guest,

  /// The media folders (`/srv`): no children, only when not empty.
  media,

  /// What none of the others explains.
  other,

  /// Free space.
  free,

  /// One generation: what only it holds.
  generation,

  /// What two or more generations hold.
  common,

  /// One owner's apps (a profile id, `starter` or `guest`).
  appEnv,

  /// Apps in two or more owners' sets, counted once.
  shared,

  /// A folder ([StorageNode.name]).
  dir,

  /// The files directly in a folder, and folders too small to show.
  files,

  /// A home's installed Steam games.
  steam,

  /// One Steam game ([StorageNode.name]).
  steamGame,

  /// A kind this launcher does not know (a newer daemon).
  unknown,
}

/// One segment of the storage ring. [children] add up to [bytes] (except at
/// the disk root, see the contract): a segment is exactly its children.
@immutable
class StorageNode {
  const StorageNode({
    required this.kind,
    required this.bytes,
    this.children = const [],
    this.id,
    this.name,
    this.generation,
    this.date,
    this.current = false,
    this.booted = false,
    this.appId,
  });

  final StorageKind kind;
  final int bytes;
  final List<StorageNode> children;

  /// A profile id (`profile`, `app_env`; `starter`, `guest` for `app_env`).
  final String? id;

  /// A folder's or a Steam game's name.
  final String? name;
  final int? generation;
  final DateTime? date;

  /// The running system generation; a profile's current apps.
  final bool current;

  /// The system generation the box started with.
  final bool booted;

  /// A Steam game's appid.
  final int? appId;

  /// Whether A goes into it: a node with children, and every home (the
  /// top level has no children for them: they come from
  /// [StorageRepository.tree]).
  bool get canOpen =>
      children.isNotEmpty ||
      kind == StorageKind.profile ||
      kind == StorageKind.guest;

  /// A home whose folders come from [StorageRepository.tree].
  bool get isHome =>
      (kind == StorageKind.profile && id != null) || kind == StorageKind.guest;

  /// The tree id of a home: the profile id or `guest`.
  String? get homeId => kind == StorageKind.guest ? 'guest' : id;

  StorageNode withChildren(List<StorageNode> c) => StorageNode(
    kind: kind,
    bytes: bytes,
    children: c,
    id: id,
    name: name,
    generation: generation,
    date: date,
    current: current,
    booted: booted,
    appId: appId,
  );
}

/// The Nix store's filesystem, like df.
@immutable
class DiskSpace {
  const DiskSpace({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });

  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
}

/// What a clean-up that keeps [keep] generations would remove and free now
/// (an estimate from the last measurement).
@immutable
class CleanupEstimate {
  const CleanupEstimate({
    required this.keep,
    required this.generations,
    required this.bytes,
  });

  final int keep;
  final int generations;
  final int bytes;
}

/// The two clean-ups.
enum CleanupTarget { system, profiles }

/// The last measurement (`storage.get`): the top level, every profile's
/// total, the system and apps breakdown, and the clean-up estimates. It
/// never holds a file, folder or game name.
@immutable
class StorageMeasurement {
  const StorageMeasurement({
    required this.measuredAt,
    required this.disk,
    required this.root,
    required this.garbageBytes,
    required this.systemEstimates,
    required this.profileEstimates,
  });

  final DateTime measuredAt;
  final DiskSpace disk;

  /// `kind: disk`; profile and guest nodes without children.
  final StorageNode root;

  /// Files that nothing uses now (any clean-up deletes them).
  final int garbageBytes;
  final List<CleanupEstimate> systemEstimates;
  final List<CleanupEstimate> profileEstimates;

  /// The estimate for [target] keeping [keep]; null when the daemon sent
  /// none for it.
  CleanupEstimate? estimate(CleanupTarget target, int keep) {
    final list = target == CleanupTarget.system
        ? systemEstimates
        : profileEstimates;
    return list.where((e) => e.keep == keep).firstOrNull;
  }
}

/// One home's folders and Steam games (`storage.tree`).
@immutable
class StorageTree {
  const StorageTree({
    required this.id,
    required this.measuredAt,
    required this.root,
  });

  /// A profile id or `guest`.
  final String id;
  final DateTime measuredAt;
  final StorageNode root;
}

enum CleanupFrequency {
  daily('Every day'),
  weekly('Every week'),
  monthly('Every month');

  const CleanupFrequency(this.label);
  final String label;
}

/// The automatic clean-up (`cleanup.get`; state.json `settings.cleanup`).
@immutable
class CleanupSettings {
  const CleanupSettings({
    this.enable = true,
    this.frequency = CleanupFrequency.weekly,
    this.keepSystem = 5,
    this.keepProfiles = 5,
  });

  final bool enable;
  final CleanupFrequency frequency;
  final int keepSystem;
  final int keepProfiles;

  int keep(CleanupTarget t) =>
      t == CleanupTarget.system ? keepSystem : keepProfiles;

  CleanupSettings copyWith({
    bool? enable,
    CleanupFrequency? frequency,
    int? keepSystem,
    int? keepProfiles,
  }) => CleanupSettings(
    enable: enable ?? this.enable,
    frequency: frequency ?? this.frequency,
    keepSystem: keepSystem ?? this.keepSystem,
    keepProfiles: keepProfiles ?? this.keepProfiles,
  );

  @override
  bool operator ==(Object other) =>
      other is CleanupSettings &&
      other.enable == enable &&
      other.frequency == frequency &&
      other.keepSystem == keepSystem &&
      other.keepProfiles == keepProfiles;

  @override
  int get hashCode => Object.hash(enable, frequency, keepSystem, keepProfiles);
}

/// The fewest and most generations a clean-up keeps.
const minKeep = 1;
const maxKeep = 10;

/// Settings -> Storage. Every call can throw [SystemException]
/// (`unavailable` on a daemon before 0.14).
abstract class StorageRepository {
  /// `storage.get`: the last measurement, null before the first.
  Future<StorageMeasurement?> get();

  /// `storage.measure`: a `storage_measure` job (the running one's when one
  /// runs already). Any profile, no PIN.
  Future<JobHandle> measure();

  /// `storage.tree {id, admin_pin?}`: one home's folders and games. The
  /// caller's own home needs no PIN; another's needs the admin PIN
  /// ([SystemErrorKind.pinRequired] with `pin: admin`).
  /// [SystemErrorKind.notFound]: not measured (measure again).
  Future<StorageTree> tree(String id, {String? adminPin});

  /// `storage.cleanup_system` / `storage.cleanup_profiles {keep,
  /// admin_pin?}`: a clean-up job. The admin PIN every time. The finished
  /// job's result carries `freed_bytes` and `generations_removed`
  /// ([cleanupFreed]).
  Future<JobHandle> cleanup(CleanupTarget target, int keep, {String? adminPin});

  /// `cleanup.get`.
  Future<CleanupSettings> cleanupSettings();

  /// `cleanup.set {..., admin_pin?}`: a rebuild job.
  /// [SystemErrorKind.nothingToDo] when nothing changes.
  Future<JobHandle> setCleanupSettings(
    CleanupSettings settings, {
    String? adminPin,
  });
}

/// What a finished clean-up job freed (its result), null when unknown.
({int freedBytes, int generationsRemoved})? cleanupFreed(JobSnapshot s) {
  final r = s.result;
  final f = r?['freed_bytes'];
  if (f is! int) return null;
  final g = r?['generations_removed'];
  return (freedBytes: f, generationsRemoved: g is int ? g : 0);
}

/// A size as the Storage screen shows it, in decimal units like the disk's
/// label: "312 GB", "9.4 GB", "800 MB", "12.5 MB", "0 MB".
String storageSize(int bytes) {
  const mb = 1000 * 1000;
  const gb = 1000 * mb;
  const tb = 1000 * gb;
  if (bytes >= 10 * tb) return '${(bytes / tb).round()} TB';
  if (bytes >= tb) return '${(bytes / tb).toStringAsFixed(1)} TB';
  if (bytes >= 100 * gb) return '${(bytes / gb).round()} GB';
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= 100 * mb) return '${(bytes / mb).round()} MB';
  if (bytes >= mb ~/ 10) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return bytes == 0 ? '0 MB' : '0.1 MB';
}
