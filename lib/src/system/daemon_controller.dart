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
      guardCall(() async => _state((await _conn.inputSettingsGet()).toJson()));

  @override
  Future<ControllerState> set(StoredController settings) => guardCall(() async {
    final r = _state(
      (await _conn.inputSettingsSet(
        api.InputSettingsSetParams(settings: controllerSettingsOf(settings)),
      )).toJson(),
    );
    _changes.add(r);
    return r;
  });

  /// Both results are an InputSettings on the wire.
  static ControllerState _state(Map<String, dynamic> json) =>
      controllerStateFrom(api.InputSettings.fromJson(json));

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
