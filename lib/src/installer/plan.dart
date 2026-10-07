/// The installer's plan: the JSON object `hinteros-install --plan -` reads on
/// stdin (format in the system repo's README, "Installer"). This file is the
/// only place that knows the field names.
library;

import 'dart:convert';

enum InstallChannel {
  stable('Stable', 'For everyday use. Changes arrive after they were tried.'),
  beta('Beta', 'New things first. Can have rough edges.');

  const InstallChannel(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// What the backend's `network` field says about the connection.
enum PlanNetwork {
  /// Online if cache.nixos.org answers (the backend's default).
  auto,

  /// Fail early when the box is not online (apps that need a download).
  online,

  /// Do not even try.
  offline,
}

/// Where the install may not go: the same limits as the backend, so the UI
/// can say no early. The backend checks again; it has the last word.
const minDiskBytes = 16 * 1024 * 1024 * 1024;

/// Names the backend refuses for the admin account.
const _reservedUsers = {
  'root',
  'hinteros',
  'nobody',
  'deploy',
  'sshd',
  'daemon',
  'nixbld',
};

/// UI checks mirroring the backend's plan validation. Each returns null when
/// the value is fine, else a sentence for the person at the TV.
abstract final class PlanChecks {
  static final _user = RegExp(r'^[a-z_][a-z0-9_-]{0,31}$');
  static final _host = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

  /// Shortest admin password the installer asks for. The backend only needs
  /// it to be non-empty; this is the UI's own rule (it is the sudo and SSH
  /// password).
  static const minPassword = 8;

  static String? username(String v) {
    if (v.isEmpty) return 'Choose a user name.';
    if (!_user.hasMatch(v)) {
      return 'Use lowercase letters, digits, - and _ only, starting with a '
          'letter (at most 32 characters).';
    }
    if (_reservedUsers.contains(v) ||
        v.startsWith('systemd-') ||
        v.startsWith('nixbld')) {
      return '"$v" is reserved for the system. Choose another name.';
    }
    return null;
  }

  static String? password(String v) {
    if (v.isEmpty) return 'Choose a password.';
    if (v.length < minPassword) {
      return 'The password needs at least $minPassword characters.';
    }
    if (v.contains(RegExp(r'[\n\r\u0000]'))) {
      return 'The password cannot contain line breaks.';
    }
    return null;
  }

  static String? hostname(String v) {
    if (!_host.hasMatch(v)) {
      return 'Use 1 to 63 lowercase letters, digits and hyphens, not '
          'starting or ending with a hyphen.';
    }
    return null;
  }
}

/// Everything the install needs, as the backend wants it. [toJson] is the
/// wire format; [toString] never shows the password.
class InstallPlan {
  const InstallPlan({
    required this.disk,
    required this.hostname,
    required this.adminUser,
    required this.adminPassword,
    this.ssh = false,
    this.channel = InstallChannel.stable,
    this.network = PlanNetwork.auto,
    this.apps = const [],
    this.wifiSsid,
    this.wifiPsk,
  });

  /// Whole-disk device path (lsblk's PATH, `/dev/nvme0n1`).
  final String disk;
  final String hostname;
  final String adminUser;
  final String adminPassword;
  final bool ssh;
  final InstallChannel channel;
  final PlanNetwork network;
  final List<String> apps;

  /// A Wi-Fi network this UI connected to; the installer keeps the
  /// connection on the installed box. Null: nothing to keep.
  final String? wifiSsid;
  final String? wifiPsk;

  Map<String, Object?> toJson() => {
    'disk': disk,
    'hostname': hostname,
    'admin': {'user': adminUser, 'password': adminPassword},
    'ssh': {'enable': ssh},
    'channel': channel.name,
    'base': 'unstable',
    'network': network.name,
    'apps': apps,
    if (wifiSsid != null)
      'wifi': {'ssid': wifiSsid, if (wifiPsk != null) 'psk': wifiPsk},
  };

  /// The bytes for the backend's stdin (UTF-8 JSON, one line).
  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  @override
  String toString() =>
      'InstallPlan(disk: $disk, host: $hostname, admin: $adminUser, '
      'ssh: $ssh, channel: ${channel.name}, apps: $apps, password: <hidden>)';
}
