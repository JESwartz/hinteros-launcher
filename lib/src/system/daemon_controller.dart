/// [ControllerRepository] over the session daemon's `input.settings.*`,
/// `input.capture` and `input_captured` (session API 0.20).
library;

import 'dart:async';

import '../api/api.dart' as api;
import 'controller.dart';
import 'daemon_errors.dart';

Map<String, String> _strings(Map<String, Object?>? m) => {
  for (final e in (m ?? const {}).entries)
    if (e.value is String) e.key: e.value! as String,
};

PointerPrefs _pointer(api.PointerSettings? p) => PointerPrefs(
  speed: p?.speed,
  swapSticks: p?.swapSticks,
  leftClick: p?.leftClick,
  rightClick: p?.rightClick,
);

/// The model of an `input.settings.get` result.
ControllerState controllerStateFrom(api.InputSettings r) => ControllerState(
  stored: StoredController(
    general: _strings(r.settings.general),
    keyboard: _strings(r.settings.keyboard),
    apps: {
      for (final e in (r.settings.apps ?? const {}).entries)
        if (e.value is Map)
          e.key: _strings((e.value! as Map).cast<String, Object?>()),
    },
    pointer: _pointer(r.settings.pointer),
  ),
  defaultButtons: _strings(r.defaults.general),
  defaultKeys: _strings(r.defaults.keyboard),
  defaultPointer: _pointer(r.defaults.pointer),
  buttons: r.buttons,
  actions: r.actions,
  keyActions: r.keyActions,
  keys: r.keys,
  modifiers: r.modifiers,
  speedMin: r.speed.min,
  speedMax: r.speed.max,
  speedStep: r.speed.step,
  apps: [
    for (final a in r.apps)
      KeyboardAppKeys(id: a.id, name: a.name, keymap: _strings(a.keymap)),
  ],
);

/// The stored form on the wire; empty parts are left out.
api.ControllerSettings controllerSettingsOf(StoredController s) =>
    api.ControllerSettings(
      general: s.general.isEmpty ? null : s.general,
      keyboard: s.keyboard.isEmpty ? null : s.keyboard,
      apps: s.apps.isEmpty ? null : s.apps,
      pointer: s.pointer.isEmpty
          ? null
          : api.PointerSettings(
              speed: s.pointer.speed,
              swapSticks: s.pointer.swapSticks,
              leftClick: s.pointer.leftClick,
              rightClick: s.pointer.rightClick,
            ),
    );

/// [sent] laid over [stored], the stored form the daemon last gave.
/// `input.settings.set` replaces the whole form, so what this launcher does
/// not know (a newer daemon's parts, pointer fields, or values that are not
/// a key name) goes back unchanged instead of being deleted. What the
/// launcher shows (the string entries of the maps, the four pointer fields)
/// is [sent]'s alone.
Map<String, dynamic> mergeControllerSettings(
  Map<String, dynamic>? stored,
  api.ControllerSettings sent,
) {
  final old = stored ?? const <String, dynamic>{};
  final s = sent.toJson();
  final out = <String, dynamic>{...old};
  void put(String k, Map<String, Object?>? v) =>
      v == null || v.isEmpty ? out.remove(k) : out[k] = v;
  put('general', _overStrings(old['general'], s['general']));
  put('keyboard', _overStrings(old['keyboard'], s['keyboard']));
  final oldApps = old['apps'] is Map ? old['apps'] as Map : const {};
  final newApps = s['apps'] is Map ? s['apps'] as Map : const {};
  put('apps', {
    for (final e in oldApps.entries)
      if (e.value is! Map) '${e.key}': e.value,
    for (final id in {...oldApps.keys, ...newApps.keys})
      if (_overStrings(oldApps[id], newApps[id]) case final m?
          when m.isNotEmpty)
        '$id': m,
  });
  final oldPointer = old['pointer'] is Map ? old['pointer'] as Map : const {};
  put('pointer', {
    for (final e in oldPointer.entries)
      if (!_pointerFields.contains(e.key)) '${e.key}': e.value,
    ...?(s['pointer'] as Map<String, dynamic>?),
  });
  return out;
}

const _pointerFields = {'speed', 'swap_sticks', 'left_click', 'right_click'};

/// The non-string entries of [old] (unknown to the launcher) and [sent].
Map<String, Object?>? _overStrings(Object? old, Object? sent) {
  final m = <String, Object?>{
    if (old is Map)
      for (final e in old.entries)
        if (e.value is! String) '${e.key}': e.value,
    if (sent is Map)
      for (final e in sent.entries) '${e.key}': e.value,
  };
  return m.isEmpty ? null : m;
}

class DaemonController implements ControllerRepository {
  DaemonController(this._conn) {
    _events = _conn.events.listen((e) {
      if (e is api.InputCapturedEvent) _finish(e.button);
    });
    // A capture cannot outlive the connection.
    _status = _conn.statusChanges.listen((s) {
      if (s is! api.Connected) _finish(null);
    });
    unawaited(
      _conn
          .subscribeTo(const [api.EventName.inputCaptured])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  late final StreamSubscription<api.SessionEvent> _events;
  late final StreamSubscription<api.ConnectionStatus> _status;
  final _changes = StreamController<ControllerState>.broadcast();
  Completer<String?>? _capture;

  void _finish(String? button) {
    final c = _capture;
    _capture = null;
    if (c != null && !c.isCompleted) c.complete(button);
  }

  @override
  Stream<ControllerState> get changes => _changes.stream;

  @override
  Future<ControllerState> get() =>
      guardCall(() async => _state(await _conn.rpc('input.settings.get', {})));

  @override
  Future<ControllerState> set(StoredController settings) => guardCall(() async {
    final sent = controllerSettingsOf(settings);
    final r = _state(
      await _conn.rpc('input.settings.set', {
        'settings': mergeControllerSettings(_stored, sent),
      }),
    );
    _changes.add(r);
    return r;
  });

  /// The stored form of the last result, as the daemon sent it (with what
  /// this launcher does not read).
  Map<String, dynamic>? _stored;

  /// Both results are an InputSettings on the wire, read here from the raw
  /// JSON: the typed form would drop what [set] has to send back.
  ControllerState _state(Map<String, dynamic> json) {
    final s = controllerStateFrom(api.InputSettings.fromJson(json));
    final raw = json['settings'];
    _stored = raw is Map ? raw.cast<String, dynamic>() : null;
    return s;
  }

  @override
  Future<String?> capture() async {
    // A capture still waiting ends without a button: the new one replaces it.
    _finish(null);
    final c = _capture = Completer<String?>();
    await guardCall(_conn.inputCapture);
    return c.future;
  }

  Future<void> dispose() async {
    _finish(null);
    await _events.cancel();
    await _status.cancel();
    await _changes.close();
  }
}
