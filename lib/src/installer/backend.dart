/// What the installer UI needs from the machine. Screens only see
/// [InstallerBackend]: [ProcessInstallerBackend] runs the real tools (the
/// ISO), [FakeInstallerBackend] scripts them (tests and `--installer --mock`).
library;

import '../system/models.dart';
import 'plan.dart';
import 'progress.dart';

/// A backend call that did not work, with a sentence for the screen.
class InstallerException implements Exception {
  const InstallerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NetworkState {
  const NetworkState({
    this.wiredConnected = false,
    this.wifiAvailable = false,
    this.wifiSsid,
    this.online = false,
  });

  /// A cable is plugged in and connected.
  final bool wiredConnected;

  /// There is a Wi-Fi adapter.
  final bool wifiAvailable;

  /// The Wi-Fi network the box is connected to, if any.
  final String? wifiSsid;

  /// The internet can be reached (as far as NetworkManager can tell).
  final bool online;
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
      return 'Removable drive. It could be the installer USB stick.';
    }
    if (sizeBytes < minDiskBytes) return 'Too small: at least 16 GB needed.';
    return null;
  }

  bool get usable => unusableReason == null;
}

abstract class InstallerBackend {
  /// Wired status, Wi-Fi presence, connectivity.
  Future<NetworkState> network();

  /// Visible Wi-Fi networks, strongest first, one per name.
  Future<List<WifiAp>> scanWifi();

  /// Joins [ssid]. The password goes to the tool's stdin, never to its
  /// command line. Throws [InstallerException].
  Future<void> connectWifi(String ssid, {String? psk});

  /// Whole disks of this machine (usable or not: the UI shows why not).
  Future<List<DiskInfo>> disks();

  /// The apps the installer offers, from the catalog index on the ISO.
  Future<List<StoreApp>> catalog();

  /// `hinteros-install --plan - --validate-only`: touches nothing.
  InstallRun validate(InstallPlan plan);

  /// `hinteros-install --plan -`: erases the disk and installs.
  InstallRun install(InstallPlan plan);

  /// `systemctl reboot`.
  Future<void> reboot();
}
