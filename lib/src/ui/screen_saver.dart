/// The screen saver: after some minutes without input on the launcher (Settings
/// > Display and sound > Screen saver), a black screen with the clock, the
/// HinterOS name or nothing on it. Only over the launcher: an app or game in
/// front (a film, a paused game) never gets it. The first press only closes
/// it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api.dart' show NavAction, NavPhase;
import '../nav/nav_controller.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import 'drop_down.dart';
import 'widgets.dart' show Pane, btn;

/// When the screen saver shows. The shell gives it all input first.
class ScreenSaverController extends ChangeNotifier {
  ScreenSaverController(this._settings) {
    _settings.addListener(_restart);
  }

  final SettingsController _settings;

  /// Brings Steam forward as the screen saver ([ScreenSaverStyle.steam]);
  /// false when it cannot (the clock then).
  Future<bool> Function()? startSteam;

  Timer? _timer;
  bool _allowed = false;
  bool _showing = false;

  /// The press that closed the screen saver: its repeats and its release go
  /// nowhere.
  NavAction? _eating;

  bool get showing => _showing;

  /// The launcher is in front and nothing else has the screen (loading, the
  /// on-screen keyboard, the session ending). False also closes it.
  set allowed(bool value) {
    if (value == _allowed) return;
    _allowed = value;
    if (!value) _hide();
    _restart();
  }

  /// Show it now (Settings: Show now).
  void show() {
    if (_showing) return;
    _timer?.cancel();
    final steam = startSteam;
    if (_settings.value.screenSaverStyle == ScreenSaverStyle.steam &&
        steam != null) {
      // Steam takes the screen: the launcher is no longer in front, so the
      // wait starts again when it is.
      unawaited(
        steam().then((ok) {
          if (!ok && _allowed && !_showing) {
            _showing = true;
            notifyListeners();
          }
        }),
      );
      return;
    }
    _showing = true;
    notifyListeners();
  }

  /// A controller or keyboard action. True: it closed the screen saver or
  /// belongs to the press that did, and goes no further.
  bool input(NavAction action, NavPhase phase) {
    if (_showing) {
      if (phase == NavPhase.press) {
        _eating = action;
        wake();
      }
      return true;
    }
    if (_eating == action) {
      if (phase == NavPhase.release) _eating = null;
      if (phase != NavPhase.press) return true;
      _eating = null;
    }
    _restart();
    return false;
  }

  /// Other input (Home, a typed letter): closes the screen saver (true) or
  /// starts the wait again.
  bool wake() {
    final was = _showing;
    _hide();
    _restart();
    return was;
  }

  void _hide() {
    if (!_showing) return;
    _showing = false;
    notifyListeners();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final minutes = _settings.value.screenSaverMinutes;
    if (!_allowed || _showing || minutes <= 0) return;
    _timer = Timer(Duration(minutes: minutes), show);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settings.removeListener(_restart);
    super.dispose();
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The screen saver itself, over the whole screen. What is on it moves so
/// that nothing stays on the same pixels, but it draws few frames: a frame
/// costs the box's CPU as much as any animation (Xwayland and gamescope
/// included), and the screen saver can be up for hours. The clock goes to a
/// new place each minute, when its time changes anyway, with a short fade.
/// The logo moves one screen pixel on each axis eight times a second: steps
/// that small look like smooth motion, at an eighth of the frames of a
/// normal animation (bigger steps less often looked jerky). With reduce
/// motion the logo also only moves once a minute, and nothing fades.
class ScreenSaver extends StatefulWidget {
  const ScreenSaver({super.key, required this.style, required this.time});

  final ScreenSaverStyle style;

  /// The wall clock (the top bar's time).
  final DateTime time;

  @override
  State<ScreenSaver> createState() => _ScreenSaverState();
}

class _ScreenSaverState extends State<ScreenSaver> {
  /// One physical pixel per axis per step: 8 pixels a second.
  static const _step = Duration(milliseconds: 125);
  static const _fade = Duration(milliseconds: 500);
  Timer? _timer;
  int _steps = 0;

  bool get _drifts =>
      widget.style == ScreenSaverStyle.logo &&
      !HinterTheme.of(context).reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScreenSaver old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_drifts) {
      _timer ??= Timer.periodic(_step, (_) => setState(() => _steps++));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _minute => widget.time.millisecondsSinceEpoch ~/ 60000;

  /// Where the content is when it does not drift: a new place each minute,
  /// from -0.8 to 0.8 on each axis.
  Alignment _place() {
    final m = _minute;
    double r(int salt) {
      final x = math.sin(m * 12.9898 + salt * 78.233) * 43758.5453;
      return (x - x.floorToDouble()) * 1.6 - 0.8;
    }

    return Alignment(r(1), r(2));
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final dim = t.text.withValues(alpha: 0.7);
    final Widget? content = switch (widget.style) {
      ScreenSaverStyle.black => null,
      // Steam could not come forward.
      ScreenSaverStyle.clock || ScreenSaverStyle.steam => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.time.hour.toString().padLeft(2, '0')}:'
            '${widget.time.minute.toString().padLeft(2, '0')}',
            style: t.headline.copyWith(fontSize: 160, height: 1, color: dim),
          ),
          const SizedBox(height: HinterTokens.s2),
          Text(
            '${_weekdays[widget.time.weekday - 1]} ${widget.time.day} '
            '${_months[widget.time.month - 1]}',
            style: t.title.copyWith(color: dim),
          ),
        ],
      ),
      ScreenSaverStyle.logo => Text(
        'HinterOS',
        style: t.headline.copyWith(fontSize: 96, color: t.accent),
      ),
    };
    final Widget? placed = switch (content) {
      null => null,
      // Drawn once; each step only moves the layer.
      final c when _drifts => CustomSingleChildLayout(
        delegate: _Drift(_steps, MediaQuery.devicePixelRatioOf(context)),
        child: RepaintBoundary(child: c),
      ),
      final c => AnimatedSwitcher(
        duration: t.reduceMotion ? Duration.zero : _fade,
        child: Align(key: ValueKey(_minute), alignment: _place(), child: c),
      ),
    };
    return ColoredBox(
      key: const ValueKey('screen-saver'),
      color: Colors.black,
      child: placed == null
          ? const SizedBox.expand()
          : Padding(
              padding: const EdgeInsets.all(HinterTokens.s5),
              child: placed,
            ),
    );
  }
}

/// The drifting logo's place after [steps]: straight lines at 45 degrees that
/// turn back at the edges, one physical pixel per axis per step, always on
/// whole pixels.
class _Drift extends SingleChildLayoutDelegate {
  _Drift(this.steps, this.dpr);

  final int steps;
  final double dpr;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 0..max..0 in physical pixels, starting part of the way along.
    double axis(double room, double start) {
      final max = (math.max(0, room) * dpr).floor();
      if (max == 0) return 0;
      final p = (steps + (max * start).floor()) % (2 * max);
      return (p <= max ? p : 2 * max - p) / dpr;
    }

    return Offset(
      axis(size.width - childSize.width, 0.5),
      axis(size.height - childSize.height, 0.3),
    );
  }

  @override
  bool shouldRelayout(_Drift old) => old.steps != steps || old.dpr != dpr;
}

String _minutesLabel(int m) => switch (m) {
  0 => 'Off',
  1 => '1 minute',
  _ => '$m minutes',
};

/// Settings > Display and sound > Screen saver: when it starts, what it
/// shows, and Show now.
class ScreenSaverSection extends StatelessWidget {
  const ScreenSaverSection({
    super.key,
    required this.region,
    required this.settings,
    required this.onShow,
    this.steamInstalled = false,
  });

  final NavRegion region;
  final SettingsController settings;
  final VoidCallback? onShow;

  /// Steam is installed: its screen saver is a choice.
  final bool steamInstalled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final t = HinterTheme.of(context);
      final s = settings.value;
      final p = Pane(region);
      p.add(Text('Start after', style: t.label));
      p.row(
        'after',
        1,
        _field<int>(
          rowKey: 'after',
          label: _minutesLabel(s.screenSaverMinutes),
          values: LauncherSettings.screenSaverSteps,
          current: s.screenSaverMinutes,
          labelOf: _minutesLabel,
          onChoose: (m) =>
              settings.update(settings.value.copyWith(screenSaverMinutes: m)),
        ),
      );
      p.add(Text('Style', style: t.label), gap: HinterTokens.s3);
      p.row(
        'style',
        1,
        _field<ScreenSaverStyle>(
          rowKey: 'style',
          label: s.screenSaverStyle.label,
          values: [
            for (final v in ScreenSaverStyle.values)
              if (v != ScreenSaverStyle.steam ||
                  steamInstalled ||
                  s.screenSaverStyle == v)
                v,
          ],
          current: s.screenSaverStyle,
          labelOf: (v) => v.label,
          onChoose: (v) =>
              settings.update(settings.value.copyWith(screenSaverStyle: v)),
        ),
      );
      if (s.screenSaverStyle == ScreenSaverStyle.steam) {
        p.add(
          Text(
            'Steam waits before it shows its screen saver. '
            'Set the time in Steam: Settings > Power.',
            style: t.bodyDim,
          ),
          gap: HinterTokens.s2,
        );
      }
      p.buttons('show', [btn('Show now', onShow)], gap: HinterTokens.s3);
      return p.build();
    },
  );

  Widget _field<T>({
    required String rowKey,
    required String label,
    required List<T> values,
    required T current,
    required String Function(T) labelOf,
    required void Function(T) onChoose,
  }) => Builder(
    builder: (context) {
      final t = HinterTheme.of(context);
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DropDown<T>(
          region: region,
          rowKey: rowKey,
          listKey: ValueKey('screen-saver-$rowKey-list'),
          field: Text(label, style: t.body),
          groups: () => [
            DropDownGroup(null, [
              for (final v in values)
                DropDownChoice(
                  value: v,
                  current: v == current,
                  build: (c) => Text(labelOf(v), style: t.body),
                ),
            ]),
          ],
          onChoose: onChoose,
        ),
      );
    },
  );
}
