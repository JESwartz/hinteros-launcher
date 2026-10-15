/// Data types of the system layer: what the Settings -> System sections, the
/// update reminders, the progress screen and the Store show.
///
/// These mirror `hinteros-docs/design/system-api.md` (privileged service,
/// relayed by the session daemon) and `design/catalog.md` (index entries), but
/// the launcher only depends on these types and the repository interfaces in
/// `repositories.dart`, not on the wire schema.
library;

import 'package:flutter/foundation.dart';

import 'storage.dart' show CleanupFrequency;

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

  /// 3013: an app to install conflicts with another one, or an app to
  /// remove is needed by another. `data`: `id`, `conflicts_with`.
  appConflict,

  /// 3014: an app to install has vendor terms whose current version was not
  /// accepted. `data`: `id`, `version`.
  termsRequired,

  /// 4002: a connection, pairing or mode change failed. `data['reason']`
  /// is for code (`not_applied`, `nothing_to_revert`, ...).
  deviceFailed,

  /// 4004: polkit refused the session user.
  notAuthorized,

  /// 4005: logind refuses suspend, reboot and power off while a system
  /// update is being applied.
  powerInhibited,

  /// -32602
  invalidParams,

  /// 3016: a PIN is missing or wrong. `data`: `pin` (`self`, `admin` or
  /// `target`), `retry_after_ms` while the backoff lock lasts.
  pinRequired,

  /// 3015: the box has the most profiles it can have. `data['max']`.
  profileLimit,

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
  remove('Removing'),
  appsRollback('Rolling back apps'),
  profileCreate('Creating the profile'),
  profileRemove('Removing the profile'),
  guest('Changing the guest'),
  starterSet('Saving the starter apps'),
  guestEnd('Ending the guest session'),

  /// 0.14: scanning what uses the disk (Settings -> Storage).
  storageMeasure('Scanning the disk'),

  /// 0.14: old system generations removed, then unused files deleted.
  cleanupSystem('Cleaning up the system'),

  /// 0.14: old app generations of every profile removed, then unused files
  /// deleted.
  cleanupProfiles('Cleaning up profiles'),

  /// 0.14: the automatic clean-up setting (a rebuild).
  cleanupSet('Saving the automatic clean-up'),

  /// 0.17: the tip of another channel verified before a switch.
  channelCheck('Checking the channel');

  const JobKind(this.title);
  final String title;

  /// Stages a job of this kind can report, in order (system-api.md "Job
  /// model": not every job has every stage).
  List<JobStage> get stages => switch (this) {
    update || channel || base => const [
      JobStage.preparing,
      JobStage.fetching,
      JobStage.verifying,
      JobStage.evaluating,
      JobStage.downloading,
      JobStage.building,
      JobStage.activating,
      JobStage.finishing,
    ],
    updateCheck || channelCheck => const [
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
    guestEnd => const [JobStage.preparing, JobStage.finishing],
    storageMeasure => const [
      JobStage.preparing,
      JobStage.measuring,
      JobStage.finishing,
    ],
    cleanupSystem || cleanupProfiles => const [
      JobStage.preparing,
      JobStage.cleaning,
      JobStage.collecting,
      JobStage.finishing,
    ],
    appsRollback || starterSet => const [
      JobStage.preparing,
      JobStage.evaluating,
      JobStage.activating,
      JobStage.finishing,
    ],
    rebuild ||
    hardwareRedetect ||
    ssh ||
    remove ||
    profileCreate ||
    profileRemove ||
    guest ||
    cleanupSet => const [
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

  /// 0.12: the rebuild that switches on what new apps need box-wide
  /// (32-bit graphics for Steam).
  box('Preparing the box'),

  /// 0.14: scanning the disk (with a percentage).
  measuring('Scanning'),
  evaluating('Evaluating changes'),
  downloading('Downloading'),
  building('Building'),
  activating('Switching over'),

  /// 0.14: removing old generations (a clean-up; no longer cancellable).
  cleaning('Removing old versions'),

  /// 0.14: deleting files that nothing uses now.
  collecting('Deleting unused files'),

  /// 0.12: every profile's apps are rebuilt for the new system.
  apps('Updating the apps'),
  finishing('Finishing');

  const JobStage(this.label);
  final String label;

  /// `jobs.cancel` is allowed until the activation stage starts.
  bool get cancellable => index < activating.index;
}

/// What a job is about (session API 0.15 `subject`): which apps, whose,
/// which version, from what to what. Every field is optional; which ones a
/// kind sets is in JOB-PROGRESS-API "JobSubject".
@immutable
class JobSubject {
  const JobSubject({
    this.owner,
    this.profileId,
    this.profileName,
    this.apps = const [],
    this.deleteData = false,
    this.fromOwner,
    this.generation,
    this.fromGeneration,
    this.rev,
    this.version,
    this.channel,
    this.fromChannel,
    this.fromRev,
    this.fromVersion,
    this.base,
    this.fromBase,
    this.enabled,
    this.keep,
    this.frequency,
    this.keepSystem,
    this.keepProfiles,
  });

  /// Apps jobs: a profile id, `guest` or `starter`.
  final String? owner;
  final String? profileId;

  /// The profile's name when the job started.
  final String? profileName;

  /// Display names of the apps installed, removed or set (id, name).
  final List<({String id, String name})> apps;
  final bool deleteData;

  /// `starter`: an app set copied from the starter apps.
  final String? fromOwner;
  final int? generation;
  final int? fromGeneration;
  final String? rev;

  /// The target release as the update screens name it
  /// (`0.7.1.c6b69ce beta`), and the one before.
  final String? version;
  final UpdateChannel? channel;
  final UpdateChannel? fromChannel;
  final String? fromRev;
  final String? fromVersion;
  final NixBase? base;
  final NixBase? fromBase;

  /// The new on/off value (remote access, Guest, automatic clean-up).
  final bool? enabled;

  /// Clean-ups: versions kept.
  final int? keep;
  final CleanupFrequency? frequency;
  final int? keepSystem;
  final int? keepProfiles;
}

/// What nix builds now (session API 0.15 `detail.builds_*`, `building`).
@immutable
class BuildProgress {
  const BuildProgress({
    this.done,
    this.total,
    this.running,
    this.name,
    this.version,
    this.phase,
    this.percent,
  });

  /// Derivations built so far.
  final int? done;

  /// Derivations nix expects to build (can grow).
  final int? total;

  /// How many build at once.
  final int? running;

  /// The latest one that still builds (`hinteros-daemon`), its version
  /// and nix's phase (`configure`, `build`, `install`, ...).
  final String? name;
  final String? version;
  final String? phase;

  /// How far that one is, 0..99, from its build phase (session API 0.18);
  /// null when nix gives none (no phase yet, or a builder without phases).
  final int? percent;

  /// The one that builds now as "n of m": done + 1, never above the total.
  int? get current {
    final t = total;
    if (t == null || t <= 0) return null;
    return ((done ?? 0) + 1).clamp(1, t);
  }
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
    this.subject = const JobSubject(),
    this.build,
    this.startedAt,
    this.finishedAt,
    this.lastActivityAt,
    this.heardAt,
  });

  final String jobId;
  final JobKind kind;
  final JobStage stage;

  /// Where it means something (downloading, building, scanning).
  final int? percent;

  /// What is counted, as text ("120 MB of 300 MB").
  final String? detail;
  final bool finished;
  final bool ok;
  final bool cancelled;
  final JobError? error;
  final bool sessionRestartRequired;

  /// `job_finished.result` (an `update_check` job: the check result as JSON).
  final Map<String, dynamic>? result;

  /// What the job is about.
  final JobSubject subject;

  /// While building: the count and the name.
  final BuildProgress? build;

  /// When the job's process started, and ended (box clock).
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// The last time the job's process wrote output.
  final DateTime? lastActivityAt;

  /// When this launcher last heard of the job (an event or `jobs.get`; the
  /// service sends a heartbeat at least every 2 s while it runs).
  final DateTime? heardAt;

  bool get running => !finished;
  bool get failed => finished && !ok && !cancelled;
  bool get canCancel => running && stage.cancellable;

  JobSnapshot copyWith({
    JobKind? kind,
    JobStage? stage,
    int? percent,
    bool clearPercent = false,
    String? detail,
    bool clearDetail = false,
    bool? finished,
    bool? ok,
    bool? cancelled,
    JobError? error,
    bool? sessionRestartRequired,
    Map<String, dynamic>? result,
    JobSubject? subject,
    BuildProgress? build,
    bool clearBuild = false,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? lastActivityAt,
    DateTime? heardAt,
  }) => JobSnapshot(
    jobId: jobId,
    kind: kind ?? this.kind,
    stage: stage ?? this.stage,
    percent: clearPercent ? null : (percent ?? this.percent),
    detail: clearDetail ? null : (detail ?? this.detail),
    finished: finished ?? this.finished,
    ok: ok ?? this.ok,
    cancelled: cancelled ?? this.cancelled,
    error: error ?? this.error,
    sessionRestartRequired:
        sessionRestartRequired ?? this.sessionRestartRequired,
    result: result ?? this.result,
    subject: subject ?? this.subject,
    build: clearBuild ? null : (build ?? this.build),
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    heardAt: heardAt ?? this.heardAt,
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
  beta('Beta'),
  stable('Stable');

  const UpdateChannel(this.label);
  final String label;
}

enum NixBase {
  unstable('Latest'),
  stable('Stable');

  const NixBase(this.label);
  final String label;
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

/// An app an update adds to the catalog or takes away from this box.
@immutable
class CatalogChange {
  const CatalogChange(this.id, this.name, {this.reason});

  final String id;
  final String name;

  /// Why it goes away (`removed_apps`); null for a new app.
  final String? reason;
}

@immutable
class AvailableUpdate {
  const AvailableUpdate({
    required this.rev,
    required this.version,
    required this.date,
    required this.summary,
    this.severity,
    this.securitySummary,
    this.signer = '',
    this.newApps,
    this.removedApps,
  });

  /// 40 hex characters; what `update.apply` takes.
  final String rev;

  /// What to call it on screen: the release version ("0.6.1", shown as
  /// "HinterOS 0.6.1"), or the date for a revision without one.
  final String version;
  final DateTime date;
  final String summary;

  /// Non-null for a security update.
  final SecuritySeverity? severity;

  /// One line saying what the security fix is about (the newest
  /// `Security-Summary:` trailer); null if the release has none.
  final String? securitySummary;
  final String signer;

  /// Apps the update makes installable (`update.check`'s `new_apps`); null
  /// when the target's catalog could not be read.
  final List<CatalogChange>? newApps;

  /// Installed apps the update takes away, with the catalog's reason; null
  /// when unknown.
  final List<CatalogChange>? removedApps;

  /// The update carries a catalog change (more Store apps).
  bool get catalogChanged => newApps?.isNotEmpty ?? false;

  bool get isSecurity => severity != null;
}

/// The verified tip of another channel (`system.channel.check`, session API
/// 0.17): what a switch to [channel] installs. The owner confirms it, then
/// [UpdatesRepository.setChannel] takes [rev].
@immutable
class ChannelTarget {
  const ChannelTarget({
    required this.channel,
    required this.rev,
    required this.version,
    required this.date,
    this.older = false,
  });

  final UpdateChannel channel;

  /// 40 hex characters; what `channel.set` takes.
  final String rev;

  /// What to call it on screen ("0.7.0 stable"), or its date.
  final String version;
  final DateTime date;

  /// It does not build on the version this box runs: the switch may go back
  /// to an older version.
  final bool older;
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
    this.profiles,
    this.readdsFeatures = const [],
  });

  final int generation;
  final DateTime date;

  /// Null when the generation has no config snapshot.
  final String? rev;
  final bool current;
  final bool booted;

  /// The accounts in that generation (0.12), with their names when the box
  /// still knows them; null when unknown.
  final List<({String id, String? name})>? profiles;

  /// Box features a rollback to it turns back on (0.13, `readds_features`:
  /// the profiles' apps need them, that generation lacks them).
  final List<String> readdsFeatures;
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
    this.supported = true,
  });

  final String ssid;

  /// 0..100
  final int signal;
  final bool secured;
  final bool connected;

  /// The box has a stored connection (no password needed to join).
  final bool saved;

  /// False for WEP and 802.1X (enterprise): the daemon refuses to join them.
  final bool supported;

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
    this.wifiAvailable = true,
    this.wifiEnabled = true,
    this.ethernet = false,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    this.connectivity = Connectivity.unknown,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;
  final bool wifiEnabled;
  final bool ethernet;
  final String? wifiSsid;

  /// 0..100
  final int? wifiSignal;
  final String? address;
  final Connectivity connectivity;

  bool get online => ethernet || wifiSsid != null;
}

/// How far NetworkManager could check that the connection reaches the
/// internet.
enum Connectivity { unknown, none, portal, limited, full }

// ---------------------------------------------------------------- bluetooth

enum BtKind {
  controller('Controller'),
  headset('Headset'),
  speaker('Speaker'),
  keyboard('Keyboard'),
  mouse('Mouse'),
  phone('Phone'),
  computer('Computer'),
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
    this.battery,
  });

  /// The Bluetooth address.
  final String id;
  final String name;
  final BtKind kind;
  final bool paired;
  final bool connected;

  /// Percent, when the device reports it.
  final int? battery;

  BtDevice copyWith({bool? paired, bool? connected}) => BtDevice(
    id: id,
    name: name,
    kind: kind,
    paired: paired ?? this.paired,
    connected: connected ?? this.connected,
    battery: battery,
  );
}

/// A pairing the daemon needs the user's word on (`bluetooth_confirm`).
@immutable
class BtConfirmRequest {
  const BtConfirmRequest({
    required this.id,
    required this.name,
    required this.passkey,
    required this.mustAnswer,
  });

  final String id;
  final String name;
  final String passkey;

  /// True: compare the code with the device's and accept or reject (mode
  /// `confirm`). False: type the code on the device (mode `display`); nothing
  /// to answer.
  final bool mustAnswer;
}

// ---------------------------------------------------------------- display, audio

/// The display's modes. [canSet] false: the box cannot change the mode (an
/// internal panel, or gamescope is not set up for it).
@immutable
class DisplayInfo {
  const DisplayInfo({required this.modes, this.canSet = true, this.display});

  final List<DisplayMode> modes;
  final bool canSet;

  /// The display's name, when known.
  final String? display;
}

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
  music('Music'),
  photos('Photos'),
  utilities('Utilities'),
  other('Other');

  const StoreCategory(this.label);
  final String label;

  /// An unknown category means Other (the catalog schema).
  static StoreCategory parse(String? s) =>
      values.firstWhere((c) => c.name == s, orElse: () => other);
}

/// Where an app stands on this box (`store.list`'s `state`).
enum StoreState {
  available,
  installed,
  installing,
  removing,

  /// Installed, but the catalog retired it: it still works and can be removed.
  retired,

  /// Installed, but the next update takes it away.
  unavailable;

  /// The app is on the box (it is still there while being removed).
  bool get isInstalled => switch (this) {
    available || installing => false,
    _ => true,
  };

  /// A job is working on it.
  bool get busy => this == installing || this == removing;
}

/// An app's vendor terms as the index lists them (`title`, `version`, `url`,
/// `retrieved`, `file`), plus the [text] read from that file next to the
/// index. Shown in full before install; the box records [version].
@immutable
class VendorTerms {
  const VendorTerms({
    required this.title,
    required this.version,
    required this.url,
    required this.retrieved,
    required this.file,
    required this.text,
  });

  /// Document title ("Steam Subscriber Agreement").
  final String title;

  /// The vendor's version or revision date; recorded with the acceptance.
  final String version;
  final String url;

  /// `YYYY-MM-DD`: when the text was copied from [url].
  final String retrieved;

  /// Relative to the index (`terms/<id>-<version>.txt`).
  final String file;
  final String text;
}

/// Where an app's icon comes from. The session daemon resolves it at runtime
/// (installed app's `desktopId`, then `iconUrl`, then discovery on `siteUrl`,
/// then the kiosk profile's favicon, then a letter tile); the launcher never
/// fetches icons itself.
@immutable
class StoreIcon {
  const StoreIcon({
    this.desktopId,
    this.iconUrl,
    this.siteUrl,
    this.firefoxProfile = false,
    this.path,
  });

  /// The icon the daemon resolved on this box (0.9, `icon.path`): an
  /// absolute path to an image, absent until there is one.
  final String? path;

  final String? desktopId;
  final String? iconUrl;
  final String? siteUrl;
  final bool firefoxProfile;
}

/// One permission an app declares in the catalog (session API 0.18): what
/// its sandbox may reach. A required one is always granted; an optional one
/// the profile can turn off (at install and on the app's page). A change
/// applies the next time the app starts.
@immutable
class AppPermission {
  const AppPermission({
    required this.name,
    this.required = false,
    this.granted = true,
  });

  /// The catalog name (`gamepad`, `mic`, `downloads`).
  final String name;
  final bool required;

  /// This profile's choice (true until it turns an optional one off).
  final bool granted;

  /// What the user sees: a short name, or the catalog name for one this
  /// launcher does not know.
  String get label => permissionLabel(name);

  AppPermission copyWith({bool? granted}) => AppPermission(
    name: name,
    required: required,
    granted: granted ?? this.granted,
  );
}

/// The short name of permission [name] on screen.
String permissionLabel(String name) => switch (name) {
  'gamepad' => 'Controller',
  'mic' => 'Microphone',
  'downloads' => 'Downloads folder',
  'lan' => 'Local network',
  _ => name,
};

/// One catalog index entry (format 2); see `catalog.dart` for the parser.
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
    this.free = true,
    this.installer = true,
    this.installerDefault = false,
    this.onIso = false,
    this.isWeb = false,
    this.buildsOnDevice = false,
    this.icon = const StoreIcon(),
    this.dataPaths = const [],
    this.removeDataWarning,
    this.homepage = '',
    this.state = StoreState.available,
    this.statusReason,
    this.conflicts = const [],
    this.missingServices = const [],
    this.permissions = const [],
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
  final bool free;

  /// Listed in the installer's app selection (always true for [onIso]).
  final bool installer;

  /// Pre-selected in the installer's app selection.
  final bool installerDefault;

  /// Part of the installer ISO (no network download needed).
  final bool onIso;

  /// A web (kiosk) app rather than a native one.
  final bool isWeb;

  /// Unfree and not in the binary cache: fetched from the vendor and built
  /// on the box.
  final bool buildsOnDevice;
  final StoreIcon icon;

  /// Paths in a profile's home that "remove and delete data" deletes.
  final List<String> dataPaths;

  /// Shown when removing with data deletion (Steam: installed games go too).
  final String? removeDataWarning;
  final String homepage;

  /// Where it stands on this box. The catalog file (installer) has no state:
  /// [StoreState.available].
  final StoreState state;

  /// Why the catalog retired or removed it.
  final String? statusReason;

  /// Ids of apps that cannot be installed together with this one.
  final List<String> conflicts;

  /// Services (box-wide, admin profile only) this app needs that are not
  /// enabled on this box (0.12). While any is missing it cannot be installed.
  final List<({String id, String name})> missingServices;

  /// What its sandbox may reach (0.18), in catalog order, with this
  /// profile's choices. Empty: it declares none.
  final List<AppPermission> permissions;

  bool get hasTerms => terms != null;

  String get sizeLabel => sizeMiB >= 1000
      ? '${(sizeMiB / 1024).toStringAsFixed(1)} GB'
      : '$sizeMiB MB';
}

/// The first [n] characters of a revision, for display ("" for none).
String shortRev(String? rev, [int n = 7]) =>
    rev == null ? '' : (rev.length > n ? rev.substring(0, n) : rev);

// ---------------------------------------------------------------- admin password

/// polkit wants the admin password for something the launcher asked for
/// (`authentication_requested`).
@immutable
class AuthRequest {
  const AuthRequest({
    required this.cookie,
    required this.action,
    required this.message,
    required this.account,
  });

  /// Names this request in `auth.respond` and `auth.cancel`.
  final String cookie;

  /// The polkit action (`org.hinteros.system.ssh`).
  final String action;

  /// polkit's own sentence, in English.
  final String message;

  /// Whose password is asked for (the first identity).
  final String account;
}

/// How an authentication request ended (`authentication_finished`).
enum AuthOutcome { authorized, failed, cancelled }

@immutable
class AuthFinished {
  const AuthFinished(this.cookie, this.outcome);

  final String cookie;
  final AuthOutcome outcome;
}

/// `auth.respond`'s answer. A wrong password ([ok] false) leaves the request
/// open while [attemptsLeft] is above zero.
@immutable
class AuthAnswer {
  const AuthAnswer({required this.ok, required this.attemptsLeft});

  final bool ok;
  final int attemptsLeft;
}
