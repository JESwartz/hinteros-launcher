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
          // The hello examples name the server version they were written for
          // (upstream left them at 0.4 in the 0.5 schema): play them against
          // a mock that serves that version.
          final mock = MockDaemon(
            serverApiVersion:
                ((ex['result'] as Map?)?['api_version'] ??
                        ((ex['error'] as Map?)?['data']
                            as Map?)?['server_api_version'] ??
                        apiVersion)
                    as String,
          );
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

          // apps.close examples close a command app (cmd-1) and a Steam game.
          if (method == 'apps.close') {
            await mock.appsLaunch(const AppsLaunchParams(command: ['sleep']));
            await mock.appsLaunch(
              const AppsLaunchParams(url: 'steam://rungameid/620'),
            );
          }
          // Steam has dialogs open in the examples that return windows or an app.
          if (method == 'steam.attention' || method == 'steam.focus') {
            final shown =
                (ex['result'] as Map?)?['windows'] != null &&
                    ((ex['result'] as Map)['windows'] as List).isNotEmpty ||
                (method == 'steam.focus' && !ex.containsKey('error'));
            if (shown) {
              mock.setSteamAttention(const [
                SteamWindow(window: 6291459, title: 'Steam Guard', pid: 2412),
              ]);
            }
          }

          // The 0.4 error examples describe a daemon without the feature.
          final errCode = (ex['error'] as Map?)?['code'];
          if (errCode == ApiErrorCode.keyboardUnavailable) {
            mock.keyboardAvailable = false;
          }
          if (errCode == ApiErrorCode.oskUnavailable) mock.oskEnabled = false;

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

    test('games.list output validates and matches the typed model', () async {
      final mock = MockDaemon(games: mockGames(artDir: '/art'));
      await mock.rpc('hello', _hello);
      final raw = await mock.rpc('games.list', {});
      _expectValid(
        (_section('methods')['games.list'] as Map<String, dynamic>)['result']
            as Map<String, dynamic>,
        raw,
        'games.list result',
      );
      final games = (await mock.gamesList()).games;
      expect(games.map((g) => g.toJson()), raw['games']);
      expect(games.map((g) => g.name), [...games.map((g) => g.name)]..sort());
      // Every install state the schema knows is in the fake library.
      expect(
        games.map((g) => g.installState).toSet(),
        containsAll([
          InstallState.installed,
          InstallState.updateRequired,
          InstallState.updating,
          InstallState.installing,
        ]),
      );
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

      test('apps.close ends the app with reason closed', () async {
        final app = (await mock.appsLaunch(
          const AppsLaunchParams(command: ['firefox']),
        )).app;
        await settle();
        seen.clear();
        await mock.appsClose(AppsCloseParams(id: app.id));
        await settle();
        expect(seen, [isA<AppExitedEvent>(), isA<FocusChangedEvent>()]);
        expect((seen[0] as AppExitedEvent).reason, ExitReason.closed);
        expect((await mock.appsRunning()).apps, isEmpty);
        await expectLater(
          mock.appsClose(AppsCloseParams(id: app.id)),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 2001)),
        );
      });

      test('a game launches by Steam URL as steam-<appid>', () async {
        final app = (await mock.appsLaunch(
          const AppsLaunchParams(url: 'steam://rungameid/620'),
        )).app;
        expect(app.id, 'steam-620');
        expect(app.name, 'Portal 2');
        expect(app.source, AppSource.steam);
        await expectLater(
          mock.rpc('apps.launch', {'url': 'https://example.com'}),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', -32602)),
        );
      });

      test('the built-in steam app runs as steam_client', () async {
        expect((await mock.appsList()).apps.first.id, 'steam');
        final app = (await mock.appsLaunch(const AppsLaunchParams(id: 'steam')))
            .app;
        expect(app.source, AppSource.steamClient);
        expect(app.gamescopeAppId, 769);
      });

      test('steam attention: event, query, focus clears it', () async {
        await expectLater(
          mock.steamFocus(),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 2003)),
        );
        mock.setSteamAttention(const [
          SteamWindow(window: 1, title: 'Steam Guard'),
        ]);
        await settle();
        expect(seen.single, isA<SteamAttentionEvent>());
        expect(
          (await mock.steamAttention()).windows.single.title,
          'Steam Guard',
        );
        seen.clear();
        final app = (await mock.steamFocus()).app;
        await settle();
        expect(app.id, 'steam');
        expect(seen.map((e) => e.runtimeType), [
          AppStartedEvent,
          FocusChangedEvent,
          SteamAttentionEvent,
        ]);
        expect((seen.last as SteamAttentionEvent).windows, isEmpty);
        expect((await mock.steamAttention()).windows, isEmpty);
      });

      test('games_changed follows a library change', () async {
        mock.toggleFirstUpdate();
        await settle();
        expect(seen, [isA<GamesChangedEvent>()]);
        final installed = (await mock.gamesList()).games.where(
          (g) => g.installState == InstallState.installed,
        );
        expect(installed.map((g) => g.name), contains('Factorio'));
      });

      test(
        'apps_changed follows an icon change; apps.list carries the icon',
        () async {
          const dir = '/icons';
          final withIcons = MockDaemon(apps: mockAppsWithIcons(dir));
          expect(
            withIcons.apps.map((a) => a.icon).whereType<String>(),
            isEmpty,
            reason: 'no such directory: no icons',
          );
          mock.setAppIcon('plex', '/icons/plex.png');
          await settle();
          expect(seen, [isA<AppsChangedEvent>()]);
          final raw = await mock.rpc('apps.list', {});
          _expectValid(
            (_section('methods')['apps.list'] as Map<String, dynamic>)['result']
                as Map<String, dynamic>,
            raw,
            'apps.list result',
          );
          final plex = (raw['apps'] as List).cast<Map>().firstWhere(
            (a) => a['id'] == 'plex',
          );
          expect(plex['icon'], '/icons/plex.png');
          // An app without an icon has no icon key at all (the field is optional).
          final steam = (raw['apps'] as List).cast<Map>().first;
          expect(steam.containsKey('icon'), isFalse);
          // Taking it away again is a change too.
          mock.setAppIcon('plex', null);
          await settle();
          expect(seen, hasLength(2));
        },
      );

      test('osk.show/hide emit osk_visibility once per change', () async {
        await mock.oskShow();
        await mock.oskShow();
        await settle();
        expect(seen.whereType<OskVisibilityEvent>().map((e) => e.visible), [
          true,
        ]);
        await mock.oskHide();
        await settle();
        expect(seen.whereType<OskVisibilityEvent>().map((e) => e.visible), [
          true,
          false,
        ]);
      });

      test(
        'while the OSK is up, input_nav goes only to hinteros-osk',
        () async {
          final osk = MockDaemon(clientName: 'hinteros-osk');
          await osk.rpc('hello', _hello);
          await osk.subscribeTo([EventName.inputNav]);
          final oskSeen = <SessionEvent>[];
          osk.events.listen(oskSeen.add);
          // Each mock is one connection; both have the keyboard up.
          await mock.oskShow();
          await osk.oskShow();
          osk.emitNav(NavAction.right);
          mock.emitNav(NavAction.up);
          await settle();
          expect(oskSeen.whereType<InputNavEvent>().map((e) => e.action), [
            NavAction.right,
          ]);
          expect(seen.whereType<InputNavEvent>(), isEmpty);
        },
      );

      test('Home and a focus change hide the OSK', () async {
        await mock.oskShow();
        mock.pressHome();
        expect(mock.oskVisible, isFalse);
        await mock.oskShow();
        await mock.appsLaunch(const AppsLaunchParams(id: 'jellyfin'));
        expect(mock.oskVisible, isFalse);
      });

      test('keys.* log, untypeable characters and invalid keys', () async {
        expect(
          (await mock.keysType(const KeysTypeParams(text: 'aé'))).untypeable,
          ['é'],
        );
        await mock.keysKey(
          const KeysKeyParams(key: Key.l, modifiers: [Modifier.ctrl]),
        );
        await mock.keysAction(const KeysActionParams(action: KeyAction.enter));
        expect(mock.keyLog, ['type:a', 'key:l+ctrl', 'action:enter']);
        await expectLater(
          mock.rpc('keys.key', {'key': 'nope'}),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', -32602)),
        );
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
