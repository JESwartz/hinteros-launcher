import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import '../system/repositories.dart';
import 'system/common.dart';
import 'system/hardware_sections.dart';
import 'system/network_sections.dart';
import 'system/storage_section.dart';
import 'system/system_sections.dart';
import 'system/time_zone_section.dart';
import 'common.dart' show EdgeFade;
import 'focus_frame.dart';
import 'nav_focusable.dart';
import 'profiles/profiles_section.dart';
import 'profiles/session_profile.dart';
import 'screen_saver.dart';

/// One setting: a section of a group's pane.
class _Setting {
  const _Setting(this.id, this.title);

  final String id;
  final String title;
}

/// One entry of the settings list: its settings show stacked in the pane.
class _Group {
  const _Group(this.id, this.title, this.entries);

  final String id;
  final String title;
  final List<_Setting> entries;
}

const _groups = [
  _Group('profiles', 'Profiles', [_Setting('profiles', 'Profiles')]),
  _Group('updates', 'Updates', [_Setting('updates', 'Updates')]),
  _Group('storage', 'Storage', [_Setting('storage', 'Storage')]),
  _Group('network', 'Network', [
    _Setting('net', 'Network'),
    _Setting('bt', 'Bluetooth'),
  ]),
  _Group('display_sound', 'Display and sound', [
    _Setting('display', 'Display'),
    _Setting('audio', 'Audio'),
    _Setting('screensaver', 'Screen saver'),
  ]),
  _Group('accessibility', 'Accessibility', [
    _Setting('text', 'Text size'),
    _Setting('contrast', 'High contrast'),
    _Setting('focus', 'Focus marker'),
    _Setting('motion', 'Reduce motion'),
    _Setting('osk_text', 'Show typed passwords on the on-screen keyboard'),
  ]),
  _Group('system', 'System', [
    _Setting('time', 'Time zone'),
    _Setting('power', 'Power'),
    _Setting('app_displays', 'Apps open at once'),
    _Setting('ssh', 'Remote access'),
    _Setting('about', 'About'),
  ]),
];

/// Ids of the settings list entries (the groups), in list order.
List<String> get settingsGroupIds => [for (final g in _groups) g.id];

/// Ids of all settings (the sections of the groups), in order.
List<String> get settingsEntryIds => [
  for (final g in _groups)
    for (final e in g.entries) e.id,
];

/// The list position of the group that holds setting [entryId] (a group id
/// gives its own position).
int settingsGroupIndexOf(String entryId) {
  final i = _groups.indexWhere(
    (g) => g.id == entryId || g.entries.any((e) => e.id == entryId),
  );
  if (i < 0) throw ArgumentError.value(entryId, 'entryId', 'no such setting');
  return i;
}

/// The position of setting [entryId] in its group's pane (0 for a group id).
int settingsSectionIndexOf(String entryId) {
  final g = _groups[settingsGroupIndexOf(entryId)];
  final i = g.entries.indexWhere((e) => e.id == entryId);
  return i < 0 ? 0 : i;
}

/// The navigation regions of Settings: the list, and one region per stacked
/// section of the open group. The first section uses the shell's [detail]
/// region; the others get their own, linked up and down in order, so focus
/// walks through all sections of a group as one list. Each section owns its
/// region as before (rows, move and Back handlers).
class SettingsRegions {
  SettingsRegions(this._nav, {required this.list, required this.detail}) {
    _setUp(detail);
    list.neighbors[NavDir.right] = detail;
  }

  final NavController _nav;
  final NavRegion list;

  /// The region of the first section of the open group.
  final NavRegion detail;
  final _more = <NavRegion>[];
  String? _group;
  int _count = 0;

  /// The section focus last went to: Right or Accept on the list returns
  /// there.
  late NavRegion _last = detail;

  /// A deep link waits for this section's rows.
  String? _pending;
  NavRegion? _waiting;
  VoidCallback? _waiter;

  /// The region of section [i] of the open group.
  NavRegion section(int i) {
    if (i == 0) return detail;
    while (_more.length < i) {
      final r = NavRegion('settings-detail-${_more.length + 1}');
      _nav.adopt(r);
      _setUp(r);
      _more.add(r);
    }
    return _more[i - 1];
  }

  void _setUp(NavRegion r) {
    r.passWhenEmpty = true;
    r.neighbors[NavDir.left] = list;
    r.backTarget = list;
    r.onEnter = (dir) {
      final rows = r.model.rows;
      if (dir == NavDir.down) {
        final i = rows.indexWhere((x) => x.length > 0);
        if (i >= 0) r.model.goTo(i, 0);
      } else if (dir == NavDir.up) {
        final i = rows.lastIndexWhere((x) => x.length > 0);
        if (i >= 0) r.model.goTo(i, 0);
      }
      if (dir == NavDir.up || dir == NavDir.down) _remember(r);
    };
  }

  void _remember(NavRegion r) {
    _last = r;
    list.neighbors[NavDir.right] = r;
  }

  /// Called by the screen on each build: group [id] with [count] sections
  /// shows. A new group starts at the top of its first section.
  void _show(String id, int count) {
    if (id != _group) {
      _group = id;
      for (var i = 0; i < _more.length + 1; i++) {
        final r = section(i);
        r.setRows(const []);
        r.model.reset();
      }
      _remember(detail);
      _cancelWait();
    }
    if (count != _count) {
      _count = count;
      for (var i = 0; i <= _more.length; i++) {
        final r = section(i);
        if (i + 1 < count) {
          final next = section(i + 1);
          r.neighbors[NavDir.down] = next;
          next.neighbors[NavDir.up] = r;
        } else {
          r.neighbors.remove(NavDir.down);
          if (i >= count) r.setRows(const []);
        }
      }
    }
    final p = _pending;
    if (p != null && settingsGroupIndexOf(p) == settingsGroupIds.indexOf(id)) {
      _pending = null;
      _focusWhenReady(section(settingsSectionIndexOf(p)));
    }
  }

  void _focusWhenReady(NavRegion r) {
    _cancelWait();
    _remember(r);
    void go() {
      _cancelWait();
      final i = r.model.rows.indexWhere((x) => x.length > 0);
      if (i >= 0) r.model.goTo(i, 0);
      _nav.focusRegion(r);
    }

    _waiting = r;
    _waiter = () {
      if (r.hasItems) go();
    };
    r.addListener(_waiter!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_waiting == r && r.hasItems) go();
    });
  }

  void _cancelWait() {
    final w = _waiter;
    if (w != null) _waiting?.removeListener(w);
    _waiting = null;
    _waiter = null;
  }

  /// A deep link: highlights in the list the group of [id] (a group id or a
  /// setting id). A setting inside a group of several (Bluetooth, Time zone)
  /// also gets focus as soon as its section has rows; the pane scrolls to
  /// it.
  void select(String id) {
    list.model.goTo(settingsGroupIndexOf(id), 0);
    // The screen's next build (now, or when Settings shows) takes it.
    _pending = settingsGroupIds.contains(id) ? null : id;
    list.changed();
  }

  /// Accept on the list: into the pane, where focus last was in it.
  void enter() => _nav.focusRegion(_last.hasItems ? _last : detail);

  /// Back to the first item everywhere (the Home button).
  void reset() {
    list.reset();
    detail.reset();
    for (final r in _more) {
      r.reset();
    }
    _remember(detail);
  }

  void dispose() {
    _cancelWait();
    for (final r in _more) {
      r.dispose();
    }
  }
}

class _Option {
  const _Option(this.label, this.selected, this.apply);

  final String label;
  final bool selected;
  final void Function(LauncherSettings s, SettingsController c) apply;
}

List<_Option> _onOff(
  bool value,
  LauncherSettings Function(LauncherSettings s, bool v) set,
) => [
  _Option('Off', !value, (s, c) => c.update(set(s, false))),
  _Option('On', value, (s, c) => c.update(set(s, true))),
];

List<_Option> _options(String id, LauncherSettings s) => switch (id) {
  'text' => [
    for (final v in LauncherSettings.textScaleSteps)
      _Option(
        '${(v * 100).round()}%',
        s.textScale == v,
        (s, c) => c.update(s.copyWith(textScale: v)),
      ),
  ],
  'contrast' => _onOff(s.highContrast, (s, v) => s.copyWith(highContrast: v)),
  'focus' => [
    for (final f in FocusStyle.values)
      _Option(
        f.label,
        s.focusStyle == f,
        (s, c) => c.update(s.copyWith(focusStyle: f)),
      ),
  ],
  'motion' => _onOff(s.reduceMotion, (s, v) => s.copyWith(reduceMotion: v)),
  'osk_text' => _onOff(
    s.showTypedOnOsk,
    (s, v) => s.copyWith(showTypedOnOsk: v),
  ),
  _ => const [],
};

/// Settings: the groups on the left, the settings of the highlighted group
/// on the right, stacked in one scrolling pane (list-detail). Right/Accept on
/// the list enters the pane, Up/Down walk through all its sections, Left or
/// Back returns.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.services,
    required this.regions,
    this.profileSession,
    this.onShowScreenSaver,
    this.now,
  });

  /// The clock of the sections ("measured 2 hours ago"); fixed in tests.
  final DateTime Function()? now;

  /// The shell's profile session (Settings -> Profiles switches with it).
  final ProfileSession? profileSession;

  /// Settings > Screen saver: Show now.
  final VoidCallback? onShowScreenSaver;

  final SettingsController settings;
  final SystemServices services;
  final SettingsRegions regions;

  @override
  Widget build(BuildContext context) {
    final list = regions.list;
    list.setRows([for (final g in _groups) NavRow(g.id, 1)]);
    return ListenableBuilder(
      listenable: list,
      builder: (context, _) {
        final selected = _groups[list.model.row.clamp(0, _groups.length - 1)];
        regions._show(selected.id, selected.entries.length);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            HinterTokens.margin,
            HinterTokens.s2,
            HinterTokens.margin,
            HinterTokens.s4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 600,
                child: EdgeFade(
                  top: 24,
                  bottom: 24,
                  child: SingleChildScrollView(
                    // Room for the focus ring of the first and last rows,
                    // beyond the fades.
                    padding: const EdgeInsets.symmetric(
                      horizontal: HinterTokens.s2,
                      vertical: 24 + HinterTokens.focusRoom,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _groups.length; i++) ...[
                          if (i > 0) const SizedBox(height: HinterTokens.s2),
                          NavFocusable(
                            region: list,
                            rowKey: _groups[i].id,
                            col: 0,
                            onSelect: regions.enter,
                            builder: (_, f) => _ListRow(
                              title: _groups[i].title,
                              focused: f,
                              selected: _groups[i] == selected,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: HinterTokens.s5),
              Expanded(
                child: _Detail(
                  group: selected,
                  regions: regions,
                  settings: settings,
                  services: services,
                  profileSession: profileSession,
                  onShowScreenSaver: onShowScreenSaver,
                  now: now ?? DateTime.now,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.focused,
    required this.selected,
  });

  final String title;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? t.surfaceHigh : t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          border: t.highContrast
              ? Border.all(color: t.textDim, width: selected ? 4 : 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2 + 4,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pane of a group: its title, then each setting under its heading (a
/// group of one setting needs no heading), in one scroll view.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.group,
    required this.regions,
    required this.settings,
    required this.services,
    this.profileSession,
    this.onShowScreenSaver,
    this.now = DateTime.now,
  });

  final ProfileSession? profileSession;
  final VoidCallback? onShowScreenSaver;
  final DateTime Function() now;
  final _Group group;
  final SettingsRegions regions;
  final SettingsController settings;
  final SystemServices services;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final stacked = group.entries.length > 1;
    return EdgeFade(
      top: 24,
      bottom: 24,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HinterTokens.s2,
          HinterTokens.s2,
          HinterTokens.s2,
          24 + HinterTokens.focusRoom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: t.headline),
            for (var i = 0; i < group.entries.length; i++) ...[
              SizedBox(
                height: i == 0 || !stacked ? HinterTokens.s4 : HinterTokens.s5,
              ),
              if (stacked) ...[
                Text(group.entries[i].title, style: t.title),
                const SizedBox(height: HinterTokens.s2),
              ],
              KeyedSubtree(
                key: ValueKey('settings-section-${group.entries[i].id}'),
                child: _section(group.entries[i].id, regions.section(i)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String id, NavRegion region) {
    final env = SectionEnv(services: services, region: region, now: now);
    return switch (id) {
      'profiles' => ProfilesSection(env, session: profileSession),
      'net' => NetworkSection(env),
      'bt' => BluetoothSection(env),
      'display' => DisplaySection(env),
      'audio' => AudioSection(env),
      'screensaver' => ScreenSaverSection(
        region: region,
        settings: settings,
        onShow: onShowScreenSaver,
      ),
      'power' => PowerSection(env),
      'app_displays' => AppDisplaysSection(env),
      'time' => TimeZoneSection(env),
      'ssh' => RemoteAccessSection(env),
      'updates' => UpdatesSection(env),
      'storage' => StorageSection(env),
      'about' => AboutSection(env),
      _ => _OptionsSection(id: id, region: region, settings: settings),
    };
  }
}

/// A launcher setting: its options as a radio list, with a live preview
/// under them where one helps.
class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.id,
    required this.region,
    required this.settings,
  });

  final String id;
  final NavRegion region;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final options = _options(id, settings.value);
      region.setRows([
        for (var i = 0; i < options.length; i++) NavRow('o$i', 1),
      ]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: HinterTokens.s2),
            NavFocusable(
              region: region,
              rowKey: 'o$i',
              col: 0,
              onSelect: () => options[i].apply(settings.value, settings),
              builder: (_, f) => _OptionRow(option: options[i], focused: f),
            ),
          ],
          if (id == 'text' || id == 'focus') ...[
            const SizedBox(height: HinterTokens.s4),
            _Preview(id: id),
          ],
        ],
      );
    },
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.focused});

  final _Option option;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1,
      child: SizedBox(
        width: 520,
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
                // Radio mark: filled disc vs empty ring (shape, not colour).
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.text, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: option.selected
                      ? Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: HinterTokens.s2),
                Text(option.label, style: t.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live preview under the options (the text itself already follows the
/// setting; the focus style preview shows each style).
class _Preview extends StatelessWidget {
  const _Preview({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    switch (id) {
      case 'text':
        return Text(
          'The quick brown fox jumps over the lazy dog.',
          style: t.body,
        );
      case 'focus':
        return Padding(
          padding: const EdgeInsets.only(left: HinterTokens.s2),
          child: Row(
            children: [
              for (final s in FocusStyle.values) ...[
                FocusFrame(
                  focused: true,
                  style: s,
                  scale: 1,
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.surfaceHigh,
                        borderRadius: BorderRadius.circular(
                          HinterTokens.radiusCard,
                        ),
                      ),
                      child: Center(child: Text(s.label, style: t.caption)),
                    ),
                  ),
                ),
                const SizedBox(width: HinterTokens.s4),
              ],
            ],
          ),
        );
    }
    return const SizedBox.shrink();
  }
}
