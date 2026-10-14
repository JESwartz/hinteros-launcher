/// [TimeZoneRepository] over the session daemon's relayed
/// `system.time_zone.*` methods and `time_zone_changed` (session API 0.16,
/// system API 0.8).
library;

import 'dart:async';

import '../api/api.dart' as api;
import 'daemon_errors.dart';
import 'time_zone.dart';

DateTime? _unix(int? seconds) => seconds == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

TimeZoneInfo _info({
  required String zone,
  required int offsetSeconds,
  required int standardOffsetSeconds,
  required int? offsetValidUntil,
}) => TimeZoneInfo(
  zone: zone,
  offset: Duration(seconds: offsetSeconds),
  standardOffset: Duration(seconds: standardOffsetSeconds),
  validUntil: _unix(offsetValidUntil),
);

class DaemonTimeZone implements TimeZoneRepository {
  DaemonTimeZone(this._conn) {
    _events = _conn.events.listen((e) {
      if (e is api.TimeZoneChangedEvent) {
        _changes.add(
          _info(
            zone: e.zone,
            offsetSeconds: e.offsetSeconds,
            standardOffsetSeconds: e.standardOffsetSeconds,
            offsetValidUntil: e.offsetValidUntil,
          ),
        );
      }
    });
    // Events missed while disconnected: the zone as it is now.
    _status = _conn.statusChanges.listen((s) {
      if (s is api.Connected && _changes.hasListener) {
        get().then(_changes.add, onError: (_) {});
      }
    });
    unawaited(
      _conn
          .subscribeTo(const [api.EventName.timeZoneChanged])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  late final StreamSubscription<api.SessionEvent> _events;
  late final StreamSubscription<api.ConnectionStatus> _status;
  final _changes = StreamController<TimeZoneInfo>.broadcast();

  @override
  Stream<TimeZoneInfo> get changes => _changes.stream;

  @override
  Future<TimeZoneInfo> get() => guardCall(() async {
    final r = await _conn.systemTimeZoneGet();
    return _info(
      zone: r.zone,
      offsetSeconds: r.offsetSeconds,
      standardOffsetSeconds: r.standardOffsetSeconds,
      offsetValidUntil: r.offsetValidUntil,
    );
  });

  @override
  Future<List<TimeZoneEntry>> list() => guardCall(() async {
    final r = await _conn.systemTimeZoneList();
    return [
      for (final z in r.zones)
        TimeZoneEntry(
          zone: z.zone,
          offset: Duration(seconds: z.offsetSeconds),
          standardOffset: Duration(seconds: z.standardOffsetSeconds),
        ),
    ];
  });

  @override
  Future<TimeZoneInfo> set(String zone, {String? adminPin}) =>
      guardCall(() async {
        final r = await _conn.systemTimeZoneSet(
          api.SystemTimeZoneSetParams(zone: zone, adminPin: adminPin),
        );
        return _info(
          zone: r.zone,
          offsetSeconds: r.offsetSeconds,
          standardOffsetSeconds: r.standardOffsetSeconds,
          offsetValidUntil: r.offsetValidUntil,
        );
      });

  Future<void> dispose() async {
    await _events.cancel();
    await _status.cancel();
    await _changes.close();
  }
}
