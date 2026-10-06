import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// How the focused card is marked. Every style uses shape and thickness, not
/// only colour, so it works for colour-blind users.
enum FocusStyle {
  /// Thick white ring with a dark gap, plus scale. The default.
  ring('Ring'),

  /// Thin ring plus a wide soft glow and scale.
  glow('Glow'),

  /// A thick bar under the card plus scale.
  bar('Bar');

  const FocusStyle(this.label);
  final String label;
}

/// Local-only launcher preferences (the daemon knows nothing about these).
@immutable
class LauncherSettings {
  const LauncherSettings({
    this.textScale = 1.0,
    this.highContrast = false,
    this.focusStyle = FocusStyle.ring,
    this.reduceMotion = false,
    this.showTypedOnOsk = false,
  });

  static const minTextScale = 1.0;
  static const maxTextScale = 1.6;

  /// The steps offered in Settings.
  static const textScaleSteps = [1.0, 1.2, 1.4, 1.6];

  final double textScale;
  final bool highContrast;
  final FocusStyle focusStyle;
  final bool reduceMotion;

  /// Show what was typed in the on-screen keyboard's preview strip. Off
  /// (the default) masks it with dots, so passwords do not appear on the TV;
  /// only the latest character shows briefly.
  final bool showTypedOnOsk;

  LauncherSettings copyWith({
    double? textScale,
    bool? highContrast,
    FocusStyle? focusStyle,
    bool? reduceMotion,
    bool? showTypedOnOsk,
  }) => LauncherSettings(
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    focusStyle: focusStyle ?? this.focusStyle,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    showTypedOnOsk: showTypedOnOsk ?? this.showTypedOnOsk,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'text_scale': textScale,
    'high_contrast': highContrast,
    'focus_style': focusStyle.name,
    'reduce_motion': reduceMotion,
    'osk_show_typed': showTypedOnOsk,
  };

  /// Lenient: wrong types or unknown values fall back to the default for that
  /// field, so a hand-edited or newer file never breaks the launcher.
  factory LauncherSettings.fromJson(Map<String, dynamic> j) {
    const d = LauncherSettings();
    final scale = j['text_scale'];
    return LauncherSettings(
      textScale: scale is num
          ? scale.toDouble().clamp(minTextScale, maxTextScale)
          : d.textScale,
      highContrast: j['high_contrast'] is bool
          ? j['high_contrast'] as bool
          : d.highContrast,
      focusStyle: FocusStyle.values.firstWhere(
        (s) => s.name == j['focus_style'],
        orElse: () => d.focusStyle,
      ),
      reduceMotion: j['reduce_motion'] is bool
          ? j['reduce_motion'] as bool
          : d.reduceMotion,
      showTypedOnOsk: j['osk_show_typed'] is bool
          ? j['osk_show_typed'] as bool
          : d.showTypedOnOsk,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LauncherSettings &&
      other.textScale == textScale &&
      other.highContrast == highContrast &&
      other.focusStyle == focusStyle &&
      other.reduceMotion == reduceMotion &&
      other.showTypedOnOsk == showTypedOnOsk;

  @override
  int get hashCode => Object.hash(
    textScale,
    highContrast,
    focusStyle,
    reduceMotion,
    showTypedOnOsk,
  );
}

/// Where settings live.
abstract class SettingsStorage {
  Future<LauncherSettings> load();
  Future<void> save(LauncherSettings settings);
}

/// Not persisted (tests, goldens).
class MemorySettingsStorage implements SettingsStorage {
  MemorySettingsStorage([this.value = const LauncherSettings()]);
  LauncherSettings value;

  @override
  Future<LauncherSettings> load() async => value;

  @override
  Future<void> save(LauncherSettings settings) async => value = settings;
}

/// `$XDG_CONFIG_HOME/hinteros/launcher.json` (default `~/.config/...`).
class FileSettingsStorage implements SettingsStorage {
  FileSettingsStorage(this.file);

  factory FileSettingsStorage.xdg({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final xdg = env['XDG_CONFIG_HOME'];
    final home = env['HOME'];
    final base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : '${home ?? '.'}/.config';
    return FileSettingsStorage(File('$base/hinteros/launcher.json'));
  }

  final File file;

  @override
  Future<LauncherSettings> load() async {
    try {
      final j = jsonDecode(await file.readAsString());
      if (j is Map<String, dynamic>) return LauncherSettings.fromJson(j);
    } catch (_) {
      // Missing or corrupt: defaults.
    }
    return const LauncherSettings();
  }

  /// Writes atomically (temp file, then rename).
  @override
  Future<void> save(LauncherSettings settings) async {
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n',
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('could not save settings to ${file.path}: $e');
    }
  }
}

/// Holds the current settings and persists every change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._storage, [this._value = const LauncherSettings()]);

  /// Loads from [storage] first.
  static Future<SettingsController> load(SettingsStorage storage) async =>
      SettingsController(storage, await storage.load());

  final SettingsStorage _storage;
  LauncherSettings _value;

  LauncherSettings get value => _value;

  void update(LauncherSettings next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
    _storage.save(next);
  }
}
