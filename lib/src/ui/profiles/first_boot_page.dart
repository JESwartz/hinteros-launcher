/// First-boot mode inside the session (profiles.md "First-boot mode"): when
/// `profile.current` says `setup_required` (no admin profile exists; this
/// session runs on the spare account), the launcher opens this wizard over
/// Home: controllers, network, display, then the profile form for the admin
/// profile (`profiles.setup_admin`: no rebuild, no network), and ends on Home
/// in the new profile.
///
/// Every step between Welcome and All set is a choice: a step with nothing to
/// choose is skipped (a display whose mode can't be set, or that has only one
/// mode), and the profile step is the form itself, not a page about it.
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
import '../system/hardware_sections.dart' show KeepDisplayDialog;
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

  /// The way the wizard is moving, so a step with nothing to choose is
  /// skipped in the same direction.
  bool _forward = true;
  String? _message;
  NetworkStatus? _net;
  List<WifiNetwork> _wifi = const [];
  List<BtDevice> _devices = const [];
  StreamSubscription<List<BtDevice>>? _bt;
  DisplayInfo? _display;
  bool _formOpen = false;
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
      _back();
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

  void _back() {
    if (_step == FirstBootStep.welcome) return;
    _go(FirstBootStep.values[_step.index - 1], forward: false);
  }

  /// Leaves a step that turned out to have nothing to choose.
  void _skip() =>
      _forward ? _go(FirstBootStep.values[_step.index + 1]) : _back();

  void _go(FirstBootStep s, {bool forward = true}) {
    setState(() {
      _step = s;
      _forward = forward;
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
      case FirstBootStep.profile:
        // Straight into the form: B there comes back a step.
        if (forward) unawaited(_createProfile());
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
    if (!mounted || _step != FirstBootStep.display) return;
    // Nothing to choose: a display that can't be set, or has one mode.
    if (d == null || !d.canSet || d.modes.length < 2) {
      _skip();
      return;
    }
    setState(() => _display = d);
  }

  /// `display.set_mode`, then the keep-or-go-back countdown, as in Settings.
  Future<void> _setMode(DisplayMode m) async {
    if (m.current) return;
    final da = _s.displayAudio;
    try {
      await da.setDisplayMode(m);
    } on SystemException catch (e) {
      if (mounted) setState(() => _message = e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _message = null);
    final keep = await ModalScope.of(context)
        .show<bool>((c, modal) => KeepDisplayDialog(modal: modal, mode: m));
    await _try(keep == true ? da.keepDisplayMode : da.revertDisplayMode);
    final d = await _try(da.displayModes);
    if (mounted && d != null) setState(() => _display = d);
  }

  Future<void> _createProfile() async {
    if (_formOpen) return;
    _formOpen = true;
    final ProfileFormResult? form;
    try {
      form = await showProfileForm(
        context,
        admin: true,
        editText: sessionEditText(context),
      );
    } finally {
      _formOpen = false;
    }
    if (!mounted || _step != FirstBootStep.profile) return;
    if (form == null) {
      _back();
      return;
    }
    try {
      await _s.profiles.setupAdmin(
        name: form.name,
        color: form.color,
        pin: form.pin,
        locked: form.locked,
      );
    } on SystemException catch (e) {
      // Stays on this step with the reason and Try again.
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
        p.add(Text('Set up this box. It takes a few minutes.', style: t.title));
        p.add(
          Text(
            'Move with the D-pad, A chooses, B goes back.',
            style: t.bodyDim,
          ),
        );
      case FirstBootStep.controllers:
        p.add(
          Text(
            'Put a controller in pairing mode, then choose it below.',
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
                ? 'Checking the network...'
                : (n.online
                      ? 'Online.'
                      : 'Not online. Updates and the Store need the '
                            'internet.'),
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
        final d = _display;
        p.add(
          Text(
            d == null
                ? 'Checking the display...'
                : 'Choose a resolution if the picture does not fit or is '
                      'not sharp.',
            style: t.bodyDim,
          ),
        );
        final modes = d?.modes ?? const <DisplayMode>[];
        for (var i = 0; i < modes.length; i++) {
          final m = modes[i];
          p.item(
            'm$i',
            onSelect: () => unawaited(_setMode(m)),
            builder: (f) => SettingRow(
              title: m.label,
              focused: f,
              subtitle: [m.name, if (m.preferred) 'recommended'].join(', '),
              trailing: Text(m.current ? 'Current' : '', style: t.bodyDim),
            ),
          );
        }
      case FirstBootStep.profile:
        // The form is open over this; only a failed setup shows here.
        break;
      case FirstBootStep.done:
        p.add(Text('You are ready, ${_createdName ?? ''}.', style: t.title));
    }
    if (_step != FirstBootStep.profile || _message != null) {
      p.buttons('actions', [
        btn(
          switch (_step) {
            FirstBootStep.welcome => 'Start',
            FirstBootStep.profile => 'Try again',
            FirstBootStep.done => 'Go to Home',
            _ => 'Continue',
          },
          _next,
          primary: true,
        ),
      ], gap: HinterTokens.s4);
    }
    return FullPage(
      title: _step.title,
      subtitle: 'Step ${_step.index + 1} of ${FirstBootStep.values.length}',
      child: SingleChildScrollView(child: p.build()),
    );
  }
}
