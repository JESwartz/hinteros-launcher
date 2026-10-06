import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'nav_focusable.dart';

/// Top bar: wordmark, section tabs, clock. The tabs are one wrapping row in
/// [region]; focusing a tab selects its section (like console UIs).
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.region,
    required this.labels,
    required this.selected,
    required this.onFocusTab,
    required this.time,
  });

  final NavRegion region;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onFocusTab;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HinterTokens.margin,
        HinterTokens.s4,
        HinterTokens.margin,
        HinterTokens.s2,
      ),
      child: Row(
        children: [
          // The wordmark makes way for the tabs at large text sizes.
          if (MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
            Text(
              'HinterOS',
              style: t.label.copyWith(color: t.accent, letterSpacing: 1),
            ),
            const SizedBox(width: HinterTokens.s6),
          ],
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: HinterTokens.s2),
            NavFocusable(
              region: region,
              rowKey: 'tabs',
              col: i,
              onFocused: () => onFocusTab(i),
              scrollIntoView: false,
              builder: (context, focused) => _Tab(
                label: labels[i],
                selected: i == selected,
                focused: focused,
              ),
            ),
          ],
          const Spacer(),
          Text('$hh:$mm', style: t.title.copyWith(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.focused,
  });

  final String label;
  final bool selected;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusPill,
      scale: 1.05,
      // The bar style would collide with the selected-tab bar.
      style: t.focusStyle == FocusStyle.bar ? FocusStyle.ring : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HinterTokens.s3,
          vertical: HinterTokens.s1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: t.label.copyWith(
                color: selected ? t.text : t.textDim,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            // Selected marker: a bar under the label (shape, not only colour).
            AnimatedContainer(
              duration: t.fast,
              height: 6,
              width: selected ? 48 : 0,
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
