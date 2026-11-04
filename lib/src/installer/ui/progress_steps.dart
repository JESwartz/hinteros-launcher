import 'dart:async';

import 'package:flutter/material.dart';

import '../../log.dart';
import '../../theme/hinter_theme.dart';
import '../../ui/widgets.dart';
import '../backend.dart';
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
          InstallPhase.failed when f.diskUntouched =>
            'The install did not start',
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
    final stages = f.stages;
    final current = stages.indexOf(f.progressStage);
    // One bar for the step being worked on (a stage, or one app), not for the
    // whole chain: the steps run at very different speeds. Without a
    // measurable fraction the bar is indeterminate.
    final String caption;
    if (inApps) {
      caption = f.appsLine ?? 'Installing apps';
    } else if (current >= 0) {
      caption =
          'Step ${current + 1} of ${stages.length} · '
          '${f.stageName(stages[current])}';
    } else {
      caption = f.stageName(f.progressStage);
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
            for (var i = 0; i < stages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: HinterTokens.s1),
                child: Row(
                  children: [
                    CheckMark(checked: i < current, size: 32),
                    const SizedBox(width: HinterTokens.s2),
                    Text(
                      f.stageName(stages[i]),
                      style: i == current
                          ? t.label.copyWith(color: t.accent)
                          : (i < current ? t.body : t.bodyDim),
                    ),
                  ],
                ),
              ),
          ],
        ),
        gap: HinterTokens.s2,
      );
    }
    if (!inApps && f.buildLine != null) {
      // Builds can take long with nothing new from the backend: the minutes
      // go on by themselves.
      p.add(_BuildLine(flow: f), gap: HinterTokens.s1);
    } else if (f.progressMessage.isNotEmpty) {
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
          // The page title says "Installing HinterOS": no heading here.
          _SpinnerCaption(caption: caption, captionKey: key),
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
    final refused = f.diskUntouched;
    p.add(
      StatusLine(
        refused
            ? 'Nothing was changed on your disk.'
            : f.runKeep
            ? 'The install stopped before the end. Your files stay on the '
                  'disk, but HinterOS may not start. "Try again" starts over.'
            : 'The install stopped before the end. The disk may be changed '
                  'and HinterOS may not start. "Try again" starts over.',
        error: !refused,
      ),
    );
    p.add(Text(explainCode(e?.code), style: t.title), gap: HinterTokens.s3);
    if (f.newerFailed) {
      p.add(
        Text('Version: ${f.runLabel}', style: t.body),
        gap: HinterTokens.s2,
      );
    }
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
    // Another disk is at the chosen path, or the install on it cannot be
    // kept: the same plan cannot work.
    if (f.diskChanged || f.keepRefused) {
      p.buttons('actions', [
        btn('Select the disk', f.chooseDiskAgain, primary: true),
      ], gap: HinterTokens.s4);
      return;
    }
    p.buttons('actions', [
      // An erase goes back to the summary, to be held again.
      btn('Try again', f.retry, primary: true),
      // A newer HinterOS that did not install: choose the version again
      // (the one on the USB stick, for example).
      if (f.newerFailed)
        btn('Choose another version', f.chooseVersionAgain)
      else if (f.runKeep)
        btn('Change my choices', f.leaveFailure),
    ], gap: HinterTokens.s4);
  }
}

/// The caption of the running install with a spinner on its left, as high as
/// one line of the caption.
class _SpinnerCaption extends StatelessWidget {
  const _SpinnerCaption({required this.caption, required this.captionKey});

  final String caption;
  final Key captionKey;

  @override
  Widget build(BuildContext context) {
    final style = HinterTheme.of(context).label;
    final line = TextPainter(
      text: TextSpan(text: caption, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = line.preferredLineHeight;
    line.dispose();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Spinner(size: size),
        const SizedBox(width: HinterTokens.s1),
        Expanded(
          child: Text(caption, key: captionKey, style: style),
        ),
      ],
    );
  }
}

/// "Building hinteros-launcher (3 of 12): 20%. Time elapsed: 06:12", built again
/// every second so the time counts up while the backend says nothing new.
class _BuildLine extends StatefulWidget {
  const _BuildLine({required this.flow});

  final InstallerFlow flow;

  @override
  State<_BuildLine> createState() => _BuildLineState();
}

class _BuildLineState extends State<_BuildLine> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    widget.flow.buildLine ?? '',
    key: const ValueKey('build-line'),
    style: HinterTheme.of(context).caption,
  );
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
  bool _rebootFailed = false;

  Future<void> _reboot() async {
    setState(() {
      _restarting = true;
      _rebootFailed = false;
    });
    try {
      await widget.env.flow.reboot();
    } on InstallerException catch (e) {
      logFailure('restarting', e);
      if (!mounted) return;
      setState(() {
        _restarting = false;
        _rebootFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    final t = HinterTheme.of(context);
    final f = env.flow;
    final p = Pane(env.region);
    p.add(Text('Remove installation media and restart.', style: t.title));
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
      if (_rebootFailed) {
        p.add(
          const StatusLine('Cannot restart. Try again.', error: true),
          gap: HinterTokens.s3,
        );
      }
      p.buttons('actions', [
        btn('Restart now', _reboot, primary: true),
      ], gap: HinterTokens.s4);
    }
    return StepPage(
      step: InstallerStep.done,
      title: f.installedLabel == null
          ? 'HinterOS is installed'
          : '${f.installedLabel} is installed',
      child: scrolling(p.build()),
    );
  }
}
