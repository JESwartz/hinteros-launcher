import 'dart:async';

import 'package:flutter/material.dart';

import '../../settings/launcher_settings.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../../ui/widgets.dart';
import '../gamepad.dart';
import 'host.dart';
import '../../ui/pages.dart' show FullPage;
import 'steps.dart' show scrolling;

/// The first-boot wizard (`--first-boot`): what a freshly installed box, or
/// one you pre-installed yourself, asks before the launcher starts. It runs
/// on the daemon's runtime settings (the same repositories as Settings).
///
/// A SKELETON: network, controller pairing and a display check work;
/// everything else the M9 roadmap lists is a TODO below.
///
/// TODO(M9): first profile (name, avatar) via the profiles API.
/// TODO(M9): update channel (`channel.set`), as in the installer's options.
/// TODO(M9): the app step for boxes without the installer's selection: the
/// same `AppSelectionView`, then `apps.install` for each pick (needs M8).
/// TODO(M9): display mode picker with the keep/revert countdown
/// (`DisplayAudioRepository.setDisplayMode`, `keepDisplayMode`).
/// TODO(M9): skip the steps that are already done (a box that has a profile
/// or a paired controller), and the session handover when finished (the
/// daemon starts the launcher instead of this wizard).
/// TODO(M9): use the daemon's keyboard (`osk.*`) instead of the in-app one:
/// the daemon is running here.
class FirstBootApp extends StatelessWidget {
  const FirstBootApp({
    super.key,
    required this.services,
    this.pad,
    this.settings = const LauncherSettings(),
    this.onFinished,
  });

  final SystemServices services;
  final Stream<PadEvent>? pad;
  final LauncherSettings settings;

  /// The wizard is done (the real thing exits so the session starts the
  /// launcher).
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) => ConsoleApp(
    settings: settings,
    title: 'HinterOS setup',
    home: ConsoleHost(
      pad: pad,
      builder: (context, console) => FirstBootScreen(
        services: services,
        console: console,
        onFinished: onFinished,
      ),
    ),
  );
}

enum FirstBootStep {
  welcome('Welcome'),
  network('Internet'),
  controllers('Controllers'),
  display('Display'),
  done('All set');

  const FirstBootStep(this.title);
  final String title;
}

class FirstBootScreen extends StatefulWidget {
  const FirstBootScreen({
    super.key,
    required this.services,
    required this.console,
    this.onFinished,
  });

  final SystemServices services;
  final ConsoleController console;
  final VoidCallback? onFinished;

  @override
  State<FirstBootScreen> createState() => _FirstBootScreenState();
}

class _FirstBootScreenState extends State<FirstBootScreen> {
  FirstBootStep _step = FirstBootStep.welcome;
  NetworkStatus? _net;
  List<WifiNetwork> _wifi = const [];
  String? _message;
  List<BtDevice> _devices = const [];
  StreamSubscription<List<BtDevice>>? _btSub;
  DisplayInfo? _display;

  SystemServices get _s => widget.services;
  ConsoleController get _c => widget.console;

  @override
  void initState() {
    super.initState();
    _c.onBack = () {
      if (_step == FirstBootStep.welcome) return false;
      _go(FirstBootStep.values[_step.index - 1]);
      return true;
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.refocus();
    });
  }

  @override
  void dispose() {
    _btSub?.cancel();
    super.dispose();
  }

  Future<T?> _try<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on SystemException catch (e) {
      if (mounted) setState(() => _message = e.message);
      return null;
    }
  }

  void _go(FirstBootStep s) {
    setState(() {
      _step = s;
      _message = null;
    });
    _c.newScreen();
    switch (s) {
      case FirstBootStep.network:
        unawaited(_loadNetwork());
      case FirstBootStep.controllers:
        unawaited(_loadControllers());
      case FirstBootStep.display:
        unawaited(_loadDisplay());
      default:
        break;
    }
  }

  Future<void> _loadNetwork() async {
    final n = await _try(_s.network.status);
    final w = await _try(_s.network.scan);
    if (!mounted) return;
    setState(() {
      _net = n;
      _wifi = w ?? const [];
    });
  }

  Future<void> _joinWifi(WifiNetwork ap) async {
    String? pw;
    if (ap.secured) {
      pw = await _c.editText(title: 'Password for ${ap.ssid}', secret: true);
      if (pw == null) return;
    }
    await _try(() => _s.network.connect(ap.ssid, password: pw));
    await _loadNetwork();
  }

  Future<void> _loadControllers() async {
    await _try(_s.bluetooth.load);
    _btSub ??= _s.bluetooth.devices.listen((d) {
      if (mounted) setState(() => _devices = d);
    });
    if (mounted) setState(() => _devices = _s.bluetooth.current);
    await _try(_s.bluetooth.startScan);
  }

  Future<void> _loadDisplay() async {
    final d = await _try(_s.displayAudio.displayModes);
    if (mounted) setState(() => _display = d);
  }

  void _next() {
    if (_step == FirstBootStep.done) {
      widget.onFinished?.call();
      return;
    }
    _go(FirstBootStep.values[_step.index + 1]);
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(_c.content);
    if (_message != null) p.add(StatusLine(_message!, error: true));
    switch (_step) {
      case FirstBootStep.welcome:
        p.add(
          Text(
            'Let us set up this computer. It takes a minute. Move with '
            'the D-pad, A chooses, B goes back.',
            style: t.title,
          ),
        );
      case FirstBootStep.network:
        final n = _net;
        p.add(
          StatusLine(
            n == null
                ? 'Looking at the network...'
                : (n.online ? 'This computer is online.' : 'Not online yet.'),
            ok: n?.online ?? false,
          ),
        );
        for (var i = 0; i < _wifi.length; i++) {
          final ap = _wifi[i];
          p.item(
            'w$i',
            onSelect: () => _joinWifi(ap),
            builder: (f) => SettingRow(
              title: ap.ssid,
              focused: f,
              leading: SignalBars(bars: ap.bars),
              trailing: ap.secured ? const LockMark() : null,
            ),
          );
        }
      case FirstBootStep.controllers:
        p.add(
          Text(
            'Put your controller in pairing mode. It appears below and '
            'pairs when you choose it.',
            style: t.bodyDim,
          ),
        );
        for (var i = 0; i < _devices.length; i++) {
          final d = _devices[i];
          p.item(
            'b$i',
            onSelect: d.paired || d.connected
                ? null
                : () => _try(() => _s.bluetooth.pair(d.id)),
            builder: (f) => SettingRow(
              title: d.name,
              focused: f,
              trailing: Text(
                d.connected
                    ? 'Connected'
                    : d.paired
                    ? 'Paired'
                    : 'Choose to pair',
                style: t.caption,
              ),
            ),
          );
        }
      case FirstBootStep.display:
        final m = _display?.modes.where((m) => m.current).firstOrNull;
        p.add(
          Text(
            m == null
                ? 'Checking the display...'
                : 'The picture is ${m.width} by ${m.height} at '
                      '${m.refreshHz.round()} Hz. Can you read this '
                      'comfortably?',
            style: t.title,
          ),
        );
        p.add(
          Text(
            'If not, you can change it later in Settings.',
            style: t.bodyDim,
          ),
        );
      case FirstBootStep.done:
        p.add(Text('You are ready to use HinterOS.', style: t.title));
    }
    p.buttons('actions', [
      btn(
        switch (_step) {
          FirstBootStep.welcome => 'Start',
          FirstBootStep.done => 'Finish',
          FirstBootStep.display => 'Looks good',
          _ => 'Continue',
        },
        _next,
        primary: true,
      ),
    ], gap: HinterTokens.s4);
    return FullPage(
      title: _step.title,
      subtitle:
          'Setup, step ${_step.index + 1} of ${FirstBootStep.values.length}',
      child: scrolling(p.build()),
    );
  }
}
