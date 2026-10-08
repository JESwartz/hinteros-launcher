/// `hinteros-launcher --greeter`: the profile picker of the greeter session
/// (profiles.md, "The picker"). It talks to the greeter-mode session daemon
/// only; `--mock` uses the in-process fakes (PINs: James 2468, Sam 1357).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'api/api.dart';
import 'installer/gamepad.dart' show PadEvent;
import 'system/daemon_profiles.dart';
import 'system/daemon_system.dart';
import 'system/mock_system.dart';
import 'ui/profiles/greeter_screen.dart';

bool _flag(List<String> args, String flag, String env) =>
    args.contains(flag) || (Platform.environment[env] ?? '').isNotEmpty;

/// Whether the command line asks for the picker.
bool wantsGreeter(List<String> args) =>
    _flag(args, '--greeter', 'HINTEROS_GREETER');

/// Controller input from the daemon's `input_nav`.
Stream<PadEvent> padFromDaemon(DaemonConnection c) {
  unawaited(c.subscribeTo([EventName.inputNav]).catchError((_) {}));
  return c.events
      .where((e) => e is InputNavEvent)
      .cast<InputNavEvent>()
      .map((e) => (e.action, e.phase));
}

Future<void> runGreeter(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final mock = _flag(args, '--mock', 'HINTEROS_MOCK');
  final hideCursor = !_flag(args, '--windowed', 'HINTEROS_WINDOWED');
  if (mock) {
    final s = MockSystemServices(autoRunJobs: true);
    runApp(
      GreeterApp(
        greeter: MockGreeter(s.mockJobs, box: s.mockProfiles.box),
        jobs: s.mockJobs,
        system: s.mockSystem,
        hideCursor: hideCursor,
      ),
    );
    return;
  }
  final conn = DaemonClient(socketPath: defaultSocketPath())..start();
  final jobs = DaemonJobs(conn);
  runApp(
    GreeterApp(
      greeter: DaemonGreeter(conn, jobs),
      jobs: jobs,
      system: DaemonSystem(conn, jobs),
      pad: padFromDaemon(conn),
      hideCursor: hideCursor,
    ),
  );
}
