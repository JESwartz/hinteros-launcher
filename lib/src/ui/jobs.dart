/// Jobs on screen outside their page: what a job is called ([jobTitle]),
/// the [JobCenter] that follows a job after the person left its page, the
/// compact indicator for the top bar ([JobIndicator]) and the bar that
/// always moves while a job runs ([JobBar]).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../settings/launcher_settings.dart' show FocusStyle;
import '../system/models.dart';
import '../system/repositories.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';

// ---------------------------------------------------------------- text

/// "Moonlight", "Moonlight and Steam", "Moonlight and 2 more apps".
String _appNames(List<({String id, String name})> apps) => switch (apps) {
  [] => '',
  [final a] => a.name,
  [final a, final b] => '${a.name} and ${b.name}',
  [final a, ...final rest] => '${a.name} and ${rest.length} more apps',
};

/// What a job does, as the title of its page and of its notice:
/// "Installing Moonlight", "Updating to HinterOS 0.7.1.c6b69ce beta".
/// [name] is what the caller knows when the service says nothing (the
/// app of a Store action).
String jobTitle(JobSnapshot s, {String? name}) {
  final x = s.subject;
  final apps = x.apps.isEmpty ? (name ?? '') : _appNames(x.apps);
  return switch (s.kind) {
    JobKind.update =>
      x.version == null
          ? 'Updating HinterOS'
          : 'Updating to HinterOS ${x.version}',
    JobKind.rollback =>
      x.generation == null
          ? 'Rolling back'
          : 'Rolling back to generation ${x.generation}',
    JobKind.channel => switch ((x.fromChannel, x.channel)) {
      (final from?, final to?) => 'Switching from ${from.label} to ${to.label}',
      (_, final to?) => 'Switching to ${to.label}',
      _ => s.kind.title,
    },
    JobKind.base => switch ((x.fromBase, x.base)) {
      (final from?, final to?) =>
        'Switching the base from ${from.label} to ${to.label}',
      (_, final to?) => 'Switching the base to ${to.label}',
      _ => s.kind.title,
    },
    JobKind.ssh => switch (x.enabled) {
      true => 'Turning on remote access',
      false => 'Turning off remote access',
      null => s.kind.title,
    },
    JobKind.install when x.fromOwner == 'starter' => 'Adding the starter apps',
    JobKind.install => apps.isEmpty ? 'Installing apps' : 'Installing $apps',
    JobKind.remove => apps.isEmpty ? 'Removing apps' : 'Removing $apps',
    JobKind.clearData =>
      apps.isEmpty ? s.kind.title : 'Clearing the data of $apps',
    JobKind.appsRollback =>
      x.generation == null
          ? s.kind.title
          : 'Rolling back apps to generation ${x.generation}',
    JobKind.profileCreate =>
      x.profileName == null
          ? s.kind.title
          : 'Creating the profile ${x.profileName}',
    JobKind.profileRemove =>
      x.profileName == null
          ? s.kind.title
          : 'Removing the profile ${x.profileName}',
    JobKind.guest => switch (x.enabled) {
      true => 'Turning on Guest',
      false => 'Turning off Guest',
      null => s.kind.title,
    },
    JobKind.cleanupSet when x.enabled == false =>
      'Turning off automatic clean-up',
    JobKind.servicesEnable when x.services.isNotEmpty =>
      'Turning on ${_appNames(x.services)}',
    JobKind.servicesDisable when x.services.isNotEmpty =>
      'Turning off ${_appNames(x.services)}',
    JobKind.libraryAdd when x.library != null =>
      'Adding the library ${x.library}',
    JobKind.libraryRemove when x.library != null =>
      'Removing the library ${x.library}',
    _ => name != null && s.kind == JobKind.rebuild ? name : s.kind.title,
  };
}

/// The line under the title: for whom, from what, what else happens.
/// Null when there is nothing to add.
String? jobSubtitle(JobSnapshot s) {
  final x = s.subject;
  final parts = <String>[
    if (x.owner == 'guest' && s.kind != JobKind.guestEnd)
      'For the guest'
    else if (x.owner == 'starter' && s.kind != JobKind.starterSet)
      'For the starter apps'
    else if (x.profileName != null &&
        s.kind != JobKind.profileCreate &&
        s.kind != JobKind.profileRemove)
      'For ${x.profileName}',
    if (s.kind == JobKind.update && x.fromVersion != null)
      'Now on HinterOS ${x.fromVersion}',
    if (s.kind == JobKind.channel && x.version != null)
      'New version: HinterOS ${x.version}',
    if (s.kind == JobKind.rollback && x.fromGeneration != null)
      'Now on generation ${x.fromGeneration}',
    if (s.kind == JobKind.remove && x.deleteData) 'The app data is deleted too',
    if (s.kind == JobKind.servicesDisable && x.deleteData)
      'The server data is deleted too',
    if (s.kind == JobKind.starterSet && x.apps.isNotEmpty)
      x.apps.length == 1 ? '1 app' : '${x.apps.length} apps',
    if ((s.kind == JobKind.cleanupSystem ||
            s.kind == JobKind.cleanupProfiles) &&
        x.keep != null)
      x.keep == 1
          ? 'Keeps the newest version'
          : 'Keeps the ${x.keep} newest versions',
    if (s.kind == JobKind.cleanupSet &&
        x.enabled != false &&
        x.frequency != null)
      x.frequency!.label,
  ];
  return parts.isEmpty ? null : '${parts.join('. ')}.';
}

/// The short notice when a job the person left ends.
String jobNotice(JobSnapshot s, {String? name}) {
  final title = jobTitle(s, name: name);
  if (s.ok) {
    return s.sessionRestartRequired
        ? '$title: done. Restart the session to use it.'
        : '$title: done.';
  }
  return s.cancelled ? '$title: cancelled.' : '$title: failed.';
}

/// How long a job has run: "00:40", "12:05", "1:05:00" (an hour or more).
String elapsedText(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  final mmss = '${two(s ~/ 60 % 60)}:${two(s % 60)}';
  return s < 3600 ? mmss : '${s ~/ 3600}:$mmss';
}

/// Nix's build phase in words.
String phaseText(String phase) => switch (phase) {
  'unpack' => 'unpacking',
  'patch' => 'patching',
  'configure' => 'configuring',
  'build' => 'compiling',
  'check' => 'testing',
  'install' => 'installing',
  'fixup' || 'installCheck' || 'dist' => 'finishing',
  _ => phase,
};

/// "3 of 12" while nix builds; null when it gives no count.
String? buildCount(BuildProgress? b) {
  final n = b?.current;
  return n == null ? null : '$n of ${b!.total}';
}

/// What builds now, in small text: "hinteros-daemon 0.7.1: 20%, compiling"
/// (the percent of that one alone, when nix gives it).
String? buildName(BuildProgress? b) {
  if (b == null || b.name == null) return null;
  final more = (b.running ?? 1) - 1;
  return [
    b.version == null ? b.name! : '${b.name} ${b.version}',
    if (b.percent != null) ': ${b.percent}%',
    if (b.phase != null) ', ${phaseText(b.phase!)}',
    if (more > 0) ' (and $more more)',
  ].join();
}

/// The progress in a few characters (the top bar): "3 of 12", "42%",
/// else the stage.
String jobProgressShort(JobSnapshot s) {
  if (s.finished) {
    if (s.ok) return s.sessionRestartRequired ? 'Restart needed' : 'Done';
    return s.cancelled ? 'Cancelled' : 'Failed';
  }
  if (s.stage == JobStage.building) {
    final c = buildCount(s.build);
    if (c != null) return 'Building $c';
  }
  if (s.percent != null) return '${s.percent}%';
  return s.stage.label;
}

// ---------------------------------------------------------------- center

/// Follows the job whose page the person left ("Hide" or Back), for the top
/// bar indicator and the notice when it ends. One job at a time: the
/// service runs one mutating job at a time.
class JobCenter extends ChangeNotifier {
  JobCenter(this.jobs);

  final JobsRepository jobs;

  /// The job shown in the top bar: still running, or ended and not yet
  /// seen (failed, or waiting for a session restart).
  JobSnapshot? get background => _background;
  JobSnapshot? _background;

  /// What the caller called the job (the app's name), for the titles.
  String? get backgroundName => _name;
  String? _name;

  /// The job whose page is on screen.
  String? _page;
  StreamSubscription<JobSnapshot>? _sub;

  /// A job the person left ended (not while its page shows).
  void Function(JobSnapshot s, String? name)? onFinished;

  /// The page of [jobId] opened: the indicator goes while it shows.
  void pageOpened(String jobId) {
    _page = jobId;
    if (_background?.jobId != jobId) return;
    // Called while the page builds: the top bar follows after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  /// The page closed. [hidden]: the person left it while the job runs,
  /// so the top bar follows the job from now on.
  void pageClosed(JobSnapshot s, {required bool hidden, String? name}) {
    if (_page == s.jobId) _page = null;
    if (hidden && s.running) {
      follow(s, name: name);
      return;
    }
    if (_background?.jobId == s.jobId) {
      _clear();
    } else {
      notifyListeners();
    }
  }

  /// Whether the indicator shows (there is a job and its page does not).
  bool get showsIndicator => _background != null && _background!.jobId != _page;

  /// Follows [s] in the top bar.
  void follow(JobSnapshot s, {String? name}) {
    if (_background?.jobId != s.jobId) {
      unawaited(_sub?.cancel());
      _sub = null;
      _name = name;
    } else {
      _name = name ?? _name;
    }
    _background = s;
    notifyListeners();
    if (s.finished) return;
    _sub ??= jobs
        .watch(s.jobId)
        .listen(
          (n) {
            if (_background?.jobId != n.jobId) return;
            _background = n;
            if (n.finished) _ended(n);
            notifyListeners();
          },
          onError: (Object _) {
            // Lost: the page says so when it opens; the bar keeps the
            // last state rather than claiming an end.
          },
        );
  }

  void _ended(JobSnapshot s) {
    _sub = null;
    final visible = _page == s.jobId;
    if (!visible) onFinished?.call(s, _name);
    // Done (no restart) or cancelled: nothing left to see.
    if (s.cancelled || (s.ok && !s.sessionRestartRequired)) {
      _background = null;
      _name = null;
    }
  }

  /// After a launcher start or a reconnect: the job that runs on the box
  /// shows in the top bar.
  Future<void> reattach() async {
    final JobSnapshot? r;
    try {
      r = await jobs.running();
    } catch (_) {
      return;
    }
    if (r == null || !r.running) return;
    if (_page == r.jobId || _background?.jobId == r.jobId) return;
    if (_page != null) return;
    follow(r);
  }

  /// The person saw the end (the restart notice was answered "Later" keeps
  /// it; closing the page clears it).
  void clear() => _clear();

  void _clear() {
    unawaited(_sub?.cancel());
    _sub = null;
    _background = null;
    _name = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

/// Gives the job pages the shell's [JobCenter] (none: a page cannot be
/// left while its job runs).
class JobCenterScope extends InheritedWidget {
  const JobCenterScope({super.key, required this.center, required super.child});

  final JobCenter center;

  static JobCenter? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<JobCenterScope>()?.center;

  @override
  bool updateShouldNotify(JobCenterScope old) => center != old.center;
}

// ---------------------------------------------------------------- motion

/// A tick every second while [active]: the elapsed time, the heartbeat
/// check and the moving bar follow it. Each tick starts a short animation
/// that ends well before the next, so the screen is still between them.
mixin JobTicker<T extends StatefulWidget> on State<T> {
  Timer? _ticker;
  int tick = 0;

  void startTicking() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => tick++);
    });
  }

  void stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    stopTicking();
    super.dispose();
  }
}

/// How long one move of the bar takes (shorter than a tick).
const _move = Duration(milliseconds: 700);

/// The job's bar: filled to [fraction] where there is a count, with a light
/// band that moves across the filled part; without a count a block that
/// moves from end to end. It moves once per [tick]; with reduced motion it
/// stays still (the text still changes).
class JobBar extends StatelessWidget {
  const JobBar({
    super.key,
    required this.fraction,
    required this.tick,
    this.height = 20,
  });

  final double? fraction;
  final int tick;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final f = fraction?.clamp(0.0, 1.0);
    final still = t.reduceMotion;
    final x = still ? 0.0 : (tick.isEven ? -1.0 : 1.0);
    final r = BorderRadius.circular(height / 2);
    Widget band(double width, Color color) => AnimatedAlign(
      duration: still ? Duration.zero : _move,
      curve: Curves.easeInOut,
      alignment: Alignment(x, 0),
      child: FractionallySizedBox(
        widthFactor: width,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: r),
          child: SizedBox(height: height),
        ),
      ),
    );
    return Container(
      key: const ValueKey('job-bar'),
      height: height,
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: r,
        border: Border.all(color: t.textDim, width: 2),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: f == null || f < 0.04
            ? band(0.25, t.accent)
            : Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: f,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: t.accent, borderRadius: r),
                    child: SizedBox(
                      height: height,
                      child: f < 0.12
                          ? null
                          : band(0.3, t.onAccent.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar

/// The job in the top bar, next to the profile chip and the clock: a ring
/// (the percentage, or a turning arc), what the job is and its progress.
/// Selecting it opens the job's page again.
class JobIndicator extends StatefulWidget {
  const JobIndicator({
    super.key,
    required this.job,
    required this.focused,
    this.name,
    this.compact = false,
  });

  final JobSnapshot job;
  final String? name;
  final bool focused;

  /// Large text: the ring and the short progress only.
  final bool compact;

  @override
  State<JobIndicator> createState() => _JobIndicatorState();
}

class _JobIndicatorState extends State<JobIndicator> with JobTicker {
  @override
  void initState() {
    super.initState();
    if (widget.job.running) startTicking();
  }

  @override
  void didUpdateWidget(JobIndicator old) {
    super.didUpdateWidget(old);
    widget.job.running ? startTicking() : stopTicking();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final s = widget.job;
    final short = jobProgressShort(s);
    final color = s.finished && !s.ok && !s.cancelled
        ? t.danger
        : (s.finished && s.ok ? t.positive : t.accent);
    return FocusFrame(
      focused: widget.focused,
      radius: HinterTokens.radiusPill,
      scale: 1.05,
      gap: HinterTokens.s2,
      style: t.focusStyle == FocusStyle.bar ? FocusStyle.ring : null,
      child: Container(
        key: const ValueKey('job-indicator'),
        padding: const EdgeInsets.fromLTRB(8, 6, HinterTokens.s2, 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusPill),
          border: Border.all(
            color: t.highContrast ? t.text : t.surfaceHigh,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Ring(
              fraction: s.running && s.percent != null
                  ? s.percent! / 100
                  : null,
              tick: tick,
              state: s.running
                  ? _RingState.running
                  : (s.ok ? _RingState.done : _RingState.failed),
              color: color,
            ),
            const SizedBox(width: HinterTokens.s1 + 4),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.compact ? 360 : 340,
                ),
                child: widget.compact
                    ? Text(
                        short,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: t.text),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jobTitle(s, name: widget.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              color: t.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            short,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RingState { running, done, failed }

class _Ring extends StatelessWidget {
  const _Ring({
    required this.fraction,
    required this.tick,
    required this.state,
    required this.color,
  });

  final double? fraction;
  final int tick;
  final _RingState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final paint = CustomPaint(
      size: const Size.square(44),
      painter: _RingPainter(
        fraction: fraction,
        state: state,
        color: color,
        track: t.surfaceHigh,
        mark: t.onAccent,
      ),
    );
    // Without a percentage the arc turns half a turn each tick.
    if (state != _RingState.running || fraction != null || t.reduceMotion) {
      return paint;
    }
    return AnimatedRotation(
      turns: tick * 0.5,
      duration: _move,
      curve: Curves.easeInOut,
      child: paint,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.state,
    required this.color,
    required this.track,
    required this.mark,
  });

  final double? fraction;
  final _RingState state;
  final Color color;
  final Color track;
  final Color mark;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 4;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    switch (state) {
      case _RingState.running:
        canvas.drawCircle(c, r, stroke..color = track);
        final sweep = fraction == null
            ? math.pi * 0.6
            : math.max(0.02, fraction!) * math.pi * 2;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          sweep,
          false,
          stroke..color = color,
        );
      case _RingState.done:
        canvas.drawCircle(c, r + 3, Paint()..color = color);
        canvas.drawPath(
          Path()
            ..moveTo(s.width * 0.28, s.height * 0.52)
            ..lineTo(s.width * 0.44, s.height * 0.68)
            ..lineTo(s.width * 0.74, s.height * 0.34),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = mark,
        );
      case _RingState.failed:
        canvas.drawCircle(c, r + 3, Paint()..color = color);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = mark;
        canvas.drawLine(
          Offset(s.width / 2, s.height * 0.26),
          Offset(s.width / 2, s.height * 0.58),
          p,
        );
        canvas.drawCircle(
          Offset(s.width / 2, s.height * 0.74),
          3,
          Paint()..color = mark,
        );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.fraction != fraction || o.state != state || o.color != color;
}
