/// What the installer UI needs from the machine. Screens only see
/// [InstallerBackend]: [ProcessInstallerBackend] runs the real tools (the
/// ISO), [FakeInstallerBackend] scripts them (tests and `--installer --mock`).
library;

import '../system/models.dart';
import 'plan.dart';
import 'progress.dart';

/// A backend call that did not work, with a sentence for the screen.
class InstallerException implements Exception {
  const InstallerException(this.message, {this.code});
  final String message;

  /// The backend's error code, when it gave one.
  final String? code;
  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// One HinterOS revision: its commit and its `release/version`.
class HinterRelease {
  const HinterRelease({required this.rev, required this.version});

  /// 40 hex digits.
  final String rev;

  /// `MAJOR.MINOR.PATCH[-suffix]`, or the first 12 hex digits of [rev] when
  /// the revision has no readable version.
  final String version;
}

/// What `hinteros-install --check-newer` found: the installer's own
/// revision and, when the channel's verified tip is newer, that one.
class NewerCheck {
  const NewerCheck({required this.channel, required this.iso, this.newer});

  /// The channel that was checked (the installer's default when none was
  /// asked for).
  final InstallChannel channel;
  final HinterRelease iso;

  /// Null: nothing newer than [iso] on [channel]. On beta the versions can
  /// be equal; only this field says "newer".
  final HinterRelease? newer;
}

/// What `hinteros-install --info` says the installer carries: its own
/// revision and the channel it is for. Known offline.
class InstallerInfo {
  const InstallerInfo({required this.iso, required this.channel});

  final HinterRelease iso;

  /// The installer's channel (`hinteros.installer.channel`): the default
  /// channel of the plan.
  final InstallChannel channel;
}

class NetworkState {
  const NetworkState({
    this.wiredConnected = false,
    this.wifiAvailable = false,
    this.wifiSsid,
    this.online = false,
    this.connecting = false,
    this.cableWaiting = false,
  });

  /// A cable is plugged in and connected.
  final bool wiredConnected;

  /// There is a Wi-Fi adapter.
  final bool wifiAvailable;

  /// The Wi-Fi network the box is connected to, if any.
  final String? wifiSsid;

  /// The internet was reached: the last probe of the cache server worked.
  /// Never taken from NetworkManager's cached connectivity.
  final bool online;

  /// NetworkManager is bringing a connection up right now (it reports
  /// "connecting (getting IP configuration)" and the like): the link and the
  /// internet are not there yet, but they are on their way.
  final bool connecting;

  /// A cable is plugged in (the wired device is "disconnected" rather than
  /// "unavailable") but NetworkManager has not started a connection yet. A
  /// fresh plug shows this for a few seconds; with no connection profile it
  /// stays, so it is only waited for briefly.
  final bool cableWaiting;

  /// A connection is expected soon, though not up yet.
  bool get pending => !linkUp && (connecting || cableWaiting);

  /// A cable or Wi-Fi connection is up (whether or not it reaches anywhere).
  bool get linkUp => wiredConnected || wifiSsid != null;

  /// The same link state with another probe result.
  NetworkState withOnline(bool online) => NetworkState(
    wiredConnected: wiredConnected,
    wifiAvailable: wifiAvailable,
    wifiSsid: wifiSsid,
    online: online,
    connecting: connecting,
    cableWaiting: cableWaiting,
  );
}

class WifiAp {
  const WifiAp({
    required this.ssid,
    required this.signal,
    required this.secured,
    this.inUse = false,
    this.supported = true,
  });

  final String ssid;

  /// 0..100.
  final int signal;
  final bool secured;
  final bool inUse;

  /// False for networks this installer cannot join (WEP, 802.1X, odd names).
  final bool supported;

  /// 0..4 for the bars.
  int get bars => signal <= 0 ? 0 : ((signal - 1) ~/ 25 + 1).clamp(1, 4);
}

class DiskInfo {
  const DiskInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.diskSeq,
    this.model,
    this.transport,
    this.removable = false,
    this.mountpoints = const [],
  });

  /// `/dev/nvme0n1`: goes into the plan.
  final String path;

  /// The kernel name (`nvme0n1`).
  final String name;
  final int sizeBytes;

  /// The kernel's disk sequence number (lsblk `DISK-SEQ`): new each time a
  /// disk is attached and never used again until the next boot. It goes
  /// into the plan, so the backend can see that the disk at [path] is still
  /// the one chosen here (a kernel name such as `sdb` goes to the next disk
  /// plugged in). Null: lsblk did not say; the disk cannot be chosen.
  final int? diskSeq;
  final String? model;
  final String? transport;
  final bool removable;

  /// Where the disk or any of its partitions is mounted (`/mnt` leftovers of
  /// an earlier try excluded, like the backend does).
  final List<String> mountpoints;

  String get title => (model != null && model!.isNotEmpty) ? model! : name;

  String get sizeLabel {
    final gb = sizeBytes / 1e9;
    return gb >= 1000
        ? '${(gb / 1000).toStringAsFixed(1)} TB'
        : '${gb.round()} GB';
  }

  /// Why this disk cannot be chosen, or null when it can.
  String? get unusableReason {
    if (mountpoints.isNotEmpty) {
      return 'In use (mounted at ${mountpoints.join(', ')}). It may be the '
          'installer stick.';
    }
    if (removable) {
      return 'Removable drive. It may be the installer USB stick.';
    }
    if (sizeBytes < minDiskBytes) return 'Too small: at least 16 GB needed.';
    if (diskSeq == null) return 'Cannot identify this disk.';
    return null;
  }

  bool get usable => unusableReason == null;
}

abstract class InstallerBackend {
  /// Wired status, Wi-Fi presence and a fresh reachability probe. [force]
  /// also makes NetworkManager re-evaluate its connectivity. Never cached.
  Future<NetworkState> network({bool force = false});

  /// Only the device states, read fresh and quickly: [NetworkState.online]
  /// is false because nothing was probed.
  Future<NetworkState> networkLink();

  /// One event whenever NetworkManager reports a change (`nmcli monitor`).
  /// The monitor runs while the stream has a listener.
  Stream<void> watchNetwork();

  /// Visible Wi-Fi networks, strongest first, one per name.
  Future<List<WifiAp>> scanWifi();

  /// Joins [ssid]. The password goes to the tool's stdin, never to its
  /// command line. Throws [InstallerException].
  Future<void> connectWifi(String ssid, {String? psk});

  /// Whole disks of this machine (usable or not: the UI shows why not).
  Future<List<DiskInfo>> disks();

  /// The apps the installer offers, from the catalog index on the ISO.
  Future<List<StoreApp>> catalog();

  /// `hinteros-install --info`: the installer's own revision and channel.
  /// Offline and quick. Throws [InstallerException] when it fails (an older
  /// installer without `--info`).
  Future<InstallerInfo> info();

  /// `hinteros-install --check-newer [--channel ...]`: whether [channel]
  /// (null: the installer's own default) has a newer signed HinterOS than
  /// this installer. Touches nothing. Throws [InstallerException] (with the
  /// backend's code) when the check fails.
  Future<NewerCheck> checkNewer({InstallChannel? channel});

  /// `hinteros-install --plan - --validate-only`: touches nothing.
  InstallRun validate(InstallPlan plan);

  /// `hinteros-install --plan -`: erases the disk and installs.
  InstallRun install(InstallPlan plan);

  /// `systemctl reboot`.
  Future<void> reboot();
}
