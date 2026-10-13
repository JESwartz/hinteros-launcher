import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../system/catalog.dart';
import '../system/models.dart';
import 'backend.dart';
import 'parsers.dart';
import 'plan.dart';
import 'progress.dart';

/// The real backend, for the ISO: runs `lsblk`, `nmcli`, `hinteros-install`
/// and `systemctl` as the current user (root there). Every command is an
/// executable plus a list of fixed arguments: no shell is involved and no
/// user-typed text is ever part of an argument list apart from a Wi-Fi name
/// that came out of `nmcli`'s own scan (and `-` leading names are refused
/// when scanning). Secrets (the admin password, a Wi-Fi password) only travel
/// on stdin; nothing the tools print on stderr is kept.
class ProcessInstallerBackend implements InstallerBackend {
  ProcessInstallerBackend({
    this.installBinary = 'hinteros-install',
    this.catalogPath = catalogIndexPath,
    this.reachable = _probeCache,
  });

  /// Whether the internet is reachable: a real HTTPS request, 5 s at most.
  final Future<bool> Function() reachable;

  final String installBinary;
  final String catalogPath;

  Future<String> _stdout(
    String exe,
    List<String> args, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ProcessResult r;
    try {
      r = await Process.run(
        exe,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
    } on ProcessException {
      throw InstallerException('$exe is not available on this system.');
    } on TimeoutException {
      throw InstallerException('$exe did not answer in time.');
    }
    if (r.exitCode != 0) {
      throw InstallerException('$exe failed (status ${r.exitCode}).');
    }
    return r.stdout as String;
  }

  static const _deviceArgs = ['-t', '-f', 'TYPE,STATE,CONNECTION', 'device'];

  @override
  Future<NetworkState> networkLink() async =>
      parseNetwork(await _stdout('nmcli', _deviceArgs));

  @override
  Future<NetworkState> network({bool force = false}) async {
    // Read fresh every time; nothing is remembered between calls.
    final link = await networkLink();
    if (!link.linkUp) return link;
    // NetworkManager's own CONNECTIVITY is only re-evaluated every few
    // minutes and may be stale or "unknown", so it is not read at all. A
    // forced check just brings it up to date for the rest of the system; the
    // probe decides.
    final check = force
        ? _stdout(
            'nmcli',
            ['networking', 'connectivity', 'check'],
            timeout: const Duration(seconds: 6),
          ).then<void>((_) {}, onError: (_) {})
        : Future<void>.value();
    final reached = await reachable();
    await check;
    return link.withOnline(reached);
  }

  @override
  Stream<void> watchNetwork() {
    Process? p;
    var closed = false;
    late final StreamController<void> c;
    c = StreamController<void>(
      onListen: () async {
        try {
          p = await Process.start('nmcli', ['monitor']);
        } on ProcessException {
          await c.close();
          return;
        }
        if (closed) {
          p!.kill();
          return;
        }
        unawaited(p!.stderr.drain<void>());
        p!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (_) => c.add(null),
              onDone: () {
                if (!closed) c.close();
              },
            );
      },
      onCancel: () {
        closed = true;
        p?.kill();
      },
    );
    return c.stream;
  }

  @override
  Future<List<WifiAp>> scanWifi() async => parseWifiList(
    await _stdout('nmcli', [
      '-t',
      '-f',
      'IN-USE,SSID,SIGNAL,SECURITY',
      'device',
      'wifi',
      'list',
      '--rescan',
      'yes',
    ], timeout: const Duration(seconds: 30)),
  );

  @override
  Future<void> connectWifi(String ssid, {String? psk}) async {
    // `--ask` makes nmcli read the password from stdin instead of taking it
    // from the command line, where every local user could see it.
    // TODO(hardware): check on real hardware that nmcli --ask reads a piped
    // stdin on the ISO's NetworkManager version.
    if (ssid.isEmpty || ssid.startsWith('-')) {
      throw const InstallerException('Cannot join this network.');
    }
    final Process p;
    try {
      p = await Process.start('nmcli', [
        '-w',
        '40',
        '--ask',
        'device',
        'wifi',
        'connect',
        ssid,
      ]);
    } on ProcessException {
      throw const InstallerException('nmcli is not available on this system.');
    }
    unawaited(p.stdout.drain<void>());
    unawaited(p.stderr.drain<void>());
    if (psk != null) p.stdin.writeln(psk);
    await p.stdin.close().catchError((_) {});
    final int rc;
    try {
      rc = await p.exitCode.timeout(const Duration(seconds: 50));
    } on TimeoutException {
      p.kill();
      throw const InstallerException(
        'The connection took too long. Try again.',
      );
    }
    if (rc != 0) {
      throw InstallerException(
        psk == null
            ? 'Could not connect to "$ssid".'
            : 'Could not connect to "$ssid". Check the password and try again.',
      );
    }
  }

  @override
  Future<List<DiskInfo>> disks() async =>
      parseLsblk(await _stdout('lsblk', lsblkArgs));

  @override
  Future<List<StoreApp>> catalog() async {
    if (!File(catalogPath).existsSync()) return fallbackCatalog();
    try {
      final apps = [
        for (final a in loadCatalogIndex(catalogPath))
          if (a.installer) a,
      ];
      if (apps.isNotEmpty) return apps;
    } on FormatException {
      // An index this installer does not understand: offer the fallback.
    } on FileSystemException {
      // Same.
    }
    return fallbackCatalog();
  }

  @override
  Future<InstallerInfo> info() async {
    // Offline and instant: only what is built into the installer.
    final out = await _stdout(installBinary, const [
      '--info',
    ], timeout: const Duration(seconds: 10));
    final line = out
        .split('\n')
        .lastWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    try {
      return parseInstallerInfo(line);
    } on FormatException {
      throw const InstallerException(
        'hinteros-install --info gave an answer this installer cannot read.',
        code: 'internal',
      );
    }
  }

  /// The backend cuts its own network steps off after 120 s in total; this
  /// is only a guard against a hung process.
  static const checkNewerTimeout = Duration(seconds: 150);

  @override
  Future<NewerCheck> checkNewer({InstallChannel? channel}) async {
    final ProcessResult r;
    try {
      r = await Process.run(
        installBinary,
        [
          '--check-newer',
          if (channel != null) ...['--channel', channel.name],
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(checkNewerTimeout);
    } on ProcessException {
      throw const InstallerException(
        'hinteros-install is not available on this system.',
        code: 'internal',
      );
    } on TimeoutException {
      throw const InstallerException(
        'The check for a newer HinterOS took too long.',
        code: 'timeout',
      );
    }
    // stdout is one JSON line; stderr is text for people and is not kept.
    final line = (r.stdout as String)
        .split('\n')
        .lastWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    if (r.exitCode == 0) {
      try {
        return parseNewerCheck(line);
      } on FormatException {
        throw const InstallerException(
          'The check for a newer HinterOS gave an answer this installer '
          'cannot read.',
          code: 'internal',
        );
      }
    }
    final e = parseProgressLine(line);
    throw InstallerException(
      e?.message ??
          'The check for a newer HinterOS failed '
              '(status ${r.exitCode}).',
      code: e?.code,
    );
  }

  InstallRun _run(InstallPlan plan, List<String> args) {
    final events = StreamController<InstallEvent>();
    final done = Completer<int>();
    unawaited(() async {
      try {
        final p = await Process.start(installBinary, ['--plan', '-', ...args]);
        // The plan, with the password, goes in through stdin only.
        p.stdin.add(plan.encode());
        await p.stdin.close().catchError((_) {});
        // The tools' own output is in the log file; stderr is not kept here.
        unawaited(p.stderr.drain<void>());
        await events.addStream(progressEvents(p.stdout));
        done.complete(await p.exitCode);
      } on ProcessException {
        events.add(
          const InstallEvent(
            stage: 'validate',
            percent: 0,
            level: InstallLevel.error,
            message: 'hinteros-install is not available on this system.',
            code: 'internal',
          ),
        );
        done.complete(1);
      } catch (_) {
        done.complete(1);
      } finally {
        await events.close();
      }
    }());
    return InstallRun(events.stream, done.future);
  }

  @override
  InstallRun validate(InstallPlan plan) => _run(plan, ['--validate-only']);

  @override
  InstallRun install(InstallPlan plan) => _run(plan, const []);

  @override
  Future<void> reboot() async {
    await Process.run('systemctl', ['reboot']);
  }
}

/// GET https://cache.nixos.org/nix-cache-info; true on a 2xx answer.
Future<bool> _probeCache() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client
        .getUrl(Uri.parse('https://cache.nixos.org/nix-cache-info'))
        .timeout(const Duration(seconds: 5));
    final res = await req.close().timeout(const Duration(seconds: 5));
    await res.drain<void>().timeout(const Duration(seconds: 5));
    return res.statusCode >= 200 && res.statusCode < 300;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
