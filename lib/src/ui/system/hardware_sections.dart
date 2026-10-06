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

class NetworkSection extends StatelessWidget {
  const NetworkSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) {
    final net = env.services.network;
    return Loaded<(NetworkStatus, List<WifiNetwork>)>(
      region: env.region,
      load: () async => (await net.status(), await net.scan()),
      builder: (context, data, reload) {
        final (status, networks) = data;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        p.add(
          StatusLine(
            status.wifiSsid != null
                ? 'Connected to ${status.wifiSsid}'
                      '${status.address == null ? '' : ' (${status.address})'}.'
                : status.ethernet
                ? 'Connected by cable.'
                : 'Not connected.',
            ok: status.online,
          ),
        );
        p.item(
          'wifi',
          onSelect: () async {
            await _guard(
              context,
              () => net.setWifiEnabled(!status.wifiEnabled),
            );
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
            onSelect: reload,
            builder: (f) =>
                SettingRow(title: 'Scan again', focused: f, dim: true),
          );
          p.add(Text('Networks nearby', style: t.label), gap: HinterTokens.s2);
          for (var i = 0; i < networks.length; i++) {
            final n = networks[i];
            p.item(
              'n$i',
              onSelect: () => _select(context, n, reload),
              builder: (f) => SettingRow(
                title: n.ssid,
                focused: f,
                subtitle: [
                  if (n.connected) 'Connected',
                  if (!n.connected && n.saved) 'Saved',
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

  Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
    }
  }

  Future<void> _select(
    BuildContext context,
    WifiNetwork n,
    Future<void> Function() reload,
  ) async {
    final net = env.services.network;
    if (n.connected) {
      final c = await showChoice<String>(
        context,
        title: n.ssid,
        body: 'You are connected to this network.',
        choices: const [
          Choice('Disconnect', 'disconnect'),
          Choice('Forget this network', 'forget', danger: true),
        ],
      );
      if (c == null || !context.mounted) return;
      await _guard(
        context,
        () => c == 'disconnect' ? net.disconnect() : net.forget(n.ssid),
      );
    } else if (n.secured && !n.saved) {
      final r = await showTextEntry(
        context,
        title: 'Password for ${n.ssid}',
        body:
            'Wi-Fi passwords are kept on this box for everyone who uses it, '
            'so you only enter it once.',
        secret: true,
        submitLabel: 'Connect',
        submit: (pw) async {
          if (pw.isEmpty) return 'Type the password first.';
          try {
            await net.connect(n.ssid, password: pw);
            return null;
          } on SystemException catch (e) {
            return e.kind == SystemErrorKind.wrongPassword
                ? 'That password was not accepted. Try again.'
                : e.message;
          }
        },
      );
      if (r == null) return;
    } else {
      await _guard(context, () => net.connect(n.ssid));
    }
    await reload();
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
  StreamSubscription<List<BtDevice>>? _sub;

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
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Scanning drains power and slows audio: stop when leaving.
    unawaited(_bt.stopScan().catchError((_) {}));
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
    }
  }

  Future<void> _select(BtDevice d) async {
    if (!d.paired) {
      final r = await showConfirm(
        context,
        title: 'Pair with ${d.name}?',
        body:
            'Put it in pairing mode first (for a controller, hold its '
            'pairing button until the light flashes).',
        confirmLabel: 'Pair',
      );
      if (r == null) return;
      await _guard(() => _bt.pair(d.id));
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
    p.item(
      'scan',
      onSelect: () async {
        await _guard(() => _scanning ? _bt.stopScan() : _bt.startScan());
        if (mounted) setState(() => _scanning = _bt.scanning);
      },
      builder: (f) => SettingRow(
        title: 'Look for new devices',
        subtitle: _scanning
            ? 'Searching. Put your device in pairing mode.'
            : null,
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
      p.item(
        'd$i',
        onSelect: () => _select(d),
        builder: (f) => SettingRow(
          title: d.name,
          focused: f,
          subtitle:
              '${d.kind.label}, '
              '${d.connected
                  ? 'connected'
                  : d.paired
                  ? 'paired'
                  : 'not paired'}',
          trailing: Text(
            d.connected
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

// ------------------------------------------------------------------ display

class DisplaySection extends StatelessWidget {
  const DisplaySection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) {
    final da = env.services.displayAudio;
    return Loaded<List<DisplayMode>>(
      region: env.region,
      load: da.displayModes,
      builder: (context, modes, reload) {
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        p.item(
          'guide',
          onSelect: () =>
              ModalScope.of(context)
                  .show<void>((c, m) => SafeAreaGuide(modal: m)),
          builder: (f) => SettingRow(
            title: 'Check the picture edges',
            subtitle: 'Shows the safe area, to spot overscan.',
            focused: f,
            trailing: const _SafePreview(),
          ),
        );
        p.add(
          Text('Resolution and refresh rate', style: t.label),
          gap: HinterTokens.s2,
        );
        for (var i = 0; i < modes.length; i++) {
          final m = modes[i];
          p.item(
            'm$i',
            onSelect: () => _apply(context, modes, m, reload),
            builder: (f) => SettingRow(
              title: m.label,
              focused: f,
              subtitle: [
                m.name,
                if (m.preferred) 'recommended by your TV',
              ].join(', '),
              trailing: Text(m.current ? 'Current' : '', style: t.bodyDim),
              leading: _Radio(selected: m.current),
            ),
          );
        }
        return p.build();
      },
    );
  }

  Future<void> _apply(
    BuildContext context,
    List<DisplayMode> modes,
    DisplayMode m,
    Future<void> Function() reload,
  ) async {
    if (m.current) return;
    final da = env.services.displayAudio;
    final old = modes.firstWhere((x) => x.current, orElse: () => m);
    try {
      await da.setDisplayMode(m);
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
      return;
    }
    if (!context.mounted) return;
    final keep = await ModalScope.of(context)
        .show<bool>((c, modal) => KeepDisplayDialog(modal: modal, mode: m));
    if (keep != true) {
      try {
        await da.setDisplayMode(old);
      } catch (_) {}
    }
    await reload();
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.text, width: 3),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// A miniature screen with the 5% safe frame.
class _SafePreview extends StatelessWidget {
  const _SafePreview();

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Container(
      width: 128,
      height: 72,
      decoration: BoxDecoration(
        color: t.background,
        border: Border.all(color: t.text, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6.4, vertical: 3.6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: t.accent, width: 2),
        ),
      ),
    );
  }
}

/// "Keep this resolution?" with a countdown that reverts on its own, so a
/// mode the TV cannot show never strands the user on a black screen.
class KeepDisplayDialog extends StatefulWidget {
  const KeepDisplayDialog({
    super.key,
    required this.modal,
    required this.mode,
    this.seconds = 15,
  });

  final ModalHandle<bool> modal;
  final DisplayMode mode;
  final int seconds;

  @override
  State<KeepDisplayDialog> createState() => _KeepDisplayDialogState();
}

class _KeepDisplayDialogState extends State<KeepDisplayDialog> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        widget.modal.close(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    widget.modal.region.setRows(const [NavRow('buttons', 2)]);
    return DialogCard(
      title: 'Keep ${widget.mode.label}?',
      children: [
        Text(
          'If you can see this, the TV accepts it. Going back to the old '
          'setting in $_left seconds unless you keep it.',
          style: t.bodyDim,
        ),
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: widget.modal.region,
          rowKey: 'buttons',
          buttons: [
            btn('Go back', () => widget.modal.close(false)),
            btn('Keep', () => widget.modal.close(true), primary: true),
          ],
        ),
      ],
    );
  }
}

/// Full screen: the outer edge and the inner frame 5% in (the margin the
/// launcher keeps free of anything important).
class SafeAreaGuide extends StatelessWidget {
  const SafeAreaGuide({super.key, required this.modal});

  final ModalHandle<void> modal;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    modal.region.setRows(const [NavRow('close', 1)]);
    return ColoredBox(
      color: t.background,
      child: LayoutBuilder(
        builder: (context, c) {
          final mx = c.maxWidth * 0.05;
          final my = c.maxHeight * 0.05;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: t.danger, width: 8),
                  ),
                ),
              ),
              Positioned(
                left: mx,
                right: mx,
                top: my,
                bottom: my,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: t.accent, width: 4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(HinterTokens.s5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Safe area', style: t.headline),
                        const SizedBox(height: HinterTokens.s2),
                        Text(
                          'You should see the red line at the very edge of '
                          'the screen on all four sides. If it is cut off, '
                          'the TV is zooming the picture (overscan): look for '
                          'a "Just scan", "Screen fit" or "1:1" picture '
                          'setting on the TV. The blue frame is the margin '
                          'HinterOS keeps clear, so everything important '
                          'stays visible even on a TV that cannot be fixed.',
                          style: t.body,
                        ),
                        const SizedBox(height: HinterTokens.s4),
                        DialogButtons(
                          region: modal.region,
                          rowKey: 'close',
                          buttons: [btn('Done', modal.close, primary: true)],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ audio

class AudioSection extends StatefulWidget {
  const AudioSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<AudioSection> createState() => _AudioSectionState();
}

class _AudioSectionState extends State<AudioSection> {
  AudioState? _audio;
  Object? _error;

  DisplayAudioRepository get _da => widget.env.services.displayAudio;

  @override
  void initState() {
    super.initState();
    widget.env.region.interceptMove = _onMove;
    unawaited(_load());
  }

  @override
  void dispose() {
    if (widget.env.region.interceptMove == _onMove) {
      widget.env.region.interceptMove = null;
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await _da.audio();
      if (mounted) setState(() => _audio = a);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Left and right on the volume row change the volume.
  bool _onMove(NavDir dir) {
    final a = _audio;
    if (a == null || widget.env.region.model.currentRow?.key != 'volume') {
      return false;
    }
    if (dir != NavDir.left && dir != NavDir.right) return false;
    final v = (a.volume + (dir == NavDir.right ? 5 : -5)).clamp(0, 100);
    setState(
      () => _audio = AudioState(outputs: a.outputs, volume: v, muted: a.muted),
    );
    unawaited(_da.setVolume(v));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    if (_error != null) {
      return (Pane(
        widget.env.region,
      )..add(StatusLine(describeError(_error!), error: true))).build();
    }
    final a = _audio;
    if (a == null) {
      widget.env.region.setRows(const []);
      return const StatusLine('Loading...');
    }
    final p = Pane(widget.env.region);
    p.item(
      'volume',
      onSelect: () async {
        await _da.setMuted(!a.muted);
        await _load();
      },
      builder: (f) => SettingRow(
        title: 'Volume',
        subtitle: 'Left and right change it. Accept mutes.',
        focused: f,
        trailing: SizedBox(
          width: 420,
          child: Row(
            children: [
              Expanded(child: HBar(fraction: a.muted ? 0 : a.volume / 100)),
              const SizedBox(width: HinterTokens.s2),
              SizedBox(
                width: 110,
                child: Text(
                  a.muted ? 'Muted' : '${a.volume}%',
                  textAlign: TextAlign.right,
                  style: t.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    p.add(Text('Play sound through', style: t.label), gap: HinterTokens.s2);
    for (var i = 0; i < a.outputs.length; i++) {
      final o = a.outputs[i];
      p.item(
        'o$i',
        onSelect: () async {
          await _da.setAudioOutput(o.id);
          await _load();
        },
        builder: (f) => SettingRow(
          title: o.name,
          focused: f,
          leading: _Radio(selected: o.current),
        ),
      );
    }
    return p.build();
  }
}

// ------------------------------------------------------------------ power

class PowerSection extends StatelessWidget {
  const PowerSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) {
    final sys = env.services.system;
    final p = Pane(env.region);
    Future<void> run(PowerAction a) async {
      try {
        await sys.power(a);
      } on SystemException catch (e) {
        if (context.mounted) {
          await showMessage(
            context,
            title: "That didn't work",
            body: e.message,
          );
        }
      }
    }

    Future<void> confirm(PowerAction a, String body) async {
      final r = await showConfirm(
        context,
        title: '${a.label}?',
        body: body,
        confirmLabel: a.label,
        danger: true,
      );
      if (r != null) await run(a);
    }

    p.item(
      'sleep',
      onSelect: () => run(PowerAction.sleep),
      builder: (f) => SettingRow(
        title: 'Sleep',
        subtitle: 'Wake it with a controller button.',
        focused: f,
      ),
    );
    p.item(
      'restart',
      onSelect: () => confirm(
        PowerAction.restart,
        'Everything that is running is closed, then the box starts again.',
      ),
      builder: (f) => SettingRow(title: 'Restart', focused: f),
    );
    p.item(
      'shutdown',
      onSelect: () => confirm(
        PowerAction.shutdown,
        'Everything that is running is closed and the box turns off.',
      ),
      builder: (f) => SettingRow(title: 'Shut down', focused: f),
    );
    return p.build();
  }
}
