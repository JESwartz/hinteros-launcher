// The real TimeZoneRepository over the mock daemon's relay (session API
// 0.16): get, list, set with the admin PIN (none in first-boot mode), the
// errors, and `time_zone_changed`.
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
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
  test('a new box is on UTC; the list has offsets, by name', () async {
    final (_, s) = await _setup();
    final z = await s.timeZone.get();
    expect(z.zone, 'UTC');
    expect(z.offset, Duration.zero);
    expect(z.validUntil, isNull);
    final list = await s.timeZone.list();
    expect([
      for (final e in list) e.zone,
    ], [for (final e in list) e.zone]..sort());
    final chicago = list.firstWhere((e) => e.zone == 'America/Chicago');
    expect(chicago.offset, const Duration(hours: -5));
    expect(chicago.standardOffset, const Duration(hours: -6));
    expect(chicago.region, 'America');
  });

  test('set: the admin PIN, then the zone at once and the event', () async {
    final (mock, s) = await _setup();
    final seen = <TimeZoneInfo>[];
    final sub = s.timeZone.changes.listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    final e = await _fails(s.timeZone.set('America/Chicago'));
    expect(e.kind, SystemErrorKind.pinRequired);
    expect(mock.system.timeZone, 'UTC');
    final z = await s.timeZone.set('America/Chicago', adminPin: _pin);
    expect(z.zone, 'America/Chicago');
    expect(z.offset, const Duration(hours: -5));
    expect(z.standardOffset, const Duration(hours: -6));
    expect(z.validUntil, DateTime.utc(2026, 11, 1, 7));
    expect(mock.system.timeZone, 'America/Chicago');
    await pumpEventQueue();
    expect(seen.single, z);
    // The same zone again: nothing changes, no event.
    await s.timeZone.set('America/Chicago', adminPin: _pin);
    await pumpEventQueue();
    expect(seen, hasLength(1));
  });

  test('unknown and badly formed zones are refused', () async {
    final (mock, s) = await _setup();
    for (final bad in [
      'Mars/Olympus_Mons',
      '../etc/passwd',
      'Europe/ London',
    ]) {
      final e = await _fails(s.timeZone.set(bad, adminPin: _pin));
      expect(e.kind, SystemErrorKind.invalidParams, reason: bad);
    }
    expect(mock.system.timeZone, 'UTC');
  });

  test('first-boot mode: no admin profile, no PIN', () async {
    final (mock, s) = await _setup();
    mock.profiles.profiles.removeWhere((p) => p.admin);
    final z = await s.timeZone.set('Asia/Kolkata');
    expect(z.offset, const Duration(hours: 5, minutes: 30));
    expect(mock.system.timeZone, 'Asia/Kolkata');
  });
}
