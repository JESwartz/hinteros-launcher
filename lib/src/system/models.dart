/// Data types of the system layer: what the Settings -> System sections, the
/// update reminders, the progress screen and the Store show.
///
/// These mirror `hinteros-docs/design/system-api.md` (privileged service,
/// relayed by the session daemon) and `design/catalog.md` (index entries), but
/// the launcher only depends on these types and the repository interfaces in
/// `repositories.dart`, not on the wire schema.
library;

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------- errors

enum SystemErrorKind {
  /// 3001: the service is down or its version does not match.
  unavailable,

  /// 3002
  permissionDenied,

  /// 3004: memory or disk check failed.
  insufficientResources,

  /// 3005: another job runs, or it is past the point of cancelling.
  jobBusy,

  /// 3006
  rateLimited,

  /// 3007
  stateConflict,

  /// 3008: the home lab or cache cannot be reached.
  updateUnreachable,

  /// 3009: unsigned, unknown signer, not a fast-forward.
  updateVerificationFailed,

  /// 3010
  notFound,

  /// 3011: downgrade without acknowledgement.
  needsAcknowledgement,

  /// The admin password was wrong (polkit auth_admin said no).
  wrongPassword,

  /// 3012: polkit wants the admin password and the launcher cannot pass it
  /// on yet (no polkit authentication agent). `data['action']` names the
  /// polkit action.
  authenticationRequired,

  /// Wi-Fi / Bluetooth failures (NetworkManager, BlueZ).
  deviceFailed,

  /// -32602
  invalidParams,

  /// The requested state already holds (a method answered `job_id: null`).
  nothingToDo,

  /// Anything else that went wrong.
  failed,
}

class SystemException implements Exception {
  const SystemException(this.kind, this.message, {this.data = const {}});

  final SystemErrorKind kind;
  final String message;
  final Map<String, Object?> data;

  @override
  String toString() => 'SystemException(${kind.name}): $message';
}

// ---------------------------------------------------------------- jobs

enum JobKind {
  update('Updating HinterOS'),
  updateCheck('Checking for updates'),
  rollback('Rolling back'),
  rebuild('Applying changes'),
  hardwareRedetect('Detecting hardware'),
  channel('Switching channel'),
  base('Switching software base'),
  ssh('Changing remote access'),
  install('Installing'),
  remove('Removing');

  const JobKind(this.title);
  final String title;

  /// Stages a job of this kind can report, in order (system-api.md "Job
  /// model": not every job has every stage).
  List<JobStage> get stages => switch (this) {
    update || channel || base => JobStage.values,
    updateCheck => const [
      JobStage.preparing,
      JobStage.fetching,
      JobStage.verifying,
    ],
    rollback => const [
      JobStage.preparing,
      JobStage.activating,
      JobStage.finishing,
    ],
    install => const [
      JobStage.preparing,
      JobStage.downloading,
      JobStage.building,
      JobStage.activating,
      JobStage.finishing,
    ],
    rebuild || hardwareRedetect || ssh || remove => const [
      JobStage.preparing,
      JobStage.building,
      JobStage.activating,
      JobStage.finishing,
    ],
  };

  /// Whether the session may restart when this finishes (the switch can
  /// change the session daemon itself).
  bool get mayRestartSession =>
      this == update ||
      this == rollback ||
      this == rebuild ||
      this == hardwareRedetect ||
      this == channel ||
      this == base;
}

enum JobStage {
  preparing('Preparing'),
  fetching('Fetching the update'),
  verifying('Checking the signature'),
  evaluating('Working out what changes'),
  downloading('Downloading'),
  building('Building'),
  activating('Switching over'),
  finishing('Finishing');

  const JobStage(this.label);
  final String label;

  /// `jobs.cancel` is allowed until the activation stage starts.
  bool get cancellable => index < activating.index;
}

/// What `jobs.get` / `job_*` events add up to for one job.
@immutable
class JobSnapshot {
  const JobSnapshot({
    required this.jobId,
    required this.kind,
    this.stage = JobStage.preparing,
    this.percent,
    this.detail,
    this.finished = false,
    this.ok = false,
    this.cancelled = false,
    this.error,
    this.sessionRestartRequired = false,
    this.result,
  });

  final String jobId;
  final JobKind kind;
  final JobStage stage;

  /// Only where it means something (downloading).
  final int? percent;
  final String? detail;
  final bool finished;
  final bool ok;
  final bool cancelled;
  final JobError? error;
  final bool sessionRestartRequired;

  /// `job_finished.result` (an `update_check` job: the check result as JSON).
  final Map<String, dynamic>? result;

  bool get running => !finished;
  bool get failed => finished && !ok && !cancelled;
  bool get canCancel => running && stage.cancellable;

  JobSnapshot copyWith({
    JobKind? kind,
    JobStage? stage,
    int? percent,
    bool clearPercent = false,
    String? detail,
    bool? finished,
    bool? ok,
    bool? cancelled,
    JobError? error,
    bool? sessionRestartRequired,
    Map<String, dynamic>? result,
  }) => JobSnapshot(
    jobId: jobId,
    kind: kind ?? this.kind,
    stage: stage ?? this.stage,
    percent: clearPercent ? null : (percent ?? this.percent),
    detail: detail ?? this.detail,
    finished: finished ?? this.finished,
    ok: ok ?? this.ok,
    cancelled: cancelled ?? this.cancelled,
    error: error ?? this.error,
    sessionRestartRequired:
        sessionRestartRequired ?? this.sessionRestartRequired,
    result: result ?? this.result,
  );
}

/// `job_finished.error` (3003 job_failed and friends).
@immutable
class JobError {
  const JobError({required this.message, this.stage, this.logHint, this.kind});

  final String message;

  /// The stage that failed.
  final JobStage? stage;

  /// Where to look (a journal unit); shown as a hint, never opened.
  final String? logHint;
  final SystemErrorKind? kind;
}

/// A started job: follow it with [JobsRepository.watch].
@immutable
class JobHandle {
  const JobHandle(this.jobId, this.kind);

  final String jobId;
  final JobKind kind;
}

// ---------------------------------------------------------------- updates

enum UpdateChannel {
  beta('Beta', 'Gets changes first.'),
  stable('Stable', 'Changes arrive after they have run on Beta.');

  const UpdateChannel(this.label, this.blurb);
  final String label;
  final String blurb;
}

enum NixBase {
  unstable('Latest', 'Newest software (nixos-unstable).'),
  stable('Stable', 'Older, steadier software. Switching down needs a warning.');

  const NixBase(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// The `security` trailer's severity of a signed update commit.
enum SecuritySeverity {
  low('Low'),
  moderate('Moderate'),
  high('High'),
  critical('Critical'),
  unknown('Unrated');

  const SecuritySeverity(this.label);
  final String label;

  static SecuritySeverity parse(String? s) => switch (s?.toLowerCase()) {
    'low' => low,
    'moderate' || 'medium' => moderate,
    'high' => high,
    'critical' => critical,
    _ => unknown,
  };
}

@immutable
class AvailableUpdate {
  const AvailableUpdate({
    required this.rev,
    required this.version,
    required this.date,
    required this.summary,
    this.severity,
    this.signer = '',
    this.catalogChanged = false,
  });

  /// 40 hex characters; what `update.apply` takes.
  final String rev;

  /// What to call it on screen.
  final String version;
  final DateTime date;
  final String summary;

  /// Non-null for a security update.
  final SecuritySeverity? severity;
  final String signer;

  /// The update carries a new catalog revision (more Store apps).
  final bool catalogChanged;

  bool get isSecurity => severity != null;
}

@immutable
class UpdateStatus {
  const UpdateStatus({
    required this.currentVersion,
    required this.currentRev,
    this.available,
    this.checkedAt,
  });

  final String currentVersion;
  final String currentRev;
  final AvailableUpdate? available;

  /// Null: never checked since the box started.
  final DateTime? checkedAt;

  bool get behind => available != null;
}

@immutable
class Generation {
  const Generation({
    required this.generation,
    required this.date,
    this.rev,
    this.current = false,
    this.booted = false,
  });

  final int generation;
  final DateTime date;

  /// Null when the generation has no config snapshot.
  final String? rev;
  final bool current;
  final bool booted;
}

// ---------------------------------------------------------------- system

enum PowerAction {
  sleep('Sleep'),
  restart('Restart'),
  shutdown('Shut down');

  const PowerAction(this.label);
  final String label;
}

@immutable
class SystemInfo {
  const SystemInfo({
    required this.version,
    required this.base,
    required this.hostname,
    this.channel,
    this.rev,
    this.generation,
    this.dev = false,
    this.hostKeyFingerprints = const [],
  });

  final String version;

  /// Null without a locked channel (the dev box).
  final UpdateChannel? channel;
  final NixBase base;
  final String? rev;
  final int? generation;
  final String hostname;
  final bool dev;
  final List<String> hostKeyFingerprints;
}

/// SSH state. For now SSH is plain username and password: you log in as the
/// admin account with its password, over the local network. (Key import and
/// key-only login are in the backlog.)
@immutable
class SshState {
  const SshState({required this.enabled});

  final bool enabled;
}

// ---------------------------------------------------------------- network

@immutable
class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    this.secured = true,
    this.connected = false,
    this.saved = false,
  });

  final String ssid;

  /// 0..100
  final int signal;
  final bool secured;
  final bool connected;

  /// The box has a stored connection (no password needed to join).
  final bool saved;

  /// 1..4 bars.
  int get bars => signal >= 75
      ? 4
      : signal >= 50
      ? 3
      : signal >= 25
      ? 2
      : 1;

  String get strength => switch (bars) {
    4 => 'Excellent',
    3 => 'Good',
    2 => 'Fair',
    _ => 'Weak',
  };
}

@immutable
class NetworkStatus {
  const NetworkStatus({
    this.wifiEnabled = true,
    this.ethernet = false,
    this.wifiSsid,
    this.address,
  });

  final bool wifiEnabled;
  final bool ethernet;
  final String? wifiSsid;
  final String? address;

  bool get online => ethernet || wifiSsid != null;
}

// ---------------------------------------------------------------- bluetooth

enum BtKind {
  controller('Controller'),
  headset('Headset'),
  speaker('Speaker'),
  keyboard('Keyboard'),
  other('Other');

  const BtKind(this.label);
  final String label;
}

@immutable
class BtDevice {
  const BtDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.paired = false,
    this.connected = false,
  });

  /// The adapter address.
  final String id;
  final String name;
  final BtKind kind;
  final bool paired;
  final bool connected;

  BtDevice copyWith({bool? paired, bool? connected}) => BtDevice(
    id: id,
    name: name,
    kind: kind,
    paired: paired ?? this.paired,
    connected: connected ?? this.connected,
  );
}

// ---------------------------------------------------------------- display, audio

@immutable
class DisplayMode {
  const DisplayMode({
    required this.width,
    required this.height,
    required this.refreshHz,
    this.current = false,
    this.preferred = false,
  });

  final int width;
  final int height;
  final double refreshHz;
  final bool current;
  final bool preferred;

  String get id => '${width}x$height@${refreshHz.toStringAsFixed(2)}';

  String get label {
    final hz = refreshHz == refreshHz.roundToDouble()
        ? refreshHz.round().toString()
        : refreshHz.toStringAsFixed(2);
    return '$width x $height at $hz Hz';
  }

  String get name => switch ((width, height)) {
    (3840, 2160) => '4K',
    (2560, 1440) => '1440p',
    (1920, 1080) => '1080p',
    (1280, 720) => '720p',
    _ => '${height}p',
  };
}

@immutable
class AudioOutput {
  const AudioOutput({
    required this.id,
    required this.name,
    this.current = false,
  });

  final String id;
  final String name;
  final bool current;
}

@immutable
class AudioState {
  const AudioState({
    required this.outputs,
    required this.volume,
    this.muted = false,
  });

  final List<AudioOutput> outputs;

  /// 0..100
  final int volume;
  final bool muted;
}

// ---------------------------------------------------------------- store

enum StoreCategory {
  games('Games'),
  video('Video'),
  web('Web'),
  tools('Tools'),
  other('Other');

  const StoreCategory(this.label);
  final String label;

  /// An unknown category means Other (catalog.md).
  static StoreCategory parse(String? s) =>
      values.firstWhere((c) => c.name == s, orElse: () => other);
}

/// Vendor terms shown in full on the box before install (catalog.md,
/// "Full vendor terms on the box").
@immutable
class VendorTerms {
  const VendorTerms({
    required this.vendor,
    required this.version,
    required this.sourceUrl,
    required this.text,
  });

  final String vendor;

  /// Recorded with the acceptance.
  final String version;
  final String sourceUrl;
  final String text;
}

/// Where an app's icon comes from, resolved at runtime (catalog.md "Icons").
@immutable
class StoreIcon {
  const StoreIcon({this.desktopId, this.siteUrl, this.firefoxProfile = false});

  final String? desktopId;
  final String? siteUrl;
  final bool firefoxProfile;
}

/// One catalog index entry.
@immutable
class StoreApp {
  const StoreApp({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.sizeMiB,
    this.description = '',
    this.depends = const [],
    this.terms,
    this.onIso = false,
    this.featured = false,
    this.icon = const StoreIcon(),
    this.removeDataWarning,
    this.homepage = '',
  });

  final String id;
  final String name;
  final String summary;
  final String description;
  final StoreCategory category;
  final int sizeMiB;

  /// Ids of apps installed with this one (transitively resolved by the
  /// repository, so these are the extra ones).
  final List<String> depends;
  final VendorTerms? terms;

  /// Part of the installer ISO (no network download needed).
  final bool onIso;
  final bool featured;
  final StoreIcon icon;

  /// Shown when removing with data deletion (Steam: installed games go too).
  final String? removeDataWarning;
  final String homepage;

  bool get hasTerms => terms != null;

  String get sizeLabel => sizeMiB >= 1000
      ? '${(sizeMiB / 1024).toStringAsFixed(1)} GB'
      : '$sizeMiB MB';
}

/// The first [n] characters of a revision, for display ("" for none).
String shortRev(String? rev, [int n = 7]) =>
    rev == null ? '' : (rev.length > n ? rev.substring(0, n) : rev);
