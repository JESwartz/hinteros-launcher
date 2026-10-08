/// What `hinteros-install` prints on stdout: one JSON object per line,
/// `{stage, percent, level, message, code?}` plus, all optional: `phase`
/// (`system`|`apps`), `step_percent` (0..100 of the current stage or app
/// alone; absent = unmeasurable), `app`, `app_index`, `app_total`; and what its exit status means
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
  int? whole(Object? v) => v is num ? v.round() : null;
  final sp = whole(j['step_percent']);
  final ai = whole(j['app_index']);
  final at = whole(j['app_total']);
  return InstallEvent(
    phase: j['phase'] == 'apps' ? InstallSection.apps : InstallSection.system,
    app: app is String && app.isNotEmpty ? app : null,
    appIndex: ai != null && ai > 0 ? ai : null,
    appTotal: at != null && at > 0 ? at : null,
    stepPercent: sp?.clamp(0, 100),
    failedApps: failed is List ? failed.whereType<String>().toList() : const [],
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
  'validate': 'Checking your choices',
  'partition': 'Erasing and preparing the disk',
  'facter': 'Looking at this computer\'s hardware',
  'config': 'Writing the settings',
  'install': 'Installing HinterOS',
  'snapshot': 'Checking the result',
  'finalize': 'Finishing up',
  'done': 'Done',
};

/// Stages shown as a checklist, in order (`done` is the end, not a step).
const installStages = [
  'validate',
  'partition',
  'facter',
  'config',
  'install',
  'snapshot',
  'finalize',
];

String stageLabel(String stage) => _stageLabels[stage] ?? 'Working';

/// A plain explanation for a backend error or warning code, with what to do
/// about it. Unknown codes get a general sentence (the backend's own message
/// is shown as well).
String explainCode(String? code) => switch (code) {
  'not-root' => 'The installer was not started with the rights it needs.',
  'plan-unreadable' || 'plan-invalid' || 'unknown-field' =>
    'The installer could not understand the choices it was '
        'given. This is a bug in the installer.',
  'disk-missing' || 'disk-not-found' =>
    'The disk you picked is not there any more. Was it '
        'unplugged? Go back and pick a disk again.',
  'disk-not-a-disk' =>
    'What you picked is not a whole disk. Go back and '
        'choose another one.',
  'disk-in-use' =>
    'The disk you picked is in use, perhaps because it is '
        'the installer USB stick. Choose a different disk.',
  'disk-too-small' =>
    'The disk you picked is too small. HinterOS needs a '
        'disk of at least 16 GB.',
  'mnt-in-use' =>
    'Something from an earlier try is still in the way. '
        'Restart the installer and try again.',
  'hostname-invalid' =>
    'The computer name is not allowed. Go back to '
        'the options and change it.',
  'admin-missing' || 'admin-password-missing' =>
    'The admin account needs a password. Go back '
        'and set one.',
  'admin-password-ambiguous' ||
  'admin-password-invalid' ||
  'admin-hash-invalid' =>
    'The admin password cannot be used. Go back and '
        'choose another.',
  'admin-user-invalid' || 'admin-user-reserved' =>
    'The admin user name is not allowed. Go back and '
        'choose another.',
  'ssh-invalid' || 'channel-invalid' || 'base-invalid' || 'network-invalid' =>
    'One of the options is not valid. This is a bug in '
        'the installer.',
  'apps-invalid' || 'app-unknown' || 'app-duplicate' =>
    'The app list is not valid. Go back to the apps and '
        'check it.',
  'app-needs-network' =>
    'Some of the apps you picked are downloaded, and '
        'this computer is not online. Connect to the internet, or untick '
        'those apps (they can be added later from the Store).',
  'no-network' =>
    'The installer needs the internet for the apps you '
        'picked, but could not reach it. Check the cable or the Wi-Fi.',
  'app-failed' =>
    'An app could not be installed. HinterOS itself is fine, and the app '
        'can be added later from the Store.',
  'wifi-invalid' => 'The Wi-Fi details cannot be used.',
  'wifi-failed' =>
    'The Wi-Fi connection did not work. The install goes on '
        'without it.',
  'not-uefi' =>
    'This computer did not start the installer in UEFI mode. '
        'HinterOS needs UEFI: check the firmware boot settings and start '
        'from the USB stick again.',
  'already-running' => 'An install is already running.',
  'low-memory' => 'This computer has little memory. The install may fail.',
  'mount-failed' =>
    'The new disk could not be set up. The disk may be '
        'faulty.',
  'step-failed' => 'A step of the install failed. The log has the details.',
  'hash-failed' => 'The admin password could not be stored.',
  'copy-failed' =>
    'Files could not be copied to the new disk. It may be '
        'full or faulty.',
  'install-failed' =>
    'Installing the system failed. If you are online this '
        'can be a problem with a download: trying again often helps.',
  'snapshot-missing' => 'The installed system is incomplete. Try again.',
  'snapshot-differs' =>
    'A setting was restored to match the installed '
        'system. Nothing for you to do.',
  'facter-failed' =>
    'The hardware could not be examined, so the system '
        'uses general drivers. It should still work.',
  'unmount-failed' =>
    'The disk could not be released cleanly. Wait a '
        'moment before you restart.',
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
