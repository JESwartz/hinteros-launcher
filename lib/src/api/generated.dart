// GENERATED CODE - DO NOT EDIT.
// Source: schema/session-api.json (session API 0.2).
// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)
//
// ignore_for_file: unnecessary_this, unnecessary_cast

import 'dart:convert';

/// API version this client was generated for (sent in `hello`).
const apiVersion = '0.2';

/// Method names in the schema.
const apiMethodNames = <String>[
  'hello',
  'ping',
  'subscribe',
  'unsubscribe',
  'apps.list',
  'apps.launch',
  'apps.running',
  'apps.focus',
];

/// Event names in the schema.
const apiEventNames = <String>[
  'home_pressed',
  'app_started',
  'app_exited',
  'focus_changed',
  'input_nav',
];

/// Error name to JSON-RPC code.
const apiErrorCodesByName = <String, int>{
  'parse_error': -32700,
  'invalid_request': -32600,
  'method_not_found': -32601,
  'invalid_params': -32602,
  'internal_error': -32603,
  'handshake_required': 1001,
  'version_mismatch': 1002,
  'already_handshaken': 1003,
  'app_not_found': 2001,
  'app_launch_failed': 2002,
};

/// JSON-RPC error codes of the session API.
abstract final class ApiErrorCode {
  /// The line is not valid JSON.
  static const parseError = -32700;

  /// Valid JSON but not a valid JSON-RPC 2.0 request (batches are not supported).
  static const invalidRequest = -32600;

  /// Unknown method (or not available in the negotiated version).
  static const methodNotFound = -32601;

  /// Params do not match the method's params schema.
  static const invalidParams = -32602;

  /// Unexpected server-side failure.
  static const internalError = -32603;

  /// A method other than 'hello' was called before the handshake.
  static const handshakeRequired = 1001;

  /// Client and server API versions are incompatible.
  static const versionMismatch = 1002;

  /// 'hello' was called twice on one connection.
  static const alreadyHandshaken = 1003;

  /// No such app (apps.launch: not in apps.list; apps.focus: not running).
  static const appNotFound = 2001;

  /// The app could not be started (spawn failed, or it has nothing to launch).
  static const appLaunchFailed = 2002;
}

/// MAJOR.MINOR
typedef ApiVersion = String;

/// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'.
typedef AppId = String;

/// A running app's id, or null for the launcher.
typedef FocusTarget = String;

/// Name and build version of one side of the connection (informational, for logs).
class Peer {
  const Peer({required this.name, required this.version});

  final String name;
  final String version;

  factory Peer.fromJson(Map<String, dynamic> json) =>
      Peer(name: json['name'] as String, version: json['version'] as String);

  Map<String, dynamic> toJson() => {'name': name, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is Peer && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Peer(${jsonEncode(toJson())})';
}

enum EventName {
  homePressed('home_pressed'),
  appStarted('app_started'),
  appExited('app_exited'),
  focusChanged('focus_changed'),
  inputNav('input_nav'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const EventName(this.value);
  final String value;

  factory EventName.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// How a running app was started. Clients must treat unknown values like 'command'.
enum AppSource {
  command('command'),
  steam('steam'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const AppSource(this.value);
  final String value;

  factory AppSource.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class RunningApp {
  const RunningApp({
    required this.id,
    required this.name,
    required this.source,
    required this.gamescopeAppId,
    this.pid,
  });

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'.
  final String id;

  /// Display name.
  final String name;

  /// How a running app was started. Clients must treat unknown values like 'command'.
  final AppSource source;

  /// The app id gamescope knows its windows by (the Steam app id for Steam games). For diagnostics.
  final int gamescopeAppId;

  /// Process the daemon started for it, if it tracks one.
  final int? pid;

  factory RunningApp.fromJson(Map<String, dynamic> json) => RunningApp(
    id: json['id'] as String,
    name: json['name'] as String,
    source: AppSource.fromJson(json['source'] as String),
    gamescopeAppId: json['gamescope_app_id'] as int,
    pid: json['pid'] == null ? null : json['pid'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source.toJson(),
    'gamescope_app_id': gamescopeAppId,
    'pid': ?pid,
  };

  @override
  bool operator ==(Object other) =>
      other is RunningApp && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'RunningApp(${jsonEncode(toJson())})';
}

/// Why an app ended: 'exited' normally (status 0, or a Steam game's windows closed), 'crashed' (non-zero status or killed), 'launch_timeout' (a Steam game never showed a window). Clients must treat unknown values like 'exited'.
enum ExitReason {
  exited('exited'),
  crashed('crashed'),
  launchTimeout('launch_timeout'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const ExitReason(this.value);
  final String value;

  factory ExitReason.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// Navigation intent. Gamepad mapping: d-pad and left stick = directions, A/Cross = accept, B/Circle = back, Y/Triangle = context, X/Square = secondary, Start = menu, Select/View = view, L1/R1 = page_left/page_right, L2/R2 = trigger_left/trigger_right, Quick Access = quick, keyboard button = keyboard.
enum NavAction {
  up('up'),
  down('down'),
  left('left'),
  right('right'),
  accept('accept'),
  back('back'),
  context('context'),
  secondary('secondary'),
  menu('menu'),
  view('view'),
  pageLeft('page_left'),
  pageRight('page_right'),
  triggerLeft('trigger_left'),
  triggerRight('trigger_right'),
  quick('quick'),
  keyboard('keyboard'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const NavAction(this.value);
  final String value;

  factory NavAction.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum NavPhase {
  press('press'),
  repeat('repeat'),
  release('release'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const NavPhase(this.value);
  final String value;

  factory NavPhase.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// How the app is launched. Clients must treat unknown values like 'native'.
enum AppKind {
  native('native'),
  web('web'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const AppKind(this.value);
  final String value;

  factory AppKind.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class App {
  const App({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
  });

  /// Stable identifier, used by apps.launch.
  final String id;

  /// Display name.
  final String name;

  /// How the app is launched. Clients must treat unknown values like 'native'.
  final AppKind kind;

  /// Absolute path to an icon file, if any.
  final String? icon;

  factory App.fromJson(Map<String, dynamic> json) => App(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: AppKind.fromJson(json['kind'] as String),
    icon: json['icon'] == null ? null : json['icon'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.toJson(),
    'icon': ?icon,
  };

  @override
  bool operator ==(Object other) =>
      other is App && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'App(${jsonEncode(toJson())})';
}

class HelloParams {
  const HelloParams({required this.apiVersion, required this.client});

  /// MAJOR.MINOR
  final String apiVersion;

  /// Name and build version of one side of the connection (informational, for logs).
  final Peer client;

  factory HelloParams.fromJson(Map<String, dynamic> json) => HelloParams(
    apiVersion: json['api_version'] as String,
    client: Peer.fromJson((json['client'] as Map).cast<String, dynamic>()),
  );

  Map<String, dynamic> toJson() => {
    'api_version': apiVersion,
    'client': client.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is HelloParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'HelloParams(${jsonEncode(toJson())})';
}

class HelloResult {
  const HelloResult({required this.apiVersion, required this.server});

  /// MAJOR.MINOR
  final String apiVersion;

  /// Name and build version of one side of the connection (informational, for logs).
  final Peer server;

  factory HelloResult.fromJson(Map<String, dynamic> json) => HelloResult(
    apiVersion: json['api_version'] as String,
    server: Peer.fromJson((json['server'] as Map).cast<String, dynamic>()),
  );

  Map<String, dynamic> toJson() => {
    'api_version': apiVersion,
    'server': server.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is HelloResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'HelloResult(${jsonEncode(toJson())})';
}

class PingParams {
  const PingParams({this.nonce});

  final String? nonce;

  factory PingParams.fromJson(Map<String, dynamic> json) =>
      PingParams(nonce: json['nonce'] == null ? null : json['nonce'] as String);

  Map<String, dynamic> toJson() => {'nonce': ?nonce};

  @override
  bool operator ==(Object other) =>
      other is PingParams && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PingParams(${jsonEncode(toJson())})';
}

class PingResult {
  const PingResult({this.nonce});

  final String? nonce;

  factory PingResult.fromJson(Map<String, dynamic> json) =>
      PingResult(nonce: json['nonce'] == null ? null : json['nonce'] as String);

  Map<String, dynamic> toJson() => {'nonce': ?nonce};

  @override
  bool operator ==(Object other) =>
      other is PingResult && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PingResult(${jsonEncode(toJson())})';
}

class SubscribeParams {
  const SubscribeParams({required this.events});

  final List<EventName> events;

  factory SubscribeParams.fromJson(Map<String, dynamic> json) =>
      SubscribeParams(
        events: (json['events'] as List)
            .map((x) => EventName.fromJson(x as String))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'events': events.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SubscribeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SubscribeParams(${jsonEncode(toJson())})';
}

class SubscribeResult {
  const SubscribeResult({required this.events});

  final List<EventName> events;

  factory SubscribeResult.fromJson(Map<String, dynamic> json) =>
      SubscribeResult(
        events: (json['events'] as List)
            .map((x) => EventName.fromJson(x as String))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'events': events.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SubscribeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SubscribeResult(${jsonEncode(toJson())})';
}

class UnsubscribeParams {
  const UnsubscribeParams({required this.events});

  final List<EventName> events;

  factory UnsubscribeParams.fromJson(Map<String, dynamic> json) =>
      UnsubscribeParams(
        events: (json['events'] as List)
            .map((x) => EventName.fromJson(x as String))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'events': events.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is UnsubscribeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'UnsubscribeParams(${jsonEncode(toJson())})';
}

class UnsubscribeResult {
  const UnsubscribeResult({required this.events});

  final List<EventName> events;

  factory UnsubscribeResult.fromJson(Map<String, dynamic> json) =>
      UnsubscribeResult(
        events: (json['events'] as List)
            .map((x) => EventName.fromJson(x as String))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'events': events.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is UnsubscribeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'UnsubscribeResult(${jsonEncode(toJson())})';
}

class AppsListParams {
  const AppsListParams();

  factory AppsListParams.fromJson(Map<String, dynamic> json) =>
      AppsListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AppsListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsListParams(${jsonEncode(toJson())})';
}

class AppsListResult {
  const AppsListResult({required this.apps});

  final List<App> apps;

  factory AppsListResult.fromJson(Map<String, dynamic> json) => AppsListResult(
    apps: (json['apps'] as List)
        .map((x) => App.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'apps': apps.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is AppsListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsListResult(${jsonEncode(toJson())})';
}

class AppsLaunchParams {
  const AppsLaunchParams({this.id, this.command, this.url, this.name});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'.
  final String? id;

  /// Program and arguments. The program is looked up in the daemon's PATH.
  final List<String>? command;

  /// A Steam game, launched through the configured steam binary.
  final String? url;

  /// Display name for a 'command' launch (default: the program's file name).
  final String? name;

  factory AppsLaunchParams.fromJson(Map<String, dynamic> json) =>
      AppsLaunchParams(
        id: json['id'] == null ? null : json['id'] as String,
        command: json['command'] == null
            ? null
            : (json['command'] as List).map((x) => x as String).toList(),
        url: json['url'] == null ? null : json['url'] as String,
        name: json['name'] == null ? null : json['name'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'command': ?command,
    'url': ?url,
    'name': ?name,
  };

  @override
  bool operator ==(Object other) =>
      other is AppsLaunchParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsLaunchParams(${jsonEncode(toJson())})';
}

class AppsLaunchResult {
  const AppsLaunchResult({required this.app});

  final RunningApp app;

  factory AppsLaunchResult.fromJson(Map<String, dynamic> json) =>
      AppsLaunchResult(
        app: RunningApp.fromJson((json['app'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {'app': app.toJson()};

  @override
  bool operator ==(Object other) =>
      other is AppsLaunchResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsLaunchResult(${jsonEncode(toJson())})';
}

class AppsRunningParams {
  const AppsRunningParams();

  factory AppsRunningParams.fromJson(Map<String, dynamic> json) =>
      AppsRunningParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AppsRunningParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsRunningParams(${jsonEncode(toJson())})';
}

class AppsRunningResult {
  const AppsRunningResult({required this.apps, required this.focused});

  final List<RunningApp> apps;

  /// A running app's id, or null for the launcher.
  final String? focused;

  factory AppsRunningResult.fromJson(Map<String, dynamic> json) =>
      AppsRunningResult(
        apps: (json['apps'] as List)
            .map((x) => RunningApp.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
        focused: json['focused'] == null ? null : json['focused'] as String,
      );

  Map<String, dynamic> toJson() => {
    'apps': apps.map((x) => x.toJson()).toList(),
    'focused': focused,
  };

  @override
  bool operator ==(Object other) =>
      other is AppsRunningResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsRunningResult(${jsonEncode(toJson())})';
}

class AppsFocusParams {
  const AppsFocusParams({required this.id});

  /// A running app's id, or null for the launcher.
  final String? id;

  factory AppsFocusParams.fromJson(Map<String, dynamic> json) =>
      AppsFocusParams(id: json['id'] == null ? null : json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is AppsFocusParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsFocusParams(${jsonEncode(toJson())})';
}

class AppsFocusResult {
  const AppsFocusResult();

  factory AppsFocusResult.fromJson(Map<String, dynamic> json) =>
      AppsFocusResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AppsFocusResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsFocusResult(${jsonEncode(toJson())})';
}

/// The global Home button was pressed. The launcher brings itself to the front.
final class HomePressedEvent extends SessionEvent {
  const HomePressedEvent();

  factory HomePressedEvent.fromJson(Map<String, dynamic> json) =>
      HomePressedEvent();

  Map<String, dynamic> toJson() => {};

  @override
  String get name => 'home_pressed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is HomePressedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'HomePressedEvent(${jsonEncode(toJson())})';
}

/// An app was started through apps.launch.
final class AppStartedEvent extends SessionEvent {
  const AppStartedEvent({required this.app});

  final RunningApp app;

  factory AppStartedEvent.fromJson(Map<String, dynamic> json) =>
      AppStartedEvent(
        app: RunningApp.fromJson((json['app'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {'app': app.toJson()};

  @override
  String get name => 'app_started';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is AppStartedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppStartedEvent(${jsonEncode(toJson())})';
}

/// A running app ended. If it had focus, the launcher is back in front (see focus_changed).
final class AppExitedEvent extends SessionEvent {
  const AppExitedEvent({required this.id, required this.reason, this.exitCode});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'.
  final String id;

  /// Why an app ended: 'exited' normally (status 0, or a Steam game's windows closed), 'crashed' (non-zero status or killed), 'launch_timeout' (a Steam game never showed a window). Clients must treat unknown values like 'exited'.
  final ExitReason reason;

  /// Exit status of the app's main process, if known (128 + signal number if it was killed).
  final int? exitCode;

  factory AppExitedEvent.fromJson(Map<String, dynamic> json) => AppExitedEvent(
    id: json['id'] as String,
    reason: ExitReason.fromJson(json['reason'] as String),
    exitCode: json['exit_code'] == null ? null : json['exit_code'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reason': reason.toJson(),
    'exit_code': ?exitCode,
  };

  @override
  String get name => 'app_exited';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is AppExitedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppExitedEvent(${jsonEncode(toJson())})';
}

/// Another app, or the launcher (null), now has focus.
final class FocusChangedEvent extends SessionEvent {
  const FocusChangedEvent({required this.app});

  /// A running app's id, or null for the launcher.
  final String? app;

  factory FocusChangedEvent.fromJson(Map<String, dynamic> json) =>
      FocusChangedEvent(
        app: json['app'] == null ? null : json['app'] as String,
      );

  Map<String, dynamic> toJson() => {'app': app};

  @override
  String get name => 'focus_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is FocusChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'FocusChangedEvent(${jsonEncode(toJson())})';
}

/// A controller navigation intent, sent only while the launcher has focus.
final class InputNavEvent extends SessionEvent {
  const InputNavEvent({required this.action, required this.phase});

  /// Navigation intent. Gamepad mapping: d-pad and left stick = directions, A/Cross = accept, B/Circle = back, Y/Triangle = context, X/Square = secondary, Start = menu, Select/View = view, L1/R1 = page_left/page_right, L2/R2 = trigger_left/trigger_right, Quick Access = quick, keyboard button = keyboard.
  final NavAction action;
  final NavPhase phase;

  factory InputNavEvent.fromJson(Map<String, dynamic> json) => InputNavEvent(
    action: NavAction.fromJson(json['action'] as String),
    phase: NavPhase.fromJson(json['phase'] as String),
  );

  Map<String, dynamic> toJson() => {
    'action': action.toJson(),
    'phase': phase.toJson(),
  };

  @override
  String get name => 'input_nav';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is InputNavEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputNavEvent(${jsonEncode(toJson())})';
}

class VersionMismatchData {
  const VersionMismatchData({
    required this.clientApiVersion,
    required this.serverApiVersion,
  });

  /// MAJOR.MINOR
  final String clientApiVersion;

  /// MAJOR.MINOR
  final String serverApiVersion;

  factory VersionMismatchData.fromJson(Map<String, dynamic> json) =>
      VersionMismatchData(
        clientApiVersion: json['client_api_version'] as String,
        serverApiVersion: json['server_api_version'] as String,
      );

  Map<String, dynamic> toJson() => {
    'client_api_version': clientApiVersion,
    'server_api_version': serverApiVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is VersionMismatchData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'VersionMismatchData(${jsonEncode(toJson())})';
}

/// Typed calls for every method of the session API.
///
/// Implementors provide [rpc], which sends one request and returns its
/// result object (or throws).
mixin SessionApiMethods {
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params);

  /// Version handshake. Must be the first request on a connection.
  ///
  /// The client sends the API version it was built against. Majors must match (during 0.x the minor must match too). The result carries the negotiated version: min(client, server). On a mismatch the server answers with version_mismatch and closes the connection.
  Future<HelloResult> hello(HelloParams params) async =>
      HelloResult.fromJson(await rpc('hello', params.toJson()));

  /// Liveness check. Echoes the optional nonce.
  Future<PingResult> ping([PingParams params = const PingParams()]) async =>
      PingResult.fromJson(await rpc('ping', params.toJson()));

  /// Start receiving the given events on this connection. Returns the full subscription set.
  Future<SubscribeResult> subscribe(SubscribeParams params) async =>
      SubscribeResult.fromJson(await rpc('subscribe', params.toJson()));

  /// Stop receiving the given events. Returns the remaining subscription set.
  Future<UnsubscribeResult> unsubscribe(UnsubscribeParams params) async =>
      UnsubscribeResult.fromJson(await rpc('unsubscribe', params.toJson()));

  /// Apps the launcher can show and launch: the apps from the daemon's config, or a fixed stub list when none are configured.
  Future<AppsListResult> appsList([
    AppsListParams params = const AppsListParams(),
  ]) async => AppsListResult.fromJson(await rpc('apps.list', params.toJson()));

  /// Start an app and give it focus. Returns once it is spawned, before it shows a window.
  ///
  /// Exactly one of: 'id' (an app from apps.list), 'command' (argv, run as the session user), or 'url' (a Steam game, handed to the running Steam client). If the app is already running it is focused instead and the result describes the running instance. Its windows are shown as soon as they appear; until then the launcher stays visible. Progress is reported through app_started, focus_changed and app_exited.
  Future<AppsLaunchResult> appsLaunch([
    AppsLaunchParams params = const AppsLaunchParams(),
  ]) async =>
      AppsLaunchResult.fromJson(await rpc('apps.launch', params.toJson()));

  /// Apps started through apps.launch that are still running, and which one has focus.
  ///
  /// Re-query this after reconnecting: app_started, app_exited and focus_changed are not replayed.
  Future<AppsRunningResult> appsRunning([
    AppsRunningParams params = const AppsRunningParams(),
  ]) async =>
      AppsRunningResult.fromJson(await rpc('apps.running', params.toJson()));

  /// Bring a running app, or the launcher (null), to the front.
  ///
  /// Focusing the launcher does not stop the app that had focus. Controller input goes to whatever has focus; while the launcher has focus it arrives as input_nav events.
  Future<AppsFocusResult> appsFocus(AppsFocusParams params) async =>
      AppsFocusResult.fromJson(await rpc('apps.focus', params.toJson()));
}

/// A server-pushed notification of the session API.
sealed class SessionEvent {
  const SessionEvent();

  /// Wire name, e.g. `home_pressed`.
  String get name;

  Map<String, dynamic> get params;

  /// Builds the typed event; names this client does not know become
  /// [UnknownSessionEvent].
  static SessionEvent fromNotification(
    String name,
    Map<String, dynamic> params,
  ) => switch (name) {
    'home_pressed' => HomePressedEvent.fromJson(params),
    'app_started' => AppStartedEvent.fromJson(params),
    'app_exited' => AppExitedEvent.fromJson(params),
    'focus_changed' => FocusChangedEvent.fromJson(params),
    'input_nav' => InputNavEvent.fromJson(params),
    _ => UnknownSessionEvent(name, params),
  };
}

/// An event from a newer daemon than this client knows.
final class UnknownSessionEvent extends SessionEvent {
  const UnknownSessionEvent(this.name, this.params);

  @override
  final String name;

  @override
  final Map<String, dynamic> params;
}
