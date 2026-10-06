import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../settings/launcher_settings.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'nav_focusable.dart';

/// One entry of the settings list and the options its detail pane offers.
class _Setting {
  const _Setting(this.id, this.title, this.blurb);

  final String id;
  final String title;
  final String blurb;
}

const _items = [
  _Setting(
    'text',
    'Text size',
    'Scales all text in the launcher. Layouts make room for it.',
  ),
  _Setting(
    'contrast',
    'High contrast',
    'Black background, white text and a yellow focus marker.',
  ),
  _Setting(
    'focus',
    'Focus marker',
    'How the selected card is marked. All styles differ in shape, not only colour.',
  ),
  _Setting(
    'motion',
    'Reduce motion',
    'No scaling or sliding; the focus marker still shows.',
  ),
  _Setting(
    'system',
    'System',
    'Network, Bluetooth, audio, display, updates and rollback.',
  ),
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
    required this.list,
    required this.detail,
    required this.onEnterDetail,
  });

  final SettingsController settings;
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
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
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
                            title: _items[i].title,
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
              const SizedBox(width: HinterTokens.s5),
              Expanded(
                child: _Detail(
                  setting: selected,
                  options: options,
                  region: detail,
                  settings: settings,
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
  });

  final _Setting setting;
  final List<_Option> options;
  final NavRegion region;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.all(HinterTokens.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(setting.title, style: t.headline),
          const SizedBox(height: HinterTokens.s1),
          Text(setting.blurb, style: t.bodyDim),
          const SizedBox(height: HinterTokens.s4),
          if (setting.id == 'system')
            // M5: Wi-Fi, Bluetooth, audio, display, updates, rollback.
            _Placeholder(t: t)
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.t});

  final HinterTokens t;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HinterTokens.s4),
        child: Text('System settings arrive with milestone M5.', style: t.body),
      ),
    );
  }
}
