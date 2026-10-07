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
///  - `failed`: the install fails part-way (exit 1, `install-failed`)
FakeInstallerBackend mockBackend(String scenario) {
  final b = FakeInstallerBackend(
    delay: const Duration(milliseconds: 600),
    wifiPasswords: const {
      'Living Room': 'correct horse',
      'Neighbour 5G': 'correct horse',
    },
    state: scenario == 'online'
        ? const NetworkState(
            wiredConnected: true,
            wifiAvailable: true,
            online: true,
          )
        : const NetworkState(wifiAvailable: true),
  );
  switch (scenario) {
    case 'refused':
      b.validateScript = FakeScript.refused(
        'disk-in-use',
        '/dev/nvme0n1 is in use',
      );
    case 'failed':
      b.installScript = FakeScript.failed();
  }
  return b;
}

/// Runs the installer (`--installer`) or the first-boot wizard
/// (`--first-boot`). With `--mock` nothing touches this machine.
Future<void> runInstallerMode(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final mock = _flag(args, '--mock', 'HINTEROS_MOCK');
  final EvdevPad? pad = mock ? null : (EvdevPad()..start());
  if (wantsFirstBoot(args) && !wantsInstaller(args)) {
    final SystemServices services;
    if (mock) {
      services = MockSystemServices(autoRunJobs: true);
    } else {
      services = daemonSystemServices(
        DaemonClient(socketPath: defaultSocketPath()),
      );
    }
    runApp(FirstBootApp(services: services, pad: pad?.events));
    return;
  }
  final scenario = args
      .where((a) => a.startsWith('--mock-scenario='))
      .map((a) => a.substring('--mock-scenario='.length))
      .firstOrNull;
  final InstallerBackend backend = mock
      ? mockBackend(scenario ?? 'ok')
      : ProcessInstallerBackend();
  runApp(InstallerApp(flow: InstallerFlow(backend), pad: pad?.events));
}
