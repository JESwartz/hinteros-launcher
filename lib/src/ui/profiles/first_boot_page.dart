/// First-boot mode inside the session (profiles.md "First-boot mode"): when
/// `profile.current` says `setup_required` (no admin profile exists; this
/// session runs on the spare account), the launcher opens this wizard over
/// Home: controllers, network, display, then "Create your profile" (the
/// admin profile, `profiles.setup_admin`: no rebuild, no network), and ends
/// on Home in the new profile.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';
import 'profile_form.dart';
import 'session_profile.dart' show sessionEditText;

enum FirstBootStep {
  welcome('Welcome'),
  controllers('Controllers'),
  network('Internet'),
  display('Display'),
  profile('Create your profile'),
  done('All set');

  const FirstBootStep(this.title);
  final String title;
}

class FirstBootPage extends StatefulWidget {
  const FirstBootPage({
    super.key,
    required this.modal,
    required this.services,
    this.onCreated,
  });

  final ModalHandle<void> modal;
  final SystemServices services;

  /// The admin profile exists now.
  final Future<void> Function()? onCreated;

  @override
  State<FirstBootPage> createState() => _FirstBootPageState();
}

class _FirstBootPageState extends State<FirstBootPage> {
  FirstBootStep _step = FirstBootStep.welcome;
  String? _message;
  NetworkStatus? _net;
  List<WifiNetwork> _wifi = const [];
  List<BtDevice> _devices = const [];
  StreamSubscription<List<BtDevice>>? _bt;
  DisplayInfo? _display;
  String? _createdName;

  SystemServices get _s => widget.services;
  NavRegion get _region => widget.modal.region;

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () => false;
    _region.onBack = () {
      if (_step == FirstBootStep.welcome ||
          _step == FirstBootStep.done ||
          _createdName != null) {
        return true;
      }
      _go(FirstBootStep.values[_step.index - 1]);
      return true;
    };
  }

  @override
  void dispose() {
    _bt?.cancel();
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
    _region.reset();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_region.focusCurrent());
    });
  }

  Future<void> _loadNetwork() async {
    final n = await _try(_s.network.status);
    final w = await _try(_s.network.list);
    if (!mounted) return;
    setState(() {
      _net = n;
      _wifi = w ?? const [];
    });
  }

  Future<void> _join(WifiNetwork ap) async {
    if (ap.secured) {
      await showTextEntry(
        context,
        title: 'Password for ${ap.ssid}',
        secret: true,
        submitLabel: 'Join',
        submit: (pw) async {
          try {
            await _s.network.connect(ap.ssid, password: pw);
            return null;
          } on SystemException catch (e) {
            return e.message;
          }
        },
      );
    } else {
      await _try(() => _s.network.connect(ap.ssid));
    }
    await _loadNetwork();
  }

  Future<void> _loadControllers() async {
    await _try(_s.bluetooth.load);
    _bt ??= _s.bluetooth.devices.listen((d) {
      if (mounted) setState(() => _devices = d);
    });
    if (mounted) setState(() => _devices = _s.bluetooth.current);
    await _try(_s.bluetooth.startScan);
  }

  Future<void> _loadDisplay() async {
    final d = await _try(_s.displayAudio.displayModes);
    if (mounted) setState(() => _display = d);
  }

  Future<void> _createProfile() async {
    final form = await showProfileForm(
      context,
      admin: true,
      editText: sessionEditText(context),
    );
    if (form == null || !mounted) return;
    try {
      await _s.profiles.setupAdmin(
        name: form.name,
        color: form.color,
        pin: form.pin,
        locked: form.locked,
      );
    } on SystemException catch (e) {
      if (mounted) setState(() => _message = e.message);
      return;
    }
    await widget.onCreated?.call();
    if (!mounted) return;
    _createdName = form.name;
    _go(FirstBootStep.done);
  }

  void _next() {
    switch (_step) {
      case FirstBootStep.profile:
        unawaited(_createProfile());
      case FirstBootStep.done:
        widget.modal.close();
      default:
        _go(FirstBootStep.values[_step.index + 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(_region);
    if (_message != null) p.add(StatusLine(_message!, error: true));
    switch (_step) {
      case FirstBootStep.welcome:
        p.add(
          Text(
            "Let's set up this box. It takes a minute. Move with the D-pad, "
            'A chooses, B goes back.',
            style: t.title,
          ),
        );
      case FirstBootStep.controllers:
        p.add(
          Text(
            'Put a controller in pairing mode. It appears below and pairs '
            'when you choose it. You can also do this later in Settings.',
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
      case FirstBootStep.network:
        final n = _net;
        p.add(
          StatusLine(
            n == null
                ? 'Looking at the network...'
                : (n.online
                      ? 'This box is online.'
                      : 'Not online. Everything here works offline too; '
                            'updates and the Store need the internet.'),
            ok: n?.online ?? false,
          ),
        );
        for (var i = 0; i < _wifi.length; i++) {
          final ap = _wifi[i];
          p.item(
            'w$i',
            onSelect: () => unawaited(_join(ap)),
            builder: (f) => SettingRow(
              title: ap.ssid,
              focused: f,
              leading: SignalBars(bars: ap.bars),
              trailing: ap.secured ? const LockMark() : null,
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
      case FirstBootStep.profile:
        p.add(
          Text(
            'Now your profile: a name, a colour and a PIN. This is the admin '
            "profile. Its PIN is needed to manage other profiles and this "
            'box.',
            style: t.title,
          ),
        );
      case FirstBootStep.done:
        p.add(
          Text(
            'You are ready, ${_createdName ?? ''}. Add more profiles in '
            'Settings, Profiles.',
            style: t.title,
          ),
        );
    }
    p.buttons('actions', [
      btn(
        switch (_step) {
          FirstBootStep.welcome => 'Start',
          FirstBootStep.display => 'Looks good',
          FirstBootStep.profile => 'Create my profile',
          FirstBootStep.done => 'Go to Home',
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
      child: SingleChildScrollView(child: p.build()),
    );
  }
}
