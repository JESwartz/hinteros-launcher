import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../jobs.dart' show JobCenterScope;
import '../pages.dart' show showJobProgress;
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../profiles/profile_ui.dart' show profileColor, withBoxAdminPin;
import '../widgets.dart';
import 'common.dart';
import 'storage_ring.dart';

// ------------------------------------------------------------------ names

/// Who the ring's homes and app sets belong to: profile id -> name and
/// colour (`profiles.list`).
typedef ProfileNames = Map<String, ({String name, ProfileColor color})>;

/// What the screen calls [n]. Folder and game names are the only names that
/// come from the box; everything else is the launcher's own words.
String storageName(StorageNode n, ProfileNames who, {StorageNode? parent}) {
  String profile(String? id) =>
      who[id]?.name ??
      (id != null && id.startsWith('p') ? 'Profile ${id.substring(1)}' : '?');
  return switch (n.kind) {
    StorageKind.disk => 'Disk',
    StorageKind.system => 'System',
    StorageKind.apps => 'Apps',
    StorageKind.profile => profile(n.id),
    StorageKind.guest => 'Guest',
    StorageKind.other => 'Other',
    StorageKind.free => 'Free space',
    StorageKind.generation => 'Generation ${n.generation ?? '?'}',
    StorageKind.common => 'Shared by generations',
    StorageKind.appEnv => switch (n.id) {
      'starter' => 'Starter apps',
      'guest' => 'Guest',
      final id => profile(id),
    },
    StorageKind.shared => 'Shared by profiles',
    StorageKind.dir => n.name ?? 'Folder',
    StorageKind.files => 'Other files',
    StorageKind.steam => 'Steam games',
    StorageKind.steamGame => n.name ?? 'Game ${n.appId ?? ''}'.trim(),
    StorageKind.unknown => 'Other',
  };
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "Scanned 2 hours ago."
String measuredAgo(DateTime at, DateTime now) {
  final d = now.difference(at);
  String n(int v, String unit) => '$v $unit${v == 1 ? '' : 's'}';
  if (d.inMinutes < 1) return 'Scanned just now.';
  if (d.inHours < 1) return 'Scanned ${n(d.inMinutes, 'minute')} ago.';
  if (d.inDays < 1) return 'Scanned ${n(d.inHours, 'hour')} ago.';
  return 'Scanned ${n(d.inDays, 'day')} ago.';
}

// ------------------------------------------------------------------ colours

const _systemColor = Color(0xFF4C8DF6);
const _appsColor = Color(0xFF2BB3A3);
const _guestColor = Color(0xFF8E97AA);
const _otherColor = Color(0xFF5C6478);

/// A segment's colour: the top level by kind (a profile in its own colour),
/// the levels below in lighter and darker steps of the level's colour.
Color storageColor(
  StorageNode n,
  int index,
  ProfileNames who,
  HinterTokens t, {
  Color? base,
}) {
  Color top() => switch (n.kind) {
    StorageKind.system => _systemColor,
    StorageKind.apps => _appsColor,
    StorageKind.profile =>
      who[n.id] == null ? _guestColor : profileColor(who[n.id]!.color),
    StorageKind.guest => _guestColor,
    StorageKind.free => t.surfaceHigh,
    _ => _otherColor,
  };
  if (n.kind == StorageKind.free) return t.surfaceHigh;
  if (n.kind == StorageKind.other || n.kind == StorageKind.unknown) {
    return _otherColor;
  }
  if (base == null) return top();
  // The remainder nodes (shared, other files) in grey-ish, the rest in
  // steps of the level's colour.
  if (n.kind == StorageKind.files ||
      n.kind == StorageKind.common ||
      n.kind == StorageKind.shared) {
    return Color.lerp(base, _otherColor, 0.65)!;
  }
  final hsl = HSLColor.fromColor(base);
  final step = [0.0, 0.14, -0.12, 0.26, -0.2][index % 5];
  return hsl.withLightness((hsl.lightness + step).clamp(0.25, 0.8)).toColor();
}

// ------------------------------------------------------------------ section

class _Level {
  _Level(this.node, this.color);

  final StorageNode node;

  /// The colour its segment had one level up (null at the top).
  final Color? color;
  int selected = 0;
}

/// Settings -> Storage: the ring of what uses the disk, the disk's numbers,
/// Measure again, the two clean-ups and the automatic clean-up. Read-only:
/// nothing here deletes a file or removes an app.
///
/// Left and right go around the ring, A opens a segment that has more in
/// it, B goes back out (at the top: back to the settings list). Another
/// profile's home (or the guest's) opens with the admin PIN; the own one
/// opens directly.
class StorageSection extends StatefulWidget {
  const StorageSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  StorageMeasurement? _m;
  bool _loaded = false;
  Object? _error;
  ProfileNames _who = const {};
  CurrentProfile? _me;
  CleanupSettings? _auto;
  final _stack = <_Level>[];

  /// A home's tree is on its way.
  bool _opening = false;

  /// A line about the last thing that did not work.
  String? _note;

  /// A clean-up ran since the measurement: its numbers are old.
  bool _stale = false;

  SectionEnv get env => widget.env;
  StorageRepository get _storage => env.services.storage;

  @override
  void initState() {
    super.initState();
    env.region.interceptMove = _onMove;
    env.region.onBack = _onBack;
    unawaited(_load());
  }

  @override
  void dispose() {
    if (env.region.interceptMove == _onMove) env.region.interceptMove = null;
    if (env.region.onBack == _onBack) env.region.onBack = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await _storage.get();
      // Names and colours of the profiles, who this is, the automatic
      // clean-up: each is optional (the ring still works without them).
      ProfileNames who = const {};
      CurrentProfile? me;
      CleanupSettings? auto;
      try {
        final ps = await env.services.profiles.list();
        who = {
          for (final p in ps.profiles) p.id: (name: p.name, color: p.color),
        };
      } on SystemException {
        // A box before profiles.
      }
      try {
        me = await env.services.profiles.current();
      } on SystemException {
        // Unknown: every home then asks for the admin PIN.
      }
      try {
        auto = await _storage.cleanupSettings();
      } on SystemException {
        // The pickers start at the defaults.
      }
      if (!mounted) return;
      setState(() {
        _m = m;
        _who = who;
        _me = me;
        _auto = auto;
        _loaded = true;
        _error = null;
        _stack
          ..clear()
          ..addAll([if (m != null) _Level(m.root, null)]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loaded = false;
      });
    }
  }

  bool get _onRing => env.region.model.currentRow?.key == 'ring';

  _Level? get _level => _stack.isEmpty ? null : _stack.last;

  List<StorageNode> get _children => _level?.node.children ?? const [];

  /// Left and right go around the ring (and round the end).
  bool _onMove(NavDir dir) {
    final l = _level;
    if (!_onRing || l == null) return false;
    if (dir != NavDir.left && dir != NavDir.right) return false;
    // A home is opening: stay on the ring.
    if (_opening) return true;
    final n = _children.length;
    if (n == 0) return true;
    setState(() {
      l.selected = (l.selected + (dir == NavDir.right ? 1 : n - 1)) % n;
      _note = null;
    });
    return true;
  }

  /// B on the ring goes one level out; at the top it leaves (the list).
  bool _onBack() {
    if (!_onRing || _stack.length <= 1) return false;
    setState(() {
      _stack.removeLast();
      _note = null;
    });
    return true;
  }

  bool _own(String id) {
    final me = _me;
    if (me == null) return false;
    return me.guest ? id == CurrentProfile.guestId : me.id == id;
  }

  Future<void> _open() async {
    final l = _level;
    if (l == null || _opening || _children.isEmpty) return;
    final n = _children[l.selected.clamp(0, _children.length - 1)];
    if (!n.canOpen) return;
    final color = storageColor(
      n,
      l.selected,
      _who,
      HinterTheme.of(context),
      base: l.color,
    );
    if (!n.isHome) {
      setState(() => _stack.add(_Level(n, color)));
      return;
    }
    final id = n.homeId!;
    setState(() {
      _opening = true;
      _note = null;
    });
    StorageTree? tree;
    try {
      tree = _own(id)
          ? await _storage.tree(id)
          : await withBoxAdminPin(
              context,
              env.services.profiles,
              title: 'Open ${storageName(n, _who)}',
              action: (pin) => _storage.tree(id, adminPin: pin),
            );
    } on SystemException catch (e) {
      if (mounted) {
        setState(
          () => _note = e.kind == SystemErrorKind.notFound
              ? 'Not scanned yet. Scan now.'
              : e.message,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (tree != null) {
        _stack.add(_Level(n.withChildren(tree.root.children), color));
      }
    });
  }

  Future<void> _measure() async {
    final JobHandle h;
    try {
      h = await _storage.measure();
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
      return;
    }
    if (!mounted) return;
    var r = await showJobProgress(context, env.services, h);
    // Left while it runs: the numbers come when it is done.
    if (r != null && r.running) r = await _whenDone(h.jobId);
    if (!(r?.ok ?? false) || !mounted) return;
    _stale = false;
    await _load();
  }

  /// The end of a job whose page the person left.
  Future<JobSnapshot?> _whenDone(String jobId) => env.services.jobs
      .watch(jobId)
      .firstWhere((s) => s.finished)
      .then<JobSnapshot?>((s) => s, onError: (Object _) => null);

  Future<void> _cleanup(CleanupTarget target) async {
    final m = _m;
    final keep = await showCleanup(
      context,
      target: target,
      measurement: m,
      keep: (_auto ?? const CleanupSettings()).keep(target),
    );
    if (keep == null || !mounted) return;
    final JobHandle? job;
    try {
      job = await withBoxAdminPin(
        context,
        env.services.profiles,
        title: target == CleanupTarget.system
            ? 'Clean up the system'
            : 'Clean up profiles',
        action: (pin) => _storage.cleanup(target, keep, adminPin: pin),
      );
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
      return;
    }
    if (job == null || !mounted) return;
    // When the clean-up is done, a scan starts at once: the numbers on
    // the screen are then new, not the ones from before.
    final scan = Completer<JobHandle?>();
    final sub = env.services.jobs.watch(job.jobId).listen((s) {
      if (!s.finished || scan.isCompleted) return;
      if (!s.ok) return scan.complete(null);
      _storage.measure().then(
        scan.complete,
        onError: (Object _) => scan.complete(null),
      );
    }, onError: (Object _) => scan.isCompleted ? null : scan.complete(null));
    final center = JobCenterScope.maybeOf(context);
    final r = await showJobProgress(context, env.services, job);
    if (r != null && r.running) {
      // Left while it runs: the scan starts when it is done and shows in
      // the top bar; the numbers come when the scan is done.
      final h = await scan.future;
      unawaited(sub.cancel());
      if (h == null) {
        if (mounted) setState(() => _stale = true);
        return;
      }
      center?.follow(JobSnapshot(jobId: h.jobId, kind: h.kind));
      final done = await _whenDone(h.jobId);
      if (!mounted) return;
      if (done?.ok ?? false) {
        _stale = false;
        await _load();
      } else {
        setState(() => _stale = true);
      }
      return;
    }
    // Not awaited: a cancel future can finish outside the test zone.
    unawaited(sub.cancel());
    if (!(r?.ok ?? false) || !mounted) return;
    // The page closes only once the job is over: by then the scan was
    // asked for (or the clean-up failed).
    final h = scan.isCompleted ? await scan.future : null;
    if (!mounted) return;
    if (h == null) {
      setState(() => _stale = true);
      return;
    }
    final done = await showJobProgress(context, env.services, h);
    if (!mounted) return;
    if (done?.ok ?? false) {
      _stale = false;
      await _load();
    } else {
      setState(() => _stale = true);
    }
  }

  Future<void> _automatic() async {
    final now = _auto ?? const CleanupSettings();
    final want = await showAutomaticCleanup(context, now);
    if (want == null || want == now || !mounted) return;
    final ok = await runAdminJob(
      context,
      env.services,
      title: 'Automatic clean-up',
      start: (pin) => _storage.setCleanupSettings(want, adminPin: pin),
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _auto = want);
    } else {
      // Read it back: the job may have failed, the setting stays.
      try {
        final a = await _storage.cleanupSettings();
        if (mounted) setState(() => _auto = a);
      } on SystemException {
        // Keep what is shown.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    if (_error != null) {
      return (Pane(env.region)
            ..add(StatusLine(describeError(_error!), error: true))
            ..buttons('retry', [
              btn('Try again', () {
                setState(() => _error = null);
                unawaited(_load());
              }),
            ]))
          .build();
    }
    if (!_loaded) {
      env.region.setRows(const []);
      return const StatusLine('Loading...');
    }
    final p = Pane(env.region);
    final m = _m;
    if (m == null) {
      p.add(const StatusLine('Not scanned yet.'));
      p.item(
        'measure',
        onSelect: _measure,
        builder: (f) => SettingRow(title: 'Scan now', focused: f),
        gap: HinterTokens.s3,
      );
    } else {
      p.row('ring', 1, _ringRow(t, m), gap: 0);
      if (_note != null) p.add(StatusLine(_note!, error: true));
      if (_stale) {
        p.add(
          const StatusLine(
            'These numbers are from before the clean-up. Scan now.',
          ),
        );
      }
      p.item(
        'measure',
        onSelect: _measure,
        builder: (f) => SettingRow(
          title: 'Scan now',
          focused: f,
          trailing: Text(
            measuredAgo(m.measuredAt, env.now()),
            style: t.bodyDim,
          ),
        ),
        gap: HinterTokens.s3,
      );
    }
    p.item(
      'clean_system',
      onSelect: () => _cleanup(CleanupTarget.system),
      builder: (f) => SettingRow(title: 'Clean up the system', focused: f),
    );
    p.item(
      'clean_profiles',
      onSelect: () => _cleanup(CleanupTarget.profiles),
      builder: (f) => SettingRow(title: 'Clean up profiles', focused: f),
    );
    final a = _auto;
    p.item(
      'auto',
      onSelect: _automatic,
      builder: (f) => SettingRow(
        title: 'Automatic clean-up',
        focused: f,
        trailing: Text(
          a == null ? '' : (a.enable ? a.frequency.label : 'Off'),
          style: t.bodyDim,
        ),
      ),
    );
    return p.build();
  }

  Widget _ringRow(HinterTokens t, StorageMeasurement m) {
    final l = _level!;
    final kids = _children;
    final sel = kids.isEmpty ? -1 : l.selected.clamp(0, kids.length - 1);
    final angles = ringAngles([for (final k in kids) k.bytes]);
    final segments = [
      for (var i = 0; i < kids.length; i++)
        RingSegment(
          angles[i].$1,
          angles[i].$2,
          storageColor(kids[i], i, _who, t, base: l.color),
          openable: kids[i].canOpen,
        ),
    ];
    final node = sel < 0 ? null : kids[sel];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavFocusable(
          region: env.region,
          rowKey: 'ring',
          col: 0,
          onSelect: _open,
          builder: (_, f) => StorageRing(
            key: const ValueKey('storage-ring'),
            segments: segments,
            selected: sel,
            focused: f,
            busy: _opening,
            centerTitle: storageName(l.node, _who),
            centerSize: storageSize(l.node.bytes),
          ),
        ),
        const SizedBox(width: HinterTokens.s4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: HinterTokens.s4),
            child: _info(t, m, l, node),
          ),
        ),
      ],
    );
  }

  Widget _info(HinterTokens t, StorageMeasurement m, _Level l, StorageNode? n) {
    final lines = <Widget>[];
    if (n != null) {
      final total = l.node.bytes;
      final pct = total <= 0 ? 0 : (n.bytes * 100 / total);
      lines
        ..add(
          Row(
            children: [
              Flexible(
                child: Text(
                  storageName(n, _who),
                  key: const ValueKey('storage-selected-name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.title,
                ),
              ),
              // It opens: the same mark as on its segment.
              if (n.canOpen) ...[
                const SizedBox(width: HinterTokens.s2),
                const OpenCue(key: ValueKey('storage-open-cue')),
              ],
            ],
          ),
        )
        ..add(
          Text(
            storageSize(n.bytes),
            key: const ValueKey('storage-selected-size'),
            style: t.label,
          ),
        )
        ..add(
          Text(
            '${pct < 1 && n.bytes > 0 ? '<1' : pct.round()}% of '
            '${storageName(l.node, _who)}',
            style: t.bodyDim,
          ),
        );
      if (n.kind == StorageKind.generation) {
        lines.add(
          Text(
            [
              if (n.date != null) _date(n.date!),
              if (n.current) 'Current',
              if (n.booted) 'Started with',
            ].join(', '),
            style: t.bodyDim,
          ),
        );
      }
    }
    TableRow figure(String label, int bytes) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: HinterTokens.s3, bottom: 4),
          child: Text(label, style: t.bodyDim),
        ),
        Text(storageSize(bytes), style: t.body),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines,
        const SizedBox(height: HinterTokens.s4),
        Text('Disk', style: t.label),
        const SizedBox(height: HinterTokens.s1),
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            figure('Total', m.disk.totalBytes),
            figure('Used', m.disk.usedBytes),
            figure('Free', m.disk.freeBytes),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ steppers

/// A number or choice that left and right change, with an arrow on each
/// side that shows it can be pressed: the arrow of the side just pressed
/// lights up for a moment, an arrow at the end of the range is not drawn.
class StepperMark extends StatefulWidget {
  const StepperMark({
    super.key,
    required this.label,
    this.canDown = true,
    this.canUp = true,
    this.pulse = 0,
    this.pulseSide = 0,
  });

  final String label;
  final bool canDown;
  final bool canUp;

  /// Goes up with every press; [pulseSide] says which: -1 left, 1 right.
  final int pulse;
  final int pulseSide;

  @override
  State<StepperMark> createState() => _StepperMarkState();
}

class _StepperMarkState extends State<StepperMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  @override
  void didUpdateWidget(StepperMark old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse && widget.pulseSide != 0) {
      _lit.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _lit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    Widget arrow(bool left, bool on) => AnimatedBuilder(
      animation: _lit,
      builder: (_, _) {
        final side = left ? -1 : 1;
        final glow = on && widget.pulseSide == side ? 1 - _lit.value : 0.0;
        return CustomPaint(
          key: ValueKey(left ? 'stepper-left' : 'stepper-right'),
          size: const Size(40, 40),
          painter: _ArrowPainter(
            left: left,
            visible: on,
            color: Color.lerp(t.text, t.onAccent, glow)!,
            lit: t.accent.withValues(alpha: glow),
          ),
        );
      },
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(true, widget.canDown),
        const SizedBox(width: HinterTokens.s1),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: t.label,
          ),
        ),
        const SizedBox(width: HinterTokens.s1),
        arrow(false, widget.canUp),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.left,
    required this.visible,
    required this.color,
    required this.lit,
  });

  final bool left;
  final bool visible;
  final Color color;

  /// The disc behind a just-pressed arrow (transparent when not lit).
  final Color lit;

  @override
  void paint(Canvas canvas, Size s) {
    if (!visible) return;
    final c = s.center(Offset.zero);
    if (lit.a > 0) canvas.drawCircle(c, s.width / 2, Paint()..color = lit);
    const w = 10.0, h = 14.0;
    final p = left
        ? (Path()
            ..moveTo(c.dx + w / 2, c.dy - h)
            ..lineTo(c.dx - w / 2 - 2, c.dy)
            ..lineTo(c.dx + w / 2, c.dy + h))
        : (Path()
            ..moveTo(c.dx - w / 2, c.dy - h)
            ..lineTo(c.dx + w / 2 + 2, c.dy)
            ..lineTo(c.dx - w / 2, c.dy + h));
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter o) =>
      o.left != left ||
      o.visible != visible ||
      o.color != color ||
      o.lit != lit;
}

/// The warning a keep of 1 needs: no rollback for that part.
String? keepWarning(CleanupTarget target, int keep) {
  if (keep >= 2) return null;
  return target == CleanupTarget.system
      ? 'No older version stays. You cannot roll back the system.'
      : 'No older apps stay. Profiles cannot roll back their apps.';
}

// ------------------------------------------------------------------ clean-up

/// Asks how many generations a clean-up keeps (1 to 10, left and right),
/// shows what it frees (the measurement's estimate) and warns below 2.
/// Resolves with the number, or null when cancelled.
Future<int?> showCleanup(
  BuildContext context, {
  required CleanupTarget target,
  required StorageMeasurement? measurement,
  required int keep,
}) => ModalScope.of(context).show<int>(
  (context, modal) => CleanupDialog(
    modal: modal,
    target: target,
    measurement: measurement,
    keep: keep,
  ),
);

class CleanupDialog extends StatefulWidget {
  const CleanupDialog({
    super.key,
    required this.modal,
    required this.target,
    required this.measurement,
    required this.keep,
  });

  final ModalHandle<int> modal;
  final CleanupTarget target;
  final StorageMeasurement? measurement;
  final int keep;

  @override
  State<CleanupDialog> createState() => _CleanupDialogState();
}

class _CleanupDialogState extends State<CleanupDialog> {
  late int _keep = widget.keep.clamp(minKeep, maxKeep);
  int _pulse = 0;
  int _side = 0;

  @override
  void initState() {
    super.initState();
    widget.modal.region.interceptMove = _onMove;
  }

  bool _onMove(NavDir dir) {
    if (widget.modal.region.model.currentRow?.key != 'keep') return false;
    if (dir != NavDir.left && dir != NavDir.right) return false;
    final d = dir == NavDir.right ? 1 : -1;
    final k = (_keep + d).clamp(minKeep, maxKeep);
    if (k != _keep) {
      setState(() {
        _keep = k;
        _pulse++;
        _side = d;
      });
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows(const [NavRow('keep', 1), NavRow('buttons', 2)]);
    final system = widget.target == CleanupTarget.system;
    final e = widget.measurement?.estimate(widget.target, _keep);
    final warning = keepWarning(widget.target, _keep);
    return DialogCard(
      title: system ? 'Clean up the system' : 'Clean up profiles',
      children: [
        const SizedBox(height: HinterTokens.s2),
        NavFocusable(
          region: region,
          rowKey: 'keep',
          col: 0,
          scrollIntoView: false,
          builder: (_, f) => SettingRow(
            title: 'Versions to keep',
            focused: f,
            trailing: StepperMark(
              key: const ValueKey('keep-value'),
              label: '$_keep',
              pulse: _pulse,
              pulseSide: _side,
              canDown: _keep > minKeep,
              canUp: _keep < maxKeep,
            ),
          ),
        ),
        const SizedBox(height: HinterTokens.s3),
        Text(
          e == null
              ? 'Scan the disk to see what this frees.'
              : 'Frees about ${storageSize(e.bytes)}. '
                    'Removes ${e.generations} '
                    '${e.generations == 1 ? 'version' : 'versions'}.',
          key: const ValueKey('cleanup-estimate'),
          style: t.body,
        ),
        if (warning != null) ...[
          const SizedBox(height: HinterTokens.s2),
          StatusLine(
            warning,
            key: const ValueKey('cleanup-warning'),
            error: true,
          ),
        ],
        const SizedBox(height: HinterTokens.s2),
        Text("Needs the admin profile's PIN.", style: t.caption),
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: region,
          rowKey: 'buttons',
          buttons: [
            btn('Cancel', widget.modal.close),
            btn(
              'Clean up',
              () => widget.modal.close(_keep),
              primary: true,
              danger: warning != null,
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ automatic

/// The automatic clean-up: on or off, how often, and how many versions the
/// system and the profiles keep. Resolves with the new setting (Save), or
/// null when cancelled.
Future<CleanupSettings?> showAutomaticCleanup(
  BuildContext context,
  CleanupSettings now,
) => ModalScope.of(context).show<CleanupSettings>(
  (context, modal) => AutomaticCleanupDialog(modal: modal, initial: now),
);

class AutomaticCleanupDialog extends StatefulWidget {
  const AutomaticCleanupDialog({
    super.key,
    required this.modal,
    required this.initial,
  });

  final ModalHandle<CleanupSettings> modal;
  final CleanupSettings initial;

  @override
  State<AutomaticCleanupDialog> createState() => _AutomaticCleanupState();
}

class _AutomaticCleanupState extends State<AutomaticCleanupDialog> {
  late CleanupSettings _s = widget.initial;

  /// Presses per row and the side of the last one (the arrow lights up).
  final _pulse = <String, (int, int)>{};

  @override
  void initState() {
    super.initState();
    widget.modal.region.interceptMove = _onMove;
  }

  String? get _row => widget.modal.region.model.currentRow?.key;

  void _step(String? row, int d) {
    int keep(int v) => (v + d).clamp(minKeep, maxKeep);
    final f = CleanupFrequency.values;
    setState(() {
      final before = _s;
      _s = switch (row) {
        'enable' => _s.copyWith(enable: d > 0),
        'frequency' => _s.copyWith(
          frequency: f[(_s.frequency.index + d).clamp(0, f.length - 1)],
        ),
        'keep_system' => _s.copyWith(keepSystem: keep(_s.keepSystem)),
        'keep_profiles' => _s.copyWith(keepProfiles: keep(_s.keepProfiles)),
        _ => _s,
      };
      if (_s != before && row != null) {
        _pulse[row] = ((_pulse[row]?.$1 ?? 0) + 1, d);
      }
    });
  }

  bool _onMove(NavDir dir) {
    final row = _row;
    if (row == null || row == 'buttons') return false;
    if (dir != NavDir.left && dir != NavDir.right) return false;
    _step(row, dir == NavDir.right ? 1 : -1);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows(const [
      NavRow('enable', 1),
      NavRow('frequency', 1),
      NavRow('keep_system', 1),
      NavRow('keep_profiles', 1),
      NavRow('buttons', 2),
    ]);
    final s = _s;
    final f = CleanupFrequency.values;
    Widget row(String key, String title, Widget trailing, {VoidCallback? on}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: HinterTokens.s1 + 4),
          child: NavFocusable(
            region: region,
            rowKey: key,
            col: 0,
            scrollIntoView: false,
            onSelect: on,
            builder: (_, focused) => SettingRow(
              title: title,
              focused: focused,
              dim: key != 'enable' && !s.enable,
              trailing: trailing,
            ),
          ),
        );
    final warnings = [
      if (s.enable) ?keepWarning(CleanupTarget.system, s.keepSystem),
      if (s.enable) ?keepWarning(CleanupTarget.profiles, s.keepProfiles),
    ];
    return DialogCard(
      title: 'Automatic clean-up',
      children: [
        const SizedBox(height: HinterTokens.s1),
        row(
          'enable',
          'Clean up automatically',
          ToggleMark(on: s.enable),
          on: () => setState(() => _s = s.copyWith(enable: !s.enable)),
        ),
        row(
          'frequency',
          'How often',
          StepperMark(
            key: const ValueKey('auto-frequency'),
            pulse: _pulse['frequency']?.$1 ?? 0,
            pulseSide: _pulse['frequency']?.$2 ?? 0,
            label: s.frequency.label,
            canDown: s.frequency.index > 0,
            canUp: s.frequency.index < f.length - 1,
          ),
        ),
        row(
          'keep_system',
          'System versions to keep',
          StepperMark(
            key: const ValueKey('auto-keep-system'),
            pulse: _pulse['keep_system']?.$1 ?? 0,
            pulseSide: _pulse['keep_system']?.$2 ?? 0,
            label: '${s.keepSystem}',
            canDown: s.keepSystem > minKeep,
            canUp: s.keepSystem < maxKeep,
          ),
        ),
        row(
          'keep_profiles',
          'App versions to keep',
          StepperMark(
            key: const ValueKey('auto-keep-profiles'),
            pulse: _pulse['keep_profiles']?.$1 ?? 0,
            pulseSide: _pulse['keep_profiles']?.$2 ?? 0,
            label: '${s.keepProfiles}',
            canDown: s.keepProfiles > minKeep,
            canUp: s.keepProfiles < maxKeep,
          ),
        ),
        for (final w in warnings) ...[
          const SizedBox(height: HinterTokens.s1),
          StatusLine(w, error: true),
        ],
        const SizedBox(height: HinterTokens.s2),
        Text("Saving needs the admin profile's PIN.", style: t.caption),
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: region,
          rowKey: 'buttons',
          buttons: [
            btn('Cancel', widget.modal.close),
            btn('Save', () => widget.modal.close(_s), primary: true),
          ],
        ),
      ],
    );
  }
}
