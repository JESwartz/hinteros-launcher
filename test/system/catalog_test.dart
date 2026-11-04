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
          'jellyfin-desktop',
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
        [
          'firefox',
          'jellyfin-desktop',
          'plex-htpc',
          'steam',
          'vacuum-tube',
          'youtube',
        ],
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
        ['firefox', 'jellyfin-desktop', 'youtube'],
      );
      expect(by['steam']!.onIso, isFalse);
      expect(by['steam']!.unfree, isTrue);
      expect(by['steam']!.delivery, AppDelivery.download);
      expect(by['plex-htpc']!.unfree, isTrue);
      expect(by['plex-htpc']!.delivery, AppDelivery.build);
      expect(by['moonlight']!.unfree, isFalse);
      expect(by['moonlight']!.delivery, AppDelivery.download);
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
      expect(
        by['jellyfin-desktop']!.icon.desktopId,
        'org.jellyfin.JellyfinDesktop',
      );
      expect(by['jellyfin-desktop']!.icon.iconUrl, startsWith('https://'));
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
      expect(j['indexVersion'], 4);
      for (final a in j['entries'] as List) {
        for (final k in [
          'id',
          'name',
          'kind',
          'starter',
          'onIso',
          'terms',
          'unfree',
          'delivery',
          'boxFeatures',
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
      'indexVersion': 4,
      'entries': [
        {
          'id': 'x',
          'name': 'X',
          'summary': 's',
          'category': 'video',
          'sizeMiB': 5,
          'status': 'available',
          'unfree': false,
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
        parseCatalogIndex(one({'unfree': true}), readTerms: noTerms),
        isEmpty,
      );
      // Terms listed, file missing.
      expect(
        parseCatalogIndex(
          one({'unfree': true, 'terms': terms}),
          readTerms: noTerms,
        ),
        isEmpty,
      );
      // Terms listed and readable: offered.
      final apps = parseCatalogIndex(
        one({'unfree': true, 'terms': terms}),
        readTerms: (f) => f == 'terms/x-1.txt' ? 'TEXT' : null,
      );
      expect(apps.single.terms!.text, 'TEXT');
      // A field that is missing counts as unfree.
      expect(
        parseCatalogIndex(one({'unfree': null}), readTerms: noTerms),
        isEmpty,
      );
    });

    test('retired and removed entries are hidden', () {
      final src = jsonEncode({
        'indexVersion': 4,
        'entries': [
          {
            'id': 'gone',
            'name': 'Gone',
            'status': 'removed',
            'statusReason': 'x',
          },
          {'id': 'old', 'name': 'Old', 'status': 'retired', 'unfree': false},
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

    test('starter, and no services', () {
      final offered = parseCatalogIndex(
        one({'kind': 'app', 'starter': 'offered'}),
        readTerms: noTerms,
      ).single;
      expect(offered.installer, isTrue);
      expect(offered.installerDefault, isFalse);
      final ticked = parseCatalogIndex(
        one({'kind': 'app', 'starter': 'ticked'}),
        readTerms: noTerms,
      ).single;
      expect(ticked.installerDefault, isTrue);
      final none = parseCatalogIndex(
        one({'kind': 'app', 'starter': null}),
        readTerms: noTerms,
      ).single;
      expect(none.installer, isFalse);
      expect(
        parseCatalogIndex(one({'kind': 'service'}), readTerms: noTerms),
        isEmpty,
      );
    });

    test('values of a newer catalog follow the schema rules', () {
      // An unknown kind is ignored, even when offered at install.
      expect(
        parseCatalogIndex(
          one({'kind': 'driver', 'starter': 'ticked'}),
          readTerms: noTerms,
        ),
        isEmpty,
      );
      // An unknown starter value is not offered.
      expect(
        parseCatalogIndex(
          one({'kind': 'app', 'starter': 'later'}),
          readTerms: noTerms,
        ).single.installer,
        isFalse,
      );
      // An unknown permission is not shown; an unknown level is required.
      final perms = parseCatalogIndex(
        one({
          'permissions': {
            'mic': 'optional',
            'gamepad': 'always',
            'camera': 'optional',
          },
        }),
        readTerms: noTerms,
      ).single.permissions;
      expect(
        [for (final p in perms) (p.name, p.required)],
        [('mic', false), ('gamepad', true)],
      );
    });

    test('delivery: a value this code does not know is a build', () {
      AppDelivery of(Object? d) => parseCatalogIndex(
        one({'delivery': d}),
        readTerms: noTerms,
      ).single.delivery;
      expect(of('download'), AppDelivery.download);
      expect(of('build'), AppDelivery.build);
      expect(of('later'), AppDelivery.build);
      expect(of(null), AppDelivery.download);
    });

    test('another index version is refused', () {
      for (final v in [1, 2, 3, 5]) {
        expect(
          () => parseCatalogIndex(
            '{"indexVersion":$v,"entries":[]}',
            readTerms: noTerms,
          ),
          throwsFormatException,
        );
      }
      // Index 4 keeps its entries under `entries`.
      expect(
        () => parseCatalogIndex(
          '{"indexVersion":4,"apps":[]}',
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
      expect(
        [for (final a in apps) a.id],
        ['jellyfin-desktop', 'youtube', 'firefox'],
      );
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
