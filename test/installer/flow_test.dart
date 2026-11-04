import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/fake_backend.dart';
import 'package:hinteros_launcher/src/installer/flow.dart';

import '../support/harness.dart' show pumpFor;
import '../support/installer_harness.dart';

const online = NetworkState(
  wiredConnected: true,
  wifiAvailable: true,
  online: true,
);

void main() {
  group('welcome and network', () {
    testWidgets('Welcome starts the install steps; Back goes back', (t) async {
      final h = InstallerHarness();
      await h.pump(t);
      expect(find.text('Welcome to HinterOS'), findsOneWidget);
      expect(h.focus, 'content/start:0');
      await h.back(t); // nowhere to go
      expect(h.flow.step, InstallerStep.welcome);
      await h.accept(t);
      expect(h.flow.step, InstallerStep.network);
      expect(find.text('Step 1 of 6'), findsOneWidget);
      await h.back(t);
      expect(h.flow.step, InstallerStep.welcome);
    });

    testWidgets('offline: says so, and carries on without internet', (t) async {
      final h = InstallerHarness();
      await h.start(t);
      expect(find.text('This computer is not online.'), findsOneWidget);
      expect(find.text('Continue without internet'), findsOneWidget);
      expect(find.text('No Wi-Fi adapter found.'), findsOneWidget);
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.disk);
      expect(h.flow.online, isFalse);
    });

    testWidgets('wired: online, Continue', (t) async {
      final h = InstallerHarness(backend: FakeInstallerBackend(state: online));
      await h.start(t);
      expect(find.text('Network cable: connected.'), findsOneWidget);
      expect(find.text('This computer is online.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(h.flow.online, isTrue);
    });

    testWidgets('Wi-Fi: the password comes from the on-screen keyboard', (
      t,
    ) async {
      final backend = FakeInstallerBackend(
        state: const NetworkState(wifiAvailable: true),
        wifiPasswords: {'Living Room': 'correct horse'},
      );
      final h = InstallerHarness(backend: backend);
      await h.start(t);
      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('Office (802.1X)'), findsOneWidget);
      expect(find.text('Not supported.'), findsOneWidget);

      // A wrong password: the error is shown, still offline.
      await h.choose(t, 'w:Living Room');
      expect(find.text('Password for Living Room'), findsOneWidget);
      await h.type(t, 'wrong');
      expect(find.textContaining('Check the password'), findsOneWidget);
      expect(h.flow.online, isFalse);

      // The right one.
      await h.choose(t, 'w:Living Room');
      await h.type(t, 'correct horse');
      expect(find.text('This computer is online.'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(
        backend.calls.where((c) => c == 'connectWifi:Living Room').length,
        2,
      );

      // An unsupported network cannot be chosen.
      await h.moveTo(t, 'w:Office (802.1X)');
      await h.accept(t);
      expect(backend.calls.contains('connectWifi:Office (802.1X)'), isFalse);
      expect(h.console(t).typing, isFalse);
    });

    /// On the internet step with a Wi-Fi scan that waits for [gate]: the
    /// spinner turns, so only frames, no settle.
    Future<InstallerHarness> slowScan(
      WidgetTester t,
      Completer<void> gate,
    ) async {
      final h = InstallerHarness(
        backend: FakeInstallerBackend(
          state: const NetworkState(wifiAvailable: true),
          scanHold: gate.future,
        ),
      );
      await h.pump(t);
      h.flow.next();
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(h.flow.step, InstallerStep.network);
      expect(find.text('Searching…'), findsOneWidget);
      return h;
    }

    testWidgets('a slow Wi-Fi scan: the focus goes to the first network', (
      t,
    ) async {
      final gate = Completer<void>();
      final h = await slowScan(t, gate);
      expect(h.focus, 'content/actions:0', reason: 'only the buttons yet');
      gate.complete();
      await t.pumpAndSettle();
      expect(h.focus, 'content/w:Living Room:0');
      // A later scan does not move it again.
      await h.moveTo(t, 'actions');
      await h.flow.scanWifi();
      await t.pumpAndSettle();
      expect(h.focus, 'content/actions:0');
    });

    testWidgets('a slow Wi-Fi scan: a focus that was moved stays', (t) async {
      final gate = Completer<void>();
      final h = await slowScan(t, gate);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(h.focus, 'content/actions:1');
      gate.complete();
      await t.pumpAndSettle();
      expect(h.focus, 'content/actions:1');
    });

    testWidgets('an open Wi-Fi network joins without a password', (t) async {
      final backend = FakeInstallerBackend(
        state: const NetworkState(wifiAvailable: true),
      );
      final h = InstallerHarness(backend: backend);
      await h.start(t);
      await h.choose(t, 'w:Cafe Guest');
      expect(h.console(t).typing, isFalse);
      expect(h.flow.online, isTrue);
      expect(h.flow.joinedSsid, 'Cafe Guest');
    });
  });

  group('disk', () {
    Future<InstallerHarness> toDisk(WidgetTester t) async {
      final h = InstallerHarness();
      await h.start(t);
      await h.choose(t, 'actions', 1);
      return h;
    }

    testWidgets(
      'unusable disks are shown with the reason and cannot be chosen',
      (t) async {
        final h = await toDisk(t);
        expect(find.textContaining('Example NVMe 512GB'), findsOneWidget);
        expect(find.textContaining('Example SATA SSD 1TB'), findsOneWidget);
        expect(find.textContaining('In use (mounted at /iso)'), findsOneWidget);
        expect(find.textContaining('Removable drive'), findsOneWidget);
        expect(
          find.textContaining('Too small: at least 17.2 GB'),
          findsOneWidget,
        );
        expect(find.text('Cannot be used'), findsNWidgets(3));
        expect(buttonEnabled(t, 'Continue'), isFalse);

        // Pressing accept on the stick (row d3) does nothing.
        await h.moveTo(t, 'd3');
        await h.accept(t);
        expect(h.flow.disk, isNull);
        expect(h.flow.step, InstallerStep.disk);

        // The NVMe disk can.
        await h.choose(t, 'd0');
        expect(h.flow.disk!.path, '/dev/nvme0n1');
        expect(buttonEnabled(t, 'Continue'), isTrue);
      },
    );

    testWidgets('Continue goes on without a question', (t) async {
      final h = await toDisk(t);
      await h.choose(t, 'd0');
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.account);
      expect(h.flow.disk!.name, 'nvme0n1');
      expect(h.backend.calls, isNot(contains('install')));
    });

    testWidgets('Refresh: a disk plugged in again is not the chosen one', (
      t,
    ) async {
      final h = await toDisk(t);
      await h.choose(t, 'd0');
      expect(h.flow.disk!.diskSeq, 1);
      h.backend.replug('/dev/nvme0n1');
      await h.choose(t, 'actions', 0); // Refresh
      expect(h.flow.disk, isNull, reason: 'same path, another disk');
      expect(buttonEnabled(t, 'Continue'), isFalse);

      // The SATA disk did not change: its choice stays.
      await h.choose(t, 'd1');
      await h.choose(t, 'actions', 0);
      expect(h.flow.disk!.path, '/dev/sda');
    });

    testWidgets('no usable disk: an error and no way on', (t) async {
      final h = InstallerHarness(
        backend: FakeInstallerBackend(disks: [mockDisks()[3], mockDisks()[2]]),
      );
      await h.start(t);
      // No install to keep: the disk step is the last before the summary.
      await h.choose(t, 'actions', 1);
      expect(h.flow.step, InstallerStep.account);
      h.flow.go(InstallerStep.disk);
      await t.pumpAndSettle();
      expect(find.textContaining('No disk can be used'), findsOneWidget);
      expect(buttonEnabled(t, 'Continue'), isFalse);
    });
  });

  group('admin account', () {
    Future<InstallerHarness> toAccount(WidgetTester t) async {
      final h = InstallerHarness();
      await h.start(t);
      h.flow.chooseDisk(mockDisks().first);
      h.flow.go(InstallerStep.account);
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('user name and password come from the on-screen keyboard', (
      t,
    ) async {
      final h = await toAccount(t);
      expect(buttonEnabled(t, 'Continue'), isFalse);
      await h.choose(t, 'user');
      expect(h.console(t).typing, isTrue);
      await h.type(t, 'james');
      expect(h.flow.username, 'james');
      expect(find.text('james'), findsOneWidget);
      // Never shown in the clear.
      await h.choose(t, 'pw');
      await h.type(t, 'sekrit-pass');
      expect(find.text('sekrit-pass'), findsNothing);
      expect(find.text('•' * 11), findsOneWidget);
    });

    testWidgets('a password that does not match is refused', (t) async {
      final h = await toAccount(t);
      await h.choose(t, 'user');
      await h.type(t, 'james');
      await h.choose(t, 'pw');
      await h.type(t, 'longpassword1');
      await h.choose(t, 'pw2');
      await h.type(t, 'longpassword2');
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(buttonEnabled(t, 'Continue'), isFalse);
      // Accepting a disabled Continue does nothing.
      await h.moveTo(t, 'actions');
      await h.accept(t);
      expect(h.flow.step, InstallerStep.account);

      await h.choose(t, 'pw2');
      await h.type(t, 'longpassword1');
      expect(find.text('The passwords do not match.'), findsNothing);
      expect(find.text('The account looks good.'), findsNothing);
      expect(buttonEnabled(t, 'Continue'), isTrue);
      await h.choose(t, 'actions');
      expect(h.flow.step, InstallerStep.options);
    });

    testWidgets('bad names and short passwords are explained', (t) async {
      final h = await toAccount(t);
      await h.choose(t, 'user');
      await h.type(t, 'root');
      expect(find.textContaining('is reserved'), findsOneWidget);
      await h.choose(t, 'user');
      await h.type(t, 'Mixed Case');
      expect(find.textContaining('lowercase letters'), findsOneWidget);
      await h.choose(t, 'user');
      await h.type(t, 'james');
      await h.choose(t, 'pw');
      await h.type(t, 'short');
      expect(find.textContaining('at least 8 characters'), findsOneWidget);
      expect(buttonEnabled(t, 'Continue'), isFalse);
    });

    testWidgets('View cancels an edit, the keyboard edits the existing text', (
      t,
    ) async {
      final h = await toAccount(t);
      await h.choose(t, 'user');
      await h.console(t).keyboard!.type('abc');
      await h.press(t, NavAction.view);
      expect(h.console(t).typing, isFalse);
      expect(h.flow.username, '');
      // Editing starts from what is there; Backspace takes characters off.
      h.flow.setUsername('james');
      await t.pumpAndSettle();
      await h.choose(t, 'user');
      expect(find.byKey(const ValueKey('text-field')), findsOneWidget);
      expect(
        t
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('text-field')),
                matching: find.byType(Text),
              ),
            )
            .data,
        'james',
      );
    });
  });

  group('options', () {
    Future<InstallerHarness> toOptions(WidgetTester t) async {
      final h = InstallerHarness();
      await h.start(t);
      h.flow.go(InstallerStep.options);
      await t.pumpAndSettle();
      return h;
    }

    testWidgets(
      'SSH is off by default, with its explanation; the toggle works',
      (t) async {
        final h = await toOptions(t);
        expect(h.flow.ssh, isFalse);
        expect(find.text('Enable SSH'), findsOneWidget);
        expect(find.text('Off'), findsOneWidget);
        expect(
          find.textContaining(
            'Lets other computers on your network log in as the admin',
          ),
          findsOneWidget,
        );
        await h.choose(t, 'ssh');
        expect(h.flow.ssh, isTrue);
        expect(find.text('On'), findsOneWidget);
        await h.choose(t, 'ssh');
        expect(h.flow.ssh, isFalse);
      },
    );

    testWidgets('host name defaults to hinteros; the channel toggles', (
      t,
    ) async {
      final h = await toOptions(t);
      expect(h.flow.hostname, 'hinteros');
      expect(find.text('hinteros'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      await h.choose(t, 'channel');
      expect(find.text('Beta'), findsOneWidget);
      await h.choose(t, 'host');
      await h.type(t, 'Bad Name');
      expect(
        find.textContaining('lowercase letters, digits and hyphens'),
        findsWidgets,
      );
      expect(buttonEnabled(t, 'Continue'), isFalse);
      await h.choose(t, 'host');
      await h.type(t, 'tv-box');
      expect(buttonEnabled(t, 'Continue'), isTrue);
    });
  });

  group('apps', () {
    testWidgets('offline: online-only apps are disabled and say why', (
      t,
    ) async {
      final h = InstallerHarness();
      await h.start(t);
      h.flow.go(InstallerStep.apps);
      await t.pumpAndSettle();
      expect(h.flow.apps!.selected, {'youtube', 'firefox'});
      expect(
        find.text('Needs internet'),
        findsNWidgets(3),
        reason: 'Steam, Plex, Moonlight',
      );
      final steam = h.flow.apps!.apps.indexWhere((a) => a.id == 'steam');
      await h.choose(t, 'a$steam');
      expect(h.flow.apps!.isSelected('steam'), isFalse);
      expect(find.text('Read and accept'), findsNothing);
      // The ISO's apps still work.
      final jf = h.flow.apps!.apps.indexWhere(
        (a) => a.id == 'jellyfin-desktop',
      );
      await h.choose(t, 'a$jf');
      expect(h.flow.apps!.isSelected('jellyfin-desktop'), isTrue);
    });

    testWidgets('online: Steam needs its terms accepted before Continue', (
      t,
    ) async {
      final h = InstallerHarness(backend: FakeInstallerBackend(state: online));
      await h.start(t);
      h.flow.go(InstallerStep.apps);
      await t.pumpAndSettle();
      expect(find.text('Needs internet'), findsNothing);
      final steam = h.flow.apps!.apps.indexWhere((a) => a.id == 'steam');
      await h.choose(t, 'a$steam');
      expect(h.flow.apps!.isSelected('steam'), isTrue);
      expect(buttonEnabled(t, 'Continue'), isFalse);
      await h.choose(t, 'terms0');
      expect(find.text('Terms for Steam'), findsOneWidget);
      for (var i = 0; i < 60 && !buttonEnabled(t, 'Accept and install'); i++) {
        await h.press(t, NavAction.pageRight);
      }
      await h.press(t, NavAction.down);
      await h.press(t, NavAction.right);
      await h.accept(t);
      expect(h.flow.apps!.termsComplete, isTrue);
      expect(buttonEnabled(t, 'Continue'), isTrue);
    });

    testWidgets('going offline drops apps that were ticked while online', (
      t,
    ) async {
      final h = InstallerHarness(backend: FakeInstallerBackend(state: online));
      await h.start(t);
      await h.flow.loadCatalog();
      h.flow.apps!.toggle('plex-htpc');
      expect(h.flow.apps!.isSelected('plex-htpc'), isTrue);
      h.backend.state = const NetworkState();
      await h.flow.refreshNetwork();
      expect(h.flow.apps!.selected, {'youtube', 'firefox'});
    });
  });

  group('the plan', () {
    /// Fills in everything, as a person would.
    Future<InstallerHarness> toSummary(
      WidgetTester t, {
      FakeInstallerBackend? backend,
      void Function(InstallerFlow f)? tweak,
    }) async {
      final h = InstallerHarness(backend: backend);
      await h.pump(t);
      await h.flow.refreshNetwork();
      await h.flow.loadCatalog();
      await h.flow.loadDisks();
      h.flow.chooseDisk(h.flow.disks!.first);
      h.flow.setUsername('james');
      h.flow.setPassword('change-me-now');
      h.flow.setRepeat('change-me-now');
      tweak?.call(h.flow);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('offline default: exactly the backend format', (t) async {
      final h = await toSummary(t);
      expect(find.textContaining('Erase Example NVMe'), findsOneWidget);
      expect(h.flow.buildPlan().toJson(), {
        'disk': '/dev/nvme0n1',
        'diskSeq': 1,
        'hostname': 'hinteros',
        'admin': {'user': 'james', 'password': 'change-me-now'},
        'ssh': {'enable': false},
        'channel': 'stable',
        'base': 'unstable',
        'network': 'offline',
        'apps': ['firefox', 'youtube'],
        'acceptedTerms': <String, String>{},
      });
    });

    testWidgets('online with Steam, SSH, beta and a joined Wi-Fi network', (
      t,
    ) async {
      final backend = FakeInstallerBackend(
        state: const NetworkState(wifiAvailable: true),
        wifiPasswords: {'Living Room': 'correct horse'},
      );
      final h = await toSummary(
        t,
        backend: backend,
        tweak: (f) {
          f.toggleSsh();
          f.toggleChannel();
          f.setHostname('tv-box');
        },
      );
      await h.flow.joinWifi(
        (await backend.scanWifi()).first,
        psk: 'correct horse',
      );
      final steam = h.flow.apps!.apps.firstWhere((a) => a.id == 'steam');
      h.flow.apps!.toggle('steam');
      h.flow.apps!.accept(steam);
      expect(h.flow.buildPlan().toJson(), {
        'disk': '/dev/nvme0n1',
        'diskSeq': 1,
        'hostname': 'tv-box',
        'admin': {'user': 'james', 'password': 'change-me-now'},
        'ssh': {'enable': true},
        'channel': 'beta',
        'base': 'unstable',
        'network': 'online',
        'apps': ['firefox', 'steam', 'youtube'],
        'acceptedTerms': {'steam': '2026-09-10'},
        'wifi': {'ssid': 'Living Room', 'psk': 'correct horse'},
      });
    });

    testWidgets('on Wi-Fi before the installer started: it is kept too', (
      t,
    ) async {
      final h = await toSummary(
        t,
        backend: FakeInstallerBackend(
          state: const NetworkState(
            wifiAvailable: true,
            wifiSsid: 'Living Room',
            online: true,
          ),
        ),
      );
      expect(h.flow.joinedSsid, isNull);
      // No password: the backend copies the saved connection.
      expect(h.flow.buildPlan().toJson()['wifi'], {'ssid': 'Living Room'});
      expect(find.text('Wi-Fi: Living Room'), findsOneWidget);
    });

    testWidgets('wired and only apps from the ISO: network auto', (t) async {
      final h = await toSummary(
        t,
        backend: FakeInstallerBackend(state: online),
      );
      final j = h.flow.buildPlan().toJson();
      expect(j['network'], 'auto');
      expect(j.containsKey('wifi'), isFalse);
    });
  });

  group('install', () {
    Future<InstallerHarness> toSummary(
      WidgetTester t, {
      FakeInstallerBackend? backend,
    }) async {
      final h = InstallerHarness(backend: backend);
      await h.pump(t);
      await h.flow.refreshNetwork();
      await h.flow.loadCatalog();
      await h.flow.loadDisks();
      h.flow.chooseDisk(h.flow.disks!.first);
      h.flow.setUsername('james');
      h.flow.setPassword('change-me-now');
      h.flow.setRepeat('change-me-now');
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('the summary shows the disk that is erased', (t) async {
      final h = await toSummary(t);
      expect(find.text('Erase Example NVMe 512GB, 512 GB'), findsOneWidget);
      expect(
        find.text('Everything on this disk is deleted. You cannot undo this.'),
        findsOneWidget,
      );
      expect(
        find.text('Hold A on Erase and install for 5 seconds.'),
        findsOneWidget,
      );
      expect(h.focus, 'content/actions:0', reason: 'Back has the focus');
    });

    testWidgets('a short hold does not erase', (t) async {
      final backend = FakeInstallerBackend();
      final h = await toSummary(t, backend: backend);
      await h.moveTo(t, 'actions', 1);
      // A press and release, then a hold that stops at 4 s.
      await h.holdAccept(t, Duration.zero);
      await h.holdAccept(t, const Duration(seconds: 4));
      await t.pump(const Duration(seconds: 10));
      expect(h.flow.step, InstallerStep.summary);
      expect(h.flow.phase, InstallPhase.idle);
      expect(backend.calls, isNot(contains('validate')));
      expect(backend.calls, isNot(contains('install')));
    });

    testWidgets('a 5 s hold erases and installs', (t) async {
      final backend = FakeInstallerBackend();
      final h = await toSummary(t, backend: backend);
      await h.moveTo(t, 'actions', 1);
      await h.holdAccept(t, const Duration(milliseconds: 4900));
      expect(h.flow.step, InstallerStep.summary, reason: 'let go at 4.9 s');
      await h.holdAccept(t, const Duration(milliseconds: 5100));
      expect(backend.calls, containsAllInOrder(['validate', 'install']));
      expect(h.flow.step, InstallerStep.done);
    });

    testWidgets('Enter held on a keyboard erases too', (t) async {
      final backend = FakeInstallerBackend();
      final h = await toSummary(t, backend: backend);
      await h.moveTo(t, 'actions', 1);
      await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await pumpFor(t, const Duration(seconds: 2));
      await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.summary);
      await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await pumpFor(t, const Duration(milliseconds: 5100));
      await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(h.flow.step, InstallerStep.done);
    });

    testWidgets('B and Back go back, nothing erased', (t) async {
      final backend = FakeInstallerBackend();
      final h = await toSummary(t, backend: backend);
      await h.moveTo(t, 'actions', 1);
      await h.back(t);
      expect(h.flow.step, InstallerStep.disk);
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      await h.choose(t, 'actions'); // Back
      expect(h.flow.step, InstallerStep.disk);
      expect(backend.calls, isNot(contains('validate')));
    });

    testWidgets('a whole install: validate, install, Done, restart', (t) async {
      final backend = FakeInstallerBackend();
      final h = await toSummary(t, backend: backend);
      expect(find.text('Erase and install'), findsOneWidget);
      expect(
        h.focus,
        'content/actions:0',
        reason: 'Back has the focus, not Install',
      );
      await h.eraseAndInstall(t);

      expect(backend.calls.where((c) => c == 'validate' || c == 'install'), [
        'validate',
        'install',
      ]);
      // Both calls got the same plan, on stdin.
      expect(backend.plans.length, 2);
      expect(backend.plans[0], backend.plans[1]);
      expect(backend.plans[1]['admin'], {
        'user': 'james',
        'password': 'change-me-now',
      });
      expect(h.flow.step, InstallerStep.done);
      expect(
        find.text('HinterOS 0.7.0 stable (1a2b3c4) is installed'),
        findsOneWidget,
      );
      expect(find.textContaining('Remove installation media'), findsOneWidget);
      expect(
        find.textContaining('general drivers'),
        findsOneWidget,
        reason: 'the warning',
      );
      expect(h.flow.password, isEmpty, reason: 'wiped after the install');

      expect(backend.rebooted, isFalse);
      await h.accept(t); // Restart now
      expect(backend.rebooted, isTrue);
      expect(find.text('Restarting...'), findsOneWidget);
    });

    testWidgets('the restart fails: says so, Restart now again', (t) async {
      final backend = FakeInstallerBackend()..rebootFails = true;
      final h = await toSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.step, InstallerStep.done);
      await h.accept(t); // Restart now
      expect(find.text('Restarting...'), findsNothing);
      expect(find.text('Cannot restart. Try again.'), findsOneWidget);
      backend.rebootFails = false;
      await h.accept(t);
      expect(backend.calls.where((c) => c == 'reboot').length, 2);
      expect(find.text('Restarting...'), findsOneWidget);
    });

    testWidgets('progress: stage, percent, warnings, no Back while it runs', (
      t,
    ) async {
      final backend = FakeInstallerBackend(
        delay: const Duration(milliseconds: 100),
      );
      final h = await toSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.validating);
      expect(find.text('Verifying install configuration'), findsOneWidget);

      // Part-way through the install: the warning and a percentage.
      for (var i = 0; i < 80 && h.flow.percent < 57; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(h.flow.phase, InstallPhase.installing);
      expect(find.text('Installing HinterOS'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('percent'))).data,
        '${h.flow.stepPercent}%',
      );
      expect(h.flow.progressStage, 'build');
      expect(
        find.textContaining('Step 6 of 9 · Building HinterOS'),
        findsOneWidget,
      );
      expect(find.text('Copying packages'), findsOneWidget);
      expect(find.text('Installing boot loader'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('build-line'))).data,
        startsWith('Building hinteros-launcher (3 of 12): 88%. Time elapsed: '),
      );
      expect(find.byKey(const ValueKey('spinner')), findsOneWidget);
      expect(find.textContaining('general drivers'), findsOneWidget);
      await h.back(t);
      expect(
        h.flow.step,
        InstallerStep.install,
        reason: 'Back is off while installing',
      );
      for (var i = 0; i < 80 && h.flow.running; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pumpAndSettle();
      expect(h.flow.phase, InstallPhase.succeeded);
    });

    testWidgets('exit 2: refused, nothing touched; try again', (t) async {
      final backend = FakeInstallerBackend()
        ..validateScript = FakeScript.refused(
          'disk-in-use',
          '/dev/nvme0n1 is in use (mounted at: /iso)',
        );
      final h = await toSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.refused);
      expect(h.flow.outcome!.exitCode, 2);
      expect(find.text('The install did not start'), findsOneWidget);
      expect(find.text('Nothing was changed on your disk.'), findsOneWidget);
      expect(find.textContaining('Choose a different disk'), findsOneWidget);
      expect(find.textContaining('(disk-in-use)'), findsOneWidget);
      expect(
        find.textContaining('/var/log/hinteros-install.log'),
        findsOneWidget,
      );
      expect(
        backend.calls.contains('install'),
        isFalse,
        reason: 'never got to install',
      );
      expect(h.focus, 'content/actions:0');

      // Try again: an erase is held again on the summary; now it passes.
      backend.validateScript = null;
      await h.accept(t);
      expect(h.flow.step, InstallerStep.summary);
      expect(h.flow.phase, InstallPhase.idle);
      expect(backend.calls.where((c) => c == 'validate').length, 1);
      await h.eraseAndInstall(t);
      expect(h.flow.step, InstallerStep.done);
      expect(backend.calls.where((c) => c == 'validate').length, 2);
    });

    testWidgets('the disk changed after the plan was checked: choose it '
        'again', (t) async {
      final backend = FakeInstallerBackend();
      // Unplugged and plugged in again between the check and the install:
      // the same path, a new disk sequence number.
      backend.beforeInstall = () {
        backend.replug('/dev/nvme0n1');
        backend.beforeInstall = null;
      };
      final h = await toSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.refused);
      expect(h.flow.outcome!.error!.code, 'disk-changed');
      expect(backend.plans.last['diskSeq'], 1);
      expect(find.text('The install did not start'), findsOneWidget);
      expect(find.text('Nothing was changed on your disk.'), findsOneWidget);
      expect(
        find.text('The disk changed. Select the disk again.'),
        findsOneWidget,
      );
      // The same plan cannot work: no "Try again".
      expect(find.text('Try again'), findsNothing);
      expect(h.focus, 'content/actions:0');

      await h.accept(t); // Select the disk
      expect(h.flow.step, InstallerStep.disk);
      expect(h.flow.phase, InstallPhase.idle);
      expect(h.flow.disk, isNull);
      expect(buttonEnabled(t, 'Continue'), isFalse);
      expect(h.flow.disks!.first.diskSeq, 6, reason: 'the list is read again');

      // Chosen again, the plan carries the new number and installs.
      await h.choose(t, 'd0');
      h.flow.go(InstallerStep.summary);
      await t.pumpAndSettle();
      await h.eraseAndInstall(t);
      expect(h.flow.step, InstallerStep.done);
      expect(backend.plans.last['diskSeq'], 6);
    });

    testWidgets('exit 1: failed part-way; Try again goes to the summary', (
      t,
    ) async {
      final backend = FakeInstallerBackend()
        ..installScript = FakeScript.failed();
      final h = await toSummary(t, backend: backend);
      await h.eraseAndInstall(t);
      expect(h.flow.phase, InstallPhase.failed);
      expect(h.flow.outcome!.exitCode, 1);
      expect(find.text('The install did not finish'), findsOneWidget);
      expect(find.textContaining('The install stopped.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('spinner')),
        findsNothing,
        reason: 'nothing runs',
      );
      expect(
        find.textContaining('Installing the system failed'),
        findsOneWidget,
      );
      expect(find.textContaining('(install-failed)'), findsOneWidget);
      expect(
        find.textContaining('/var/log/hinteros-install.log'),
        findsWidgets,
      );
      expect(backend.calls, containsAllInOrder(['validate', 'install']));

      expect(find.text('Change my choices'), findsNothing);
      await h.accept(t); // Try again
      expect(h.flow.step, InstallerStep.summary);
      expect(
        backend.calls.where((c) => c == 'install').length,
        1,
        reason: 'nothing runs before the hold',
      );
      expect(h.flow.phase, InstallPhase.idle);
      expect(h.flow.password, 'change-me-now', reason: 'kept for another try');
    });

    testWidgets('the password is never printed or shown', (t) async {
      final lines = <String>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => lines.add(m ?? '');
      final InstallerHarness h;
      try {
        h = await toSummary(t);
        await h.eraseAndInstall(t);
      } finally {
        debugPrint = old;
      }
      expect(lines.join(), isNot(contains('change-me-now')));
      expect(find.textContaining('change-me-now'), findsNothing);
    });

    testWidgets('typing with the controller on the in-app keyboard', (t) async {
      final h = InstallerHarness();
      await h.start(t);
      h.flow.go(InstallerStep.account);
      await t.pumpAndSettle();
      await h.choose(t, 'user');
      expect(find.text('Typed text appears here'), findsOneWidget);
      // The keyboard starts on Q; the controller moves around it.
      expect(h.focus, 'osk/r1:0');
      await h.press(t, NavAction.down); // A
      expect(h.focus, 'osk/r2:0');
      await h.accept(t);
      await h.press(t, NavAction.right); // S
      await h.accept(t);
      await h.press(t, NavAction.right); // D
      await h.accept(t);
      expect(h.console(t).keyboard!.text.value, 'asd');
      await h.press(t, NavAction.secondary); // X is Backspace
      expect(h.console(t).keyboard!.text.value, 'as');
      // Down to the bottom row; Space is a key there.
      await h.press(t, NavAction.down);
      await h.press(t, NavAction.down);
      expect(h.focus, startsWith('osk/bottom:'));
      for (var i = 0; i < 12 && h.focus != 'osk/bottom:2'; i++) {
        await h.press(t, NavAction.right);
      }
      await h.accept(t);
      expect(h.console(t).keyboard!.text.value, 'as ');
      // Along to Done.
      for (var i = 0; i < 12 && h.focus != 'osk/bottom:5'; i++) {
        await h.press(t, NavAction.right);
      }
      await h.accept(t);
      expect(h.console(t).typing, isFalse);
      expect(h.flow.username, 'as ');
    });

    testWidgets('B closes the in-app keyboard like View: the edit is dropped', (
      t,
    ) async {
      final h = InstallerHarness();
      await h.start(t);
      h.flow.go(InstallerStep.account);
      await t.pumpAndSettle();
      await h.choose(t, 'user');
      await h.accept(t); // q
      expect(h.console(t).keyboard!.text.value, 'q');
      await h.press(t, NavAction.back);
      await t.pumpAndSettle();
      expect(h.console(t).typing, isFalse);
      expect(h.flow.username, isNot('q'));
      expect(h.flow.step, InstallerStep.account);
    });
  });
}
