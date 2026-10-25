import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'nav_focusable.dart';

/// A pill button: focus shown by [FocusFrame]. A disabled button stays
/// focusable (so the user can see what it is and why) but dimmed, dashed and
/// inert: the caller ignores accept.
class HButton extends StatelessWidget {
  const HButton({
    super.key,
    required this.label,
    required this.focused,
    this.primary = false,
    this.enabled = true,
    this.danger = false,
  });

  final String label;
  final bool focused;
  final bool primary;
  final bool enabled;

  /// A destructive action: outlined in the danger colour.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final fill = !enabled
        ? t.surface
        : primary
        ? (danger ? t.danger : t.accent)
        : t.surface;
    final fg = !enabled
        ? t.textDim.withValues(alpha: 0.6)
        : primary
        ? t.onAccent
        : (danger ? t.danger : t.text);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusPill,
      scale: 1.05,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: primary && enabled
              ? null
              : Border.all(
                  color: enabled
                      ? (danger ? t.danger : t.textDim)
                      : t.textDim.withValues(alpha: 0.5),
                  width: 2,
                ),
          borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s4,
            vertical: HinterTokens.s1 + 4,
          ),
          child: Text(label, maxLines: 1, style: t.label.copyWith(color: fg)),
        ),
      ),
    );
  }
}

/// A row of a settings list: title, optional second line, something on the
/// right. Focus is drawn around it.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.focused,
    this.subtitle,
    this.trailing,
    this.leading,
    this.danger = false,
    this.dim = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final bool focused;
  final bool danger;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          border: t.highContrast
              ? Border.all(color: t.textDim, width: 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: HinterTokens.s2),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.label.copyWith(
                        color: danger
                            ? t.danger
                            : dim
                            ? t.textDim
                            : t.text,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null) Text(subtitle!, style: t.caption),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: HinterTokens.s2),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// On/off shown as a switch plus the word, so it never relies on colour. A
/// [locked] one (cannot be changed) is drawn faded. [note] goes left of the
/// switch, so the switches of a list stay in line.
class ToggleMark extends StatelessWidget {
  const ToggleMark({
    super.key,
    required this.on,
    this.label,
    this.note,
    this.locked = false,
  });

  final bool on;
  final String? label;
  final String? note;
  final bool locked;

  static double _offWidth(BuildContext context, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: 'Off', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = p.width;
    p.dispose();
    return w.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final knob = Container(
      width: 64,
      height: 36,
      padding: const EdgeInsets.all(4),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? t.accent : t.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on ? t.accent : t.textDim, width: 2),
      ),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: on ? t.onAccent : t.textDim,
          shape: BoxShape.circle,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null) ...[
          Text(note!, style: t.bodyDim),
          const SizedBox(width: HinterTokens.s1),
        ],
        if (locked) Opacity(opacity: 0.5, child: knob) else knob,
        const SizedBox(width: HinterTokens.s1),
        if (label != null)
          Text(label!, style: t.bodyDim)
        else
          // As wide as "Off" both ways, so the switch does not move.
          SizedBox(
            width: _offWidth(context, t.bodyDim),
            child: Text(on ? 'On' : 'Off', style: t.bodyDim),
          ),
      ],
    );
  }
}

/// A square check box with a drawn tick.
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.checked, this.size = 36});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _CheckPainter(checked, t.text, t.accent, t.onAccent),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.checked, this.line, this.fill, this.tick);

  final bool checked;
  final Color line;
  final Color fill;
  final Color tick;

  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & s,
      Radius.circular(s.width * 0.2),
    );
    if (checked) canvas.drawRRect(r, Paint()..color = fill);
    canvas.drawRRect(
      r.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = checked ? fill : line,
    );
    if (checked) {
      final p = Path()
        ..moveTo(s.width * 0.22, s.height * 0.52)
        ..lineTo(s.width * 0.43, s.height * 0.72)
        ..lineTo(s.width * 0.78, s.height * 0.30);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = tick,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter o) =>
      o.checked != checked || o.line != line || o.fill != fill;
}

/// Wi-Fi signal: four bars of rising height.
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return CustomPaint(
      size: const Size(44, 36),
      painter: _BarsPainter(bars, t.text, t.textDim.withValues(alpha: 0.45)),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.bars, this.on, this.off);

  final int bars;
  final Color on;
  final Color off;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width / 7;
    for (var i = 0; i < 4; i++) {
      final h = s.height * (0.3 + 0.7 * (i + 1) / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 2 * w, s.height - h, w * 1.4, h),
          const Radius.circular(2),
        ),
        Paint()..color = i < bars ? on : off,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.bars != bars || o.on != on;
}

/// A padlock, drawn.
class LockMark extends StatelessWidget {
  const LockMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _LockPainter(HinterTheme.of(context).text),
  );
}

class _LockPainter extends CustomPainter {
  _LockPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.11
      ..color = color;
    canvas.drawArc(
      Rect.fromLTWH(
        s.width * 0.26,
        s.height * 0.06,
        s.width * 0.48,
        s.height * 0.56,
      ),
      3.14159,
      3.14159,
      false,
      stroke,
    );
    canvas.drawLine(
      Offset(s.width * 0.26, s.height * 0.34),
      Offset(s.width * 0.26, s.height * 0.5),
      stroke,
    );
    canvas.drawLine(
      Offset(s.width * 0.74, s.height * 0.34),
      Offset(s.width * 0.74, s.height * 0.5),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * 0.14,
          s.height * 0.46,
          s.width * 0.72,
          s.height * 0.48,
        ),
        Radius.circular(s.width * 0.1),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_LockPainter o) => o.color != color;
}

/// A horizontal bar, filled to [fraction] (0..1), or an indeterminate stripe
/// when [fraction] is null.
class HBar extends StatelessWidget {
  const HBar({super.key, required this.fraction, this.height = 20});

  final double? fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final f = fraction;
        return Container(
          height: height,
          width: c.maxWidth,
          decoration: BoxDecoration(
            color: t.surfaceHigh,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: t.textDim, width: 2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            // Without a percentage a short stripe in the middle says "working".
            widthFactor: f == null ? 0.25 : f.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: SizedBox(height: height),
            ),
          ),
        );
      },
    );
  }
}

/// Collects the focusable rows and the other widgets of one settings pane, in
/// order, and hands the rows to the pane's [NavRegion]. Build a pane, add to
/// it, then use [build].
class Pane {
  Pane(this.region);

  final NavRegion region;
  final _children = <Widget>[];
  final _rows = <NavRow>[];

  /// A non-focusable widget (heading, explanation).
  void add(Widget w, {double gap = HinterTokens.s2}) {
    if (_children.isNotEmpty) _children.add(SizedBox(height: gap));
    _children.add(w);
  }

  /// One focusable row of one item.
  void item(
    String key, {
    required VoidCallback? onSelect,
    VoidCallback? onContext,
    required Widget Function(bool focused) builder,
    double gap = HinterTokens.s1 + 4,
  }) {
    _rows.add(NavRow(key, 1));
    add(
      NavFocusable(
        region: region,
        rowKey: key,
        col: 0,
        onSelect: onSelect,
        onContext: onContext,
        builder: (_, f) => builder(f),
      ),
      gap: gap,
    );
  }

  /// One row of buttons, side by side.
  void buttons(
    String key,
    List<
      ({
        String label,
        VoidCallback? onSelect,
        bool primary,
        bool enabled,
        bool danger,
      })
    >
    buttons, {
    double gap = HinterTokens.s2,
  }) {
    _rows.add(NavRow(key, buttons.length));
    add(
      Wrap(
        spacing: HinterTokens.s2,
        runSpacing: HinterTokens.s1,
        children: [
          for (var i = 0; i < buttons.length; i++)
            NavFocusable(
              region: region,
              rowKey: key,
              col: i,
              onSelect: buttons[i].enabled ? buttons[i].onSelect : null,
              builder: (_, f) => HButton(
                label: buttons[i].label,
                focused: f,
                primary: buttons[i].primary,
                enabled: buttons[i].enabled,
                danger: buttons[i].danger,
              ),
            ),
        ],
      ),
      gap: gap,
    );
  }

  /// A row of [count] items that [child] builds itself (its own
  /// [NavFocusable]s at `key:0` .. `key:count-1`).
  void row(
    String key,
    int count,
    Widget child, {
    double gap = HinterTokens.s2,
  }) {
    _rows.add(NavRow(key, count));
    add(child, gap: gap);
  }

  /// Hands the rows to the region and returns the content.
  Widget build() {
    region.setRows(_rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _children,
    );
  }
}

/// Shorthand for a button spec of [Pane.buttons].
({
  String label,
  VoidCallback? onSelect,
  bool primary,
  bool enabled,
  bool danger,
})
btn(
  String label,
  VoidCallback? onSelect, {
  bool primary = false,
  bool enabled = true,
  bool danger = false,
}) => (
  label: label,
  onSelect: onSelect,
  primary: primary,
  enabled: enabled,
  danger: danger,
);

/// A short line under a heading in a pane.
class PaneHeading extends StatelessWidget {
  const PaneHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: HinterTheme.of(context).title);
}

/// A small spinning ring: something is being worked on.
class Spinner extends StatefulWidget {
  const Spinner({super.key, this.size = 22});

  final double size;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion: a still ring, the words say what is going on.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = HinterTheme.of(context).accent;
    return SizedBox(
      key: const ValueKey('spinner'),
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _turn,
        child: CustomPaint(painter: _RingPainter(color)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      r.deflate(2),
      0,
      6.2832,
      false,
      paint..color = color.withValues(alpha: 0.25),
    );
    canvas.drawArc(r.deflate(2), -1.5708, 4.2, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

/// A status message in a pane: a mark that is not just colour, and text.
class StatusLine extends StatelessWidget {
  const StatusLine(
    this.text, {
    super.key,
    this.error = false,
    this.ok = false,
    this.busy = false,
  });

  final String text;

  /// Still working: a spinner instead of the mark.
  final bool busy;
  final bool error;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    if (busy) {
      return Row(
        children: [
          const SizedBox(width: 40, child: Center(child: Spinner())),
          const SizedBox(width: HinterTokens.s2),
          Expanded(child: Text(text, style: t.bodyDim)),
        ],
      );
    }
    final mark = error ? '!' : (ok ? 'OK' : 'i');
    final color = error
        ? t.danger
        : ok
        ? t.positive
        : t.textDim;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
          ),
          child: Text(
            mark,
            textAlign: TextAlign.center,
            style: t.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: HinterTokens.s2),
        Expanded(child: Text(text, style: t.bodyDim)),
      ],
    );
  }
}

/// The "DEV" badge of a developer build (`system.info.dev`): letters, not
/// just colour.
class DevBadge extends StatelessWidget {
  const DevBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
      ),
      child: Text(
        'DEV',
        style: t.caption.copyWith(
          color: t.onAccent,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
