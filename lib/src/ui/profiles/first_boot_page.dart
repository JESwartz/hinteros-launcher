/// First-boot mode inside the session: when
/// `profile.current` says `setup_required` (no admin profile exists; this
/// session runs on the spare account), the launcher opens this wizard over
/// Home: controllers, network, time zone (it starts on the
/// box's zone, UTC on a new box, and needs no PIN), display, then the
/// profile form for the admin profile (`profiles.setup_admin`: no rebuild,
/// no network), and ends on Home in the new profile.
///
/// Every step between Welcome and All set is a choice, and the profile step
/// is the form itself, not a page about it. Display always has the picture
/// edge check; the resolution only when the display has modes to choose.
/// Controllers and Display are optional: their button says Skip until
/// something was done there.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../pages.dart' show FullPage, PageScroll;
import '../system/hardware_sections.dart'
    show DisplayModeDropDown, KeepDisplayDialog, SafeAreaGuide, SafePreview;
import '../system/network_sections.dart' show PairConfirmDialog;
import '../time_zone/time_zone_picker.dart';
import '../widgets.dart';
import 'profile_form.dart';
import 'session_profile.dart' show sessionEditText;

enum FirstBootStep {
  welcome('Welcome'),
  controllers('Controllers', optional: true),
  network('Internet'),
  timeZone('Time zone'),
  display('Display', optional: true),
  profile('Create your profile'),
  done('All set');

  const FirstBootStep(this.title, {this.optional = false});
  final String title;
  final bool optional;
}

/// How long one controller search lasts (the daemon's most); it starts
/// again while the step is open.
const _scanSeconds = 300;

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
  StreamSubscription<BtConfirmRequest>? _confirms;
  Timer? _rescan;

  /// The device being paired now, and the open code dialog of that pairing.
  String? _pairing;
  ModalHandle<bool>? _confirmModal;
  DisplayInfo? _display;
  bool _displayLoaded = false;

  /// A mode was kept on the Display step (it is not skipped then).
  bool _modeChanged = false;
  TimeZoneInfo? _zone;
  List<TimeZoneEntry> _zones = const [];
  bool _settingZone = false;
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
    _confirms?.cancel();
    _stopScan();
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

  void _go(FirstBootStep s, {bool forward = true}) {
    if (_step == FirstBootStep.controllers && s != _step) _stopScan();
    setState(() {
      _step = s;
      _message = null;
    });
    _region.reset();
    switch (s) {
      case FirstBootStep.network:
        unawaited(_loadNetwork());
      case FirstBootStep.timeZone:
        unawaited(_loadTimeZone());
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
            await _s.network.connect(ap.id, password: pw);
            return null;
          } on SystemException catch (e) {
            return e.message;
          }
        },
      );
    } else {
      await _try(() => _s.network.connect(ap.id));
    }
    await _loadNetwork();
  }

  Future<void> _loadTimeZone() async {
    final tz = _s.timeZone;
    final info = await _try(tz.get);
    final zones = await _try(tz.list);
    if (!mounted) return;
    setState(() {
      _zone = info ?? _zone;
      _zones = zones ?? _zones;
    });
    // The drop-down first (it was not there while loading).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _step != FirstBootStep.timeZone || _zone == null) return;
      _region.model.goTo(0, 0);
      _region.changed();
      unawaited(_region.focusCurrent());
    });
  }

  /// First-boot mode: no admin profile yet, so no PIN.
  Future<void> _setZone(TimeZoneEntry z) async {
    setState(() {
      _settingZone = true;
      _message = null;
    });
    final info = await _try(() => _s.timeZone.set(z.zone));
    if (!mounted) return;
    setState(() {
      _settingZone = false;
      if (info != null) _zone = info;
    });
  }

  Future<void> _loadControllers() async {
    await _try(_s.bluetooth.load);
    _bt ??= _s.bluetooth.devices.listen((d) {
      if (mounted) setState(() => _devices = d);
    });
    _confirms ??= _s.bluetooth.confirmRequests.listen(_onConfirm);
    if (mounted) setState(() => _devices = _s.bluetooth.current);
    // Left the step (Skip) or the wizard meanwhile: no scan.
    bool left() => !mounted || _step != FirstBootStep.controllers;
    if (left()) return;
    await _try(() => _s.bluetooth.startScan(timeoutS: _scanSeconds));
    if (left()) {
      unawaited(_s.bluetooth.stopScan().catchError((_) {}));
      return;
    }
    // A controller put in pairing mode later must still be found.
    _rescan?.cancel();
    _rescan = Timer.periodic(const Duration(seconds: _scanSeconds - 10), (_) {
      if (mounted && _step == FirstBootStep.controllers) {
        unawaited(_try(() => _s.bluetooth.startScan(timeoutS: _scanSeconds)));
      }
    });
  }

  void _stopScan() {
    if (_rescan == null) return;
    _rescan!.cancel();
    _rescan = null;
    // Scanning slows Bluetooth audio and other devices.
    unawaited(_s.bluetooth.stopScan().catchError((_) {}));
  }

  /// Controllers first, then by name; the order does not change while a
  /// row has the focus only because a device was found.
  List<BtDevice> get _sortedDevices {
    final l = [..._devices];
    int rank(BtDevice d) => d.kind == BtKind.controller ? 0 : 1;
    l.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return l;
  }

  /// Pairs (the daemon trusts and connects it), or connects a paired one.
  Future<void> _chooseDevice(BtDevice d) async {
    if (_pairing != null || d.connected) return;
    setState(() {
      _pairing = d.id;
      _message = null;
    });
    try {
      await _try(
        () => d.paired ? _s.bluetooth.connect(d.id) : _s.bluetooth.pair(d.id),
      );
    } finally {
      _confirmModal?.close();
      _confirmModal = null;
      if (mounted) setState(() => _pairing = null);
    }
  }

  /// The pairing needs a code compared or typed on the device.
  Future<void> _onConfirm(BtConfirmRequest r) async {
    if (!mounted || _step != FirstBootStep.controllers) return;
    _confirmModal?.close();
    final accepted = await ModalScope.of(context).show<bool>((c, m) {
      _confirmModal = m;
      return PairConfirmDialog(modal: m, request: r);
    });
    // Closed because the pairing ended: nothing to answer.
    if (_confirmModal == null || !r.mustAnswer) return;
    _confirmModal = null;
    await _try(() => _s.bluetooth.confirm(r.id, accept: accepted == true));
  }

  Future<void> _loadDisplay() async {
    final d = await _try(_s.displayAudio.displayModes);
    if (!mounted || _step != FirstBootStep.display) return;
    setState(() {
      _display = d;
      _displayLoaded = true;
    });
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
    if (keep == true) _modeChanged = true;
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
        p.add(Text('Set up HinterOS', style: t.title));
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
        if (_devices.isEmpty) {
          p.add(const StatusLine('Searching...', busy: true));
        }
        // Rows keyed by address: a device found meanwhile does not move the
        // focus to another device.
        for (final d in _sortedDevices) {
          final pairing = _pairing == d.id;
          p.item(
            'bt-${d.id}',
            onSelect: d.connected || _pairing != null
                ? null
                : () => unawaited(_chooseDevice(d)),
            builder: (f) => SettingRow(
              title: d.name,
              subtitle: d.kind == BtKind.controller ? null : d.kind.label,
              focused: f,
              trailing: pairing
                  ? const Spinner(size: 32)
                  : Text(
                      d.connected
                          ? 'Connected'
                          : d.paired
                          ? 'Connect'
                          : 'Pair',
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
                : n.wifiSsid != null
                ? 'Connected to ${n.wifiSsid}.'
                : n.ethernet
                ? 'Connected by cable.'
                : 'Not online. Updates and the Store need the internet.',
            ok: n?.online ?? false,
          ),
        );
        // Names can repeat (one per security): the list's own flag says
        // which one is joined; the name only when the list has none.
        final listed = _wifi.any((ap) => ap.connected);
        for (var i = 0; i < _wifi.length; i++) {
          final ap = _wifi[i];
          final joined = ap.connected || (!listed && ap.ssid == n?.wifiSsid);
          p.item(
            'w$i',
            onSelect: joined ? null : () => unawaited(_join(ap)),
            builder: (f) => SettingRow(
              title: ap.ssid,
              focused: f,
              leading: SignalBars(bars: ap.bars),
              trailing: joined
                  ? Text('Connected', style: t.caption)
                  : (ap.secured ? const LockMark() : null),
            ),
          );
        }
      case FirstBootStep.timeZone:
        final z = _zone;
        if (z == null) {
          if (_message == null) p.add(const StatusLine('Loading...'));
        } else {
          p.row(
            'zone',
            1,
            TimeZonePicker(
              region: _region,
              rowKey: 'zone',
              zones: _zones,
              current: z,
              busy: _settingZone,
              onChoose: _setZone,
            ),
          );
        }
      case FirstBootStep.display:
        final d = _display;
        if (!_displayLoaded) {
          p.add(const StatusLine('Checking the display...', busy: true));
        } else {
          // Only a display that can be set and has more than one mode.
          if (d != null && d.canSet && d.modes.length > 1) {
            p.add(Text('Choose a resolution', style: t.bodyDim));
            p.row(
              'mode',
              1,
              DisplayModeDropDown(
                region: _region,
                rowKey: 'mode',
                modes: d.modes,
                onChoose: (m) => unawaited(_setMode(m)),
              ),
            );
          }
          p.item(
            'guide',
            onSelect: () =>
                ModalScope.of(context)
                    .show<void>((c, m) => SafeAreaGuide(modal: m)),
            builder: (f) => SettingRow(
              title: 'Check the picture edges',
              focused: f,
              trailing: const SafePreview(),
            ),
            gap: HinterTokens.s3,
          );
        }
      case FirstBootStep.profile:
        // The form is open over this; only a failed setup shows here.
        break;
      case FirstBootStep.done:
        p.add(Text("You're all set, ${_createdName ?? ''}.", style: t.title));
    }
    if (_step != FirstBootStep.profile || _message != null) {
      p.buttons('actions', [
        btn(
          switch (_step) {
            FirstBootStep.welcome => 'Start',
            FirstBootStep.profile => 'Try again',
            FirstBootStep.done => 'Go to Home',
            FirstBootStep.controllers when !_devices.any((d) => d.connected) =>
              'Skip',
            FirstBootStep.display when !_modeChanged => 'Skip',
            _ => 'Continue',
          },
          _next,
          primary: true,
        ),
      ], gap: HinterTokens.s4);
    }
    return FullPage(
      title: _step.title,
      subtitle:
          'Step ${_step.index + 1} of ${FirstBootStep.values.length}'
          '${_step.optional ? ' · Optional' : ''}',
      child: PageScroll(child: p.build()),
    );
  }
}
