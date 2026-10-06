/// What stands in for the parts the daemon does not offer yet: every call
/// fails with `unavailable`, so the screens say so instead of showing
/// made-up data. (The system, updates and jobs ones are only here for tests
/// and as the shape of the rest; the real build uses `daemon_system.dart`.)
library;

import 'models.dart';
import 'repositories.dart';

const _gone = SystemException(
  SystemErrorKind.unavailable,
  'This needs a newer HinterOS service than the one that is running.',
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
  bool get acceptsAdminPassword => false;
  @override
  Future<SshState> ssh() => Future.error(_gone);
  @override
  Future<JobHandle?> applySettings() => Future.error(_gone);
  @override
  Future<JobHandle> setSsh(bool enable, {String? adminPassword}) =>
      Future.error(_gone);
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
  Future<JobHandle> rollback({int? generation}) => Future.error(_gone);
  @override
  Future<JobHandle> setChannel(
    UpdateChannel channel, {
    bool acknowledgeDowngrade = false,
  }) => Future.error(_gone);
  @override
  Future<JobHandle> setBase(
    NixBase base, {
    bool acknowledgeDowngrade = false,
  }) => Future.error(_gone);
}

class _UnavailableNetwork implements NetworkRepository {
  @override
  Future<NetworkStatus> status() => Future.error(_gone);
  @override
  Future<List<WifiNetwork>> scan() => Future.error(_gone);
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
  Future<List<DisplayMode>> displayModes() => Future.error(_gone);
  @override
  Future<void> setDisplayMode(DisplayMode mode) => Future.error(_gone);
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
  Future<List<StoreApp>> catalog() => Future.error(_gone);
  @override
  Set<String> get installed => const {};
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  bool get moreAfterUpdate => false;
  @override
  Future<String?> resolveIcon(StoreApp app) async => null;
  @override
  Future<JobHandle> install(String id, {String? acceptedTerms}) =>
      Future.error(_gone);
  @override
  Future<JobHandle> remove(String id, {bool deleteData = false}) =>
      Future.error(_gone);
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
);
