/// What the system UI needs from the world. Screens only ever see these
/// interfaces. `daemon_system.dart` implements the system ones (info, SSH,
/// updates, jobs) over the session API 0.6 `system.*` relay; `mock_system.dart`
/// has in-process fakes for all of them (like `MockDaemon`), and
/// `unavailable_system.dart` answers "unavailable" for what the daemon does
/// not offer yet (Wi-Fi, Bluetooth, display, audio, power: TODO(0.7); the
/// Store: TODO(M8)).
library;

import 'models.dart';

/// Jobs (`jobs.get`, `job_started` / `job_progress` / `job_finished`).
abstract class JobsRepository {
  /// The job's state now, then every change, ending with the finished state.
  /// An unknown id gives a stream that errors with [SystemErrorKind.notFound].
  Stream<JobSnapshot> watch(String jobId);

  /// `jobs.cancel`: [SystemErrorKind.jobBusy] once activation has started.
  Future<void> cancel(String jobId);
}

/// `system.info`, power, SSH.
abstract class SystemRepository {
  /// `system.info`.
  Future<SystemInfo> info();

  /// Restarts the launcher session (after a job reported
  /// `session_restart_required`).
  // TODO(0.7): no session API method for it in 0.6
  Future<void> restartSession();

  /// Power goes session daemon -> logind directly (system-api.md "Power").
  // TODO(0.7): session-side power (logind)
  Future<void> power(PowerAction action);

  Future<SshState> ssh();

  /// Whether the admin password can be passed on (see `adminPasswordUi`).
  /// When false, turning SSH on is attempted as it is and the screen explains
  /// [SystemErrorKind.authenticationRequired].
  bool get acceptsAdminPassword;

  /// Turns SSH on or off (`ssh.set`). SSH is plain username and password:
  /// you log in as the admin account. Turning it on needs the admin password
  /// (polkit `auth_admin`): without a polkit agent the service answers
  /// [SystemErrorKind.authenticationRequired]; with one,
  /// [SystemErrorKind.wrongPassword] means the password was not right.
  /// Turning it off needs none. [SystemErrorKind.nothingToDo] when SSH
  /// already is in that state.
  Future<JobHandle> setSsh(bool enable, {String? adminPassword});

  /// `settings.get` then `settings.set` with the revision it returned
  /// (retried once when it went stale). Null when there was nothing to
  /// change.
  Future<JobHandle?> applySettings();
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
  // TODO(0.7): NetworkManager, runtime (no rebuild)
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
  // TODO(0.7): BlueZ, runtime (no rebuild)
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
  // TODO(0.7): the session's display (gamescope/DRM) and PipeWire
  Future<List<DisplayMode>> displayModes();
  Future<void> setDisplayMode(DisplayMode mode);

  Future<AudioState> audio();
  Future<void> setAudioOutput(String id);
  Future<void> setVolume(int percent);
  Future<void> setMuted(bool muted);
}

/// The Store: catalog index, installed apps, install and remove.
abstract class StoreRepository {
  // TODO(M8): /run/current-system/sw/share/hinteros/catalog.json,
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
