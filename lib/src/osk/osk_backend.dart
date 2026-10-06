import 'dart:async';

import '../api/api.dart';

/// Keys that are not text: sent as `keys.action` (API 0.4).
enum OskAction {
  backspace('backspace'),
  enter('enter'),
  tab('tab');

  const OskAction(this.wire);

  /// The value of `keys.action {action}`.
  // TODO(0.4): confirm the wire names against the schema.
  final String wire;
}

/// What the on-screen keyboard needs from the daemon (API 0.4: `osk.hide`,
/// `keys.type`, `keys.key`, `keys.action`, the `osk_visibility` event, and
/// `input_nav` while the OSK is up). The UI only ever sees this interface;
/// wiring 0.4 later is [DaemonOskBackend] filling in its TODO(0.4) spots, and
/// [MockOskBackend] stands in until then (and in tests).
abstract class OskBackend {
  /// `input_nav` events. The daemon routes them to the OSK client only while
  /// the OSK is visible.
  Stream<InputNavEvent> get nav;

  /// `osk_visibility {visible}`. The OSK process stays resident; the daemon
  /// shows and hides its window.
  Stream<bool> get visibility;

  /// `keys.type {text}`: characters (the daemon picks uinput or the
  /// gamescope input method per character).
  Future<void> type(String text);

  /// `keys.action {action}`: backspace, enter, tab.
  Future<void> action(OskAction action);

  /// `keys.key {key, modifiers}`: a named key with modifiers (shortcuts).
  /// Not used by the current layout; part of the interface for later pages.
  Future<void> key(String key, {List<String> modifiers = const []});

  /// `osk.hide`: the Done key.
  Future<void> hide();

  Future<void> dispose();
}

/// In-process stand-in: records the calls, takes `input_nav` and visibility
/// from the outside. Used by `--mock`, tests and goldens.
class MockOskBackend implements OskBackend {
  final _nav = StreamController<InputNavEvent>.broadcast();
  final _visibility = StreamController<bool>.broadcast();

  /// Every call in order, as `type:<text>`, `action:<wire>`,
  /// `key:<key>[+mod...]` and `hide`.
  final List<String> calls = [];

  /// When set, calls throw it (to test the error display).
  Object? failWith;

  /// Called for every recorded call (the dev window prints them).
  void Function(String call)? onCall;

  void _record(String call) {
    if (failWith != null) throw failWith!;
    calls.add(call);
    onCall?.call(call);
  }

  /// Everything `keys.type` was given, concatenated.
  String get typedText => calls
      .where((c) => c.startsWith('type:'))
      .map((c) => c.substring(5))
      .join();

  /// As if the daemon sent `input_nav`.
  void emitNav(NavAction action, [NavPhase phase = NavPhase.press]) =>
      _nav.add(InputNavEvent(action: action, phase: phase));

  /// As if the daemon sent `osk_visibility`.
  void setVisible(bool visible) => _visibility.add(visible);

  @override
  Stream<InputNavEvent> get nav => _nav.stream;

  @override
  Stream<bool> get visibility => _visibility.stream;

  @override
  Future<void> type(String text) async => _record('type:$text');

  @override
  Future<void> action(OskAction action) async =>
      _record('action:${action.wire}');

  @override
  Future<void> key(String key, {List<String> modifiers = const []}) async =>
      _record('key:${[key, ...modifiers].join('+')}');

  @override
  Future<void> hide() async {
    _record('hide');
    _visibility.add(false);
  }

  @override
  Future<void> dispose() async {
    await _nav.close();
    await _visibility.close();
  }
}

/// The real thing over the session socket. API 0.3 has `input_nav` (only while
/// the launcher has focus) and nothing else, so the calls are not wired yet.
class DaemonOskBackend implements OskBackend {
  DaemonOskBackend(this.connection) {
    connection.start();
    // TODO(0.4): also subscribe to EventName.oskVisibility.
    connection.subscribeTo([EventName.inputNav]);
  }

  final DaemonConnection connection;

  @override
  Stream<InputNavEvent> get nav =>
      connection.events.where((e) => e is InputNavEvent).cast();

  // TODO(0.4): map OskVisibilityEvent to this stream.
  @override
  Stream<bool> get visibility => const Stream.empty();

  static UnsupportedError _notYet(String what) =>
      UnsupportedError('$what needs session API 0.4');

  // TODO(0.4): connection.keysType(KeysTypeParams(text: text)).
  @override
  Future<void> type(String text) => Future.error(_notYet('keys.type'));

  // TODO(0.4): connection.keysAction(KeysActionParams(action: ...)).
  @override
  Future<void> action(OskAction action) => Future.error(_notYet('keys.action'));

  // TODO(0.4): connection.keysKey(KeysKeyParams(key: key, modifiers: ...)).
  @override
  Future<void> key(String key, {List<String> modifiers = const []}) =>
      Future.error(_notYet('keys.key'));

  // TODO(0.4): connection.oskHide().
  @override
  Future<void> hide() => Future.error(_notYet('osk.hide'));

  @override
  Future<void> dispose() => connection.close();
}
