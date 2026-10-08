/// Handing over to the current system's launcher after an update.
///
/// The launcher is not a systemd unit: gamescope runs it (through the
/// session's home loop, hinteros `nixos/modules/session.nix`), so a system
/// switch that restarts the session daemon leaves this process running, with
/// the old generation's code. When the new daemon speaks another session API
/// the handshake is refused forever ("API version mismatch").
///
/// The home loop runs the launcher that `HINTEROS_HOME_LINK`
/// (`/run/current-system/hinteros-console/home`, updated by every switch)
/// points to, tells it the fully resolved path it started
/// (`HINTEROS_HOME_EXE`) and runs the link again whenever the launcher exits with `HINTEROS_HOME_RELAUNCH` (75). So
/// the launcher exits with that code when the system has a *different*
/// launcher than this one and either
///
/// - the daemon refuses it for its API version, or
/// - the daemon connection came back after being lost (the daemon was
///   restarted, normally by the switch, which also ended the running apps):
///   picking up a launcher-only fix costs nothing then.
///
/// With the same launcher installed (a downgraded daemon, a daemon crash) it
/// stays and keeps retrying, as before. Without the home loop (older sessions,
/// `--mock`, development) the variables are missing and nothing happens.
library;

import 'dart:async';
import 'dart:io' as io;

import '../api/daemon.dart';
import '../log.dart';

class HomeRelaunch {
  HomeRelaunch({
    required this.code,
    required this.link,
    required this.running,
    String Function(String path)? resolve,
    void Function(int code)? exit,
  }) : _resolve = resolve ?? _resolveLink,
       _exit = exit ?? io.exit;

  /// From the variables the home loop sets; null fields when it did not.
  factory HomeRelaunch.fromEnvironment([Map<String, String>? env]) {
    env ??= io.Platform.environment;
    String? nonEmpty(String name) {
      final v = env![name];
      return v == null || v.isEmpty ? null : v;
    }

    return HomeRelaunch(
      code: int.tryParse(nonEmpty('HINTEROS_HOME_RELAUNCH') ?? ''),
      link: nonEmpty('HINTEROS_HOME_LINK'),
      running: nonEmpty('HINTEROS_HOME_EXE'),
    );
  }

  /// Exit code that makes the home loop start the link again.
  final int? code;

  /// The current system's launcher (a symlink).
  final String? link;

  /// The fully resolved launcher this process was started as.
  final String? running;

  final String Function(String path) _resolve;
  final void Function(int code) _exit;

  static String _resolveLink(String path) =>
      io.File(path).resolveSymbolicLinksSync();

  /// Whether the system now has another launcher than this one.
  bool get otherInstalled {
    final link = this.link, running = this.running;
    if (code == null || link == null || running == null) return false;
    try {
      return _resolve(link) != running;
    } catch (_) {
      // No link (yet): stay.
      return false;
    }
  }

  /// Exits for the home loop if [why] and another launcher is installed.
  bool _maybeExit(String why) {
    if (!otherInstalled) return false;
    logSink(
      'hinteros-launcher: $why and the system has another launcher '
      '(${_resolve(link!)}, this is $running): exiting with $code so the '
      'session starts it',
    );
    _exit(code!);
    return true;
  }

  /// Follows [changes] (starting from [initial]) and exits as described
  /// above. Cancel the subscription to stop.
  StreamSubscription<ConnectionStatus> watch(
    ConnectionStatus initial,
    Stream<ConnectionStatus> changes,
  ) {
    var connectedBefore = initial is Connected;
    var lost = false;
    var done = false;
    return changes.listen((s) {
      if (done) return;
      switch (s) {
        case VersionMismatch():
          done = _maybeExit(
            'the session daemon speaks API ${s.serverApiVersion}, '
            'this launcher ${s.clientApiVersion}',
          );
        case Connected():
          if (connectedBefore && lost) {
            done = _maybeExit('the session daemon was restarted');
          }
          connectedBefore = true;
          lost = false;
        case Unreachable() || Connecting():
          lost = lost || connectedBefore;
      }
    });
  }
}
