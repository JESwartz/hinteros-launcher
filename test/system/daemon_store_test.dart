// The real Store repository (`DaemonStore`) over the mock daemon: `store.list`
// merged with what is installed, `store_changed`, install and remove through
// `system.apps.*` with their job events, and the service's errors.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_store.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/repositories.dart';

Future<(api.MockDaemon, SystemServices)> _setup([
  api.MockDaemon? daemon,
]) async {
  final mock = daemon ?? api.MockDaemon();
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

StoreApp _app(List<StoreApp> apps, String id) =>
    apps.firstWhere((a) => a.id == id);

/// Everything the mock daemon has queued has been delivered.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// A mock whose first `store.list` is answered late (after the second).
class _SlowFirstList extends api.MockDaemon {
  final late = Completer<void>();
  int lists = 0;

  @override
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (method != 'store.list') return super.rpc(method, params);
    final n = ++lists;
    final r = await super.rpc(method, params);
    if (n == 2) {
      // The older request's answer comes after the newer one's.
      late.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (n == 1) await late.future;
    return r;
  }
}

/// A service that never gets the revision right.
class _AlwaysStale extends api.MockDaemon {
  int installs = 0;

  @override
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) {
    if (method == 'system.apps.install') {
      installs++;
      return Future.error(
        const api.ApiException(
          api.ApiErrorCode.stateConflict,
          'state.json changed since settings.get',
          {'reason': 'revision'},
        ),
      );
    }
    return super.rpc(method, params);
  }
}

void main() {
  group('the listing', () {
    test(
      'apps by name with their state, terms text and the installed set',
      () async {
        final (mock, s) = await _setup();
        mock.system.installedApps.addAll(['jellyfin', 'old-player']);
        expect(s.store.loaded, isFalse);
        final apps = await s.store.catalog();
        expect(s.store.loaded, isTrue);
        expect(
          apps.map((a) => a.name),
          [...apps.map((a) => a.name)]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
        );
        expect(_app(apps, 'steam').state, StoreState.installed);
        expect(_app(apps, 'moonlight').state, StoreState.available);
        expect(_app(apps, 'jellyfin').state, StoreState.installed);
        // A retired app shows only because it is installed.
        expect(_app(apps, 'old-player').state, StoreState.retired);
        expect(
          _app(apps, 'old-player').statusReason,
          'Replaced by the Video player.',
        );
        expect(s.store.installed, {'steam', 'jellyfin', 'old-player'});
        expect(s.store.stateOf('steam'), StoreState.installed);
        expect(s.store.stateOf('nothing'), StoreState.available);
        // The terms text comes from the file the daemon names.
        final steam = _app(apps, 'steam');
        expect(steam.terms!.version, '2026-09-10');
        expect(steam.terms!.title, 'Steam Subscriber Agreement');
        expect(steam.terms!.text, contains('PLACEHOLDER TERMS'));
        expect(
          steam.removeDataWarning,
          contains('Games this profile installed'),
        );
        expect(_app(apps, 'youtube').isWeb, isTrue);
        expect(_app(apps, 'retroarch').depends, ['retroarch-cores']);
        expect(_app(apps, 'kodi').conflicts, ['jellyfin']);
      },
    );

    test('a retired app that is not installed is not listed', () async {
      final (_, s) = await _setup();
      expect(
        (await s.store.catalog()).any((a) => a.id == 'old-player'),
        isFalse,
      );
    });

    test('an unfree app whose terms cannot be read is not offered', () async {
      final mock = api.MockDaemon();
      await mock.waitConnected();
      final store = DaemonStore(
        mock,
        DaemonJobs(mock),
        readTerms: (path) => path.contains('plex') ? null : 'text',
      );
      addTearDown(mock.close);
      final apps = await store.catalog();
      expect(apps.any((a) => a.id == 'plex-htpc'), isFalse);
      expect(apps.any((a) => a.id == 'steam'), isTrue);
      // Installed, it can still be removed.
      mock.system.installedApps.add('plex-htpc');
      final again = await store.catalog();
      expect(_app(again, 'plex-htpc').state, StoreState.installed);
      expect(_app(again, 'plex-htpc').terms, isNull);
    });

    test('an installed app the catalog dropped can be removed', () async {
      final (mock, s) = await _setup();
      mock.system.installedApps.add('mystery');
      final mystery = _app(await s.store.catalog(), 'mystery');
      expect(mystery.state, StoreState.unavailable);
      expect(s.store.installed, contains('mystery'));
    });

    test(
      'no catalog index: the Store is unavailable, with the reason',
      () async {
        final (mock, s) = await _setup();
        mock.system.catalogMissing = true;
        final e = await _fails(s.store.catalog());
        expect(e.kind, SystemErrorKind.unavailable);
        expect(e.message, contains('The Store'));
      },
    );

    test('system service down: system_unavailable', () async {
      final (mock, s) = await _setup();
      mock.system.unavailable = api.SystemUnavailableDataReason.down;
      final e = await _fails(s.store.catalog());
      expect(e.kind, SystemErrorKind.unavailable);
      expect(e.data['reason'], 'down');
    });

    test('the listing is loaded by itself once connected', () async {
      final (_, s) = await _setup();
      await _settle();
      await _settle();
      expect(s.store.loaded, isTrue);
      expect(s.store.installed, {'steam'});
    });

    test('icons are the daemon-resolved ones of installed apps', () async {
      final (mock, s) = await _setup(
        api.MockDaemon(
          apps: const [
            api.App(
              id: 'steam',
              name: 'Steam',
              kind: api.AppKind.native,
              permissions: [],
              icon: '/icons/steam.png',
            ),
          ],
        ),
      );
      final apps = await s.store.catalog();
      expect(
        await s.store.resolveIcon(_app(apps, 'steam')),
        '/icons/steam.png',
      );
      // Not installed: no icon, the letter tile (the launcher fetches none).
      expect(await s.store.resolveIcon(_app(apps, 'moonlight')), isNull);
      mock.setAppIcon('steam', '/icons/other.png');
      await _settle();
      expect(
        await s.store.resolveIcon(_app(apps, 'steam')),
        '/icons/other.png',
      );
    });

    test('a slow answer does not overwrite a newer one', () async {
      final slow = _SlowFirstList();
      await slow.waitConnected();
      final s = daemonSystemServices(slow);
      addTearDown(slow.close);
      // The first listing is under way (held back) ...
      final first = s.store.catalog();
      await _settle();
      // ... the box changes, the second listing is answered first.
      slow.system.installedApps.add('moonlight');
      final second = s.store.catalog();
      await Future.wait([first, second]);
      await _settle();
      expect(s.store.stateOf('moonlight'), StoreState.installed);
    });
  });

  group('follows the box', () {
    test(
      'install: installing while the job runs, installed after, store_changed',
      () async {
        final (mock, s) = await _setup();
        await s.store.catalog();
        var changes = 0;
        s.store.changes.listen((_) => changes++);
        final h = await s.store.install('moonlight', acceptedTerms: const {});
        expect(h.kind, JobKind.install);
        await _settle();
        expect(s.store.stateOf('moonlight'), StoreState.installing);
        expect(s.store.installed, isNot(contains('moonlight')));
        final done = s.jobs.watch(h.jobId).firstWhere((j) => j.finished);
        mock.system.finishJob(h.jobId);
        expect((await done).ok, isTrue);
        await _settle();
        await _settle();
        expect(s.store.stateOf('moonlight'), StoreState.installed);
        expect(s.store.installed, contains('moonlight'));
        expect(changes, greaterThanOrEqualTo(2));
        expect(mock.system.log, ['apps.install:moonlight']);
      },
    );

    test(
      'remove: removing while the job runs, gone after; delete_data is sent',
      () async {
        final (mock, s) = await _setup();
        await s.store.catalog();
        final h = await s.store.remove('steam', deleteData: true);
        expect(h.kind, JobKind.remove);
        await _settle();
        expect(s.store.stateOf('steam'), StoreState.removing);
        expect(
          s.store.installed,
          contains('steam'),
          reason: 'still on the box',
        );
        mock.system.finishJob(h.jobId);
        await _settle();
        await _settle();
        expect(s.store.stateOf('steam'), StoreState.available);
        expect(mock.system.log, ['apps.remove:steam:data=true']);
        expect(mock.system.installedApps, isEmpty);
      },
    );

    test('the job reports progress through the jobs repository', () async {
      final (mock, s) = await _setup();
      final h = await s.store.install('moonlight');
      mock.system.progressJob(h.jobId, api.Stage.downloading, percent: 50);
      final snap = await s.jobs
          .watch(h.jobId)
          .firstWhere((j) => j.percent == 50);
      expect(snap.kind, JobKind.install);
      expect(snap.stage, JobStage.downloading);
      mock.system.finishJob(h.jobId);
    });

    test(
      'more apps after the update: from the check, then the listing',
      () async {
        final (mock, s) = await _setup();
        await s.store.catalog();
        expect(s.store.moreAfterUpdate, isFalse);
        mock.system.nextUpdate = api.AvailableUpdate(
          rev: '9a8b7c6d5e4f30211a2b3c4d5e6f708192a3b4c5',
          date: 1791300000,
          summary: 'More apps.',
          signer: 'release@hinteros',
          security: null,
          commits: 2,
          newApps: const [api.CatalogApp(id: 'mpv-2', name: 'Player 2')],
          removedApps: const [
            api.RemovedApp(
              id: 'old-player',
              name: 'Old player',
              reason: 'Gone.',
            ),
          ],
        );
        final status = s.updates.check();
        await _settle();
        mock.system.finishJob(mock.system.runningJobId!);
        final st = await status;
        expect(st.available!.newApps!.single.name, 'Player 2');
        expect(st.available!.catalogChanged, isTrue);
        expect(st.available!.removedApps!.single.reason, 'Gone.');
        await _settle();
        await _settle();
        expect(
          s.store.moreAfterUpdate,
          isTrue,
          reason: 'store_changed re-listed',
        );
      },
    );
  });

  group('install and the service\'s answers', () {
    test(
      'the terms version goes in accepted_terms; without it terms_required',
      () async {
        final (mock, s) = await _setup();
        mock.system.installedApps.clear();
        final e = await _fails(s.store.install('steam'));
        expect(e.kind, SystemErrorKind.termsRequired);
        expect(e.data['id'], 'steam');
        expect(e.data['version'], '2026-09-10');
        final h = await s.store.install(
          'steam',
          acceptedTerms: const {'steam': '2026-09-10'},
        );
        mock.system.finishJob(h.jobId);
        expect(mock.system.installedApps, ['steam']);
      },
    );

    test('a dependency\'s terms are needed too', () async {
      final (mock, s) = await _setup();
      mock.system.installedApps.clear();
      mock.system.catalog = [
        for (final a in mock.system.catalog)
          a.id == 'retroarch-cores'
              ? api.StoreApp.fromJson({
                  ...a.toJson(),
                  'free': false,
                  'terms': {
                    'title': 'Cores terms',
                    'version': '1',
                    'url': 'https://example.invalid',
                    'retrieved': '2026-10-06',
                    'file': '/nonexistent',
                  },
                })
              : a,
      ];
      final e = await _fails(s.store.install('retroarch'));
      expect(e.kind, SystemErrorKind.termsRequired);
      expect(e.data['id'], 'retroarch-cores');
    });

    test('app_conflict names both apps', () async {
      final (mock, s) = await _setup();
      mock.system.installedApps.add('jellyfin');
      final e = await _fails(s.store.install('kodi'));
      expect(e.kind, SystemErrorKind.appConflict);
      expect(e.data, {'id': 'kodi', 'conflicts_with': 'jellyfin'});
    });

    test('insufficient_resources carries the sizes', () async {
      final (mock, s) = await _setup();
      mock.system.freeDiskMib = 100;
      final e = await _fails(s.store.install('retroarch'));
      expect(e.kind, SystemErrorKind.insufficientResources);
      expect(e.message, contains('free disk space'));
      expect(e.data['needed_bytes'], (220 + 400) << 20);
      expect(e.data['available_bytes'], 100 << 20);
    });

    test('already installed is nothing to do', () async {
      final (_, s) = await _setup();
      final e = await _fails(
        s.store.install('steam', acceptedTerms: const {'steam': '2026-09-10'}),
      );
      expect(e.kind, SystemErrorKind.nothingToDo);
    });

    test(
      'an unknown app is not_found; a retired one is not available',
      () async {
        final (_, s) = await _setup();
        expect(
          (await _fails(s.store.install('nope'))).kind,
          SystemErrorKind.notFound,
        );
        final e = await _fails(s.store.install('old-player'));
        expect(e.kind, SystemErrorKind.invalidParams);
        expect(e.message, contains('not available'));
      },
    );

    test('a stale revision: settings.get again and one more try', () async {
      final (mock, s) = await _setup();
      mock.system.failNext = const api.ApiException(
        api.ApiErrorCode.stateConflict,
        'state.json changed since settings.get',
        {'reason': 'revision'},
      );
      final h = await s.store.install('moonlight');
      expect(h.kind, JobKind.install);
      // Tried twice: the first failed, the second went through.
      expect(mock.system.log, [
        'apps.install:moonlight',
        'apps.install:moonlight',
      ]);
      mock.system.finishJob(h.jobId);
    });

    test(
      'a revision that stays stale is reported, after one retry only',
      () async {
        final stale = _AlwaysStale();
        final (_, s) = await _setup(stale);
        final e = await _fails(s.store.install('moonlight'));
        expect(e.kind, SystemErrorKind.stateConflict);
        expect(stale.installs, 2);
      },
    );

    test('another job running is job_busy', () async {
      final (mock, s) = await _setup();
      final h = await s.store.install('moonlight');
      final e = await _fails(s.store.install('mpv'));
      expect(e.kind, SystemErrorKind.jobBusy);
      mock.system.finishJob(h.jobId);
    });
  });

  group('remove and the service\'s answers', () {
    test('an app another one needs stays: app_conflict', () async {
      final (mock, s) = await _setup();
      mock.system.installedApps.addAll(['retroarch', 'retroarch-cores']);
      final e = await _fails(s.store.remove('retroarch-cores'));
      expect(e.kind, SystemErrorKind.appConflict);
      expect(e.data, {'id': 'retroarch-cores', 'conflicts_with': 'retroarch'});
    });

    test('not installed is not_found', () async {
      final (_, s) = await _setup();
      expect(
        (await _fails(s.store.remove('mpv'))).kind,
        SystemErrorKind.notFound,
      );
    });
  });

  group('session API 0.9: icon.path', () {
    test(
      'comes with store.list, also for apps that are not installed',
      () async {
        final (mock, services) = await _setup();
        final store = services.store;
        await store.catalog();
        expect(_app(store.apps, 'moonlight').icon.path, isNull);
        expect(await store.resolveIcon(_app(store.apps, 'moonlight')), isNull);
        var changes = 0;
        final sub = store.changes.listen((_) => changes++);
        addTearDown(sub.cancel);
        mock.system.setStoreIcon('moonlight', '/icons/moonlight.png');
        await _settle();
        await _settle();
        expect(changes, greaterThan(0));
        final a = _app(store.apps, 'moonlight');
        expect(a.state, StoreState.available);
        expect(a.icon.path, '/icons/moonlight.png');
        expect(await store.resolveIcon(a), '/icons/moonlight.png');
      },
    );

    test('an installed app'
        's apps.list icon is the fallback', () async {
      final (_, services) = await _setup();
      await services.store.catalog();
      final steam = _app(services.store.apps, 'steam');
      expect(steam.icon.path, isNull);
      expect(await services.store.resolveIcon(steam), isNull);
    });
  });

  group('session API 0.18: permissions', () {
    test(
      'store.list and apps.list carry them; set_permission changes them',
      () async {
        final (mock, services) = await _setup();
        final store = services.store;
        await store.catalog();
        final before = _app(store.apps, 'mpv').permissions;
        expect(
          [for (final p in before) (p.name, p.required, p.granted)],
          [
            ('gamepad', true, true),
            ('mic', false, true),
            ('downloads', false, true),
          ],
        );
        expect(before.map((p) => p.label), [
          'Controller',
          'Microphone',
          'Downloads folder',
        ]);
        expect(_app(store.apps, 'kodi').permissions, isEmpty);
        final events = <api.SessionEvent>[];
        final sub = mock.events.listen(events.add);
        addTearDown(sub.cancel);
        // Not installed yet: the choice is kept for its install.
        await store.setPermission('mpv', 'mic', false);
        await _settle();
        await _settle();
        expect(mock.system.log, contains('apps.set_permission:mpv:mic:false'));
        expect(events.whereType<api.AppsChangedEvent>(), isNotEmpty);
        expect(_app(store.apps, 'mpv').permissions.map((p) => p.granted), [
          true,
          false,
          true,
        ], reason: 'store_changed refreshed the listing');
        mock.apps.add(
          const api.App(
            id: 'mpv',
            name: 'Video player',
            kind: api.AppKind.native,
            permissions: [],
          ),
        );
        final listed = (await mock.appsList()).apps.firstWhere(
          (a) => a.id == 'mpv',
        );
        expect(listed.permissions.map((p) => p.granted), [true, false, true]);
      },
    );

    test('the errors', () async {
      final (_, services) = await _setup();
      final store = services.store;
      var e = await _fails(store.setPermission('mpv', 'gamepad', false));
      expect(e.kind, SystemErrorKind.invalidParams);
      expect(e.message, 'This app needs that permission.');
      e = await _fails(store.setPermission('mpv', 'lan', false));
      expect(e.kind, SystemErrorKind.notFound);
      expect(e.message, 'This app does not use that permission.');
      e = await _fails(store.setPermission('nope', 'mic', false));
      expect(e.kind, SystemErrorKind.notFound);
      expect(e.message, 'That app is not there any more.');
    });
  });
}
