import 'package:flutter/material.dart';

import '../../theme/hinter_theme.dart';
import '../../ui/widgets.dart';
import '../flow.dart';
import '../progress.dart';
import 'steps.dart';

/// The install itself: the stages in plain words, a percentage, warnings,
/// and on error what it means, where the log is, and Try again / Back.
class InstallStepView extends StatelessWidget {
  const InstallStepView({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        switch (f.phase) {
          case InstallPhase.idle:
          case InstallPhase.validating:
          case InstallPhase.installing:
          case InstallPhase.succeeded:
            _running(context, f, p);
          case InstallPhase.refused:
          case InstallPhase.failed:
            _failure(context, f, p);
        }
        final title = switch (f.phase) {
          InstallPhase.refused => 'The install did not start',
          InstallPhase.failed => 'The install did not finish',
          _ => 'Installing HinterOS',
        };
        return StepPage(
          step: InstallerStep.install,
          title: title,
          subtitle: f.running ? 'Do not turn off the computer.' : null,
          child: scrolling(DefaultTextStyle(style: t.body, child: p.build())),
        );
      },
    );
  }

  void _running(BuildContext context, InstallerFlow f, Pane p) {
    final t = HinterTheme.of(context);
    // Nothing to press while it runs: Back is off, too.
    env.region.setRows(const []);
    final inApps = f.section == InstallSection.apps;
    final current = installStages.indexOf(f.progressStage);
    // One bar for the step being worked on (a stage, or one app), not for the
    // whole chain: the steps run at very different speeds. Without a
    // measurable fraction the bar is indeterminate.
    final String caption;
    if (inApps) {
      caption = f.appsLine ?? 'Installing apps';
    } else if (current >= 0) {
      caption =
          'Step ${current + 1} of ${installStages.length} · '
          '${stageLabel(installStages[current])}';
    } else {
      caption = stageLabel(f.progressStage);
    }
    p.add(
      _stepHeader(
        t,
        caption,
        f.stepPercent,
        inApps ? const ValueKey('apps-line') : const ValueKey('step-line'),
      ),
    );
    if (!inApps) {
      p.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < installStages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: HinterTokens.s1),
                child: Row(
                  children: [
                    CheckMark(checked: i < current, size: 32),
                    const SizedBox(width: HinterTokens.s2),
                    Text(
                      stageLabel(installStages[i]),
                      style: i == current
                          ? t.label.copyWith(color: t.accent)
                          : (i < current ? t.body : t.bodyDim),
                    ),
                    if (i == current) ...[
                      const SizedBox(width: HinterTokens.s2),
                      Text('now', style: t.caption),
                    ],
                  ],
                ),
              ),
          ],
        ),
        gap: HinterTokens.s2,
      );
    }
    if (f.progressMessage.isNotEmpty) {
      p.add(Text(f.progressMessage, style: t.caption), gap: HinterTokens.s1);
    }
    for (final w in f.warnings) {
      if (w.code == 'app-failed') continue; // listed on the Done screen
      p.add(
        StatusLine('${explainCode(w.code)} (${w.message})'),
        gap: HinterTokens.s2,
      );
    }
  }

  /// What is being done now and its own bar; [percent] null = unmeasurable.
  Widget _stepHeader(HinterTokens t, String caption, int? percent, Key key) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Installing HinterOS', style: t.title),
          const SizedBox(height: HinterTokens.s1),
          Text(caption, key: key, style: t.label),
          const SizedBox(height: HinterTokens.s1),
          Row(
            children: [
              Expanded(
                child: HBar(
                  fraction: percent == null ? null : percent / 100,
                  height: 28,
                ),
              ),
              const SizedBox(width: HinterTokens.s3),
              SizedBox(
                width: 120,
                child: percent == null
                    ? Text(
                        'working',
                        textAlign: TextAlign.right,
                        style: t.caption,
                      )
                    : Text(
                        '$percent%',
                        key: const ValueKey('percent'),
                        textAlign: TextAlign.right,
                        style: t.title,
                      ),
              ),
            ],
          ),
        ],
      );

  void _failure(BuildContext context, InstallerFlow f, Pane p) {
    final t = HinterTheme.of(context);
    final o = f.outcome;
    final e = o?.error;
    final refused = f.phase == InstallPhase.refused;
    p.add(
      StatusLine(
        refused
            ? 'Nothing was changed on your disk.'
            : 'The install stopped before the end. The disk may be changed '
                  'and HinterOS may not start. "Try again" starts over.',
        error: !refused,
      ),
    );
    p.add(Text(explainCode(e?.code), style: t.title), gap: HinterTokens.s3);
    if (e != null) {
      p.add(
        Text(
          'Details: ${e.message}${e.code != null ? ' (${e.code})' : ''}',
          style: t.bodyDim,
        ),
        gap: HinterTokens.s2,
      );
    }
    p.add(
      Text('Full log: $installLogPath', style: t.caption),
      gap: HinterTokens.s2,
    );
    p.buttons('actions', [
      btn('Try again', f.startInstall, primary: true),
      btn('Change my choices', f.leaveFailure),
    ], gap: HinterTokens.s4);
  }
}

/// The last screen: remove the stick, restart.
class DoneStepView extends StatefulWidget {
  const DoneStepView({super.key, required this.env});

  final StepEnv env;

  @override
  State<DoneStepView> createState() => _DoneStepViewState();
}

class _DoneStepViewState extends State<DoneStepView> {
  bool _restarting = false;

  Future<void> _reboot() async {
    setState(() => _restarting = true);
    await widget.env.flow.reboot();
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    final t = HinterTheme.of(context);
    final f = env.flow;
    final p = Pane(env.region);
    p.add(Text('Remove the USB stick, then restart.', style: t.title));
    final failedApps = f.failedAppNames;
    if (failedApps.isNotEmpty) {
      p.add(
        StatusLine(
          "These apps did not install. Add them later from the Store: "
          "${failedApps.join(', ')}",
        ),
        gap: HinterTokens.s3,
      );
    }
    for (final w in f.warnings) {
      if (w.code == 'app-failed') continue;
      p.add(
        StatusLine('${explainCode(w.code)} (${w.message})'),
        gap: HinterTokens.s2,
      );
    }
    if (_restarting) {
      p.add(const StatusLine('Restarting...'), gap: HinterTokens.s3);
      env.region.setRows(const []);
    } else {
      p.buttons('actions', [
        btn('Restart now', _reboot, primary: true),
      ], gap: HinterTokens.s4);
    }
    return StepPage(
      step: InstallerStep.done,
      title: 'HinterOS is installed',
      child: scrolling(p.build()),
    );
  }
}
