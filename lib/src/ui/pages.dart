import 'dart:async';

import 'package:flutter/material.dart';

import '../nav/nav_model.dart';
import '../nav/nav_controller.dart';
import '../api/api.dart' show NavAction;
import '../system/models.dart';
import '../system/repositories.dart';
import '../theme/hinter_theme.dart';
import 'dialogs.dart';
import 'focus_frame.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'session_ending.dart';
import 'widgets.dart';

/// A full-screen page: opaque, with the overscan-safe margin, a title and
/// optional subtitle.
class FullPage extends StatelessWidget {
  const FullPage({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return ColoredBox(
      color: t.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HinterTokens.margin,
          HinterTokens.s5,
          HinterTokens.margin,
          HinterTokens.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: HinterTokens.s3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.headline),
                      if (subtitle != null) Text(subtitle!, style: t.bodyDim),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: HinterTokens.s3),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ progress

/// Follows a job (`jobs.watch`) on a full-screen page: stages, a percentage
/// where one is known, Cancel while that is allowed, the session-restart
/// notice, and on failure what happened and that nothing changed. Resolves
/// with the last snapshot once the user closes it.
Future<JobSnapshot?> showJobProgress(
  BuildContext context,
  SystemServices services,
  JobHandle job, {
  String? subtitle,
}) => ModalScope.of(context).show<JobSnapshot>(
  (context, modal) => JobProgressScreen(
    modal: modal,
    services: services,
    job: job,
    subtitle: subtitle,
  ),
);

class JobProgressScreen extends StatefulWidget {
  const JobProgressScreen({
    super.key,
    required this.modal,
    required this.services,
    required this.job,
    this.subtitle,
  });

  final ModalHandle<JobSnapshot> modal;
  final SystemServices services;
  final JobHandle job;
  final String? subtitle;

  @override
  State<JobProgressScreen> createState() => _JobProgressScreenState();
}

class _JobProgressScreenState extends State<JobProgressScreen> {
  late JobSnapshot _snap = JobSnapshot(
    jobId: widget.job.jobId,
    kind: widget.job.kind,
  );
  StreamSubscription<JobSnapshot>? _sub;
  String? _cancelNote;

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () => _snap.finished;
    _sub = widget.services.jobs
        .watch(widget.job.jobId)
        .listen(
          (s) {
            if (mounted) setState(() => _snap = s);
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(
              () => _snap = _snap.copyWith(
                finished: true,
                ok: false,
                error: JobError(
                  message: e is SystemException
                      ? e.message
                      : 'Lost contact with this job.',
                ),
              ),
            );
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    try {
      await widget.services.jobs.cancel(widget.job.jobId);
    } on SystemException catch (e) {
      if (mounted) setState(() => _cancelNote = e.message);
    }
  }

  Future<void> _restart() async {
    try {
      await endSessionWith(
        context,
        const SessionEnding(title: 'Restarting the session…'),
        widget.services.system.restartSession,
      );
    } on SystemException catch (e) {
      if (mounted) {
        setState(() => _cancelNote = "Can't restart the session: ${e.message}");
      }
      return;
    }
    widget.modal.close(_snap);
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final s = _snap;
    final region = widget.modal.region;
    // The kind's usual stages, plus the one the service reports if it is not
    // among them (the list is a guide, the service decides).
    final stages = _stagesOf(s);
    final current = stages.indexOf(s.stage);
    final restart = s.finished && s.ok && s.sessionRestartRequired;
    region.setRows([NavRow('buttons', restart ? 2 : 1)]);

    final String headline;
    if (!s.finished) {
      headline = s.kind.title;
    } else if (s.ok) {
      headline = 'Done';
    } else if (s.cancelled) {
      headline = 'Cancelled';
    } else {
      headline = switch (s.kind) {
        JobKind.update => 'Update failed',
        JobKind.rollback => 'Rollback failed',
        JobKind.install => 'Install failed',
        JobKind.remove => 'Removal failed',
        _ => 'Failed',
      };
    }

    return FullPage(
      title: headline,
      subtitle: widget.subtitle,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: HinterTokens.s1),
                child: Row(
                  children: [
                    _StageMark(state: _stateOf(i, current, s, stages)),
                    const SizedBox(width: HinterTokens.s2),
                    Text(
                      stages[i].label,
                      style: i == current && !s.finished
                          ? t.label
                          : t.bodyDim.copyWith(
                              fontWeight:
                                  _stateOf(i, current, s, stages) ==
                                      _MarkState.failed
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                    ),
                    if (i == current && !s.finished && s.percent != null)
                      Text('  ${s.percent}%', style: t.label),
                  ],
                ),
              ),
            const SizedBox(height: HinterTokens.s3),
            if (!s.finished) ...[
              SizedBox(
                width: 900,
                child: HBar(
                  fraction: s.percent == null ? null : s.percent! / 100,
                ),
              ),
              const SizedBox(height: HinterTokens.s1),
              Text(
                s.percent != null
                    ? '${s.percent}%${s.detail == null ? '' : '  ${s.detail}'}'
                    : (s.detail ?? 'Working…'),
                style: t.bodyDim,
              ),
            ],
            if (!s.finished && s.kind.mayRestartSession) ...[
              const SizedBox(height: HinterTokens.s3),
              const StatusLine(
                'The session restarts when this finishes. Open games and apps '
                'close.',
              ),
            ],
            if (s.finished && s.ok) ...[
              StatusLine(
                restart
                    ? 'Restart the session to use the change.'
                    : 'Change applied.',
                ok: true,
              ),
            ],
            if (s.finished && !s.ok) ...[
              if (s.error != null) StatusLine(s.error!.message, error: true),
              const SizedBox(height: HinterTokens.s2),
              Text(
                s.cancelled
                    ? 'Nothing changed.'
                    : 'Nothing changed. Try again.',
                style: t.body,
              ),
            ],
            if (_cancelNote != null) ...[
              const SizedBox(height: HinterTokens.s2),
              StatusLine(_cancelNote!, error: true),
            ],
            const SizedBox(height: HinterTokens.s4),
            if (!s.finished)
              DialogButtons(
                region: region,
                rowKey: 'buttons',
                buttons: [
                  btn(
                    s.canCancel ? 'Cancel' : "Can't cancel now",
                    s.canCancel ? _cancel : null,
                    enabled: s.canCancel,
                  ),
                ],
              )
            else if (restart)
              DialogButtons(
                region: region,
                rowKey: 'buttons',
                buttons: [
                  btn('Restart session', _restart, primary: true),
                  btn('Later', () => widget.modal.close(s)),
                ],
              )
            else
              DialogButtons(
                region: region,
                rowKey: 'buttons',
                buttons: [
                  btn('Close', () => widget.modal.close(s), primary: true),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static List<JobStage> _stagesOf(JobSnapshot s) {
    final base = s.kind.stages;
    final extra = [s.stage, ?s.error?.stage].where((x) => !base.contains(x));
    if (extra.isEmpty) return base;
    return [...base, ...extra.toSet()]..sort((a, b) => a.index - b.index);
  }

  static _MarkState _stateOf(
    int i,
    int current,
    JobSnapshot s,
    List<JobStage> stages,
  ) {
    if (s.finished && s.ok) return _MarkState.done;
    if (s.finished) {
      final failedAt = s.error?.stage == null
          ? current
          : stages.indexOf(s.error!.stage!);
      if (s.cancelled) {
        return i < current ? _MarkState.done : _MarkState.pending;
      }
      return i < failedAt
          ? _MarkState.done
          : i == failedAt
          ? _MarkState.failed
          : _MarkState.pending;
    }
    return i < current
        ? _MarkState.done
        : i == current
        ? _MarkState.active
        : _MarkState.pending;
  }
}

enum _MarkState { done, active, pending, failed }

class _StageMark extends StatelessWidget {
  const _StageMark({required this.state});

  final _MarkState state;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return CustomPaint(
      size: const Size.square(36),
      painter: _StagePainter(state, t.text, t.accent, t.onAccent, t.danger),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.state, this.line, this.accent, this.onAccent, this.danger);

  final _MarkState state;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color danger;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    switch (state) {
      case _MarkState.pending:
        canvas.drawCircle(c, r, ring..color = line.withValues(alpha: 0.5));
      case _MarkState.active:
        canvas.drawCircle(c, r, ring..color = accent);
        canvas.drawCircle(c, r * 0.5, Paint()..color = accent);
      case _MarkState.done:
        canvas.drawCircle(c, r, Paint()..color = accent);
        canvas.drawPath(
          Path()
            ..moveTo(s.width * 0.28, s.height * 0.52)
            ..lineTo(s.width * 0.44, s.height * 0.68)
            ..lineTo(s.width * 0.74, s.height * 0.34),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = onAccent,
        );
      case _MarkState.failed:
        canvas.drawCircle(c, r, Paint()..color = danger);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = onAccent;
        canvas.drawLine(
          Offset(s.width * 0.34, s.height * 0.34),
          Offset(s.width * 0.66, s.height * 0.66),
          p,
        );
        canvas.drawLine(
          Offset(s.width * 0.66, s.height * 0.34),
          Offset(s.width * 0.34, s.height * 0.66),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(_StagePainter o) => o.state != state || o.accent != accent;
}

// ------------------------------------------------------------------ terms

/// The vendor terms of [app] in full. The text scrolls with the controller
/// (up/down a line, the shoulder buttons a page), and "Accept and install"
/// stays disabled until the end has been reached. Resolves true on accept.
Future<bool> showTerms(
  BuildContext context,
  StoreApp app, {
  String acceptLabel = 'Accept and install',
  String? note,
}) async =>
    await ModalScope.of(context).show<bool>(
      (context, modal) => TermsScreen(
        modal: modal,
        app: app,
        acceptLabel: acceptLabel,
        note: note,
      ),
    ) ??
    false;

class TermsScreen extends StatefulWidget {
  const TermsScreen({
    super.key,
    required this.modal,
    required this.app,
    this.acceptLabel = 'Accept and install',
    this.note,
  });

  final ModalHandle<bool> modal;
  final StoreApp app;
  final String acceptLabel;

  /// A line above the buttons ("Each profile accepts these for itself").
  final String? note;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final _scroll = ScrollController();
  bool _atEnd = false;
  double _fraction = 0;
  static const _line = 96.0;

  VendorTerms get _terms => widget.app.terms!;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    final r = widget.modal.region;
    r.interceptMove = _onMove;
    r.onAction = _onAction;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final p = _scroll.position;
    final end = p.maxScrollExtent <= 0 || p.pixels >= p.maxScrollExtent - 4;
    final f = p.maxScrollExtent <= 0 ? 1.0 : p.pixels / p.maxScrollExtent;
    if (end != _atEnd || (f - _fraction).abs() > 0.001) {
      if (mounted) {
        setState(() {
          _atEnd = _atEnd || end;
          _fraction = f;
        });
      }
    }
  }

  void _scrollBy(double d) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final target = (p.pixels + d).clamp(0.0, p.maxScrollExtent);
    final t = HinterTheme.of(context);
    if (t.fast == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: t.fast, curve: Curves.easeOut);
    }
  }

  bool get _onText => widget.modal.region.model.currentRow?.key == 'text';

  /// Up and down scroll the text while it has the focus; at its ends they
  /// move on (to the buttons).
  bool _onMove(NavDir dir) {
    if (!_onText || !_scroll.hasClients) return false;
    final p = _scroll.position;
    if (dir == NavDir.down && p.pixels < p.maxScrollExtent - 1) {
      _scrollBy(_line);
      return true;
    }
    if (dir == NavDir.up && p.pixels > 1) {
      _scrollBy(-_line);
      return true;
    }
    return false;
  }

  bool _onAction(NavAction a) {
    if (!_scroll.hasClients) return false;
    final page = _scroll.position.viewportDimension - _line;
    if (a == NavAction.pageRight) {
      _scrollBy(page);
      return true;
    }
    if (a == NavAction.pageLeft) {
      _scrollBy(-page);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows(const [NavRow('text', 1), NavRow('buttons', 2)]);
    return FullPage(
      title: 'Terms for ${widget.app.name}',
      subtitle:
          '${_terms.title}, version ${_terms.version}. Source: '
          '${_terms.url}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: NavFocusableBox(
              region: region,
              rowKey: 'text',
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(HinterTokens.s3),
                      child: Text(_terms.text, style: t.body),
                    ),
                  ),
                  _Track(controller: _scroll, fraction: _fraction),
                ],
              ),
            ),
          ),
          const SizedBox(height: HinterTokens.s2),
          Text(
            _atEnd
                ? 'You read to the end.'
                : 'Read to the end to accept. L1 and R1 scroll a page.',
            style: t.caption,
          ),
          if (widget.note != null) ...[
            const SizedBox(height: HinterTokens.s1),
            Text(widget.note!, style: t.caption),
          ],
          const SizedBox(height: HinterTokens.s2),
          DialogButtons(
            region: region,
            rowKey: 'buttons',
            buttons: [
              btn('Decline', () => widget.modal.close(false)),
              btn(
                widget.acceptLabel,
                () => widget.modal.close(true),
                primary: true,
                enabled: _atEnd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A focusable framed area (the focus marker goes around the whole box).
class NavFocusableBox extends StatelessWidget {
  const NavFocusableBox({
    super.key,
    required this.region,
    required this.rowKey,
    required this.child,
  });

  final NavRegion region;
  final String rowKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return NavFocusable(
      region: region,
      rowKey: rowKey,
      col: 0,
      scrollIntoView: false,
      builder: (_, focused) => FocusFrame(
        focused: focused,
        radius: HinterTokens.radiusCard,
        scale: 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
            border: Border.all(color: t.textDim, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.controller, required this.fraction});

  final ScrollController controller;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(HinterTokens.s2),
      child: LayoutBuilder(
        builder: (context, c) {
          return SizedBox(
            width: 16,
            height: c.maxHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  top: (c.maxHeight - 96) * fraction,
                  left: 0,
                  right: 0,
                  height: 96,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ security notice

enum SecurityChoice { updateNow, later }

/// How long the security notice cannot be dismissed (threat-model decision).
const securityLockout = Duration(seconds: 5);

/// The full-screen security-update notice: states the severity, and for
/// [securityLockout] cannot be dismissed (visible countdown, buttons and Back
/// inert). Then "Update now" / "Later". Never updates by itself.
Future<SecurityChoice?> showSecurityNotice(
  BuildContext context,
  AvailableUpdate update, {
  Duration lockout = securityLockout,
}) => ModalScope.of(context).show<SecurityChoice>(
  (context, modal) =>
      SecurityNotice(modal: modal, update: update, lockout: lockout),
);

class SecurityNotice extends StatefulWidget {
  const SecurityNotice({
    super.key,
    required this.modal,
    required this.update,
    this.lockout = securityLockout,
  });

  final ModalHandle<SecurityChoice> modal;
  final AvailableUpdate update;
  final Duration lockout;

  @override
  State<SecurityNotice> createState() => _SecurityNoticeState();
}

class _SecurityNoticeState extends State<SecurityNotice> {
  late int _left = (widget.lockout.inMilliseconds / 1000).ceil();
  Timer? _timer;

  bool get _locked => _left > 0;

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () => !_locked;
    if (_locked) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (!_locked) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final u = widget.update;
    final region = widget.modal.region;
    region.setRows(const [NavRow('buttons', 2)]);
    final sev = u.severity ?? SecuritySeverity.unknown;
    return ColoredBox(
      color: t.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HinterTokens.margin,
          vertical: HinterTokens.s5,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '!',
                        textScaler: TextScaler.noScaling,
                        style: t.headline.copyWith(
                          color: t.onAccent,
                          fontSize: 64,
                        ),
                      ),
                    ),
                    const SizedBox(width: HinterTokens.s4),
                    Expanded(child: Text('Security update', style: t.headline)),
                  ],
                ),
                const SizedBox(height: HinterTokens.s4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HinterTokens.s3,
                    vertical: HinterTokens.s1,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.danger, width: 4),
                    borderRadius: BorderRadius.circular(
                      HinterTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    'Severity: ${sev.label}',
                    style: t.title.copyWith(color: t.danger),
                  ),
                ),
                if (u.securitySummary != null) ...[
                  const SizedBox(height: HinterTokens.s2),
                  Text(
                    u.securitySummary!,
                    key: const ValueKey('security-summary'),
                    style: t.title,
                  ),
                ],
                const SizedBox(height: HinterTokens.s3),
                Text(
                  'HinterOS ${u.version} fixes a security problem.',
                  style: t.title,
                ),
                const SizedBox(height: HinterTokens.s1),
                Text(u.summary, style: t.body),
                const SizedBox(height: HinterTokens.s2),
                Text('The update restarts your session.', style: t.bodyDim),
                const SizedBox(height: HinterTokens.s4),
                Text(
                  _locked
                      ? 'You can choose in $_left '
                            '${_left == 1 ? 'second' : 'seconds'}.'
                      : 'Choose when to update.',
                  key: const ValueKey('countdown'),
                  style: t.label.copyWith(color: _locked ? t.accent : t.text),
                ),
                const SizedBox(height: HinterTokens.s2),
                DialogButtons(
                  region: region,
                  rowKey: 'buttons',
                  buttons: [
                    btn(
                      _locked ? 'Later ($_left)' : 'Later',
                      () => widget.modal.close(SecurityChoice.later),
                      enabled: !_locked,
                    ),
                    btn(
                      _locked ? 'Update now ($_left)' : 'Update now',
                      () => widget.modal.close(SecurityChoice.updateNow),
                      primary: true,
                      enabled: !_locked,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
