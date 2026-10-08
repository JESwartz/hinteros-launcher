// GENERATED CODE - DO NOT EDIT.
// Source: schema/session-api.json (session API 0.12).
// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)
//
// ignore_for_file: unnecessary_this, unnecessary_cast, prefer_null_aware_operators, prefer_if_null_operators

import 'dart:convert';

/// API version this client was generated for (sent in `hello`).
const apiVersion = '0.12';

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
  'system.apps.install',
  'system.apps.remove',
  'system.jobs.get',
  'system.jobs.list',
  'system.jobs.cancel',
  'network.status',
  'wifi.scan',
  'wifi.list',
  'wifi.connect',
  'wifi.disconnect',
  'wifi.forget',
  'wifi.enable',
  'bluetooth.status',
  'bluetooth.scan',
  'bluetooth.devices',
  'bluetooth.pair',
  'bluetooth.confirm',
  'bluetooth.connect',
  'bluetooth.disconnect',
  'bluetooth.forget',
  'audio.outputs',
  'audio.set_output',
  'audio.volume',
  'audio.mute',
  'display.modes',
  'display.set_mode',
  'display.keep',
  'display.revert',
  'power.capabilities',
  'power.suspend',
  'power.reboot',
  'power.poweroff',
  'auth.respond',
  'auth.cancel',
  'session.restart',
  'store.list',
  'profile.current',
  'session.switch_profile',
  'session.switch_wait',
  'session.switch_force_close',
  'session.switch_cancel',
  'session.unlock',
  'session.end_guest',
  'greeter.list',
  'greeter.login',
  'greeter.pin',
  'greeter.cancel',
  'greeter.create',
  'system.profiles.list',
  'system.profiles.create',
  'system.profiles.setup_admin',
  'system.profiles.rename',
  'system.profiles.set_appearance',
  'system.profiles.set_pin',
  'system.profiles.set_locked',
  'system.profiles.reset_pin',
  'system.profiles.remove',
  'system.guest.set',
  'system.apps.list',
  'system.apps.generations',
  'system.apps.rollback',
  'system.apps.accept_terms',
  'system.starter_set.get',
  'system.starter_set.set',
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
  'network_changed',
  'wifi_list_changed',
  'bluetooth_changed',
  'bluetooth_confirm',
  'audio_changed',
  'authentication_requested',
  'authentication_finished',
  'store_changed',
  'switch_progress',
  'switch_blocked',
  'lock_state',
  'profiles_changed',
  'greeter_prompt',
  'greeter_result',
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
  'app_conflict': 3013,
  'terms_required': 3014,
  'system_unavailable': 3001,
  'unavailable': 4001,
  'device_failed': 4002,
  'wrong_password': 4003,
  'not_authorized': 4004,
  'power_inhibited': 4005,
  'profile_limit': 3015,
  'pin_required': 3016,
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

  /// Unknown generation or job; for runtime settings: a Wi-Fi network not in range, a Bluetooth device, an audio output or a display mode that does not exist, or a bluetooth.confirm with nothing waiting; system.apps.install: an id not in the running generation's catalog; system.apps.remove: an id that is not installed; auth.respond, auth.cancel: no such authentication request (or it is over).
  static const notFound = 3010;

  /// A downgrading channel or base switch without acknowledge_downgrade: true.
  static const needsAcknowledgement = 3011;

  /// polkit would allow the action only after interactive authentication (auth_admin: the admin password), and it did not happen: no authentication agent is registered for the caller (no session daemon agent, or another client than the session daemon called), or the user cancelled the prompt or did not answer in time.
  static const authenticationRequired = 3012;

  /// apps.install: id conflicts with conflicts_with (installed or also requested). apps.remove: conflicts_with, which stays installed, depends on id.
  static const appConflict = 3013;

  /// apps.install: app id has vendor terms and accepted_terms does not name their current version (show the terms, then retry with it).
  static const termsRequired = 3014;

  /// A relayed method could not reach the system service: it is down (reason down) or speaks another system API version (reason version_mismatch, e.g. after a switch until the session restarts). The session API keeps working.
  static const systemUnavailable = 3001;

  /// A runtime-settings method needs a service that is not there (not installed, not running, no permission to reach it, or no such hardware). Also store.list without a readable catalog index (service catalog), session.restart without a greetd session on seat0 (service logind), and auth.respond when polkit's agent helper cannot be run (service polkit).
  static const unavailable = 4001;

  /// The service accepted the request but the operation failed (a connection or pairing attempt, a mode change). The message says why in words; reason is for code.
  static const deviceFailed = 4002;

  /// wifi.connect: the network refused the password.
  static const wrongPassword = 4003;

  /// The service's polkit policy refused the session user (not the active local session, or the system's polkit rules are missing); auth.respond and auth.cancel from a client other than the launcher.
  static const notAuthorized = 4004;

  /// logind refused suspend, reboot or power off because an inhibitor lock blocks it (a system job is switching over). The message is logind's.
  static const powerInhibited = 4005;

  /// profiles.create (greeter.create): the box has the most profiles it can have (the guest does not count).
  static const profileLimit = 3015;

  /// A method needs a PIN that is missing or wrong: self (the caller's), admin (the admin profile's) or target (the profile being entered). retry_after_ms while the profile's backoff lock is active (3 free failures, then 1 s doubling up to 5 min).
  static const pinRequired = 3016;
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

/// Catalog app id (state.json apps).
typedef CatalogId = String;

/// A vendor terms version from the catalog.
typedef TermsVersion = String;

/// polkit's cookie for one authentication request.
typedef AuthCookie = String;

/// A Bluetooth address, upper case.
typedef BtAddress = String;

/// A profile id: p&lt;N&gt;, server-generated, never reused.
typedef ProfileId = String;

/// A profile id, or 'guest'.
typedef ProfileTarget = String;

/// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
typedef ProfileName = String;

/// 4 to 8 ASCII digits. Never logged.
typedef Pin = String;

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
  networkChanged('network_changed'),
  wifiListChanged('wifi_list_changed'),
  bluetoothChanged('bluetooth_changed'),
  bluetoothConfirm('bluetooth_confirm'),
  audioChanged('audio_changed'),
  authenticationRequested('authentication_requested'),
  authenticationFinished('authentication_finished'),
  storeChanged('store_changed'),
  switchProgress('switch_progress'),
  switchBlocked('switch_blocked'),
  lockState('lock_state'),
  profilesChanged('profiles_changed'),
  greeterPrompt('greeter_prompt'),
  greeterResult('greeter_result'),

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
  appsInstall('apps_install'),
  appsRemove('apps_remove'),
  appsRollback('apps_rollback'),
  profilesCreate('profiles_create'),
  profilesRemove('profiles_remove'),
  guestSet('guest_set'),
  starterSet('starter_set'),

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

class CatalogApp {
  const CatalogApp({required this.id, required this.name});

  /// Catalog app id (state.json apps).
  final String id;
  final String name;

  factory CatalogApp.fromJson(Map<String, dynamic> json) =>
      CatalogApp(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is CatalogApp && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'CatalogApp(${jsonEncode(toJson())})';
}

class RemovedApp {
  const RemovedApp({
    required this.id,
    required this.name,
    required this.reason,
  });

  /// Catalog app id (state.json apps).
  final String id;
  final String name;

  /// The catalog's statusReason.
  final String? reason;

  factory RemovedApp.fromJson(Map<String, dynamic> json) => RemovedApp(
    id: json['id'] as String,
    name: json['name'] as String,
    reason: json['reason'] == null ? null : json['reason'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'reason': reason};

  @override
  bool operator ==(Object other) =>
      other is RemovedApp && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'RemovedApp(${jsonEncode(toJson())})';
}

enum AuthOutcome {
  authorized('authorized'),
  failed('failed'),
  cancelled('cancelled'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const AuthOutcome(this.value);
  final String value;

  factory AuthOutcome.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum StoreState {
  available('available'),
  installed('installed'),
  installing('installing'),
  removing('removing'),
  retired('retired'),
  unavailable('unavailable'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const StoreState(this.value);
  final String value;

  factory StoreState.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

enum CatalogStatus {
  available('available'),
  retired('retired'),
  removed('removed'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const CatalogStatus(this.value);
  final String value;

  factory CatalogStatus.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// Where the real icon is (HinterOS ships no logos): the installed app's desktop file, the vendor's logo URL, discovery on site_url, or the kiosk profile's favicon.
class StoreAppIcon {
  const StoreAppIcon({
    this.desktopId,
    this.siteUrl,
    this.iconUrl,
    required this.firefoxProfile,
    this.path,
  });

  final String? desktopId;
  final String? siteUrl;
  final String? iconUrl;
  final bool firefoxProfile;

  /// 0.9: the resolved icon on this box (absolute path to an image), when there is one: the installed app's desktop file and icon theme, or downloaded from icon_url / site_url and cached (https only; same cache, size limits and refresh as apps.list icons). Absent until resolved; store_changed is sent when it appears.
  final String? path;

  factory StoreAppIcon.fromJson(Map<String, dynamic> json) => StoreAppIcon(
    desktopId: json['desktop_id'] == null ? null : json['desktop_id'] as String,
    siteUrl: json['site_url'] == null ? null : json['site_url'] as String,
    iconUrl: json['icon_url'] == null ? null : json['icon_url'] as String,
    firefoxProfile: json['firefox_profile'] as bool,
    path: json['path'] == null ? null : json['path'] as String,
  );

  Map<String, dynamic> toJson() => {
    'desktop_id': ?desktopId,
    'site_url': ?siteUrl,
    'icon_url': ?iconUrl,
    'firefox_profile': firefoxProfile,
    'path': ?path,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreAppIcon &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreAppIcon(${jsonEncode(toJson())})';
}

class StoreAppTerms {
  const StoreAppTerms({
    required this.title,
    required this.version,
    required this.url,
    required this.retrieved,
    required this.file,
  });

  final String title;

  /// A vendor terms version from the catalog.
  final String version;
  final String url;
  final String retrieved;

  /// Absolute path of the plain UTF-8 text on this box.
  final String file;

  factory StoreAppTerms.fromJson(Map<String, dynamic> json) => StoreAppTerms(
    title: json['title'] as String,
    version: json['version'] as String,
    url: json['url'] as String,
    retrieved: json['retrieved'] as String,
    file: json['file'] as String,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'version': version,
    'url': url,
    'retrieved': retrieved,
    'file': file,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreAppTerms &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreAppTerms(${jsonEncode(toJson())})';
}

class NamedApp {
  const NamedApp({required this.id, required this.name});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;
  final String name;

  factory NamedApp.fromJson(Map<String, dynamic> json) =>
      NamedApp(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is NamedApp && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'NamedApp(${jsonEncode(toJson())})';
}

/// A catalog entry (hinteros-catalog index version 2, fields in snake_case) with its state on this box. Removed entries (tombstones) only have id, name and status_reason; the other fields are empty.
class StoreApp {
  const StoreApp({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.category,
    required this.homepage,
    required this.kind,
    required this.sizeMib,
    required this.icon,
    required this.requires,
    required this.depends,
    required this.conflicts,
    required this.installer,
    required this.onIso,
    required this.installerDefault,
    required this.dataPaths,
    required this.terms,
    required this.buildsOnDevice,
    required this.free,
    required this.redistributable,
    required this.status,
    required this.statusReason,
    required this.state,
    this.missingServices,
  });

  /// Catalog app id (state.json apps).
  final String id;
  final String name;
  final String summary;
  final String description;

  /// games, video, music, photos, utilities; anything else: Other.
  final String category;
  final String homepage;

  /// How the app is launched. Clients must treat unknown values like 'native'.
  final AppKind kind;

  /// Approximate download plus disk use.
  final int sizeMib;

  /// Where the real icon is (HinterOS ships no logos): the installed app's desktop file, the vendor's logo URL, discovery on site_url, or the kiosk profile's favicon.
  final StoreAppIcon icon;
  final List<String> requires;
  final List<String> depends;
  final List<String> conflicts;
  final bool installer;
  final bool onIso;
  final bool installerDefault;

  /// Deleted in every profile's home by system.apps.remove {delete_data: true}.
  final List<String> dataPaths;

  /// The vendor's terms, shown in full before install; null if none.
  final StoreAppTerms? terms;

  /// Fetched from the vendor and prepared on this box during install (a few minutes, needs internet).
  final bool buildsOnDevice;
  final bool free;
  final bool redistributable;
  final CatalogStatus status;
  final String? statusReason;
  final StoreState state;

  /// 0.12: services (box-wide, admin profile only) this app needs that are not enabled on this box. Absent or empty: none. While any is missing the app cannot be installed: say which service, and that the admin profile can install it in the Server section.
  final List<NamedApp>? missingServices;

  factory StoreApp.fromJson(Map<String, dynamic> json) => StoreApp(
    id: json['id'] as String,
    name: json['name'] as String,
    summary: json['summary'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    homepage: json['homepage'] as String,
    kind: AppKind.fromJson(json['kind'] as String),
    sizeMib: json['size_mib'] as int,
    icon: StoreAppIcon.fromJson((json['icon'] as Map).cast<String, dynamic>()),
    requires: (json['requires'] as List).map((x) => x as String).toList(),
    depends: (json['depends'] as List).map((x) => x as String).toList(),
    conflicts: (json['conflicts'] as List).map((x) => x as String).toList(),
    installer: json['installer'] as bool,
    onIso: json['on_iso'] as bool,
    installerDefault: json['installer_default'] as bool,
    dataPaths: (json['data_paths'] as List).map((x) => x as String).toList(),
    terms: json['terms'] == null
        ? null
        : StoreAppTerms.fromJson(
            (json['terms'] as Map).cast<String, dynamic>(),
          ),
    buildsOnDevice: json['builds_on_device'] as bool,
    free: json['free'] as bool,
    redistributable: json['redistributable'] as bool,
    status: CatalogStatus.fromJson(json['status'] as String),
    statusReason: json['status_reason'] == null
        ? null
        : json['status_reason'] as String,
    state: StoreState.fromJson(json['state'] as String),
    missingServices: json['missing_services'] == null
        ? null
        : (json['missing_services'] as List)
              .map((x) => NamedApp.fromJson((x as Map).cast<String, dynamic>()))
              .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'summary': summary,
    'description': description,
    'category': category,
    'homepage': homepage,
    'kind': kind.toJson(),
    'size_mib': sizeMib,
    'icon': icon.toJson(),
    'requires': requires,
    'depends': depends,
    'conflicts': conflicts,
    'installer': installer,
    'on_iso': onIso,
    'installer_default': installerDefault,
    'data_paths': dataPaths,
    'terms': terms == null ? null : terms!.toJson(),
    'builds_on_device': buildsOnDevice,
    'free': free,
    'redistributable': redistributable,
    'status': status.toJson(),
    'status_reason': statusReason,
    'state': state.toJson(),
    if (missingServices != null)
      'missing_services': missingServices!.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is StoreApp && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreApp(${jsonEncode(toJson())})';
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

/// An account in a system generation's state.json, with its name when this box still knows it.
class GenerationProfile {
  const GenerationProfile({required this.id, required this.name});

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;
  final String? name;

  factory GenerationProfile.fromJson(Map<String, dynamic> json) =>
      GenerationProfile(
        id: json['id'] as String,
        name: json['name'] == null ? null : json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is GenerationProfile &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GenerationProfile(${jsonEncode(toJson())})';
}

class Generation {
  const Generation({
    required this.generation,
    required this.date,
    required this.rev,
    required this.current,
    required this.booted,
    this.profiles,
  });

  final int generation;

  /// Created (Unix time, seconds).
  final int date;

  /// System repo revision in its config snapshot, if any.
  final String? rev;
  final bool current;
  final bool booted;

  /// 0.12: the accounts in that generation's state.json (null: unknown, e.g. no config snapshot). The rollback screen names the profiles a rollback would remove and those that would come back with an empty home.
  final List<GenerationProfile>? profiles;

  factory Generation.fromJson(Map<String, dynamic> json) => Generation(
    generation: json['generation'] as int,
    date: json['date'] as int,
    rev: json['rev'] == null ? null : json['rev'] as String,
    current: json['current'] as bool,
    booted: json['booted'] as bool,
    profiles: json['profiles'] == null
        ? null
        : (json['profiles'] as List)
              .map(
                (x) => GenerationProfile.fromJson(
                  (x as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
  );

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'date': date,
    'rev': rev,
    'current': current,
    'booted': booted,
    if (profiles != null) 'profiles': profiles!.map((x) => x.toJson()).toList(),
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
    required this.newApps,
    required this.removedApps,
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

  /// Apps the update makes installable (in the target's catalog, not available in the running one), by id; null if the target's catalog could not be read (since 0.3). The Store says 'More apps are available after the next update'.
  final List<CatalogApp>? newApps;

  /// Installed apps the update takes away (removed from, or missing in, the target's catalog); null if unknown (since 0.3). The update screen names them with the reason.
  final List<RemovedApp>? removedApps;

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
        newApps: json['new_apps'] == null
            ? null
            : (json['new_apps'] as List)
                  .map(
                    (x) =>
                        CatalogApp.fromJson((x as Map).cast<String, dynamic>()),
                  )
                  .toList(),
        removedApps: json['removed_apps'] == null
            ? null
            : (json['removed_apps'] as List)
                  .map(
                    (x) =>
                        RemovedApp.fromJson((x as Map).cast<String, dynamic>()),
                  )
                  .toList(),
      );

  Map<String, dynamic> toJson() => {
    'rev': rev,
    'date': date,
    'summary': summary,
    'signer': signer,
    'security': security == null ? null : security!.toJson(),
    'commits': commits,
    'new_apps': newApps == null
        ? null
        : newApps!.map((x) => x.toJson()).toList(),
    'removed_apps': removedApps == null
        ? null
        : removedApps!.map((x) => x.toJson()).toList(),
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

enum Connectivity {
  unknown('unknown'),
  none('none'),
  portal('portal'),
  limited('limited'),
  full('full'),

  /// A value this client does not know (newer daemon).
  unknown_('unknown');

  const Connectivity(this.value);
  final String value;

  factory Connectivity.fromJson(String value) => values.firstWhere(
    (e) => e != unknown_ && e.value == value,
    orElse: () => unknown_,
  );

  String toJson() => value;
}

class NetworkStatus {
  const NetworkStatus({
    required this.wifiAvailable,
    required this.wifiEnabled,
    required this.ethernet,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    required this.connectivity,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;

  /// Wi-Fi is switched on.
  final bool wifiEnabled;

  /// An Ethernet device is connected.
  final bool ethernet;

  /// The network Wi-Fi is connected to (absent when not connected).
  final String? wifiSsid;
  final int? wifiSignal;

  /// The primary connection's IPv4 address.
  final String? address;
  final Connectivity connectivity;

  factory NetworkStatus.fromJson(Map<String, dynamic> json) => NetworkStatus(
    wifiAvailable: json['wifi_available'] as bool,
    wifiEnabled: json['wifi_enabled'] as bool,
    ethernet: json['ethernet'] as bool,
    wifiSsid: json['wifi_ssid'] == null ? null : json['wifi_ssid'] as String,
    wifiSignal: json['wifi_signal'] == null ? null : json['wifi_signal'] as int,
    address: json['address'] == null ? null : json['address'] as String,
    connectivity: Connectivity.fromJson(json['connectivity'] as String),
  );

  Map<String, dynamic> toJson() => {
    'wifi_available': wifiAvailable,
    'wifi_enabled': wifiEnabled,
    'ethernet': ethernet,
    'wifi_ssid': ?wifiSsid,
    'wifi_signal': ?wifiSignal,
    'address': ?address,
    'connectivity': connectivity.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is NetworkStatus &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'NetworkStatus(${jsonEncode(toJson())})';
}

/// wpa is WPA or WPA2 with a passphrase, wpa3 is SAE only, enterprise (802.1X) cannot be joined with a password alone.
enum WifiSecurity {
  open('open'),
  wep('wep'),
  wpa('wpa'),
  wpa3('wpa3'),
  enterprise('enterprise'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const WifiSecurity(this.value);
  final String value;

  factory WifiSecurity.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.security,
    required this.known,
    required this.connected,
  });

  final String ssid;
  final int signal;

  /// wpa is WPA or WPA2 with a passphrase, wpa3 is SAE only, enterprise (802.1X) cannot be joined with a password alone.
  final WifiSecurity security;

  /// A connection for it is stored (no password needed).
  final bool known;
  final bool connected;

  factory WifiNetwork.fromJson(Map<String, dynamic> json) => WifiNetwork(
    ssid: json['ssid'] as String,
    signal: json['signal'] as int,
    security: WifiSecurity.fromJson(json['security'] as String),
    known: json['known'] as bool,
    connected: json['connected'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'signal': signal,
    'security': security.toJson(),
    'known': known,
    'connected': connected,
  };

  @override
  bool operator ==(Object other) =>
      other is WifiNetwork &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiNetwork(${jsonEncode(toJson())})';
}

class WifiList {
  const WifiList({required this.networks});

  /// Strongest first.
  final List<WifiNetwork> networks;

  factory WifiList.fromJson(Map<String, dynamic> json) => WifiList(
    networks: (json['networks'] as List)
        .map((x) => WifiNetwork.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'networks': networks.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is WifiList && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiList(${jsonEncode(toJson())})';
}

enum BtKind {
  gamepad('gamepad'),
  headset('headset'),
  speaker('speaker'),
  keyboard('keyboard'),
  mouse('mouse'),
  phone('phone'),
  computer('computer'),
  other('other'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const BtKind(this.value);
  final String value;

  factory BtKind.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class BtDevice {
  const BtDevice({
    required this.address,
    required this.name,
    required this.kind,
    required this.paired,
    required this.connected,
    required this.trusted,
    this.battery,
    this.rssi,
  });

  /// A Bluetooth address, upper case.
  final String address;
  final String name;
  final BtKind kind;
  final bool paired;
  final bool connected;
  final bool trusted;
  final int? battery;

  /// dBm, while in range.
  final int? rssi;

  factory BtDevice.fromJson(Map<String, dynamic> json) => BtDevice(
    address: json['address'] as String,
    name: json['name'] as String,
    kind: BtKind.fromJson(json['kind'] as String),
    paired: json['paired'] as bool,
    connected: json['connected'] as bool,
    trusted: json['trusted'] as bool,
    battery: json['battery'] == null ? null : json['battery'] as int,
    rssi: json['rssi'] == null ? null : json['rssi'] as int,
  );

  Map<String, dynamic> toJson() => {
    'address': address,
    'name': name,
    'kind': kind.toJson(),
    'paired': paired,
    'connected': connected,
    'trusted': trusted,
    'battery': ?battery,
    'rssi': ?rssi,
  };

  @override
  bool operator ==(Object other) =>
      other is BtDevice && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BtDevice(${jsonEncode(toJson())})';
}

class BtStatus {
  const BtStatus({
    required this.available,
    required this.powered,
    required this.scanning,
  });

  /// There is a Bluetooth adapter.
  final bool available;
  final bool powered;
  final bool scanning;

  factory BtStatus.fromJson(Map<String, dynamic> json) => BtStatus(
    available: json['available'] as bool,
    powered: json['powered'] as bool,
    scanning: json['scanning'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'available': available,
    'powered': powered,
    'scanning': scanning,
  };

  @override
  bool operator ==(Object other) =>
      other is BtStatus && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BtStatus(${jsonEncode(toJson())})';
}

enum AudioKind {
  hdmi('hdmi'),
  analog('analog'),
  usb('usb'),
  bluetooth('bluetooth'),
  other('other'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const AudioKind(this.value);
  final String value;

  factory AudioKind.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class AudioOutput {
  const AudioOutput({
    required this.id,
    required this.name,
    required this.kind,
    required this.default_,
  });

  /// The sink's name.
  final String id;
  final String name;
  final AudioKind kind;
  final bool default_;

  factory AudioOutput.fromJson(Map<String, dynamic> json) => AudioOutput(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: AudioKind.fromJson(json['kind'] as String),
    default_: json['default'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.toJson(),
    'default': default_,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioOutput &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioOutput(${jsonEncode(toJson())})';
}

class AudioState {
  const AudioState({
    required this.outputs,
    required this.volume,
    required this.muted,
  });

  final List<AudioOutput> outputs;

  /// The default output's volume, percent.
  final int volume;
  final bool muted;

  factory AudioState.fromJson(Map<String, dynamic> json) => AudioState(
    outputs: (json['outputs'] as List)
        .map((x) => AudioOutput.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
    volume: json['volume'] as int,
    muted: json['muted'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'outputs': outputs.map((x) => x.toJson()).toList(),
    'volume': volume,
    'muted': muted,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioState && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioState(${jsonEncode(toJson())})';
}

/// A display mode: pixels, and refresh rate in whole Hz (59.94 Hz is 60).
class Mode {
  const Mode({
    required this.width,
    required this.height,
    required this.refresh,
  });

  final int width;
  final int height;
  final int refresh;

  factory Mode.fromJson(Map<String, dynamic> json) => Mode(
    width: json['width'] as int,
    height: json['height'] as int,
    refresh: json['refresh'] as int,
  );

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'refresh': refresh,
  };

  @override
  bool operator ==(Object other) =>
      other is Mode && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Mode(${jsonEncode(toJson())})';
}

class DisplayModeInfo {
  const DisplayModeInfo({
    required this.width,
    required this.height,
    required this.refresh,
    required this.current,
    required this.preferred,
  });

  final int width;
  final int height;
  final int refresh;
  final bool current;

  /// The display's own first choice.
  final bool preferred;

  factory DisplayModeInfo.fromJson(Map<String, dynamic> json) =>
      DisplayModeInfo(
        width: json['width'] as int,
        height: json['height'] as int,
        refresh: json['refresh'] as int,
        current: json['current'] as bool,
        preferred: json['preferred'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'refresh': refresh,
    'current': current,
    'preferred': preferred,
  };

  @override
  bool operator ==(Object other) =>
      other is DisplayModeInfo &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayModeInfo(${jsonEncode(toJson())})';
}

class DisplayModes {
  const DisplayModes({required this.modes, this.display, required this.canSet});

  final List<DisplayModeInfo> modes;

  /// Make and model of the display, if known.
  final String? display;

  /// display.set_mode can work.
  final bool canSet;

  factory DisplayModes.fromJson(Map<String, dynamic> json) => DisplayModes(
    modes: (json['modes'] as List)
        .map(
          (x) => DisplayModeInfo.fromJson((x as Map).cast<String, dynamic>()),
        )
        .toList(),
    display: json['display'] == null ? null : json['display'] as String,
    canSet: json['can_set'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'modes': modes.map((x) => x.toJson()).toList(),
    'display': ?display,
    'can_set': canSet,
  };

  @override
  bool operator ==(Object other) =>
      other is DisplayModes &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayModes(${jsonEncode(toJson())})';
}

/// logind's answer: challenge needs authentication nobody can give on this box.
enum PowerCapability {
  yes('yes'),
  no('no'),
  challenge('challenge'),
  na('na'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const PowerCapability(this.value);
  final String value;

  factory PowerCapability.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class PowerCapabilities {
  const PowerCapabilities({
    required this.suspend,
    required this.reboot,
    required this.poweroff,
  });

  /// logind's answer: challenge needs authentication nobody can give on this box.
  final PowerCapability suspend;

  /// logind's answer: challenge needs authentication nobody can give on this box.
  final PowerCapability reboot;

  /// logind's answer: challenge needs authentication nobody can give on this box.
  final PowerCapability poweroff;

  factory PowerCapabilities.fromJson(Map<String, dynamic> json) =>
      PowerCapabilities(
        suspend: PowerCapability.fromJson(json['suspend'] as String),
        reboot: PowerCapability.fromJson(json['reboot'] as String),
        poweroff: PowerCapability.fromJson(json['poweroff'] as String),
      );

  Map<String, dynamic> toJson() => {
    'suspend': suspend.toJson(),
    'reboot': reboot.toJson(),
    'poweroff': poweroff.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PowerCapabilities &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerCapabilities(${jsonEncode(toJson())})';
}

/// The profile's colour (tile and chip). Clients must treat unknown values like teal.
enum ProfileColor {
  teal('teal'),
  blue('blue'),
  purple('purple'),
  pink('pink'),
  red('red'),
  orange('orange'),
  yellow('yellow'),
  green('green'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const ProfileColor(this.value);
  final String value;

  factory ProfileColor.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// Disk use of a profile's home (hinteros-usage.service), app store paths not included.
class ProfileUsage {
  const ProfileUsage({
    required this.totalBytes,
    required this.steamGamesBytes,
    required this.at,
  });

  final int totalBytes;
  final int steamGamesBytes;

  /// Measured (Unix seconds).
  final int at;

  factory ProfileUsage.fromJson(Map<String, dynamic> json) => ProfileUsage(
    totalBytes: json['total_bytes'] as int,
    steamGamesBytes: json['steam_games_bytes'] as int,
    at: json['at'] as int,
  );

  Map<String, dynamic> toJson() => {
    'total_bytes': totalBytes,
    'steam_games_bytes': steamGamesBytes,
    'at': at,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfileUsage &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfileUsage(${jsonEncode(toJson())})';
}

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.color,
    required this.user,
    required this.admin,
    required this.locked,
    required this.lockedUntil,
    required this.active,
    required this.lastUsedAt,
    required this.usage,
  });

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
  final String name;

  /// The profile's colour (tile and chip). Clients must treat unknown values like teal.
  final ProfileColor color;
  final String user;
  final bool admin;
  final bool locked;

  /// PIN backoff lock until (Unix seconds), or null.
  final int? lockedUntil;

  /// This profile is on screen now.
  final bool active;
  final int? lastUsedAt;
  final ProfileUsage? usage;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    color: ProfileColor.fromJson(json['color'] as String),
    user: json['user'] as String,
    admin: json['admin'] as bool,
    locked: json['locked'] as bool,
    lockedUntil: json['locked_until'] == null
        ? null
        : json['locked_until'] as int,
    active: json['active'] as bool,
    lastUsedAt: json['last_used_at'] == null
        ? null
        : json['last_used_at'] as int,
    usage: json['usage'] == null
        ? null
        : ProfileUsage.fromJson((json['usage'] as Map).cast<String, dynamic>()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toJson(),
    'user': user,
    'admin': admin,
    'locked': locked,
    'locked_until': lockedUntil,
    'active': active,
    'last_used_at': lastUsedAt,
    'usage': usage == null ? null : usage!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is Profile && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Profile(${jsonEncode(toJson())})';
}

/// What the picker may know of a profile (profiles-public.json).
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.color,
    required this.locked,
    required this.admin,
    required this.lockedUntil,
  });

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
  final String name;

  /// The profile's colour (tile and chip). Clients must treat unknown values like teal.
  final ProfileColor color;
  final bool locked;
  final bool admin;
  final int? lockedUntil;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    color: ProfileColor.fromJson(json['color'] as String),
    locked: json['locked'] as bool,
    admin: json['admin'] as bool,
    lockedUntil: json['locked_until'] == null
        ? null
        : json['locked_until'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toJson(),
    'locked': locked,
    'admin': admin,
    'locked_until': lockedUntil,
  };

  @override
  bool operator ==(Object other) =>
      other is PublicProfile &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PublicProfile(${jsonEncode(toJson())})';
}

class Appearance {
  const Appearance({
    required this.textScale,
    required this.highContrast,
    required this.reduceMotion,
  });

  final num textScale;
  final bool highContrast;
  final bool reduceMotion;

  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
    textScale: json['text_scale'] as num,
    highContrast: json['high_contrast'] as bool,
    reduceMotion: json['reduce_motion'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'text_scale': textScale,
    'high_contrast': highContrast,
    'reduce_motion': reduceMotion,
  };

  @override
  bool operator ==(Object other) =>
      other is Appearance && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Appearance(${jsonEncode(toJson())})';
}

/// A started profile job and the id the new profile will have.
class ProfileJobRef {
  const ProfileJobRef({required this.jobId, required this.id});

  /// Server-issued job id.
  final String jobId;

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  factory ProfileJobRef.fromJson(Map<String, dynamic> json) =>
      ProfileJobRef(jobId: json['job_id'] as String, id: json['id'] as String);

  Map<String, dynamic> toJson() => {'job_id': jobId, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is ProfileJobRef &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfileJobRef(${jsonEncode(toJson())})';
}

class AppGeneration {
  const AppGeneration({
    required this.generation,
    required this.date,
    required this.ids,
    required this.systemRev,
    required this.current,
  });

  final int generation;

  /// Created (Unix seconds).
  final int date;
  final List<String> ids;

  /// The system revision the env was built against.
  final String? systemRev;
  final bool current;

  factory AppGeneration.fromJson(Map<String, dynamic> json) => AppGeneration(
    generation: json['generation'] as int,
    date: json['date'] as int,
    ids: (json['ids'] as List).map((x) => x as String).toList(),
    systemRev: json['system_rev'] == null ? null : json['system_rev'] as String,
    current: json['current'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'date': date,
    'ids': ids,
    'system_rev': systemRev,
    'current': current,
  };

  @override
  bool operator ==(Object other) =>
      other is AppGeneration &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppGeneration(${jsonEncode(toJson())})';
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
  const OskShowResult({required this.visible, this.password});

  /// Whether the on-screen keyboard is now visible.
  final bool visible;

  /// (0.10) The keyboard is up for a password field (see osk_visibility). Absent when false.
  final bool? password;

  factory OskShowResult.fromJson(Map<String, dynamic> json) => OskShowResult(
    visible: json['visible'] as bool,
    password: json['password'] == null ? null : json['password'] as bool,
  );

  Map<String, dynamic> toJson() => {'visible': visible, 'password': ?password};

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
  const OskHideResult({required this.visible, this.password});

  /// Whether the on-screen keyboard is now visible.
  final bool visible;

  /// (0.10) The keyboard is up for a password field (see osk_visibility). Absent when false.
  final bool? password;

  factory OskHideResult.fromJson(Map<String, dynamic> json) => OskHideResult(
    visible: json['visible'] as bool,
    password: json['password'] == null ? null : json['password'] as bool,
  );

  Map<String, dynamic> toJson() => {'visible': visible, 'password': ?password};

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
    required this.apps,
    required this.ssh,
  });

  final Base base;

  /// Catalog app ids installed from the Store (state.json apps), in install order (since 0.3).
  final List<String> apps;
  final SystemSettingsGetResultSettingsSsh ssh;

  factory SystemSettingsGetResultSettings.fromJson(Map<String, dynamic> json) =>
      SystemSettingsGetResultSettings(
        base: Base.fromJson(json['base'] as String),
        apps: (json['apps'] as List).map((x) => x as String).toList(),
        ssh: SystemSettingsGetResultSettingsSsh.fromJson(
          (json['ssh'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'base': base.toJson(),
    'apps': apps,
    'ssh': ssh.toJson(),
  };

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

class SystemAppsInstallParams {
  const SystemAppsInstallParams({
    required this.ids,
    required this.revision,
    this.acceptedTerms,
  });

  final List<String> ids;

  /// SHA-256 of state.json, hex.
  final String revision;

  /// App id to the terms version the user accepted (after reading the full text).
  final Map<String, Object?>? acceptedTerms;

  factory SystemAppsInstallParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsInstallParams(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        revision: json['revision'] as String,
        acceptedTerms: json['accepted_terms'] == null
            ? null
            : (json['accepted_terms'] as Map).cast<String, Object?>(),
      );

  Map<String, dynamic> toJson() => {
    'ids': ids,
    'revision': revision,
    'accepted_terms': ?acceptedTerms,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemAppsInstallParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsInstallParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemAppsInstallResult {
  const SystemAppsInstallResult({required this.jobId});

  final String? jobId;

  factory SystemAppsInstallResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsInstallResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsInstallResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsInstallResult(${jsonEncode(toJson())})';
}

class SystemAppsRemoveParams {
  const SystemAppsRemoveParams({
    required this.ids,
    required this.revision,
    required this.deleteData,
  });

  final List<String> ids;

  /// SHA-256 of state.json, hex.
  final String revision;
  final bool deleteData;

  factory SystemAppsRemoveParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsRemoveParams(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        revision: json['revision'] as String,
        deleteData: json['delete_data'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'ids': ids,
    'revision': revision,
    'delete_data': deleteData,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemAppsRemoveParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsRemoveParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemAppsRemoveResult {
  const SystemAppsRemoveResult({required this.jobId});

  final String? jobId;

  factory SystemAppsRemoveResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsRemoveResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsRemoveResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsRemoveResult(${jsonEncode(toJson())})';
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

class NetworkStatusParams {
  const NetworkStatusParams();

  factory NetworkStatusParams.fromJson(Map<String, dynamic> json) =>
      NetworkStatusParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is NetworkStatusParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'NetworkStatusParams(${jsonEncode(toJson())})';
}

class NetworkStatusResult {
  const NetworkStatusResult({
    required this.wifiAvailable,
    required this.wifiEnabled,
    required this.ethernet,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    required this.connectivity,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;

  /// Wi-Fi is switched on.
  final bool wifiEnabled;

  /// An Ethernet device is connected.
  final bool ethernet;

  /// The network Wi-Fi is connected to (absent when not connected).
  final String? wifiSsid;
  final int? wifiSignal;

  /// The primary connection's IPv4 address.
  final String? address;
  final Connectivity connectivity;

  factory NetworkStatusResult.fromJson(
    Map<String, dynamic> json,
  ) => NetworkStatusResult(
    wifiAvailable: json['wifi_available'] as bool,
    wifiEnabled: json['wifi_enabled'] as bool,
    ethernet: json['ethernet'] as bool,
    wifiSsid: json['wifi_ssid'] == null ? null : json['wifi_ssid'] as String,
    wifiSignal: json['wifi_signal'] == null ? null : json['wifi_signal'] as int,
    address: json['address'] == null ? null : json['address'] as String,
    connectivity: Connectivity.fromJson(json['connectivity'] as String),
  );

  Map<String, dynamic> toJson() => {
    'wifi_available': wifiAvailable,
    'wifi_enabled': wifiEnabled,
    'ethernet': ethernet,
    'wifi_ssid': ?wifiSsid,
    'wifi_signal': ?wifiSignal,
    'address': ?address,
    'connectivity': connectivity.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is NetworkStatusResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'NetworkStatusResult(${jsonEncode(toJson())})';
}

class WifiScanParams {
  const WifiScanParams();

  factory WifiScanParams.fromJson(Map<String, dynamic> json) =>
      WifiScanParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is WifiScanParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiScanParams(${jsonEncode(toJson())})';
}

class WifiScanResult {
  const WifiScanResult({required this.networks});

  /// Strongest first.
  final List<WifiNetwork> networks;

  factory WifiScanResult.fromJson(Map<String, dynamic> json) => WifiScanResult(
    networks: (json['networks'] as List)
        .map((x) => WifiNetwork.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'networks': networks.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is WifiScanResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiScanResult(${jsonEncode(toJson())})';
}

class WifiListParams {
  const WifiListParams();

  factory WifiListParams.fromJson(Map<String, dynamic> json) =>
      WifiListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is WifiListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiListParams(${jsonEncode(toJson())})';
}

class WifiListResult {
  const WifiListResult({required this.networks});

  /// Strongest first.
  final List<WifiNetwork> networks;

  factory WifiListResult.fromJson(Map<String, dynamic> json) => WifiListResult(
    networks: (json['networks'] as List)
        .map((x) => WifiNetwork.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'networks': networks.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is WifiListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiListResult(${jsonEncode(toJson())})';
}

class WifiConnectParams {
  const WifiConnectParams({required this.ssid, this.password});

  final String ssid;

  /// 8 to 63 characters (WPA), or 64 hex digits (the raw key).
  final String? password;

  factory WifiConnectParams.fromJson(Map<String, dynamic> json) =>
      WifiConnectParams(
        ssid: json['ssid'] as String,
        password: json['password'] == null ? null : json['password'] as String,
      );

  Map<String, dynamic> toJson() => {'ssid': ssid, 'password': ?password};

  @override
  bool operator ==(Object other) =>
      other is WifiConnectParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiConnectParams(${jsonEncode(toJson())})';
}

class WifiConnectResult {
  const WifiConnectResult({
    required this.wifiAvailable,
    required this.wifiEnabled,
    required this.ethernet,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    required this.connectivity,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;

  /// Wi-Fi is switched on.
  final bool wifiEnabled;

  /// An Ethernet device is connected.
  final bool ethernet;

  /// The network Wi-Fi is connected to (absent when not connected).
  final String? wifiSsid;
  final int? wifiSignal;

  /// The primary connection's IPv4 address.
  final String? address;
  final Connectivity connectivity;

  factory WifiConnectResult.fromJson(
    Map<String, dynamic> json,
  ) => WifiConnectResult(
    wifiAvailable: json['wifi_available'] as bool,
    wifiEnabled: json['wifi_enabled'] as bool,
    ethernet: json['ethernet'] as bool,
    wifiSsid: json['wifi_ssid'] == null ? null : json['wifi_ssid'] as String,
    wifiSignal: json['wifi_signal'] == null ? null : json['wifi_signal'] as int,
    address: json['address'] == null ? null : json['address'] as String,
    connectivity: Connectivity.fromJson(json['connectivity'] as String),
  );

  Map<String, dynamic> toJson() => {
    'wifi_available': wifiAvailable,
    'wifi_enabled': wifiEnabled,
    'ethernet': ethernet,
    'wifi_ssid': ?wifiSsid,
    'wifi_signal': ?wifiSignal,
    'address': ?address,
    'connectivity': connectivity.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is WifiConnectResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiConnectResult(${jsonEncode(toJson())})';
}

class WifiDisconnectParams {
  const WifiDisconnectParams();

  factory WifiDisconnectParams.fromJson(Map<String, dynamic> json) =>
      WifiDisconnectParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is WifiDisconnectParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiDisconnectParams(${jsonEncode(toJson())})';
}

class WifiDisconnectResult {
  const WifiDisconnectResult({
    required this.wifiAvailable,
    required this.wifiEnabled,
    required this.ethernet,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    required this.connectivity,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;

  /// Wi-Fi is switched on.
  final bool wifiEnabled;

  /// An Ethernet device is connected.
  final bool ethernet;

  /// The network Wi-Fi is connected to (absent when not connected).
  final String? wifiSsid;
  final int? wifiSignal;

  /// The primary connection's IPv4 address.
  final String? address;
  final Connectivity connectivity;

  factory WifiDisconnectResult.fromJson(
    Map<String, dynamic> json,
  ) => WifiDisconnectResult(
    wifiAvailable: json['wifi_available'] as bool,
    wifiEnabled: json['wifi_enabled'] as bool,
    ethernet: json['ethernet'] as bool,
    wifiSsid: json['wifi_ssid'] == null ? null : json['wifi_ssid'] as String,
    wifiSignal: json['wifi_signal'] == null ? null : json['wifi_signal'] as int,
    address: json['address'] == null ? null : json['address'] as String,
    connectivity: Connectivity.fromJson(json['connectivity'] as String),
  );

  Map<String, dynamic> toJson() => {
    'wifi_available': wifiAvailable,
    'wifi_enabled': wifiEnabled,
    'ethernet': ethernet,
    'wifi_ssid': ?wifiSsid,
    'wifi_signal': ?wifiSignal,
    'address': ?address,
    'connectivity': connectivity.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is WifiDisconnectResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiDisconnectResult(${jsonEncode(toJson())})';
}

class WifiForgetParams {
  const WifiForgetParams({required this.ssid});

  final String ssid;

  factory WifiForgetParams.fromJson(Map<String, dynamic> json) =>
      WifiForgetParams(ssid: json['ssid'] as String);

  Map<String, dynamic> toJson() => {'ssid': ssid};

  @override
  bool operator ==(Object other) =>
      other is WifiForgetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiForgetParams(${jsonEncode(toJson())})';
}

class WifiForgetResult {
  const WifiForgetResult();

  factory WifiForgetResult.fromJson(Map<String, dynamic> json) =>
      WifiForgetResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is WifiForgetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiForgetResult(${jsonEncode(toJson())})';
}

class WifiEnableParams {
  const WifiEnableParams({required this.enabled});

  final bool enabled;

  factory WifiEnableParams.fromJson(Map<String, dynamic> json) =>
      WifiEnableParams(enabled: json['enabled'] as bool);

  Map<String, dynamic> toJson() => {'enabled': enabled};

  @override
  bool operator ==(Object other) =>
      other is WifiEnableParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiEnableParams(${jsonEncode(toJson())})';
}

class WifiEnableResult {
  const WifiEnableResult({
    required this.wifiAvailable,
    required this.wifiEnabled,
    required this.ethernet,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    required this.connectivity,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;

  /// Wi-Fi is switched on.
  final bool wifiEnabled;

  /// An Ethernet device is connected.
  final bool ethernet;

  /// The network Wi-Fi is connected to (absent when not connected).
  final String? wifiSsid;
  final int? wifiSignal;

  /// The primary connection's IPv4 address.
  final String? address;
  final Connectivity connectivity;

  factory WifiEnableResult.fromJson(
    Map<String, dynamic> json,
  ) => WifiEnableResult(
    wifiAvailable: json['wifi_available'] as bool,
    wifiEnabled: json['wifi_enabled'] as bool,
    ethernet: json['ethernet'] as bool,
    wifiSsid: json['wifi_ssid'] == null ? null : json['wifi_ssid'] as String,
    wifiSignal: json['wifi_signal'] == null ? null : json['wifi_signal'] as int,
    address: json['address'] == null ? null : json['address'] as String,
    connectivity: Connectivity.fromJson(json['connectivity'] as String),
  );

  Map<String, dynamic> toJson() => {
    'wifi_available': wifiAvailable,
    'wifi_enabled': wifiEnabled,
    'ethernet': ethernet,
    'wifi_ssid': ?wifiSsid,
    'wifi_signal': ?wifiSignal,
    'address': ?address,
    'connectivity': connectivity.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is WifiEnableResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiEnableResult(${jsonEncode(toJson())})';
}

class BluetoothStatusParams {
  const BluetoothStatusParams();

  factory BluetoothStatusParams.fromJson(Map<String, dynamic> json) =>
      BluetoothStatusParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is BluetoothStatusParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothStatusParams(${jsonEncode(toJson())})';
}

class BluetoothStatusResult {
  const BluetoothStatusResult({
    required this.available,
    required this.powered,
    required this.scanning,
  });

  /// There is a Bluetooth adapter.
  final bool available;
  final bool powered;
  final bool scanning;

  factory BluetoothStatusResult.fromJson(Map<String, dynamic> json) =>
      BluetoothStatusResult(
        available: json['available'] as bool,
        powered: json['powered'] as bool,
        scanning: json['scanning'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'available': available,
    'powered': powered,
    'scanning': scanning,
  };

  @override
  bool operator ==(Object other) =>
      other is BluetoothStatusResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothStatusResult(${jsonEncode(toJson())})';
}

class BluetoothScanParams {
  const BluetoothScanParams({required this.enabled, this.timeoutS});

  final bool enabled;
  final int? timeoutS;

  factory BluetoothScanParams.fromJson(Map<String, dynamic> json) =>
      BluetoothScanParams(
        enabled: json['enabled'] as bool,
        timeoutS: json['timeout_s'] == null ? null : json['timeout_s'] as int,
      );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'timeout_s': ?timeoutS};

  @override
  bool operator ==(Object other) =>
      other is BluetoothScanParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothScanParams(${jsonEncode(toJson())})';
}

class BluetoothScanResult {
  const BluetoothScanResult({
    required this.available,
    required this.powered,
    required this.scanning,
  });

  /// There is a Bluetooth adapter.
  final bool available;
  final bool powered;
  final bool scanning;

  factory BluetoothScanResult.fromJson(Map<String, dynamic> json) =>
      BluetoothScanResult(
        available: json['available'] as bool,
        powered: json['powered'] as bool,
        scanning: json['scanning'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'available': available,
    'powered': powered,
    'scanning': scanning,
  };

  @override
  bool operator ==(Object other) =>
      other is BluetoothScanResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothScanResult(${jsonEncode(toJson())})';
}

class BluetoothDevicesParams {
  const BluetoothDevicesParams();

  factory BluetoothDevicesParams.fromJson(Map<String, dynamic> json) =>
      BluetoothDevicesParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is BluetoothDevicesParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothDevicesParams(${jsonEncode(toJson())})';
}

class BluetoothDevicesResult {
  const BluetoothDevicesResult({required this.devices});

  final List<BtDevice> devices;

  factory BluetoothDevicesResult.fromJson(Map<String, dynamic> json) =>
      BluetoothDevicesResult(
        devices: (json['devices'] as List)
            .map((x) => BtDevice.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'devices': devices.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is BluetoothDevicesResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothDevicesResult(${jsonEncode(toJson())})';
}

class BluetoothPairParams {
  const BluetoothPairParams({required this.address});

  /// A Bluetooth address, upper case.
  final String address;

  factory BluetoothPairParams.fromJson(Map<String, dynamic> json) =>
      BluetoothPairParams(address: json['address'] as String);

  Map<String, dynamic> toJson() => {'address': address};

  @override
  bool operator ==(Object other) =>
      other is BluetoothPairParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothPairParams(${jsonEncode(toJson())})';
}

class BluetoothPairResult {
  const BluetoothPairResult({
    required this.address,
    required this.name,
    required this.kind,
    required this.paired,
    required this.connected,
    required this.trusted,
    this.battery,
    this.rssi,
  });

  /// A Bluetooth address, upper case.
  final String address;
  final String name;
  final BtKind kind;
  final bool paired;
  final bool connected;
  final bool trusted;
  final int? battery;

  /// dBm, while in range.
  final int? rssi;

  factory BluetoothPairResult.fromJson(Map<String, dynamic> json) =>
      BluetoothPairResult(
        address: json['address'] as String,
        name: json['name'] as String,
        kind: BtKind.fromJson(json['kind'] as String),
        paired: json['paired'] as bool,
        connected: json['connected'] as bool,
        trusted: json['trusted'] as bool,
        battery: json['battery'] == null ? null : json['battery'] as int,
        rssi: json['rssi'] == null ? null : json['rssi'] as int,
      );

  Map<String, dynamic> toJson() => {
    'address': address,
    'name': name,
    'kind': kind.toJson(),
    'paired': paired,
    'connected': connected,
    'trusted': trusted,
    'battery': ?battery,
    'rssi': ?rssi,
  };

  @override
  bool operator ==(Object other) =>
      other is BluetoothPairResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothPairResult(${jsonEncode(toJson())})';
}

class BluetoothConfirmParams {
  const BluetoothConfirmParams({required this.address, required this.accept});

  /// A Bluetooth address, upper case.
  final String address;
  final bool accept;

  factory BluetoothConfirmParams.fromJson(Map<String, dynamic> json) =>
      BluetoothConfirmParams(
        address: json['address'] as String,
        accept: json['accept'] as bool,
      );

  Map<String, dynamic> toJson() => {'address': address, 'accept': accept};

  @override
  bool operator ==(Object other) =>
      other is BluetoothConfirmParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothConfirmParams(${jsonEncode(toJson())})';
}

class BluetoothConfirmResult {
  const BluetoothConfirmResult();

  factory BluetoothConfirmResult.fromJson(Map<String, dynamic> json) =>
      BluetoothConfirmResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is BluetoothConfirmResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothConfirmResult(${jsonEncode(toJson())})';
}

class BluetoothConnectParams {
  const BluetoothConnectParams({required this.address});

  /// A Bluetooth address, upper case.
  final String address;

  factory BluetoothConnectParams.fromJson(Map<String, dynamic> json) =>
      BluetoothConnectParams(address: json['address'] as String);

  Map<String, dynamic> toJson() => {'address': address};

  @override
  bool operator ==(Object other) =>
      other is BluetoothConnectParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothConnectParams(${jsonEncode(toJson())})';
}

class BluetoothConnectResult {
  const BluetoothConnectResult({
    required this.address,
    required this.name,
    required this.kind,
    required this.paired,
    required this.connected,
    required this.trusted,
    this.battery,
    this.rssi,
  });

  /// A Bluetooth address, upper case.
  final String address;
  final String name;
  final BtKind kind;
  final bool paired;
  final bool connected;
  final bool trusted;
  final int? battery;

  /// dBm, while in range.
  final int? rssi;

  factory BluetoothConnectResult.fromJson(Map<String, dynamic> json) =>
      BluetoothConnectResult(
        address: json['address'] as String,
        name: json['name'] as String,
        kind: BtKind.fromJson(json['kind'] as String),
        paired: json['paired'] as bool,
        connected: json['connected'] as bool,
        trusted: json['trusted'] as bool,
        battery: json['battery'] == null ? null : json['battery'] as int,
        rssi: json['rssi'] == null ? null : json['rssi'] as int,
      );

  Map<String, dynamic> toJson() => {
    'address': address,
    'name': name,
    'kind': kind.toJson(),
    'paired': paired,
    'connected': connected,
    'trusted': trusted,
    'battery': ?battery,
    'rssi': ?rssi,
  };

  @override
  bool operator ==(Object other) =>
      other is BluetoothConnectResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothConnectResult(${jsonEncode(toJson())})';
}

class BluetoothDisconnectParams {
  const BluetoothDisconnectParams({required this.address});

  /// A Bluetooth address, upper case.
  final String address;

  factory BluetoothDisconnectParams.fromJson(Map<String, dynamic> json) =>
      BluetoothDisconnectParams(address: json['address'] as String);

  Map<String, dynamic> toJson() => {'address': address};

  @override
  bool operator ==(Object other) =>
      other is BluetoothDisconnectParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothDisconnectParams(${jsonEncode(toJson())})';
}

class BluetoothDisconnectResult {
  const BluetoothDisconnectResult({
    required this.address,
    required this.name,
    required this.kind,
    required this.paired,
    required this.connected,
    required this.trusted,
    this.battery,
    this.rssi,
  });

  /// A Bluetooth address, upper case.
  final String address;
  final String name;
  final BtKind kind;
  final bool paired;
  final bool connected;
  final bool trusted;
  final int? battery;

  /// dBm, while in range.
  final int? rssi;

  factory BluetoothDisconnectResult.fromJson(Map<String, dynamic> json) =>
      BluetoothDisconnectResult(
        address: json['address'] as String,
        name: json['name'] as String,
        kind: BtKind.fromJson(json['kind'] as String),
        paired: json['paired'] as bool,
        connected: json['connected'] as bool,
        trusted: json['trusted'] as bool,
        battery: json['battery'] == null ? null : json['battery'] as int,
        rssi: json['rssi'] == null ? null : json['rssi'] as int,
      );

  Map<String, dynamic> toJson() => {
    'address': address,
    'name': name,
    'kind': kind.toJson(),
    'paired': paired,
    'connected': connected,
    'trusted': trusted,
    'battery': ?battery,
    'rssi': ?rssi,
  };

  @override
  bool operator ==(Object other) =>
      other is BluetoothDisconnectResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothDisconnectResult(${jsonEncode(toJson())})';
}

class BluetoothForgetParams {
  const BluetoothForgetParams({required this.address});

  /// A Bluetooth address, upper case.
  final String address;

  factory BluetoothForgetParams.fromJson(Map<String, dynamic> json) =>
      BluetoothForgetParams(address: json['address'] as String);

  Map<String, dynamic> toJson() => {'address': address};

  @override
  bool operator ==(Object other) =>
      other is BluetoothForgetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothForgetParams(${jsonEncode(toJson())})';
}

class BluetoothForgetResult {
  const BluetoothForgetResult();

  factory BluetoothForgetResult.fromJson(Map<String, dynamic> json) =>
      BluetoothForgetResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is BluetoothForgetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothForgetResult(${jsonEncode(toJson())})';
}

class AudioOutputsParams {
  const AudioOutputsParams();

  factory AudioOutputsParams.fromJson(Map<String, dynamic> json) =>
      AudioOutputsParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AudioOutputsParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioOutputsParams(${jsonEncode(toJson())})';
}

class AudioOutputsResult {
  const AudioOutputsResult({
    required this.outputs,
    required this.volume,
    required this.muted,
  });

  final List<AudioOutput> outputs;

  /// The default output's volume, percent.
  final int volume;
  final bool muted;

  factory AudioOutputsResult.fromJson(Map<String, dynamic> json) =>
      AudioOutputsResult(
        outputs: (json['outputs'] as List)
            .map(
              (x) => AudioOutput.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        volume: json['volume'] as int,
        muted: json['muted'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'outputs': outputs.map((x) => x.toJson()).toList(),
    'volume': volume,
    'muted': muted,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioOutputsResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioOutputsResult(${jsonEncode(toJson())})';
}

class AudioSetOutputParams {
  const AudioSetOutputParams({required this.id});

  final String id;

  factory AudioSetOutputParams.fromJson(Map<String, dynamic> json) =>
      AudioSetOutputParams(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is AudioSetOutputParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioSetOutputParams(${jsonEncode(toJson())})';
}

class AudioSetOutputResult {
  const AudioSetOutputResult({
    required this.outputs,
    required this.volume,
    required this.muted,
  });

  final List<AudioOutput> outputs;

  /// The default output's volume, percent.
  final int volume;
  final bool muted;

  factory AudioSetOutputResult.fromJson(Map<String, dynamic> json) =>
      AudioSetOutputResult(
        outputs: (json['outputs'] as List)
            .map(
              (x) => AudioOutput.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        volume: json['volume'] as int,
        muted: json['muted'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'outputs': outputs.map((x) => x.toJson()).toList(),
    'volume': volume,
    'muted': muted,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioSetOutputResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioSetOutputResult(${jsonEncode(toJson())})';
}

class AudioVolumeParams {
  const AudioVolumeParams({this.percent});

  final int? percent;

  factory AudioVolumeParams.fromJson(Map<String, dynamic> json) =>
      AudioVolumeParams(
        percent: json['percent'] == null ? null : json['percent'] as int,
      );

  Map<String, dynamic> toJson() => {'percent': ?percent};

  @override
  bool operator ==(Object other) =>
      other is AudioVolumeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioVolumeParams(${jsonEncode(toJson())})';
}

class AudioVolumeResult {
  const AudioVolumeResult({
    required this.outputs,
    required this.volume,
    required this.muted,
  });

  final List<AudioOutput> outputs;

  /// The default output's volume, percent.
  final int volume;
  final bool muted;

  factory AudioVolumeResult.fromJson(Map<String, dynamic> json) =>
      AudioVolumeResult(
        outputs: (json['outputs'] as List)
            .map(
              (x) => AudioOutput.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        volume: json['volume'] as int,
        muted: json['muted'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'outputs': outputs.map((x) => x.toJson()).toList(),
    'volume': volume,
    'muted': muted,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioVolumeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioVolumeResult(${jsonEncode(toJson())})';
}

class AudioMuteParams {
  const AudioMuteParams({required this.muted});

  final bool muted;

  factory AudioMuteParams.fromJson(Map<String, dynamic> json) =>
      AudioMuteParams(muted: json['muted'] as bool);

  Map<String, dynamic> toJson() => {'muted': muted};

  @override
  bool operator ==(Object other) =>
      other is AudioMuteParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioMuteParams(${jsonEncode(toJson())})';
}

class AudioMuteResult {
  const AudioMuteResult({
    required this.outputs,
    required this.volume,
    required this.muted,
  });

  final List<AudioOutput> outputs;

  /// The default output's volume, percent.
  final int volume;
  final bool muted;

  factory AudioMuteResult.fromJson(Map<String, dynamic> json) =>
      AudioMuteResult(
        outputs: (json['outputs'] as List)
            .map(
              (x) => AudioOutput.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        volume: json['volume'] as int,
        muted: json['muted'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'outputs': outputs.map((x) => x.toJson()).toList(),
    'volume': volume,
    'muted': muted,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioMuteResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioMuteResult(${jsonEncode(toJson())})';
}

class DisplayModesParams {
  const DisplayModesParams();

  factory DisplayModesParams.fromJson(Map<String, dynamic> json) =>
      DisplayModesParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is DisplayModesParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayModesParams(${jsonEncode(toJson())})';
}

class DisplayModesResult {
  const DisplayModesResult({
    required this.modes,
    this.display,
    required this.canSet,
  });

  final List<DisplayModeInfo> modes;

  /// Make and model of the display, if known.
  final String? display;

  /// display.set_mode can work.
  final bool canSet;

  factory DisplayModesResult.fromJson(Map<String, dynamic> json) =>
      DisplayModesResult(
        modes: (json['modes'] as List)
            .map(
              (x) =>
                  DisplayModeInfo.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        display: json['display'] == null ? null : json['display'] as String,
        canSet: json['can_set'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'modes': modes.map((x) => x.toJson()).toList(),
    'display': ?display,
    'can_set': canSet,
  };

  @override
  bool operator ==(Object other) =>
      other is DisplayModesResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayModesResult(${jsonEncode(toJson())})';
}

/// A display mode: pixels, and refresh rate in whole Hz (59.94 Hz is 60).
class DisplaySetModeParams {
  const DisplaySetModeParams({
    required this.width,
    required this.height,
    required this.refresh,
  });

  final int width;
  final int height;
  final int refresh;

  factory DisplaySetModeParams.fromJson(Map<String, dynamic> json) =>
      DisplaySetModeParams(
        width: json['width'] as int,
        height: json['height'] as int,
        refresh: json['refresh'] as int,
      );

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'refresh': refresh,
  };

  @override
  bool operator ==(Object other) =>
      other is DisplaySetModeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplaySetModeParams(${jsonEncode(toJson())})';
}

class DisplaySetModeResult {
  const DisplaySetModeResult({required this.previous, required this.current});

  /// A display mode: pixels, and refresh rate in whole Hz (59.94 Hz is 60).
  final Mode previous;

  /// A display mode: pixels, and refresh rate in whole Hz (59.94 Hz is 60).
  final Mode current;

  factory DisplaySetModeResult.fromJson(
    Map<String, dynamic> json,
  ) => DisplaySetModeResult(
    previous: Mode.fromJson((json['previous'] as Map).cast<String, dynamic>()),
    current: Mode.fromJson((json['current'] as Map).cast<String, dynamic>()),
  );

  Map<String, dynamic> toJson() => {
    'previous': previous.toJson(),
    'current': current.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is DisplaySetModeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplaySetModeResult(${jsonEncode(toJson())})';
}

class DisplayKeepParams {
  const DisplayKeepParams();

  factory DisplayKeepParams.fromJson(Map<String, dynamic> json) =>
      DisplayKeepParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is DisplayKeepParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayKeepParams(${jsonEncode(toJson())})';
}

class DisplayKeepResult {
  const DisplayKeepResult();

  factory DisplayKeepResult.fromJson(Map<String, dynamic> json) =>
      DisplayKeepResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is DisplayKeepResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayKeepResult(${jsonEncode(toJson())})';
}

class DisplayRevertParams {
  const DisplayRevertParams();

  factory DisplayRevertParams.fromJson(Map<String, dynamic> json) =>
      DisplayRevertParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is DisplayRevertParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayRevertParams(${jsonEncode(toJson())})';
}

class DisplayRevertResult {
  const DisplayRevertResult({required this.current});

  /// A display mode: pixels, and refresh rate in whole Hz (59.94 Hz is 60).
  final Mode current;

  factory DisplayRevertResult.fromJson(Map<String, dynamic> json) =>
      DisplayRevertResult(
        current: Mode.fromJson(
          (json['current'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {'current': current.toJson()};

  @override
  bool operator ==(Object other) =>
      other is DisplayRevertResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DisplayRevertResult(${jsonEncode(toJson())})';
}

class PowerCapabilitiesParams {
  const PowerCapabilitiesParams();

  factory PowerCapabilitiesParams.fromJson(Map<String, dynamic> json) =>
      PowerCapabilitiesParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerCapabilitiesParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerCapabilitiesParams(${jsonEncode(toJson())})';
}

class PowerCapabilitiesResult {
  const PowerCapabilitiesResult({
    required this.suspend,
    required this.reboot,
    required this.poweroff,
  });

  /// logind's answer: challenge needs authentication nobody can give on this box.
  final PowerCapability suspend;

  /// logind's answer: challenge needs authentication nobody can give on this box.
  final PowerCapability reboot;

  /// logind's answer: challenge needs authentication nobody can give on this box.
  final PowerCapability poweroff;

  factory PowerCapabilitiesResult.fromJson(Map<String, dynamic> json) =>
      PowerCapabilitiesResult(
        suspend: PowerCapability.fromJson(json['suspend'] as String),
        reboot: PowerCapability.fromJson(json['reboot'] as String),
        poweroff: PowerCapability.fromJson(json['poweroff'] as String),
      );

  Map<String, dynamic> toJson() => {
    'suspend': suspend.toJson(),
    'reboot': reboot.toJson(),
    'poweroff': poweroff.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PowerCapabilitiesResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerCapabilitiesResult(${jsonEncode(toJson())})';
}

class PowerSuspendParams {
  const PowerSuspendParams();

  factory PowerSuspendParams.fromJson(Map<String, dynamic> json) =>
      PowerSuspendParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerSuspendParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerSuspendParams(${jsonEncode(toJson())})';
}

class PowerSuspendResult {
  const PowerSuspendResult();

  factory PowerSuspendResult.fromJson(Map<String, dynamic> json) =>
      PowerSuspendResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerSuspendResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerSuspendResult(${jsonEncode(toJson())})';
}

class PowerRebootParams {
  const PowerRebootParams();

  factory PowerRebootParams.fromJson(Map<String, dynamic> json) =>
      PowerRebootParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerRebootParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerRebootParams(${jsonEncode(toJson())})';
}

class PowerRebootResult {
  const PowerRebootResult();

  factory PowerRebootResult.fromJson(Map<String, dynamic> json) =>
      PowerRebootResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerRebootResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerRebootResult(${jsonEncode(toJson())})';
}

class PowerPoweroffParams {
  const PowerPoweroffParams();

  factory PowerPoweroffParams.fromJson(Map<String, dynamic> json) =>
      PowerPoweroffParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerPoweroffParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerPoweroffParams(${jsonEncode(toJson())})';
}

class PowerPoweroffResult {
  const PowerPoweroffResult();

  factory PowerPoweroffResult.fromJson(Map<String, dynamic> json) =>
      PowerPoweroffResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is PowerPoweroffResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerPoweroffResult(${jsonEncode(toJson())})';
}

class AuthRespondParams {
  const AuthRespondParams({required this.cookie, required this.password});

  /// polkit's cookie for one authentication request.
  final String cookie;
  final String password;

  factory AuthRespondParams.fromJson(Map<String, dynamic> json) =>
      AuthRespondParams(
        cookie: json['cookie'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {'cookie': cookie, 'password': password};

  @override
  bool operator ==(Object other) =>
      other is AuthRespondParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthRespondParams(${jsonEncode(toJson())})';
}

class AuthRespondResult {
  const AuthRespondResult({required this.ok, required this.attemptsLeft});

  final bool ok;
  final int attemptsLeft;

  factory AuthRespondResult.fromJson(Map<String, dynamic> json) =>
      AuthRespondResult(
        ok: json['ok'] as bool,
        attemptsLeft: json['attempts_left'] as int,
      );

  Map<String, dynamic> toJson() => {'ok': ok, 'attempts_left': attemptsLeft};

  @override
  bool operator ==(Object other) =>
      other is AuthRespondResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthRespondResult(${jsonEncode(toJson())})';
}

class AuthCancelParams {
  const AuthCancelParams({required this.cookie});

  /// polkit's cookie for one authentication request.
  final String cookie;

  factory AuthCancelParams.fromJson(Map<String, dynamic> json) =>
      AuthCancelParams(cookie: json['cookie'] as String);

  Map<String, dynamic> toJson() => {'cookie': cookie};

  @override
  bool operator ==(Object other) =>
      other is AuthCancelParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthCancelParams(${jsonEncode(toJson())})';
}

class AuthCancelResult {
  const AuthCancelResult();

  factory AuthCancelResult.fromJson(Map<String, dynamic> json) =>
      AuthCancelResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AuthCancelResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthCancelResult(${jsonEncode(toJson())})';
}

class SessionRestartParams {
  const SessionRestartParams();

  factory SessionRestartParams.fromJson(Map<String, dynamic> json) =>
      SessionRestartParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionRestartParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionRestartParams(${jsonEncode(toJson())})';
}

class SessionRestartResult {
  const SessionRestartResult();

  factory SessionRestartResult.fromJson(Map<String, dynamic> json) =>
      SessionRestartResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionRestartResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionRestartResult(${jsonEncode(toJson())})';
}

class StoreListParams {
  const StoreListParams();

  factory StoreListParams.fromJson(Map<String, dynamic> json) =>
      StoreListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is StoreListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreListParams(${jsonEncode(toJson())})';
}

class StoreListResult {
  const StoreListResult({
    required this.indexVersion,
    required this.apps,
    required this.moreAfterUpdate,
  });

  final int indexVersion;
  final List<StoreApp> apps;
  final bool moreAfterUpdate;

  factory StoreListResult.fromJson(Map<String, dynamic> json) =>
      StoreListResult(
        indexVersion: json['index_version'] as int,
        apps: (json['apps'] as List)
            .map((x) => StoreApp.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
        moreAfterUpdate: json['more_after_update'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'index_version': indexVersion,
    'apps': apps.map((x) => x.toJson()).toList(),
    'more_after_update': moreAfterUpdate,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreListResult(${jsonEncode(toJson())})';
}

class ProfileCurrentParams {
  const ProfileCurrentParams();

  factory ProfileCurrentParams.fromJson(Map<String, dynamic> json) =>
      ProfileCurrentParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is ProfileCurrentParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfileCurrentParams(${jsonEncode(toJson())})';
}

class ProfileCurrentResult {
  const ProfileCurrentResult({
    required this.id,
    required this.name,
    required this.color,
    required this.admin,
    required this.locked,
    required this.guest,
    required this.setupRequired,
    required this.pinSet,
    required this.screenLocked,
  });

  /// A profile id, or 'guest'.
  final String id;

  /// Null for a spare account in first-boot mode.
  final String? name;
  final ProfileColor? color;
  final bool admin;

  /// The profile asks for its PIN to enter (at the picker and after sleep).
  final bool locked;
  final bool guest;
  final bool setupRequired;
  final bool pinSet;
  final bool screenLocked;

  factory ProfileCurrentResult.fromJson(Map<String, dynamic> json) =>
      ProfileCurrentResult(
        id: json['id'] as String,
        name: json['name'] == null ? null : json['name'] as String,
        color: json['color'] == null
            ? null
            : ProfileColor.fromJson(json['color'] as String),
        admin: json['admin'] as bool,
        locked: json['locked'] as bool,
        guest: json['guest'] as bool,
        setupRequired: json['setup_required'] as bool,
        pinSet: json['pin_set'] as bool,
        screenLocked: json['screen_locked'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color == null ? null : color!.toJson(),
    'admin': admin,
    'locked': locked,
    'guest': guest,
    'setup_required': setupRequired,
    'pin_set': pinSet,
    'screen_locked': screenLocked,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfileCurrentResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfileCurrentResult(${jsonEncode(toJson())})';
}

class SessionSwitchProfileParams {
  const SessionSwitchProfileParams({required this.id});

  /// A profile id, or 'guest'.
  final String id;

  factory SessionSwitchProfileParams.fromJson(Map<String, dynamic> json) =>
      SessionSwitchProfileParams(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchProfileParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchProfileParams(${jsonEncode(toJson())})';
}

class SessionSwitchProfileResult {
  const SessionSwitchProfileResult();

  factory SessionSwitchProfileResult.fromJson(Map<String, dynamic> json) =>
      SessionSwitchProfileResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchProfileResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchProfileResult(${jsonEncode(toJson())})';
}

class SessionSwitchWaitParams {
  const SessionSwitchWaitParams();

  factory SessionSwitchWaitParams.fromJson(Map<String, dynamic> json) =>
      SessionSwitchWaitParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchWaitParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchWaitParams(${jsonEncode(toJson())})';
}

class SessionSwitchWaitResult {
  const SessionSwitchWaitResult();

  factory SessionSwitchWaitResult.fromJson(Map<String, dynamic> json) =>
      SessionSwitchWaitResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchWaitResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchWaitResult(${jsonEncode(toJson())})';
}

class SessionSwitchForceCloseParams {
  const SessionSwitchForceCloseParams({required this.app});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String app;

  factory SessionSwitchForceCloseParams.fromJson(Map<String, dynamic> json) =>
      SessionSwitchForceCloseParams(app: json['app'] as String);

  Map<String, dynamic> toJson() => {'app': app};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchForceCloseParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchForceCloseParams(${jsonEncode(toJson())})';
}

class SessionSwitchForceCloseResult {
  const SessionSwitchForceCloseResult();

  factory SessionSwitchForceCloseResult.fromJson(Map<String, dynamic> json) =>
      SessionSwitchForceCloseResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchForceCloseResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchForceCloseResult(${jsonEncode(toJson())})';
}

class SessionSwitchCancelParams {
  const SessionSwitchCancelParams();

  factory SessionSwitchCancelParams.fromJson(Map<String, dynamic> json) =>
      SessionSwitchCancelParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchCancelParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchCancelParams(${jsonEncode(toJson())})';
}

class SessionSwitchCancelResult {
  const SessionSwitchCancelResult();

  factory SessionSwitchCancelResult.fromJson(Map<String, dynamic> json) =>
      SessionSwitchCancelResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionSwitchCancelResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionSwitchCancelResult(${jsonEncode(toJson())})';
}

class SessionUnlockParams {
  const SessionUnlockParams({required this.pin});

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;

  factory SessionUnlockParams.fromJson(Map<String, dynamic> json) =>
      SessionUnlockParams(pin: json['pin'] as String);

  Map<String, dynamic> toJson() => {'pin': pin};

  @override
  bool operator ==(Object other) =>
      other is SessionUnlockParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionUnlockParams(${jsonEncode(toJson())})';
}

class SessionUnlockResult {
  const SessionUnlockResult();

  factory SessionUnlockResult.fromJson(Map<String, dynamic> json) =>
      SessionUnlockResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionUnlockResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionUnlockResult(${jsonEncode(toJson())})';
}

class SessionEndGuestParams {
  const SessionEndGuestParams();

  factory SessionEndGuestParams.fromJson(Map<String, dynamic> json) =>
      SessionEndGuestParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionEndGuestParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionEndGuestParams(${jsonEncode(toJson())})';
}

class SessionEndGuestResult {
  const SessionEndGuestResult();

  factory SessionEndGuestResult.fromJson(Map<String, dynamic> json) =>
      SessionEndGuestResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionEndGuestResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionEndGuestResult(${jsonEncode(toJson())})';
}

class GreeterListParams {
  const GreeterListParams();

  factory GreeterListParams.fromJson(Map<String, dynamic> json) =>
      GreeterListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is GreeterListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterListParams(${jsonEncode(toJson())})';
}

class GreeterListResult {
  const GreeterListResult({
    required this.profiles,
    required this.guest,
    required this.firstBoot,
    required this.focus,
    required this.appearance,
    required this.job,
  });

  final List<PublicProfile> profiles;

  /// The guest is enabled.
  final bool guest;
  final bool firstBoot;
  final String? focus;
  final Appearance appearance;
  final String? job;

  factory GreeterListResult.fromJson(Map<String, dynamic> json) =>
      GreeterListResult(
        profiles: (json['profiles'] as List)
            .map(
              (x) => PublicProfile.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        guest: json['guest'] as bool,
        firstBoot: json['first_boot'] as bool,
        focus: json['focus'] == null ? null : json['focus'] as String,
        appearance: Appearance.fromJson(
          (json['appearance'] as Map).cast<String, dynamic>(),
        ),
        job: json['job'] == null ? null : json['job'] as String,
      );

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((x) => x.toJson()).toList(),
    'guest': guest,
    'first_boot': firstBoot,
    'focus': focus,
    'appearance': appearance.toJson(),
    'job': job,
  };

  @override
  bool operator ==(Object other) =>
      other is GreeterListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterListResult(${jsonEncode(toJson())})';
}

class GreeterLoginParams {
  const GreeterLoginParams({required this.id});

  /// A profile id, or 'guest'.
  final String id;

  factory GreeterLoginParams.fromJson(Map<String, dynamic> json) =>
      GreeterLoginParams(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is GreeterLoginParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterLoginParams(${jsonEncode(toJson())})';
}

class GreeterLoginResult {
  const GreeterLoginResult();

  factory GreeterLoginResult.fromJson(Map<String, dynamic> json) =>
      GreeterLoginResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is GreeterLoginResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterLoginResult(${jsonEncode(toJson())})';
}

class GreeterPinParams {
  const GreeterPinParams({required this.pin});

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;

  factory GreeterPinParams.fromJson(Map<String, dynamic> json) =>
      GreeterPinParams(pin: json['pin'] as String);

  Map<String, dynamic> toJson() => {'pin': pin};

  @override
  bool operator ==(Object other) =>
      other is GreeterPinParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterPinParams(${jsonEncode(toJson())})';
}

class GreeterPinResult {
  const GreeterPinResult();

  factory GreeterPinResult.fromJson(Map<String, dynamic> json) =>
      GreeterPinResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is GreeterPinResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterPinResult(${jsonEncode(toJson())})';
}

class GreeterCancelParams {
  const GreeterCancelParams();

  factory GreeterCancelParams.fromJson(Map<String, dynamic> json) =>
      GreeterCancelParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is GreeterCancelParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterCancelParams(${jsonEncode(toJson())})';
}

class GreeterCancelResult {
  const GreeterCancelResult();

  factory GreeterCancelResult.fromJson(Map<String, dynamic> json) =>
      GreeterCancelResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is GreeterCancelResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterCancelResult(${jsonEncode(toJson())})';
}

class GreeterCreateParams {
  const GreeterCreateParams({
    required this.name,
    this.color,
    required this.pin,
    required this.locked,
  });

  /// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
  final String name;

  /// The profile's colour (tile and chip). Clients must treat unknown values like teal.
  final ProfileColor? color;

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;
  final bool locked;

  factory GreeterCreateParams.fromJson(Map<String, dynamic> json) =>
      GreeterCreateParams(
        name: json['name'] as String,
        color: json['color'] == null
            ? null
            : ProfileColor.fromJson(json['color'] as String),
        pin: json['pin'] as String,
        locked: json['locked'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (color != null) 'color': color!.toJson(),
    'pin': pin,
    'locked': locked,
  };

  @override
  bool operator ==(Object other) =>
      other is GreeterCreateParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterCreateParams(${jsonEncode(toJson())})';
}

/// A started profile job and the id the new profile will have.
class GreeterCreateResult {
  const GreeterCreateResult({required this.jobId, required this.id});

  /// Server-issued job id.
  final String jobId;

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  factory GreeterCreateResult.fromJson(Map<String, dynamic> json) =>
      GreeterCreateResult(
        jobId: json['job_id'] as String,
        id: json['id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is GreeterCreateResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterCreateResult(${jsonEncode(toJson())})';
}

class SystemProfilesListParams {
  const SystemProfilesListParams();

  factory SystemProfilesListParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesListParams(${jsonEncode(toJson())})';
}

class SystemProfilesListResultGuest {
  const SystemProfilesListResultGuest({
    required this.enabled,
    required this.usage,
  });

  final bool enabled;
  final ProfileUsage? usage;

  factory SystemProfilesListResultGuest.fromJson(Map<String, dynamic> json) =>
      SystemProfilesListResultGuest(
        enabled: json['enabled'] as bool,
        usage: json['usage'] == null
            ? null
            : ProfileUsage.fromJson(
                (json['usage'] as Map).cast<String, dynamic>(),
              ),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'usage': usage == null ? null : usage!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesListResultGuest &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesListResultGuest(${jsonEncode(toJson())})';
}

class SystemProfilesListResult {
  const SystemProfilesListResult({
    required this.profiles,
    required this.guest,
    required this.max,
    required this.firstBoot,
  });

  final List<Profile> profiles;
  final SystemProfilesListResultGuest guest;
  final int max;
  final bool firstBoot;

  factory SystemProfilesListResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesListResult(
        profiles: (json['profiles'] as List)
            .map((x) => Profile.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
        guest: SystemProfilesListResultGuest.fromJson(
          (json['guest'] as Map).cast<String, dynamic>(),
        ),
        max: json['max'] as int,
        firstBoot: json['first_boot'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((x) => x.toJson()).toList(),
    'guest': guest.toJson(),
    'max': max,
    'first_boot': firstBoot,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesListResult(${jsonEncode(toJson())})';
}

class SystemProfilesCreateParams {
  const SystemProfilesCreateParams({
    required this.name,
    this.color,
    required this.pin,
    required this.locked,
    required this.revision,
  });

  /// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
  final String name;

  /// The profile's colour (tile and chip). Clients must treat unknown values like teal.
  final ProfileColor? color;

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;
  final bool locked;

  /// SHA-256 of state.json, hex.
  final String revision;

  factory SystemProfilesCreateParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesCreateParams(
        name: json['name'] as String,
        color: json['color'] == null
            ? null
            : ProfileColor.fromJson(json['color'] as String),
        pin: json['pin'] as String,
        locked: json['locked'] as bool,
        revision: json['revision'] as String,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (color != null) 'color': color!.toJson(),
    'pin': pin,
    'locked': locked,
    'revision': revision,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesCreateParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesCreateParams(${jsonEncode(toJson())})';
}

/// A started profile job and the id the new profile will have.
class SystemProfilesCreateResult {
  const SystemProfilesCreateResult({required this.jobId, required this.id});

  /// Server-issued job id.
  final String jobId;

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  factory SystemProfilesCreateResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesCreateResult(
        jobId: json['job_id'] as String,
        id: json['id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesCreateResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesCreateResult(${jsonEncode(toJson())})';
}

class SystemProfilesSetupAdminParams {
  const SystemProfilesSetupAdminParams({
    required this.name,
    this.color,
    required this.pin,
    required this.locked,
  });

  /// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
  final String name;

  /// The profile's colour (tile and chip). Clients must treat unknown values like teal.
  final ProfileColor? color;

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;
  final bool locked;

  factory SystemProfilesSetupAdminParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesSetupAdminParams(
        name: json['name'] as String,
        color: json['color'] == null
            ? null
            : ProfileColor.fromJson(json['color'] as String),
        pin: json['pin'] as String,
        locked: json['locked'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (color != null) 'color': color!.toJson(),
    'pin': pin,
    'locked': locked,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetupAdminParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemProfilesSetupAdminParams(${jsonEncode(toJson())})';
}

class SystemProfilesSetupAdminResult {
  const SystemProfilesSetupAdminResult({required this.id});

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  factory SystemProfilesSetupAdminResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesSetupAdminResult(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetupAdminResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemProfilesSetupAdminResult(${jsonEncode(toJson())})';
}

class SystemProfilesRenameParams {
  const SystemProfilesRenameParams({
    required this.id,
    required this.name,
    this.pin,
  });

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters. Never a username.
  final String name;

  /// 4 to 8 ASCII digits. Never logged.
  final String? pin;

  factory SystemProfilesRenameParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesRenameParams(
        id: json['id'] as String,
        name: json['name'] as String,
        pin: json['pin'] == null ? null : json['pin'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'pin': ?pin};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesRenameParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesRenameParams(${jsonEncode(toJson())})';
}

class SystemProfilesRenameResult {
  const SystemProfilesRenameResult();

  factory SystemProfilesRenameResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesRenameResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesRenameResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesRenameResult(${jsonEncode(toJson())})';
}

class SystemProfilesSetAppearanceParams {
  const SystemProfilesSetAppearanceParams({
    this.color,
    this.textScale,
    this.highContrast,
    this.reduceMotion,
  });

  /// The profile's colour (tile and chip). Clients must treat unknown values like teal.
  final ProfileColor? color;
  final num? textScale;
  final bool? highContrast;
  final bool? reduceMotion;

  factory SystemProfilesSetAppearanceParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemProfilesSetAppearanceParams(
    color: json['color'] == null
        ? null
        : ProfileColor.fromJson(json['color'] as String),
    textScale: json['text_scale'] == null ? null : json['text_scale'] as num,
    highContrast: json['high_contrast'] == null
        ? null
        : json['high_contrast'] as bool,
    reduceMotion: json['reduce_motion'] == null
        ? null
        : json['reduce_motion'] as bool,
  );

  Map<String, dynamic> toJson() => {
    if (color != null) 'color': color!.toJson(),
    'text_scale': ?textScale,
    'high_contrast': ?highContrast,
    'reduce_motion': ?reduceMotion,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetAppearanceParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemProfilesSetAppearanceParams(${jsonEncode(toJson())})';
}

class SystemProfilesSetAppearanceResult {
  const SystemProfilesSetAppearanceResult();

  factory SystemProfilesSetAppearanceResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemProfilesSetAppearanceResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetAppearanceResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemProfilesSetAppearanceResult(${jsonEncode(toJson())})';
}

class SystemProfilesSetPinParams {
  const SystemProfilesSetPinParams({required this.pin, this.currentPin});

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;

  /// 4 to 8 ASCII digits. Never logged.
  final String? currentPin;

  factory SystemProfilesSetPinParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesSetPinParams(
        pin: json['pin'] as String,
        currentPin: json['current_pin'] == null
            ? null
            : json['current_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'pin': pin, 'current_pin': ?currentPin};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetPinParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesSetPinParams(${jsonEncode(toJson())})';
}

class SystemProfilesSetPinResult {
  const SystemProfilesSetPinResult();

  factory SystemProfilesSetPinResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesSetPinResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetPinResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesSetPinResult(${jsonEncode(toJson())})';
}

class SystemProfilesSetLockedParams {
  const SystemProfilesSetLockedParams({
    required this.locked,
    required this.pin,
  });

  final bool locked;

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;

  factory SystemProfilesSetLockedParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesSetLockedParams(
        locked: json['locked'] as bool,
        pin: json['pin'] as String,
      );

  Map<String, dynamic> toJson() => {'locked': locked, 'pin': pin};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetLockedParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesSetLockedParams(${jsonEncode(toJson())})';
}

class SystemProfilesSetLockedResult {
  const SystemProfilesSetLockedResult();

  factory SystemProfilesSetLockedResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesSetLockedResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesSetLockedResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesSetLockedResult(${jsonEncode(toJson())})';
}

class SystemProfilesResetPinParams {
  const SystemProfilesResetPinParams({
    required this.id,
    required this.newPin,
    this.adminPin,
  });

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  /// 4 to 8 ASCII digits. Never logged.
  final String newPin;

  /// 4 to 8 ASCII digits. Never logged.
  final String? adminPin;

  factory SystemProfilesResetPinParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesResetPinParams(
        id: json['id'] as String,
        newPin: json['new_pin'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'new_pin': newPin,
    'admin_pin': ?adminPin,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesResetPinParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesResetPinParams(${jsonEncode(toJson())})';
}

class SystemProfilesResetPinResult {
  const SystemProfilesResetPinResult();

  factory SystemProfilesResetPinResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesResetPinResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesResetPinResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesResetPinResult(${jsonEncode(toJson())})';
}

class SystemProfilesRemoveParams {
  const SystemProfilesRemoveParams({
    required this.id,
    required this.confirmId,
    required this.pin,
    required this.revision,
  });

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String id;

  /// A profile id: p&lt;N&gt;, server-generated, never reused.
  final String confirmId;

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;

  /// SHA-256 of state.json, hex.
  final String revision;

  factory SystemProfilesRemoveParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesRemoveParams(
        id: json['id'] as String,
        confirmId: json['confirm_id'] as String,
        pin: json['pin'] as String,
        revision: json['revision'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'confirm_id': confirmId,
    'pin': pin,
    'revision': revision,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesRemoveParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesRemoveParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemProfilesRemoveResult {
  const SystemProfilesRemoveResult({required this.jobId});

  final String? jobId;

  factory SystemProfilesRemoveResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesRemoveResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesRemoveResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesRemoveResult(${jsonEncode(toJson())})';
}

class SystemGuestSetParams {
  const SystemGuestSetParams({required this.enabled, required this.adminPin});

  final bool enabled;

  /// 4 to 8 ASCII digits. Never logged.
  final String adminPin;

  factory SystemGuestSetParams.fromJson(Map<String, dynamic> json) =>
      SystemGuestSetParams(
        enabled: json['enabled'] as bool,
        adminPin: json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'admin_pin': adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemGuestSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemGuestSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemGuestSetResult {
  const SystemGuestSetResult({required this.jobId});

  final String? jobId;

  factory SystemGuestSetResult.fromJson(Map<String, dynamic> json) =>
      SystemGuestSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemGuestSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemGuestSetResult(${jsonEncode(toJson())})';
}

class SystemAppsListParams {
  const SystemAppsListParams();

  factory SystemAppsListParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsListParams(${jsonEncode(toJson())})';
}

class SystemAppsListResult {
  const SystemAppsListResult({
    required this.generation,
    required this.revision,
    required this.ids,
    required this.needsTerms,
    required this.box,
  });

  final int generation;

  /// SHA-256 of state.json, hex.
  final String revision;
  final List<String> ids;
  final List<String> needsTerms;

  /// Box features the caller's apps need.
  final List<String> box;

  factory SystemAppsListResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsListResult(
        generation: json['generation'] as int,
        revision: json['revision'] as String,
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        needsTerms: (json['needs_terms'] as List)
            .map((x) => x as String)
            .toList(),
        box: (json['box'] as List).map((x) => x as String).toList(),
      );

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'revision': revision,
    'ids': ids,
    'needs_terms': needsTerms,
    'box': box,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemAppsListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsListResult(${jsonEncode(toJson())})';
}

class SystemAppsGenerationsParams {
  const SystemAppsGenerationsParams();

  factory SystemAppsGenerationsParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsGenerationsParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsGenerationsParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsGenerationsParams(${jsonEncode(toJson())})';
}

class SystemAppsGenerationsResult {
  const SystemAppsGenerationsResult({required this.generations});

  final List<AppGeneration> generations;

  factory SystemAppsGenerationsResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsGenerationsResult(
        generations: (json['generations'] as List)
            .map(
              (x) => AppGeneration.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'generations': generations.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemAppsGenerationsResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsGenerationsResult(${jsonEncode(toJson())})';
}

class SystemAppsRollbackParams {
  const SystemAppsRollbackParams({required this.generation});

  final int generation;

  factory SystemAppsRollbackParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsRollbackParams(generation: json['generation'] as int);

  Map<String, dynamic> toJson() => {'generation': generation};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsRollbackParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsRollbackParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemAppsRollbackResult {
  const SystemAppsRollbackResult({required this.jobId});

  final String? jobId;

  factory SystemAppsRollbackResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsRollbackResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsRollbackResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsRollbackResult(${jsonEncode(toJson())})';
}

class SystemAppsAcceptTermsParams {
  const SystemAppsAcceptTermsParams({required this.id, required this.version});

  /// Catalog app id (state.json apps).
  final String id;

  /// A vendor terms version from the catalog.
  final String version;

  factory SystemAppsAcceptTermsParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsAcceptTermsParams(
        id: json['id'] as String,
        version: json['version'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsAcceptTermsParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsAcceptTermsParams(${jsonEncode(toJson())})';
}

class SystemAppsAcceptTermsResult {
  const SystemAppsAcceptTermsResult();

  factory SystemAppsAcceptTermsResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsAcceptTermsResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsAcceptTermsResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsAcceptTermsResult(${jsonEncode(toJson())})';
}

class SystemStarterSetGetParams {
  const SystemStarterSetGetParams();

  factory SystemStarterSetGetParams.fromJson(Map<String, dynamic> json) =>
      SystemStarterSetGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemStarterSetGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStarterSetGetParams(${jsonEncode(toJson())})';
}

class SystemStarterSetGetResult {
  const SystemStarterSetGetResult({required this.ids, required this.updatedAt});

  final List<String> ids;
  final int? updatedAt;

  factory SystemStarterSetGetResult.fromJson(Map<String, dynamic> json) =>
      SystemStarterSetGetResult(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        updatedAt: json['updated_at'] == null
            ? null
            : json['updated_at'] as int,
      );

  Map<String, dynamic> toJson() => {'ids': ids, 'updated_at': updatedAt};

  @override
  bool operator ==(Object other) =>
      other is SystemStarterSetGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStarterSetGetResult(${jsonEncode(toJson())})';
}

class SystemStarterSetSetParams {
  const SystemStarterSetSetParams({required this.ids, required this.pin});

  final List<String> ids;

  /// 4 to 8 ASCII digits. Never logged.
  final String pin;

  factory SystemStarterSetSetParams.fromJson(Map<String, dynamic> json) =>
      SystemStarterSetSetParams(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        pin: json['pin'] as String,
      );

  Map<String, dynamic> toJson() => {'ids': ids, 'pin': pin};

  @override
  bool operator ==(Object other) =>
      other is SystemStarterSetSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStarterSetSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemStarterSetSetResult {
  const SystemStarterSetSetResult({required this.jobId});

  final String? jobId;

  factory SystemStarterSetSetResult.fromJson(Map<String, dynamic> json) =>
      SystemStarterSetSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemStarterSetSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStarterSetSetResult(${jsonEncode(toJson())})';
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

/// The apps.list result changed: an app's resolved icon became available or changed (for example a web app's icon finished downloading), or (0.9) the daemon reloaded its app list after a switch installed or removed apps. Call apps.list again.
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

/// The on-screen keyboard was shown or hidden (osk.show/osk.hide, the controller chord, A on a focused text field, B while it is visible, Home, or a focus change).
final class OskVisibilityEvent extends SessionEvent {
  const OskVisibilityEvent({required this.visible, this.password});

  final bool visible;

  /// The keyboard is up for a password field. Absent when false.
  final bool? password;

  factory OskVisibilityEvent.fromJson(Map<String, dynamic> json) =>
      OskVisibilityEvent(
        visible: json['visible'] as bool,
        password: json['password'] == null ? null : json['password'] as bool,
      );

  Map<String, dynamic> toJson() => {'visible': visible, 'password': ?password};

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

/// The network status changed (cable, Wi-Fi joined or lost, address, Wi-Fi switched).
final class NetworkChangedEvent extends SessionEvent {
  const NetworkChangedEvent({
    required this.wifiAvailable,
    required this.wifiEnabled,
    required this.ethernet,
    this.wifiSsid,
    this.wifiSignal,
    this.address,
    required this.connectivity,
  });

  /// There is a Wi-Fi device.
  final bool wifiAvailable;

  /// Wi-Fi is switched on.
  final bool wifiEnabled;

  /// An Ethernet device is connected.
  final bool ethernet;

  /// The network Wi-Fi is connected to (absent when not connected).
  final String? wifiSsid;
  final int? wifiSignal;

  /// The primary connection's IPv4 address.
  final String? address;
  final Connectivity connectivity;

  factory NetworkChangedEvent.fromJson(
    Map<String, dynamic> json,
  ) => NetworkChangedEvent(
    wifiAvailable: json['wifi_available'] as bool,
    wifiEnabled: json['wifi_enabled'] as bool,
    ethernet: json['ethernet'] as bool,
    wifiSsid: json['wifi_ssid'] == null ? null : json['wifi_ssid'] as String,
    wifiSignal: json['wifi_signal'] == null ? null : json['wifi_signal'] as int,
    address: json['address'] == null ? null : json['address'] as String,
    connectivity: Connectivity.fromJson(json['connectivity'] as String),
  );

  Map<String, dynamic> toJson() => {
    'wifi_available': wifiAvailable,
    'wifi_enabled': wifiEnabled,
    'ethernet': ethernet,
    'wifi_ssid': ?wifiSsid,
    'wifi_signal': ?wifiSignal,
    'address': ?address,
    'connectivity': connectivity.toJson(),
  };

  @override
  String get name => 'network_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is NetworkChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'NetworkChangedEvent(${jsonEncode(toJson())})';
}

/// The list of Wi-Fi networks in range changed (a scan finished, a network came or went, saved networks changed).
final class WifiListChangedEvent extends SessionEvent {
  const WifiListChangedEvent({required this.networks});

  /// Strongest first.
  final List<WifiNetwork> networks;

  factory WifiListChangedEvent.fromJson(Map<String, dynamic> json) =>
      WifiListChangedEvent(
        networks: (json['networks'] as List)
            .map(
              (x) => WifiNetwork.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'networks': networks.map((x) => x.toJson()).toList(),
  };

  @override
  String get name => 'wifi_list_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is WifiListChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'WifiListChangedEvent(${jsonEncode(toJson())})';
}

/// The adapter's state or a device changed (found, paired, connected, battery, gone).
final class BluetoothChangedEvent extends SessionEvent {
  const BluetoothChangedEvent({required this.status, required this.devices});

  final BtStatus status;
  final List<BtDevice> devices;

  factory BluetoothChangedEvent.fromJson(Map<String, dynamic> json) =>
      BluetoothChangedEvent(
        status: BtStatus.fromJson(
          (json['status'] as Map).cast<String, dynamic>(),
        ),
        devices: (json['devices'] as List)
            .map((x) => BtDevice.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'status': status.toJson(),
    'devices': devices.map((x) => x.toJson()).toList(),
  };

  @override
  String get name => 'bluetooth_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is BluetoothChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothChangedEvent(${jsonEncode(toJson())})';
}

enum BluetoothConfirmEventMode {
  confirm('confirm'),
  display('display'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const BluetoothConfirmEventMode(this.value);
  final String value;

  factory BluetoothConfirmEventMode.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// A device being paired wants the user to compare or read a passkey.
final class BluetoothConfirmEvent extends SessionEvent {
  const BluetoothConfirmEvent({
    required this.address,
    required this.name_,
    required this.passkey,
    required this.mode,
  });

  /// A Bluetooth address, upper case.
  final String address;
  final String name_;
  final String passkey;
  final BluetoothConfirmEventMode mode;

  factory BluetoothConfirmEvent.fromJson(Map<String, dynamic> json) =>
      BluetoothConfirmEvent(
        address: json['address'] as String,
        name_: json['name'] as String,
        passkey: json['passkey'] as String,
        mode: BluetoothConfirmEventMode.fromJson(json['mode'] as String),
      );

  Map<String, dynamic> toJson() => {
    'address': address,
    'name': name_,
    'passkey': passkey,
    'mode': mode.toJson(),
  };

  @override
  String get name => 'bluetooth_confirm';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is BluetoothConfirmEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'BluetoothConfirmEvent(${jsonEncode(toJson())})';
}

/// The outputs, the default output, the volume or the mute state changed.
final class AudioChangedEvent extends SessionEvent {
  const AudioChangedEvent({
    required this.outputs,
    required this.volume,
    required this.muted,
  });

  final List<AudioOutput> outputs;

  /// The default output's volume, percent.
  final int volume;
  final bool muted;

  factory AudioChangedEvent.fromJson(Map<String, dynamic> json) =>
      AudioChangedEvent(
        outputs: (json['outputs'] as List)
            .map(
              (x) => AudioOutput.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        volume: json['volume'] as int,
        muted: json['muted'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'outputs': outputs.map((x) => x.toJson()).toList(),
    'volume': volume,
    'muted': muted,
  };

  @override
  String get name => 'audio_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is AudioChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AudioChangedEvent(${jsonEncode(toJson())})';
}

class AuthenticationRequestedEventIdentitiesItem {
  const AuthenticationRequestedEventIdentitiesItem({
    required this.uid,
    required this.name,
  });

  final int uid;
  final String name;

  factory AuthenticationRequestedEventIdentitiesItem.fromJson(
    Map<String, dynamic> json,
  ) => AuthenticationRequestedEventIdentitiesItem(
    uid: json['uid'] as int,
    name: json['name'] as String,
  );

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is AuthenticationRequestedEventIdentitiesItem &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'AuthenticationRequestedEventIdentitiesItem(${jsonEncode(toJson())})';
}

/// polkit needs the admin password for an action the launcher asked for (for example system.ssh.set): show the password dialog. Sent only to the launcher (hello client name hinteros-launcher).
final class AuthenticationRequestedEvent extends SessionEvent {
  const AuthenticationRequestedEvent({
    required this.cookie,
    required this.action,
    required this.message,
    required this.identities,
  });

  /// polkit's cookie for one authentication request.
  final String cookie;
  final String action;
  final String message;
  final List<AuthenticationRequestedEventIdentitiesItem> identities;

  factory AuthenticationRequestedEvent.fromJson(Map<String, dynamic> json) =>
      AuthenticationRequestedEvent(
        cookie: json['cookie'] as String,
        action: json['action'] as String,
        message: json['message'] as String,
        identities: (json['identities'] as List)
            .map(
              (x) => AuthenticationRequestedEventIdentitiesItem.fromJson(
                (x as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'cookie': cookie,
    'action': action,
    'message': message,
    'identities': identities.map((x) => x.toJson()).toList(),
  };

  @override
  String get name => 'authentication_requested';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is AuthenticationRequestedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthenticationRequestedEvent(${jsonEncode(toJson())})';
}

/// An authentication request is over: authorized, failed (too many wrong passwords) or cancelled (auth.cancel, polkit, or 2 minutes without an answer). Sent only to the launcher.
final class AuthenticationFinishedEvent extends SessionEvent {
  const AuthenticationFinishedEvent({
    required this.cookie,
    required this.outcome,
  });

  /// polkit's cookie for one authentication request.
  final String cookie;
  final AuthOutcome outcome;

  factory AuthenticationFinishedEvent.fromJson(Map<String, dynamic> json) =>
      AuthenticationFinishedEvent(
        cookie: json['cookie'] as String,
        outcome: AuthOutcome.fromJson(json['outcome'] as String),
      );

  Map<String, dynamic> toJson() => {
    'cookie': cookie,
    'outcome': outcome.toJson(),
  };

  @override
  String get name => 'authentication_finished';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is AuthenticationFinishedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AuthenticationFinishedEvent(${jsonEncode(toJson())})';
}

/// What store.list returns may have changed: an apps job started or finished, any other job that switched the system finished, or an update check changed more_after_update, or (0.9) a catalog app's icon was resolved (icon.path). Query store.list again.
final class StoreChangedEvent extends SessionEvent {
  const StoreChangedEvent();

  factory StoreChangedEvent.fromJson(Map<String, dynamic> json) =>
      StoreChangedEvent();

  Map<String, dynamic> toJson() => {};

  @override
  String get name => 'store_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is StoreChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreChangedEvent(${jsonEncode(toJson())})';
}

enum SwitchProgressEventStage {
  closingApps('closing_apps'),
  closingSteam('closing_steam'),
  ending('ending'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const SwitchProgressEventStage(this.value);
  final String value;

  factory SwitchProgressEventStage.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// A profile switch (session.switch_profile) moved on: closing_apps (app: the one being closed, when known), closing_steam, ending (the session ends next). The launcher shows the Switching screen.
final class SwitchProgressEvent extends SessionEvent {
  const SwitchProgressEvent({required this.stage, this.app});

  final SwitchProgressEventStage stage;
  final NamedApp? app;

  factory SwitchProgressEvent.fromJson(Map<String, dynamic> json) =>
      SwitchProgressEvent(
        stage: SwitchProgressEventStage.fromJson(json['stage'] as String),
        app: json['app'] == null
            ? null
            : NamedApp.fromJson((json['app'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {
    'stage': stage.toJson(),
    if (app != null) 'app': app!.toJson(),
  };

  @override
  String get name => 'switch_progress';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is SwitchProgressEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SwitchProgressEvent(${jsonEncode(toJson())})';
}

/// An app (or Steam, or a game) has not closed waited_s seconds into a switch. The launcher, in front, asks: Keep waiting (session.switch_wait), Force close (session.switch_force_close) or Cancel switch (session.switch_cancel).
final class SwitchBlockedEvent extends SessionEvent {
  const SwitchBlockedEvent({required this.app, required this.waitedS});

  final NamedApp app;
  final int waitedS;

  factory SwitchBlockedEvent.fromJson(Map<String, dynamic> json) =>
      SwitchBlockedEvent(
        app: NamedApp.fromJson((json['app'] as Map).cast<String, dynamic>()),
        waitedS: json['waited_s'] as int,
      );

  Map<String, dynamic> toJson() => {'app': app.toJson(), 'waited_s': waitedS};

  @override
  String get name => 'switch_blocked';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is SwitchBlockedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SwitchBlockedEvent(${jsonEncode(toJson())})';
}

/// The sleep lock of a locked profile: locked true before the box sleeps (the launcher is in front, apps keep running behind it; show the PIN pad on resume), false after session.unlock.
final class LockStateEvent extends SessionEvent {
  const LockStateEvent({required this.locked});

  final bool locked;

  factory LockStateEvent.fromJson(Map<String, dynamic> json) =>
      LockStateEvent(locked: json['locked'] as bool);

  Map<String, dynamic> toJson() => {'locked': locked};

  @override
  String get name => 'lock_state';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is LockStateEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'LockStateEvent(${jsonEncode(toJson())})';
}

/// The profiles changed: after a profile job, a rename, a PIN, lock or appearance change. profiles is what system.profiles.list's profiles would say now (also for profile.current's fields).
final class ProfilesChangedEvent extends SessionEvent {
  const ProfilesChangedEvent({required this.profiles});

  final List<Profile> profiles;

  factory ProfilesChangedEvent.fromJson(Map<String, dynamic> json) =>
      ProfilesChangedEvent(
        profiles: (json['profiles'] as List)
            .map((x) => Profile.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((x) => x.toJson()).toList(),
  };

  @override
  String get name => 'profiles_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is ProfilesChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfilesChangedEvent(${jsonEncode(toJson())})';
}

enum GreeterPromptEventKind {
  pin('pin'),
  info('info'),
  error('error'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const GreeterPromptEventKind(this.value);
  final String value;

  factory GreeterPromptEventKind.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

/// Greeter mode only: greetd asks something for the login in progress. kind pin: show the PIN pad (answer with greeter.pin). info and error carry greetd's message.
final class GreeterPromptEvent extends SessionEvent {
  const GreeterPromptEvent({
    required this.id,
    required this.kind,
    this.message,
  });

  /// A profile id, or 'guest'.
  final String id;
  final GreeterPromptEventKind kind;
  final String? message;

  factory GreeterPromptEvent.fromJson(Map<String, dynamic> json) =>
      GreeterPromptEvent(
        id: json['id'] as String,
        kind: GreeterPromptEventKind.fromJson(json['kind'] as String),
        message: json['message'] == null ? null : json['message'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.toJson(),
    'message': ?message,
  };

  @override
  String get name => 'greeter_prompt';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is GreeterPromptEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterPromptEvent(${jsonEncode(toJson())})';
}

/// Greeter mode only: the login in progress ended. ok: the profile's session starts and the greeter exits. Not ok: a wrong PIN, or locked_seconds while the backoff lock lasts (show 'Try again in N seconds'); greetd's session was cancelled, a new greeter.login starts over.
final class GreeterResultEvent extends SessionEvent {
  const GreeterResultEvent({
    required this.id,
    required this.ok,
    this.lockedSeconds,
  });

  /// A profile id, or 'guest'.
  final String id;
  final bool ok;
  final int? lockedSeconds;

  factory GreeterResultEvent.fromJson(Map<String, dynamic> json) =>
      GreeterResultEvent(
        id: json['id'] as String,
        ok: json['ok'] as bool,
        lockedSeconds: json['locked_seconds'] == null
            ? null
            : json['locked_seconds'] as int,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ok': ok,
    'locked_seconds': ?lockedSeconds,
  };

  @override
  String get name => 'greeter_result';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is GreeterResultEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterResultEvent(${jsonEncode(toJson())})';
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

class AppConflictData {
  const AppConflictData({required this.id, required this.conflictsWith});

  /// Catalog app id (state.json apps).
  final String id;

  /// Catalog app id (state.json apps).
  final String conflictsWith;

  factory AppConflictData.fromJson(Map<String, dynamic> json) =>
      AppConflictData(
        id: json['id'] as String,
        conflictsWith: json['conflicts_with'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'conflicts_with': conflictsWith};

  @override
  bool operator ==(Object other) =>
      other is AppConflictData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppConflictData(${jsonEncode(toJson())})';
}

class TermsRequiredData {
  const TermsRequiredData({required this.id, required this.version});

  /// Catalog app id (state.json apps).
  final String id;

  /// A vendor terms version from the catalog.
  final String version;

  factory TermsRequiredData.fromJson(Map<String, dynamic> json) =>
      TermsRequiredData(
        id: json['id'] as String,
        version: json['version'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is TermsRequiredData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'TermsRequiredData(${jsonEncode(toJson())})';
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

enum UnavailableDataService {
  networkmanager('networkmanager'),
  bluez('bluez'),
  audio('audio'),
  display('display'),
  logind('logind'),
  catalog('catalog'),
  polkit('polkit'),
  apps('apps'),
  greeter('greeter'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const UnavailableDataService(this.value);
  final String value;

  factory UnavailableDataService.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class UnavailableData {
  const UnavailableData({required this.service, required this.reason});

  final UnavailableDataService service;
  final String reason;

  factory UnavailableData.fromJson(Map<String, dynamic> json) =>
      UnavailableData(
        service: UnavailableDataService.fromJson(json['service'] as String),
        reason: json['reason'] as String,
      );

  Map<String, dynamic> toJson() => {
    'service': service.toJson(),
    'reason': reason,
  };

  @override
  bool operator ==(Object other) =>
      other is UnavailableData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'UnavailableData(${jsonEncode(toJson())})';
}

class DeviceFailedData {
  const DeviceFailedData({required this.reason});

  final String reason;

  factory DeviceFailedData.fromJson(Map<String, dynamic> json) =>
      DeviceFailedData(reason: json['reason'] as String);

  Map<String, dynamic> toJson() => {'reason': reason};

  @override
  bool operator ==(Object other) =>
      other is DeviceFailedData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DeviceFailedData(${jsonEncode(toJson())})';
}

class PowerInhibitedData {
  const PowerInhibitedData({this.who, this.why});

  final String? who;
  final String? why;

  factory PowerInhibitedData.fromJson(Map<String, dynamic> json) =>
      PowerInhibitedData(
        who: json['who'] == null ? null : json['who'] as String,
        why: json['why'] == null ? null : json['why'] as String,
      );

  Map<String, dynamic> toJson() => {'who': ?who, 'why': ?why};

  @override
  bool operator ==(Object other) =>
      other is PowerInhibitedData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PowerInhibitedData(${jsonEncode(toJson())})';
}

class ProfileLimitData {
  const ProfileLimitData({required this.max});

  final int max;

  factory ProfileLimitData.fromJson(Map<String, dynamic> json) =>
      ProfileLimitData(max: json['max'] as int);

  Map<String, dynamic> toJson() => {'max': max};

  @override
  bool operator ==(Object other) =>
      other is ProfileLimitData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfileLimitData(${jsonEncode(toJson())})';
}

enum PinRequiredDataPin {
  self('self'),
  admin('admin'),
  target('target'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const PinRequiredDataPin(this.value);
  final String value;

  factory PinRequiredDataPin.fromJson(String value) => values.firstWhere(
    (e) => e != unknown && e.value == value,
    orElse: () => unknown,
  );

  String toJson() => value;
}

class PinRequiredData {
  const PinRequiredData({required this.pin, this.retryAfterMs});

  final PinRequiredDataPin pin;
  final int? retryAfterMs;

  factory PinRequiredData.fromJson(Map<String, dynamic> json) =>
      PinRequiredData(
        pin: PinRequiredDataPin.fromJson(json['pin'] as String),
        retryAfterMs: json['retry_after_ms'] == null
            ? null
            : json['retry_after_ms'] as int,
      );

  Map<String, dynamic> toJson() => {
    'pin': pin.toJson(),
    'retry_after_ms': ?retryAfterMs,
  };

  @override
  bool operator ==(Object other) =>
      other is PinRequiredData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PinRequiredData(${jsonEncode(toJson())})';
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
  /// The on-screen keyboard is a separate client (hinteros-osk) whose window the daemon shows as a gamescope overlay; it never takes focus, so typed keys reach the focused app. While it is visible, InputPlumber is in intercept mode ALL and input_nav goes only to the connection whose hello client name is 'hinteros-osk' (not to the launcher). osk_visibility follows if the visibility changed. Showing it again does nothing. The user can also summon it with the controller (Guide + Y by default, or A on a focused text field in a keyboard-profile Firefox app), and B hides it whatever has focus (the keyboard client never receives back while visible).
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
  /// Login over SSH is the admin account with its password; the system repo configures sshd. polkit's default for this action is auth_admin. The service checks it with AllowUserInteraction (since 0.3): polkit asks the authentication agent registered for the calling process (the session daemon's, which shows the launcher a password prompt) and the call waits until the user answered (at most 5 minutes). Without an agent the call gets authentication_required; a cancelled or timed-out prompt also gives authentication_required, too many wrong passwords permission_denied (reason polkit). Returns job_id null if SSH already is in that state.
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

  /// Relayed to the system service's apps.install. Install Store apps (job). Action org.hinteros.system.apps.
  ///
  /// ids (1 to 8 catalog ids) must be in the running generation's catalog index (/run/current-system/sw/share/hinteros/catalog.json, never the caller's copy) with status available; their depends are added (transitively). Ids already installed are skipped; if nothing is left the result is job_id null. A conflict between a new app and an installed or requested one is app_conflict. Every new app with vendor terms needs accepted_terms[id] equal to the catalog's terms.version, else terms_required (the box records the acceptance: id, version, time, uid and profile, in the audit log and /var/lib/hinteros/terms-accepted.json). revision must be settings.get's (state_conflict otherwise). Free disk space must cover the new apps' sizeMiB plus the usual rebuild margin (insufficient_resources). The job writes state.json's apps from the service's typed state and runs the apply flow.
  Future<SystemAppsInstallResult> systemAppsInstall(
    SystemAppsInstallParams params,
  ) async => SystemAppsInstallResult.fromJson(
    await rpc('system.apps.install', params.toJson()),
  );

  /// Relayed to the system service's apps.remove. Remove installed Store apps (job), optionally with their data. Action org.hinteros.system.apps.
  ///
  /// ids (1 to 8) must be installed (not_found otherwise). An app that another installed app depends on cannot be removed alone (app_conflict, conflicts_with names the dependent). The job writes state.json without them and runs the apply flow. With delete_data, after a successful switch the job deletes each removed app's dataPaths (from the running generation's catalog) in every profile's home, as root without following symlinks (each path component is opened with O_NOFOLLOW relative to the home; nothing outside the home and no other filesystem is touched) and logs what it deleted. The launcher closes running apps first.
  Future<SystemAppsRemoveResult> systemAppsRemove(
    SystemAppsRemoveParams params,
  ) async => SystemAppsRemoveResult.fromJson(
    await rpc('system.apps.remove', params.toJson()),
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

  /// Wired and Wi-Fi state, the SSID joined and the IP address.
  ///
  /// Runtime settings (NetworkManager over D-Bus, as the session user). The same object comes with every network_changed event.
  Future<NetworkStatusResult> networkStatus([
    NetworkStatusParams params = const NetworkStatusParams(),
  ]) async => NetworkStatusResult.fromJson(
    await rpc('network.status', params.toJson()),
  );

  /// Ask for a fresh scan and return the networks it finds.
  ///
  /// Returns when the scan has finished (at most a few seconds); NetworkManager refuses scans right after another one, in which case the current list comes back. wifi_list_changed follows.
  Future<WifiScanResult> wifiScan([
    WifiScanParams params = const WifiScanParams(),
  ]) async => WifiScanResult.fromJson(await rpc('wifi.scan', params.toJson()));

  /// The networks NetworkManager knows now, strongest first (no scan).
  Future<WifiListResult> wifiList([
    WifiListParams params = const WifiListParams(),
  ]) async => WifiListResult.fromJson(await rpc('wifi.list', params.toJson()));

  /// Join a network, creating a system-wide connection for it.
  ///
  /// The password is needed unless the network is open or already known; it is stored in NetworkManager's system connection (readable by the session user, as accepted in the threat model) and is never logged by the daemon. Returns when the connection is up (or has failed, at most about 45 s). A failed new connection is removed again. 802.1X (enterprise) networks are refused with invalid_params.
  Future<WifiConnectResult> wifiConnect(WifiConnectParams params) async =>
      WifiConnectResult.fromJson(await rpc('wifi.connect', params.toJson()));

  /// Leave the current Wi-Fi network (it will not rejoin until connected again).
  Future<WifiDisconnectResult> wifiDisconnect([
    WifiDisconnectParams params = const WifiDisconnectParams(),
  ]) async => WifiDisconnectResult.fromJson(
    await rpc('wifi.disconnect', params.toJson()),
  );

  /// Delete the stored connections of a network.
  ///
  /// Disconnects if it is the network in use. Forgetting a network that is not stored is not an error.
  Future<WifiForgetResult> wifiForget(WifiForgetParams params) async =>
      WifiForgetResult.fromJson(await rpc('wifi.forget', params.toJson()));

  /// Switch Wi-Fi on or off.
  Future<WifiEnableResult> wifiEnable(WifiEnableParams params) async =>
      WifiEnableResult.fromJson(await rpc('wifi.enable', params.toJson()));

  /// Whether there is an adapter, whether it is on and whether it is scanning.
  ///
  /// Runtime settings (BlueZ over D-Bus, as the session user).
  Future<BluetoothStatusResult> bluetoothStatus([
    BluetoothStatusParams params = const BluetoothStatusParams(),
  ]) async => BluetoothStatusResult.fromJson(
    await rpc('bluetooth.status', params.toJson()),
  );

  /// Start or stop looking for devices.
  ///
  /// Discovery stops by itself after timeout_s (default 30, at most 300). Found devices arrive as bluetooth_changed. While scanning (and while a bluetooth.pair is running) the daemon's pairing agent answers pairing requests; at other times it refuses them.
  Future<BluetoothScanResult> bluetoothScan(BluetoothScanParams params) async =>
      BluetoothScanResult.fromJson(
        await rpc('bluetooth.scan', params.toJson()),
      );

  /// Known and discovered devices: paired ones first, then by name.
  ///
  /// Devices BlueZ has seen but that never reported a name are left out.
  Future<BluetoothDevicesResult> bluetoothDevices([
    BluetoothDevicesParams params = const BluetoothDevicesParams(),
  ]) async => BluetoothDevicesResult.fromJson(
    await rpc('bluetooth.devices', params.toJson()),
  );

  /// Pair with a device, trust it so that it reconnects by itself, and connect.
  ///
  /// The daemon registers a BlueZ agent (DisplayYesNo): devices without input or output (controllers, most headsets) pair without a prompt. If the device asks for a numeric comparison the daemon sends bluetooth_confirm {mode: confirm} and waits up to 30 s for bluetooth.confirm; devices that show a passkey to be typed on them get bluetooth_confirm {mode: display}. Legacy PIN requests are answered with 0000. Gives up after 45 s. Pairing an already paired device just trusts and connects it. Returns the device.
  Future<BluetoothPairResult> bluetoothPair(BluetoothPairParams params) async =>
      BluetoothPairResult.fromJson(
        await rpc('bluetooth.pair', params.toJson()),
      );

  /// Answer a bluetooth_confirm request (numeric comparison).
  Future<BluetoothConfirmResult> bluetoothConfirm(
    BluetoothConfirmParams params,
  ) async => BluetoothConfirmResult.fromJson(
    await rpc('bluetooth.confirm', params.toJson()),
  );

  /// Connect a paired device.
  Future<BluetoothConnectResult> bluetoothConnect(
    BluetoothConnectParams params,
  ) async => BluetoothConnectResult.fromJson(
    await rpc('bluetooth.connect', params.toJson()),
  );

  /// Disconnect a device (it stays paired).
  Future<BluetoothDisconnectResult> bluetoothDisconnect(
    BluetoothDisconnectParams params,
  ) async => BluetoothDisconnectResult.fromJson(
    await rpc('bluetooth.disconnect', params.toJson()),
  );

  /// Unpair a device and remove it.
  Future<BluetoothForgetResult> bluetoothForget(
    BluetoothForgetParams params,
  ) async => BluetoothForgetResult.fromJson(
    await rpc('bluetooth.forget', params.toJson()),
  );

  /// Audio outputs, which one is the default, and its volume and mute state.
  ///
  /// Runtime settings through PipeWire's PulseAudio interface (pactl). Every audio.* method returns this same state. An output is a sink; its id is the sink's name, stable across restarts.
  Future<AudioOutputsResult> audioOutputs([
    AudioOutputsParams params = const AudioOutputsParams(),
  ]) async =>
      AudioOutputsResult.fromJson(await rpc('audio.outputs', params.toJson()));

  /// Make an output the default: sound goes there.
  Future<AudioSetOutputResult> audioSetOutput(
    AudioSetOutputParams params,
  ) async => AudioSetOutputResult.fromJson(
    await rpc('audio.set_output', params.toJson()),
  );

  /// Set the default output's volume (0 to 100 percent, never above), or just report it.
  Future<AudioVolumeResult> audioVolume([
    AudioVolumeParams params = const AudioVolumeParams(),
  ]) async =>
      AudioVolumeResult.fromJson(await rpc('audio.volume', params.toJson()));

  /// Mute or unmute the default output.
  Future<AudioMuteResult> audioMute(AudioMuteParams params) async =>
      AudioMuteResult.fromJson(await rpc('audio.mute', params.toJson()));

  /// The display's modes (resolution and refresh rate), and the one in use.
  ///
  /// Under gamescope. The list is gamescope's own (the .modes file next to GAMESCOPE_PATCHED_EDID_FILE); the current mode comes from its Xwayland root window. can_set says whether display.set_mode can work (gamescope's mode save file is configured and the display is external). See the README for how modes are changed at runtime.
  Future<DisplayModesResult> displayModes([
    DisplayModesParams params = const DisplayModesParams(),
  ]) async =>
      DisplayModesResult.fromJson(await rpc('display.modes', params.toJson()));

  /// Change the display's resolution and refresh rate, until reverted or kept.
  ///
  /// The mode must be in display.modes. gamescope has no runtime mode request, so the daemon records the mode in gamescope's mode save file (GAMESCOPE_MODE_SAVE_FILE, keyed by the display's name) and nudges gamescope to pick the display's mode again (GAMESCOPE_DISPLAY_MODE_NUDGE). That also makes it the mode used at the next start. Returns once gamescope runs the new mode (about a second); if it does not switch, the old mode is restored and device_failed {reason: not_applied} is returned. The previous mode is remembered for display.revert. A launcher's keep-or-revert dialog calls display.keep when the user keeps it and display.revert when the time runs out.
  Future<DisplaySetModeResult> displaySetMode(
    DisplaySetModeParams params,
  ) async => DisplaySetModeResult.fromJson(
    await rpc('display.set_mode', params.toJson()),
  );

  /// Accept the mode set by display.set_mode: there is nothing to revert to any more.
  Future<DisplayKeepResult> displayKeep([
    DisplayKeepParams params = const DisplayKeepParams(),
  ]) async =>
      DisplayKeepResult.fromJson(await rpc('display.keep', params.toJson()));

  /// Go back to the mode from before the last display.set_mode (unless kept).
  Future<DisplayRevertResult> displayRevert([
    DisplayRevertParams params = const DisplayRevertParams(),
  ]) async => DisplayRevertResult.fromJson(
    await rpc('display.revert', params.toJson()),
  );

  /// What logind says about suspend, reboot and power off for this user.
  ///
  /// Power goes from the session daemon straight to logind (system-api.md, Power), authorised by the polkit rules for the active local session user.
  Future<PowerCapabilitiesResult> powerCapabilities([
    PowerCapabilitiesParams params = const PowerCapabilitiesParams(),
  ]) async => PowerCapabilitiesResult.fromJson(
    await rpc('power.capabilities', params.toJson()),
  );

  /// Suspend the machine.
  ///
  /// Returns once logind accepted the request. A system job (update, rebuild) holds a block inhibitor while it switches over: logind then refuses and the error is power_inhibited with its own text.
  Future<PowerSuspendResult> powerSuspend([
    PowerSuspendParams params = const PowerSuspendParams(),
  ]) async =>
      PowerSuspendResult.fromJson(await rpc('power.suspend', params.toJson()));

  /// Restart the machine.
  ///
  /// Same rules as power.suspend.
  Future<PowerRebootResult> powerReboot([
    PowerRebootParams params = const PowerRebootParams(),
  ]) async =>
      PowerRebootResult.fromJson(await rpc('power.reboot', params.toJson()));

  /// Shut the machine down.
  ///
  /// Same rules as power.suspend.
  Future<PowerPoweroffResult> powerPoweroff([
    PowerPoweroffParams params = const PowerPoweroffParams(),
  ]) async => PowerPoweroffResult.fromJson(
    await rpc('power.poweroff', params.toJson()),
  );

  /// Answer an authentication_requested prompt with the password. Only the launcher (hello client name hinteros-launcher) may call it.
  ///
  /// The daemon runs polkit's agent helper (polkit-agent-helper-1, or polkit's helper socket) for the request's first identity with this password; the helper checks it with PAM and tells polkit. ok true: polkit authorizes the action, and the call that needed it (for example system.ssh.set) goes on; authentication_finished {outcome: authorized} follows. ok false: wrong password; the prompt stays open while attempts_left &gt; 0 (3 tries), then the request fails (authentication_finished {outcome: failed}) and the waiting call gets permission_denied. The password is only passed to the helper: never logged, never stored, wiped from the daemon's memory after use. At most 511 bytes, no newline or NUL (invalid_params).
  Future<AuthRespondResult> authRespond(AuthRespondParams params) async =>
      AuthRespondResult.fromJson(await rpc('auth.respond', params.toJson()));

  /// Dismiss an authentication_requested prompt. Only the launcher may call it.
  ///
  /// polkit then refuses the action; the waiting call gets authentication_required. authentication_finished {outcome: cancelled} follows.
  Future<AuthCancelResult> authCancel(AuthCancelParams params) async =>
      AuthCancelResult.fromJson(await rpc('auth.cancel', params.toJson()));

  /// Restart the TV session: the compositor, the launcher and everything started in it, and the session daemon itself.
  ///
  /// For job_finished {session_restart_required: true} (and system_unavailable {reason: version_mismatch}). The daemon answers first, then asks logind to terminate the user's graphical session on seat0 (a greetd session: greetd's default_session starts it again at once, with the new generation's programs), then asks the user's systemd to restart the session daemon's own unit. Apps the daemon started end with it. Only a session started by greetd is ever terminated (never a desktop session). unavailable {service: logind}: no such session, or logind cannot be reached.
  Future<SessionRestartResult> sessionRestart([
    SessionRestartParams params = const SessionRestartParams(),
  ]) async => SessionRestartResult.fromJson(
    await rpc('session.restart', params.toJson()),
  );

  /// The App Store: the running generation's catalog, merged with what is installed.
  ///
  /// From the catalog index of the running generation (/run/current-system/sw/share/hinteros/catalog.json) and system.settings.get's installed apps. Lists available apps and installed ones whatever their catalog status (retired: still works, can be removed; removed: the next update takes it away), sorted by name; apps being installed or removed through this daemon have state installing/removing. Terms carry the full text's path on this box, so the launcher can show it offline before system.apps.install. more_after_update: the last update check found apps that the next update makes installable. unavailable {service: catalog}: no index, or an index version this daemon does not read.
  Future<StoreListResult> storeList([
    StoreListParams params = const StoreListParams(),
  ]) async =>
      StoreListResult.fromJson(await rpc('store.list', params.toJson()));

  /// The profile this session belongs to (the daemon's own user).
  ///
  /// setup_required: the account is a spare in first-boot mode (no admin profile exists); the launcher runs its first-boot wizard, which ends with system.profiles.setup_admin. pin_set false: a profile migrated from a single-user box without a PIN yet; the launcher asks for one before Home (system.profiles.set_pin without current_pin). screen_locked: the sleep lock is up right now (lock_state follows every change). The guest has guest true, no PIN and is never locked or admin.
  Future<ProfileCurrentResult> profileCurrent([
    ProfileCurrentParams params = const ProfileCurrentParams(),
  ]) async => ProfileCurrentResult.fromJson(
    await rpc('profile.current', params.toJson()),
  );

  /// Switch to another profile (or the guest): close everything running here, then end this session; the greeter takes over.
  ///
  /// The daemon calls system.profiles.switch {id} (writes the switch hint), brings the launcher to the front, sends SIGTERM to every running app (switch_progress closing_apps), asks Steam to exit (closing_steam). Nothing is force-closed silently: an app still running after switch.wait_s (10 s; Steam 15 s) produces switch_blocked and waits for session.switch_wait, session.switch_force_close or session.switch_cancel. Then it hides the keyboard, resets InputPlumber and ends its logind session (switch_progress ending). The reply comes when the switch has started, before anything closes. invalid_params {reason: same} for the session's own profile; not_found for an unknown profile; job_busy while a switch is already under way.
  Future<SessionSwitchProfileResult> sessionSwitchProfile(
    SessionSwitchProfileParams params,
  ) async => SessionSwitchProfileResult.fromJson(
    await rpc('session.switch_profile', params.toJson()),
  );

  /// The not-responding pop-up's Keep waiting: wait another switch.wait_s for the blocked app (switch_blocked again if it is still running).
  Future<SessionSwitchWaitResult> sessionSwitchWait([
    SessionSwitchWaitParams params = const SessionSwitchWaitParams(),
  ]) async => SessionSwitchWaitResult.fromJson(
    await rpc('session.switch_wait', params.toJson()),
  );

  /// The not-responding pop-up's Force close: SIGKILL the app's process group; the switch continues.
  Future<SessionSwitchForceCloseResult> sessionSwitchForceClose(
    SessionSwitchForceCloseParams params,
  ) async => SessionSwitchForceCloseResult.fromJson(
    await rpc('session.switch_force_close', params.toJson()),
  );

  /// The not-responding pop-up's Cancel switch: the profile stays (with whatever already closed gone); the hint is withdrawn.
  Future<SessionSwitchCancelResult> sessionSwitchCancel([
    SessionSwitchCancelParams params = const SessionSwitchCancelParams(),
  ]) async => SessionSwitchCancelResult.fromJson(
    await rpc('session.switch_cancel', params.toJson()),
  );

  /// The sleep lock screen's PIN: relays system.profiles.unlock {pin} (the profile's own PIN, same backoff). lock_state {locked: false} follows.
  ///
  /// A wrong PIN or an active backoff is pin_required {pin: self, retry_after_ms?}. Without a lock up: invalid_params {reason: not_locked}.
  Future<SessionUnlockResult> sessionUnlock(SessionUnlockParams params) async =>
      SessionUnlockResult.fromJson(
        await rpc('session.unlock', params.toJson()),
      );

  /// End guest session: guest only. Ends the session like a switch (to the picker) and wipes the guest now (home emptied, app link back to the starter set), as a reboot would.
  Future<SessionEndGuestResult> sessionEndGuest([
    SessionEndGuestParams params = const SessionEndGuestParams(),
  ]) async => SessionEndGuestResult.fromJson(
    await rpc('session.end_guest', params.toJson()),
  );

  /// Greeter mode only: the picker's view of the box (/run/hinteros/profiles-public.json).
  ///
  /// focus: the profile to focus first (the switch target, else the last used). appearance: the most accessible combination of the profiles' mirrored appearance. job: a profile job the picker should show (a removal that ended this session), else null. Only the hinteros-launcher connection may call greeter.* (not_authorized); a daemon not in greeter mode answers unavailable {service: greeter}.
  Future<GreeterListResult> greeterList([
    GreeterListParams params = const GreeterListParams(),
  ]) async =>
      GreeterListResult.fromJson(await rpc('greeter.list', params.toJson()));

  /// Greeter mode only: start entering a profile (greetd create_session).
  ///
  /// An unlocked profile, the guest or a holder of a one-time token (a just-created profile) starts at once: greeter_result {ok: true}, and the greeter session ends. A locked profile gets greeter_prompt {kind: pin}; answer with greeter.pin. Another login in progress is cancelled first.
  Future<GreeterLoginResult> greeterLogin(GreeterLoginParams params) async =>
      GreeterLoginResult.fromJson(await rpc('greeter.login', params.toJson()));

  /// Greeter mode only: the PIN for the greeter_prompt of the login in progress. The PIN goes to greetd and is wiped; greeter_result follows.
  Future<GreeterPinResult> greeterPin(GreeterPinParams params) async =>
      GreeterPinResult.fromJson(await rpc('greeter.pin', params.toJson()));

  /// Greeter mode only: give up the login in progress (greetd cancel_session). Nothing in progress is not an error.
  Future<GreeterCancelResult> greeterCancel([
    GreeterCancelParams params = const GreeterCancelParams(),
  ]) async => GreeterCancelResult.fromJson(
    await rpc('greeter.cancel', params.toJson()),
  );

  /// Greeter mode only: Add profile from the picker (profiles.create over greeter.sock, a job of about a minute). When the job succeeds, greeter.login {id} enters the new profile without its PIN (one-time token).
  Future<GreeterCreateResult> greeterCreate(GreeterCreateParams params) async =>
      GreeterCreateResult.fromJson(
        await rpc('greeter.create', params.toJson()),
      );

  /// Relayed to the system service's profiles.list. The profiles of this box, the guest and the limit. Read-only; starts a usage scan when the numbers are older than an hour.
  Future<SystemProfilesListResult> systemProfilesList([
    SystemProfilesListParams params = const SystemProfilesListParams(),
  ]) async => SystemProfilesListResult.fromJson(
    await rpc('system.profiles.list', params.toJson()),
  );

  /// Relayed to the system service's profiles.create. Add a profile (job profiles_create: a rebuild that adds the account, about a minute). Action org.hinteros.system.profiles.create.
  ///
  /// revision must be settings.get's (state_conflict otherwise). At 8 profiles: profile_limit. On success the profile has its metadata, PIN and lock flag, and its apps are the starter set; profiles_changed follows.
  Future<SystemProfilesCreateResult> systemProfilesCreate(
    SystemProfilesCreateParams params,
  ) async => SystemProfilesCreateResult.fromJson(
    await rpc('system.profiles.create', params.toJson()),
  );

  /// Relayed to the system service's profiles.setup_admin. First-boot mode: make the caller's spare account the admin profile (metadata, PIN, apps = the starter set). No job, no rebuild, no network.
  ///
  /// Only a spare caller, only while no admin profile exists (permission_denied otherwise).
  Future<SystemProfilesSetupAdminResult> systemProfilesSetupAdmin(
    SystemProfilesSetupAdminParams params,
  ) async => SystemProfilesSetupAdminResult.fromJson(
    await rpc('system.profiles.setup_admin', params.toJson()),
  );

  /// Relayed to the system service's profiles.rename. Own profile: no PIN. Another profile: the admin PIN (pin_required {pin: admin} without it or when wrong).
  Future<SystemProfilesRenameResult> systemProfilesRename(
    SystemProfilesRenameParams params,
  ) async => SystemProfilesRenameResult.fromJson(
    await rpc('system.profiles.rename', params.toJson()),
  );

  /// Relayed to the system service's profiles.set_appearance. Own profile's colour and the appearance mirrored for the picker.
  Future<SystemProfilesSetAppearanceResult> systemProfilesSetAppearance([
    SystemProfilesSetAppearanceParams params =
        const SystemProfilesSetAppearanceParams(),
  ]) async => SystemProfilesSetAppearanceResult.fromJson(
    await rpc('system.profiles.set_appearance', params.toJson()),
  );

  /// Relayed to the system service's profiles.set_pin. Change the own PIN with the current one (current_pin left out only while no PIN is set: the migration's first PIN).
  Future<SystemProfilesSetPinResult> systemProfilesSetPin(
    SystemProfilesSetPinParams params,
  ) async => SystemProfilesSetPinResult.fromJson(
    await rpc('system.profiles.set_pin', params.toJson()),
  );

  /// Relayed to the system service's profiles.set_locked. Own profile's lock flag, with the own PIN.
  Future<SystemProfilesSetLockedResult> systemProfilesSetLocked(
    SystemProfilesSetLockedParams params,
  ) async => SystemProfilesSetLockedResult.fromJson(
    await rpc('system.profiles.set_locked', params.toJson()),
  );

  /// Relayed to the system service's profiles.reset_pin. Give another profile a new PIN with the admin PIN; for the admin profile itself no admin_pin, but the admin account's password (polkit org.hinteros.system.profiles.recover, the agent prompt).
  Future<SystemProfilesResetPinResult> systemProfilesResetPin(
    SystemProfilesResetPinParams params,
  ) async => SystemProfilesResetPinResult.fromJson(
    await rpc('system.profiles.reset_pin', params.toJson()),
  );

  /// Relayed to the system service's profiles.remove. Remove a profile with everything in it (job profiles_remove). Own PIN for the own profile (the session then ends, as in a switch), the admin PIN for another. Never the admin profile (invalid_params {reason: admin}).
  Future<SystemProfilesRemoveResult> systemProfilesRemove(
    SystemProfilesRemoveParams params,
  ) async => SystemProfilesRemoveResult.fromJson(
    await rpc('system.profiles.remove', params.toJson()),
  );

  /// Relayed to the system service's guest.set. Guest on or off (job guest_set, a rebuild), with the admin PIN.
  Future<SystemGuestSetResult> systemGuestSet(
    SystemGuestSetParams params,
  ) async => SystemGuestSetResult.fromJson(
    await rpc('system.guest.set', params.toJson()),
  );

  /// Relayed to the system service's apps.list. The caller's own apps (its current app env's manifest). Read-only.
  ///
  /// revision stands for the caller's current app generation: pass it as system.apps.install and system.apps.remove's revision. needs_terms: apps that came with the starter set whose vendor terms this profile has not accepted yet (ask on first launch, system.apps.accept_terms). On a box not migrated to per-profile apps: unavailable {service: apps, reason: schema1} (then settings.get's revision and apps apply).
  Future<SystemAppsListResult> systemAppsList([
    SystemAppsListParams params = const SystemAppsListParams(),
  ]) async => SystemAppsListResult.fromJson(
    await rpc('system.apps.list', params.toJson()),
  );

  /// Relayed to the system service's apps.generations. The caller's app generations (current plus up to 3 earlier), newest first. Read-only.
  Future<SystemAppsGenerationsResult> systemAppsGenerations([
    SystemAppsGenerationsParams params = const SystemAppsGenerationsParams(),
  ]) async => SystemAppsGenerationsResult.fromJson(
    await rpc('system.apps.generations', params.toJson()),
  );

  /// Relayed to the system service's apps.rollback. Put the caller's apps back to an earlier generation (job apps_rollback; the box stage first if it needs a box feature that is off).
  Future<SystemAppsRollbackResult> systemAppsRollback(
    SystemAppsRollbackParams params,
  ) async => SystemAppsRollbackResult.fromJson(
    await rpc('system.apps.rollback', params.toJson()),
  );

  /// Relayed to the system service's apps.accept_terms. Accept the vendor terms of an app in needs_terms (first launch of a starter-set app). version must be the running catalog's terms version. Recorded by this profile.
  Future<SystemAppsAcceptTermsResult> systemAppsAcceptTerms(
    SystemAppsAcceptTermsParams params,
  ) async => SystemAppsAcceptTermsResult.fromJson(
    await rpc('system.apps.accept_terms', params.toJson()),
  );

  /// Relayed to the system service's starter_set.get. The apps every new profile and guest session starts with. Read-only.
  Future<SystemStarterSetGetResult> systemStarterSetGet([
    SystemStarterSetGetParams params = const SystemStarterSetGetParams(),
  ]) async => SystemStarterSetGetResult.fromJson(
    await rpc('system.starter_set.get', params.toJson()),
  );

  /// Relayed to the system service's starter_set.set. Change the starter set (job starter_set) with the admin PIN; ids must be among the admin profile's current apps (invalid_params {reason: not_in_admin_profile}). Affects only profiles and guest sessions created afterwards.
  Future<SystemStarterSetSetResult> systemStarterSetSet(
    SystemStarterSetSetParams params,
  ) async => SystemStarterSetSetResult.fromJson(
    await rpc('system.starter_set.set', params.toJson()),
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
    'network_changed' => NetworkChangedEvent.fromJson(params),
    'wifi_list_changed' => WifiListChangedEvent.fromJson(params),
    'bluetooth_changed' => BluetoothChangedEvent.fromJson(params),
    'bluetooth_confirm' => BluetoothConfirmEvent.fromJson(params),
    'audio_changed' => AudioChangedEvent.fromJson(params),
    'authentication_requested' => AuthenticationRequestedEvent.fromJson(params),
    'authentication_finished' => AuthenticationFinishedEvent.fromJson(params),
    'store_changed' => StoreChangedEvent.fromJson(params),
    'switch_progress' => SwitchProgressEvent.fromJson(params),
    'switch_blocked' => SwitchBlockedEvent.fromJson(params),
    'lock_state' => LockStateEvent.fromJson(params),
    'profiles_changed' => ProfilesChangedEvent.fromJson(params),
    'greeter_prompt' => GreeterPromptEvent.fromJson(params),
    'greeter_result' => GreeterResultEvent.fromJson(params),
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
