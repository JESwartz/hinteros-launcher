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
import 'jobs.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'qr_code.dart';
import 'restart_countdown.dart';
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

/// Follows a job (`jobs.watch`) on a full-screen page: what it does (for
/// whom, which version), stages, while building the count and the name,
/// a bar that always moves, the time it takes, Cancel while that is allowed,
/// the session-restart notice, and on failure what happened. While the job
/// runs the person can leave the page ("Hide" or Back): the job keeps
/// running and the top bar shows it ([JobCenter]). Resolves with the last
/// snapshot when the page closes: a running one when it was left.
/// [name] names the job when the service does not (the app of a Store
/// action); [initial] is what is known already (a page opened again).
Future<JobSnapshot?> showJobProgress(
  BuildContext context,
  SystemServices services,
  JobHandle job, {
  String? name,
  JobSnapshot? initial,
}) => ModalScope.of(context).show<JobSnapshot>(
  (context, modal) => JobProgressScreen(
    modal: modal,
    services: services,
    job: job,
    name: name,
    initial: initial,
  ),
);

/// After this long without news of a running job the page says so (the
/// service sends a heartbeat at least every 2 s).
const jobQuietAfter = Duration(seconds: 20);

/// After this long without output from the job's process the page says
/// that some steps take long.
const jobNoOutputAfter = Duration(minutes: 3);

class JobProgressScreen extends StatefulWidget {
  const JobProgressScreen({
    super.key,
    required this.modal,
    required this.services,
    required this.job,
    this.name,
    this.initial,
  });

  final ModalHandle<JobSnapshot> modal;
  final SystemServices services;
  final JobHandle job;
  final String? name;
  final JobSnapshot? initial;

  @override
  State<JobProgressScreen> createState() => _JobProgressScreenState();
}

class _JobProgressScreenState extends State<JobProgressScreen> with JobTicker {
  late JobSnapshot _snap =
      widget.initial ??
      JobSnapshot(jobId: widget.job.jobId, kind: widget.job.kind);
  late final DateTime _opened = widget.services.jobs.now();
  StreamSubscription<JobSnapshot>? _sub;
  String? _cancelNote;
  JobCenter? _center;

  /// The countdown to the session restart runs (until a restart is tried).
  bool _autoRestart = true;
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () {
      if (_snap.finished) {
        _close();
      } else if (_center != null) {
        _close(hidden: true);
      }
      return false;
    };
    if (_snap.running) startTicking();
    _sub = widget.services.jobs
        .watch(widget.job.jobId)
        .listen(
          (s) {
            if (!mounted) return;
            setState(() => _snap = s);
            if (s.finished) stopTicking();
          },
          onError: (Object e) {
            if (!mounted) return;
            stopTicking();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_center == null) {
      _center = JobCenterScope.maybeOf(context);
      _center?.pageOpened(widget.job.jobId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Closes the page; [hidden]: the person leaves it while the job runs.
  void _close({bool hidden = false}) {
    _center?.pageClosed(_snap, hidden: hidden, name: widget.name);
    widget.modal.close(_snap);
  }

  Future<void> _cancel() async {
    try {
      await widget.services.jobs.cancel(widget.job.jobId);
    } on SystemException catch (e) {
      if (mounted) setState(() => _cancelNote = e.message);
    }
  }

  Future<void> _restart() async {
    if (_restarting) return;
    setState(() {
      _restarting = true;
      _autoRestart = false;
    });
    try {
      await endSessionWith(
        context,
        const SessionEnding(title: 'Restarting the session…'),
        widget.services.system.restartSession,
      );
    } on SystemException catch (e) {
      if (mounted) {
        setState(() {
          _restarting = false;
          _cancelNote = "Can't restart the session: ${e.message}";
        });
      }
      return;
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final s = _snap;
    final region = widget.modal.region;
    final restart = s.finished && s.ok && s.sessionRestartRequired;
    final canHide = !s.finished && _center != null;
    region.setRows([NavRow('buttons', restart || canHide ? 2 : 1)]);

    final title = jobTitle(s, name: widget.name);
    final String headline;
    if (!s.finished) {
      headline = title;
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
    final sub = jobSubtitle(s);

    final stages = _stages(context, s);
    // Side by side on a TV, also with large text: the buttons stay on
    // screen.
    final wide = MediaQuery.sizeOf(context).width >= 1500;

    return FullPage(
      title: headline,
      subtitle: s.finished ? title : sub,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!s.finished && wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 640, child: stages),
                  const SizedBox(width: HinterTokens.s5),
                  Expanded(child: _now(context, s)),
                ],
              )
            else ...[
              stages,
              if (!s.finished) ...[
                const SizedBox(height: HinterTokens.s3),
                _now(context, s),
              ],
            ],
            const SizedBox(height: HinterTokens.s3),
            if (!s.finished && s.kind.mayRestartSession) ...[
              const StatusLine(
                'The session restarts when this finishes. Open games and apps '
                'close.',
              ),
            ],
            if (s.finished && s.ok) ...[
              StatusLine(
                restart
                    ? 'Restart the session to use the change.'
                    : _doneText(s),
                key: const ValueKey('job-done'),
                ok: true,
              ),
              if (restart && _autoRestart) ...[
                const SizedBox(height: HinterTokens.s1),
                RestartCountdown(onEnd: _restart),
              ],
            ],
            if (s.finished && s.ok && _readded(s)) ...[
              const SizedBox(height: HinterTokens.s1),
              Text('The parts your apps need are on again.', style: t.body),
            ],
            if (s.finished && !s.ok) ...[
              if (s.error != null) StatusLine(s.error!.message, error: true),
              const SizedBox(height: HinterTokens.s2),
              Text(
                s.cancelled
                    ? 'Nothing changed.'
                    // The rollback itself stays when only its box stage
                    // failed (0.13).
                    : s.kind == JobKind.rollback &&
                          s.error?.stage == JobStage.box
                    ? 'The rollback is done. Some apps may not work.'
                    // A clean-up can stop after it removed some versions.
                    : (s.kind == JobKind.cleanupSystem ||
                              s.kind == JobKind.cleanupProfiles) &&
                          s.error?.stage != JobStage.preparing
                    ? 'Some old versions may be gone. Try again.'
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
                  if (canHide)
                    btn('Hide', () => _close(hidden: true), primary: true),
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
                  btn('Later', _close),
                ],
              )
            else
              DialogButtons(
                region: region,
                rowKey: 'buttons',
                buttons: [btn('Close', _close, primary: true)],
              ),
          ],
        ),
      ),
    );
  }

  /// The kind's stages with a mark each.
  Widget _stages(BuildContext context, JobSnapshot s) {
    final t = HinterTheme.of(context);
    // The kind's usual stages, plus the one the service reports if it is not
    // among them (the list is a guide, the service decides).
    final stages = _stagesOf(s);
    final current = stages.indexOf(s.stage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: HinterTokens.s1),
            child: Row(
              children: [
                _StageMark(state: _stateOf(i, current, s, stages)),
                const SizedBox(width: HinterTokens.s2),
                Flexible(
                  child: Text(
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
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// A Tailscale sign-in that waits (0.19): the address as a large QR code
  /// and as text, for a phone.
  Widget _signIn(BuildContext context, String url) {
    final t = HinterTheme.of(context);
    final side = (MediaQuery.sizeOf(context).height * 0.42).clamp(240.0, 460.0);
    return Row(
      key: const ValueKey('job-sign-in'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QrCodeView(data: url, size: side),
        const SizedBox(width: HinterTokens.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan the code to sign in.', style: t.title),
              const SizedBox(height: HinterTokens.s2),
              Text(url, key: const ValueKey('job-auth-url'), style: t.body),
            ],
          ),
        ),
      ],
    );
  }

  /// What happens now: the stage with its count or percentage (large),
  /// what builds (small), the bar, the time, and a word when the job is
  /// quiet. A sign-in that waits shows its address instead.
  Widget _now(BuildContext context, JobSnapshot s) {
    final url = s.authUrl;
    if (url != null && s.stage == JobStage.signingIn) {
      return _signIn(context, url);
    }
    final t = HinterTheme.of(context);
    final building = s.stage == JobStage.building;
    final count = building ? buildCount(s.build) : null;
    final big = count ?? (s.percent == null ? null : '${s.percent}%');
    final small = building ? buildName(s.build) : s.detail;
    final now = widget.services.jobs.now();
    final started = s.startedAt ?? _opened;
    var heard = s.heardAt ?? _opened;
    if (heard.isBefore(_opened)) heard = _opened;
    final quiet = now.difference(heard);
    final noOutput = s.lastActivityAt == null
        ? Duration.zero
        : now.difference(s.lastActivityAt!);
    final under = [
      if (count != null && s.percent != null) '${s.percent}% in all',
      'Time elapsed: ${elapsedText(now.difference(started))}',
    ];
    return Column(
      key: const ValueKey('job-now'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: HinterTokens.s2,
          children: [
            Text(s.stage.label, style: t.title),
            if (big != null)
              Text(
                big,
                key: const ValueKey('job-count'),
                style: t.headline.copyWith(color: t.accent, height: 1.05),
              ),
          ],
        ),
        if (small != null)
          Text(
            small,
            key: const ValueKey('job-what'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyDim,
          ),
        const SizedBox(height: HinterTokens.s2),
        JobBar(
          fraction: s.percent == null ? null : s.percent! / 100,
          tick: tick,
        ),
        const SizedBox(height: HinterTokens.s1),
        Text(
          under.join('    '),
          key: const ValueKey('job-elapsed'),
          style: t.bodyDim,
        ),
        if (quiet >= jobQuietAfter) ...[
          const SizedBox(height: HinterTokens.s2),
          StatusLine(
            'No news for ${_ago(quiet)}. The job is still running.',
            key: const ValueKey('job-quiet'),
          ),
        ] else if (noOutput >= jobNoOutputAfter) ...[
          const SizedBox(height: HinterTokens.s2),
          StatusLine(
            'No new output for ${_ago(noOutput)}. Some steps take a long '
            'time.',
            key: const ValueKey('job-no-output'),
          ),
        ],
      ],
    );
  }

  static String _ago(Duration d) =>
      d.inSeconds < 60 ? '${d.inSeconds} s' : '${d.inMinutes} min';

  /// What a job that finished well did: a clean-up says what it freed.
  static String _doneText(JobSnapshot s) {
    switch (s.kind) {
      case JobKind.cleanupSystem || JobKind.cleanupProfiles:
        final f = cleanupFreed(s);
        return f == null
            ? 'Clean-up done.'
            : 'Freed ${storageSize(f.freedBytes)}.';
      case JobKind.storageMeasure:
        return 'Scan done.';
      default:
        return 'Change applied.';
    }
  }

  /// A rollback that turned box features back on (`features_readded`).
  static bool _readded(JobSnapshot s) =>
      s.kind == JobKind.rollback &&
      switch (s.result?['features_readded']) {
        final List<Object?> l => l.isNotEmpty,
        _ => false,
      };

  static List<JobStage> _stagesOf(JobSnapshot s) {
    final base = s.kind.stages;
    final extra = [s.stage, ?s.error?.stage].where((x) => !base.contains(x));
    if (extra.isEmpty) return base;
    // A rollback's box stage comes last, after the switch and the apps.
    double order(JobStage x) => s.kind == JobKind.rollback && x == JobStage.box
        ? JobStage.apps.index + 0.5
        : x.index.toDouble();
    return [...base, ...extra.toSet()]
      ..sort((a, b) => order(a).compareTo(order(b)));
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
        name: app.name,
        terms: app.terms!,
        acceptLabel: acceptLabel,
        note: note,
      ),
    ) ??
    false;

/// The terms of [app] to read only (its Store page): Back, no Accept.
Future<void> showTermsToRead(BuildContext context, StoreApp app) =>
    ModalScope.of(context).show<bool>(
      (context, modal) => TermsScreen(
        modal: modal,
        name: app.name,
        terms: app.terms!,
        readOnly: true,
      ),
    );

/// [showTerms] for a box-wide service of the Server tab (Plex).
Future<bool> showServiceTerms(
  BuildContext context, {
  required String name,
  required VendorTerms terms,
  String acceptLabel = 'Accept and turn on',
}) async =>
    await ModalScope.of(context).show<bool>(
      (context, modal) => TermsScreen(
        modal: modal,
        name: name,
        terms: terms,
        acceptLabel: acceptLabel,
      ),
    ) ??
    false;

class TermsScreen extends StatefulWidget {
  const TermsScreen({
    super.key,
    required this.modal,
    required this.name,
    required this.terms,
    this.acceptLabel = 'Accept and install',
    this.note,
    this.readOnly = false,
  });

  final ModalHandle<bool> modal;

  /// Only Back (the app page): nothing to accept.
  final bool readOnly;

  /// Whose terms (an app, a service).
  final String name;
  final VendorTerms terms;
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

  VendorTerms get _terms => widget.terms;

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
    region.setRows([
      const NavRow('text', 1),
      NavRow('buttons', widget.readOnly ? 1 : 2),
    ]);
    return FullPage(
      title: 'Terms for ${widget.name}',
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
            widget.readOnly
                ? 'L1 and R1 scroll a page.'
                : _atEnd
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
              if (widget.readOnly)
                btn('Back', () => widget.modal.close(false), primary: true)
              else ...[
                btn('Decline', () => widget.modal.close(false)),
                btn(
                  widget.acceptLabel,
                  () => widget.modal.close(true),
                  primary: true,
                  enabled: _atEnd,
                ),
              ],
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

/// How long Later (and Back) on the security notice wait (threat-model decision).
const securityLockout = Duration(seconds: 5);

/// The full-screen security-update notice: states the severity. "Update now"
/// works at once and has the focus; "Later" and Back wait [securityLockout]
/// (a countdown on Later). Never updates by itself.
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
  bool _placed = false;

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
    if (!_placed) {
      // Focus starts on Update now (Later waits).
      _placed = true;
      region.model.goTo(0, 1);
    }
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
                      'Update now',
                      () => widget.modal.close(SecurityChoice.updateNow),
                      primary: true,
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
