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
/// new place each minute, when its time changes anyway; the logo moves a
/// few pixels four times a second. With reduce motion the logo also only
/// moves once a minute.
class ScreenSaver extends StatefulWidget {
  const ScreenSaver({super.key, required this.style, required this.time});

  final ScreenSaverStyle style;

  /// The wall clock (the top bar's time).
  final DateTime time;

  @override
  State<ScreenSaver> createState() => _ScreenSaverState();
}

class _ScreenSaverState extends State<ScreenSaver> {
  static const _step = Duration(milliseconds: 250);
  Timer? _timer;
  Duration _elapsed = Duration.zero;

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
      _timer ??= Timer.periodic(
        _step,
        (_) => setState(() => _elapsed += _step),
      );
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

  /// Where the content is, from -1 to 1 on each axis.
  Alignment _where() {
    if (!_drifts) {
      // A new place each minute.
      final m = widget.time.millisecondsSinceEpoch ~/ 60000;
      double r(int salt) {
        final x = math.sin(m * 12.9898 + salt * 78.233) * 43758.5453;
        return (x - x.floorToDouble()) * 1.6 - 0.8;
      }

      return Alignment(r(1), r(2));
    }
    // Straight lines that turn back at the edges, slowly (some pixels a
    // second on a 1080p screen).
    final s = _elapsed.inMilliseconds / 1000;
    double bounce(double period) {
      final f = (s / period) % 1;
      return f < 0.5 ? -1 + 4 * f : 3 - 4 * f;
    }

    return Alignment(bounce(360), bounce(220));
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final dim = t.text.withValues(alpha: 0.7);
    final Widget? content = switch (widget.style) {
      ScreenSaverStyle.black => null,
      ScreenSaverStyle.clock => Column(
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
    return ColoredBox(
      key: const ValueKey('screen-saver'),
      color: Colors.black,
      child: content == null
          ? const SizedBox.expand()
          : Padding(
              padding: const EdgeInsets.all(HinterTokens.s5),
              child: Align(alignment: _where(), child: content),
            ),
    );
  }
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
  });

  final NavRegion region;
  final SettingsController settings;
  final VoidCallback? onShow;

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
          values: ScreenSaverStyle.values,
          current: s.screenSaverStyle,
          labelOf: (v) => v.label,
          onChoose: (v) =>
              settings.update(settings.value.copyWith(screenSaverStyle: v)),
        ),
      );
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
