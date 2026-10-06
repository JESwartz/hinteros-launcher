// Contract test: every example in the vendored schema is replayed through the
// mock daemon, and everything the mock produces is validated against the
// schema's JSON Schema payloads (via the json_schema package).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:json_schema/json_schema.dart';

final _doc = jsonDecode(
  File('schema/session-api.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> _section(String k) =>
    (_doc[k] as Map<String, dynamic>?) ?? {};

/// A validator for one payload schema; `$ref`s resolve against the document's `$defs`.
JsonSchema _validator(Map<String, dynamic> payload) => JsonSchema.create({
  ...payload,
  r'$defs': _doc[r'$defs'],
}, schemaVersion: SchemaVersion.draft2020_12);

void _expectValid(Map<String, dynamic> payload, Object? value, String what) {
  final r = _validator(payload).validate(value);
  expect(
    r.isValid,
    isTrue,
    reason: '$what does not match the schema: ${r.errors}\n$value',
  );
}

/// A client hello the mock accepts, to get past the handshake.
final _hello = HelloParams(
  apiVersion: apiVersion,
  client: const Peer(name: 'contract-test', version: '0'),
).toJson();

void main() {
  test('vendored schema is the version the client was generated for', () {
    expect(_doc['version'], apiVersion);
    expect(_section('methods').keys, apiMethodNames);
    expect(_section('events').keys, apiEventNames);
  });

  group('methods: every example through the mock', () {
    for (final entry in _section('methods').entries) {
      final method = entry.key;
      final spec = entry.value as Map<String, dynamic>;
      final examples = (spec['examples'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      test('$method has examples', () => expect(examples, isNotEmpty));

      for (final ex in examples) {
        test('$method: ${ex['name']}', () async {
          final mock = MockDaemon();
          final params = (ex['params'] as Map).cast<String, dynamic>();
          _expectValid(
            spec['params'] as Map<String, dynamic>,
            params,
            'example params',
          );
          if (method != 'hello') await mock.rpc('hello', _hello);
          // These examples describe a game that is already running (in the background).
          if (method == 'apps.focus' || method == 'apps.running') {
            await mock.appsLaunch(
              const AppsLaunchParams(url: 'steam://rungameid/1000001'),
            );
            await mock.appsFocus(const AppsFocusParams(id: null));
          }

          if (ex.containsKey('error')) {
            final expected = ex['error'] as Map<String, dynamic>;
            final err = await mock
                .rpc(method, params)
                .then<ApiException?>(
                  (_) => null,
                  onError: (Object e) => e as ApiException,
                );
            expect(err, isNotNull, reason: 'expected an error');
            expect(err!.code, expected['code']);
            final errEntry = _section('errors').entries
                .firstWhere((e) => (e.value as Map)['code'] == err.code);
            // The method must declare its own errors (generic ones apply everywhere).
            expect(
              err.code <= -32000 ||
                  (spec['errors'] as List).contains(errEntry.key),
              isTrue,
              reason: '${errEntry.key} is not declared by $method',
            );
            final errName = errEntry.value as Map<String, dynamic>;
            if (errName['data'] != null) {
              _expectValid(
                errName['data'] as Map<String, dynamic>,
                err.data,
                'error data',
              );
              expect(err.data, expected['data']);
            }
          } else {
            final result = await mock.rpc(method, params);
            _expectValid(
              spec['result'] as Map<String, dynamic>,
              result,
              'result',
            );
            // The shape must survive the generated typed model unchanged.
            expect(result.keys.toSet(), (ex['result'] as Map).keys.toSet());
          }
        });
      }
    }
  });

  group('events: every example through the mock', () {
    for (final entry in _section('events').entries) {
      final name = entry.key;
      final spec = entry.value as Map<String, dynamic>;
      for (final ex
          in (spec['examples'] as List).cast<Map<String, dynamic>>()) {
        test('$name: ${ex['name']}', () async {
          final mock = MockDaemon();
          await mock.rpc('hello', _hello);
          await mock.subscribe(
            SubscribeParams(events: [EventName.fromJson(name)]),
          );
          final got = mock.events.first;
          final params = (ex['params'] as Map).cast<String, dynamic>();
          _expectValid(
            spec['params'] as Map<String, dynamic>,
            params,
            'params',
          );
          mock.emitRaw(name, params);
          final event = await got;
          expect(event, isNot(isA<UnknownSessionEvent>()));
          expect(event.name, name);
          // Typed event round-trips to the example params.
          expect(event.params, params);
          _expectValid(
            spec['params'] as Map<String, dynamic>,
            event.params,
            'typed event',
          );
        });
      }
    }
  });

  group('protocol rules', () {
    test('the validator rejects bad payloads and resolves \$refs', () {
      final schema =
          (_section('methods')['apps.list'] as Map<String, dynamic>)['result']
              as Map<String, dynamic>;
      bool valid(Map<String, dynamic> app) => _validator(schema).validate({
        'apps': [app],
      }).isValid;
      expect(valid({'id': 'ok', 'name': 'x', 'kind': 'web'}), isTrue);
      expect(valid({'id': 'Bad Id', 'name': 'x', 'kind': 'web'}), isFalse);
      expect(valid({'id': 'ok', 'name': 'x', 'kind': 'other'}), isFalse);
      expect(valid({'id': 'ok', 'name': 'x', 'kind': 'web', 'z': 1}), isFalse);
    });

    test('requests before hello get handshake_required', () async {
      final mock = MockDaemon();
      await expectLater(
        mock.rpc('ping', {}),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 1001)),
      );
    });

    test('second hello gets already_handshaken', () async {
      final mock = MockDaemon();
      await mock.rpc('hello', _hello);
      await expectLater(
        mock.rpc('hello', _hello),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 1003)),
      );
    });

    test('unknown methods get method_not_found', () async {
      final mock = MockDaemon();
      await mock.rpc('hello', _hello);
      await expectLater(
        mock.rpc('nope.nothing', {}),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', -32601)),
      );
    });

    test('events are only delivered to subscribers', () async {
      final mock = MockDaemon();
      await mock.rpc('hello', _hello);
      final seen = <SessionEvent>[];
      mock.events.listen(seen.add);
      mock.pressHome();
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      await mock.subscribeTo([EventName.homePressed]);
      mock.pressHome();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [isA<HomePressedEvent>()]);
      await mock.unsubscribeFrom([EventName.homePressed]);
      mock.pressHome();
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1));
    });

    test('apps.list output validates and matches the typed model', () async {
      final mock = MockDaemon();
      await mock.rpc('hello', _hello);
      final raw = await mock.rpc('apps.list', {});
      _expectValid(
        (_section('methods')['apps.list'] as Map<String, dynamic>)['result']
            as Map<String, dynamic>,
        raw,
        'apps.list result',
      );
      final typed = (await mock.appsList()).apps;
      expect(typed.map((a) => a.toJson()), raw['apps']);
    });

    group('apps and focus', () {
      late MockDaemon mock;
      late List<SessionEvent> seen;
      setUp(() async {
        mock = MockDaemon();
        await mock.rpc('hello', _hello);
        await mock.subscribeTo(
          EventName.values.where((e) => e != EventName.unknown),
        );
        seen = [];
        mock.events.listen(seen.add);
      });
      Future<void> settle() => Future<void>.delayed(Duration.zero);

      test('launch emits app_started then focus_changed', () async {
        final r = await mock.appsLaunch(const AppsLaunchParams(id: 'jellyfin'));
        await settle();
        expect(r.app.id, 'jellyfin');
        expect(seen, [isA<AppStartedEvent>(), isA<FocusChangedEvent>()]);
        expect((seen[1] as FocusChangedEvent).app, 'jellyfin');
        final running = await mock.appsRunning();
        expect(running.apps.map((a) => a.id), ['jellyfin']);
        expect(running.focused, 'jellyfin');
      });

      test('launching a running app only focuses it', () async {
        await mock.appsLaunch(const AppsLaunchParams(id: 'jellyfin'));
        await mock.appsFocus(const AppsFocusParams(id: null));
        await settle();
        seen.clear();
        await mock.appsLaunch(const AppsLaunchParams(id: 'jellyfin'));
        await settle();
        expect(seen, [isA<FocusChangedEvent>()]);
        expect((await mock.appsRunning()).apps, hasLength(1));
      });

      test('launch needs exactly one of id, command, url', () async {
        await expectLater(
          mock.rpc('apps.launch', {}),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', -32602)),
        );
        await expectLater(
          mock.rpc('apps.launch', {
            'id': 'steam',
            'command': ['x'],
          }),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', -32602)),
        );
      });

      test('exit of the focused app returns focus to the launcher', () async {
        final app = (await mock.appsLaunch(
          const AppsLaunchParams(command: ['firefox']),
        )).app;
        expect(app.id, 'cmd-1');
        await settle();
        seen.clear();
        mock.simulateExit(app.id, reason: ExitReason.crashed, exitCode: 139);
        await settle();
        expect(seen, [isA<AppExitedEvent>(), isA<FocusChangedEvent>()]);
        expect((seen[1] as FocusChangedEvent).app, isNull);
        expect((await mock.appsRunning()).apps, isEmpty);
      });

      test('input_nav is only sent while the launcher has focus', () async {
        mock.emitNav(NavAction.right);
        await mock.appsLaunch(const AppsLaunchParams(id: 'jellyfin'));
        await settle();
        seen.clear();
        mock.emitNav(NavAction.right);
        await settle();
        expect(seen, isEmpty);
        mock.pressHome();
        await settle();
        expect(seen, [isA<FocusChangedEvent>(), isA<HomePressedEvent>()]);
      });
    });
  });
}
