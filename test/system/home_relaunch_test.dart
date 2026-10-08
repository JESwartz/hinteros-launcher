import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/log.dart';
import 'package:hinteros_launcher/src/system/home_relaunch.dart';

const _peer = Peer(name: 'hinteros-session', version: '0.1.0');
const _connected = Connected(apiVersion: '0.10', server: _peer);
const _mismatch = VersionMismatch(
  clientApiVersion: '0.9',
  serverApiVersion: '0.10',
);

void main() {
  late String installed;
  late List<int> exits;
  late List<String> lines;
  late StreamController<ConnectionStatus> changes;

  HomeRelaunch relaunch({
    int? code = 75,
    String? link = '/run/current-system/hinteros-console/home',
  }) => HomeRelaunch(
    code: code,
    link: link,
    running: '/nix/store/old-launcher/bin/hinteros-launcher',
    resolve: (p) {
      expect(p, '/run/current-system/hinteros-console/home');
      return installed;
    },
    exit: exits.add,
  );

  setUp(() {
    installed = '/nix/store/new-launcher/bin/hinteros-launcher';
    exits = [];
    lines = [];
    logSink = lines.add;
    changes = StreamController<ConnectionStatus>();
  });

  Future<void> send(ConnectionStatus s) async {
    changes.add(s);
    await Future<void>.delayed(Duration.zero);
  }

  test('a version mismatch hands over to a different launcher', () async {
    relaunch().watch(const Connecting(), changes.stream);
    await send(_mismatch);
    expect(exits, [75]);
    expect(lines.single, contains('API 0.10'));
    // Once only.
    await send(_mismatch);
    expect(exits, [75]);
  });

  test('the same launcher installed: it stays and retries', () async {
    installed = '/nix/store/old-launcher/bin/hinteros-launcher';
    relaunch().watch(const Connecting(), changes.stream);
    await send(_mismatch);
    await send(const Unreachable('gone'));
    await send(_connected);
    await send(const Unreachable('gone'));
    await send(_connected);
    expect(exits, isEmpty);
  });

  test('a restarted daemon with a new launcher installed', () async {
    relaunch().watch(const Connecting(), changes.stream);
    // The first connection is not a restart.
    await send(_connected);
    expect(exits, isEmpty);
    await send(const Unreachable('connection closed'));
    await send(const Connecting());
    await send(_connected);
    expect(exits, [75]);
  });

  test('without the home loop nothing happens', () async {
    for (final r in [relaunch(code: null), relaunch(link: null)]) {
      expect(r.otherInstalled, isFalse);
      final c = StreamController<ConnectionStatus>();
      r.watch(_connected, c.stream);
      c.add(_mismatch);
      c.add(const Unreachable('x'));
      c.add(_connected);
      await Future<void>.delayed(Duration.zero);
    }
    expect(exits, isEmpty);
    // A missing link (resolve throws) also keeps it.
    final r = HomeRelaunch(
      code: 75,
      link: '/nonexistent/hinteros-home',
      running: '/x',
    );
    expect(r.otherInstalled, isFalse);
  });

  test('reads the home loop variables', () {
    final r = HomeRelaunch.fromEnvironment({
      'HINTEROS_HOME_RELAUNCH': '75',
      'HINTEROS_HOME_LINK': '/run/current-system/hinteros-console/home',
      'HINTEROS_HOME_EXE': '/nix/store/a/bin/hinteros-launcher',
    });
    expect(
      (r.code, r.link, r.running),
      (
        75,
        '/run/current-system/hinteros-console/home',
        '/nix/store/a/bin/hinteros-launcher',
      ),
    );
    final none = HomeRelaunch.fromEnvironment({});
    expect((none.code, none.link, none.running), (null, null, null));
  });
}
