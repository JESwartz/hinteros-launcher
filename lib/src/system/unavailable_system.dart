/// What stands in for the parts the daemon does not offer yet: every call
/// fails with `unavailable`, so the screens say so instead of showing
/// made-up data. (The system, updates and jobs ones are only here for tests
/// and as the shape of the rest; the real build uses `daemon_system.dart`.)
library;

import 'models.dart';
import 'repositories.dart';

const _gone = SystemException(
  SystemErrorKind.unavailable,
  'This needs a newer HinterOS service.',
);

class _UnavailableJobs implements JobsRepository {
  @override
  Stream<JobSnapshot> watch(String jobId) => Stream.error(_gone);
  @override
  Future<void> cancel(String jobId) => Future.error(_gone);
}

class _UnavailableSystem implements SystemRepository {
  @override
  Future<SystemInfo> info() => Future.error(_gone);
  @override
  Future<void> restartSession() => Future.error(_gone);
  @override
  Future<void> power(PowerAction action) => Future.error(_gone);
  @override
  Future<Set<PowerAction>> powerAllowed() => Future.error(_gone);
  @override
  Future<SshState> ssh() => Future.error(_gone);
  @override
  Future<JobHandle?> applySettings() => Future.error(_gone);
  @override
  Future<JobHandle> setSsh(bool enable) => Future.error(_gone);
  @override
  Future<JobHandle> redetectHardware({String? adminPin}) => Future.error(_gone);
}

class _UnavailableUpdates implements UpdatesRepository {
  @override
  UpdateStatus get status =>
      const UpdateStatus(currentVersion: 'unknown', currentRev: '');
  @override
  Stream<UpdateStatus> get changes => const Stream.empty();
  @override
  Future<UpdateStatus> check() => Future.error(_gone);
  @override
  Future<JobHandle> apply(String rev) => Future.error(_gone);
  @override
  Future<List<Generation>> generations() => Future.error(_gone);
  @override
  Future<JobHandle> rollback({int? generation, String? adminPin}) =>
      Future.error(_gone);
  @override
  Future<JobHandle> setChannel(
    UpdateChannel channel, {
    bool acknowledgeDowngrade = false,
    String? adminPin,
  }) => Future.error(_gone);
  @override
  Future<JobHandle> setBase(
    NixBase base, {
    bool acknowledgeDowngrade = false,
    String? adminPin,
  }) => Future.error(_gone);
}

class _UnavailableNetwork implements NetworkRepository {
  @override
  Future<NetworkStatus> status() => Future.error(_gone);
  @override
  Future<List<WifiNetwork>> scan() => Future.error(_gone);
  @override
  Future<List<WifiNetwork>> list() => Future.error(_gone);
  @override
  Stream<NetworkStatus> get statusChanges => const Stream.empty();
  @override
  Stream<List<WifiNetwork>> get listChanges => const Stream.empty();
  @override
  Future<void> connect(String ssid, {String? password}) => Future.error(_gone);
  @override
  Future<void> disconnect() => Future.error(_gone);
  @override
  Future<void> forget(String ssid) => Future.error(_gone);
  @override
  Future<void> setWifiEnabled(bool enabled) => Future.error(_gone);
}

class _UnavailableBluetooth implements BluetoothRepository {
  @override
  bool get scanning => false;
  @override
  Future<void> load() => Future.error(_gone);
  @override
  Stream<BtConfirmRequest> get confirmRequests => const Stream.empty();
  @override
  Future<void> confirm(String id, {required bool accept}) =>
      Future.error(_gone);
  @override
  Stream<List<BtDevice>> get devices => const Stream.empty();
  @override
  List<BtDevice> get current => const [];
  @override
  Future<void> startScan() => Future.error(_gone);
  @override
  Future<void> stopScan() => Future.error(_gone);
  @override
  Future<void> pair(String id) => Future.error(_gone);
  @override
  Future<void> connect(String id) => Future.error(_gone);
  @override
  Future<void> disconnect(String id) => Future.error(_gone);
  @override
  Future<void> forget(String id) => Future.error(_gone);
}

class _UnavailableDisplayAudio implements DisplayAudioRepository {
  @override
  Future<DisplayInfo> displayModes() => Future.error(_gone);
  @override
  Future<void> setDisplayMode(DisplayMode mode) => Future.error(_gone);
  @override
  Future<void> keepDisplayMode() => Future.error(_gone);
  @override
  Future<void> revertDisplayMode() => Future.error(_gone);
  @override
  Stream<AudioState> get audioChanges => const Stream.empty();
  @override
  Future<AudioState> audio() => Future.error(_gone);
  @override
  Future<void> setAudioOutput(String id) => Future.error(_gone);
  @override
  Future<void> setVolume(int percent) => Future.error(_gone);
  @override
  Future<void> setMuted(bool muted) => Future.error(_gone);
}

class _UnavailableStore implements StoreRepository {
  @override
  bool get loaded => false;
  @override
  Future<List<StoreApp>> catalog() => Future.error(_gone);
  @override
  List<StoreApp> get apps => const [];
  @override
  Set<String> get installed => const {};
  @override
  StoreState stateOf(String id) => StoreState.available;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  bool get moreAfterUpdate => false;
  @override
  Future<String?> resolveIcon(StoreApp app) async => null;
  @override
  Future<JobHandle> install(
    String id, {
    Map<String, String> acceptedTerms = const {},
  }) => Future.error(_gone);
  @override
  Future<JobHandle> remove(String id, {bool deleteData = false}) =>
      Future.error(_gone);
  @override
  Set<String> get needsTerms => const {};
  @override
  Future<void> acceptTerms(String id, String version) => Future.error(_gone);
  @override
  Future<List<AppGeneration>> appGenerations() => Future.error(_gone);
  @override
  Future<JobHandle> rollbackApps(int generation) => Future.error(_gone);
}

/// Profiles on a box (or daemon) without them: every call fails.
class UnavailableProfiles implements ProfilesRepository {
  const UnavailableProfiles();

  @override
  Future<CurrentProfile> current() => Future.error(_gone);
  @override
  Future<ProfilesState> list() => Future.error(_gone);
  @override
  Stream<List<ProfileInfo>> get changes => const Stream.empty();
  @override
  Stream<bool> get lockChanges => const Stream.empty();
  @override
  Stream<SwitchEvent> get switchEvents => const Stream.empty();
  @override
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) => Future.error(_gone);
  @override
  Future<void> setupAdmin({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) => Future.error(_gone);
  @override
  Future<void> rename(String id, String name, {String? adminPin}) =>
      Future.error(_gone);
  @override
  Future<void> setColor(ProfileColor color) => Future.error(_gone);
  @override
  Future<void> setPin(String pin, {String? currentPin}) => Future.error(_gone);
  @override
  Future<void> mirrorAppearance({
    required double textScale,
    required bool highContrast,
    required bool reduceMotion,
  }) => Future.error(_gone);
  @override
  Future<void> setLocked(bool locked, String pin) => Future.error(_gone);
  @override
  Future<void> resetPin(String id, String newPin, {required String adminPin}) =>
      Future.error(_gone);
  @override
  Future<JobHandle> remove(String id, String pin) => Future.error(_gone);
  @override
  Future<JobHandle?> setGuest(bool enabled, String adminPin) =>
      Future.error(_gone);
  @override
  Future<StarterSet> starterSet() => Future.error(_gone);
  @override
  Future<JobHandle?> setStarterSet(List<String> ids, String adminPin) =>
      Future.error(_gone);
  @override
  Future<void> switchTo(String id, {String? pin}) => Future.error(_gone);
  @override
  Future<void> keepWaiting() => Future.error(_gone);
  @override
  Future<void> forceClose(String appId) => Future.error(_gone);
  @override
  Future<void> cancelSwitch() => Future.error(_gone);
  @override
  Future<void> unlock(String pin) => Future.error(_gone);
  @override
  Future<void> endGuest() => Future.error(_gone);
}

class _UnavailableAuth implements AuthRepository {
  @override
  Stream<AuthRequest> get requests => const Stream.empty();
  @override
  Stream<AuthFinished> get finished => const Stream.empty();
  @override
  Future<AuthAnswer> respond(String cookie, String password) =>
      Future.error(_gone);
  @override
  Future<void> cancel(String cookie) async {}
}

/// Every system call fails with `unavailable`.
SystemServices unavailableSystemServices() => SystemServices(
  jobs: _UnavailableJobs(),
  system: _UnavailableSystem(),
  updates: _UnavailableUpdates(),
  network: _UnavailableNetwork(),
  bluetooth: _UnavailableBluetooth(),
  displayAudio: _UnavailableDisplayAudio(),
  store: _UnavailableStore(),
  auth: _UnavailableAuth(),
  profiles: const UnavailableProfiles(),
);
