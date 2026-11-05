/// The runtime settings over session API 0.7: Wi-Fi (`network.status`,
/// `wifi.*`), Bluetooth (`bluetooth.*`), audio (`audio.*`) and display
/// (`display.*`). Power lives in `DaemonSystem`.
///
/// Each area degrades on its own: when the daemon answers `unavailable`
/// (4001: no NetworkManager, BlueZ, PipeWire, gamescope or logind) only that
/// area's calls throw [SystemErrorKind.unavailable]. Events keep the screens
/// current: `network_changed`, `wifi_list_changed`, `bluetooth_changed`,
/// `bluetooth_confirm`, `audio_changed`.
library;

import 'dart:async';

import '../api/api.dart' as api;
import 'daemon_errors.dart';
import 'models.dart';
import 'repositories.dart';

Future<void> _subscribe(
  api.DaemonConnection conn,
  Iterable<api.EventName> names,
) => conn.subscribeTo(names).then((_) {}, onError: (_) {});

// ---------------------------------------------------------------- network

NetworkStatus _status(
  bool wifiAvailable,
  bool wifiEnabled,
  bool ethernet,
  String? ssid,
  int? signal,
  String? address,
  api.Connectivity connectivity,
) => NetworkStatus(
  wifiAvailable: wifiAvailable,
  wifiEnabled: wifiEnabled,
  ethernet: ethernet,
  wifiSsid: ssid,
  wifiSignal: signal,
  address: address,
  connectivity: switch (connectivity) {
    api.Connectivity.none => Connectivity.none,
    api.Connectivity.portal => Connectivity.portal,
    api.Connectivity.limited => Connectivity.limited,
    api.Connectivity.full => Connectivity.full,
    _ => Connectivity.unknown,
  },
);

List<WifiNetwork> _networks(List<api.WifiNetwork> list) => [
  for (final n in list)
    WifiNetwork(
      id: n.id,
      ssid: n.ssid,
      signal: n.signal,
      secured: n.security != api.WifiSecurity.open,
      connected: n.connected,
      saved: n.known,
      supported: const {
        api.WifiSecurity.open,
        api.WifiSecurity.wpa,
        api.WifiSecurity.wpa3,
      }.contains(n.security),
    ),
];

class DaemonNetwork implements NetworkRepository {
  DaemonNetwork(this._conn) {
    _events = _conn.events.listen((ev) {
      switch (ev) {
        case api.NetworkChangedEvent():
          _statusChanges.add(
            _status(
              ev.wifiAvailable,
              ev.wifiEnabled,
              ev.ethernet,
              ev.wifiSsid,
              ev.wifiSignal,
              ev.address,
              ev.connectivity,
            ),
          );
        case api.WifiListChangedEvent():
          _listChanges.add(_networks(ev.networks));
        default:
      }
    });
    unawaited(
      _subscribe(_conn, const [
        api.EventName.networkChanged,
        api.EventName.wifiListChanged,
      ]),
    );
  }

  final api.DaemonConnection _conn;
  // ignore: unused_field
  late final StreamSubscription<api.SessionEvent> _events;
  final _statusChanges = StreamController<NetworkStatus>.broadcast();
  final _listChanges = StreamController<List<WifiNetwork>>.broadcast();

  @override
  Stream<NetworkStatus> get statusChanges => _statusChanges.stream;

  @override
  Stream<List<WifiNetwork>> get listChanges => _listChanges.stream;

  @override
  Future<NetworkStatus> status() => guardCall(() async {
    final s = await _conn.networkStatus();
    return _status(
      s.wifiAvailable,
      s.wifiEnabled,
      s.ethernet,
      s.wifiSsid,
      s.wifiSignal,
      s.address,
      s.connectivity,
    );
  });

  @override
  Future<List<WifiNetwork>> scan() =>
      guardCall(() async => _networks((await _conn.wifiScan()).networks));

  @override
  Future<List<WifiNetwork>> list() =>
      guardCall(() async => _networks((await _conn.wifiList()).networks));

  @override
  Future<void> connect(String id, {String? password}) => guardCall(
    () => _conn.wifiConnect(api.WifiConnectParams(id: id, password: password)),
  );

  @override
  Future<void> disconnect() => guardCall(() => _conn.wifiDisconnect());

  @override
  Future<void> forget(String id) =>
      guardCall(() => _conn.wifiForget(api.WifiForgetParams(id: id)));

  @override
  Future<void> setWifiEnabled(bool enabled) =>
      guardCall(() => _conn.wifiEnable(api.WifiEnableParams(enabled: enabled)));
}

// ---------------------------------------------------------------- bluetooth

BtKind _btKind(api.BtKind k) => switch (k) {
  api.BtKind.gamepad => BtKind.controller,
  api.BtKind.headset => BtKind.headset,
  api.BtKind.speaker => BtKind.speaker,
  api.BtKind.keyboard => BtKind.keyboard,
  api.BtKind.mouse => BtKind.mouse,
  api.BtKind.phone => BtKind.phone,
  api.BtKind.computer => BtKind.computer,
  api.BtKind.other || api.BtKind.unknown => BtKind.other,
};

BtDevice _btDevice(api.BtDevice d) => BtDevice(
  id: d.address,
  name: d.name,
  kind: _btKind(d.kind),
  paired: d.paired,
  connected: d.connected,
  battery: d.battery,
);

class DaemonBluetooth implements BluetoothRepository {
  DaemonBluetooth(this._conn) {
    _events = _conn.events.listen((ev) {
      switch (ev) {
        case api.BluetoothChangedEvent():
          _scanning = ev.status.scanning;
          _set([for (final d in ev.devices) _btDevice(d)]);
        case api.BluetoothConfirmEvent():
          _confirms.add(
            BtConfirmRequest(
              id: ev.address,
              name: ev.name_,
              passkey: ev.passkey,
              mustAnswer: ev.mode == api.BluetoothConfirmEventMode.confirm,
            ),
          );
        default:
      }
    });
    unawaited(
      _subscribe(_conn, const [
        api.EventName.bluetoothChanged,
        api.EventName.bluetoothConfirm,
      ]),
    );
  }

  final api.DaemonConnection _conn;
  // ignore: unused_field
  late final StreamSubscription<api.SessionEvent> _events;
  final _changes = StreamController<List<BtDevice>>.broadcast();
  final _confirms = StreamController<BtConfirmRequest>.broadcast();
  List<BtDevice> _devices = const [];
  bool _scanning = false;

  void _set(List<BtDevice> d) {
    _devices = d;
    _changes.add(d);
  }

  @override
  bool get scanning => _scanning;
  @override
  Stream<List<BtDevice>> get devices => _changes.stream;
  @override
  List<BtDevice> get current => List.unmodifiable(_devices);
  @override
  Stream<BtConfirmRequest> get confirmRequests => _confirms.stream;

  @override
  Future<void> load() => guardCall(() async {
    final s = await _conn.bluetoothStatus();
    if (!s.available) {
      throw const SystemException(
        SystemErrorKind.unavailable,
        "Bluetooth isn't available on this box.",
        data: {'service': 'bluez', 'reason': 'no_adapter'},
      );
    }
    _scanning = s.scanning;
    _devices = [
      for (final d in (await _conn.bluetoothDevices()).devices) _btDevice(d),
    ];
  });

  @override
  Future<void> startScan({int? timeoutS}) => guardCall(() async {
    _scanning = (await _conn.bluetoothScan(
      api.BluetoothScanParams(enabled: true, timeoutS: timeoutS),
    )).scanning;
  });

  @override
  Future<void> stopScan() => guardCall(() async {
    _scanning = (await _conn.bluetoothScan(
      const api.BluetoothScanParams(enabled: false),
    )).scanning;
  });

  @override
  Future<void> confirm(String id, {required bool accept}) => guardCall(
    () => _conn.bluetoothConfirm(
      api.BluetoothConfirmParams(address: id, accept: accept),
    ),
  );

  @override
  Future<void> pair(String id) => guardCall(
    () => _conn.bluetoothPair(api.BluetoothPairParams(address: id)),
  );

  @override
  Future<void> connect(String id) => guardCall(
    () => _conn.bluetoothConnect(api.BluetoothConnectParams(address: id)),
  );

  @override
  Future<void> disconnect(String id) => guardCall(
    () => _conn.bluetoothDisconnect(api.BluetoothDisconnectParams(address: id)),
  );

  @override
  Future<void> forget(String id) => guardCall(
    () => _conn.bluetoothForget(api.BluetoothForgetParams(address: id)),
  );
}

// ---------------------------------------------------------------- display, audio

AudioState _audio(List<api.AudioOutput> outputs, int volume, bool muted) =>
    AudioState(
      outputs: [
        for (final o in outputs)
          AudioOutput(id: o.id, name: o.name, current: o.default_),
      ],
      volume: volume,
      muted: muted,
    );

class DaemonDisplayAudio implements DisplayAudioRepository {
  DaemonDisplayAudio(this._conn) {
    _events = _conn.events.listen((ev) {
      if (ev is api.AudioChangedEvent) {
        _audioChanges.add(_audio(ev.outputs, ev.volume, ev.muted));
      }
    });
    unawaited(_subscribe(_conn, const [api.EventName.audioChanged]));
  }

  final api.DaemonConnection _conn;
  // ignore: unused_field
  late final StreamSubscription<api.SessionEvent> _events;
  final _audioChanges = StreamController<AudioState>.broadcast();

  @override
  Stream<AudioState> get audioChanges => _audioChanges.stream;

  @override
  Future<DisplayInfo> displayModes() => guardCall(() async {
    final r = await _conn.displayModes();
    return DisplayInfo(
      canSet: r.canSet,
      display: r.display,
      modes: [
        for (final m in r.modes)
          DisplayMode(
            width: m.width,
            height: m.height,
            refreshHz: m.refresh.toDouble(),
            current: m.current,
            preferred: m.preferred,
          ),
      ],
    );
  });

  @override
  Future<void> setDisplayMode(DisplayMode mode) => guardCall(
    () => _conn.displaySetMode(
      api.DisplaySetModeParams(
        width: mode.width,
        height: mode.height,
        refresh: mode.refreshHz.round(),
      ),
    ),
  );

  @override
  Future<void> keepDisplayMode() => guardCall(() => _conn.displayKeep());

  @override
  Future<void> revertDisplayMode() => guardCall(() => _conn.displayRevert());

  @override
  Future<AudioState> audio() => guardCall(() async {
    final r = await _conn.audioOutputs();
    return _audio(r.outputs, r.volume, r.muted);
  });

  @override
  Future<void> setAudioOutput(String id) =>
      guardCall(() => _conn.audioSetOutput(api.AudioSetOutputParams(id: id)));

  @override
  Future<void> setVolume(int percent) => guardCall(
    () => _conn.audioVolume(api.AudioVolumeParams(percent: percent)),
  );

  @override
  Future<void> setMuted(bool muted) =>
      guardCall(() => _conn.audioMute(api.AudioMuteParams(muted: muted)));
}
