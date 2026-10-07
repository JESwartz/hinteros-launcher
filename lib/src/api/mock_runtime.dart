/// The runtime settings of [MockDaemon] (session API 0.7): Wi-Fi, Bluetooth,
/// audio, display and power, with the daemon's rules. Passwords are checked
/// (`wrong_password`), a numeric-comparison pairing waits for
/// `bluetooth.confirm`, a display change is remembered for `display.revert`
/// until `display.keep`, logind refuses power actions while an inhibitor is
/// set, and each area can be made unavailable on its own (`unavailable`).
/// Events (`network_changed`, `wifi_list_changed`, `bluetooth_changed`,
/// `bluetooth_confirm`, `audio_changed`) follow every change, like the real
/// daemon's (our own changes reach the other clients at once).
///
/// Tests drive it through the fields and methods below. Placeholder data
/// throughout.
library;

import 'dart:async';
import 'dart:convert';

import 'errors.dart';
import 'generated.dart';

/// How a fake Bluetooth device pairs.
enum MockPairing {
  /// Controllers, most headsets: no prompt.
  justWorks,

  /// Numeric comparison: `bluetooth_confirm {mode: confirm}`, then waits for
  /// `bluetooth.confirm` (the real daemon rejects after 30 s; here a test
  /// answers, or sets [MockRuntime.confirmTimeout]).
  confirm,

  /// The device shows no code; the user types the one shown here on it:
  /// `bluetooth_confirm {mode: display}`; the pairing ends when the test calls
  /// [MockRuntime.finishDisplayPairing].
  display,
}

class MockAccessPoint {
  MockAccessPoint(
    this.ssid,
    this.signal,
    this.security, {
    this.password = 'correct horse',
    this.known = false,
  });

  final String ssid;
  int signal;
  final WifiSecurity security;

  /// What the network accepts.
  String password;
  bool known;
  bool connected = false;
}

class MockBtDevice {
  MockBtDevice(
    this.address,
    this.name,
    this.kind, {
    this.paired = false,
    this.connected = false,
    this.trusted = false,
    this.battery,
    this.rssi,
    this.pairing = MockPairing.justWorks,
    this.passkey = '123456',
  });

  final String address;
  final String name;
  final BtKind kind;
  bool paired;
  bool connected;
  bool trusted;
  int? battery;
  int? rssi;
  MockPairing pairing;
  String passkey;

  /// Known to BlueZ (paired before) or found by a scan. Others are not
  /// listed until the first scan.
  bool listed = false;

  BtDevice toApi() => BtDevice(
    address: address,
    name: name,
    kind: kind,
    paired: paired,
    connected: connected,
    trusted: trusted,
    battery: battery,
    rssi: rssi,
  );
}

class MockRuntime {
  MockRuntime({required this.emit}) {
    for (final d in devices) {
      d.listed = d.paired;
    }
  }

  final void Function(String name, Map<String, dynamic> params) emit;

  static const _services = {
    'network': 'networkmanager',
    'wifi': 'networkmanager',
    'bluetooth': 'bluez',
    'audio': 'audio',
    'display': 'display',
    'power': 'logind',
  };

  static bool handles(String method) =>
      _services.containsKey(method.split('.').first);

  /// What the real daemon says when the service is missing.
  static const unavailableReasons = {
    'networkmanager':
        'org.freedesktop.NetworkManager has no owner on the '
        'system bus',
    'bluez': 'org.bluez has no owner on the system bus',
    'audio': 'Connection refused',
    'display': 'no gamescope on :0',
    'logind': 'org.freedesktop.login1 has no owner on the system bus',
  };

  /// Services that answer `unavailable`, with the reason.
  final Map<String, String> unavailable = {};

  /// Makes [service] (`networkmanager`, `bluez`, `audio`, `display`,
  /// `logind`) answer `unavailable`, or brings it back.
  void setUnavailable(String service, {bool gone = true, String? reason}) {
    if (gone) {
      unavailable[service] = reason ?? unavailableReasons[service]!;
    } else {
      unavailable.remove(service);
    }
  }

  /// Methods called, in order (`wifi.connect`, `power.suspend`, ...).
  final List<String> calls = [];

  /// `not_authorized` for the next calls (polkit says no).
  bool notAuthorized = false;

  // ---- Wi-Fi

  bool wifiAvailable = true;
  bool wifiEnabled = true;
  bool ethernet = false;
  Connectivity connectivity = Connectivity.full;
  String address = '192.168.1.20';

  final List<MockAccessPoint> accessPoints = [
    MockAccessPoint('Home', 72, WifiSecurity.wpa, known: true)
      ..connected = true,
    MockAccessPoint('Home-5G', 64, WifiSecurity.wpa, known: true),
    MockAccessPoint('Neighbour', 31, WifiSecurity.wpa3, password: 'wifi-pass'),
    MockAccessPoint('Cafe Guest', 45, WifiSecurity.open),
    MockAccessPoint('Office', 22, WifiSecurity.enterprise),
  ];

  NetworkStatus status() {
    final c = wifiEnabled
        ? accessPoints.where((a) => a.connected).firstOrNull
        : null;
    return NetworkStatus(
      wifiAvailable: wifiAvailable,
      wifiEnabled: wifiEnabled,
      ethernet: ethernet,
      wifiSsid: c?.ssid,
      wifiSignal: c?.signal,
      address: c != null || ethernet ? address : null,
      connectivity: c != null || ethernet ? connectivity : Connectivity.none,
    );
  }

  WifiList wifiList() => WifiList(
    networks: [
      if (wifiEnabled)
        for (final a in [...accessPoints]..sort((a, b) => b.signal - a.signal))
          WifiNetwork(
            ssid: a.ssid,
            signal: a.signal,
            security: a.security,
            known: a.known,
            connected: a.connected,
          ),
    ],
  );

  String? _lastStatus;
  String? _lastList;

  void _emitNetwork() {
    final s = jsonEncode(status().toJson());
    if (s != _lastStatus) {
      _lastStatus = s;
      emit('network_changed', status().toJson());
    }
    final l = jsonEncode(wifiList().toJson());
    if (l != _lastList) {
      _lastList = l;
      emit('wifi_list_changed', wifiList().toJson());
    }
  }

  /// Something else changes the network (the cable is plugged in, ...).
  void networkChanged() => _emitNetwork();

  MockAccessPoint _ap(String ssid) => accessPoints.firstWhere(
    (a) => a.ssid == ssid,
    orElse: () => throw ApiException(
      ApiErrorCode.notFound,
      'no network named $ssid in range',
    ),
  );

  void _needWifi() {
    if (!wifiEnabled) {
      throw const ApiException(
        ApiErrorCode.deviceFailed,
        'Wi-Fi is turned off',
        {'reason': 'wifi_disabled'},
      );
    }
  }

  Map<String, dynamic> _connect(Map<String, dynamic> p) {
    final ssid = _string(p, 'ssid');
    final password = p['password'] as String?;
    _needWifi();
    final ap = _ap(ssid);
    if (ap.security == WifiSecurity.enterprise ||
        ap.security == WifiSecurity.wep) {
      throw ApiException(
        ApiErrorCode.invalidParams,
        '$ssid uses a security the daemon does not join',
        const {'field': 'ssid', 'reason': 'unsupported_security'},
      );
    }
    if (ap.security != WifiSecurity.open) {
      if (password == null && !ap.known) {
        throw ApiException(
          ApiErrorCode.invalidParams,
          '$ssid needs a password',
          const {'field': 'password', 'reason': 'required'},
        );
      }
      if (password != null && password != ap.password) {
        // A connection made for it is removed again: nothing is stored.
        throw ApiException(
          ApiErrorCode.wrongPassword,
          'the password for $ssid was not accepted',
        );
      }
      ap.known = true;
    }
    for (final a in accessPoints) {
      a.connected = a == ap;
    }
    _emitNetwork();
    return status().toJson();
  }

  // ---- Bluetooth

  bool bluetoothAdapter = true;
  bool bluetoothPowered = true;
  bool scanning = false;

  /// The last `bluetooth.scan` timeout asked for.
  int? scanTimeoutS;

  /// The next pairing is rejected on the device (`rejected`).
  bool rejectPairing = false;

  /// How long a `confirm` pairing waits for the answer (null: forever).
  Duration? confirmTimeout;

  final List<MockBtDevice> devices = [
    MockBtDevice(
      'AA:BB:CC:DD:EE:01',
      'Xbox Wireless Controller',
      BtKind.gamepad,
      paired: true,
      connected: true,
      trusted: true,
      battery: 80,
    ),
    MockBtDevice('AA:BB:CC:DD:EE:02', 'Headphones', BtKind.headset, rssi: -60),
    MockBtDevice(
      'AA:BB:CC:DD:EE:03',
      'Phone',
      BtKind.phone,
      rssi: -55,
      pairing: MockPairing.confirm,
      passkey: '012345',
    ),
    MockBtDevice(
      'AA:BB:CC:DD:EE:04',
      'Keyboard K1',
      BtKind.keyboard,
      rssi: -70,
      pairing: MockPairing.display,
      passkey: '654321',
    ),
  ];

  Completer<bool>? _confirming;
  String? _confirmingAddress;
  Completer<bool>? _displaying;
  String? _displayingAddress;

  BtStatus btStatus() => BtStatus(
    available: bluetoothAdapter,
    powered: bluetoothPowered,
    scanning: scanning,
  );

  List<BtDevice> btDevices() {
    final shown = devices.where((d) => d.listed).toList()
      ..sort((a, b) {
        if (a.paired != b.paired) return a.paired ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return [for (final d in shown) d.toApi()];
  }

  void _emitBluetooth() => emit('bluetooth_changed', {
    'status': btStatus().toJson(),
    'devices': [for (final d in btDevices()) d.toJson()],
  });

  MockBtDevice _device(String address) => devices.firstWhere(
    (d) => d.address == address && d.listed,
    orElse: () => throw ApiException(
      ApiErrorCode.notFound,
      'no Bluetooth device $address',
    ),
  );

  void _needAdapter() {
    if (!bluetoothAdapter) {
      throw const ApiException(
        ApiErrorCode.deviceFailed,
        'there is no Bluetooth adapter',
        {'reason': 'no_adapter'},
      );
    }
  }

  Map<String, dynamic> _scan(Map<String, dynamic> p) {
    _needAdapter();
    final on = p['enabled'];
    if (on is! bool) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        'enabled is required',
        {'field': 'enabled', 'reason': 'required'},
      );
    }
    scanning = on;
    scanTimeoutS = p['timeout_s'] as int?;
    if (on) {
      for (final d in devices) {
        d.listed = true;
      }
    }
    _emitBluetooth();
    return btStatus().toJson();
  }

  /// The scan ran out its timeout.
  void endScan() {
    scanning = false;
    _emitBluetooth();
  }

  /// A device shows up (or goes away) on its own.
  void deviceAppears(String address, {bool listed = true}) {
    devices.firstWhere((d) => d.address == address).listed = listed;
    _emitBluetooth();
  }

  Future<Map<String, dynamic>> _pair(Map<String, dynamic> p) async {
    _needAdapter();
    final d = _device(_string(p, 'address'));
    if (!d.paired) {
      switch (d.pairing) {
        case MockPairing.justWorks:
          break;
        case MockPairing.confirm:
          final c = _confirming = Completer<bool>();
          _confirmingAddress = d.address;
          emit('bluetooth_confirm', {
            'address': d.address,
            'name': d.name,
            'passkey': d.passkey,
            'mode': 'confirm',
          });
          Timer? timer;
          if (confirmTimeout != null) {
            timer = Timer(confirmTimeout!, () {
              if (!c.isCompleted) c.complete(false);
            });
          }
          final ok = await c.future;
          timer?.cancel();
          _confirming = null;
          _confirmingAddress = null;
          if (!ok) _pairingRejected();
        case MockPairing.display:
          final c = _displaying = Completer<bool>();
          _displayingAddress = d.address;
          emit('bluetooth_confirm', {
            'address': d.address,
            'name': d.name,
            'passkey': d.passkey,
            'mode': 'display',
          });
          final ok = await c.future;
          _displaying = null;
          _displayingAddress = null;
          if (!ok) _pairingRejected();
      }
      if (rejectPairing) {
        rejectPairing = false;
        _pairingRejected();
      }
      d
        ..paired = true
        ..trusted = true;
    }
    d.connected = true;
    _emitBluetooth();
    return d.toApi().toJson();
  }

  Never _pairingRejected() => throw const ApiException(
    ApiErrorCode.deviceFailed,
    'pairing was rejected',
    {'reason': 'rejected'},
  );

  /// The user typed the code on the device (or gave up: [ok] false).
  void finishDisplayPairing({bool ok = true}) => _displaying?.complete(ok);

  /// Address of the pairing that waits for `bluetooth.confirm`, if any.
  String? get confirmWaiting => _confirmingAddress;
  String? get displayWaiting => _displayingAddress;

  Map<String, dynamic> _confirm(Map<String, dynamic> p) {
    final address = _string(p, 'address');
    final accept = p['accept'];
    final c = _confirming;
    if (accept is! bool) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        'accept is required',
        {'field': 'accept', 'reason': 'required'},
      );
    }
    if (c == null || c.isCompleted || _confirmingAddress != address) {
      throw ApiException(
        ApiErrorCode.notFound,
        'no pairing of $address waits for confirmation',
      );
    }
    c.complete(accept);
    return const {};
  }

  // ---- audio

  bool audioMuted = false;
  int audioVolume = 60;
  final List<AudioOutput> _outputs = [
    const AudioOutput(
      id: 'alsa_output.pci-0000_01_00.1.hdmi-stereo',
      name: 'HDMI / DisplayPort',
      kind: AudioKind.hdmi,
      default_: true,
    ),
    const AudioOutput(
      id: 'bluez_output.AA_BB_CC_DD_EE_02.1',
      name: 'Headphones',
      kind: AudioKind.bluetooth,
      default_: false,
    ),
    const AudioOutput(
      id: 'alsa_output.usb-Gamepad-00.analog-stereo',
      name: 'Controller headset jack',
      kind: AudioKind.usb,
      default_: false,
    ),
  ];

  AudioState audioState() => AudioState(
    outputs: List.of(_outputs),
    volume: audioVolume,
    muted: audioMuted,
  );

  Map<String, dynamic> _audioChanged() {
    final s = audioState().toJson();
    emit('audio_changed', s);
    return s;
  }

  /// Something else changes the sound (a headset connects, a hardware key).
  void audioChangedElsewhere({int? volume, bool? muted, String? output}) {
    if (volume != null) audioVolume = volume;
    if (muted != null) audioMuted = muted;
    if (output != null) _setOutput(output);
    _audioChanged();
  }

  void _setOutput(String id) {
    if (!_outputs.any((o) => o.id == id)) {
      throw ApiException(ApiErrorCode.notFound, 'no audio output $id');
    }
    for (var i = 0; i < _outputs.length; i++) {
      final o = _outputs[i];
      _outputs[i] = AudioOutput(
        id: o.id,
        name: o.name,
        kind: o.kind,
        default_: o.id == id,
      );
    }
  }

  // ---- display

  /// False: an internal panel, or gamescope without the mode save file.
  bool displayCanSet = true;
  String? displayName = 'Sony TV';

  /// gamescope ignores the change (started with `-W/-H/-r`): `not_applied`.
  bool displayIgnoresMode = false;

  final List<Mode> _modes = const [
    Mode(width: 3840, height: 2160, refresh: 60),
    Mode(width: 2560, height: 1440, refresh: 120),
    Mode(width: 1920, height: 1080, refresh: 120),
    Mode(width: 1920, height: 1080, refresh: 60),
    Mode(width: 1280, height: 720, refresh: 60),
  ];
  Mode _current = const Mode(width: 3840, height: 2160, refresh: 60);

  /// The mode before the first change that was neither kept nor reverted.
  Mode? _pending;

  /// The mode the display runs now.
  Mode get displayMode => _current;

  /// Whether a change waits for `display.keep` or `display.revert`.
  bool get displayChangePending => _pending != null;

  DisplayModes displayModes() => DisplayModes(
    modes: [
      for (final m in _modes)
        DisplayModeInfo(
          width: m.width,
          height: m.height,
          refresh: m.refresh,
          current: m == _current,
          preferred: m == _modes.first,
        ),
    ],
    display: displayName,
    canSet: displayCanSet,
  );

  Map<String, dynamic> _setMode(Map<String, dynamic> p) {
    final m = Mode(
      width: _int(p, 'width'),
      height: _int(p, 'height'),
      refresh: _int(p, 'refresh'),
    );
    if (!_modes.contains(m)) {
      throw ApiException(
        ApiErrorCode.notFound,
        'the display has no ${m.width}x${m.height}@${m.refresh} mode',
      );
    }
    if (!displayCanSet || displayIgnoresMode) {
      throw ApiException(
        ApiErrorCode.deviceFailed,
        'gamescope did not switch to ${m.width}x${m.height}@${m.refresh} '
        '(is it started with -W/-H/-r?)',
        const {'reason': 'not_applied'},
      );
    }
    final previous = _current;
    // A second change before deciding reverts to the mode before both.
    _pending ??= previous;
    _current = m;
    return DisplaySetModeResult(previous: previous, current: m).toJson();
  }

  // ---- power

  /// logind's `CanSuspend`, `CanReboot` and `CanPowerOff`.
  PowerCapabilities powerCapabilities = const PowerCapabilities(
    suspend: PowerCapability.yes,
    reboot: PowerCapability.yes,
    poweroff: PowerCapability.yes,
  );

  /// A system job holds its `block` inhibitor (an update is switching over):
  /// logind refuses. `who` and `why` are logind's words.
  bool inhibited = false;
  String inhibitor = 'hinteros-system';
  String inhibitorReason = 'switching to a new system';

  /// `suspend`, `reboot`, `poweroff` accepted by logind, in order.
  final List<String> power = [];

  Map<String, dynamic> _power(String what) {
    if (inhibited) {
      throw ApiException(
        ApiErrorCode.powerInhibited,
        'Operation inhibited by "$inhibitor" (PID 812), reason is '
        '"$inhibitorReason".',
        {'who': inhibitor, 'why': inhibitorReason},
      );
    }
    power.add(what);
    return const {};
  }

  // ---- dispatch

  static String _string(Map<String, dynamic> p, String key) {
    final v = p[key];
    if (v is String && v.isNotEmpty) return v;
    throw ApiException(ApiErrorCode.invalidParams, '$key is required', {
      'field': key,
      'reason': 'required',
    });
  }

  static int _int(Map<String, dynamic> p, String key) {
    final v = p[key];
    if (v is int) return v;
    throw ApiException(ApiErrorCode.invalidParams, '$key is required', {
      'field': key,
      'reason': 'required',
    });
  }

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> p,
  ) async {
    final service = _services[method.split('.').first]!;
    final gone = unavailable[service];
    if (gone != null) {
      throw ApiException(
        ApiErrorCode.unavailable,
        '$service is not available',
        {'service': service, 'reason': gone},
      );
    }
    // Reads and answers to a waiting pairing need no polkit.
    const reads = {
      'network.status',
      'wifi.list',
      'bluetooth.status',
      'bluetooth.devices',
      'bluetooth.confirm',
      'audio.outputs',
      'display.modes',
      'power.capabilities',
    };
    if (notAuthorized && !reads.contains(method)) {
      throw const ApiException(
        ApiErrorCode.notAuthorized,
        'logind refused: Access denied',
      );
    }
    calls.add(method);
    switch (method) {
      case 'network.status':
        return status().toJson();
      case 'wifi.scan':
        _needWifi();
        _emitNetwork();
        return wifiList().toJson();
      case 'wifi.list':
        return wifiList().toJson();
      case 'wifi.connect':
        return _connect(p);
      case 'wifi.disconnect':
        for (final a in accessPoints) {
          a.connected = false;
        }
        _emitNetwork();
        return status().toJson();
      case 'wifi.forget':
        final ap = accessPoints
            .where((a) => a.ssid == _string(p, 'ssid'))
            .firstOrNull;
        if (ap != null) {
          ap
            ..known = false
            ..connected = false;
          _emitNetwork();
        }
        return const {};
      case 'wifi.enable':
        final on = p['enabled'];
        if (on is! bool) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'enabled is required',
            {'field': 'enabled', 'reason': 'required'},
          );
        }
        wifiEnabled = on;
        if (!on) {
          for (final a in accessPoints) {
            a.connected = false;
          }
        }
        _emitNetwork();
        return status().toJson();
      case 'bluetooth.status':
        return btStatus().toJson();
      case 'bluetooth.scan':
        return _scan(p);
      case 'bluetooth.devices':
        return {
          'devices': [for (final d in btDevices()) d.toJson()],
        };
      case 'bluetooth.pair':
        return _pair(p);
      case 'bluetooth.confirm':
        return _confirm(p);
      case 'bluetooth.connect':
        _needAdapter();
        final d = _device(_string(p, 'address'));
        if (!d.paired) {
          throw const ApiException(
            ApiErrorCode.deviceFailed,
            'the device is not paired',
            {'reason': 'not_paired'},
          );
        }
        d.connected = true;
        _emitBluetooth();
        return d.toApi().toJson();
      case 'bluetooth.disconnect':
        _needAdapter();
        final d = _device(_string(p, 'address'));
        d.connected = false;
        _emitBluetooth();
        return d.toApi().toJson();
      case 'bluetooth.forget':
        _needAdapter();
        final d = _device(_string(p, 'address'));
        d
          ..paired = false
          ..connected = false
          ..trusted = false
          ..battery = null
          ..rssi = -60
          ..listed = false;
        _emitBluetooth();
        return const {};
      case 'audio.outputs':
        return audioState().toJson();
      case 'audio.set_output':
        _setOutput(_string(p, 'id'));
        return _audioChanged();
      case 'audio.volume':
        final v = p['percent'];
        if (v != null) {
          if (v is! int || v < 0 || v > 100) {
            throw const ApiException(
              ApiErrorCode.invalidParams,
              'percent is 0 to 100',
              {'field': 'percent', 'reason': 'out_of_range'},
            );
          }
          audioVolume = v;
          return _audioChanged();
        }
        return audioState().toJson();
      case 'audio.mute':
        final m = p['muted'];
        if (m is! bool) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'muted is required',
            {'field': 'muted', 'reason': 'required'},
          );
        }
        audioMuted = m;
        return _audioChanged();
      case 'display.modes':
        return displayModes().toJson();
      case 'display.set_mode':
        return _setMode(p);
      case 'display.keep':
        _pending = null;
        return const {};
      case 'display.revert':
        final back = _pending;
        if (back == null) {
          throw const ApiException(
            ApiErrorCode.deviceFailed,
            'no display change to revert',
            {'reason': 'nothing_to_revert'},
          );
        }
        _pending = null;
        _current = back;
        return {'current': back.toJson()};
      case 'power.capabilities':
        return powerCapabilities.toJson();
      case 'power.suspend':
        return _power('suspend');
      case 'power.reboot':
        return _power('reboot');
      case 'power.poweroff':
        return _power('poweroff');
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }
}
