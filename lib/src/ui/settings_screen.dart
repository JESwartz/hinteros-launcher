import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import '../system/repositories.dart';
import 'system/common.dart';
import 'system/hardware_sections.dart';
import 'system/network_sections.dart';
import 'system/system_sections.dart';
import 'common.dart' show EdgeFade;
import 'focus_frame.dart';
import 'nav_focusable.dart';
import 'profiles/profiles_section.dart';
import 'profiles/session_profile.dart';

/// One entry of the settings list and the options its detail pane offers.
class _Setting {
  const _Setting(this.id, this.title, [this.listTitle]);

  final String id;
  final String title;

  /// A shorter title for the list, where the full one would not fit.
  final String? listTitle;
}

const _items = [
  _Setting('text', 'Text size'),
  _Setting('contrast', 'High contrast'),
  _Setting('focus', 'Focus marker'),
  _Setting('motion', 'Reduce motion'),
  _Setting(
    'osk_text',
    'Show typed passwords on the on-screen keyboard',
    'Typed passwords on keyboard',
  ),
  _Setting('profiles', 'Profiles'),
  _Setting('net', 'Network'),
  _Setting('bt', 'Bluetooth'),
  _Setting('display', 'Display'),
  _Setting('audio', 'Audio'),
  _Setting('power', 'Power'),
  _Setting('ssh', 'Remote access'),
  _Setting('updates', 'Updates'),
  _Setting('about', 'About'),
];

class _Option {
  const _Option(this.label, this.selected, this.apply);

  final String label;
  final bool selected;
  final void Function(LauncherSettings s, SettingsController c) apply;
}

String _valueOf(String id, LauncherSettings s) => switch (id) {
  'text' => '${(s.textScale * 100).round()}%',
  'contrast' => s.highContrast ? 'On' : 'Off',
  'focus' => s.focusStyle.label,
  'motion' => s.reduceMotion ? 'On' : 'Off',
  'osk_text' => s.showTypedOnOsk ? 'On' : 'Off',
  _ => '',
};

List<_Option> _options(String id, LauncherSettings s) {
  switch (id) {
    case 'text':
      return [
        for (final v in LauncherSettings.textScaleSteps)
          _Option(
            '${(v * 100).round()}%',
            s.textScale == v,
            (s, c) => c.update(s.copyWith(textScale: v)),
          ),
      ];
    case 'contrast':
      return [
        _Option(
          'Off',
          !s.highContrast,
          (s, c) => c.update(s.copyWith(highContrast: false)),
        ),
        _Option(
          'On',
          s.highContrast,
          (s, c) => c.update(s.copyWith(highContrast: true)),
        ),
      ];
    case 'focus':
      return [
        for (final f in FocusStyle.values)
          _Option(
            f.label,
            s.focusStyle == f,
            (s, c) => c.update(s.copyWith(focusStyle: f)),
          ),
      ];
    case 'osk_text':
      return [
        _Option(
          'Off',
          !s.showTypedOnOsk,
          (s, c) => c.update(s.copyWith(showTypedOnOsk: false)),
        ),
        _Option(
          'On',
          s.showTypedOnOsk,
          (s, c) => c.update(s.copyWith(showTypedOnOsk: true)),
        ),
      ];
    case 'motion':
      return [
        _Option(
          'Off',
          !s.reduceMotion,
          (s, c) => c.update(s.copyWith(reduceMotion: false)),
        ),
        _Option(
          'On',
          s.reduceMotion,
          (s, c) => c.update(s.copyWith(reduceMotion: true)),
        ),
      ];
  }
  return const [];
}

/// Settings: a list on the left, the options of the highlighted entry on the
/// right (list-detail). Right/Accept on the list enters the detail pane, Left
/// or Back returns. Only local launcher settings exist for now; the System
/// entry is a placeholder.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.services,
    required this.list,
    required this.detail,
    required this.onEnterDetail,
    this.profileSession,
  });

  /// The shell's profile session (Settings -> Profiles switches with it).
  final ProfileSession? profileSession;

  final SettingsController settings;
  final SystemServices services;
  final NavRegion list;
  final NavRegion detail;

  /// Accept on a list entry: move focus into the detail pane.
  final VoidCallback onEnterDetail;

  @override
  Widget build(BuildContext context) {
    list.setRows([for (final i in _items) NavRow(i.id, 1)]);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, list]),
      builder: (context, _) {
        final s = settings.value;
        final selected = _items[list.model.row.clamp(0, _items.length - 1)];
        final options = _options(selected.id, s);
        detail.setRows([
          for (var i = 0; i < options.length; i++) NavRow('o$i', 1),
        ]);
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
                    padding: const EdgeInsets.all(HinterTokens.s2),
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++) ...[
                          if (i > 0) const SizedBox(height: HinterTokens.s2),
                          NavFocusable(
                            region: list,
                            rowKey: _items[i].id,
                            col: 0,
                            onSelect: onEnterDetail,
                            builder: (_, f) => _ListRow(
                              title: _items[i].listTitle ?? _items[i].title,
                              value: _valueOf(_items[i].id, s),
                              focused: f,
                              selected: _items[i] == selected,
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
                  setting: selected,
                  options: options,
                  region: detail,
                  settings: settings,
                  services: services,
                  profileSession: profileSession,
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
    required this.value,
    required this.focused,
    required this.selected,
  });

  final String title;
  final String value;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusSmall,
      scale: 1.03,
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (value.isNotEmpty) Text(value, style: t.bodyDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.setting,
    required this.options,
    required this.region,
    required this.settings,
    required this.services,
    this.profileSession,
  });

  final ProfileSession? profileSession;
  final _Setting setting;
  final List<_Option> options;
  final NavRegion region;
  final SettingsController settings;
  final SystemServices services;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return EdgeFade(
      top: 24,
      bottom: 24,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HinterTokens.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(setting.title, style: t.headline),
            const SizedBox(height: HinterTokens.s4),
            if (_systemIds.contains(setting.id))
              KeyedSubtree(
                key: ValueKey(setting.id),
                child: setting.id == 'profiles'
                    ? ProfilesSection(
                        SectionEnv(services: services, region: region),
                        session: profileSession,
                      )
                    : _systemSection(
                        setting.id,
                        SectionEnv(services: services, region: region),
                      ),
              )
            else ...[
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
              const SizedBox(height: HinterTokens.s4),
              _Preview(id: setting.id),
            ],
          ],
        ),
      ),
    );
  }
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
      scale: 1.02,
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

/// The entries that show a system section instead of local options.
const _systemIds = {
  'profiles',
  'net',
  'bt',
  'display',
  'audio',
  'power',
  'ssh',
  'updates',
  'about',
};

Widget _systemSection(String id, SectionEnv env) => switch (id) {
  'net' => NetworkSection(env),
  'bt' => BluetoothSection(env),
  'display' => DisplaySection(env),
  'audio' => AudioSection(env),
  'power' => PowerSection(env),
  'ssh' => RemoteAccessSection(env),
  'updates' => UpdatesSection(env),
  _ => AboutSection(env),
};

/// Ids of the settings entries, in list order.
List<String> get settingsEntryIds => [for (final i in _items) i.id];
