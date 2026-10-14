import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
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

/// "Measured 2 hours ago."
String measuredAgo(DateTime at, DateTime now) {
  final d = now.difference(at);
  String n(int v, String unit) => '$v $unit${v == 1 ? '' : 's'}';
  if (d.inMinutes < 1) return 'Measured just now.';
  if (d.inHours < 1) return 'Measured ${n(d.inMinutes, 'minute')} ago.';
  if (d.inDays < 1) return 'Measured ${n(d.inHours, 'hour')} ago.';
  return 'Measured ${n(d.inDays, 'day')} ago.';
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
              ? 'This is not measured yet. Measure again.'
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
    final ok = await runJob(context, env.services, _storage.measure);
    if (!ok || !mounted) return;
    _stale = false;
    await _load();
  }

  Future<void> _cleanup(CleanupTarget target) async {
    final m = _m;
    final keep = await showCleanup(
      context,
      target: target,
      measurement: m,
      keep: (_auto ?? const CleanupSettings()).keep(target),
    );
    if (keep == null || !mounted) return;
    final ok = await runAdminJob(
      context,
      env.services,
      title: target == CleanupTarget.system
          ? 'Clean up the system'
          : 'Clean up profiles',
      start: (pin) => _storage.cleanup(target, keep, adminPin: pin),
    );
    if (ok && mounted) setState(() => _stale = true);
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
      p.add(const StatusLine('The disk is not measured yet.'));
      p.item(
        'measure',
        onSelect: _measure,
        builder: (f) => SettingRow(title: 'Measure the disk', focused: f),
        gap: HinterTokens.s3,
      );
    } else {
      p.row('ring', 1, _ringRow(t, m), gap: 0);
      if (_note != null) p.add(StatusLine(_note!, error: true));
      if (_stale) {
        p.add(
          const StatusLine(
            'These numbers are from before the clean-up. Measure again.',
          ),
        );
      }
      p.item(
        'measure',
        onSelect: _measure,
        builder: (f) => SettingRow(
          title: 'Measure again',
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
          Text(
            storageName(n, _who),
            key: const ValueKey('storage-selected-name'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.title,
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
      final hint = [
        if (n.canOpen) 'A opens it.',
        if (_stack.length > 1) 'B goes back.',
      ].join(' ');
      if (hint.isNotEmpty) {
        lines
          ..add(const SizedBox(height: HinterTokens.s1))
          ..add(Text(hint, style: t.caption));
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

/// A number or choice that left and right change: arrows either side,
/// dimmed at the ends (shape and words, not only colour).
class StepperMark extends StatelessWidget {
  const StepperMark({
    super.key,
    required this.label,
    this.canDown = true,
    this.canUp = true,
  });

  final String label;
  final bool canDown;
  final bool canUp;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    Widget arrow(bool left, bool on) => CustomPaint(
      size: const Size(20, 28),
      painter: _ArrowPainter(
        left,
        on ? t.text : t.textDim.withValues(alpha: 0.35),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(true, canDown),
        const SizedBox(width: HinterTokens.s2),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48),
          child: Text(label, textAlign: TextAlign.center, style: t.label),
        ),
        const SizedBox(width: HinterTokens.s2),
        arrow(false, canUp),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.left, this.color);

  final bool left;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path();
    if (left) {
      p
        ..moveTo(s.width, 0)
        ..lineTo(0, s.height / 2)
        ..lineTo(s.width, s.height);
    } else {
      p
        ..moveTo(0, 0)
        ..lineTo(s.width, s.height / 2)
        ..lineTo(0, s.height);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter o) => o.left != left || o.color != color;
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

  @override
  void initState() {
    super.initState();
    widget.modal.region.interceptMove = _onMove;
  }

  bool _onMove(NavDir dir) {
    if (widget.modal.region.model.currentRow?.key != 'keep') return false;
    if (dir != NavDir.left && dir != NavDir.right) return false;
    final k = (_keep + (dir == NavDir.right ? 1 : -1)).clamp(minKeep, maxKeep);
    if (k != _keep) setState(() => _keep = k);
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
        Text(
          system
              ? 'Removes old versions of HinterOS and the files that nothing '
                    'uses.'
              : 'Removes old versions of the apps of every profile and the '
                    'files that nothing uses.',
          style: t.bodyDim,
        ),
        const SizedBox(height: HinterTokens.s3),
        NavFocusable(
          region: region,
          rowKey: 'keep',
          col: 0,
          scrollIntoView: false,
          builder: (_, f) => SettingRow(
            title: 'Versions to keep',
            subtitle: 'Left and right change it.',
            focused: f,
            trailing: StepperMark(
              key: const ValueKey('keep-value'),
              label: '$_keep',
              canDown: _keep > minKeep,
              canUp: _keep < maxKeep,
            ),
          ),
        ),
        const SizedBox(height: HinterTokens.s3),
        Text(
          e == null
              ? 'Measure the disk to see what this frees.'
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
      _s = switch (row) {
        'enable' => _s.copyWith(enable: d > 0),
        'frequency' => _s.copyWith(
          frequency: f[(_s.frequency.index + d).clamp(0, f.length - 1)],
        ),
        'keep_system' => _s.copyWith(keepSystem: keep(_s.keepSystem)),
        'keep_profiles' => _s.copyWith(keepProfiles: keep(_s.keepProfiles)),
        _ => _s,
      };
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
