// The real network, Bluetooth, display/audio and power repositories over the
// mock daemon's runtime settings (session API 0.7): the mapping of answers,
// events and the 4xxx errors.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/repositories.dart';

Future<(api.MockDaemon, SystemServices)> _setup() async {
  final mock = api.MockDaemon();
  await mock.waitConnected();
  final services = daemonSystemServices(mock);
  addTearDown(mock.close);
  return (mock, services);
}

Future<SystemException> _fails(Future<Object?> f) async {
  try {
    await f;
  } on SystemException catch (e) {
    return e;
  }
  fail('expected a SystemException');
}

/// Lets queued events through.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('Wi-Fi', () {
    test('status and list map the wire objects', () async {
      final (_, s) = await _setup();
      final st = await s.network.status();
      expect(st.wifiSsid, 'Home');
      expect(st.address, '192.168.1.20');
      expect(st.connectivity, Connectivity.full);
      final list = await s.network.list();
      expect(list.first.ssid, 'Home');
      expect(list.first.saved, isTrue);
      expect(list.first.connected, isTrue);
      final office = list.firstWhere((n) => n.ssid == 'Office');
      expect(office.supported, isFalse);
      expect(list.firstWhere((n) => n.ssid == 'Cafe Guest').secured, isFalse);
    });

    test('a wrong password is wrong_password, the right one joins', () async {
      final (mock, s) = await _setup();
      final e = await _fails(
        s.network.connect('Neighbour', password: 'nope nope'),
      );
      expect(e.kind, SystemErrorKind.wrongPassword);
      expect(
        (await s.network.list()).firstWhere((n) => n.ssid == 'Neighbour').saved,
        isFalse,
        reason: 'a rejected key stores nothing',
      );
      await s.network.connect('Neighbour', password: 'wifi-pass');
      expect(mock.runtime.status().wifiSsid, 'Neighbour');
      // Stored now: no password needed again.
      await s.network.connect('Home');
      expect(mock.runtime.status().wifiSsid, 'Home');
    });

    test('a new network needs its password, enterprise is refused', () async {
      final (_, s) = await _setup();
      expect(
        (await _fails(s.network.connect('Neighbour'))).kind,
        SystemErrorKind.invalidParams,
      );
      final e = await _fails(s.network.connect('Office', password: 'x'));
      expect(e.kind, SystemErrorKind.invalidParams);
      expect(e.message, contains("isn't supported"));
      expect(
        (await _fails(s.network.connect('Gone'))).kind,
        SystemErrorKind.notFound,
      );
    });

    test('network_changed and wifi_list_changed arrive as streams', () async {
      final (_, s) = await _setup();
      final statuses = <NetworkStatus>[];
      final lists = <List<WifiNetwork>>[];
      s.network.statusChanges.listen(statuses.add);
      s.network.listChanges.listen(lists.add);
      await s.network.connect('Neighbour', password: 'wifi-pass');
      await _settle();
      expect(statuses.last.wifiSsid, 'Neighbour');
      expect(lists.last.firstWhere((n) => n.connected).ssid, 'Neighbour');
      await s.network.setWifiEnabled(false);
      await _settle();
      expect(statuses.last.wifiEnabled, isFalse);
      expect(lists.last, isEmpty);
    });

    test('NetworkManager missing: unavailable names Wi-Fi only', () async {
      final (mock, s) = await _setup();
      mock.runtime.setUnavailable('networkmanager');
      final e = await _fails(s.network.status());
      expect(e.kind, SystemErrorKind.unavailable);
      expect(e.message, "Wi-Fi isn't available on this box.");
      expect(e.data['service'], 'networkmanager');
      // The other areas keep working.
      expect((await s.displayAudio.audio()).volume, 60);
      expect(await s.system.powerAllowed(), isNotEmpty);
    });
  });

  group('Bluetooth', () {
    test('load lists paired devices first; a scan shows the rest', () async {
      final (_, s) = await _setup();
      await s.bluetooth.load();
      expect(s.bluetooth.current.map((d) => d.name), [
        'Xbox Wireless Controller',
      ]);
      expect(s.bluetooth.current.single.kind, BtKind.controller);
      expect(s.bluetooth.current.single.battery, 80);
      await s.bluetooth.startScan();
      await _settle();
      expect(s.bluetooth.scanning, isTrue);
      expect(s.bluetooth.current.length, 4);
      expect(s.bluetooth.current.first.paired, isTrue);
    });

    test('a controller pairs without a prompt', () async {
      final (mock, s) = await _setup();
      await s.bluetooth.load();
      await s.bluetooth.startScan();
      await s.bluetooth.pair('AA:BB:CC:DD:EE:02');
      await _settle();
      final d = s.bluetooth.current.firstWhere(
        (d) => d.id == 'AA:BB:CC:DD:EE:02',
      );
      expect(d.paired && d.connected, isTrue);
      expect(
        mock.runtime.devices.firstWhere((d) => d.name == 'Headphones').trusted,
        isTrue,
      );
    });

    test('numeric comparison: confirm request, then accept', () async {
      final (_, s) = await _setup();
      await s.bluetooth.load();
      await s.bluetooth.startScan();
      final asked = Completer<BtConfirmRequest>();
      s.bluetooth.confirmRequests.listen(asked.complete);
      final pairing = s.bluetooth.pair('AA:BB:CC:DD:EE:03');
      final r = await asked.future;
      expect(r.name, 'Phone');
      expect(r.passkey, '012345');
      expect(r.mustAnswer, isTrue);
      await s.bluetooth.confirm(r.id, accept: true);
      await pairing;
      await _settle();
      expect(
        s.bluetooth.current.firstWhere((d) => d.id == r.id).paired,
        isTrue,
      );
    });

    test('rejecting fails the pairing with device_failed', () async {
      final (_, s) = await _setup();
      await s.bluetooth.load();
      await s.bluetooth.startScan();
      final asked = Completer<BtConfirmRequest>();
      s.bluetooth.confirmRequests.listen(asked.complete);
      final pairing = _fails(s.bluetooth.pair('AA:BB:CC:DD:EE:03'));
      await s.bluetooth.confirm((await asked.future).id, accept: false);
      final e = await pairing;
      expect(e.kind, SystemErrorKind.deviceFailed);
      expect(e.data['reason'], 'rejected');
    });

    test('a device that shows the code: mode display, no answer', () async {
      final (mock, s) = await _setup();
      await s.bluetooth.load();
      await s.bluetooth.startScan();
      final asked = Completer<BtConfirmRequest>();
      s.bluetooth.confirmRequests.listen(asked.complete);
      final pairing = s.bluetooth.pair('AA:BB:CC:DD:EE:04');
      final r = await asked.future;
      expect(r.mustAnswer, isFalse);
      expect(r.passkey, '654321');
      mock.runtime.finishDisplayPairing();
      await pairing;
    });

    test('connect, disconnect, forget follow bluetooth_changed', () async {
      final (_, s) = await _setup();
      await s.bluetooth.load();
      const pad = 'AA:BB:CC:DD:EE:01';
      await s.bluetooth.disconnect(pad);
      await _settle();
      expect(s.bluetooth.current.single.connected, isFalse);
      await s.bluetooth.connect(pad);
      await _settle();
      expect(s.bluetooth.current.single.connected, isTrue);
      await s.bluetooth.forget(pad);
      await _settle();
      expect(s.bluetooth.current, isEmpty);
    });

    test('no adapter and no BlueZ are unavailable', () async {
      final (mock, s) = await _setup();
      mock.runtime.bluetoothAdapter = false;
      expect(
        (await _fails(s.bluetooth.load())).kind,
        SystemErrorKind.unavailable,
      );
      mock.runtime
        ..bluetoothAdapter = true
        ..setUnavailable('bluez');
      final e = await _fails(s.bluetooth.load());
      expect(e.message, "Bluetooth isn't available on this box.");
    });
  });

  group('audio', () {
    test('outputs, volume and mute; the default output is current', () async {
      final (_, s) = await _setup();
      var a = await s.displayAudio.audio();
      expect(a.outputs.where((o) => o.current).single.name, contains('HDMI'));
      await s.displayAudio.setVolume(35);
      await s.displayAudio.setMuted(true);
      a = await s.displayAudio.audio();
      expect((a.volume, a.muted), (35, true));
      await s.displayAudio.setAudioOutput('bluez_output.AA_BB_CC_DD_EE_02.1');
      a = await s.displayAudio.audio();
      expect(a.outputs.firstWhere((o) => o.current).name, 'Headphones');
      expect(
        (await _fails(s.displayAudio.setAudioOutput('nope'))).kind,
        SystemErrorKind.notFound,
      );
    });

    test('audio_changed carries changes made elsewhere', () async {
      final (mock, s) = await _setup();
      final seen = <AudioState>[];
      s.displayAudio.audioChanges.listen(seen.add);
      mock.runtime.audioChangedElsewhere(volume: 20, muted: true);
      await _settle();
      expect((seen.last.volume, seen.last.muted), (20, true));
    });
  });

  group('display', () {
    test('modes, then keep or revert', () async {
      final (mock, s) = await _setup();
      var info = await s.displayAudio.displayModes();
      expect(info.canSet, isTrue);
      expect(info.display, 'Sony TV');
      expect(info.modes.firstWhere((m) => m.current).label, contains('3840'));
      final hd = info.modes.firstWhere(
        (m) => m.width == 1920 && m.refreshHz == 60,
      );
      await s.displayAudio.setDisplayMode(hd);
      expect(mock.runtime.displayMode.width, 1920);
      await s.displayAudio.revertDisplayMode();
      expect(mock.runtime.displayMode.width, 3840);
      await s.displayAudio.setDisplayMode(hd);
      await s.displayAudio.keepDisplayMode();
      expect(mock.runtime.displayChangePending, isFalse);
      info = await s.displayAudio.displayModes();
      expect(info.modes.firstWhere((m) => m.current).width, 1920);
    });

    test('two changes before deciding revert to the first mode', () async {
      final (mock, s) = await _setup();
      final info = await s.displayAudio.displayModes();
      DisplayMode m(int w, int h) =>
          info.modes.firstWhere((x) => x.width == w && x.height == h);
      await s.displayAudio.setDisplayMode(m(1920, 1080));
      await s.displayAudio.setDisplayMode(m(1280, 720));
      await s.displayAudio.revertDisplayMode();
      expect(mock.runtime.displayMode.width, 3840);
    });

    test('a display that ignores the change says so; revert with nothing '
        'pending is device_failed', () async {
      final (mock, s) = await _setup();
      mock.runtime.displayIgnoresMode = true;
      final info = await s.displayAudio.displayModes();
      final e = await _fails(s.displayAudio.setDisplayMode(info.modes.last));
      expect(e.kind, SystemErrorKind.deviceFailed);
      expect(e.data['reason'], 'not_applied');
      expect(e.message, contains('did not change to that mode'));
      expect(
        (await _fails(s.displayAudio.revertDisplayMode())).data['reason'],
        'nothing_to_revert',
      );
    });

    test('can_set false is passed on', () async {
      final (mock, s) = await _setup();
      mock.runtime.displayCanSet = false;
      expect((await s.displayAudio.displayModes()).canSet, isFalse);
    });

    test('no gamescope: unavailable', () async {
      final (mock, s) = await _setup();
      mock.runtime.setUnavailable('display');
      final e = await _fails(s.displayAudio.displayModes());
      expect(e.message, "Display control isn't available on this box.");
    });
  });

  group('power', () {
    test('capabilities and the three actions', () async {
      final (mock, s) = await _setup();
      expect(await s.system.powerAllowed(), PowerAction.values.toSet());
      await s.system.power(PowerAction.sleep);
      await s.system.power(PowerAction.restart);
      await s.system.power(PowerAction.shutdown);
      expect(mock.runtime.power, ['suspend', 'reboot', 'poweroff']);
    });

    test('logind says no or challenge: the action is not allowed', () async {
      final (mock, s) = await _setup();
      mock.runtime.powerCapabilities = const api.PowerCapabilities(
        suspend: api.PowerCapability.no,
        reboot: api.PowerCapability.challenge,
        poweroff: api.PowerCapability.yes,
      );
      expect(await s.system.powerAllowed(), {PowerAction.shutdown});
    });

    test('an update holds the inhibitor: power_inhibited', () async {
      final (mock, s) = await _setup();
      mock.runtime.inhibited = true;
      final e = await _fails(s.system.power(PowerAction.restart));
      expect(e.kind, SystemErrorKind.powerInhibited);
      expect(e.message, "Can't do that while an update is being applied.");
      expect(e.data['who'], 'hinteros-system');
      expect(mock.runtime.power, isEmpty);
    });

    test('polkit says no: not_authorized', () async {
      final (mock, s) = await _setup();
      mock.runtime.notAuthorized = true;
      expect(
        (await _fails(s.system.power(PowerAction.shutdown))).kind,
        SystemErrorKind.notAuthorized,
      );
    });

    test('no logind: unavailable', () async {
      final (mock, s) = await _setup();
      mock.runtime.setUnavailable('logind');
      final e = await _fails(s.system.powerAllowed());
      expect(e.message, "Power control isn't available on this box.");
    });
  });
}
