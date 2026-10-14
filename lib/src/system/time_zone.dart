/// The box's time zone (session API 0.16, `system.time_zone.*`): the models
/// and the repository the screens use. The zone is box-wide: changing it takes
/// the admin PIN, except in first-boot mode (no admin profile yet).
library;

/// The box's zone and its UTC offset now (`TimeZoneInfo`).
class TimeZoneInfo {
  const TimeZoneInfo({
    required this.zone,
    required this.offset,
    required this.standardOffset,
    this.validUntil,
  });

  /// Before the daemon answers, and on a box without the API: UTC.
  static const utc = TimeZoneInfo(
    zone: 'UTC',
    offset: Duration.zero,
    standardOffset: Duration.zero,
  );

  /// An IANA name, e.g. `America/Chicago`.
  final String zone;

  /// The offset from UTC now (daylight saving time included).
  final Duration offset;

  /// The offset without daylight saving time: the map's band.
  final Duration standardOffset;

  /// The next change of [offset] (a daylight saving time change); null when
  /// there is none.
  final DateTime? validUntil;

  /// The wall clock time of the instant [now] in this zone, as a UTC
  /// [DateTime] whose fields are the local ones. The process's own zone is not
  /// used (glibc reads it once and keeps it).
  DateTime wallClock(DateTime now) => now.toUtc().add(offset);

  @override
  bool operator ==(Object other) =>
      other is TimeZoneInfo &&
      other.zone == zone &&
      other.offset == offset &&
      other.standardOffset == standardOffset &&
      other.validUntil == validUntil;

  @override
  int get hashCode => Object.hash(zone, offset, standardOffset, validUntil);

  @override
  String toString() => 'TimeZoneInfo($zone, ${formatUtcOffset(offset)})';
}

/// One zone of `time_zone.list`.
class TimeZoneEntry {
  const TimeZoneEntry({
    required this.zone,
    required this.offset,
    required this.standardOffset,
  });

  final String zone;
  final Duration offset;
  final Duration standardOffset;

  /// The group in the list: the part before the first `/` (`America`), or
  /// the name itself (`UTC`).
  String get region => regionOf(zone);

  /// `UTC−06:00  America/Chicago` without the gap: the parts of a list row.
  String get label => '${formatUtcOffset(offset)}  $zone';

  @override
  bool operator ==(Object other) =>
      other is TimeZoneEntry &&
      other.zone == zone &&
      other.offset == offset &&
      other.standardOffset == standardOffset;

  @override
  int get hashCode => Object.hash(zone, offset, standardOffset);

  @override
  String toString() => 'TimeZoneEntry($label)';
}

/// The regions of the list, in this order; anything else after them.
const timeZoneRegions = [
  'Africa',
  'America',
  'Antarctica',
  'Asia',
  'Atlantic',
  'Australia',
  'Europe',
  'Indian',
  'Pacific',
  'UTC',
];

String regionOf(String zone) {
  final i = zone.indexOf('/');
  return i < 0 ? zone : zone.substring(0, i);
}

/// `UTC+05:30`, `UTC−06:00` (a real minus sign), `UTC+00:00`.
String formatUtcOffset(Duration d) {
  final m = d.inMinutes;
  final sign = m < 0 ? '−' : '+';
  final a = m.abs();
  final hh = (a ~/ 60).toString().padLeft(2, '0');
  final mm = (a % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hh:$mm';
}

/// The zones grouped by region ([timeZoneRegions] order), each group sorted
/// by name.
List<(String region, List<TimeZoneEntry> zones)> groupTimeZones(
  Iterable<TimeZoneEntry> zones,
) {
  final by = <String, List<TimeZoneEntry>>{};
  for (final z in zones) {
    by.putIfAbsent(z.region, () => []).add(z);
  }
  int rank(String r) {
    final i = timeZoneRegions.indexOf(r);
    return i < 0 ? timeZoneRegions.length : i;
  }

  final regions = by.keys.toList()
    ..sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : a.compareTo(b);
    });
  return [
    for (final r in regions)
      (r, by[r]!..sort((a, b) => a.zone.compareTo(b.zone))),
  ];
}

/// `system.time_zone.*` and `time_zone_changed`.
abstract class TimeZoneRepository {
  /// `time_zone.get`.
  Future<TimeZoneInfo> get();

  /// `time_zone.list`: every zone with its offset now, by name.
  Future<List<TimeZoneEntry>> list();

  /// `time_zone.set {zone, admin_pin?}`: applies at once (no job). The admin
  /// PIN as for the other box-wide settings ([SystemErrorKind.pinRequired]);
  /// none in first-boot mode. An unknown zone is
  /// [SystemErrorKind.invalidParams].
  Future<TimeZoneInfo> set(String zone, {String? adminPin});

  /// `time_zone_changed`: the zone after every change (by anyone).
  Stream<TimeZoneInfo> get changes;
}
