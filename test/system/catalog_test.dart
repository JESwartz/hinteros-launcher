import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/parsers.dart';
import 'package:hinteros_launcher/src/system/catalog.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart' show mockCatalog;
import 'package:hinteros_launcher/src/system/models.dart';

import '../support/installer_fixtures.dart';

void main() {
  const index = '$catalogFixtureDir/catalog.json';
  List<StoreApp> load() => loadCatalogIndex(index);

  group('real catalog index (format 3)', () {
    test('every available app is read, in the order of the index', () {
      final apps = load();
      expect(
        [for (final a in apps) a.id],
        [
          'crunchyroll',
          'firefox',
          'jellyfin',
          'moonlight',
          'plex-htpc',
          'steam',
          'vacuum-tube',
          'youtube',
        ],
        reason: 'jellyfin-server is a service, not an app',
      );
    });

    test('the installer flags come from `starter`', () {
      final by = {for (final a in load()) a.id: a};
      expect(
        [
          for (final a in by.values)
            if (a.installer) a.id,
        ],
        ['firefox', 'jellyfin', 'plex-htpc', 'steam', 'vacuum-tube', 'youtube'],
      );
      expect(
        [
          for (final a in by.values)
            if (a.installerDefault) a.id,
        ],
        ['firefox', 'youtube'],
      );
      expect(
        [
          for (final a in by.values)
            if (a.onIso) a.id,
        ],
        ['firefox', 'jellyfin', 'youtube'],
      );
      expect(by['steam']!.onIso, isFalse);
      expect(by['steam']!.free, isFalse);
      expect(by['steam']!.buildsOnDevice, isFalse, reason: 'cache = true');
      expect(by['plex-htpc']!.buildsOnDevice, isTrue);
      expect(by['moonlight']!.isWeb, isFalse);
      expect(by['youtube']!.isWeb, isTrue, reason: 'type web');
    });

    test('terms: title, version, url, retrieved, file and the text', () {
      final steam = load().firstWhere((a) => a.id == 'steam');
      final t = steam.terms!;
      expect(t.title, 'Steam Subscriber Agreement');
      expect(t.version, '2026-09-10');
      expect(t.url, startsWith('https://'));
      expect(t.retrieved, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(t.file, 'terms/steam-2026-09-10.txt');
      expect(t.text, startsWith('PLACEHOLDER TERMS FOR STEAM'));
      expect(load().firstWhere((a) => a.id == 'firefox').hasTerms, isFalse);
    });

    test('icon fields and the data paths', () {
      final by = {for (final a in load()) a.id: a};
      expect(by['jellyfin']!.icon.desktopId, 'org.jellyfin.JellyfinDesktop');
      expect(by['jellyfin']!.icon.iconUrl, startsWith('https://'));
      expect(by['crunchyroll']!.icon.firefoxProfile, isTrue);
      expect(by['crunchyroll']!.icon.siteUrl, startsWith('https://'));
      expect(by['steam']!.dataPaths, contains('.local/share/Steam'));
      expect(by['steam']!.removeDataWarning, isNotNull);
      expect(by['firefox']!.removeDataWarning, isNull);
      expect(by['moonlight']!.category, StoreCategory.games);
      expect(by['firefox']!.category, StoreCategory.utilities);
    });

    test('the fixture matches the schema\'s required fields', () {
      final j = jsonDecode(File(index).readAsStringSync()) as Map;
      expect(j['indexVersion'], 3);
      for (final a in j['apps'] as List) {
        for (final k in [
          'id',
          'name',
          'kind',
          'type',
          'starter',
          'onIso',
          'terms',
          'free',
          'dataPaths',
          'icon',
        ]) {
          expect((a as Map).containsKey(k), isTrue, reason: '${a['id']} $k');
        }
      }
    });
  });

  group('parser rules', () {
    String one(Map<String, Object?> extra) => jsonEncode({
      'indexVersion': 2,
      'apps': [
        {
          'id': 'x',
          'name': 'X',
          'summary': 's',
          'category': 'video',
          'sizeMiB': 5,
          'status': 'available',
          'free': true,
          'terms': null,
          ...extra,
        },
      ],
    });
    String? noTerms(String f) => null;

    test('unfree without readable terms stays hidden', () {
      final terms = {
        'title': 'T',
        'version': '1',
        'url': 'https://x.example',
        'retrieved': '2026-01-01',
        'file': 'terms/x-1.txt',
      };
      // No terms at all.
      expect(
        parseCatalogIndex(one({'free': false}), readTerms: noTerms),
        isEmpty,
      );
      // Terms listed, file missing.
      expect(
        parseCatalogIndex(
          one({'free': false, 'terms': terms}),
          readTerms: noTerms,
        ),
        isEmpty,
      );
      // Terms listed and readable: offered.
      final apps = parseCatalogIndex(
        one({'free': false, 'terms': terms}),
        readTerms: (f) => f == 'terms/x-1.txt' ? 'TEXT' : null,
      );
      expect(apps.single.terms!.text, 'TEXT');
      // A field that is missing counts as unfree.
      expect(
        parseCatalogIndex(one({'free': null}), readTerms: noTerms),
        isEmpty,
      );
    });

    test('retired and removed entries are hidden', () {
      final src = jsonEncode({
        'indexVersion': 2,
        'apps': [
          {
            'id': 'gone',
            'name': 'Gone',
            'status': 'removed',
            'statusReason': 'x',
          },
          {'id': 'old', 'name': 'Old', 'status': 'retired', 'free': true},
        ],
      });
      expect(parseCatalogIndex(src, readTerms: noTerms), isEmpty);
    });

    test('unknown categories are Other, unknown fields are ignored', () {
      final apps = parseCatalogIndex(
        one({'category': 'spaceships', 'newField': 1}),
        readTerms: noTerms,
      );
      expect(apps.single.category, StoreCategory.other);
    });

    test('an index 2 (older systems) still reads', () {
      final app = parseCatalogIndex(
        one({'kind': 'web', 'installer': true, 'installerDefault': true}),
        readTerms: noTerms,
      ).single;
      expect(app.isWeb, isTrue);
      expect(app.installer, isTrue);
      expect(app.installerDefault, isTrue);
    });

    test('index 3: starter, type, and no services', () {
      String v3(Map<String, Object?> a) =>
          one(a).replaceFirst('"indexVersion":2', '"indexVersion":3');
      final offered = parseCatalogIndex(
        v3({'kind': 'app', 'type': 'web', 'starter': 'offered'}),
        readTerms: noTerms,
      ).single;
      expect(offered.isWeb, isTrue);
      expect(offered.installer, isTrue);
      expect(offered.installerDefault, isFalse);
      final ticked = parseCatalogIndex(
        v3({'kind': 'app', 'type': 'native', 'starter': 'ticked'}),
        readTerms: noTerms,
      ).single;
      expect(ticked.isWeb, isFalse);
      expect(ticked.installerDefault, isTrue);
      final none = parseCatalogIndex(
        v3({'kind': 'app', 'type': 'web', 'starter': null}),
        readTerms: noTerms,
      ).single;
      expect(none.installer, isFalse);
      expect(
        parseCatalogIndex(
          v3({'kind': 'service', 'type': 'service'}),
          readTerms: noTerms,
        ),
        isEmpty,
      );
    });

    test('another index version is refused', () {
      expect(
        () => parseCatalogIndex(
          '{"indexVersion":1,"apps":[]}',
          readTerms: noTerms,
        ),
        throwsFormatException,
      );
      expect(
        () => parseCatalogIndex('[]', readTerms: noTerms),
        throwsFormatException,
      );
    });

    test('the terms reader stays inside terms/', () {
      final r = termsReaderFor(index);
      expect(r('terms/steam-2026-09-10.txt'), isNotNull);
      expect(r('terms/nope.txt'), isNull);
      expect(r('../catalog.json'), isNull);
      expect(r('terms/../catalog.json'), isNull);
      expect(r('/etc/passwd'), isNull);
    });
  });

  test(
    'the fallback offers only what is on the ISO, preselecting defaults',
    () {
      final apps = fallbackCatalog();
      expect([for (final a in apps) a.id], ['jellyfin', 'youtube', 'firefox']);
      expect(apps.every((a) => a.onIso && !a.hasTerms), isTrue);
      expect(
        [
          for (final a in apps)
            if (a.installerDefault) a.id,
        ],
        ['youtube', 'firefox'],
      );
    },
  );

  test('the Store mock reads the same fixture', () {
    final ids = [for (final a in mockCatalog()) a.id];
    expect(ids, containsAll(['steam', 'plex-htpc', 'firefox']));
  });
}
