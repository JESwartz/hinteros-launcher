// GENERATED CODE - DO NOT EDIT.
// Source: schema/session-api.json (session API 0.6).
// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)
//
// ignore_for_file: unnecessary_this, unnecessary_cast, prefer_null_aware_operators, prefer_if_null_operators

import 'dart:convert';

/// API version this client was generated for (sent in `hello`).
const apiVersion = '0.6';

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
  'osk.show',
  'osk.hide',
  'keys.type',
  'keys.key',
  'keys.action',
  'system.info',
  'system.settings.get',
  'system.settings.set',
  'system.ssh.set',
  'system.generations.list',
  'system.rebuild',
  'system.hardware.redetect',
  'system.rollback',
  'system.update.check',
  'system.update.apply',
  'system.channel.set',
  'system.base.set',
  'system.jobs.get',
  'system.jobs.list',
  'system.jobs.cancel',
];

/// Event names in the schema.
const apiEventNames = <String>[
  'home_pressed',
  'app_started',
  'app_exited',
  'focus_changed',
  'input_nav',
  'games_changed',
  'apps_changed',
  'steam_attention',
  'osk_visibility',
  'job_started',
  'job_progress',
  'job_finished',
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
  'keyboard_unavailable': 2004,
  'osk_unavailable': 2005,
  'permission_denied': 3002,
  'job_failed': 3003,
  'insufficient_resources': 3004,
  'job_busy': 3005,
  'rate_limited': 3006,
  'state_conflict': 3007,
  'update_unreachable': 3008,
  'update_verification_failed': 3009,
  'not_found': 3010,
  'needs_acknowledgement': 3011,
  'authentication_required': 3012,
  'system_unavailable': 3001,
};

/// JSON-RPC error codes of the session API.
abstract final class ApiErrorCode {
  /// The line is not valid JSON.
  static const parseError = -32700;

  /// Valid JSON but not a valid JSON-RPC 2.0 request (batches are not supported).
  static const invalidRequest = -32600;

  /// Unknown method (or not available in the negotiated version).
  static const methodNotFound = -32601;

  /// Params do not match the method's params schema (unknown fields included), or fail a semantic check. data names the field when known.
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

  /// keys.*: nothing can deliver the input (no virtual keyboard because /dev/uinput could not be opened, and, for text and some actions, no gamescope input method).
  static const keyboardUnavailable = 2004;

  /// osk.show: the on-screen keyboard is disabled in the daemon's config.
  static const oskUnavailable = 2005;

  /// Not allowed: the caller does not own seat0's active session (seat), polkit said no (polkit), or the peer cannot be identified safely (peer: no SO_PEERPIDFD, or the process is gone).
  static const permissionDenied = 3002;

  /// Only in job_finished.error and jobs.get: the job failed (or was cancelled) at stage; log_hint is the last relevant log line.
  static const jobFailed = 3003;

  /// Not enough memory or free disk space for a rebuild.
  static const insufficientResources = 3004;

  /// Another job runs (only one at a time), or the job is past the point of cancelling.
  static const jobBusy = 3005;

  /// Too many mutating requests from this user (10 per minute, burst 3).
  static const rateLimited = 3006;

  /// Stale settings revision, or update.apply's rev is not the last verified check result.
  static const stateConflict = 3007;

  /// The update server cannot be reached (the 'home lab unreachable' screen).
  static const updateUnreachable = 3008;

  /// The channel tip is unsigned, signed by an unknown signer, or does not descend from the locked revision.
  static const updateVerificationFailed = 3009;

  /// Unknown generation or job.
  static const notFound = 3010;

  /// A downgrading channel or base switch without acknowledge_downgrade: true.
  static const needsAcknowledgement = 3011;

  /// polkit would allow the action only after interactive authentication (auth_admin: the admin password). No agent is involved yet: the call is refused, and the launcher can ask for the password once one exists.
  static const authenticationRequired = 3012;

  /// A relayed method could not reach the system service: it is down (reason down) or speaks another system API version (reason version_mismatch, e.g. after a switch until the session restarts). The session API keeps working.
  static const systemUnavailable = 3001;
}

/// MAJOR.MINOR
typedef ApiVersion = String;

/// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
typedef AppId = String;

/// A running app's id, or null for the launcher.
typedef FocusTarget = String;

/// Absolute path of an image file in Steam's library cache (readable by the session user), or null if Steam has not cached it.
typedef ArtworkPath = String;

/// Server-issued job id.
typedef JobId = String;

/// A full git commit id.
typedef Rev = String;

/// SHA-256 of state.json, hex.
typedef Revision = String;
typedef Fingerprint = String;
typedef PolkitAction = String;

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
  appsChanged('apps_changed'),
  steamAttention('steam_attention'),
  oskVisibility('osk_visibility'),
  jobStarted('job_started'),
  jobProgress('job_progress'),
  jobFinished('job_finished'),

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

  /// Absolute path to a local icon image file (PNG, SVG, ICO, JPEG, WebP), if any. Resolved by the daemon at runtime: an explicit path from the config, else the icon the app's .desktop file names, found in the installed icon themes, else (web apps) a cached download of the site's own icon. It may appear later (see apps_changed) or change. Absent: draw a placeholder, e.g. the first letter of the name.
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

/// A key on the daemon's virtual keyboard (US layout). Letters and digits are the unshifted keys: add the 'shift' modifier for capitals and symbols, or use keys.type for text. back, forward, refresh and the media keys are the multimedia keys of that name.
enum Key {
  a('a'),
  b('b'),
  c('c'),
  d('d'),
  e('e'),
  f('f'),
  g('g'),
  h('h'),
  i('i'),
  j('j'),
  k('k'),
  l('l'),
  m('m'),
  n('n'),
  o('o'),
  p('p'),
  q('q'),
  r('r'),
  s('s'),
  t('t'),
  u('u'),
  v('v'),
  w('w'),
  x('x'),
  y('y'),
  z('z'),
  v0('0'),
  v1('1'),
  v2('2'),
  v3('3'),
  v4('4'),
  v5('5'),
  v6('6'),
  v7('7'),
  v8('8'),
  v9('9'),
  f1('f1'),
  f2('f2'),
  f3('f3'),
  f4('f4'),
  f5('f5'),
  f6('f6'),
  f7('f7'),
  f8('f8'),
  f9('f9'),
  f10('f10'),
  f11('f11'),
  f12('f12'),
  enter('enter'),
  escape('escape'),
  backspace('backspace'),
  tab('tab'),
  space('space'),
  delete('delete'),
  insert('insert'),
  home('home'),
  end('end'),
  pageUp('page_up'),
  pageDown('page_down'),
  up('up'),
  down('down'),
  left('left'),
  right('right'),
  minus('minus'),
  equal('equal'),
  leftBracket('left_bracket'),
  rightBracket('right_bracket'),
  backslash('backslash'),
  semicolon('semicolon'),
  apostrophe('apostrophe'),
  grave('grave'),
  comma('comma'),
  period('period'),
  slash('slash'),
  capsLock('caps_lock'),
  contextMenu('context_menu'),
  back('back'),
  forward('forward'),
  refresh('refresh'),
  playPause('play_pause'),
  stop('stop'),
  nextTrack('next_track'),
  previousTrack('previous_track'),
  volumeUp('volume_up'),
  volumeDown('volume_down'),
  mute('mute'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Key(this.value);
  final String value;

  factory Key.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// A modifier held while a key is pressed.
enum Modifier {
  shift('shift'),
  ctrl('ctrl'),
  alt('alt'),
  meta('meta'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Modifier(this.value);
  final String value;

  factory Modifier.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// An editing action for keys.action.
enum KeyAction {
  backspace('backspace'),
  delete('delete'),
  enter('enter'),
  tab('tab'),
  escape('escape'),
  space('space'),
  left('left'),
  right('right'),
  up('up'),
  down('down'),
  home('home'),
  end('end'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const KeyAction(this.value);
  final String value;

  factory KeyAction.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
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

enum Channel {
  stable('stable'),
  beta('beta'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Channel(this.value);
  final String value;

  factory Channel.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum Base {
  stable('stable'),
  unstable('unstable'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Base(this.value);
  final String value;

  factory Base.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum JobKind {
  settings('settings'),
  ssh('ssh'),
  rebuild('rebuild'),
  hardwareRedetect('hardware_redetect'),
  updateCheck('update_check'),
  updateApply('update_apply'),
  rollback('rollback'),
  channel('channel'),
  base('base'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const JobKind(this.value);
  final String value;

  factory JobKind.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum JobState {
  running('running'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const JobState(this.value);
  final String value;

  factory JobState.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum Stage {
  preparing('preparing'),
  fetching('fetching'),
  verifying('verifying'),
  evaluating('evaluating'),
  downloading('downloading'),
  building('building'),
  activating('activating'),
  finishing('finishing'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Stage(this.value);
  final String value;

  factory Stage.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum Severity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Severity(this.value);
  final String value;

  factory Severity.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// A started job, or null when there was nothing to do.
class JobRef {
  const JobRef({required this.jobId});

  final String? jobId;

  factory JobRef.fromJson(Map<String, dynamic> json) =>
      JobRef(jobId: json['job_id'] == null ? null : json['job_id'] as String);

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is JobRef && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobRef(${jsonEncode(toJson())})';
}

class Generation {
  const Generation({
    required this.generation,
    required this.date,
    required this.rev,
    required this.current,
    required this.booted,
  });

  final int generation;

  /// Created (Unix time, seconds).
  final int date;

  /// System repo revision in its config snapshot, if any.
  final String? rev;
  final bool current;
  final bool booted;

  factory Generation.fromJson(Map<String, dynamic> json) => Generation(
    generation: json['generation'] as int,
    date: json['date'] as int,
    rev: json['rev'] == null ? null : json['rev'] as String,
    current: json['current'] as bool,
    booted: json['booted'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'date': date,
    'rev': rev,
    'current': current,
    'booted': booted,
  };

  @override
  bool operator ==(Object other) =>
      other is Generation && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Generation(${jsonEncode(toJson())})';
}

class AvailableUpdate {
  const AvailableUpdate({
    required this.rev,
    required this.date,
    required this.summary,
    required this.signer,
    required this.security,
    required this.commits,
  });

  /// A full git commit id.
  final String rev;

  /// Commit time (Unix time, seconds).
  final int date;

  /// Subject line of rev.
  final String summary;

  /// Allowed-signers principal that signed rev.
  final String signer;

  /// Highest Security: trailer severity among the new commits; non-null means the launcher shows the full-screen security notice.
  final Severity? security;
  final int commits;

  factory AvailableUpdate.fromJson(Map<String, dynamic> json) =>
      AvailableUpdate(
        rev: json['rev'] as String,
        date: json['date'] as int,
        summary: json['summary'] as String,
        signer: json['signer'] as String,
        security: json['security'] == null
            ? null
            : Severity.fromJson(json['security'] as String),
        commits: json['commits'] as int,
      );

  Map<String, dynamic> toJson() => {
    'rev': rev,
    'date': date,
    'summary': summary,
    'signer': signer,
    'security': security == null ? null : security!.toJson(),
    'commits': commits,
  };

  @override
  bool operator ==(Object other) =>
      other is AvailableUpdate &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AvailableUpdate(${jsonEncode(toJson())})';
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.channel,
    required this.currentRev,
    required this.available,
    required this.checkedAt,
  });

  final Channel channel;
  final String? currentRev;
  final AvailableUpdate? available;
  final int checkedAt;

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) =>
      UpdateCheckResult(
        channel: Channel.fromJson(json['channel'] as String),
        currentRev: json['current_rev'] == null
            ? null
            : json['current_rev'] as String,
        available: json['available'] == null
            ? null
            : AvailableUpdate.fromJson(
                (json['available'] as Map).cast<String, dynamic>(),
              ),
        checkedAt: json['checked_at'] as int,
      );

  Map<String, dynamic> toJson() => {
    'channel': channel.toJson(),
    'current_rev': currentRev,
    'available': available == null ? null : available!.toJson(),
    'checked_at': checkedAt,
  };

  @override
  bool operator ==(Object other) =>
      other is UpdateCheckResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'UpdateCheckResult(${jsonEncode(toJson())})';
}

class AppliedResult {
  const AppliedResult({required this.generation, required this.rev});

  final int? generation;
  final String? rev;

  factory AppliedResult.fromJson(Map<String, dynamic> json) => AppliedResult(
    generation: json['generation'] == null ? null : json['generation'] as int,
    rev: json['rev'] == null ? null : json['rev'] as String,
  );

  Map<String, dynamic> toJson() => {'generation': generation, 'rev': rev};

  @override
  bool operator ==(Object other) =>
      other is AppliedResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppliedResult(${jsonEncode(toJson())})';
}

class ProgressDetail {
  const ProgressDetail({
    this.pathsDone,
    this.pathsTotal,
    this.bytesDone,
    this.bytesTotal,
  });

  final int? pathsDone;
  final int? pathsTotal;
  final int? bytesDone;
  final int? bytesTotal;

  factory ProgressDetail.fromJson(Map<String, dynamic> json) => ProgressDetail(
    pathsDone: json['paths_done'] == null ? null : json['paths_done'] as int,
    pathsTotal: json['paths_total'] == null ? null : json['paths_total'] as int,
    bytesDone: json['bytes_done'] == null ? null : json['bytes_done'] as int,
    bytesTotal: json['bytes_total'] == null ? null : json['bytes_total'] as int,
  );

  Map<String, dynamic> toJson() => {
    'paths_done': ?pathsDone,
    'paths_total': ?pathsTotal,
    'bytes_done': ?bytesDone,
    'bytes_total': ?bytesTotal,
  };

  @override
  bool operator ==(Object other) =>
      other is ProgressDetail &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProgressDetail(${jsonEncode(toJson())})';
}

/// A JSON-RPC error object (codes from this document's errors).
class ErrorObject {
  const ErrorObject({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final Object? data;

  factory ErrorObject.fromJson(Map<String, dynamic> json) => ErrorObject(
    code: json['code'] as int,
    message: json['message'] as String,
    data: json['data'] == null ? null : json['data'],
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'data': ?data,
  };

  @override
  bool operator ==(Object other) =>
      other is ErrorObject &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ErrorObject(${jsonEncode(toJson())})';
}

class Job {
  const Job({
    required this.jobId,
    required this.kind,
    required this.uid,
    required this.state,
    required this.stage,
    required this.createdAt,
    required this.finishedAt,
    required this.error,
    required this.result,
    required this.sessionRestartRequired,
  });

  /// Server-issued job id.
  final String jobId;
  final JobKind kind;

  /// Who started it.
  final int uid;
  final JobState state;

  /// Current or last reached stage.
  final Stage? stage;
  final int createdAt;
  final int? finishedAt;
  final ErrorObject? error;
  final Object? result;
  final bool sessionRestartRequired;

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    jobId: json['job_id'] as String,
    kind: JobKind.fromJson(json['kind'] as String),
    uid: json['uid'] as int,
    state: JobState.fromJson(json['state'] as String),
    stage: json['stage'] == null
        ? null
        : Stage.fromJson(json['stage'] as String),
    createdAt: json['created_at'] as int,
    finishedAt: json['finished_at'] == null ? null : json['finished_at'] as int,
    error: json['error'] == null
        ? null
        : ErrorObject.fromJson((json['error'] as Map).cast<String, dynamic>()),
    result: json['result'] == null ? null : json['result'],
    sessionRestartRequired: json['session_restart_required'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'kind': kind.toJson(),
    'uid': uid,
    'state': state.toJson(),
    'stage': stage == null ? null : stage!.toJson(),
    'created_at': createdAt,
    'finished_at': finishedAt,
    'error': error == null ? null : error!.toJson(),
    'result': result,
    'session_restart_required': sessionRestartRequired,
  };

  @override
  bool operator ==(Object other) =>
      other is Job && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Job(${jsonEncode(toJson())})';
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

class OskShowParams {
  const OskShowParams();

  factory OskShowParams.fromJson(Map<String, dynamic> json) => OskShowParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is OskShowParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'OskShowParams(${jsonEncode(toJson())})';
}

class OskShowResult {
  const OskShowResult({required this.visible});

  /// Whether the on-screen keyboard is now visible.
  final bool visible;

  factory OskShowResult.fromJson(Map<String, dynamic> json) =>
      OskShowResult(visible: json['visible'] as bool);

  Map<String, dynamic> toJson() => {'visible': visible};

  @override
  bool operator ==(Object other) =>
      other is OskShowResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'OskShowResult(${jsonEncode(toJson())})';
}

class OskHideParams {
  const OskHideParams();

  factory OskHideParams.fromJson(Map<String, dynamic> json) => OskHideParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is OskHideParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'OskHideParams(${jsonEncode(toJson())})';
}

class OskHideResult {
  const OskHideResult({required this.visible});

  /// Whether the on-screen keyboard is now visible.
  final bool visible;

  factory OskHideResult.fromJson(Map<String, dynamic> json) =>
      OskHideResult(visible: json['visible'] as bool);

  Map<String, dynamic> toJson() => {'visible': visible};

  @override
  bool operator ==(Object other) =>
      other is OskHideResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'OskHideResult(${jsonEncode(toJson())})';
}

class KeysTypeParams {
  const KeysTypeParams({required this.text});

  final String text;

  factory KeysTypeParams.fromJson(Map<String, dynamic> json) =>
      KeysTypeParams(text: json['text'] as String);

  Map<String, dynamic> toJson() => {'text': text};

  @override
  bool operator ==(Object other) =>
      other is KeysTypeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeysTypeParams(${jsonEncode(toJson())})';
}

class KeysTypeResult {
  const KeysTypeResult({required this.untypeable});

  /// Characters that were skipped, in order (duplicates kept).
  final List<String> untypeable;

  factory KeysTypeResult.fromJson(Map<String, dynamic> json) => KeysTypeResult(
    untypeable: (json['untypeable'] as List).map((x) => x as String).toList(),
  );

  Map<String, dynamic> toJson() => {'untypeable': untypeable};

  @override
  bool operator ==(Object other) =>
      other is KeysTypeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeysTypeResult(${jsonEncode(toJson())})';
}

class KeysKeyParams {
  const KeysKeyParams({required this.key, this.modifiers});

  /// A key on the daemon's virtual keyboard (US layout). Letters and digits are the unshifted keys: add the 'shift' modifier for capitals and symbols, or use keys.type for text. back, forward, refresh and the media keys are the multimedia keys of that name.
  final Key key;
  final List<Modifier>? modifiers;

  factory KeysKeyParams.fromJson(Map<String, dynamic> json) => KeysKeyParams(
    key: Key.fromJson(json['key'] as String),
    modifiers: json['modifiers'] == null
        ? null
        : (json['modifiers'] as List)
              .map((x) => Modifier.fromJson(x as String))
              .toList(),
  );

  Map<String, dynamic> toJson() => {
    'key': key.toJson(),
    if (modifiers != null)
      'modifiers': modifiers!.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is KeysKeyParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeysKeyParams(${jsonEncode(toJson())})';
}

class KeysKeyResult {
  const KeysKeyResult();

  factory KeysKeyResult.fromJson(Map<String, dynamic> json) => KeysKeyResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is KeysKeyResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeysKeyResult(${jsonEncode(toJson())})';
}

class KeysActionParams {
  const KeysActionParams({required this.action});

  /// An editing action for keys.action.
  final KeyAction action;

  factory KeysActionParams.fromJson(Map<String, dynamic> json) =>
      KeysActionParams(action: KeyAction.fromJson(json['action'] as String));

  Map<String, dynamic> toJson() => {'action': action.toJson()};

  @override
  bool operator ==(Object other) =>
      other is KeysActionParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeysActionParams(${jsonEncode(toJson())})';
}

class KeysActionResult {
  const KeysActionResult();

  factory KeysActionResult.fromJson(Map<String, dynamic> json) =>
      KeysActionResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is KeysActionResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeysActionResult(${jsonEncode(toJson())})';
}

class SystemInfoParams {
  const SystemInfoParams();

  factory SystemInfoParams.fromJson(Map<String, dynamic> json) =>
      SystemInfoParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemInfoParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemInfoParams(${jsonEncode(toJson())})';
}

class SystemInfoResultSsh {
  const SystemInfoResultSsh({
    required this.enabled,
    required this.hostKeyFingerprints,
  });

  final bool enabled;

  /// SHA256 fingerprints of the SSH host keys, for checking the first connection.
  final List<String> hostKeyFingerprints;

  factory SystemInfoResultSsh.fromJson(Map<String, dynamic> json) =>
      SystemInfoResultSsh(
        enabled: json['enabled'] as bool,
        hostKeyFingerprints: (json['host_key_fingerprints'] as List)
            .map((x) => x as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'host_key_fingerprints': hostKeyFingerprints,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemInfoResultSsh &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemInfoResultSsh(${jsonEncode(toJson())})';
}

class SystemInfoResult {
  const SystemInfoResult({
    required this.version,
    required this.channel,
    required this.base,
    required this.rev,
    required this.generation,
    required this.hostname,
    required this.dev,
    required this.ssh,
  });

  /// HinterOS release of the running generation, or 'unknown'.
  final String version;

  /// Channel /etc/hinteros follows; null without a locked channel (the dev box).
  final Channel? channel;
  final Base base;

  /// Locked system repo revision.
  final String? rev;

  /// Current system generation.
  final int? generation;
  final String hostname;

  /// A dev build (hinteros.dev.enable): the launcher shows a DEV badge.
  final bool dev;
  final SystemInfoResultSsh ssh;

  factory SystemInfoResult.fromJson(Map<String, dynamic> json) =>
      SystemInfoResult(
        version: json['version'] as String,
        channel: json['channel'] == null
            ? null
            : Channel.fromJson(json['channel'] as String),
        base: Base.fromJson(json['base'] as String),
        rev: json['rev'] == null ? null : json['rev'] as String,
        generation: json['generation'] == null
            ? null
            : json['generation'] as int,
        hostname: json['hostname'] as String,
        dev: json['dev'] as bool,
        ssh: SystemInfoResultSsh.fromJson(
          (json['ssh'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'version': version,
    'channel': channel == null ? null : channel!.toJson(),
    'base': base.toJson(),
    'rev': rev,
    'generation': generation,
    'hostname': hostname,
    'dev': dev,
    'ssh': ssh.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemInfoResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemInfoResult(${jsonEncode(toJson())})';
}

class SystemSettingsGetParams {
  const SystemSettingsGetParams();

  factory SystemSettingsGetParams.fromJson(Map<String, dynamic> json) =>
      SystemSettingsGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemSettingsGetParams(${jsonEncode(toJson())})';
}

class SystemSettingsGetResultSettingsSsh {
  const SystemSettingsGetResultSettingsSsh({required this.enabled});

  /// sshd runs; login is the admin account with its password.
  final bool enabled;

  factory SystemSettingsGetResultSettingsSsh.fromJson(
    Map<String, dynamic> json,
  ) => SystemSettingsGetResultSettingsSsh(enabled: json['enabled'] as bool);

  Map<String, dynamic> toJson() => {'enabled': enabled};

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsGetResultSettingsSsh &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemSettingsGetResultSettingsSsh(${jsonEncode(toJson())})';
}

class SystemSettingsGetResultSettings {
  const SystemSettingsGetResultSettings({
    required this.base,
    required this.ssh,
  });

  final Base base;
  final SystemSettingsGetResultSettingsSsh ssh;

  factory SystemSettingsGetResultSettings.fromJson(Map<String, dynamic> json) =>
      SystemSettingsGetResultSettings(
        base: Base.fromJson(json['base'] as String),
        ssh: SystemSettingsGetResultSettingsSsh.fromJson(
          (json['ssh'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {'base': base.toJson(), 'ssh': ssh.toJson()};

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsGetResultSettings &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemSettingsGetResultSettings(${jsonEncode(toJson())})';
}

class SystemSettingsGetResult {
  const SystemSettingsGetResult({
    required this.revision,
    required this.settings,
  });

  /// SHA-256 of state.json, hex.
  final String revision;
  final SystemSettingsGetResultSettings settings;

  factory SystemSettingsGetResult.fromJson(Map<String, dynamic> json) =>
      SystemSettingsGetResult(
        revision: json['revision'] as String,
        settings: SystemSettingsGetResultSettings.fromJson(
          (json['settings'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'settings': settings.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemSettingsGetResult(${jsonEncode(toJson())})';
}

class SystemSettingsSetParamsChanges {
  const SystemSettingsSetParamsChanges();

  factory SystemSettingsSetParamsChanges.fromJson(Map<String, dynamic> json) =>
      SystemSettingsSetParamsChanges();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsSetParamsChanges &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemSettingsSetParamsChanges(${jsonEncode(toJson())})';
}

class SystemSettingsSetParams {
  const SystemSettingsSetParams({
    required this.revision,
    required this.changes,
  });

  /// SHA-256 of state.json, hex.
  final String revision;
  final SystemSettingsSetParamsChanges changes;

  factory SystemSettingsSetParams.fromJson(Map<String, dynamic> json) =>
      SystemSettingsSetParams(
        revision: json['revision'] as String,
        changes: SystemSettingsSetParamsChanges.fromJson(
          (json['changes'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'changes': changes.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemSettingsSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemSettingsSetResult {
  const SystemSettingsSetResult({required this.jobId});

  final String? jobId;

  factory SystemSettingsSetResult.fromJson(Map<String, dynamic> json) =>
      SystemSettingsSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemSettingsSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemSettingsSetResult(${jsonEncode(toJson())})';
}

class SystemSshSetParams {
  const SystemSshSetParams({required this.enabled});

  final bool enabled;

  factory SystemSshSetParams.fromJson(Map<String, dynamic> json) =>
      SystemSshSetParams(enabled: json['enabled'] as bool);

  Map<String, dynamic> toJson() => {'enabled': enabled};

  @override
  bool operator ==(Object other) =>
      other is SystemSshSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemSshSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemSshSetResult {
  const SystemSshSetResult({required this.jobId});

  final String? jobId;

  factory SystemSshSetResult.fromJson(Map<String, dynamic> json) =>
      SystemSshSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemSshSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemSshSetResult(${jsonEncode(toJson())})';
}

class SystemGenerationsListParams {
  const SystemGenerationsListParams();

  factory SystemGenerationsListParams.fromJson(Map<String, dynamic> json) =>
      SystemGenerationsListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemGenerationsListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemGenerationsListParams(${jsonEncode(toJson())})';
}

class SystemGenerationsListResult {
  const SystemGenerationsListResult({required this.generations});

  final List<Generation> generations;

  factory SystemGenerationsListResult.fromJson(Map<String, dynamic> json) =>
      SystemGenerationsListResult(
        generations: (json['generations'] as List)
            .map((x) => Generation.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'generations': generations.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemGenerationsListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemGenerationsListResult(${jsonEncode(toJson())})';
}

class SystemRebuildParams {
  const SystemRebuildParams();

  factory SystemRebuildParams.fromJson(Map<String, dynamic> json) =>
      SystemRebuildParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemRebuildParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemRebuildParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemRebuildResult {
  const SystemRebuildResult({required this.jobId});

  final String? jobId;

  factory SystemRebuildResult.fromJson(Map<String, dynamic> json) =>
      SystemRebuildResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemRebuildResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemRebuildResult(${jsonEncode(toJson())})';
}

class SystemHardwareRedetectParams {
  const SystemHardwareRedetectParams();

  factory SystemHardwareRedetectParams.fromJson(Map<String, dynamic> json) =>
      SystemHardwareRedetectParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemHardwareRedetectParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemHardwareRedetectParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemHardwareRedetectResult {
  const SystemHardwareRedetectResult({required this.jobId});

  final String? jobId;

  factory SystemHardwareRedetectResult.fromJson(Map<String, dynamic> json) =>
      SystemHardwareRedetectResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemHardwareRedetectResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemHardwareRedetectResult(${jsonEncode(toJson())})';
}

class SystemRollbackParams {
  const SystemRollbackParams({this.generation});

  final int? generation;

  factory SystemRollbackParams.fromJson(Map<String, dynamic> json) =>
      SystemRollbackParams(
        generation: json['generation'] == null
            ? null
            : json['generation'] as int,
      );

  Map<String, dynamic> toJson() => {'generation': ?generation};

  @override
  bool operator ==(Object other) =>
      other is SystemRollbackParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemRollbackParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemRollbackResult {
  const SystemRollbackResult({required this.jobId});

  final String? jobId;

  factory SystemRollbackResult.fromJson(Map<String, dynamic> json) =>
      SystemRollbackResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemRollbackResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemRollbackResult(${jsonEncode(toJson())})';
}

class SystemUpdateCheckParams {
  const SystemUpdateCheckParams();

  factory SystemUpdateCheckParams.fromJson(Map<String, dynamic> json) =>
      SystemUpdateCheckParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemUpdateCheckParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemUpdateCheckParams(${jsonEncode(toJson())})';
}

class SystemUpdateCheckResult {
  const SystemUpdateCheckResult({required this.jobId, required this.result});

  final String? jobId;
  final UpdateCheckResult? result;

  factory SystemUpdateCheckResult.fromJson(Map<String, dynamic> json) =>
      SystemUpdateCheckResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
        result: json['result'] == null
            ? null
            : UpdateCheckResult.fromJson(
                (json['result'] as Map).cast<String, dynamic>(),
              ),
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'result': result == null ? null : result!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemUpdateCheckResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemUpdateCheckResult(${jsonEncode(toJson())})';
}

class SystemUpdateApplyParams {
  const SystemUpdateApplyParams({required this.rev});

  /// A full git commit id.
  final String rev;

  factory SystemUpdateApplyParams.fromJson(Map<String, dynamic> json) =>
      SystemUpdateApplyParams(rev: json['rev'] as String);

  Map<String, dynamic> toJson() => {'rev': rev};

  @override
  bool operator ==(Object other) =>
      other is SystemUpdateApplyParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemUpdateApplyParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemUpdateApplyResult {
  const SystemUpdateApplyResult({required this.jobId});

  final String? jobId;

  factory SystemUpdateApplyResult.fromJson(Map<String, dynamic> json) =>
      SystemUpdateApplyResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemUpdateApplyResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemUpdateApplyResult(${jsonEncode(toJson())})';
}

class SystemChannelSetParams {
  const SystemChannelSetParams({
    required this.channel,
    this.acknowledgeDowngrade,
  });

  final Channel channel;
  final bool? acknowledgeDowngrade;

  factory SystemChannelSetParams.fromJson(Map<String, dynamic> json) =>
      SystemChannelSetParams(
        channel: Channel.fromJson(json['channel'] as String),
        acknowledgeDowngrade: json['acknowledge_downgrade'] == null
            ? null
            : json['acknowledge_downgrade'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'channel': channel.toJson(),
    'acknowledge_downgrade': ?acknowledgeDowngrade,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemChannelSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemChannelSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemChannelSetResult {
  const SystemChannelSetResult({required this.jobId});

  final String? jobId;

  factory SystemChannelSetResult.fromJson(Map<String, dynamic> json) =>
      SystemChannelSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemChannelSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemChannelSetResult(${jsonEncode(toJson())})';
}

class SystemBaseSetParams {
  const SystemBaseSetParams({required this.base, this.acknowledgeDowngrade});

  final Base base;
  final bool? acknowledgeDowngrade;

  factory SystemBaseSetParams.fromJson(Map<String, dynamic> json) =>
      SystemBaseSetParams(
        base: Base.fromJson(json['base'] as String),
        acknowledgeDowngrade: json['acknowledge_downgrade'] == null
            ? null
            : json['acknowledge_downgrade'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'base': base.toJson(),
    'acknowledge_downgrade': ?acknowledgeDowngrade,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemBaseSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemBaseSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemBaseSetResult {
  const SystemBaseSetResult({required this.jobId});

  final String? jobId;

  factory SystemBaseSetResult.fromJson(Map<String, dynamic> json) =>
      SystemBaseSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemBaseSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemBaseSetResult(${jsonEncode(toJson())})';
}

class SystemJobsGetParams {
  const SystemJobsGetParams({required this.jobId});

  /// Server-issued job id.
  final String jobId;

  factory SystemJobsGetParams.fromJson(Map<String, dynamic> json) =>
      SystemJobsGetParams(jobId: json['job_id'] as String);

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemJobsGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemJobsGetParams(${jsonEncode(toJson())})';
}

class SystemJobsGetResult {
  const SystemJobsGetResult({required this.job});

  final Job job;

  factory SystemJobsGetResult.fromJson(Map<String, dynamic> json) =>
      SystemJobsGetResult(
        job: Job.fromJson((json['job'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {'job': job.toJson()};

  @override
  bool operator ==(Object other) =>
      other is SystemJobsGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemJobsGetResult(${jsonEncode(toJson())})';
}

class SystemJobsListParams {
  const SystemJobsListParams();

  factory SystemJobsListParams.fromJson(Map<String, dynamic> json) =>
      SystemJobsListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemJobsListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemJobsListParams(${jsonEncode(toJson())})';
}

class SystemJobsListResult {
  const SystemJobsListResult({required this.jobs});

  final List<Job> jobs;

  factory SystemJobsListResult.fromJson(Map<String, dynamic> json) =>
      SystemJobsListResult(
        jobs: (json['jobs'] as List)
            .map((x) => Job.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'jobs': jobs.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemJobsListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemJobsListResult(${jsonEncode(toJson())})';
}

class SystemJobsCancelParams {
  const SystemJobsCancelParams({required this.jobId});

  /// Server-issued job id.
  final String jobId;

  factory SystemJobsCancelParams.fromJson(Map<String, dynamic> json) =>
      SystemJobsCancelParams(jobId: json['job_id'] as String);

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemJobsCancelParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemJobsCancelParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemJobsCancelResult {
  const SystemJobsCancelResult({required this.jobId});

  final String? jobId;

  factory SystemJobsCancelResult.fromJson(Map<String, dynamic> json) =>
      SystemJobsCancelResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemJobsCancelResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemJobsCancelResult(${jsonEncode(toJson())})';
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

/// A controller navigation intent, sent to the launcher while it has focus, or only to the on-screen keyboard while it is visible.
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

/// An app's resolved icon became available or changed (for example a web app's icon finished downloading). Call apps.list again.
final class AppsChangedEvent extends SessionEvent {
  const AppsChangedEvent();

  factory AppsChangedEvent.fromJson(Map<String, dynamic> json) =>
      AppsChangedEvent();

  Map<String, dynamic> toJson() => {};

  @override
  String get name => 'apps_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is AppsChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsChangedEvent(${jsonEncode(toJson())})';
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

/// The on-screen keyboard was shown or hidden (osk.show/osk.hide, the controller chord, Home, or a focus change).
final class OskVisibilityEvent extends SessionEvent {
  const OskVisibilityEvent({required this.visible});

  final bool visible;

  factory OskVisibilityEvent.fromJson(Map<String, dynamic> json) =>
      OskVisibilityEvent(visible: json['visible'] as bool);

  Map<String, dynamic> toJson() => {'visible': visible};

  @override
  String get name => 'osk_visibility';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is OskVisibilityEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'OskVisibilityEvent(${jsonEncode(toJson())})';
}

/// Relayed from the system service. A job was started (by any caller).
final class JobStartedEvent extends SessionEvent {
  const JobStartedEvent({
    required this.jobId,
    required this.kind,
    required this.uid,
  });

  /// Server-issued job id.
  final String jobId;
  final JobKind kind;
  final int uid;

  factory JobStartedEvent.fromJson(Map<String, dynamic> json) =>
      JobStartedEvent(
        jobId: json['job_id'] as String,
        kind: JobKind.fromJson(json['kind'] as String),
        uid: json['uid'] as int,
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'kind': kind.toJson(),
    'uid': uid,
  };

  @override
  String get name => 'job_started';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is JobStartedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobStartedEvent(${jsonEncode(toJson())})';
}

/// Relayed from the system service. A job reached a stage or made progress (at most 4 per second). percent only where meaningful (downloading).
final class JobProgressEvent extends SessionEvent {
  const JobProgressEvent({
    required this.jobId,
    required this.stage,
    this.percent,
    this.detail,
  });

  /// Server-issued job id.
  final String jobId;
  final Stage stage;
  final int? percent;
  final ProgressDetail? detail;

  factory JobProgressEvent.fromJson(Map<String, dynamic> json) =>
      JobProgressEvent(
        jobId: json['job_id'] as String,
        stage: Stage.fromJson(json['stage'] as String),
        percent: json['percent'] == null ? null : json['percent'] as int,
        detail: json['detail'] == null
            ? null
            : ProgressDetail.fromJson(
                (json['detail'] as Map).cast<String, dynamic>(),
              ),
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'stage': stage.toJson(),
    'percent': ?percent,
    if (detail != null) 'detail': detail!.toJson(),
  };

  @override
  String get name => 'job_progress';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is JobProgressEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobProgressEvent(${jsonEncode(toJson())})';
}

/// Relayed from the system service. A job ended. session_restart_required: the switch replaced the system service's API or the session daemon, so the launcher should offer a session restart.
final class JobFinishedEvent extends SessionEvent {
  const JobFinishedEvent({
    required this.jobId,
    required this.kind,
    required this.ok,
    this.error,
    this.result,
    required this.sessionRestartRequired,
  });

  /// Server-issued job id.
  final String jobId;
  final JobKind kind;
  final bool ok;

  /// A JSON-RPC error object (codes from this document's errors).
  final ErrorObject? error;

  /// update_check jobs: an UpdateCheckResult; jobs that change the system: an AppliedResult.
  final Object? result;
  final bool sessionRestartRequired;

  factory JobFinishedEvent.fromJson(Map<String, dynamic> json) =>
      JobFinishedEvent(
        jobId: json['job_id'] as String,
        kind: JobKind.fromJson(json['kind'] as String),
        ok: json['ok'] as bool,
        error: json['error'] == null
            ? null
            : ErrorObject.fromJson(
                (json['error'] as Map).cast<String, dynamic>(),
              ),
        result: json['result'] == null ? null : json['result'],
        sessionRestartRequired: json['session_restart_required'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'kind': kind.toJson(),
    'ok': ok,
    if (error != null) 'error': error!.toJson(),
    'result': ?result,
    'session_restart_required': sessionRestartRequired,
  };

  @override
  String get name => 'job_finished';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is JobFinishedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobFinishedEvent(${jsonEncode(toJson())})';
}

class InvalidParamsData {
  const InvalidParamsData({required this.field, required this.reason});

  final String field;
  final String reason;

  factory InvalidParamsData.fromJson(Map<String, dynamic> json) =>
      InvalidParamsData(
        field: json['field'] as String,
        reason: json['reason'] as String,
      );

  Map<String, dynamic> toJson() => {'field': field, 'reason': reason};

  @override
  bool operator ==(Object other) =>
      other is InvalidParamsData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InvalidParamsData(${jsonEncode(toJson())})';
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

enum PermissionDeniedDataReason {
  seat('seat'),
  polkit('polkit'),
  peer('peer'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const PermissionDeniedDataReason(this.value);
  final String value;

  factory PermissionDeniedDataReason.fromJson(String value) =>
      values.firstWhere(
        (e) => e != unknown && e.value == value,
        orElse: () => unknown,
      );

  String toJson() => value;
}

class PermissionDeniedData {
  const PermissionDeniedData({required this.action, required this.reason});

  final String action;
  final PermissionDeniedDataReason reason;

  factory PermissionDeniedData.fromJson(Map<String, dynamic> json) =>
      PermissionDeniedData(
        action: json['action'] as String,
        reason: PermissionDeniedDataReason.fromJson(json['reason'] as String),
      );

  Map<String, dynamic> toJson() => {
    'action': action,
    'reason': reason.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PermissionDeniedData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PermissionDeniedData(${jsonEncode(toJson())})';
}

class JobFailedData {
  const JobFailedData({required this.stage, required this.logHint});

  final Stage stage;
  final String logHint;

  factory JobFailedData.fromJson(Map<String, dynamic> json) => JobFailedData(
    stage: Stage.fromJson(json['stage'] as String),
    logHint: json['log_hint'] as String,
  );

  Map<String, dynamic> toJson() => {
    'stage': stage.toJson(),
    'log_hint': logHint,
  };

  @override
  bool operator ==(Object other) =>
      other is JobFailedData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobFailedData(${jsonEncode(toJson())})';
}

enum InsufficientResourcesDataKind {
  memory('memory'),
  disk('disk'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const InsufficientResourcesDataKind(this.value);
  final String value;

  factory InsufficientResourcesDataKind.fromJson(String value) =>
      values.firstWhere(
        (e) => e != unknown && e.value == value,
        orElse: () => unknown,
      );

  String toJson() => value;
}

class InsufficientResourcesData {
  const InsufficientResourcesData({
    required this.kind,
    required this.neededBytes,
    required this.availableBytes,
  });

  final InsufficientResourcesDataKind kind;
  final int neededBytes;
  final int availableBytes;

  factory InsufficientResourcesData.fromJson(Map<String, dynamic> json) =>
      InsufficientResourcesData(
        kind: InsufficientResourcesDataKind.fromJson(json['kind'] as String),
        neededBytes: json['needed_bytes'] as int,
        availableBytes: json['available_bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
    'kind': kind.toJson(),
    'needed_bytes': neededBytes,
    'available_bytes': availableBytes,
  };

  @override
  bool operator ==(Object other) =>
      other is InsufficientResourcesData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InsufficientResourcesData(${jsonEncode(toJson())})';
}

class JobBusyData {
  const JobBusyData({required this.jobId});

  /// Server-issued job id.
  final String jobId;

  factory JobBusyData.fromJson(Map<String, dynamic> json) =>
      JobBusyData(jobId: json['job_id'] as String);

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is JobBusyData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobBusyData(${jsonEncode(toJson())})';
}

class RateLimitedData {
  const RateLimitedData({required this.retryAfterMs});

  final int retryAfterMs;

  factory RateLimitedData.fromJson(Map<String, dynamic> json) =>
      RateLimitedData(retryAfterMs: json['retry_after_ms'] as int);

  Map<String, dynamic> toJson() => {'retry_after_ms': retryAfterMs};

  @override
  bool operator ==(Object other) =>
      other is RateLimitedData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'RateLimitedData(${jsonEncode(toJson())})';
}

enum StateConflictDataReason {
  revision('revision'),
  updateRev('update_rev'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const StateConflictDataReason(this.value);
  final String value;

  factory StateConflictDataReason.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class StateConflictData {
  const StateConflictData({required this.reason});

  final StateConflictDataReason reason;

  factory StateConflictData.fromJson(Map<String, dynamic> json) =>
      StateConflictData(
        reason: StateConflictDataReason.fromJson(json['reason'] as String),
      );

  Map<String, dynamic> toJson() => {'reason': reason.toJson()};

  @override
  bool operator ==(Object other) =>
      other is StateConflictData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StateConflictData(${jsonEncode(toJson())})';
}

class UpdateUnreachableData {
  const UpdateUnreachableData({required this.host});

  final String host;

  factory UpdateUnreachableData.fromJson(Map<String, dynamic> json) =>
      UpdateUnreachableData(host: json['host'] as String);

  Map<String, dynamic> toJson() => {'host': host};

  @override
  bool operator ==(Object other) =>
      other is UpdateUnreachableData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'UpdateUnreachableData(${jsonEncode(toJson())})';
}

enum UpdateVerificationFailedDataReason {
  unsigned('unsigned'),
  unknownSigner('unknown_signer'),
  notFastForward('not_fast_forward'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const UpdateVerificationFailedDataReason(this.value);
  final String value;

  factory UpdateVerificationFailedDataReason.fromJson(String value) =>
      values.firstWhere(
        (e) => e != unknown && e.value == value,
        orElse: () => unknown,
      );

  String toJson() => value;
}

class UpdateVerificationFailedData {
  const UpdateVerificationFailedData({required this.reason});

  final UpdateVerificationFailedDataReason reason;

  factory UpdateVerificationFailedData.fromJson(Map<String, dynamic> json) =>
      UpdateVerificationFailedData(
        reason: UpdateVerificationFailedDataReason.fromJson(
          json['reason'] as String,
        ),
      );

  Map<String, dynamic> toJson() => {'reason': reason.toJson()};

  @override
  bool operator ==(Object other) =>
      other is UpdateVerificationFailedData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'UpdateVerificationFailedData(${jsonEncode(toJson())})';
}

class AuthenticationRequiredData {
  const AuthenticationRequiredData({required this.action});

  final String action;

  factory AuthenticationRequiredData.fromJson(Map<String, dynamic> json) =>
      AuthenticationRequiredData(action: json['action'] as String);

  Map<String, dynamic> toJson() => {'action': action};

  @override
  bool operator ==(Object other) =>
      other is AuthenticationRequiredData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthenticationRequiredData(${jsonEncode(toJson())})';
}

enum SystemUnavailableDataReason {
  down('down'),
  versionMismatch('version_mismatch'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const SystemUnavailableDataReason(this.value);
  final String value;

  factory SystemUnavailableDataReason.fromJson(String value) =>
      values.firstWhere(
        (e) => e != unknown && e.value == value,
        orElse: () => unknown,
      );

  String toJson() => value;
}

class SystemUnavailableData {
  const SystemUnavailableData({required this.reason});

  final SystemUnavailableDataReason reason;

  factory SystemUnavailableData.fromJson(Map<String, dynamic> json) =>
      SystemUnavailableData(
        reason: SystemUnavailableDataReason.fromJson(json['reason'] as String),
      );

  Map<String, dynamic> toJson() => {'reason': reason.toJson()};

  @override
  bool operator ==(Object other) =>
      other is SystemUnavailableData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemUnavailableData(${jsonEncode(toJson())})';
}

/// Typed calls for every method of the session API.
///
/// Implementors provide [rpc], which sends one request and returns its
/// result object (or throws).
mixin SessionApiMethods {
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params);

  /// Version handshake. Must be the first request on a connection.
  ///
  /// The client sends the API version it was built against. Majors must match (during 0.x the minor must match too). The result carries the negotiated version: min(client, server). On a mismatch the server answers with version_mismatch and closes the connection. The client name 'hinteros-osk' is reserved for the on-screen keyboard: such connections receive input_nav while the keyboard is visible, and only then.
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

  /// Show the on-screen keyboard over whatever has focus.
  ///
  /// The on-screen keyboard is a separate client (hinteros-osk) whose window the daemon shows as a gamescope overlay; it never takes focus, so typed keys reach the focused app. While it is visible, InputPlumber is in intercept mode ALL and input_nav goes only to the connection whose hello client name is 'hinteros-osk' (not to the launcher). osk_visibility follows if the visibility changed. Showing it again does nothing. The user can also summon it with the controller (Guide + Y by default).
  Future<OskShowResult> oskShow([
    OskShowParams params = const OskShowParams(),
  ]) async => OskShowResult.fromJson(await rpc('osk.show', params.toJson()));

  /// Hide the on-screen keyboard.
  ///
  /// Restores the previous input routing: InputPlumber's mode for whatever has focus, input_nav to the launcher while it has focus. osk_visibility follows if the visibility changed. Home and focus changes also hide it.
  Future<OskHideResult> oskHide([
    OskHideParams params = const OskHideParams(),
  ]) async => OskHideResult.fromJson(await rpc('osk.hide', params.toJson()));

  /// Type text into the focused app (never into the on-screen keyboard).
  ///
  /// Characters on the US keyboard layout are typed through the daemon's virtual keyboard (uinput, with Shift for capitals and symbols; newline = Enter, tab = Tab); others go through gamescope's input method, one character at a time. Returns at once; typing happens in the background in order with other keys.* calls. Characters neither path can type are skipped and listed in 'untypeable'.
  Future<KeysTypeResult> keysType(KeysTypeParams params) async =>
      KeysTypeResult.fromJson(await rpc('keys.type', params.toJson()));

  /// Press and release one key, optionally with modifiers, in the focused app.
  ///
  /// For keys that are not text (function keys, shortcuts such as ctrl+l). Needs the virtual keyboard (uinput). Returns at once; the key is sent in order with other keys.* calls.
  Future<KeysKeyResult> keysKey(KeysKeyParams params) async =>
      KeysKeyResult.fromJson(await rpc('keys.key', params.toJson()));

  /// An editing action in the focused app: backspace, enter, cursor movement, ...
  ///
  /// Sent as the matching key through the virtual keyboard; without it, backspace, delete, enter and the arrows fall back to gamescope's input method. Returns at once.
  Future<KeysActionResult> keysAction(KeysActionParams params) async =>
      KeysActionResult.fromJson(await rpc('keys.action', params.toJson()));

  /// Relayed to the system service's system.info. What is running: release, channel, base, locked revision, generation, hostname, dev build, SSH state and host key fingerprints. Read-only.
  Future<SystemInfoResult> systemInfo([
    SystemInfoParams params = const SystemInfoParams(),
  ]) async =>
      SystemInfoResult.fromJson(await rpc('system.info', params.toJson()));

  /// Relayed to the system service's settings.get. The user-settable view of state.json and its revision (a hash of the file). Read-only.
  Future<SystemSettingsGetResult> systemSettingsGet([
    SystemSettingsGetParams params = const SystemSettingsGetParams(),
  ]) async => SystemSettingsGetResult.fromJson(
    await rpc('system.settings.get', params.toJson()),
  );

  /// Relayed to the system service's settings.set. Change state.json settings (job). Action org.hinteros.system.settings.
  ///
  /// changes is a closed, typed object: each settable state.json field is a property here (bool, enum, bounded integer), never free-form. It has no properties in 0.2 (SSH, base and channel have their own methods), so any field is invalid_params with data {field, reason: unknown_field}, and an empty changes object returns job_id null. revision must equal settings.get's, else state_conflict. The service writes state.json from its own typed state, never the caller's bytes.
  Future<SystemSettingsSetResult> systemSettingsSet(
    SystemSettingsSetParams params,
  ) async => SystemSettingsSetResult.fromJson(
    await rpc('system.settings.set', params.toJson()),
  );

  /// Relayed to the system service's ssh.set. Turn SSH (sshd) on or off (job). Action org.hinteros.system.ssh, which needs the admin password (auth_admin).
  ///
  /// Login over SSH is the admin account with its password; the system repo configures sshd. polkit's default for this action is auth_admin, so without an authorization the call gets authentication_required (the launcher will ask for the admin password once a polkit agent exists). Returns job_id null if SSH already is in that state.
  Future<SystemSshSetResult> systemSshSet(SystemSshSetParams params) async =>
      SystemSshSetResult.fromJson(await rpc('system.ssh.set', params.toJson()));

  /// Relayed to the system service's generations.list. System generations on disk (newest first). Read-only.
  Future<SystemGenerationsListResult> systemGenerationsList([
    SystemGenerationsListParams params = const SystemGenerationsListParams(),
  ]) async => SystemGenerationsListResult.fromJson(
    await rpc('system.generations.list', params.toJson()),
  );

  /// Relayed to the system service's rebuild. Re-apply the current /etc/hinteros (job): repair after a failed switch. Action org.hinteros.system.rebuild.
  Future<SystemRebuildResult> systemRebuild([
    SystemRebuildParams params = const SystemRebuildParams(),
  ]) async => SystemRebuildResult.fromJson(
    await rpc('system.rebuild', params.toJson()),
  );

  /// Relayed to the system service's hardware.redetect. Regenerate facter.json with nixos-facter and apply it (job). Action org.hinteros.system.rebuild.
  Future<SystemHardwareRedetectResult> systemHardwareRedetect([
    SystemHardwareRedetectParams params = const SystemHardwareRedetectParams(),
  ]) async => SystemHardwareRedetectResult.fromJson(
    await rpc('system.hardware.redetect', params.toJson()),
  );

  /// Relayed to the system service's rollback. Switch to an earlier generation (default: the one before the current), then restore /etc/hinteros from its snapshot (job). Action org.hinteros.system.rollback.
  Future<SystemRollbackResult> systemRollback([
    SystemRollbackParams params = const SystemRollbackParams(),
  ]) async => SystemRollbackResult.fromJson(
    await rpc('system.rollback', params.toJson()),
  );

  /// Relayed to the system service's update.check. Look for a newer signed revision of the channel (job), or, within 60 s of the last check, return that result without a job. Action org.hinteros.system.update.check.
  ///
  /// The job lists the channel branch (git ls-remote of the URL from the running generation's channel table), fetches it into a root-owned bare repo, verifies the tip's SSH signature against the allowed signers shipped in the running generation, requires it to descend from the locked revision, and reads the highest Security: &lt;low|medium|high|critical&gt; trailer among the new commits. The job's result is an UpdateCheckResult; failures are job_failed, update_unreachable or update_verification_failed in job_finished.error.
  Future<SystemUpdateCheckResult> systemUpdateCheck([
    SystemUpdateCheckParams params = const SystemUpdateCheckParams(),
  ]) async => SystemUpdateCheckResult.fromJson(
    await rpc('system.update.check', params.toJson()),
  );

  /// Relayed to the system service's update.apply. Install the revision found by the last update.check (job). Action org.hinteros.system.update.apply.
  ///
  /// rev must equal the last verified check result's available.rev for the current channel and locked revision, else state_conflict. The job re-verifies it, locks the hinteros input to ?rev=&lt;rev&gt; (never re-fetching the branch) and runs the apply flow.
  Future<SystemUpdateApplyResult> systemUpdateApply(
    SystemUpdateApplyParams params,
  ) async => SystemUpdateApplyResult.fromJson(
    await rpc('system.update.apply', params.toJson()),
  );

  /// Relayed to the system service's channel.set. Follow another channel (job). Action org.hinteros.system.channel.
  ///
  /// The URL comes from the running generation's channel table, never from params. The target tip must be signed by an allowed signer. Moving from beta to stable, or to a tip that does not descend from the locked revision, needs acknowledge_downgrade: true (else needs_acknowledgement: at once for beta to stable, in job_finished.error for a non-fast-forward tip). Returns job_id null if the channel is already the current one.
  Future<SystemChannelSetResult> systemChannelSet(
    SystemChannelSetParams params,
  ) async => SystemChannelSetResult.fromJson(
    await rpc('system.channel.set', params.toJson()),
  );

  /// Relayed to the system service's base.set. Switch the nixpkgs base (job). Action org.hinteros.system.channel. unstable to stable needs acknowledge_downgrade: true.
  Future<SystemBaseSetResult> systemBaseSet(SystemBaseSetParams params) async =>
      SystemBaseSetResult.fromJson(
        await rpc('system.base.set', params.toJson()),
      );

  /// Relayed to the system service's jobs.get. One job: running or among the last 10 finished. Read-only.
  Future<SystemJobsGetResult> systemJobsGet(SystemJobsGetParams params) async =>
      SystemJobsGetResult.fromJson(
        await rpc('system.jobs.get', params.toJson()),
      );

  /// Relayed to the system service's jobs.list. The running job, if any, and the last 10 finished jobs, newest first. Read-only.
  Future<SystemJobsListResult> systemJobsList([
    SystemJobsListParams params = const SystemJobsListParams(),
  ]) async => SystemJobsListResult.fromJson(
    await rpc('system.jobs.list', params.toJson()),
  );

  /// Relayed to the system service's jobs.cancel. Cancel a running job before its activation stage; the box stays unchanged. Action org.hinteros.system.jobs.cancel.
  Future<SystemJobsCancelResult> systemJobsCancel(
    SystemJobsCancelParams params,
  ) async => SystemJobsCancelResult.fromJson(
    await rpc('system.jobs.cancel', params.toJson()),
  );
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
    'apps_changed' => AppsChangedEvent.fromJson(params),
    'steam_attention' => SteamAttentionEvent.fromJson(params),
    'osk_visibility' => OskVisibilityEvent.fromJson(params),
    'job_started' => JobStartedEvent.fromJson(params),
    'job_progress' => JobProgressEvent.fromJson(params),
    'job_finished' => JobFinishedEvent.fromJson(params),
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
