import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/demo/web_demo.dart';
import 'package:hinteros_launcher/src/system/profiles.dart';

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

  group('profile switch (lib/web_main.dart starts the next session)', () {
    // Waits (real timers, at most 2 s) until [done].
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    WebDemo session({String id = 'p1', WebDemo? from}) {
      final d = WebDemo(
        autoRunJobs: false,
        profileId: id,
        box: from?.services.mockProfiles.box,
        installed: from?.services.mockStore.installed,
      );
      d.services.mockProfiles.switchStepDelay = const Duration(milliseconds: 1);
      return d;
    }

    test('ends without a Steam stage and names the target', () async {
      final d = session();
      final stages = <SwitchStage>[];
      d.services.mockProfiles.switchEvents.listen((e) {
        if (e is SwitchProgress) stages.add(e.stage);
      });
      String? target;
      d.services.mockProfiles.onSwitched = (t) => target = t;
      await d.services.mockProfiles.switchTo('p2', pin: '1593');
      await until(() => target != null);
      expect(stages, [SwitchStage.closingApps, SwitchStage.ending]);
      expect(target, 'p2');
      d.services.dispose();
    });

    test('a blocked switch ends only after Close app', () async {
      final d = session();
      final p = d.services.mockProfiles
        ..blockingApp = (id: 'jellyfin', name: 'Jellyfin');
      final blocked = <SwitchBlocked>[];
      p.switchEvents.listen((e) {
        if (e is SwitchBlocked) blocked.add(e);
      });
      String? target;
      p.onSwitched = (t) => target = t;
      await p.switchTo('p3');
      await until(() => blocked.isNotEmpty);
      expect(blocked, hasLength(1));
      expect(target, isNull);
      await p.keepWaiting();
      await until(() => blocked.length > 1);
      expect(blocked, hasLength(2));
      expect(target, isNull);
      await p.forceClose('jellyfin');
      await until(() => target != null);
      expect(target, 'p3');
      d.services.dispose();
    });

    test('ending the guest session goes to the picker', () async {
      final d = session(id: CurrentProfile.guestId);
      String? target;
      d.services.mockProfiles.onSwitched = (t) => target = t;
      await d.services.mockProfiles.endGuest();
      await until(() => target != null);
      expect(target, '');
      d.services.dispose();
    });

    test('the next session: its profile, the same box and installs', () async {
      final a = session();
      a.services.mockJobs.finish(
        (await a.services.mockStore.install('openarena')).jobId,
      );
      final b = session(id: 'p3', from: a);
      expect(b.services.mockProfiles.currentId, 'p3');
      expect(b.services.mockProfiles.box, same(a.services.mockProfiles.box));
      expect(b.daemon.games.map((g) => g.name), contains('OpenArena'));
      a.services.dispose();
      b.services.dispose();
    });
  });
}
