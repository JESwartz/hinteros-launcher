/// Parsers for the output of `lsblk --json` and `nmcli -t`. Tolerant (these
/// tools differ between versions) and pure. The catalog index is parsed in
/// `system/catalog.dart`.
library;

import 'dart:convert';

import '../system/models.dart';
import 'backend.dart';
import 'plan.dart';

/// Arguments for the disk listing (no shell; fixed strings).
const lsblkArgs = [
  '--json',
  '-b',
  '-o',
  'NAME,PATH,SIZE,MODEL,TRAN,TYPE,RM,MOUNTPOINTS',
];

bool _truthy(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

int _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Leftovers of an earlier install try live under /mnt; the backend unmounts
/// them itself, so they do not make a disk "in use".
bool _isInstallLeftover(String m) => m == '/mnt' || m.startsWith('/mnt/');

void _mounts(Map<String, Object?> node, List<String> out) {
  final mp = node['mountpoints'] ?? node['mountpoint'];
  final list = mp is List ? mp : [mp];
  for (final m in list) {
    if (m is String && m.isNotEmpty && !_isInstallLeftover(m)) out.add(m);
  }
  final children = node['children'];
  if (children is List) {
    for (final c in children) {
      if (c is Map<String, Object?>) _mounts(c, out);
    }
  }
}

/// The whole disks (`type == disk`) of `lsblk --json -b` output. Loop
/// devices, optical drives and the like are not disks and do not appear.
/// Throws [FormatException] when [source] is not lsblk's JSON.
List<DiskInfo> parseLsblk(String source) {
  final j = jsonDecode(source);
  if (j is! Map || j['blockdevices'] is! List) {
    throw const FormatException('not lsblk output');
  }
  final disks = <DiskInfo>[];
  for (final d in j['blockdevices'] as List) {
    if (d is! Map<String, Object?>) continue;
    if (d['type'] != 'disk') continue;
    final name = d['name'];
    if (name is! String || name.isEmpty) continue;
    // Compressed RAM swap and RAM disks are not somewhere to install.
    if (name.startsWith('zram') || name.startsWith('ram')) continue;
    final path = d['path'];
    final mounts = <String>[];
    _mounts(d, mounts);
    final model = d['model'];
    final tran = d['tran'];
    disks.add(
      DiskInfo(
        path: path is String && path.startsWith('/dev/') ? path : '/dev/$name',
        name: name,
        sizeBytes: _int(d['size']),
        model: model is String ? model.trim() : null,
        transport: tran is String ? tran : null,
        removable: _truthy(d['rm']) || tran == 'usb',
        mountpoints: mounts,
      ),
    );
  }
  return disks;
}

/// Splits one line of `nmcli -t` output: fields are separated by `:`, and a
/// `:` or `\` inside a value is escaped with a backslash.
List<String> splitTerse(String line) {
  final fields = <String>[];
  final cur = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == r'\' && i + 1 < line.length) {
      cur.write(line[++i]);
    } else if (c == ':') {
      fields.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  fields.add(cur.toString());
  return fields;
}

/// `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list` output:
/// strongest first, one entry per name, hidden networks left out.
List<WifiAp> parseWifiList(String out) {
  final byName = <String, WifiAp>{};
  for (final line in const LineSplitter().convert(out)) {
    final f = splitTerse(line);
    if (f.length < 4) continue;
    final ssid = f[1];
    if (ssid.isEmpty || ssid.runes.any((r) => r < 0x20 || r == 0x7f)) continue;
    final signal = (int.tryParse(f[2]) ?? 0).clamp(0, 100);
    final sec = f[3].trim();
    final secured = sec.isNotEmpty && sec != '--';
    final ap = WifiAp(
      ssid: ssid,
      signal: signal,
      secured: secured,
      inUse: f[0].trim() == '*',
      // WEP and 802.1X need more than a password. A name that starts with a
      // dash could be taken for an option by nmcli.
      supported:
          !sec.contains('WEP') &&
          !sec.contains('802.1X') &&
          !ssid.startsWith('-'),
    );
    final old = byName[ssid];
    if (old == null) {
      byName[ssid] = ap;
    } else {
      // One entry per name: the strongest signal, in use if any of them is.
      final best = old.signal >= ap.signal ? old : ap;
      byName[ssid] = WifiAp(
        ssid: ssid,
        signal: best.signal,
        secured: best.secured,
        inUse: old.inUse || ap.inUse,
        supported: best.supported,
      );
    }
  }
  return byName.values.toList()..sort((a, b) => b.signal.compareTo(a.signal));
}

/// `nmcli -t -f TYPE,STATE,CONNECTION device`. [reachable] is the result of
/// the HTTPS probe, the only thing that counts as "online": a device that is
/// not connected is never online, whatever was probed or cached before.
NetworkState parseNetwork(String deviceStatus, {bool reachable = false}) {
  var wired = false;
  var wifi = false;
  var connecting = false;
  var cableWaiting = false;
  String? ssid;
  for (final line in const LineSplitter().convert(deviceStatus)) {
    final f = splitTerse(line);
    if (f.length < 3) continue;
    // "connected" or "connected (externally)"; "connecting (...)" is not yet.
    final connected = f[1].startsWith('connected');
    if (f[0] == 'ethernet' && connected) wired = true;
    if (f[0] != 'loopback' && f[1].startsWith('connecting')) connecting = true;
    // A cable gives "disconnected" until NetworkManager activates it, and
    // "unavailable" without a cable.
    if (f[0] == 'ethernet' && f[1] == 'disconnected') cableWaiting = true;
    if (f[0] == 'wifi') {
      wifi = true;
      if (connected && f[2].isNotEmpty) ssid = f[2];
    }
  }
  return NetworkState(
    wiredConnected: wired,
    wifiAvailable: wifi,
    wifiSsid: ssid,
    online: reachable && (wired || ssid != null),
    connecting: connecting,
    cableWaiting: cableWaiting,
  );
}

/// What the installer offers when the ISO has no catalog index.
// The index is the source of truth; this is only the safety net for an ISO
// built without it: the free apps that are on the ISO, no terms needed.
List<StoreApp> fallbackCatalog() => const [
  StoreApp(
    id: 'jellyfin',
    name: 'Jellyfin',
    summary: 'Free media player for your own server.',
    category: StoreCategory.video,
    sizeMiB: 280,
    onIso: true,
  ),
  StoreApp(
    id: 'youtube',
    name: 'YouTube',
    summary: 'The website, made for the TV.',
    category: StoreCategory.video,
    sizeMiB: 1,
    onIso: true,
    installerDefault: true,
  ),
  StoreApp(
    id: 'crunchyroll',
    name: 'Crunchyroll',
    summary: 'Anime streaming site.',
    category: StoreCategory.video,
    sizeMiB: 1,
    onIso: true,
  ),
  StoreApp(
    id: 'firefox',
    name: 'Firefox',
    summary: 'A full web browser, for sites that have no app.',
    category: StoreCategory.utilities,
    sizeMiB: 90,
    onIso: true,
    installerDefault: true,
  ),
];

final _rev40 = RegExp(r'^[0-9a-f]{40}$');

HinterRelease? _release(Object? v) {
  if (v is! Map) return null;
  final rev = v['rev'];
  final version = v['version'];
  if (rev is! String || !_rev40.hasMatch(rev)) return null;
  return HinterRelease(
    rev: rev,
    version: version is String && version.isNotEmpty
        ? version
        : rev.substring(0, 12),
  );
}

/// The one stdout line of a successful `hinteros-install --check-newer`.
/// Throws [FormatException] when it is not that shape.
NewerCheck parseNewerCheck(String line) {
  final Object? j = jsonDecode(line.trim());
  if (j is! Map) throw const FormatException('not an object');
  final channel = InstallChannel.values
      .where((c) => c.name == j['channel'])
      .firstOrNull;
  final iso = _release(j['iso']);
  if (channel == null || iso == null) {
    throw const FormatException('channel or iso missing');
  }
  final n = j['newer'];
  final newer = n == null ? null : _release(n);
  if (n != null && newer == null) {
    throw const FormatException('newer is malformed');
  }
  return NewerCheck(channel: channel, iso: iso, newer: newer);
}

/// The one stdout line of `hinteros-install --info`:
/// `{"iso":{"rev","version"},"channel":"stable"}`. Throws [FormatException]
/// when it is not that shape.
InstallerInfo parseInstallerInfo(String line) {
  final Object? j = jsonDecode(line.trim());
  if (j is! Map) throw const FormatException('not an object');
  final channel = InstallChannel.values
      .where((c) => c.name == j['channel'])
      .firstOrNull;
  final iso = _release(j['iso']);
  if (channel == null || iso == null) {
    throw const FormatException('channel or iso missing');
  }
  return InstallerInfo(iso: iso, channel: channel);
}
