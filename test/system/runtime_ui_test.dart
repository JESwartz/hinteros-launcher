// The runtime settings screens (Wi-Fi, Bluetooth, display, audio, power) on the
// real repositories over the mock daemon's 0.7 runtime: what the user sees for
// each answer of NetworkManager, BlueZ, PipeWire, gamescope and logind.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart' as api;
import 'package:hinteros_launcher/src/system/daemon_system.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness harness() {
  final mock = api.MockDaemon(
    apps: appsWithIcons(),
    games: gamesWithArt(),
    now: fixedNow,
  );
  return Harness(mock: mock, realServices: daemonSystemServices(mock));
}

/// The startup update check holds the system job slot: end it.
Future<void> endStartupCheck(WidgetTester t, Harness h) async {
  await t.pump();
  final id = h.mock.system.runningJobId;
  if (id != null) h.mock.system.finishJob(id);
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

Future<Harness> start(WidgetTester t) async {
  setView(t);
  final h = harness();
  await h.pump(t);
  await endStartupCheck(t, h);
  return h;
}

/// The display calls that change something (not the reads), in order.
List<String> _changes(api.MockRuntime r) => [
  for (final c in r.calls)
    if (c.startsWith('display.') && c != 'display.modes') c,
];

void main() {
  group('Wi-Fi', () {
    testWidgets('a wrong password asks again; the right one connects', (
      t,
    ) async {
      final h = await start(t);
      final r = h.mock.runtime;
      await enterSettingsEntry(t, 'net');
      expect(find.textContaining('Connected to Home'), findsOneWidget);
      // wifi, scan, then by signal: Home, Home-5G, Cafe Guest, Neighbour.
      await press(t, [kDown, kDown, kDown, kDown, kDown, kEnter]);
      expect(find.text('Password for Neighbour'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'nope nope');
      await press(t, [kEnter]);
      expect(find.text('Password for Neighbour'), findsOneWidget);
      expect(find.textContaining('Wrong password. Try again.'), findsOneWidget);
      expect(r.status().wifiSsid, 'Home', reason: 'nothing changed');
      await t.enterText(find.byType(TextField), 'wifi-pass');
      await press(t, [kEnter]);
      expect(find.text('Password for Neighbour'), findsNothing);
      expect(
        r.calls.where((c) => c == 'wifi.connect'),
        hasLength(2),
        reason: 'once wrong, once right',
      );
      expect(r.status().wifiSsid, 'Neighbour');
      expect(find.textContaining('Connected to Neighbour'), findsOneWidget);
    });

    testWidgets('a saved network joins without a password', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'net');
      await press(t, [kDown, kDown, kDown, kEnter]); // Home-5G
      expect(find.byType(TextField), findsNothing);
      expect(h.mock.runtime.status().wifiSsid, 'Home-5G');
    });

    testWidgets('a saved password that stopped working is asked for again', (
      t,
    ) async {
      final h = await start(t);
      final r = h.mock.runtime;
      r.accessPoints.firstWhere((a) => a.ssid == 'Home-5G').keyChanged = true;
      await enterSettingsEntry(t, 'net');
      await press(t, [kDown, kDown, kDown, kEnter]); // Home-5G
      expect(find.text('Password for Home-5G'), findsOneWidget);
      expect(find.textContaining('saved password'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'correct horse');
      await press(t, [kEnter]);
      expect(find.text('Password for Home-5G'), findsNothing);
      expect(r.status().wifiSsid, 'Home-5G');
    });

    testWidgets('enterprise networks explain instead of asking', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'net');
      await press(t, [kDown, kDown, kDown, kDown, kDown, kDown, kEnter]);
      expect(find.text('Office'), findsWidgets);
      expect(find.textContaining("isn't supported"), findsOneWidget);
      expect(h.mock.runtime.calls.where((c) => c == 'wifi.connect'), isEmpty);
    });

    testWidgets('changes made elsewhere show up (network_changed)', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'net');
      expect(find.textContaining('Connected to Home'), findsOneWidget);
      await h.mock.rpc('wifi.disconnect', {});
      await t.pumpAndSettle();
      expect(find.text('Not connected.'), findsOneWidget);
      h.mock.runtime
        ..ethernet = true
        ..address = '10.0.0.5'
        ..networkChanged();
      await t.pumpAndSettle();
      expect(find.textContaining('Connected by cable'), findsOneWidget);
    });

    testWidgets('a network without internet access is said so', (t) async {
      final h = harness();
      h.mock.runtime.connectivity = api.Connectivity.limited;
      setView(t);
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'net');
      expect(find.textContaining('No internet.'), findsOneWidget);
    });
  });

  group('Bluetooth', () {
    /// Scan, then focus the device named [name] and pick it.
    Future<void> pairFrom(WidgetTester t, int downs) async {
      await press(t, [kEnter]); // scan
      await press(t, [for (var i = 0; i < downs; i++) kDown, kEnter]);
      expect(find.textContaining('Pair with'), findsOneWidget);
      await press(t, [kRight, kEnter]); // Pair
    }

    testWidgets('pair with a numeric comparison: the code, then Accept', (
      t,
    ) async {
      final h = await start(t);
      final r = h.mock.runtime;
      await enterSettingsEntry(t, 'bt');
      expect(find.text('Xbox Wireless Controller'), findsOneWidget);
      expect(find.textContaining('80% battery'), findsOneWidget);
      // scan, pad, Headphones, Keyboard K1, Phone
      await pairFrom(t, 4);
      expect(find.text('Pair with Phone?'), findsWidgets);
      expect(find.byKey(const ValueKey('passkey')), findsOneWidget);
      expect(find.text('012345'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(r.confirmWaiting, 'AA:BB:CC:DD:EE:03');
      await press(t, [kRight, kEnter]); // Accept
      expect(find.text('012345'), findsNothing);
      expect(r.devices.firstWhere((d) => d.name == 'Phone').paired, isTrue);
      expect(find.text('Connected'), findsWidgets);
    });

    testWidgets('Reject fails the pairing and says so', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'bt');
      await pairFrom(t, 4);
      expect(find.text('012345'), findsOneWidget);
      await press(t, [kEnter]); // Reject is focused first
      expect(find.text('012345'), findsNothing);
      expect(find.textContaining('pairing was rejected'), findsOneWidget);
      expect(
        h.mock.runtime.devices.firstWhere((d) => d.name == 'Phone').paired,
        isFalse,
      );
    });

    testWidgets('a device that shows no code: just the code, no buttons to '
        'answer; it closes when the pairing ends', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'bt');
      await pairFrom(t, 3); // Keyboard K1
      expect(find.text('654321'), findsOneWidget);
      expect(find.textContaining('Type this code'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      h.mock.runtime.finishDisplayPairing();
      await t.pumpAndSettle();
      expect(find.text('654321'), findsNothing);
      expect(
        h.mock.runtime.devices
            .firstWhere((d) => d.name == 'Keyboard K1')
            .paired,
        isTrue,
      );
    });

    testWidgets('a controller pairs with no prompt at all', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'bt');
      await pairFrom(t, 2); // Headphones
      expect(find.byKey(const ValueKey('passkey')), findsNothing);
      expect(
        h.mock.runtime.devices.firstWhere((d) => d.name == 'Headphones').paired,
        isTrue,
      );
    });

    testWidgets('devices found by the scan appear by themselves', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'bt');
      expect(find.text('Headphones'), findsNothing);
      await press(t, [kEnter]);
      expect(find.text('Headphones'), findsOneWidget);
      expect(find.text('Searching'), findsOneWidget);
      h.mock.runtime.endScan();
      await t.pumpAndSettle();
      expect(find.text('Searching'), findsNothing);
      expect(h.mock.runtime.scanTimeoutS, isNull);
    });
  });

  group('display', () {
    /// guide, then the drop-down; its list opens at the current mode, the
    /// first: 4K60 (current), 1440p120, 1080p120, 1080p60.
    Future<void> pick(WidgetTester t, int mode) =>
        press(t, [kDown, kEnter, for (var i = 0; i < mode; i++) kDown, kEnter]);

    testWidgets('not kept in 15 seconds: display.revert, not display.keep', (
      t,
    ) async {
      final h = await start(t);
      final r = h.mock.runtime;
      await enterSettingsEntry(t, 'display');
      expect(find.textContaining('Sony TV'), findsOneWidget);
      await pick(t, 1);
      expect(find.textContaining('Keep 2560 x 1440'), findsOneWidget);
      expect(r.displayMode.width, 2560);
      await t.pump(const Duration(seconds: 14));
      expect(find.textContaining('Keep 2560 x 1440'), findsOneWidget);
      expect(find.textContaining('in 1 seconds'), findsOneWidget);
      expect(r.calls, isNot(contains('display.revert')));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.textContaining('Keep 2560'), findsNothing);
      expect(_changes(r), ['display.set_mode', 'display.revert']);
      expect(r.displayMode.width, 3840);
      // The drop-down shows the old mode again.
      expect(find.text('3840 x 2160 at 60 Hz'), findsOneWidget);
    });

    testWidgets('Keep calls display.keep and the mode stays', (t) async {
      final h = await start(t);
      final r = h.mock.runtime;
      await enterSettingsEntry(t, 'display');
      await pick(t, 1);
      await t.pump(const Duration(seconds: 5));
      await press(t, [kRight, kEnter]); // Go back, Keep
      expect(_changes(r), ['display.set_mode', 'display.keep']);
      expect(r.displayMode.width, 2560);
      expect(r.displayChangePending, isFalse);
      // The timer is gone: nothing reverts later.
      await t.pump(const Duration(seconds: 30));
      expect(r.displayMode.width, 2560);
    });

    testWidgets('Go back reverts at once', (t) async {
      final h = await start(t);
      final r = h.mock.runtime;
      await enterSettingsEntry(t, 'display');
      await pick(t, 2);
      await press(t, [kEnter]); // Go back is focused first
      expect(_changes(r), ['display.set_mode', 'display.revert']);
      expect(r.displayMode.width, 3840);
    });

    testWidgets('can_set false explains and changes nothing', (t) async {
      final h = harness();
      h.mock.runtime.displayCanSet = false;
      setView(t);
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'display');
      expect(
        find.textContaining("The resolution of this display can't be changed."),
        findsOneWidget,
      );
      await pick(t, 1);
      expect(find.text("Can't change this"), findsOneWidget);
      expect(h.mock.runtime.calls, isNot(contains('display.set_mode')));
      expect(find.textContaining('Keep '), findsNothing);
    });

    testWidgets('a display that ignores the change says so; no dialog', (
      t,
    ) async {
      final h = await start(t);
      h.mock.runtime.displayIgnoresMode = true;
      await enterSettingsEntry(t, 'display');
      await pick(t, 1);
      expect(
        find.textContaining('did not change to that mode'),
        findsOneWidget,
      );
      expect(find.textContaining('Keep '), findsNothing);
    });
  });

  group('audio', () {
    testWidgets('volume, mute and output go to the daemon; events follow', (
      t,
    ) async {
      final h = await start(t);
      final r = h.mock.runtime;
      await enterSettingsEntry(t, 'audio');
      expect(find.text('60%'), findsOneWidget);
      await press(t, [kRight, kLeft, kLeft]);
      expect(find.text('55%'), findsOneWidget);
      expect(r.audioVolume, 55);
      await press(t, [kEnter]);
      expect(r.audioMuted, isTrue);
      expect(find.text('Muted'), findsOneWidget);
      // Someone else (a headset button) changes it.
      r.audioChangedElsewhere(volume: 20, muted: false);
      await t.pumpAndSettle();
      expect(find.text('20%'), findsOneWidget);
      await press(t, [kDown, kDown, kEnter]); // Headphones
      expect(
        r.audioState().outputs.firstWhere((o) => o.default_).name,
        'Headphones',
      );
    });
  });

  group('power', () {
    testWidgets('sleep goes to logind; restart asks first', (t) async {
      final h = await start(t);
      await enterSettingsEntry(t, 'power');
      await press(t, [kEnter]);
      expect(h.mock.runtime.power, ['suspend']);
      await press(t, [kDown, kEnter]);
      expect(find.text('Restart?'), findsOneWidget);
      await press(t, [kRight]);
      await t.sendKeyEvent(kEnter);
      await t.pump();
      await t.pump();
      expect(h.mock.runtime.power, ['suspend', 'reboot']);
      expect(find.text('Restarting…'), findsOneWidget);
    });

    testWidgets('during an update: "Can\'t do that while an update is being '
        'applied"', (t) async {
      final h = await start(t);
      h.mock.runtime.inhibited = true;
      await enterSettingsEntry(t, 'power');
      await press(t, [kDown, kDown, kEnter, kRight, kEnter]); // shut down
      expect(find.text('Not right now'), findsOneWidget);
      expect(
        find.text("Can't do that while an update is being applied."),
        findsOneWidget,
      );
      expect(h.mock.runtime.power, isEmpty);
      await press(t, [kEnter]);
      expect(find.text('Not right now'), findsNothing);
    });

    testWidgets('an action logind does not allow is marked and explained', (
      t,
    ) async {
      final h = harness();
      h.mock.runtime.powerCapabilities = const api.PowerCapabilities(
        suspend: api.PowerCapability.no,
        reboot: api.PowerCapability.yes,
        poweroff: api.PowerCapability.challenge,
      );
      setView(t);
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'power');
      expect(find.text('Not allowed on this box'), findsNWidgets(2));
      await press(t, [kEnter]);
      expect(find.text("Can't sleep"), findsOneWidget);
      expect(h.mock.runtime.power, isEmpty);
    });
  });

  group('one section down, the others work', () {
    testWidgets('no BlueZ: Bluetooth says so; Wi-Fi, audio, display, power '
        'work', (t) async {
      final h = harness();
      h.mock.runtime.setUnavailable('bluez');
      setView(t);
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'net');
      expect(find.textContaining('Connected to Home'), findsOneWidget);
      // Bluetooth is under Network in the same pane.
      expect(
        find.text("Bluetooth isn't available on this box."),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      await press(t, [kLeft, kDown, kRight]);
      expect(find.textContaining('Sony TV'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      // Left and right change the volume there: Back leaves the pane.
      await downToSection(t, 'audio');
      await press(t, [kEscape, kDown, kDown, kRight]);
      expect(find.text('Sleep'), findsOneWidget);
      // Bluetooth comes back: Try again recovers.
      h.mock.runtime.setUnavailable('bluez', gone: false);
      await press(t, [kLeft, kUp, kUp, kUp, kRight]);
      await downToSection(t, 'bt');
      await press(t, [kEnter]);
      expect(find.text('Xbox Wireless Controller'), findsOneWidget);
    });

    testWidgets('each service names itself', (t) async {
      final h = harness();
      h.mock.runtime
        ..setUnavailable('networkmanager')
        ..setUnavailable('display')
        ..setUnavailable('audio')
        ..setUnavailable('logind');
      setView(t);
      await h.pump(t);
      await endStartupCheck(t, h);
      await enterSettingsEntry(t, 'net');
      expect(find.text("Wi-Fi isn't available on this box."), findsOneWidget);
      await press(t, [kLeft, kDown, kRight]);
      expect(
        find.text("Display control isn't available on this box."),
        findsOneWidget,
      );
      expect(find.text("Audio isn't available on this box."), findsOneWidget);
      await press(t, [kLeft, kDown, kDown, kRight]);
      expect(
        find.text("Power control isn't available on this box."),
        findsOneWidget,
      );
    });
  });
}
