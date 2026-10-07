import 'package:flutter/material.dart';

import '../../settings/launcher_settings.dart';
import '../flow.dart';
import '../gamepad.dart';
import 'host.dart';
import 'progress_steps.dart';
import 'steps.dart';

/// The installer (`--installer`): controller-only screens from Welcome to
/// the restart, driven by an [InstallerFlow] over an `InstallerBackend`.
class InstallerApp extends StatelessWidget {
  const InstallerApp({
    super.key,
    required this.flow,
    this.pad,
    this.settings = const LauncherSettings(),
  });

  final InstallerFlow flow;

  /// Controller presses; null: keyboard only (desktop, tests).
  final Stream<PadEvent>? pad;
  final LauncherSettings settings;

  @override
  Widget build(BuildContext context) => ConsoleApp(
    settings: settings,
    title: 'HinterOS installer',
    home: ConsoleHost(
      pad: pad,
      builder: (context, console) =>
          InstallerScreen(flow: flow, console: console),
    ),
  );
}

/// Shows the screen of [InstallerFlow.step] and does what entering one needs
/// (look at the network, list the disks, ...).
class InstallerScreen extends StatefulWidget {
  const InstallerScreen({super.key, required this.flow, required this.console});

  final InstallerFlow flow;
  final ConsoleController console;

  @override
  State<InstallerScreen> createState() => _InstallerScreenState();
}

class _InstallerScreenState extends State<InstallerScreen> {
  late InstallerStep _step = widget.flow.step;
  late InstallPhase _phase = widget.flow.phase;

  InstallerFlow get _flow => widget.flow;

  @override
  void initState() {
    super.initState();
    widget.console.onBack = () {
      if (!_flow.canGoBack) return false;
      _flow.back();
      return true;
    };
    _flow.addListener(_onFlow);
    _entered(_step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.console.refocus();
    });
    // Needed by the offline rules of the app step.
    _flow.refreshNetwork().then((_) => _flow.loadCatalog());
  }

  @override
  void dispose() {
    _flow.removeListener(_onFlow);
    super.dispose();
  }

  void _entered(InstallerStep s) {
    switch (s) {
      case InstallerStep.network:
        _flow.refreshNetwork().then((_) => _flow.scanWifi());
      case InstallerStep.disk:
        _flow.loadDisks();
      case InstallerStep.apps:
        _flow.loadCatalog();
      default:
        break;
    }
  }

  void _onFlow() {
    if (!mounted) return;
    final stepChanged = _flow.step != _step;
    final phaseChanged = _flow.phase != _phase;
    if (stepChanged) {
      _step = _flow.step;
      widget.console.newScreen();
      _entered(_step);
    } else if (phaseChanged && !_flow.running) {
      // Buttons appeared (or the retry started): focus follows.
      widget.console.refocus();
    }
    _phase = _flow.phase;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final env = StepEnv(_flow, widget.console);
    return KeyedSubtree(
      key: ValueKey(_step),
      child: switch (_step) {
        InstallerStep.welcome => WelcomeStep(env: env),
        InstallerStep.network => NetworkStep(env: env),
        InstallerStep.disk => DiskStep(env: env),
        InstallerStep.account => AccountStep(env: env),
        InstallerStep.options => OptionsStep(env: env),
        InstallerStep.apps => AppsStep(env: env),
        InstallerStep.summary => SummaryStep(env: env),
        InstallerStep.install => InstallStepView(env: env),
        InstallerStep.done => DoneStepView(env: env),
      },
    );
  }
}
