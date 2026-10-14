/// The in-process [TimeZoneRepository] (`--mock`, tests): the zones of
/// `mock_time_zones.dart`, a new box on UTC, the admin PIN except in
/// first-boot mode, `time_zone_changed` after every change.
library;

import 'dart:async';

import '../api/mock_time_zones.dart';
import 'mock_profiles.dart';
import 'models.dart';
import 'time_zone.dart';

TimeZoneInfo _info(MockZone z) => TimeZoneInfo(
  zone: z.zone,
  offset: Duration(minutes: z.offset),
  standardOffset: Duration(minutes: z.standard),
  validUntil: z.until == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(z.until! * 1000, isUtc: true),
);

class MockTimeZone implements TimeZoneRepository {
  MockTimeZone({required this.box, required this.firstBoot, this.zone = 'UTC'});

  final MockProfileBox box;

  /// No admin profile yet: no PIN.
  final bool Function() firstBoot;

  /// The box's zone now.
  String zone;

  /// Every `set` that went through, in order.
  final List<String> log = [];

  /// The next call fails with this.
  SystemException? failNext;

  /// How many times [get] was asked (the clock asks again at a change).
  int gets = 0;

  final _changes = StreamController<TimeZoneInfo>.broadcast();

  void _fail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  MockZone get _current => mockTimeZone(zone) ?? mockTimeZone('UTC')!;

  @override
  Stream<TimeZoneInfo> get changes => _changes.stream;

  @override
  Future<TimeZoneInfo> get() async {
    gets++;
    _fail();
    return _info(_current);
  }

  @override
  Future<List<TimeZoneEntry>> list() async {
    _fail();
    return [
      for (final z in mockTimeZones)
        TimeZoneEntry(
          zone: z.zone,
          offset: Duration(minutes: z.offset),
          standardOffset: Duration(minutes: z.standard),
        ),
    ];
  }

  @override
  Future<TimeZoneInfo> set(String zone, {String? adminPin}) async {
    _fail();
    if (!firstBoot()) box.checkBoxAdmin(adminPin);
    final z = mockTimeZone(zone);
    if (z == null) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'That time zone is not known.',
      );
    }
    log.add(zone);
    final changed = zone != this.zone;
    this.zone = zone;
    final info = _info(z);
    if (changed) _changes.add(info);
    return info;
  }

  /// The zone changed elsewhere (another session, a rollback):
  /// `time_zone_changed`.
  void changeElsewhere(String zone) {
    this.zone = zone;
    _changes.add(_info(_current));
  }
}
