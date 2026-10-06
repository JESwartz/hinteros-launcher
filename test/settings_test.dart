import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/theme/hinter_theme.dart';

import 'support/harness.dart';

void main() {
  test('defaults and JSON round trip', () {
    const s = LauncherSettings(
      textScale: 1.4,
      highContrast: true,
      focusStyle: FocusStyle.bar,
      reduceMotion: true,
      showTypedOnOsk: true,
    );
    expect(LauncherSettings.fromJson(s.toJson()), s);
    expect(s.toJson()['osk_show_typed'], true);
    // Privacy: masked unless asked, also for a bad value.
    expect(const LauncherSettings().showTypedOnOsk, false);
    expect(
      LauncherSettings.fromJson({'osk_show_typed': 1}).showTypedOnOsk,
      false,
    );
    expect(LauncherSettings.fromJson({}), const LauncherSettings());
  });

  test('bad values fall back per field and text scale is clamped', () {
    final s = LauncherSettings.fromJson({
      'text_scale': 9,
      'high_contrast': 'yes',
      'focus_style': 'sparkles',
      'reduce_motion': true,
    });
    expect(s.textScale, 1.6);
    expect(s.highContrast, false);
    expect(s.focusStyle, FocusStyle.ring);
    expect(s.reduceMotion, true);
  });

  test('file storage: XDG path, persistence, corrupt file', () async {
    final dir = tempDir();
    final s = FileSettingsStorage.xdg(
      environment: {'XDG_CONFIG_HOME': dir.path, 'HOME': '/nonexistent'},
    );
    expect(s.file.path, '${dir.path}/hinteros/launcher.json');
    expect(await s.load(), const LauncherSettings()); // missing

    final c = await SettingsController.load(s);
    c.update(c.value.copyWith(textScale: 1.2, highContrast: true));
    // update() saves without awaiting; load() reads after it.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final json = jsonDecode(s.file.readAsStringSync()) as Map;
    expect(json['text_scale'], 1.2);
    expect(json['high_contrast'], true);
    expect((await s.load()).textScale, 1.2);

    s.file.writeAsStringSync('{ not json');
    expect(await s.load(), const LauncherSettings());
  });

  test('HOME fallback when XDG_CONFIG_HOME is unset', () {
    final s = FileSettingsStorage.xdg(environment: {'HOME': '/home/x'});
    expect(s.file.path, '/home/x/.config/hinteros/launcher.json');
  });

  test('tokens: high contrast palette and motion', () {
    final std = HinterTokens.fromSettings(const LauncherSettings());
    final hc = HinterTokens.fromSettings(
      const LauncherSettings(highContrast: true, reduceMotion: true),
    );
    expect(hc.background, const Color(0xFF000000));
    expect(hc.text, const Color(0xFFFFFFFF));
    expect(hc.focusRing, isNot(std.focusRing));
    expect(std.fast, isNot(Duration.zero));
    expect(hc.fast, Duration.zero);
    expect(HinterTokens.fsCaption, greaterThanOrEqualTo(24));
  });

  testWidgets('changing a setting in the UI persists and applies', (t) async {
    setView(t);
    final h = Harness();
    await h.pump(t);
    // Settings > Text size > 160%
    for (final k in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
    ]) {
      await t.sendKeyEvent(k);
      await t.pumpAndSettle();
    }
    expect(h.settings.value.textScale, 1.6);
    expect(h.storage.value.textScale, 1.6, reason: 'saved');
  });

  testWidgets(
    "the on-screen keyboard text setting is off, and toggles in the UI",
    (t) async {
      setView(t);
      final h = Harness();
      await h.pump(t);
      expect(h.settings.value.showTypedOnOsk, false);
      // Settings > the fifth entry (on-screen keyboard text) > On
      for (final k in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ]) {
        await t.sendKeyEvent(k);
        await t.pumpAndSettle();
      }
      expect(h.settings.value.showTypedOnOsk, true);
      expect(h.storage.value.showTypedOnOsk, true, reason: "saved");
    },
  );
}
