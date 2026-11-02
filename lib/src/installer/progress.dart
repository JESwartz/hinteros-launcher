/// What `hinteros-install` prints on stdout: one JSON object per line,
/// `{stage, percent, level, message, code?}` plus, all optional: `phase`
/// (`system`|`apps`), `step_percent` (0..100 of the current stage or app
/// alone; absent = unmeasurable), `app`, `app_index`, `app_total`, `build`,
/// `build_index`, `build_total`, `build_percent`; and what its exit status means
/// (0 done, 2 refused before anything was touched, 1 failed part-way).
library;

import 'dart:async';
import 'dart:convert';

/// Where the backend writes its tool output (shown on error screens).
const installLogPath = '/var/log/hinteros-install.log';

enum InstallLevel { info, warn, error }

/// The install runs in two stages: the HinterOS base system, then the apps
/// the person picked.
enum InstallSection { system, apps }

class InstallEvent {
  const InstallEvent({
    required this.stage,
    required this.percent,
    required this.level,
    required this.message,
    this.code,
    this.phase = InstallSection.system,
    this.app,
    this.appIndex,
    this.appTotal,
    this.stepPercent,
    this.failedApps = const [],
    this.rev,
    this.version,
    this.build,
    this.buildIndex,
    this.buildTotal,
    this.buildPercent,
  });

  final String stage;
  final int percent;
  final InstallLevel level;
  final String message;

  /// Set on error lines (and on some warnings): see [explainCode].
  final String? code;

  /// Which of the two installs this line belongs to. Lines without a `phase`
  /// (older backends) count as the system.
  final InstallSection phase;

  /// The app an apps-phase line is about, when it names one.
  final String? app;

  /// With [app]: its 1-based position and how many apps there are.
  final int? appIndex;
  final int? appTotal;

  /// How far the current stage (or, with [app], that app) is, 0..100, on its
  /// own; null when that cannot be measured (an indeterminate bar).
  final int? stepPercent;

  /// On the final `done` line: the apps that could not be installed.
  final List<String> failedApps;

  /// On the final `done` line: the revision and release version that were
  /// installed (the installer's own or a newer one).
  final String? rev;
  final String? version;

  /// On `build` lines: the package being built now (absent when nothing is
  /// being built), its 1-based position and how many there are.
  final String? build;
  final int? buildIndex;
  final int? buildTotal;

  /// With [build]: how far that package alone is, 0..99, from its build
  /// phase; null when the backend cannot tell (no phase yet, or a builder
  /// without phases).
  final int? buildPercent;

  bool get isError => level == InstallLevel.error;
  bool get isWarning => level == InstallLevel.warn;
  bool get isDone => stage == 'done' && level != InstallLevel.error;

  @override
  String toString() => 'InstallEvent($stage $percent% $level $code)';
}

/// One stdout line, or null when it is not a progress object (blank,
/// malformed, wrong shape): the UI ignores those rather than failing.
InstallEvent? parseProgressLine(String line) {
  final s = line.trim();
  if (s.isEmpty || !s.startsWith('{')) return null;
  final Object? j;
  try {
    j = jsonDecode(s);
  } on FormatException {
    return null;
  }
  if (j is! Map) return null;
  final stage = j['stage'];
  final message = j['message'];
  if (stage is! String || message is! String) return null;
  final p = j['percent'];
  final percent = p is num ? p.round().clamp(0, 100) : 0;
  final level = switch (j['level']) {
    'warn' => InstallLevel.warn,
    'error' => InstallLevel.error,
    _ => InstallLevel.info,
  };
  final code = j['code'];
  final app = j['app'];
  final failed = j['failed_apps'];
  final rev = j['rev'];
  final version = j['version'];
  int? whole(Object? v) => v is num ? v.round() : null;
  final sp = whole(j['step_percent']);
  final ai = whole(j['app_index']);
  final at = whole(j['app_total']);
  final build = j['build'];
  final bi = whole(j['build_index']);
  final bt = whole(j['build_total']);
  final bp = whole(j['build_percent']);
  return InstallEvent(
    phase: j['phase'] == 'apps' ? InstallSection.apps : InstallSection.system,
    app: app is String && app.isNotEmpty ? app : null,
    appIndex: ai != null && ai > 0 ? ai : null,
    appTotal: at != null && at > 0 ? at : null,
    stepPercent: sp?.clamp(0, 100),
    failedApps: failed is List ? failed.whereType<String>().toList() : const [],
    rev: rev is String && rev.isNotEmpty ? rev : null,
    version: version is String && version.isNotEmpty ? version : null,
    build: build is String && build.isNotEmpty ? build : null,
    buildIndex: bi != null && bi > 0 ? bi : null,
    buildTotal: bt != null && bt > 0 ? bt : null,
    buildPercent: build is String && build.isNotEmpty ? bp?.clamp(0, 99) : null,
    stage: stage,
    percent: percent,
    level: level,
    message: message,
    code: code is String && code.isNotEmpty ? code : null,
  );
}

/// stdout bytes to events.
Stream<InstallEvent> progressEvents(Stream<List<int>> stdout) async* {
  final lines = stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final l in lines) {
    final e = parseProgressLine(l);
    if (e != null) yield e;
  }
}

/// A running backend call: its progress and, when it ends, its exit status.
class InstallRun {
  InstallRun(this.events, this.exitCode);

  final Stream<InstallEvent> events;

  /// Completes after [events] ended. 0, 1 or 2 as documented; anything else
  /// (a signal, "not found") counts as 1.
  final Future<int> exitCode;
}

/// The stages in order, in plain words.
const _stageLabels = {
  'validate': 'Verifying install configuration',
  'fetch': 'Downloading HinterOS',
  'partition': 'Erasing disk',
  'mount': 'Preparing disk',
  'facter': 'Checking hardware',
  'config': 'Writing settings',
  // Older backends: the packages, the build and the boot loader in one.
  'install': 'Installing HinterOS',
  'build': 'Building HinterOS',
  'bootloader': 'Installing boot loader',
  'snapshot': 'Validating system',
  'finalize': 'Finishing',
  'done': 'Done',
};

/// Stages shown as a checklist, in order (`done` is the end, not a step).
const installStages = [
  'validate',
  'partition',
  'facter',
  'config',
  'packages',
  'build',
  'bootloader',
  'snapshot',
  'finalize',
];

/// The same for a newer HinterOS than the installer's: it is downloaded
/// first.
const newerInstallStages = [
  'validate',
  'fetch',
  'partition',
  'facter',
  'config',
  'packages',
  'build',
  'bootloader',
  'snapshot',
  'finalize',
];

/// The same for a plan that keeps the data: nothing is partitioned.
const keepInstallStages = [
  'validate',
  'mount',
  'facter',
  'config',
  'packages',
  'build',
  'bootloader',
  'snapshot',
  'finalize',
];

/// [stage] in plain words. [download]: the packages come from the internet
/// (a newer HinterOS), not from the USB stick.
String stageLabel(String stage, {bool download = false}) => stage == 'packages'
    ? (download ? 'Downloading packages' : 'Copying packages')
    : _stageLabels[stage] ?? 'Working';

/// A plain explanation for a backend error or warning code, with what to do
/// about it. Unknown codes get a general sentence (the backend's own message
/// is shown as well).
String explainCode(String? code) => switch (code) {
  'not-root' => 'The installer does not have the rights it needs.',
  'plan-unreadable' ||
  'plan-invalid' ||
  'unknown-field' ||
  'keep-data-invalid' ||
  'keep-data-field' ||
  'disk-seq-invalid' =>
    'The installer could not read your choices. This is an installer bug.',
  'disk-missing' || 'disk-not-found' =>
    'The disk you chose is not found. Make sure it is connected, then go '
        'back and choose a disk again.',
  'disk-changed' => 'The disk changed. Select the disk again.',
  'disk-not-a-disk' =>
    'This is not a whole disk. Go back and choose another one.',
  'disk-in-use' =>
    'The disk you chose is in use. It may be the installer USB stick. '
        'Choose a different disk.',
  'disk-too-small' =>
    'The disk you chose is too small. HinterOS needs at least 16 GB.',
  'mnt-in-use' =>
    'An earlier try is still in the way. Restart the installer and try '
        'again.',
  'hostname-invalid' =>
    'The computer name is not allowed. Go back to Options and change it.',
  'admin-missing' || 'admin-password-missing' =>
    'The admin account needs a password. Go back and set one.',
  'admin-password-ambiguous' ||
  'admin-password-invalid' ||
  'admin-hash-invalid' =>
    'The admin password cannot be used. Go back and choose another.',
  'admin-user-invalid' || 'admin-user-reserved' =>
    'The admin user name is not allowed. Go back and choose another.',
  'ssh-invalid' || 'channel-invalid' || 'base-invalid' || 'network-invalid' =>
    'One of the options is not valid. This is an installer bug.',
  'apps-invalid' ||
  'app-unknown' ||
  'app-duplicate' => 'The app list is not valid. Go back to Apps and check it.',
  'app-needs-network' =>
    'Some apps you chose need the internet, and this computer is not '
        'online. Connect to the internet, or untick those apps.',
  'no-network' =>
    'The apps you chose need the internet, but the installer cannot reach '
        'it. Check the cable or the Wi-Fi.',
  'app-failed' => 'An app did not install. Add it later from the Store.',
  'wifi-invalid' => 'The Wi-Fi details cannot be used.',
  'wifi-failed' =>
    'The Wi-Fi connection did not work. The install continues without it.',
  'not-uefi' =>
    'The installer did not start in UEFI mode. Turn on UEFI in the '
        'firmware settings, then start from the USB stick again.',
  'already-running' => 'An install is already running.',
  'low-memory' => 'This computer has little memory. The install may fail.',
  'mount-failed' => 'Could not set up the disk. It may be faulty.',
  'step-failed' => 'A step of the install failed. See the log.',
  'hash-failed' => 'The admin password could not be stored.',
  'copy-failed' =>
    'Could not copy files to the disk. It may be full or faulty.',
  'install-failed' =>
    'Installing the system failed. A download may have failed. Try again.',
  'snapshot-missing' => 'The installed system is incomplete. Try again.',
  'snapshot-differs' => 'A setting was changed to match the installed system.',
  'facter-failed' =>
    'Could not check the hardware. HinterOS uses general drivers.',
  'unmount-failed' =>
    'The disk was not released cleanly. Wait a moment before you restart.',
  'fetch-failed' =>
    'The newer HinterOS did not download. Check the internet connection.',
  'rev-not-tip' =>
    'The newer HinterOS changed on the server. Choose the version again.',
  'rev-needs-network' =>
    'The newer HinterOS needs the internet, and this computer is not online.',
  'rev-invalid' =>
    'The version you chose is not valid. This is an '
        'installer bug.',
  'unsigned' || 'unknown-signer' || 'not-fast-forward' =>
    'The newer HinterOS cannot be verified. Install the version on this '
        'USB stick.',
  'repo-unreachable' || 'timeout' =>
    'The HinterOS server did not answer. Check the internet connection.',
  'channel-missing' => 'The update channel is not on the HinterOS server.',
  'iso-rev-unknown' => 'This installer cannot install a newer HinterOS.',
  'keep-no-install' ||
  'keep-no-subvolumes' => 'This disk has no HinterOS install to keep.',
  'keep-not-btrfs' ||
  'keep-layout' => 'This installer cannot keep the data on this disk.',
  'keep-unreadable' ||
  'keep-state-unreadable' ||
  'keep-uuid-mismatch' => 'The HinterOS install on this disk cannot be read.',
  'keep-schema-newer' =>
    'The HinterOS install on this disk is newer than this installer. Use a '
        'newer installer.',
  'esp-failed' =>
    'Could not write the boot partition. Your files stay on the '
        'disk.',
  'internal' => 'The installer stopped unexpectedly.',
  _ => 'The install could not be completed.',
};

/// How a finished backend call ended.
enum InstallVerdict {
  /// Exit 0 and the last line was `done`.
  success,

  /// Exit 2: the plan or the machine was refused; nothing was touched.
  refused,

  /// Exit 1 (or anything else): failed part-way; the disk may be changed.
  failed,
}

/// Collects a run: warnings, the last event, the error if there was one.
class InstallOutcome {
  InstallOutcome({
    required this.verdict,
    required this.exitCode,
    required this.warnings,
    this.error,
  });

  final InstallVerdict verdict;
  final int exitCode;
  final List<InstallEvent> warnings;

  /// The error line (a synthetic one when the backend died without it).
  final InstallEvent? error;

  /// Judges a finished run from what it printed and how it exited.
  /// Exit 0 with an error line, or without a `done` line, is a failure:
  /// the status alone is not trusted to mean success.
  factory InstallOutcome.judge({
    required int exitCode,
    required InstallEvent? last,
    required List<InstallEvent> warnings,
    InstallEvent? error,
  }) {
    if (exitCode == 0 && error == null && last != null && last.isDone) {
      return InstallOutcome(
        verdict: InstallVerdict.success,
        exitCode: 0,
        warnings: warnings,
      );
    }
    final synthetic =
        error ??
        InstallEvent(
          stage: last?.stage ?? 'validate',
          percent: last?.percent ?? 0,
          level: InstallLevel.error,
          message: exitCode == 0
              ? 'The installer ended without saying it was done.'
              : 'The installer ended with status $exitCode.',
          code: 'internal',
        );
    return InstallOutcome(
      verdict: exitCode == 2 ? InstallVerdict.refused : InstallVerdict.failed,
      exitCode: exitCode,
      warnings: warnings,
      error: synthetic,
    );
  }
}

/// Follows [run] to its end, calling [onEvent] for every event.
Future<InstallOutcome> followRun(
  InstallRun run, {
  void Function(InstallEvent e)? onEvent,
}) async {
  final warnings = <InstallEvent>[];
  InstallEvent? last;
  InstallEvent? error;
  await for (final e in run.events) {
    last = e;
    if (e.isWarning) warnings.add(e);
    if (e.isError) error = e;
    onEvent?.call(e);
  }
  final rc = await run.exitCode;
  return InstallOutcome.judge(
    exitCode: rc,
    last: last,
    warnings: warnings,
    error: error,
  );
}
