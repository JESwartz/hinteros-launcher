import 'dart:async';

import '../api/api.dart';

/// Keys that are not text: sent as `keys.action` (API 0.4).
enum OskAction {
  backspace('backspace'),
  enter('enter'),
  tab('tab');

  const OskAction(this.wire);

  /// The value of `keys.action {action}` (a `KeyAction` of the schema).
  final String wire;
}

/// What the on-screen keyboard needs from the daemon (API 0.4: `osk.hide`,
/// `keys.type`, `keys.key`, `keys.action`, the `osk_changed` event, and
/// `input_nav` while the OSK is up). The UI only ever sees this interface:
/// [DaemonOskBackend] is the real one, [MockOskBackend] stands in for `--mock`
/// and tests.
abstract class OskBackend {
  /// `input_nav` events. The daemon routes them to the OSK client only while
  /// the OSK is visible.
  Stream<InputNavEvent> get nav;

  /// `osk_changed {visible}`, only when it changes. The OSK process stays
  /// resident; the daemon shows and hides its window.
  Stream<bool> get visibility;

  /// `osk_changed {password}` (API 0.10): whether the keyboard is up for a
  /// password field. Sent with every `osk_changed`, also when only the
  /// field changed (false while hidden). The preview is masked only for
  /// passwords.
  Stream<bool> get passwordField;

  /// `keys.type {text}`: characters (the daemon picks uinput or the
  /// gamescope input method per character). Returns the characters it could
  /// not type (`untypeable`), usually none.
  Future<List<String>> type(String text);

  /// `keys.action {action}`: backspace, enter, tab.
  Future<void> action(OskAction action);

  /// `keys.key {key, modifiers}`: a named key with modifiers (shortcuts).
  /// Not used by the current layout; part of the interface for later pages.
  Future<void> key(Key key, {List<Modifier> modifiers = const []});

  /// `osk.hide`: the Done key.
  Future<void> hide();

  Future<void> dispose();
}

/// In-process stand-in: records the calls, takes `input_nav` and visibility
/// from the outside. Used by `--mock`, tests and goldens.
class MockOskBackend implements OskBackend {
  final _nav = StreamController<InputNavEvent>.broadcast();
  final _visibility = StreamController<bool>.broadcast();
  final _password = StreamController<bool>.broadcast();

  /// Every call in order, as `type:<text>`, `action:<wire>`,
  /// `key:<key>[+mod...]` and `hide`.
  final List<String> calls = [];

  /// When set, calls throw it (to test the error display).
  Object? failWith;

  /// Characters `keys.type` reports as untypeable (the mock's US keyboard).
  Set<String> untypeable = {};

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

  /// As if the daemon sent `osk_changed` (`password` for a password field).
  void setVisible(bool visible, {bool password = false}) {
    _visibility.add(visible);
    _password.add(visible && password);
  }

  /// As if the daemon said another kind of field got focus (still visible).
  void setPasswordField(bool password) => _password.add(password);

  @override
  Stream<InputNavEvent> get nav => _nav.stream;

  @override
  Stream<bool> get visibility => _visibility.stream;

  @override
  Stream<bool> get passwordField => _password.stream;

  @override
  Future<List<String>> type(String text) async {
    _record('type:$text');
    return [
      for (final c in text.runes.map(String.fromCharCode))
        if (untypeable.contains(c)) c,
    ];
  }

  @override
  Future<void> action(OskAction action) async =>
      _record('action:${action.wire}');

  @override
  Future<void> key(Key key, {List<Modifier> modifiers = const []}) async =>
      _record('key:${[key.value, ...modifiers.map((m) => m.value)].join('+')}');

  @override
  Future<void> hide() async {
    _record('hide');
    _visibility.add(false);
    _password.add(false);
  }

  @override
  Future<void> dispose() async {
    await _nav.close();
    await _visibility.close();
    await _password.close();
  }
}

/// The real thing over the session socket. It connects as the client named
/// `hinteros-osk` (build the [DaemonClient] with [oskPeer]): while the
/// keyboard is visible the daemon sends `input_nav` to this connection only.
class DaemonOskBackend implements OskBackend {
  DaemonOskBackend(this.connection) {
    connection.start();
    unawaited(
      connection
          .subscribeTo([EventName.inputNav, EventName.oskChanged])
          .catchError((_) {}),
    );
  }

  /// The hello client name the daemon recognises as the on-screen keyboard.
  static const oskPeer = Peer(name: 'hinteros-osk', version: launcherVersion);

  final DaemonConnection connection;

  @override
  Stream<InputNavEvent> get nav =>
      connection.events.where((e) => e is InputNavEvent).cast();

  Stream<OskChangedEvent> get _oskEvents =>
      connection.events.where((e) => e is OskChangedEvent).cast();

  @override
  Stream<bool> get visibility {
    // The daemon sends osk_changed again (still visible) when the field
    // kind changes: only changes count here.
    bool? last;
    return _oskEvents.map((e) => e.visible).where((v) {
      final changed = v != last;
      last = v;
      return changed;
    });
  }

  @override
  Stream<bool> get passwordField =>
      _oskEvents.map((e) => e.visible && (e.password ?? false));

  @override
  Future<List<String>> type(String text) async =>
      (await connection.keysType(KeysTypeParams(text: text))).untypeable;

  @override
  Future<void> action(OskAction action) async {
    await connection.keysAction(
      KeysActionParams(action: KeyAction.fromJson(action.wire)),
    );
  }

  @override
  Future<void> key(Key key, {List<Modifier> modifiers = const []}) async {
    await connection.keysKey(
      KeysKeyParams(key: key, modifiers: modifiers.isEmpty ? null : modifiers),
    );
  }

  @override
  Future<void> hide() async {
    await connection.oskHide();
  }

  @override
  Future<void> dispose() => connection.close();
}
