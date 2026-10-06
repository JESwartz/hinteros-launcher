// GENERATED CODE - DO NOT EDIT.
// Source: schema/session-api.json (session API 0.1).
// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)
//
// ignore_for_file: unnecessary_this, unnecessary_cast

import 'dart:convert';

/// API version this client was generated for (sent in `hello`).
const apiVersion = '0.1';

/// Method names in the schema.
const apiMethodNames = <String>[
  'hello',
  'ping',
  'subscribe',
  'unsubscribe',
  'apps.list',
];

/// Event names in the schema.
const apiEventNames = <String>['home_pressed'];

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
}

/// MAJOR.MINOR
typedef ApiVersion = String;

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

  /// Stable identifier, used by apps.launch (M2).
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

  /// Apps the launcher can show and launch. M0 returns a fixed stub list.
  Future<AppsListResult> appsList([
    AppsListParams params = const AppsListParams(),
  ]) async => AppsListResult.fromJson(await rpc('apps.list', params.toJson()));
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
