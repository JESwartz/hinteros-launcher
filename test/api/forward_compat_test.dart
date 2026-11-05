// A client of 1.0 reads a newer server of its major: fields, enum values,
// events and error codes it does not know, and job results it cannot read.
// The enums a client sends stay closed, except ProfileColor, Channel, Base
// and CleanupFrequency (sent only as known values, read with a fallback).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_server.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/repositories.dart';

const _new = 'added_by_a_later_minor';

/// [v] with a new field in every object.
Object? _grown(Object? v) => switch (v) {
  final Map<String, dynamic> m => {
    for (final e in m.entries) e.key: _grown(e.value),
    _new: _new,
  },
  final List<dynamic> l => l.map(_grown).toList(),
  _ => v,
};

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

/// `job_finished` of [id] with [result].
Map<String, dynamic> _finished(String id, String kind, Object? result) => {
  'job_id': id,
  'kind': kind,
  'ok': true,
  'result': result,
  'session_restart_required': false,
  'subject': <String, dynamic>{},
  'started_at': 1791300000,
  'finished_at': 1791300001,
};

/// The mock with one method's result changed, as a newer daemon sends it.
class _Newer extends api.MockDaemon {
  _Newer(this.method, this.change);

  final String method;
  final Map<String, dynamic> Function(Map<String, dynamic>) change;

  @override
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    final r = await super.rpc(method, params);
    return method == this.method ? change(r) : r;
  }
}

void main() {
  group('enums that grow', () {
    final readers = <String, (Object Function(String), Object)>{
      'JobKind': (api.JobKind.fromJson, api.JobKind.unknown),
      'JobState': (api.JobState.fromJson, api.JobState.unknown),
      'Stage': (api.Stage.fromJson, api.Stage.unknown),
      'Severity': (api.Severity.fromJson, api.Severity.unknown),
      'NodeKind': (api.NodeKind.fromJson, api.NodeKind.unknown),
      'TailscaleState': (
        api.TailscaleState.fromJson,
        api.TailscaleState.unknown,
      ),
      'AppKind': (api.AppKind.fromJson, api.AppKind.unknown),
      'AppSource': (api.AppSource.fromJson, api.AppSource.unknown),
      'ExitReason': (api.ExitReason.fromJson, api.ExitReason.unknown),
      'NavAction': (api.NavAction.fromJson, api.NavAction.unknown),
      'NavPhase': (api.NavPhase.fromJson, api.NavPhase.unknown),
      'InstallState': (api.InstallState.fromJson, api.InstallState.unknown),
      'AuthOutcome': (api.AuthOutcome.fromJson, api.AuthOutcome.unknown),
      'SwitchStage': (api.SwitchStage.fromJson, api.SwitchStage.unknown),
      'StoreState': (api.StoreState.fromJson, api.StoreState.unknown),
      'CatalogStatus': (api.CatalogStatus.fromJson, api.CatalogStatus.unknown),
      'WifiSecurity': (api.WifiSecurity.fromJson, api.WifiSecurity.unknown),
      'BtKind': (api.BtKind.fromJson, api.BtKind.unknown),
      'BtConfirmMode': (
        api.BluetoothConfirmEventMode.fromJson,
        api.BluetoothConfirmEventMode.unknown,
      ),
      'AudioKind': (api.AudioKind.fromJson, api.AudioKind.unknown),
      'PowerCapability': (
        api.PowerCapability.fromJson,
        api.PowerCapability.unknown,
      ),
      'Connectivity': (api.Connectivity.fromJson, api.Connectivity.unknown),
      'UnitState': (api.UnitState.fromJson, api.UnitState.unknown),
      // Sent too, but also read (system.info, job subjects, cleanup.get).
      'Channel': (api.Channel.fromJson, api.Channel.unknown),
      'Base': (api.Base.fromJson, api.Base.unknown),
      'CleanupFrequency': (
        api.CleanupFrequency.fromJson,
        api.CleanupFrequency.unknown,
      ),
      'LibraryKindShown': (
        api.LibraryKindShown.fromJson,
        api.LibraryKindShown.other,
      ),
    };
    for (final MapEntry(key: name, value: (read, catchAll))
        in readers.entries) {
      test('$name reads a new value as its catch-all', () {
        expect(read(_new), catchAll);
      });
    }

    test('a value of the schema named unknown is one value, not two', () {
      expect(
        api.Connectivity.values.where((e) => e.value == 'unknown').length,
        1,
      );
      expect(api.UnitState.values.where((e) => e.value == 'unknown').length, 1);
      expect(
        api.LibraryKindShown.fromJson('other'),
        api.LibraryKindShown.other,
      );
    });
  });

  group('closed enums', () {
    final closed = <String, (Object Function(String), List<Enum>)>{
      'LibraryKind': (api.LibraryKind.fromJson, api.LibraryKind.values),
      'Key': (api.Key.fromJson, api.Key.values),
      'Modifier': (api.Modifier.fromJson, api.Modifier.values),
      'KeyAction': (api.KeyAction.fromJson, api.KeyAction.values),
      'EventName': (api.EventName.fromJson, api.EventName.values),
    };
    // Sent but open on purpose (see tool/gen_api.dart): the client sends only
    // values of its own enum and reads a new one as `unknown`.
    const openSent = {'ProfileColor', 'Channel', 'Base', 'CleanupFrequency'};
    final doc = jsonDecode(
      File('schema/session-api.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final defs = doc[r'$defs'] as Map<String, dynamic>;

    test('every enum a client sends is closed', () {
      final sent = <String>{};
      void walk(Object? s) {
        if (s is Map<String, dynamic>) {
          final ref = s[r'$ref'];
          if (ref is String && ref.startsWith(r'#/$defs/')) {
            final name = ref.substring(8);
            if (sent.add(name)) walk(defs[name]);
          }
          s.values.forEach(walk);
        } else if (s is List) {
          s.forEach(walk);
        }
      }

      for (final m in (doc['methods'] as Map<String, dynamic>).values) {
        walk((m as Map<String, dynamic>)['params']);
      }
      final enums = sent.where(
        (n) => (defs[n] as Map<String, dynamic>).containsKey('enum'),
      );
      expect({...closed.keys, ...openSent}, containsAll(enums));
    });
    test('ProfileColor reads a new value as unknown', () {
      expect(api.ProfileColor.fromJson(_new), api.ProfileColor.unknown);
      expect(
        ProfileColor.parse(api.ProfileColor.unknown.value),
        ProfileColor.teal,
      );
    });
    test('the launcher sends only ProfileColor values of the schema', () {
      final schema =
          ((defs['ProfileColor'] as Map<String, dynamic>)['enum'] as List)
              .cast<String>();
      expect(schema, containsAll(ProfileColor.values.map((c) => c.name)));
      expect(schema, isNot(contains('unknown')));
    });
    for (final MapEntry(key: name, value: (read, values)) in closed.entries) {
      test('$name has no catch-all and refuses a new value', () {
        expect(() => read(_new), throwsFormatException);
        expect(
          values.length,
          ((defs[name] as Map<String, dynamic>)['enum'] as List).length,
        );
      });
    }
  });

  test('every event of the schema takes fields it does not know', () {
    final doc = jsonDecode(
      File('schema/session-api.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final e in (doc['events'] as Map<String, dynamic>).entries) {
      final spec = e.value as Map<String, dynamic>;
      for (final ex
          in (spec['examples'] as List).cast<Map<String, dynamic>>()) {
        final params = ex['params'] as Map<String, dynamic>;
        final event = api.SessionEvent.fromNotification(
          e.key,
          _grown(params)! as Map<String, dynamic>,
        );
        expect(event, isNot(isA<api.UnknownSessionEvent>()));
      }
    }
  });

  test('an event of a newer daemon reads as unknown', () {
    final e = api.SessionEvent.fromNotification(_new, const {'a': 1});
    expect(e, isA<api.UnknownSessionEvent>());
    expect(e.name, _new);
  });

  test('an unknown auth outcome is no authorization', () async {
    final (mock, s) = await _setup();
    final outcome = s.auth.finished.first;
    mock.emitRaw('authentication_finished', {'cookie': 'c', 'outcome': _new});
    expect((await outcome).outcome, AuthOutcome.cancelled);
  });

  test(
    'a network of an unknown security type: secured, not supported',
    () async {
      final mock = _Newer('wifi.list', (r) {
        final n = (r['networks'] as List).first as Map<String, dynamic>;
        return {
          ...r,
          'networks': [
            {...n, 'security': _new},
          ],
        };
      });
      await mock.waitConnected();
      addTearDown(mock.close);
      final n = (await daemonSystemServices(mock).network.list()).single;
      expect(n.secured, isTrue);
      expect(n.supported, isFalse);
    },
  );

  group('job results', () {
    test('an unreadable update check result is no result', () async {
      final (mock, s) = await _setup();
      final f = _fails(s.updates.check());
      await pumpEventQueue();
      final id = mock.system.runningJobId!;
      mock.emitRaw('job_finished', _finished(id, 'update_check', {_new: true}));
      final e = await f;
      expect(e.kind, SystemErrorKind.failed);
      expect(e.message, 'The update check gave no result.');
    });

    test('an unreadable channel check result is no result', () async {
      final (mock, s) = await _setup();
      final f = _fails(s.updates.checkChannel(UpdateChannel.beta));
      await pumpEventQueue();
      final id = mock.system.runningJobId!;
      mock.emitRaw(
        'job_finished',
        _finished(id, 'channel_check', {_new: true}),
      );
      final e = await f;
      expect(e.kind, SystemErrorKind.failed);
      expect(e.message, 'The check gave no result.');
    });

    test('a result that is no object is null on the snapshot', () async {
      final (mock, s) = await _setup();
      final h = await s.system.redetectHardware(adminPin: '2468');
      final finished = s.jobs.watch(h.jobId).firstWhere((j) => j.finished);
      mock.emitRaw('job_finished', _finished(h.jobId, 'rebuild', 'a string'));
      final done = await finished;
      expect(done.ok, isTrue);
      expect(done.result, isNull);
    });
  });

  test('an unknown setup and detail read as none', () async {
    final mock = _Newer(
      'system.services.list',
      (r) => {
        ...r,
        'services': [
          for (final s in (r['services'] as List).cast<Map<String, dynamic>>())
            {
              ...s,
              'enabled': true,
              'setup': _new,
              'detail': {_new: true},
            },
        ],
      },
    );
    await mock.waitConnected();
    final jobs = DaemonJobs(mock);
    final server = DaemonServer(mock, jobs, readTerms: (_) => 'Terms.');
    addTearDown(() async {
      await server.dispose();
      await jobs.dispose();
      await mock.close();
    });
    final l = await server.list();
    expect(l.services, isNotEmpty);
    for (final s in l.services) {
      expect(s.setup, ServiceSetup.none);
      expect(s.detail, isNull);
    }
  });

  test('a newer channel, base and clean-up frequency still read', () async {
    final info = _Newer(
      'system.info',
      (r) => {...r, 'channel': _new, 'base': _new},
    );
    await info.waitConnected();
    addTearDown(info.close);
    final i = await daemonSystemServices(info).system.info();
    expect(i.channel, isNull);
    expect(i.base, NixBase.unstable);

    final cleanup = _Newer(
      'system.cleanup.get',
      (r) => {...r, 'frequency': _new},
    );
    await cleanup.waitConnected();
    addTearDown(cleanup.close);
    final c = await daemonSystemServices(cleanup).storage.cleanupSettings();
    expect(c.frequency, CleanupFrequency.weekly);
  });

  test('a Store app in a newer state is not offered for install', () async {
    final mock = _Newer(
      'store.list',
      (r) => {
        ...r,
        'apps': [
          for (final a in (r['apps'] as List).cast<Map<String, dynamic>>())
            a['id'] == 'steam' ? {...a, 'state': _new} : a,
        ],
      },
    );
    await mock.waitConnected();
    addTearDown(mock.close);
    final store = daemonSystemServices(mock).store;
    final steam = (await store.catalog()).firstWhere((a) => a.id == 'steam');
    expect(steam.state, StoreState.unknown);
    expect(steam.state.isInstalled, isFalse);
    expect(store.installed, isNot(contains('steam')));
  });

  test('an unknown error code is a plain failure', () {
    final e = systemExceptionFrom(
      const api.ApiException(9999, 'new', {'a': 1}),
    );
    expect(e.kind, SystemErrorKind.failed);
    expect(e.message, 'Something went wrong. Try again.');
  });
}
