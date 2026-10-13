import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../widgets.dart';
import 'common.dart';

// ------------------------------------------------------------------ network

class NetworkSection extends StatefulWidget {
  const NetworkSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<NetworkSection> createState() => _NetworkSectionState();
}

typedef _NetData = (NetworkStatus, List<WifiNetwork>);

class _NetworkSectionState extends State<NetworkSection> {
  /// Results of our own scans, fed into the pane like the daemon's
  /// `wifi_list_changed`.
  final _scanned = StreamController<List<WifiNetwork>>.broadcast();
  String? _joining;
  bool _scanning = false;

  NetworkRepository get _net => widget.env.services.network;

  @override
  void dispose() {
    unawaited(_scanned.close());
    super.dispose();
  }

  Future<_NetData> _load() async {
    final status = await _net.status();
    if (!status.wifiAvailable || !status.wifiEnabled) {
      return (status, const <WifiNetwork>[]);
    }
    final list = await _net.list();
    unawaited(_rescan());
    return (status, list);
  }

  /// `wifi.scan` (a few seconds); the list updates when it is done.
  Future<void> _rescan() async {
    if (_scanning || !mounted) return;
    setState(() => _scanning = true);
    try {
      final list = await _net.scan().timeout(const Duration(seconds: 10));
      if (!_scanned.isClosed) _scanned.add(list);
    } on SystemException catch (e) {
      if (mounted && e.kind == SystemErrorKind.notAuthorized) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    } on TimeoutException {
      if (mounted) {
        await showMessage(
          context,
          title: 'Search took too long',
          body: 'Select "Scan again" to try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loaded<_NetData>(
      region: widget.env.region,
      load: _load,
      updates: [
        _net.statusChanges.map<_NetData Function(_NetData)>(
          (s) =>
              (d) => (s, s.wifiEnabled ? d.$2 : const <WifiNetwork>[]),
        ),
        _net.listChanges.map<_NetData Function(_NetData)>(
          (l) =>
              (d) => (d.$1, d.$1.wifiEnabled ? l : const <WifiNetwork>[]),
        ),
        _scanned.stream.map<_NetData Function(_NetData)>(
          (l) =>
              (d) => (d.$1, d.$1.wifiEnabled ? l : const <WifiNetwork>[]),
        ),
      ],
      builder: (context, data, reload) {
        final (status, networks) = data;
        final t = HinterTheme.of(context);
        final p = Pane(widget.env.region);
        p.add(_statusLine(status));
        if (_joining != null) p.add(StatusLine('Connecting to $_joining...'));
        if (!status.wifiAvailable) {
          p.add(
            Text('There is no Wi-Fi adapter in this box.', style: t.bodyDim),
          );
          return p.build();
        }
        p.item(
          'wifi',
          onSelect: () async {
            await _guard(() => _net.setWifiEnabled(!status.wifiEnabled));
            await reload();
          },
          builder: (f) => SettingRow(
            title: 'Wi-Fi',
            focused: f,
            trailing: ToggleMark(on: status.wifiEnabled),
          ),
          gap: HinterTokens.s2,
        );
        if (status.wifiEnabled) {
          p.item(
            'scan',
            onSelect: _scanning ? null : _rescan,
            builder: (f) => SettingRow(
              title: _scanning ? 'Scanning…' : 'Scan again',
              focused: f,
              dim: true,
              trailing: _scanning ? const Spinner() : null,
            ),
          );
          p.add(Text('Networks nearby', style: t.label), gap: HinterTokens.s2);
          if (networks.isEmpty) {
            p.add(Text('No networks found.', style: t.bodyDim));
          }
          for (var i = 0; i < networks.length; i++) {
            final n = networks[i];
            p.item(
              'n$i',
              onSelect: () => _select(n, reload),
              builder: (f) => SettingRow(
                title: n.ssid,
                focused: f,
                subtitle: [
                  if (n.connected) 'Connected',
                  if (!n.connected && n.saved) 'Saved',
                  if (!n.supported)
                    'Not supported'
                  else
                    n.secured ? 'Needs a password' : 'Open',
                  n.strength,
                ].join(', '),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (n.secured) const LockMark(),
                    const SizedBox(width: HinterTokens.s2),
                    SignalBars(bars: n.bars),
                  ],
                ),
              ),
            );
          }
        }
        return p.build();
      },
    );
  }

  Widget _statusLine(NetworkStatus s) {
    final where = s.wifiSsid != null
        ? 'Connected to ${s.wifiSsid}'
              '${s.address == null ? '' : ' (${s.address})'}'
        : s.ethernet
        ? 'Connected by cable${s.address == null ? '' : ' (${s.address})'}'
        : null;
    if (where == null) return const StatusLine('Not connected.');
    return switch (s.connectivity) {
      Connectivity.none ||
      Connectivity.limited => StatusLine('$where. No internet.'),
      Connectivity.portal => StatusLine('$where. The network needs a sign-in.'),
      _ => StatusLine('$where.', ok: true),
    };
  }

  Future<void> _select(WifiNetwork n, Future<void> Function() reload) async {
    if (!n.supported) {
      await showMessage(
        context,
        title: n.ssid,
        body:
            "This type of network (WEP or a business login) isn't "
            'supported.',
      );
      return;
    }
    if (n.connected) {
      final c = await showChoice<String>(
        context,
        title: n.ssid,
        body: 'Connected.',
        choices: const [
          Choice('Disconnect', 'disconnect'),
          Choice('Forget this network', 'forget', danger: true),
        ],
      );
      if (c == null || !mounted) return;
      await _guard(
        () => c == 'disconnect' ? _net.disconnect() : _net.forget(n.ssid),
      );
    } else if (n.secured && !n.saved) {
      await _askPassword(n);
    } else {
      await _join(n);
    }
    await reload();
  }

  /// Joins a saved or open network; a saved password the network no longer
  /// accepts asks for the new one.
  Future<void> _join(WifiNetwork n) async {
    setState(() => _joining = n.ssid);
    try {
      await _net.connect(n.ssid);
    } on SystemException catch (e) {
      if (!mounted) return;
      setState(() => _joining = null);
      if (e.kind == SystemErrorKind.wrongPassword && n.secured) {
        await _askPassword(
          n,
          body: 'The saved password was not accepted. Type the new one.',
        );
      } else {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    } finally {
      if (mounted) setState(() => _joining = null);
    }
  }

  /// The password dialog: a refused password keeps it open (and the keyboard
  /// comes back) for another try.
  Future<void> _askPassword(WifiNetwork n, {String? body}) async {
    await showTextEntry(
      context,
      title: 'Password for ${n.ssid}',
      body: body,
      secret: true,
      submitLabel: 'Connect',
      submit: (pw) async {
        if (pw.isEmpty) return 'Type the password first.';
        try {
          await _net.connect(n.ssid, password: pw);
          return null;
        } on SystemException catch (e) {
          return e.kind == SystemErrorKind.wrongPassword
              ? 'Wrong password. Try again.'
              : e.message;
        }
      },
    );
  }
}

// ------------------------------------------------------------------ bluetooth

class BluetoothSection extends StatefulWidget {
  const BluetoothSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<BluetoothSection> createState() => _BluetoothSectionState();
}

class _BluetoothSectionState extends State<BluetoothSection> {
  late List<BtDevice> _devices = widget.env.services.bluetooth.current;
  late bool _scanning = widget.env.services.bluetooth.scanning;
  bool _loaded = false;
  Object? _error;
  String? _pairing;
  ModalHandle<bool>? _confirmModal;
  int _confirmId = 0;
  final _closed = <int>{};
  StreamSubscription<List<BtDevice>>? _sub;
  StreamSubscription<BtConfirmRequest>? _confirms;

  BluetoothRepository get _bt => widget.env.services.bluetooth;

  @override
  void initState() {
    super.initState();
    _sub = _bt.devices.listen((d) {
      if (mounted) {
        setState(() {
          _devices = d;
          _scanning = _bt.scanning;
        });
      }
    });
    _confirms = _bt.confirmRequests.listen(_onConfirm);
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _confirms?.cancel();
    // Scanning drains power and slows audio: stop when leaving.
    if (_scanning) unawaited(_bt.stopScan().catchError((_) {}));
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _bt.load();
      if (!mounted) return;
      setState(() {
        _devices = _bt.current;
        _scanning = _bt.scanning;
        _error = null;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    }
  }

  /// The daemon wants the user's word on a pairing (`bluetooth_confirm`), or
  /// shows a code to type on the device.
  Future<void> _onConfirm(BtConfirmRequest r) async {
    if (!mounted) return;
    _closeConfirm();
    final id = ++_confirmId;
    final accepted = await ModalScope.of(context).show<bool>((c, m) {
      _confirmModal = m;
      return PairConfirmDialog(modal: m, request: r);
    });
    if (_confirmId == id) _confirmModal = null;
    // Closed by us (the pairing ended): nothing to answer any more.
    if (_closed.remove(id) || !r.mustAnswer || !mounted) return;
    try {
      await _bt.confirm(r.id, accept: accepted == true);
    } on SystemException catch (_) {
      // The 30 s ran out in between: the pairing is over anyway.
    }
  }

  void _closeConfirm() {
    final m = _confirmModal;
    if (m == null) return;
    _closed.add(_confirmId);
    m.close();
    _confirmModal = null;
  }

  Future<void> _pair(BtDevice d) async {
    setState(() => _pairing = d.id);
    try {
      await _bt.pair(d.id);
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    } finally {
      _closeConfirm();
      if (mounted) setState(() => _pairing = null);
    }
  }

  Future<void> _select(BtDevice d) async {
    if (_pairing != null) return;
    if (!d.paired) {
      final r = await showConfirm(
        context,
        title: 'Pair with ${d.name}?',
        body: 'Put the device in pairing mode first.',
        confirmLabel: 'Pair',
      );
      if (r == null) return;
      await _pair(d);
      return;
    }
    final c = await showChoice<String>(
      context,
      title: d.name,
      body: '${d.kind.label}, ${d.connected ? 'connected' : 'paired'}.',
      choices: [
        if (d.connected)
          const Choice('Disconnect', 'disconnect')
        else
          const Choice('Connect', 'connect'),
        const Choice('Forget this device', 'forget', danger: true),
      ],
    );
    if (c == null) return;
    await _guard(
      () => switch (c) {
        'connect' => _bt.connect(d.id),
        'disconnect' => _bt.disconnect(d.id),
        _ => _bt.forget(d.id),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(widget.env.region);
    if (_error != null) {
      p
        ..add(StatusLine(describeError(_error!), error: true))
        ..buttons('retry', [
          btn('Try again', () {
            setState(() => _error = null);
            unawaited(_load());
          }),
        ]);
      return p.build();
    }
    if (!_loaded) {
      widget.env.region.setRows(const []);
      return const StatusLine('Loading...');
    }
    p.item(
      'scan',
      onSelect: () async {
        await _guard(() => _scanning ? _bt.stopScan() : _bt.startScan());
        if (mounted) setState(() => _scanning = _bt.scanning);
      },
      builder: (f) => SettingRow(
        title: 'Look for new devices',
        subtitle: _scanning ? 'Put your device in pairing mode.' : null,
        focused: f,
        trailing: ToggleMark(
          on: _scanning,
          label: _scanning ? 'Searching' : 'Off',
        ),
      ),
    );
    p.add(Text('Devices', style: t.label), gap: HinterTokens.s2);
    if (_devices.isEmpty) {
      p.add(Text('No devices yet.', style: t.bodyDim));
    }
    for (var i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      final pairing = _pairing == d.id;
      p.item(
        'd$i',
        onSelect: () => _select(d),
        builder: (f) => SettingRow(
          title: d.name,
          focused: f,
          subtitle: [
            d.kind.label,
            pairing
                ? 'pairing'
                : d.connected
                ? 'connected'
                : d.paired
                ? 'paired'
                : 'not paired',
            if (d.battery != null) '${d.battery}% battery',
          ].join(', '),
          trailing: Text(
            pairing
                ? 'Pairing...'
                : d.connected
                ? 'Connected'
                : d.paired
                ? 'Paired'
                : 'Pair',
            style: t.bodyDim,
          ),
        ),
      );
    }
    return p.build();
  }
}

/// A pairing that needs the user: compare the code with the device's and
/// accept or reject (mode `confirm`), or type the code shown here on the
/// device (mode `display`).
class PairConfirmDialog extends StatelessWidget {
  const PairConfirmDialog({
    super.key,
    required this.modal,
    required this.request,
  });

  final ModalHandle<bool> modal;
  final BtConfirmRequest request;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final r = request;
    modal.region.setRows([NavRow('buttons', r.mustAnswer ? 2 : 1)]);
    return DialogCard(
      title: 'Pair with ${r.name}?',
      children: [
        Text(
          r.mustAnswer
              ? 'Does ${r.name} show the same code?'
              : 'Type this code on ${r.name}, then press Enter there.',
          style: t.bodyDim,
        ),
        const SizedBox(height: HinterTokens.s3),
        Center(
          child: Text(
            r.passkey,
            key: const ValueKey('passkey'),
            style: t.headline.copyWith(letterSpacing: 8),
          ),
        ),
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: modal.region,
          rowKey: 'buttons',
          buttons: r.mustAnswer
              ? [
                  btn('Reject', () => modal.close(false)),
                  btn('Accept', () => modal.close(true), primary: true),
                ]
              : [btn('Hide', () => modal.close(false), primary: true)],
        ),
      ],
    );
  }
}
