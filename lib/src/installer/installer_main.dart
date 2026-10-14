import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../system/daemon_system.dart';
import '../system/mock_system.dart';
import '../system/repositories.dart' show SystemServices;
import 'backend.dart';
import 'fake_backend.dart';
import 'flow.dart';
import 'gamepad.dart';
import 'keyboard_fallback.dart';
import 'plan.dart' show InstallChannel;
import 'process_backend.dart';
import 'ui/first_boot.dart';
import 'ui/installer_app.dart';

bool _flag(List<String> args, String flag, String env) =>
    args.contains(flag) || (Platform.environment[env] ?? '').isNotEmpty;

/// Whether the command line asks for the installer or the first-boot wizard.
bool wantsInstaller(List<String> args) =>
    _flag(args, '--installer', 'HINTEROS_INSTALLER');
bool wantsFirstBoot(List<String> args) =>
    _flag(args, '--first-boot', 'HINTEROS_FIRST_BOOT');

/// A scripted backend for `--installer --mock`: `--mock-scenario=NAME` picks
/// what happens (`ok` is the default). Nothing here touches the machine.
///
///  - `ok`: online over Wi-Fi after choosing "Living Room" (password
///    `correct horse`), the install succeeds
///  - `offline`: no network at all
///  - `online`: a cable is connected
///  - `refused`: the backend refuses the plan (exit 2, `disk-in-use`)
///  - `disk-changed`: the chosen disk is replaced after the plan was
///    checked (exit 2, `disk-changed`); chosen again, it installs
///  - `apps-failed`: the system installs, then the first picked app fails
///  - `failed`: the install fails part-way (exit 1, `install-failed`)
///  - `newer`: online over a cable; both channels have a newer HinterOS,
///    which installs (with its download stage)
///  - `newer-failed`: as `newer`, but the newer one fails part-way (exit 1);
///    the installer's own version installs
///  - `newer-fetch-failed`: as `newer`, but the newer one does not download
///  - `check-error`: online, but the check for a newer HinterOS fails (the
///    version step is skipped)
///  - `beta`: an offline beta installer (`--info` says beta: the Options
///    step starts on Beta)
FakeInstallerBackend mockBackend(String scenario) {
  final b = FakeInstallerBackend(
    delay: const Duration(milliseconds: 600),
    wifiPasswords: const {
      'Living Room': 'correct horse',
      'Neighbour 5G': 'correct horse',
    },
    state:
        const {
          'online',
          'newer',
          'newer-failed',
          'newer-fetch-failed',
          'check-error',
        }.contains(scenario)
        ? const NetworkState(
            wiredConnected: true,
            wifiAvailable: true,
            online: true,
          )
        : const NetworkState(wifiAvailable: true),
  );
  b.installScriptFor = (plan) => FakeScript.twoStage(
    plan.apps,
    failing: scenario == 'apps-failed' && plan.apps.isNotEmpty
        ? [plan.apps.first]
        : const [],
  );
  switch (scenario) {
    case 'refused':
      b.validateScript = FakeScript.refused(
        'disk-in-use',
        '/dev/nvme0n1 is in use',
      );
    case 'disk-changed':
      // Once: chosen again, the disk installs.
      b.beforeInstall = () {
        b.replug('/dev/nvme0n1');
        b.beforeInstall = null;
      };
    case 'failed':
      b.installScript = FakeScript.failed();
    case 'newer':
      b.newer = mockNewer();
      b.newerInstallScript = FakeScript.newerOk('0.7.1');
    case 'newer-failed':
      b.newer = mockNewer();
      b.newerInstallScript = FakeScript.failed();
    case 'newer-fetch-failed':
      b.newer = mockNewer();
      b.newerInstallScript = FakeScript.fetchFailed();
    case 'beta':
      b.defaultChannel = InstallChannel.beta;
    case 'check-error':
      b.checkError = const InstallerException(
        'the tip of the stable channel is not signed',
        code: 'unsigned',
      );
  }
  return b;
}

/// Runs the installer (`--installer`) or the first-boot wizard
/// (`--first-boot`). With `--mock` nothing touches this machine.
Future<void> runInstallerMode(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final mock = _flag(args, '--mock', 'HINTEROS_MOCK');
  final windowed = _flag(args, '--windowed', 'HINTEROS_WINDOWED');
  final EvdevPad? pad = mock ? null : (EvdevPad()..start());
  // Keys read from evdev too, but used only while the window has no keyboard
  // focus (see keyboard_fallback.dart).
  final InstallerKeyboard? kb = mock ? null : InstallerKeyboard.start();
  if (wantsFirstBoot(args) && !wantsInstaller(args)) {
    final SystemServices services;
    if (mock) {
      services = MockSystemServices(autoRunJobs: true);
    } else {
      services = daemonSystemServices(
        DaemonClient(socketPath: defaultSocketPath()),
      );
    }
    runApp(
      FirstBootApp(
        services: services,
        pad: pad?.events,
        keyboard: kb?.fallback,
        hideCursor: !windowed,
      ),
    );
    return;
  }
  final scenario = args
      .where((a) => a.startsWith('--mock-scenario='))
      .map((a) => a.substring('--mock-scenario='.length))
      .firstOrNull;
  final InstallerBackend backend = mock
      ? mockBackend(scenario ?? 'ok')
      : ProcessInstallerBackend();
  runApp(
    InstallerApp(
      flow: InstallerFlow(backend),
      pad: pad?.events,
      keyboard: kb?.fallback,
      hideCursor: !windowed,
    ),
  );
}
