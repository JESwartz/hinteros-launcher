/// What the system UI needs from the world. Screens only ever see these
/// interfaces. `daemon_system.dart` implements the system ones (info, SSH,
/// updates, jobs) over the session API 0.6 `system.*` relay, the runtime
/// settings (Wi-Fi, Bluetooth, audio, display, power) over the 0.7 methods,
/// and the 0.8 ones (admin password prompt, session restart, Store);
/// `mock_system.dart` has in-process fakes for all of them (like
/// `MockDaemon`), and `unavailable_system.dart` answers "unavailable" for
/// tests and the first moments before a connection exists.
library;

import 'models.dart';
import 'profiles.dart';
import 'storage.dart';
import 'time_zone.dart';

export 'profiles.dart';
export 'storage.dart';
export 'time_zone.dart';

/// Jobs (`jobs.get`, `job_started` / `job_progress` / `job_finished`).
abstract class JobsRepository {
  /// The job's state now, then every change, ending with the finished state.
  /// An unknown id gives a stream that errors with [SystemErrorKind.notFound].
  Stream<JobSnapshot> watch(String jobId);

  /// `jobs.cancel`: [SystemErrorKind.jobBusy] once activation has started.
  Future<void> cancel(String jobId);

  /// The job that runs on the box now, if any (`jobs.list`): after a
  /// launcher restart its progress shows again.
  Future<JobSnapshot?> running();

  /// The clock the job times are on (the box clock): the time a job has
  /// taken, and how long ago the launcher last heard of it.
  DateTime now();
}

/// `system.info`, power, SSH.
abstract class SystemRepository {
  /// `system.info`.
  Future<SystemInfo> info();

  /// Restarts the TV session (`session.restart`, after a job reported
  /// `session_restart_required`): the daemon answers and the launcher is ended
  /// with the rest of the session; greetd starts a new one. Throws
  /// [SystemErrorKind.unavailable] when this is not a TV session.
  Future<void> restartSession();

  /// `power.suspend` / `reboot` / `poweroff`, session daemon -> logind
  /// directly. [SystemErrorKind.powerInhibited] while an update is being
  /// applied; [SystemErrorKind.notAuthorized] when polkit says no.
  Future<void> power(PowerAction action);

  /// `power.capabilities`: the actions logind allows for this user. Throws
  /// [SystemErrorKind.unavailable] without logind.
  Future<Set<PowerAction>> powerAllowed();

  Future<SshState> ssh();

  /// Turns SSH on or off (`ssh.set`). SSH is plain username and password:
  /// you log in as the admin account. Turning it on needs the admin password
  /// (polkit `auth_admin`): the call waits while [AuthRepository.requests]
  /// carries the prompt, which the shell shows. The password never passes
  /// through here. [SystemErrorKind.authenticationRequired]: the prompt was
  /// cancelled (or no agent), nothing changed;
  /// [SystemErrorKind.permissionDenied]: too many wrong passwords. Turning
  /// it off needs none. [SystemErrorKind.nothingToDo] when SSH already is in
  /// that state.
  Future<JobHandle> setSsh(bool enable);

  /// `settings.get` then `settings.set` with the revision it returned
  /// (retried once when it went stale). Null when there was nothing to
  /// change.
  Future<JobHandle?> applySettings();

  /// `hardware.redetect {admin_pin?}`: detects the hardware again and
  /// applies it (a job). The admin PIN as for [UpdatesRepository.rollback].
  Future<JobHandle> redetectHardware({String? adminPin});
}

/// The admin password prompt: the session daemon is polkit's authentication
/// agent for the calls it relays. The launcher shows the prompt (the shell
/// listens to [requests]), answers with [respond] or [cancel] and closes it on
/// [finished]. The password is only ever an argument of [respond]: it is not
/// logged, kept or put into an error.
abstract class AuthRepository {
  /// `authentication_requested`.
  Stream<AuthRequest> get requests;

  /// `authentication_finished`: the request is over (authorized, failed, or
  /// cancelled by anyone).
  Stream<AuthFinished> get finished;

  /// `auth.respond`. A wrong password is an answer with `ok` false, not an
  /// error. [SystemErrorKind.notFound] when the request is over already.
  Future<AuthAnswer> respond(String cookie, String password);

  /// `auth.cancel`; a request that is over already is not an error.
  Future<void> cancel(String cookie);
}

/// Updates, rollback, channel.
abstract class UpdatesRepository {
  UpdateStatus get status;
  Stream<UpdateStatus> get changes;

  /// `update.check`; the service caches within 60 s. Throws
  /// [SystemErrorKind.updateUnreachable] / `updateVerificationFailed`.
  Future<UpdateStatus> check();

  /// `update.apply {rev, admin_pin?}`: [rev] must be the last verified
  /// check's. The admin PIN as for [rollback].
  Future<JobHandle> apply(String rev, {String? adminPin});

  /// `generations.list`, newest first.
  Future<List<Generation>> generations();

  // The box-wide actions (update, rollback, channel, base, hardware) take
  // the admin profile's PIN (session API 0.13): missing or wrong gives
  // [SystemErrorKind.pinRequired] with `pin: admin`. None is needed on a
  // schema-1 box or while the admin profile has no PIN.

  /// `rollback {generation?, admin_pin?}`; null: the previous generation.
  Future<JobHandle> rollback({int? generation, String? adminPin});

  /// `channel.set`. A switch that is a downgrade throws
  /// [SystemErrorKind.needsAcknowledgement] unless [acknowledgeDowngrade].
  Future<JobHandle> setChannel(
    UpdateChannel channel, {
    bool acknowledgeDowngrade = false,
    String? adminPin,
  });

  /// `base.set`; unstable -> stable needs [acknowledgeDowngrade].
  Future<JobHandle> setBase(
    NixBase base, {
    bool acknowledgeDowngrade = false,
    String? adminPin,
  });
}

/// Wi-Fi through NetworkManager (`network.status`, `wifi.*`). System-wide
/// connections: the password is entered once per box (threat-model decision
/// 5). Every call can throw [SystemErrorKind.unavailable] (no
/// NetworkManager); the screens say so without touching the other sections.
abstract class NetworkRepository {
  Future<NetworkStatus> status();

  /// A fresh scan (`wifi.scan`), strongest first.
  Future<List<WifiNetwork>> scan();

  /// The current list without scanning (`wifi.list`), strongest first.
  Future<List<WifiNetwork>> list();

  /// `network_changed`: the status after every change.
  Stream<NetworkStatus> get statusChanges;

  /// `wifi_list_changed`: the list after every change.
  Stream<List<WifiNetwork>> get listChanges;

  /// [SystemErrorKind.wrongPassword] for a bad password, `deviceFailed` for
  /// anything else (the message says why), `invalidParams` for WEP and 802.1X.
  Future<void> connect(String ssid, {String? password});
  Future<void> disconnect();
  Future<void> forget(String ssid);
  Future<void> setWifiEnabled(bool enabled);
}

/// Bluetooth through BlueZ (`bluetooth.*`).
abstract class BluetoothRepository {
  bool get scanning;

  /// Loads status and devices (`bluetooth.status`, `bluetooth.devices`) into
  /// [current]. Throws [SystemErrorKind.unavailable] without BlueZ.
  Future<void> load();

  /// Known and discovered devices; emits on every change
  /// (`bluetooth_changed`).
  Stream<List<BtDevice>> get devices;
  List<BtDevice> get current;

  /// Pairings that need the user's word (`bluetooth_confirm`).
  Stream<BtConfirmRequest> get confirmRequests;

  /// `bluetooth.confirm`: answers the pairing of device [id].
  Future<void> confirm(String id, {required bool accept});

  /// `bluetooth.scan`; the daemon stops by itself after 30 s.
  Future<void> startScan();
  Future<void> stopScan();

  /// Returns when the pairing is over. Controllers and headsets pair without
  /// a prompt; a numeric comparison arrives on [confirmRequests] first.
  Future<void> pair(String id);
  Future<void> connect(String id);
  Future<void> disconnect(String id);
  Future<void> forget(String id);
}

/// Display modes and audio, applied at runtime.
abstract class DisplayAudioRepository {
  /// `display.modes`.
  Future<DisplayInfo> displayModes();

  /// `display.set_mode`: switches now. The caller then asks the user and ends
  /// with [keepDisplayMode] or [revertDisplayMode].
  /// [SystemErrorKind.deviceFailed] with reason `not_applied` when the
  /// display did not switch.
  Future<void> setDisplayMode(DisplayMode mode);

  /// `display.keep`.
  Future<void> keepDisplayMode();

  /// `display.revert`: back to the mode from before the last change.
  Future<void> revertDisplayMode();

  /// `audio.outputs`.
  Future<AudioState> audio();

  /// `audio_changed`: the state after every change (also from elsewhere).
  Stream<AudioState> get audioChanges;
  Future<void> setAudioOutput(String id);
  Future<void> setVolume(int percent);
  Future<void> setMuted(bool muted);
}

/// The Store: the catalog merged with what is installed, and install and
/// remove. [DaemonStore] reads `store.list` and follows `store_changed`;
/// there is no state of its own to keep in step.
abstract class StoreRepository {
  /// The first listing arrived (until then [installed] is empty because it is
  /// not known, not because nothing is installed).
  bool get loaded;

  /// `store.list`, fresh: every app with its state, by name. Throws
  /// [SystemException]: `unavailable` without a catalog index or system
  /// service.
  Future<List<StoreApp>> catalog();

  /// The last listing ([catalog] and every `store_changed` refresh it), empty
  /// before [loaded].
  List<StoreApp> get apps;

  /// Ids of the apps that are on this box (installed, being removed,
  /// retired, unavailable); follows [changes].
  Set<String> get installed;

  /// The state of app [id] in the last listing; available when unknown.
  StoreState stateOf(String id);

  /// The listing changed (`store_changed`, or a refresh that found a change).
  Stream<void> get changes;

  /// More apps arrive with the next update (`store.list`'s
  /// `more_after_update`).
  bool get moreAfterUpdate;

  /// The app's own installed icon or, before install, the site icon (the
  /// daemon's runtime resolution). A file path, or null for placeholder art.
  Future<String?> resolveIcon(StoreApp app);

  /// `apps.install {ids: [id], revision, accepted_terms}`; [acceptedTerms] is
  /// the version of the vendor terms the user read, per app id: the app's own
  /// and those of the apps installed with it. A stale revision is fetched
  /// again and the call tried once more.
  ///
  /// [SystemErrorKind.appConflict] (`data`: `id`, `conflicts_with`),
  /// [SystemErrorKind.termsRequired] (`id`, `version`),
  /// [SystemErrorKind.insufficientResources], [SystemErrorKind.nothingToDo]
  /// (already installed).
  Future<JobHandle> install(
    String id, {
    Map<String, String> acceptedTerms = const {},
  });

  /// `apps.remove {ids: [id], revision, delete_data}`; [deleteData] also
  /// deletes the app's files in this profile's home. [SystemErrorKind.appConflict]
  /// when another installed app needs it.
  Future<JobHandle> remove(String id, {bool deleteData = false});

  // Per profile (session API 0.12): every profile has its own apps.

  /// Starter-set apps of this profile whose vendor terms it has not
  /// accepted yet (`apps.list`'s `needs_terms`): their first launch shows
  /// the terms. Follows [changes].
  Set<String> get needsTerms;

  /// `apps.accept_terms {id, version}`: the profile accepted the terms of
  /// an app it got with the starter set.
  Future<void> acceptTerms(String id, String version);

  /// `apps.generations`: this profile's app generations, newest first.
  /// [SystemErrorKind.unavailable] on a box that still has box-wide apps.
  Future<List<AppGeneration>> appGenerations();

  /// `apps.rollback {generation}`: this profile's apps as they were then.
  Future<JobHandle> rollbackApps(int generation);
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
    required this.auth,
    required this.profiles,
    required this.storage,
    required this.timeZone,
  });

  final JobsRepository jobs;
  final SystemRepository system;
  final UpdatesRepository updates;
  final NetworkRepository network;
  final BluetoothRepository bluetooth;
  final DisplayAudioRepository displayAudio;
  final StoreRepository store;
  final AuthRepository auth;

  /// Profiles (M7): the current profile, switching, the sleep lock,
  /// Settings -> Profiles.
  final ProfilesRepository profiles;

  /// Settings -> Storage (0.14): what uses the disk, the clean-ups.
  final StorageRepository storage;

  /// The box's time zone (0.16): the clock, first boot, Settings.
  final TimeZoneRepository timeZone;
}
