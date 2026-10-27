import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../focus_frame.dart';
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../pages.dart';
import '../widgets.dart';
import 'common.dart';

// Settings > Controller (session API 0.20): which button does which action,
// the pointer of pointer apps, the keys of keyboard-mode apps (all of them,
// and per app). A button is set by pressing it (`input.capture`). Every
// change is stored at once; the sections follow each other's changes.

/// [Loaded] for the controller state, following every change.
Widget _loaded(
  SectionEnv env,
  Widget Function(BuildContext context, ControllerState s) builder,
) {
  final repo = env.services.controller;
  return Loaded<ControllerState>(
    region: env.region,
    load: repo.get,
    updates: [
      repo.changes.map(
        (s) =>
            (_) => s,
      ),
    ],
    builder: (context, s, _) => builder(context, s),
  );
}

/// Stores [settings]; a refusal is shown.
Future<void> _save(
  BuildContext context,
  ControllerRepository repo,
  StoredController settings,
) async {
  try {
    await repo.set(settings);
  } on SystemException catch (e) {
    if (context.mounted) {
      await showMessage(context, title: refusalTitle(e), body: e.message);
    }
  }
}

/// "Press a button" while `input.capture` waits: the button pressed (a
/// button id or a direction), or null (Guide, no press in time, Cancel).
Future<String?> captureButton(
  BuildContext context,
  ControllerRepository repo,
  String what,
) async {
  final open = ModalScope.of(context)
      .open<String>((c, m) => _PressPrompt(modal: m, what: what));
  Object? error;
  unawaited(
    repo.capture().then(
      open.handle.close,
      onError: (Object e) {
        error = e;
        open.handle.close();
      },
    ),
  );
  final b = await open.result;
  if (error != null && context.mounted) {
    await showMessage(
      context,
      title: "That didn't work",
      body: describeError(error!),
    );
  }
  return b;
}

class _PressPrompt extends StatelessWidget {
  const _PressPrompt({required this.modal, required this.what});

  final ModalHandle<String> modal;
  final String what;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    modal.region.setRows(const [NavRow('cancel', 1)]);
    return DialogCard(
      title: 'Press a button',
      maxWidth: 760,
      children: [
        Text(what, style: t.bodyDim),
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: modal.region,
          rowKey: 'cancel',
          buttons: [btn('Cancel', modal.close)],
        ),
      ],
    );
  }
}

void _resetRow(Pane p, bool changed, VoidCallback onSelect) => p.item(
  'reset',
  onSelect: onSelect,
  builder: (f) =>
      SettingRow(title: 'Reset to defaults', focused: f, dim: !changed),
  gap: HinterTokens.s3,
);

Widget _value(BuildContext context, String text) =>
    Text(text, style: HinterTheme.of(context).label);

// ------------------------------------------------------------------ buttons

/// One row per action with its button. Select, then press the new button;
/// the action that had it gets the old one.
class ButtonsSection extends StatelessWidget {
  const ButtonsSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) => _loaded(env, (context, s) {
    final repo = env.services.controller;
    final p = Pane(env.region);
    final map = s.buttonMap;
    for (final a in s.actions) {
      p.item(
        'b-$a',
        onSelect: () => unawaited(_assign(context, s, a)),
        builder: (f) => SettingRow(
          title: actionLabel(a),
          focused: f,
          trailing: _value(context, buttonLabel(map[a] ?? '')),
        ),
      );
    }
    _resetRow(
      p,
      s.buttonsChanged,
      () => unawaited(_save(context, repo, s.withoutButtons())),
    );
    return p.build();
  });

  Future<void> _assign(
    BuildContext context,
    ControllerState s,
    String a,
  ) async {
    final repo = env.services.controller;
    final b = await captureButton(context, repo, actionLabel(a));
    if (b == null || !s.buttons.contains(b) || s.buttonMap[a] == b) return;
    if (context.mounted) await _save(context, repo, s.withButton(a, b));
  }
}

// ------------------------------------------------------------------ pointer

/// Speed (left and right), swap sticks, the two click buttons (press to
/// set; the same button as the other click swaps them).
class PointerSection extends StatefulWidget {
  const PointerSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<PointerSection> createState() => _PointerSectionState();
}

class _PointerSectionState extends State<PointerSection> {
  ControllerState? _state;
  Object? _error;

  /// The speed shown while changes are on their way.
  int? _speed;
  int _inFlight = 0;
  StreamSubscription<ControllerState>? _sub;

  ControllerRepository get _repo => widget.env.services.controller;
  NavRegion get _region => widget.env.region;

  @override
  void initState() {
    super.initState();
    _region.interceptMove = _onMove;
    _sub = _repo.changes.listen((s) {
      if (mounted && _state != null) setState(() => _state = s);
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_region.interceptMove == _onMove) _region.interceptMove = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.get();
      if (mounted) {
        setState(() {
          _state = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Left and right on the speed row change the speed.
  bool _onMove(NavDir dir) {
    final s = _state;
    if (s == null || _region.model.currentRow?.key != 'speed') return false;
    if (dir != NavDir.left && dir != NavDir.right) return false;
    final now = _speed ?? s.speed;
    final next = (now + (dir == NavDir.right ? s.speedStep : -s.speedStep))
        .clamp(s.speedMin, s.speedMax);
    if (next == now) return true;
    setState(() => _speed = next);
    unawaited(_setSpeed(s, next));
    return true;
  }

  Future<void> _setSpeed(ControllerState s, int speed) async {
    _inFlight++;
    try {
      await _save(context, _repo, s.withSpeed(speed));
    } finally {
      _inFlight--;
      if (_inFlight == 0 && mounted) setState(() => _speed = null);
    }
  }

  Future<void> _click(ControllerState s, {required bool left}) async {
    final b = await captureButton(
      context,
      _repo,
      left ? 'Left click' : 'Right click',
    );
    if (b == null || !s.buttons.contains(b)) return;
    if (b == (left ? s.leftClick : s.rightClick)) return;
    if (mounted) {
      await _save(context, _repo, s.withClick(left: left, button: b));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    if (_error != null) {
      return (Pane(_region)
            ..add(StatusLine(describeError(_error!), error: true))
            ..buttons('retry', [
              btn('Try again', () {
                setState(() => _error = null);
                unawaited(_load());
              }),
            ]))
          .build();
    }
    final s = _state;
    if (s == null) {
      _region.setRows(const []);
      return const StatusLine('Loading...');
    }
    final speed = _speed ?? s.speed;
    final p = Pane(_region);
    p.item(
      'speed',
      onSelect: null,
      builder: (f) => SettingRow(
        title: 'Speed',
        subtitle: 'Left and right change it.',
        focused: f,
        trailing: SizedBox(
          width: 420,
          child: Row(
            children: [
              Expanded(
                child: HBar(
                  fraction: s.speedMax == s.speedMin
                      ? 1
                      : (speed - s.speedMin) / (s.speedMax - s.speedMin),
                ),
              ),
              const SizedBox(width: HinterTokens.s2),
              SizedBox(
                width: 110,
                child: Text(
                  '$speed%',
                  textAlign: TextAlign.right,
                  style: t.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    p.item(
      'swap',
      onSelect: () =>
          unawaited(_save(context, _repo, s.withSwapSticks(!s.swapSticks))),
      builder: (f) => SettingRow(
        title: 'Swap sticks',
        focused: f,
        trailing: ToggleMark(on: s.swapSticks),
      ),
    );
    p.item(
      'left_click',
      onSelect: () => unawaited(_click(s, left: true)),
      builder: (f) => SettingRow(
        title: 'Left click',
        focused: f,
        trailing: _value(context, buttonLabel(s.leftClick)),
      ),
    );
    p.item(
      'right_click',
      onSelect: () => unawaited(_click(s, left: false)),
      builder: (f) => SettingRow(
        title: 'Right click',
        focused: f,
        trailing: _value(context, buttonLabel(s.rightClick)),
      ),
    );
    _resetRow(
      p,
      s.pointerChanged,
      () => unawaited(_save(context, _repo, s.withoutPointer())),
    );
    return p.build();
  }
}

// ------------------------------------------------------------------ keys

/// The row of a keymap action: the button that does it and the action
/// ("A (Accept)"), or the direction ("Up").
String keyActionTitle(ControllerState s, String action) {
  final b = s.buttonMap[action];
  return b == null
      ? actionLabel(action)
      : '${buttonLabel(b)} (${actionLabel(action)})';
}

/// One row per keymap action with its key, for every keyboard app (no
/// [appId]) or for app [appId].
void _keyRows(
  BuildContext context,
  Pane p,
  ControllerState s,
  ControllerRepository repo, {
  String? appId,
}) {
  for (final a in s.keyActions) {
    final title = keyActionTitle(s, a);
    final key = s.keyOf(a, appId);
    p.item(
      'k-$a',
      onSelect: () async {
        final k = await showKeyPicker(context, s, title: title, current: key);
        if (k == null || k == key || !context.mounted) return;
        await _save(context, repo, s.withKey(a, k, appId: appId));
      },
      builder: (f) => SettingRow(
        title: title,
        focused: f,
        trailing: _value(context, keyLabel(key)),
      ),
    );
  }
}

/// The keys of every keyboard-mode app.
class KeyboardKeysSection extends StatelessWidget {
  const KeyboardKeysSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) => _loaded(env, (context, s) {
    final repo = env.services.controller;
    final p = Pane(env.region);
    _keyRows(context, p, s, repo);
    _resetRow(
      p,
      s.keysChanged,
      () => unawaited(_save(context, repo, s.withoutKeys())),
    );
    return p.build();
  });
}

/// The keyboard-mode apps; each opens a page with its own keys.
class AppKeysSection extends StatelessWidget {
  const AppKeysSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) => _loaded(env, (context, s) {
    final t = HinterTheme.of(context);
    final p = Pane(env.region);
    if (s.apps.isEmpty) {
      p.add(const StatusLine('No keyboard apps.'));
    }
    for (final a in s.apps) {
      p.item(
        'app-${a.id}',
        onSelect: () => unawaited(
          ModalScope.of(context).show<void>(
            (c, m) => _AppKeysPage(
              modal: m,
              repo: env.services.controller,
              initial: s,
              appId: a.id,
            ),
          ),
        ),
        builder: (f) => SettingRow(
          title: a.name,
          focused: f,
          trailing: s.appChanged(a.id)
              ? Text('Changed', style: t.bodyDim)
              : null,
        ),
      );
    }
    return p.build();
  });
}

/// The keys of one app: what it gets now; a change is for this app only.
class _AppKeysPage extends StatefulWidget {
  const _AppKeysPage({
    required this.modal,
    required this.repo,
    required this.initial,
    required this.appId,
  });

  final ModalHandle<void> modal;
  final ControllerRepository repo;
  final ControllerState initial;
  final String appId;

  @override
  State<_AppKeysPage> createState() => _AppKeysPageState();
}

class _AppKeysPageState extends State<_AppKeysPage> {
  late ControllerState _s = widget.initial;
  StreamSubscription<ControllerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.repo.changes.listen((s) {
      if (mounted) setState(() => _s = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.appId;
    final p = Pane(widget.modal.region);
    _keyRows(context, p, _s, widget.repo, appId: id);
    _resetRow(
      p,
      _s.appChanged(id),
      () => unawaited(_save(context, widget.repo, _s.withoutAppKeys(id))),
    );
    p.buttons('done', [
      btn('Done', widget.modal.close, primary: true),
    ], gap: HinterTokens.s4);
    return FullPage(
      title: _s.app(id)?.name ?? id,
      child: SingleChildScrollView(child: p.build()),
    );
  }
}

// ------------------------------------------------------------------ key picker

/// Chooses a key with modifiers (or None) with the controller: the
/// modifiers as switches, then None, then every key. Null: cancelled.
Future<String?> showKeyPicker(
  BuildContext context,
  ControllerState s, {
  required String title,
  required String current,
}) => ModalScope.of(context).show<String>(
  (c, m) => _KeyPicker(modal: m, state: s, title: title, current: current),
);

class _KeyPicker extends StatefulWidget {
  const _KeyPicker({
    required this.modal,
    required this.state,
    required this.title,
    required this.current,
  });

  final ModalHandle<String> modal;
  final ControllerState state;
  final String title;
  final String current;

  @override
  State<_KeyPicker> createState() => _KeyPickerState();
}

class _KeyPickerState extends State<_KeyPicker> {
  static const _perRow = 8;

  late final (String, Set<String>) _current = splitCombo(widget.current);
  late final Set<String> _mods = widget.current == 'none'
      ? <String>{}
      : {..._current.$2};
  bool _placed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final region = widget.modal.region;
    final p = Pane(region);
    p.row(
      'mods',
      s.modifiers.length,
      Wrap(
        spacing: HinterTokens.s2,
        runSpacing: HinterTokens.s1,
        children: [
          for (var i = 0; i < s.modifiers.length; i++)
            SizedBox(
              width: 300,
              child: NavFocusable(
                region: region,
                rowKey: 'mods',
                col: i,
                onSelect: () => setState(
                  () => _mods.contains(s.modifiers[i])
                      ? _mods.remove(s.modifiers[i])
                      : _mods.add(s.modifiers[i]),
                ),
                builder: (_, f) => SettingRow(
                  title: keyLabel(s.modifiers[i]),
                  focused: f,
                  trailing: ToggleMark(on: _mods.contains(s.modifiers[i])),
                ),
              ),
            ),
        ],
      ),
    );
    p.item(
      'none',
      onSelect: () => widget.modal.close('none'),
      builder: (f) => SettingRow(title: 'None', focused: f),
      gap: HinterTokens.s3,
    );
    final keys = s.keys;
    for (var r = 0; r * _perRow < keys.length; r++) {
      final row = keys.skip(r * _perRow).take(_perRow).toList();
      p.row(
        'k$r',
        row.length,
        Row(
          children: [
            for (var c = 0; c < _perRow; c++) ...[
              if (c > 0) const SizedBox(width: HinterTokens.s1),
              Expanded(
                child: c < row.length
                    ? NavFocusable(
                        region: region,
                        rowKey: 'k$r',
                        col: c,
                        onSelect: () => widget.modal.close(
                          joinCombo(row[c], _mods, s.modifiers),
                        ),
                        builder: (_, f) => _KeyCap(
                          label: keyLabel(row[c]),
                          focused: f,
                          current:
                              widget.current != 'none' && row[c] == _current.$1,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
        gap: r == 0 ? HinterTokens.s3 : HinterTokens.s1,
      );
    }
    p.buttons('cancel', [
      btn('Cancel', widget.modal.close),
    ], gap: HinterTokens.s4);
    final pane = p.build();
    if (!_placed) {
      // Focus starts on the current key (on None when there is none). Rows:
      // modifiers, None, then the key rows.
      _placed = true;
      final i = widget.current == 'none' ? -1 : keys.indexOf(_current.$1);
      region.model.goTo(i < 0 ? 1 : 2 + i ~/ _perRow, i < 0 ? 0 : i % _perRow);
    }
    return FullPage(
      title: widget.title,
      subtitle: keyLabel(widget.current),
      child: SingleChildScrollView(child: pane),
    );
  }
}

/// A key of the picker; the current one is drawn bold with a frame.
class _KeyCap extends StatelessWidget {
  const _KeyCap({
    required this.label,
    required this.focused,
    required this.current,
  });

  final String label;
  final bool focused;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: Container(
        height: 72,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: HinterTokens.s1),
        decoration: BoxDecoration(
          color: current ? t.surfaceHigh : t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          border: current || t.highContrast
              ? Border.all(
                  color: current ? t.accent : t.textDim,
                  width: current ? 4 : 2,
                )
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: t.label.copyWith(
              fontWeight: current ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
