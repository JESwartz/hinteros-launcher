import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'nav_focusable.dart';
import 'profiles/profile_ui.dart';
import '../system/profiles.dart';
import '../system/models.dart' show JobSnapshot;
import 'jobs.dart';

/// Top bar: wordmark, section tabs, a running job, the profile chip, clock. The tabs are one wrapping row in
/// [region]; focusing a tab selects its section (like console UIs).
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.region,
    required this.labels,
    required this.selected,
    required this.onFocusTab,
    required this.time,
    this.profile,
    this.onProfile,
    this.job,
    this.jobName,
    this.onJob,
  });

  /// The job the person left running (or that ended unseen): a compact
  /// indicator before the profile chip, in the tab row; null: none.
  final JobSnapshot? job;
  final String? jobName;

  /// A on the indicator: the job's page again.
  final VoidCallback? onJob;

  /// The profile chip (colour and initial) after the tabs, as the last item
  /// of the tab row; null: no chip (no profiles on this box).
  final CurrentProfile? profile;

  /// A on the chip: the profile picker.
  final VoidCallback? onProfile;

  final NavRegion region;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onFocusTab;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    // Five tabs plus the clock: at large text sizes everything gets tighter.
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.1;
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
          // The wordmark makes way for the tabs at large text sizes, and for
          // the profile chip.
          if (MediaQuery.textScalerOf(context).scale(1) <= 1.0 &&
              labels.length <= 5 &&
              profile == null &&
              job == null) ...[
            Text(
              'HinterOS',
              style: t.label.copyWith(color: t.accent, letterSpacing: 1),
            ),
            const SizedBox(width: HinterTokens.s6),
          ],
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) SizedBox(width: big ? HinterTokens.s1 : HinterTokens.s2),
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
                compact: big,
              ),
            ),
          ],
          if (job == null)
            const Spacer()
          else ...[
            SizedBox(width: big ? HinterTokens.s2 : HinterTokens.s3),
            // Takes the room left; its text gets shorter, never the tabs.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: NavFocusable(
                  region: region,
                  rowKey: 'tabs',
                  col: labels.length,
                  onSelect: onJob,
                  scrollIntoView: false,
                  builder: (context, focused) => JobIndicator(
                    job: job!,
                    name: jobName,
                    focused: focused,
                    compact: big,
                  ),
                ),
              ),
            ),
            SizedBox(width: big ? HinterTokens.s2 : HinterTokens.s3),
          ],
          if (profile != null) ...[
            NavFocusable(
              region: region,
              rowKey: 'tabs',
              col: labels.length + (job == null ? 0 : 1),
              onSelect: onProfile,
              scrollIntoView: false,
              builder: (context, focused) =>
                  _Chip(profile: profile!, focused: focused, compact: big),
            ),
            SizedBox(width: big ? HinterTokens.s2 : HinterTokens.s3),
          ],
          Text(
            '$hh:$mm',
            style: (big ? t.label : t.title).copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// The profile chip: the profile's colour and initial (the name is in the
/// menu it opens; the bar has no room for it at large text sizes).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.profile,
    required this.focused,
    required this.compact,
  });

  final CurrentProfile profile;
  final bool focused;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusPill,
      scale: 1.05,
      style: t.focusStyle == FocusStyle.bar ? FocusStyle.ring : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              initial: profile.initial,
              color: profile.color,
              guest: profile.guest,
              size: 56,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.focused,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final bool focused;
  final bool compact;

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
        padding: EdgeInsets.symmetric(
          horizontal: compact ? HinterTokens.s2 : HinterTokens.s3,
          vertical: HinterTokens.s1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: (compact ? t.body : t.label).copyWith(
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
