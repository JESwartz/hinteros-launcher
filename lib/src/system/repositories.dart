/// What the system UI needs from the world. Screens only ever see these
/// interfaces; `mock_system.dart` implements them with in-process fakes (like
/// `MockDaemon`), and the real ones will sit on the new session API version
/// (the `system.*` relay of the privileged service) and, for Wi-Fi,
/// Bluetooth, display and audio, on whatever the daemon exposes for runtime
/// settings.
// TODO(system-api): a Daemon* implementation of each interface; nothing else
// in the launcher should need to change.
library;

import 'models.dart';

/// Jobs (`jobs.get`, `job_started` / `job_progress` / `job_finished`).
abstract class JobsRepository {
  /// The job's state now, then every change, ending with the finished state.
  /// An unknown id gives a stream that errors with [SystemErrorKind.notFound].
  // TODO(system-api): jobs.get + the three job_* events
  Stream<JobSnapshot> watch(String jobId);

  /// `jobs.cancel`: [SystemErrorKind.jobBusy] once activation has started.
  // TODO(system-api): jobs.cancel
  Future<void> cancel(String jobId);
}

/// `system.info`, power, SSH.
abstract class SystemRepository {
  // TODO(system-api): system.info
  Future<SystemInfo> info();

  /// Restarts the launcher session (after a job reported
  /// `session_restart_required`).
  // TODO(system-api): session restart (api.md `system_unavailable` window)
  Future<void> restartSession();

  /// Power goes session daemon -> logind directly (system-api.md "Power").
  // TODO(system-api): system.power (session side)
  Future<void> power(PowerAction action);

  // TODO(system-api): system.info ssh + settings.get
  Future<SshState> ssh();

  /// Turns SSH on or off (`ssh.set`). SSH is plain username and password:
  /// you log in as the admin account. Turning it on needs the admin password
  /// (polkit `auth_admin`): [SystemErrorKind.wrongPassword] when it is not
  /// right. Turning it off needs none.
  // TODO(system-api): how the password reaches polkit (an auth agent in the
  // session daemon, or a field of the method) is still open.
  Future<JobHandle> setSsh(bool enable, {String? adminPassword});
}

/// Updates, rollback, channel.
abstract class UpdatesRepository {
  UpdateStatus get status;
  Stream<UpdateStatus> get changes;

  /// `update.check`; the service caches within 60 s. Throws
  /// [SystemErrorKind.updateUnreachable] / `updateVerificationFailed`.
  Future<UpdateStatus> check();

  /// `update.apply {rev}`: [rev] must be the last verified check's.
  Future<JobHandle> apply(String rev);

  /// `generations.list`, newest first.
  Future<List<Generation>> generations();

  /// `rollback {generation?}`; null: the previous generation.
  Future<JobHandle> rollback({int? generation});

  /// `channel.set`. A switch that is a downgrade throws
  /// [SystemErrorKind.needsAcknowledgement] unless [acknowledgeDowngrade].
  Future<JobHandle> setChannel(
    UpdateChannel channel, {
    bool acknowledgeDowngrade = false,
  });

  /// `base.set`; unstable -> stable needs [acknowledgeDowngrade].
  Future<JobHandle> setBase(NixBase base, {bool acknowledgeDowngrade = false});
}

/// Wi-Fi through NetworkManager. System-wide connections: the password is
/// entered once per box (threat-model decision 5).
abstract class NetworkRepository {
  // TODO(system-api): NetworkManager, runtime (no rebuild)
  Future<NetworkStatus> status();

  /// A fresh scan, strongest first.
  Future<List<WifiNetwork>> scan();

  /// [SystemErrorKind.wrongPassword] for a bad password, `deviceFailed` for
  /// anything else.
  Future<void> connect(String ssid, {String? password});
  Future<void> disconnect();
  Future<void> forget(String ssid);
  Future<void> setWifiEnabled(bool enabled);
}

/// Bluetooth through BlueZ.
abstract class BluetoothRepository {
  // TODO(system-api): BlueZ, runtime (no rebuild)
  bool get scanning;

  /// Known and discovered devices; emits on every change.
  Stream<List<BtDevice>> get devices;
  List<BtDevice> get current;
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> pair(String id);
  Future<void> connect(String id);
  Future<void> disconnect(String id);
  Future<void> forget(String id);
}

/// Display modes and audio, applied at runtime.
abstract class DisplayAudioRepository {
  // TODO(system-api): the session's display (gamescope/DRM) and PipeWire
  Future<List<DisplayMode>> displayModes();
  Future<void> setDisplayMode(DisplayMode mode);

  Future<AudioState> audio();
  Future<void> setAudioOutput(String id);
  Future<void> setVolume(int percent);
  Future<void> setMuted(bool muted);
}

/// The Store: catalog index, installed apps, install and remove.
abstract class StoreRepository {
  // TODO(system-api): /run/current-system/sw/share/hinteros/catalog.json,
  // apps.install / apps.remove (M8), terms acceptance record

  Future<List<StoreApp>> catalog();

  /// Ids of installed apps; follows [changes].
  Set<String> get installed;
  Stream<void> get changes;

  /// `update.check` found a catalog change: more apps arrive with the next
  /// update.
  bool get moreAfterUpdate;

  /// The app's own installed icon or, before install, the site icon (the
  /// daemon's runtime resolution). A file path, or null for placeholder art.
  Future<String?> resolveIcon(StoreApp app);

  /// `apps.install`; [acceptedTerms] is the version of the vendor terms the
  /// user accepted (recorded with date and profile).
  Future<JobHandle> install(String id, {String? acceptedTerms});

  /// `apps.remove`; [deleteData] also deletes the app's files in every
  /// profile.
  Future<JobHandle> remove(String id, {bool deleteData = false});
}

/// Everything the system UI needs, passed down as one object.
class SystemServices {
  const SystemServices({
    required this.jobs,
    required this.system,
    required this.updates,
    required this.network,
    required this.bluetooth,
    required this.displayAudio,
    required this.store,
  });

  final JobsRepository jobs;
  final SystemRepository system;
  final UpdatesRepository updates;
  final NetworkRepository network;
  final BluetoothRepository bluetooth;
  final DisplayAudioRepository displayAudio;
  final StoreRepository store;
}
