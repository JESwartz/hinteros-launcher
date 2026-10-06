// GENERATED CODE - DO NOT EDIT.
// Source: schema/session-api.json (session API 0.3).
// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)
//
// ignore_for_file: unnecessary_this, unnecessary_cast

import 'dart:convert';

/// API version this client was generated for (sent in `hello`).
const apiVersion = '0.3';

/// Method names in the schema.
const apiMethodNames = <String>[
  'hello',
  'ping',
  'subscribe',
  'unsubscribe',
  'apps.list',
  'games.list',
  'steam.attention',
  'steam.focus',
  'apps.launch',
  'apps.running',
  'apps.focus',
  'apps.close',
];

/// Event names in the schema.
const apiEventNames = <String>[
  'home_pressed',
  'app_started',
  'app_exited',
  'focus_changed',
  'input_nav',
  'games_changed',
  'steam_attention',
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
  'steam_no_windows': 2003,
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

  /// No such app (apps.launch: not in apps.list; apps.focus, apps.close: not running).
  static const appNotFound = 2001;

  /// The app could not be started (spawn failed, or it has nothing to launch).
  static const appLaunchFailed = 2002;

  /// steam.focus: Steam has no windows that could be shown (not running, or no gamescope).
  static const steamNoWindows = 2003;
}

/// MAJOR.MINOR
typedef ApiVersion = String;

/// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
typedef AppId = String;

/// A running app's id, or null for the launcher.
typedef FocusTarget = String;

/// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
typedef ArtworkPath = String;

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
  gamesChanged('games_changed'),
  steamAttention('steam_attention'),

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

/// How a running app was started: 'command' (an argv under the daemon's reaper), 'steam' (a Steam game), 'steam_client' (Steam's own windows: Big Picture, dialogs). Clients must treat unknown values like 'command'.
enum AppSource {
  command('command'),
  steam('steam'),
  steamClient('steam_client'),

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

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;

  /// Display name.
  final String name;

  /// How a running app was started: 'command' (an argv under the daemon's reaper), 'steam' (a Steam game), 'steam_client' (Steam's own windows: Big Picture, dialogs). Clients must treat unknown values like 'command'.
  final AppSource source;

  /// The app id gamescope knows its windows by (the Steam app id for Steam games, 769 for Steam itself). For diagnostics.
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

/// Why an app ended: 'exited' normally (status 0, or a Steam game's windows closed), 'crashed' (non-zero status or killed), 'launch_timeout' (a Steam game never showed a window), 'closed' (ended after apps.close, however it ended). Clients must treat unknown values like 'exited'.
enum ExitReason {
  exited('exited'),
  crashed('crashed'),
  launchTimeout('launch_timeout'),
  closed('closed'),

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

/// A game's install state, from its manifest's StateFlags: 'installed' (ready), 'update_required' (installed; Steam updates it before it starts, launching works), 'updating' (installed; an update is downloading or being applied), 'installing' (not fully installed yet: first download in progress or paused), 'uninstalling'. Clients must treat unknown values like 'updating' (installed, but maybe not launchable right now).
enum InstallState {
  installed('installed'),
  updateRequired('update_required'),
  updating('updating'),
  installing('installing'),
  uninstalling('uninstalling'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const InstallState(this.value);
  final String value;

  factory InstallState.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// Steam's library artwork: 'portrait' (2:3 capsule, 300x450 or 600x900), 'header' (460x215), 'hero' (wide background, e.g. 1920x620), 'logo' (transparent PNG to draw over the hero), 'icon' (small square, e.g. 32x32).
class GameArtwork {
  const GameArtwork({
    required this.portrait,
    required this.header,
    required this.hero,
    required this.logo,
    required this.icon,
  });

  /// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
  final String? portrait;

  /// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
  final String? header;

  /// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
  final String? hero;

  /// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
  final String? logo;

  /// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
  final String? icon;

  factory GameArtwork.fromJson(Map<String, dynamic> json) => GameArtwork(
    portrait: json['portrait'] == null ? null : json['portrait'] as String,
    header: json['header'] == null ? null : json['header'] as String,
    hero: json['hero'] == null ? null : json['hero'] as String,
    logo: json['logo'] == null ? null : json['logo'] as String,
    icon: json['icon'] == null ? null : json['icon'] as String,
  );

  Map<String, dynamic> toJson() => {
    'portrait': portrait,
    'header': header,
    'hero': hero,
    'logo': logo,
    'icon': icon,
  };

  @override
  bool operator ==(Object other) =>
      other is GameArtwork &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GameArtwork(${jsonEncode(toJson())})';
}

/// An installed Steam game.
class Game {
  const Game({
    required this.appid,
    required this.name,
    required this.installState,
    required this.sizeBytes,
    required this.lastPlayed,
    required this.artwork,
  });

  /// Steam app id. Launch with apps.launch {url: 'steam://rungameid/&lt;appid&gt;'}; it then runs as 'steam-&lt;appid&gt;'.
  final int appid;

  /// Display name from the manifest.
  final String name;

  /// A game's install state, from its manifest's StateFlags: 'installed' (ready), 'update_required' (installed; Steam updates it before it starts, launching works), 'updating' (installed; an update is downloading or being applied), 'installing' (not fully installed yet: first download in progress or paused), 'uninstalling'. Clients must treat unknown values like 'updating' (installed, but maybe not launchable right now).
  final InstallState installState;

  /// Size on disk (0 if unknown).
  final int sizeBytes;

  /// When it was last played (Unix time, seconds), or null if never or unknown.
  final int? lastPlayed;

  /// Steam's library artwork: 'portrait' (2:3 capsule, 300x450 or 600x900), 'header' (460x215), 'hero' (wide background, e.g. 1920x620), 'logo' (transparent PNG to draw over the hero), 'icon' (small square, e.g. 32x32).
  final GameArtwork artwork;

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    appid: json['appid'] as int,
    name: json['name'] as String,
    installState: InstallState.fromJson(json['install_state'] as String),
    sizeBytes: json['size_bytes'] as int,
    lastPlayed: json['last_played'] == null ? null : json['last_played'] as int,
    artwork: GameArtwork.fromJson(
      (json['artwork'] as Map).cast<String, dynamic>(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'appid': appid,
    'name': name,
    'install_state': installState.toJson(),
    'size_bytes': sizeBytes,
    'last_played': lastPlayed,
    'artwork': artwork.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is Game && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Game(${jsonEncode(toJson())})';
}

/// One of Steam's own top-level windows on gamescope's Xwayland.
class SteamWindow {
  const SteamWindow({required this.window, required this.title, this.pid});

  /// X window id (diagnostics; stable while the window exists).
  final int window;

  /// Window title as Steam set it (may be empty).
  final String title;

  /// Process that owns the window (steam or steamwebhelper), if known.
  final int? pid;

  factory SteamWindow.fromJson(Map<String, dynamic> json) => SteamWindow(
    window: json['window'] as int,
    title: json['title'] as String,
    pid: json['pid'] == null ? null : json['pid'] as int,
  );

  Map<String, dynamic> toJson() => {
    'window': window,
    'title': title,
    'pid': ?pid,
  };

  @override
  bool operator ==(Object other) =>
      other is SteamWindow &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SteamWindow(${jsonEncode(toJson())})';
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

class GamesListParams {
  const GamesListParams();

  factory GamesListParams.fromJson(Map<String, dynamic> json) =>
      GamesListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is GamesListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GamesListParams(${jsonEncode(toJson())})';
}

class GamesListResult {
  const GamesListResult({required this.games});

  final List<Game> games;

  factory GamesListResult.fromJson(Map<String, dynamic> json) =>
      GamesListResult(
        games: (json['games'] as List)
            .map((x) => Game.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'games': games.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is GamesListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GamesListResult(${jsonEncode(toJson())})';
}

class SteamAttentionParams {
  const SteamAttentionParams();

  factory SteamAttentionParams.fromJson(Map<String, dynamic> json) =>
      SteamAttentionParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SteamAttentionParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SteamAttentionParams(${jsonEncode(toJson())})';
}

class SteamAttentionResult {
  const SteamAttentionResult({required this.windows});

  final List<SteamWindow> windows;

  factory SteamAttentionResult.fromJson(Map<String, dynamic> json) =>
      SteamAttentionResult(
        windows: (json['windows'] as List)
            .map(
              (x) => SteamWindow.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'windows': windows.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SteamAttentionResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SteamAttentionResult(${jsonEncode(toJson())})';
}

class SteamFocusParams {
  const SteamFocusParams();

  factory SteamFocusParams.fromJson(Map<String, dynamic> json) =>
      SteamFocusParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SteamFocusParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SteamFocusParams(${jsonEncode(toJson())})';
}

class SteamFocusResult {
  const SteamFocusResult({required this.app});

  final RunningApp app;

  factory SteamFocusResult.fromJson(Map<String, dynamic> json) =>
      SteamFocusResult(
        app: RunningApp.fromJson((json['app'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {'app': app.toJson()};

  @override
  bool operator ==(Object other) =>
      other is SteamFocusResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SteamFocusResult(${jsonEncode(toJson())})';
}

class AppsLaunchParams {
  const AppsLaunchParams({this.id, this.command, this.url, this.name});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
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

class AppsCloseParams {
  const AppsCloseParams({required this.id});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;

  factory AppsCloseParams.fromJson(Map<String, dynamic> json) =>
      AppsCloseParams(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is AppsCloseParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsCloseParams(${jsonEncode(toJson())})';
}

class AppsCloseResult {
  const AppsCloseResult();

  factory AppsCloseResult.fromJson(Map<String, dynamic> json) =>
      AppsCloseResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AppsCloseResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsCloseResult(${jsonEncode(toJson())})';
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

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;

  /// Why an app ended: 'exited' normally (status 0, or a Steam game's windows closed), 'crashed' (non-zero status or killed), 'launch_timeout' (a Steam game never showed a window), 'closed' (ended after apps.close, however it ended). Clients must treat unknown values like 'exited'.
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

/// The Steam library changed (a game was installed, removed or updated, or its artwork arrived). Call games.list again.
final class GamesChangedEvent extends SessionEvent {
  const GamesChangedEvent();

  factory GamesChangedEvent.fromJson(Map<String, dynamic> json) =>
      GamesChangedEvent();

  Map<String, dynamic> toJson() => {};

  @override
  String get name => 'games_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is GamesChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GamesChangedEvent(${jsonEncode(toJson())})';
}

/// The list of Steam windows waiting to be seen changed (see steam.attention). An empty list means nothing needs attention any more.
final class SteamAttentionEvent extends SessionEvent {
  const SteamAttentionEvent({required this.windows});

  final List<SteamWindow> windows;

  factory SteamAttentionEvent.fromJson(Map<String, dynamic> json) =>
      SteamAttentionEvent(
        windows: (json['windows'] as List)
            .map(
              (x) => SteamWindow.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'windows': windows.map((x) => x.toJson()).toList(),
  };

  @override
  String get name => 'steam_attention';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is SteamAttentionEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SteamAttentionEvent(${jsonEncode(toJson())})';
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

  /// Apps the launcher can show and launch: the built-in 'steam' entry (Steam's Big Picture mode, since 0.3), then the apps from the daemon's config, or a fixed stub list when none are configured.
  ///
  /// Installed Steam games are listed by games.list, not here.
  Future<AppsListResult> appsList([
    AppsListParams params = const AppsListParams(),
  ]) async => AppsListResult.fromJson(await rpc('apps.list', params.toJson()));

  /// Installed Steam games of the session user, read from Steam's library on disk.
  ///
  /// Read from the Steam directory (~/.local/share/Steam, else ~/.steam/steam; configurable): every library in steamapps/libraryfolders.vdf and its steamapps/appmanifest_&lt;appid&gt;.acf files. Steam tools (Proton, Steam Linux Runtime, Steamworks Common Redistributables, ...) are left out. Empty when Steam is not installed. Sorted by name. Launch a game with apps.launch {url: 'steam://rungameid/&lt;appid&gt;'}. games_changed says when to query again.
  Future<GamesListResult> gamesList([
    GamesListParams params = const GamesListParams(),
  ]) async =>
      GamesListResult.fromJson(await rpc('games.list', params.toJson()));

  /// Steam's own windows that appeared while something else had focus and still wait to be seen (Steam Guard, update prompts, cloud-save conflicts, sign-in, ...).
  ///
  /// The same list steam_attention sends. A window stops needing attention when it closes or once Steam has had focus while it was open (steam.focus, apps.launch/apps.focus 'steam'). Always empty without gamescope.
  Future<SteamAttentionResult> steamAttention([
    SteamAttentionParams params = const SteamAttentionParams(),
  ]) async => SteamAttentionResult.fromJson(
    await rpc('steam.attention', params.toJson()),
  );

  /// Bring Steam's own windows to the front (e.g. after steam_attention). Controller input goes to Steam.
  ///
  /// Steam then runs as the app 'steam' (source 'steam_client'; app_started if it was not running) and has focus; its pending windows no longer need attention. When Steam's windows close, focus returns to the app that had it before (or the launcher). Home brings the launcher back as usual.
  Future<SteamFocusResult> steamFocus([
    SteamFocusParams params = const SteamFocusParams(),
  ]) async =>
      SteamFocusResult.fromJson(await rpc('steam.focus', params.toJson()));

  /// Start an app and give it focus. Returns once it is spawned, before it shows a window.
  ///
  /// Exactly one of: 'id' (an app from apps.list), 'command' (argv, run as the session user), or 'url' (a Steam game, handed to the running Steam client; use it for games.list entries). If the app is already running it is focused instead and the result describes the running instance. Its windows are shown as soon as they appear; until then the launcher stays visible. Progress is reported through app_started, focus_changed and app_exited. The built-in id 'steam' opens Steam's Big Picture mode (steam://open/bigpicture, or 'steam -gamepadui' when Steam is not running) and shows Steam's own windows; it runs as the app 'steam' with source 'steam_client'. A Steam game's name comes from its Steam library manifest when it is installed.
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

  /// Ask a running app to quit; force it after a timeout. Returns at once, app_exited (reason 'closed') follows.
  ///
  /// A 'command' app gets SIGTERM (through its reaper, to its process group), and after the close timeout (default 5 s) everything still running under its reaper gets SIGKILL. A Steam game: every process under Steam's reaper for that app id gets SIGTERM, then SIGKILL after the timeout; Steam itself keeps running. A Steam game that has no processes yet (still being prepared by Steam) just stops being tracked. Steam ('steam_client'): Big Picture is asked to close (steam://close/bigpicture); Steam keeps running in the background. Closing an app that is already closing does nothing. If the app had focus, the launcher gets it back when it exits.
  Future<AppsCloseResult> appsClose(AppsCloseParams params) async =>
      AppsCloseResult.fromJson(await rpc('apps.close', params.toJson()));
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
    'games_changed' => GamesChangedEvent.fromJson(params),
    'steam_attention' => SteamAttentionEvent.fromJson(params),
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
