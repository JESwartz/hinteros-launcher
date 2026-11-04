import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../drop_down.dart';
import '../modal_host.dart';
import '../session_ending.dart';
import '../widgets.dart';
import 'common.dart';

// ------------------------------------------------------------------ display

class DisplaySection extends StatelessWidget {
  const DisplaySection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) {
    final da = env.services.displayAudio;
    return Loaded<DisplayInfo>(
      region: env.region,
      load: da.displayModes,
      builder: (context, info, reload) {
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        if (!info.canSet) {
          p.add(
            const StatusLine(
              "The resolution of this display can't be changed.",
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
          gap: info.canSet ? HinterTokens.s1 + 4 : HinterTokens.s2,
        );
        p.add(
          Text(
            info.display == null
                ? 'Resolution and refresh rate'
                : 'Resolution and refresh rate of ${info.display}',
            style: t.label,
          ),
          gap: HinterTokens.s2,
        );
        if (info.modes.isNotEmpty) {
          p.row(
            'mode',
            1,
            DisplayModeDropDown(
              region: env.region,
              rowKey: 'mode',
              modes: info.modes,
              onChoose: (m) => unawaited(_apply(context, info, m, reload)),
            ),
          );
        }
        return p.build();
      },
    );
  }

  /// `display.set_mode`, then the 15 second dialog: Keep calls `display.keep`,
  /// Go back or no answer in time calls `display.revert`.
  Future<void> _apply(
    BuildContext context,
    DisplayInfo info,
    DisplayMode m,
    Future<void> Function() reload,
  ) async {
    if (m.current) return;
    Future<void> say(SystemException e) =>
        showMessage(context, title: refusalTitle(e), body: e.message);
    if (!info.canSet) {
      await showMessage(
        context,
        title: "Can't change this",
        body: "The resolution of this display can't be changed.",
      );
      return;
    }
    final da = env.services.displayAudio;
    try {
      await da.setDisplayMode(m);
    } on SystemException catch (e) {
      if (context.mounted) await say(e);
      await reload();
      return;
    }
    if (!context.mounted) return;
    final keep = await ModalScope.of(context)
        .show<bool>((c, modal) => KeepDisplayDialog(modal: modal, mode: m));
    try {
      if (keep == true) {
        await da.keepDisplayMode();
      } else {
        await da.revertDisplayMode();
      }
    } on SystemException catch (e) {
      if (context.mounted) await say(e);
    }
    await reload();
  }
}

/// The display modes as a drop-down (Settings > Display, the first-boot
/// display step): the field shows the current mode, A opens the list of
/// every mode at it. One item, at [rowKey]:0 of [region]; put it in a pane
/// with `Pane.row(rowKey, 1, DisplayModeDropDown(...))`.
class DisplayModeDropDown extends StatelessWidget {
  const DisplayModeDropDown({
    super.key,
    required this.region,
    required this.rowKey,
    required this.modes,
    required this.onChoose,
    this.maxWidth = 1100,
  });

  final NavRegion region;
  final String rowKey;
  final List<DisplayMode> modes;

  /// A mode other than the current one was chosen.
  final void Function(DisplayMode mode) onChoose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final current = modes.where((m) => m.current).firstOrNull;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DropDown<DisplayMode>(
        region: region,
        rowKey: rowKey,
        listKey: const ValueKey('display-mode-list'),
        field: current == null
            ? const SizedBox(height: 36)
            : _ModeLine(current, field: true),
        groups: () => [
          DropDownGroup(null, [
            for (final m in modes)
              DropDownChoice(
                value: m,
                current: m.current,
                build: (_) => _ModeLine(m),
              ),
          ]),
        ],
        onChoose: onChoose,
      ),
    );
  }
}

/// `3840 x 2160 at 60 Hz`, then `4K, recommended` dim.
class _ModeLine extends StatelessWidget {
  const _ModeLine(this.mode, {this.field = false});

  final DisplayMode mode;

  /// In the closed field (else a line of the list).
  final bool field;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final style = field
        ? t.label
        : t.body.copyWith(
            fontWeight: mode.current ? FontWeight.w700 : FontWeight.w400,
          );
    // The mode first; the name gives way on a narrow line.
    return Row(
      children: [
        Text(mode.label, maxLines: 1, style: style),
        const SizedBox(width: HinterTokens.s2),
        Expanded(
          child: Text(
            [mode.name, if (mode.preferred) 'recommended'].join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: t.bodyDim,
          ),
        ),
      ],
    );
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
class SafePreview extends StatelessWidget {
  const SafePreview({super.key});

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
        Text('The old setting comes back in $_left seconds.', style: t.bodyDim),
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
                          'The red line must show on all four sides. If it '
                          'is cut off, set the TV picture size to "Just '
                          'scan", "Screen fit" or "1:1".',
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
  String? _note;
  int _inFlight = 0;
  StreamSubscription<AudioState>? _sub;

  DisplayAudioRepository get _da => widget.env.services.displayAudio;

  @override
  void initState() {
    super.initState();
    widget.env.region.interceptMove = _onMove;
    // `audio_changed`: changes made elsewhere (a controller, a headset that
    // connects). While our own change is on its way, its echo is not shown.
    _sub = _da.audioChanges.listen((a) {
      if (mounted && _inFlight == 0 && _audio != null) {
        setState(() => _audio = a);
      }
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (widget.env.region.interceptMove == _onMove) {
      widget.env.region.interceptMove = null;
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await _da.audio();
      if (mounted) {
        setState(() {
          _audio = a;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Runs a change; a refusal shows as a line above the controls.
  Future<void> _change(Future<void> Function() f) async {
    _inFlight++;
    try {
      await f();
      if (mounted) setState(() => _note = null);
    } on SystemException catch (e) {
      if (mounted) setState(() => _note = e.message);
    } finally {
      _inFlight--;
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
    unawaited(_change(() => _da.setVolume(v)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    if (_error != null) {
      return (Pane(widget.env.region)
            ..add(StatusLine(describeError(_error!), error: true))
            ..buttons('retry', [
              btn('Try again', () {
                setState(() => _error = null);
                unawaited(_load());
              }),
            ]))
          .build();
    }
    final a = _audio;
    if (a == null) {
      widget.env.region.setRows(const []);
      return const StatusLine('Loading...');
    }
    final p = Pane(widget.env.region);
    if (_note != null) p.add(StatusLine(_note!, error: true));
    p.item(
      'volume',
      onSelect: () async {
        await _change(() => _da.setMuted(!a.muted));
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
    if (a.outputs.isEmpty) {
      p.add(Text('No sound devices found.', style: t.bodyDim));
    }
    for (var i = 0; i < a.outputs.length; i++) {
      final o = a.outputs[i];
      p.item(
        'o$i',
        onSelect: () async {
          await _change(() => _da.setAudioOutput(o.id));
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
    return Loaded<Set<PowerAction>>(
      region: env.region,
      load: sys.powerAllowed,
      builder: (context, allowed, reload) {
        final p = Pane(env.region);
        Future<void> run(PowerAction a) async {
          try {
            if (a == PowerAction.sleep) {
              await sys.power(a);
            } else {
              // The session ends with the box: no connection error.
              await endSessionWith(context, powerEnding(a), () => sys.power(a));
            }
          } on SystemException catch (e) {
            if (context.mounted) {
              await showMessage(
                context,
                title: refusalTitle(e),
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

        void row(
          String key,
          PowerAction a,
          String title,
          String? subtitle,
          String? ask,
        ) {
          final ok = allowed.contains(a);
          p.item(
            key,
            onSelect: () async {
              if (!ok) {
                await showMessage(
                  context,
                  title: "Can't ${a.label.toLowerCase()}",
                  body: "This box doesn't let HinterOS do that.",
                );
              } else if (ask == null) {
                await run(a);
              } else {
                await confirm(a, ask);
              }
            },
            builder: (f) => SettingRow(
              title: title,
              subtitle: ok ? subtitle : "Not allowed on this box",
              focused: f,
              dim: !ok,
            ),
          );
        }

        row('sleep', PowerAction.sleep, 'Sleep', null, null);
        row(
          'restart',
          PowerAction.restart,
          'Restart',
          null,
          'All running apps close.',
        );
        row(
          'shutdown',
          PowerAction.shutdown,
          'Shut down',
          null,
          'All running apps close.',
        );
        return p.build();
      },
    );
  }
}

// ------------------------------------------------------------------ apps open at once

/// How many apps can run at once (session API 0.18 `apps.displays.*`), for
/// this profile. The session makes one display per app when it starts, so a
/// change applies after a session restart, which the section offers.
class AppDisplaysSection extends StatelessWidget {
  const AppDisplaysSection(this.env, {super.key});

  final SectionEnv env;

  static String _label(int n) => n == 1 ? '1 app' : '$n apps';

  @override
  Widget build(BuildContext context) {
    final sys = env.services.system;
    return Loaded<AppDisplaySetting>(
      region: env.region,
      load: sys.appDisplays,
      builder: (context, s, reload) {
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        if (s.active == null) {
          p.add(const StatusLine('Not available on this box.'));
          return p.build();
        }
        p.row(
          'count',
          1,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DropDown<int>(
              region: env.region,
              rowKey: 'count',
              listKey: const ValueKey('app-displays-list'),
              field: Text(_label(s.count), style: t.label),
              groups: () => [
                DropDownGroup(null, [
                  for (var n = s.min; n <= s.max; n++)
                    DropDownChoice(
                      value: n,
                      current: n == s.count,
                      build: (_) => Text(_label(n), style: t.label),
                    ),
                ]),
              ],
              onChoose: (n) => unawaited(_set(context, n, reload)),
            ),
          ),
        );
        if (s.restartNeeded) {
          p.add(
            const StatusLine('Restart the session to apply this.'),
            gap: HinterTokens.s2,
          );
          p.buttons('restart', [
            btn('Restart session', () => unawaited(_restart(context))),
          ]);
        }
        return p.build();
      },
    );
  }

  Future<void> _set(
    BuildContext context,
    int count,
    Future<void> Function() reload,
  ) async {
    final AppDisplaySetting s;
    try {
      s = await env.services.system.setAppDisplays(count);
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
      return;
    }
    await reload();
    if (!s.restartNeeded || !context.mounted) return;
    final r = await showConfirm(
      context,
      title: 'Restart the session now?',
      body: 'All running apps close.',
      confirmLabel: 'Restart',
      cancelLabel: 'Later',
    );
    if (r != null && context.mounted) await _restart(context);
  }

  Future<void> _restart(BuildContext context) async {
    try {
      await endSessionWith(
        context,
        const SessionEnding(title: 'Restarting the session...'),
        env.services.system.restartSession,
      );
    } on SystemException catch (e) {
      if (context.mounted) {
        await showMessage(context, title: refusalTitle(e), body: e.message);
      }
    }
  }
}
