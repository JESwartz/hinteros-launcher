/// The controller settings of a profile (session API 0.20,
/// `input.settings.*`, `input.capture`): which button does which action, the
/// keys keyboard-mode apps get, the pointer. The models, the changes the
/// screens make, and the repository.
library;

import 'package:flutter/foundation.dart';

/// The pointer settings: all four in the defaults, only the changed ones in
/// the stored settings.
@immutable
class PointerPrefs {
  const PointerPrefs({
    this.speed,
    this.swapSticks,
    this.leftClick,
    this.rightClick,
  });

  final int? speed;
  final bool? swapSticks;
  final String? leftClick;
  final String? rightClick;

  bool get isEmpty =>
      speed == null &&
      swapSticks == null &&
      leftClick == null &&
      rightClick == null;

  @override
  bool operator ==(Object other) =>
      other is PointerPrefs &&
      other.speed == speed &&
      other.swapSticks == swapSticks &&
      other.leftClick == leftClick &&
      other.rightClick == rightClick;

  @override
  int get hashCode => Object.hash(speed, swapSticks, leftClick, rightClick);
}

/// What the user changed (the stored form, `controller.json`): action to
/// button, action to key for every keyboard app, per app, the pointer.
@immutable
class StoredController {
  const StoredController({
    this.general = const {},
    this.keyboard = const {},
    this.apps = const {},
    this.pointer = const PointerPrefs(),
  });

  final Map<String, String> general;
  final Map<String, String> keyboard;
  final Map<String, Map<String, String>> apps;
  final PointerPrefs pointer;

  StoredController copyWith({
    Map<String, String>? general,
    Map<String, String>? keyboard,
    Map<String, Map<String, String>>? apps,
    PointerPrefs? pointer,
  }) => StoredController(
    general: general ?? this.general,
    keyboard: keyboard ?? this.keyboard,
    apps: apps ?? this.apps,
    pointer: pointer ?? this.pointer,
  );

  @override
  bool operator ==(Object other) =>
      other is StoredController &&
      mapEquals(other.general, general) &&
      mapEquals(other.keyboard, keyboard) &&
      other.apps.length == apps.length &&
      apps.entries.every((e) => mapEquals(other.apps[e.key], e.value)) &&
      other.pointer == pointer;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(general.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(keyboard.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(apps.keys),
    pointer,
  );

  @override
  String toString() =>
      'StoredController(general: $general, keyboard: $keyboard, apps: $apps)';
}

/// A keyboard-mode app and its own keys (catalog or config).
@immutable
class KeyboardAppKeys {
  const KeyboardAppKeys({
    required this.id,
    required this.name,
    required this.keymap,
  });

  final String id;
  final String name;
  final Map<String, String> keymap;
}

/// `input.settings.get`: the stored settings, the defaults and what may be
/// set. The getters give the settings in effect; the `with...` methods give
/// the stored settings for a change, ready for [ControllerRepository.set].
@immutable
class ControllerState {
  const ControllerState({
    required this.stored,
    required this.defaultButtons,
    required this.defaultKeys,
    required this.defaultPointer,
    required this.buttons,
    required this.actions,
    required this.keyActions,
    required this.keys,
    required this.modifiers,
    required this.speedMin,
    required this.speedMax,
    required this.speedStep,
    required this.apps,
  });

  final StoredController stored;
  final Map<String, String> defaultButtons;
  final Map<String, String> defaultKeys;
  final PointerPrefs defaultPointer;
  final List<String> buttons;
  final List<String> actions;
  final List<String> keyActions;
  final List<String> keys;
  final List<String> modifiers;
  final int speedMin;
  final int speedMax;
  final int speedStep;
  final List<KeyboardAppKeys> apps;

  /// Action to button now.
  Map<String, String> get buttonMap => {...defaultButtons, ...stored.general};

  int get speed => stored.pointer.speed ?? defaultPointer.speed ?? 100;
  bool get swapSticks =>
      stored.pointer.swapSticks ?? defaultPointer.swapSticks ?? false;
  String get leftClick =>
      stored.pointer.leftClick ?? defaultPointer.leftClick ?? 'rt';
  String get rightClick =>
      stored.pointer.rightClick ?? defaultPointer.rightClick ?? 'lt';

  KeyboardAppKeys? app(String id) => apps.where((a) => a.id == id).firstOrNull;

  /// The keys of every keyboard app (without an app's own); with [appId],
  /// that app's keys as the session uses them.
  Map<String, String> keymap([String? appId]) => {
    ...defaultKeys,
    ...stored.keyboard,
    if (appId != null) ...?app(appId)?.keymap,
    if (appId != null) ...?stored.apps[appId],
  };

  /// The key of [action] (`none` when it sends nothing).
  String keyOf(String action, [String? appId]) =>
      keymap(appId)[action] ?? 'none';

  bool get buttonsChanged => stored.general.isNotEmpty;
  bool get pointerChanged => !stored.pointer.isEmpty;
  bool get keysChanged => stored.keyboard.isNotEmpty;
  bool appChanged(String id) => stored.apps[id]?.isNotEmpty ?? false;

  /// [action] gets [button]; the action that had it gets [action]'s old one.
  StoredController withButton(String action, String button) {
    final map = buttonMap;
    final old = map[action];
    for (final a in actions) {
      if (a != action && map[a] == button && old != null) map[a] = old;
    }
    map[action] = button;
    return stored.copyWith(
      general: {
        for (final a in actions)
          if (map[a] != null && map[a] != defaultButtons[a]) a: map[a]!,
      },
    );
  }

  StoredController withoutButtons() => stored.copyWith(general: const {});

  StoredController _pointer({
    int? speed,
    bool? swapSticks,
    String? leftClick,
    String? rightClick,
  }) {
    final s = speed ?? this.speed;
    final w = swapSticks ?? this.swapSticks;
    final l = leftClick ?? this.leftClick;
    final r = rightClick ?? this.rightClick;
    return stored.copyWith(
      pointer: PointerPrefs(
        speed: s == defaultPointer.speed ? null : s,
        swapSticks: w == defaultPointer.swapSticks ? null : w,
        leftClick: l == defaultPointer.leftClick ? null : l,
        rightClick: r == defaultPointer.rightClick ? null : r,
      ),
    );
  }

  /// [speed] kept in speedMin..speedMax.
  StoredController withSpeed(int speed) =>
      _pointer(speed: speed.clamp(speedMin, speedMax));

  StoredController withSwapSticks(bool on) => _pointer(swapSticks: on);

  /// The left (or right) click gets [button]; when the other click has it,
  /// the two swap.
  StoredController withClick({required bool left, required String button}) {
    final mine = left ? leftClick : rightClick;
    final other = left ? rightClick : leftClick;
    final swapped = button == other ? mine : other;
    return left
        ? _pointer(leftClick: button, rightClick: swapped)
        : _pointer(rightClick: button, leftClick: swapped);
  }

  StoredController withoutPointer() =>
      stored.copyWith(pointer: const PointerPrefs());

  /// [action] sends [key] (`none`: nothing) in every keyboard app, or with
  /// [appId] in that app only. A key equal to what applies without the
  /// change is not stored.
  StoredController withKey(String action, String key, {String? appId}) {
    if (appId == null) {
      final keyboard = {...stored.keyboard}..remove(action);
      if ((defaultKeys[action] ?? 'none') != key) keyboard[action] = key;
      return stored.copyWith(keyboard: keyboard);
    }
    final base = {...defaultKeys, ...stored.keyboard, ...?app(appId)?.keymap};
    final own = {...?stored.apps[appId]}..remove(action);
    if ((base[action] ?? 'none') != key) own[action] = key;
    final apps = {...stored.apps}..remove(appId);
    if (own.isNotEmpty) apps[appId] = own;
    return stored.copyWith(apps: apps);
  }

  StoredController withoutKeys() => stored.copyWith(keyboard: const {});

  StoredController withoutAppKeys(String appId) =>
      stored.copyWith(apps: {...stored.apps}..remove(appId));
}

// ---------------------------------------------------------------- labels

/// The Xbox label of a button id: `A`, `LB`, `View`.
String buttonLabel(String id) => switch (id) {
  'view' => 'View',
  'menu' => 'Menu',
  _ => id.toUpperCase(),
};

/// What an action is called on screen.
String actionLabel(String id) => switch (id) {
  'trigger_left' => 'Left trigger',
  'trigger_right' => 'Right trigger',
  _ => _words(id),
};

/// A key with modifiers on screen: `Enter`, `Alt+Left`, `Page up`, `F5`,
/// `None`.
String keyLabel(String combo) {
  if (combo == 'none') return 'None';
  return combo.split('+').map(_keyWord).join('+');
}

String _keyWord(String k) => switch (k) {
  'ctrl' => 'Ctrl',
  'meta' => 'Meta',
  _ when k.length == 1 || RegExp(r'^f\d+$').hasMatch(k) => k.toUpperCase(),
  _ => _words(k),
};

/// `page_left` -> `Page left`.
String _words(String id) {
  final s = id.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// The key of [combo] without its modifiers, and the modifiers.
(String key, Set<String> modifiers) splitCombo(String combo) {
  final parts = combo.split('+');
  final key = parts.removeLast();
  return (key, parts.toSet());
}

/// [key] with [modifiers], modifiers first in the order of [order].
String joinCombo(String key, Set<String> modifiers, List<String> order) => [
  for (final m in order)
    if (modifiers.contains(m)) m,
  key,
].join('+');

// ---------------------------------------------------------------- repository

/// `input.settings.*` and `input.capture`.
abstract class ControllerRepository {
  /// `input.settings.get`.
  Future<ControllerState> get();

  /// `input.settings.set`: stores [settings] (the whole stored form) and
  /// applies them at once. [changes] follows. A map that is not one button
  /// per action is [SystemErrorKind.invalidParams].
  Future<ControllerState> set(StoredController settings);

  /// Every state [set] made.
  Stream<ControllerState> get changes;

  /// `input.capture`, then the `input_captured` that ends it: the button
  /// pressed (a button id or a direction), or null (Guide, no press in time).
  Future<String?> capture();
}
