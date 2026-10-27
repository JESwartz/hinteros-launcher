import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/demo/web_demo.dart';

/// The browser demo's content (assets/demo, lib/src/demo/web_demo.dart),
/// read from the repo as the desktop reads files.
void main() {
  test('the catalog parses: free apps, no terms, READMEs where vendored', () {
    final c = demoCatalog();
    expect(c.map((a) => a.id), [
      'firefox',
      'freedoom-phase1',
      'jellyfin',
      'moonlight',
      'neverball',
      'openarena',
      'shattered-pixel-dungeon',
      'supertuxkart',
    ]);
    expect(c.every((a) => a.free && a.terms == null), isTrue);
    expect(
      [
        for (final a in c)
          if (a.readme != null) a.id,
      ],
      ['firefox', 'freedoom-phase1', 'jellyfin', 'neverball', 'supertuxkart'],
    );
  });

  test('icons for all but Firefox and OpenArena, art for every game', () {
    final icons = Directory(demoIconDir)
        .listSync()
        .map((f) => f.uri.pathSegments.last);
    expect(icons.toSet(), {
      'freedoom-phase1.png',
      'jellyfin.svg',
      'moonlight.svg',
      'neverball.png',
      'shattered-pixel-dungeon.png',
      'supertuxkart.png',
    });
    for (final id in demoGameIds) {
      for (final kind in ['portrait', 'header']) {
        expect(File('$demoArtDir/${id}_$kind.png').existsSync(), isTrue);
      }
    }
  });

  test('no other products and no real names in the content', () {
    final banned = RegExp(
      r'steam|plex|youtube|crunchyroll|vacuum|modrinth|james',
      caseSensitive: false,
    );
    for (final f in Directory(demoDir).listSync(recursive: true)) {
      if (f is! File || !RegExp(r'\.(json|md)$').hasMatch(f.path)) continue;
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
    expect(demoProfiles().map((p) => p.name), ['Alex', 'Sam', 'Robin']);
  });

  test('Store installs and removals show in Games and Apps', () async {
    final demo = WebDemo(autoRunJobs: false);
    final store = demo.services.mockStore;
    final jobs = demo.services.mockJobs;
    expect(demo.daemon.apps.map((a) => a.id), demoAppIds);
    expect(demo.daemon.games.map((g) => g.name), [
      'SuperTuxKart',
      'Neverball',
      'Shattered Pixel Dungeon',
    ]);

    jobs.finish((await store.install('openarena')).jobId);
    jobs.finish((await store.remove('moonlight')).jobId);
    await Future<void>.delayed(Duration.zero);
    expect(demo.daemon.games.map((g) => g.name), contains('OpenArena'));
    expect(demo.daemon.apps.map((a) => a.id), ['jellyfin', 'firefox']);
    demo.services.dispose();
  });
}
