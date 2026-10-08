// The runtime settings (session API 0.8) against the real hinteros-session
// started with `--no-runtime`: the hello is at 0.8 for the launcher and the
// on-screen keyboard, every runtime method answers `unavailable` with the
// service it needs (the rest of the API is unaffected), and the real
// repositories turn that into "<service> isn't available on this box". Needs
// HINTEROS_SESSION_BIN; skipped otherwise.
//
// Not covered: a private bus (`--runtime-bus`) with fake NetworkManager, BlueZ,
// logind, PipeWire and gamescope. The daemon's fakes are Rust test helpers
// inside its own integration tests (`crates/hinteros-session/tests/runtime_*`),
// not programs, so nothing from Dart can start them; those paths are covered
// against the mock daemon, which passes every schema example.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/osk/osk_backend.dart';
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';

final _bin = Platform.environment['HINTEROS_SESSION_BIN'];

String? _skip() => _bin == null ? 'HINTEROS_SESSION_BIN not set' : null;

void main() {
  late Directory dir;
  late String sock;
  late Process daemon;
  final log = StringBuffer();
  DaemonClient? client;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('runtime_it');
    sock = '${dir.path}/run/session.sock';
    if (_bin == null) return;
    daemon = await Process.start(_bin!, [
      '--socket',
      sock,
      '--no-gamescope',
      '--no-inputplumber',
      '--no-uinput',
      '--no-runtime',
      '--no-auth-agent',
      '--system-socket',
      '${dir.path}/no-such-system.sock',
    ]);
    for (final s in [daemon.stdout, daemon.stderr]) {
      s.transform(utf8.decoder).listen(log.write);
    }
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (FileSystemEntity.typeSync(sock) == FileSystemEntityType.notFound) {
      if (DateTime.now().isAfter(deadline)) fail('daemon did not bind: $log');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });

  tearDown(() async {
    await client?.close();
    client = null;
    if (_bin != null) {
      daemon.kill(ProcessSignal.sigterm);
      await daemon.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          daemon.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    dir.deleteSync(recursive: true);
    log.clear();
  });

  Future<ApiException?> error(Future<Object?> f) => f.then<ApiException?>(
    (_) => null,
    onError: (Object e) => e as ApiException,
  );

  test('the launcher and the on-screen keyboard say hello at 0.8', () async {
    final c = client = DaemonClient(socketPath: sock);
    final hello = await c.waitConnected();
    expect(hello.apiVersion, '0.10');
    expect(apiVersion, '0.10');
    final osk = DaemonOskBackend(
      DaemonClient(socketPath: sock, clientInfo: DaemonOskBackend.oskPeer),
    );
    addTearDown(osk.dispose);
    expect((await osk.connection.waitConnected()).apiVersion, '0.10');
  }, skip: _skip());

  test('--no-runtime: every runtime method is unavailable, naming its service; '
      'the rest of the API works', () async {
    final c = client = DaemonClient(socketPath: sock);
    await c.waitConnected();
    const mac = 'AA:BB:CC:DD:EE:01';
    final calls = <String, Future<Object?> Function()>{
      'networkmanager': () => c.networkStatus(),
      'networkmanager/scan': () => c.wifiScan(),
      'networkmanager/list': () => c.wifiList(),
      'networkmanager/connect': () =>
          c.wifiConnect(const WifiConnectParams(ssid: 'Home')),
      'networkmanager/disconnect': () => c.wifiDisconnect(),
      'networkmanager/forget': () =>
          c.wifiForget(const WifiForgetParams(ssid: 'Home')),
      'networkmanager/enable': () =>
          c.wifiEnable(const WifiEnableParams(enabled: true)),
      'bluez': () => c.bluetoothStatus(),
      'bluez/scan': () =>
          c.bluetoothScan(const BluetoothScanParams(enabled: true)),
      'bluez/devices': () => c.bluetoothDevices(),
      'bluez/pair': () =>
          c.bluetoothPair(const BluetoothPairParams(address: mac)),
      'bluez/connect': () =>
          c.bluetoothConnect(const BluetoothConnectParams(address: mac)),
      'bluez/disconnect': () =>
          c.bluetoothDisconnect(const BluetoothDisconnectParams(address: mac)),
      'bluez/forget': () =>
          c.bluetoothForget(const BluetoothForgetParams(address: mac)),
      'audio': () => c.audioOutputs(),
      'audio/set_output': () =>
          c.audioSetOutput(const AudioSetOutputParams(id: 'x')),
      'audio/volume': () => c.audioVolume(),
      'audio/mute': () => c.audioMute(const AudioMuteParams(muted: true)),
      'display': () => c.displayModes(),
      'display/set_mode': () => c.displaySetMode(
        const DisplaySetModeParams(width: 1920, height: 1080, refresh: 60),
      ),
      'display/revert': () => c.displayRevert(),
      'logind': () => c.powerCapabilities(),
      'logind/suspend': () => c.powerSuspend(),
      'logind/reboot': () => c.powerReboot(),
      'logind/poweroff': () => c.powerPoweroff(),
    };
    for (final e in calls.entries) {
      final service = e.key.split('/').first;
      final err = await error(e.value());
      expect(err, isNotNull, reason: e.key);
      expect(err!.code, ApiErrorCode.unavailable, reason: '${e.key}: $err');
      final data = UnavailableData.fromJson(
        (err.data! as Map).cast<String, dynamic>(),
      );
      expect(data.service.value, service, reason: e.key);
      expect(data.reason, isNotEmpty);
    }
    // `display.keep` has nothing to keep (or is unavailable): never a crash.
    expect(await error(c.displayKeep()), anyOf(isNull, isA<ApiException>()));
    // Unrelated methods are unaffected.
    expect((await c.ping(const PingParams(nonce: 'x'))).nonce, 'x');
    expect((await c.appsList()).apps, isNotEmpty);
  }, skip: _skip());

  test(
    'the real repositories say "<service> isn\'t available on this box"',
    () async {
      final c = client = DaemonClient(socketPath: sock);
      await c.waitConnected();
      final s = daemonSystemServices(c);
      Future<SystemException> fails(Future<Object?> f) async {
        try {
          await f;
        } on SystemException catch (e) {
          return e;
        }
        fail('expected a SystemException');
      }

      final cases = <(String, Future<Object?> Function())>[
        ("Wi-Fi isn't available on this box.", () => s.network.status()),
        ("Wi-Fi isn't available on this box.", () => s.network.scan()),
        ("Bluetooth isn't available on this box.", () => s.bluetooth.load()),
        ("Audio isn't available on this box.", () => s.displayAudio.audio()),
        (
          "Display control isn't available on this box.",
          () => s.displayAudio.displayModes(),
        ),
        (
          "Power control isn't available on this box.",
          () => s.system.powerAllowed(),
        ),
        (
          "Power control isn't available on this box.",
          () => s.system.power(PowerAction.sleep),
        ),
      ];
      for (final (message, call) in cases) {
        final e = await fails(call());
        expect(e.kind, SystemErrorKind.unavailable);
        expect(e.message, message);
        expect(e.data['reason'], isA<String>());
      }
    },
    skip: _skip(),
  );
}
