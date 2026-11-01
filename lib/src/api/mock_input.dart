/// The controller settings of [MockDaemon] (session API 0.20,
/// `input.settings.*`, `input.capture`, `input_captured`): the stored
/// settings in memory, checked with the daemon's rules (one button per
/// action and one action per button, different click buttons, speed on its
/// step, keys that parse, known app ids), and a capture that a test answers
/// with [MockInputSettings.press] (or [MockInputSettings.script]).
library;

import 'dart:async';

import 'errors.dart';
import 'generated.dart';

/// The remappable buttons, in display order.
const mockControllerButtons = [
  'a',
  'b',
  'x',
  'y',
  'lb',
  'rb',
  'lt',
  'rt',
  'view',
  'menu',
];

/// The remappable actions, in display order.
const mockControllerActions = [
  'accept',
  'back',
  'context',
  'secondary',
  'menu',
  'view',
  'page_left',
  'page_right',
  'trigger_left',
  'trigger_right',
];

/// The actions of a keyboard-mode app's keymap: the directions too.
const mockKeyActions = [
  'up',
  'down',
  'left',
  'right',
  ...mockControllerActions,
];

const mockDefaultButtons = {
  'accept': 'a',
  'back': 'b',
  'secondary': 'x',
  'context': 'y',
  'page_left': 'lb',
  'page_right': 'rb',
  'trigger_left': 'lt',
  'trigger_right': 'rt',
  'view': 'view',
  'menu': 'menu',
};

const mockDefaultKeys = {
  'up': 'up',
  'down': 'down',
  'left': 'left',
  'right': 'right',
  'accept': 'enter',
  'back': 'escape',
};

const mockDefaultPointer = PointerSettings(
  speed: 100,
  swapSticks: false,
  leftClick: 'rt',
  rightClick: 'lt',
);

const mockModifiers = ['ctrl', 'alt', 'shift', 'meta'];

/// The fake keyboard-mode apps with their own catalog keys.
const mockKeyboardApps = [
  KeyboardApp(
    id: 'firefox',
    name: 'Firefox',
    keymap: {'page_left': 'alt+left', 'page_right': 'alt+right'},
  ),
  KeyboardApp(id: 'youtube', name: 'YouTube', keymap: {'context': 'f'}),
];

class MockInputSettings {
  MockInputSettings({
    required this.emit,
    List<KeyboardApp> apps = mockKeyboardApps,
  }) : apps = List.of(apps);

  static bool handles(String method) =>
      method == 'input.capture' || method.startsWith('input.settings.');

  final void Function(String name, Map<String, dynamic> params) emit;

  /// The profile's keyboard-mode apps.
  final List<KeyboardApp> apps;

  /// What `input.settings.set` stored last.
  ControllerSettings settings = const ControllerSettings();

  /// Every accepted `input.settings.set`, in order.
  final List<ControllerSettings> log = [];

  /// A capture runs: the next [press] is sent as `input_captured`.
  bool capturing = false;

  /// How many times `input.capture` was called.
  int captures = 0;

  /// Each capture is answered by itself with the next of these (null: Guide
  /// or the timeout) after [scriptDelay]; empty: a test calls [press].
  final List<String?> script = [];
  Duration scriptDelay = Duration.zero;

  /// The keys a [KeyComboName] may end with: the virtual keyboard's.
  static final keys = [for (final k in Key.values) k.value];

  InputSettings state() => InputSettings(
    settings: settings,
    defaults: const ControllerDefaults(
      general: mockDefaultButtons,
      keyboard: mockDefaultKeys,
      pointer: mockDefaultPointer,
    ),
    buttons: mockControllerButtons,
    actions: mockControllerActions,
    keyActions: mockKeyActions,
    keys: keys,
    modifiers: mockModifiers,
    speed: const InputSettingsSpeed(min: 25, max: 400, step: 25),
    apps: List.of(apps),
  );

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'input.settings.get':
        return state().toJson();
      case 'input.settings.set':
        final s = InputSettingsSetParams.fromJson(params).settings;
        _check(s);
        settings = s;
        log.add(s);
        return state().toJson();
      case 'input.capture':
        capturing = true;
        captures++;
        if (script.isNotEmpty) {
          final b = script.removeAt(0);
          Timer(scriptDelay, () => press(b));
        }
        return const InputCaptureResult().toJson();
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  /// A button press (a [mockControllerButtons] id or a direction), or null
  /// for Guide or the 10 s timeout. Ends a running capture with
  /// `input_captured`; without one, nothing happens.
  void press(String? button) {
    if (!capturing) return;
    capturing = false;
    emit('input_captured', InputCapturedEvent(button: button).toJson());
  }

  Never _bad(String field, String reason, String message) => throw ApiException(
    ApiErrorCode.invalidParams,
    message,
    {'field': field, 'reason': reason},
  );

  void _check(ControllerSettings s) {
    final general = s.general ?? const {};
    for (final e in general.entries) {
      if (!mockControllerActions.contains(e.key)) {
        _bad('settings.general', 'unknown_action', 'unknown action ${e.key}');
      }
      if (!mockControllerButtons.contains(e.value)) {
        _bad('settings.general', 'unknown_button', 'unknown button ${e.value}');
      }
    }
    final merged = {...mockDefaultButtons, ...general};
    for (final b in mockControllerButtons) {
      final on = [
        for (final a in mockControllerActions)
          if (merged[a] == b) a,
      ];
      if (on.length > 1) {
        _bad(
          'settings.general',
          'not_bijective',
          'general: $b has two actions (${on.join(', ')})',
        );
      }
    }
    _checkKeymap('settings.keyboard', 'keyboard', s.keyboard);
    for (final e in (s.apps ?? const {}).entries) {
      if (!apps.any((a) => a.id == e.key)) {
        _bad('settings.apps', 'unknown_app', "no keyboard app '${e.key}'");
      }
      final map = e.value;
      if (map is! Map) {
        _bad('settings.apps.${e.key}', 'invalid', 'not a keymap');
      }
      _checkKeymap(
        'settings.apps.${e.key}',
        'apps.${e.key}',
        map.cast<String, Object?>(),
      );
    }
    final p = s.pointer;
    if (p == null) return;
    final speed = p.speed;
    if (speed != null && (speed < 25 || speed > 400 || speed % 25 != 0)) {
      _bad(
        'settings.pointer.speed',
        'out_of_range',
        'pointer: speed must be 25 to 400 in steps of 25',
      );
    }
    for (final b in [p.leftClick, p.rightClick]) {
      if (b != null && !mockControllerButtons.contains(b)) {
        _bad('settings.pointer', 'unknown_button', 'unknown button $b');
      }
    }
    final left = p.leftClick ?? mockDefaultPointer.leftClick;
    final right = p.rightClick ?? mockDefaultPointer.rightClick;
    if (left == right) {
      _bad(
        'settings.pointer',
        'same_buttons',
        'pointer: left and right click are both $left',
      );
    }
  }

  void _checkKeymap(String field, String what, Map<String, Object?>? map) {
    for (final e in (map ?? const {}).entries) {
      if (!mockKeyActions.contains(e.key)) {
        _bad(field, 'unknown_action', 'unknown action ${e.key}');
      }
      final err = _comboError(e.value);
      if (err != null) _bad('$field.${e.key}', 'unknown_key', '$what: $err');
    }
  }

  /// Why [combo] does not parse as a key with modifiers (like the daemon's
  /// KeyCombo), or null.
  static String? _comboError(Object? combo) {
    if (combo is! String) return 'not a key';
    if (combo == 'none') return null;
    final parts = combo.split('+');
    final key = parts.removeLast();
    if (!keys.contains(key)) return "unknown key '$key' in '$combo'";
    for (final m in parts) {
      if (!mockModifiers.contains(m)) {
        return "unknown modifier '$m' in '$combo'";
      }
    }
    return null;
  }
}
