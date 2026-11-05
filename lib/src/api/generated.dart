// GENERATED CODE - DO NOT EDIT.
// Source: schema/session-api.json (session API 1.0).
// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)
//
// ignore_for_file: unnecessary_this, unnecessary_cast, prefer_null_aware_operators, prefer_if_null_operators

import 'dart:convert';

/// API version this client was generated for (sent in `hello`).
const apiVersion = '1.0';

/// Method names in the schema.
const apiMethodNames = <String>[
  'hello',
  'ping',
  'subscribe',
  'unsubscribe',
  'apps.list',
  'apps.set_permission',
  'apps.displays.get',
  'apps.displays.set',
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
  'system.channel.check',
  'system.channel.set',
  'system.base.set',
  'system.apps.install',
  'system.apps.remove',
  'system.apps.list',
  'system.apps.generations',
  'system.apps.rollback',
  'system.apps.accept_terms',
  'system.apps.clear_data',
  'system.profiles.list',
  'system.profiles.create',
  'system.profiles.setup_admin',
  'system.profiles.rename',
  'system.profiles.set_appearance',
  'system.profiles.set_pin',
  'system.profiles.set_locked',
  'system.profiles.reset_pin',
  'system.profiles.remove',
  'system.profiles.unlock',
  'system.guest.set',
  'system.display.save_mode',
  'system.audio.save_output',
  'system.starter_set.get',
  'system.starter_set.set',
  'system.storage.get',
  'system.storage.measure',
  'system.storage.tree',
  'system.storage.cleanup_system',
  'system.storage.cleanup_profiles',
  'system.cleanup.get',
  'system.cleanup.set',
  'system.time_zone.get',
  'system.time_zone.list',
  'system.time_zone.set',
  'system.services.list',
  'system.services.enable',
  'system.services.disable',
  'system.media.folders',
  'system.jellyfin.libraries.add',
  'system.jellyfin.libraries.remove',
  'system.jellyfin.users.reveal',
  'system.jellyfin.client_token',
  'system.plex.claim',
  'system.tailscale.login',
  'system.tailscale.logout',
  'system.cloudflare.set_token',
  'system.cloudflare.clear_token',
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
  'profile.current',
  'session.switch_profile',
  'session.switch_wait',
  'session.switch_force_close',
  'session.switch_cancel',
  'session.lock_state',
  'session.unlock',
  'session.end_guest',
  'greeter.list',
  'greeter.login',
  'greeter.pin',
  'greeter.cancel',
  'greeter.create',
  'session.restart',
  'store.list',
  'input.settings.get',
  'input.settings.set',
  'input.capture',
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
  'osk_changed',
  'time_zone_changed',
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
  'lock_changed',
  'greeter_prompt',
  'greeter_result',
  'profiles_changed',
  'input_captured',
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
  'unknown_permission': 2007,
  'permission_required': 2008,
  'no_app_display': 2009,
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
  'profile_limit': 3015,
  'pin_required': 3016,
  'terms_required': 3014,
  'system_unavailable': 3001,
  'unavailable': 4001,
  'device_failed': 4002,
  'wrong_password': 4003,
  'not_authorized': 4004,
  'power_inhibited': 4005,
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

  /// No such app (apps.launch: not in apps.list; apps.focus, apps.close: not running; apps.set_permission: not installed and not in the catalog).
  static const appNotFound = 2001;

  /// The app could not be started (spawn failed, or it has nothing to launch).
  static const appLaunchFailed = 2002;

  /// steam.focus: Steam has no windows that could be shown (not running, or no gamescope).
  static const steamNoWindows = 2003;

  /// keys.*: nothing can deliver the input (no virtual keyboard because /dev/uinput could not be opened, and, for text and some actions, no gamescope input method).
  static const keyboardUnavailable = 2004;

  /// osk.show: the on-screen keyboard is disabled in the daemon's config.
  static const oskUnavailable = 2005;

  /// apps.set_permission: the app does not declare this permission (or it is not enforced on this box).
  static const unknownPermission = 2007;

  /// apps.set_permission: a required permission cannot be denied.
  static const permissionRequired = 2008;

  /// apps.launch: every app display is in use (apps.displays.get). apps: the running apps that hold one; closing one frees it once it has exited (app_exited).
  static const noAppDisplay = 2009;

  /// Not allowed: the caller does not own seat0's active session (seat), polkit said no (polkit), the peer cannot be identified safely (peer: no SO_PEERPIDFD, or the process is gone), the caller's profile may not do it (profile), or jobs.cancel of a job another profile started without admin_pin (starter).
  static const permissionDenied = 3002;

  /// Only in job_finished.error and jobs.get: the job failed (or was cancelled) at stage; log_hint is the last relevant log line. Reason cancelled: the job was cancelled (jobs.cancel; any kind). Else reason says why a Server section job failed: unreachable (the service does not answer), not_ready (its setup is not done), refused (the service or tool said no; log_hint says why), timeout (nobody signed in in time), not_connected (the Cloudflare tunnel did not connect).
  static const jobFailed = 3003;

  /// Not enough memory or free disk space for a rebuild.
  static const insufficientResources = 3004;

  /// Another job runs (only one at a time), or the job is past the point of cancelling. data.job_id is that job; data can be absent when the running job cannot be read (a job a later version started, after a rollback).
  static const jobBusy = 3005;

  /// Too many mutating requests from this user (10 per minute, burst 3).
  static const rateLimited = 3006;

  /// Stale settings revision, update.apply's rev is not the last verified check result (update_rev), or channel.set's rev is not the last verified channel.check result for that channel (channel_rev).
  static const stateConflict = 3007;

  /// The update server cannot be reached (the 'home lab unreachable' screen).
  static const updateUnreachable = 3008;

  /// The channel tip is unsigned, signed by an unknown signer, does not descend from the locked revision (not_fast_forward), or does not descend from the newest verified tip this box saw on that channel branch (older_than_seen: an older signed release served again).
  static const updateVerificationFailed = 3009;

  /// Unknown generation or job; for runtime settings: a Wi-Fi network not in range, a Bluetooth device, an audio output or a display mode that does not exist, or a bluetooth.confirm with nothing waiting; system.apps.install: an id not in the running generation's catalog; system.apps.remove: an id that is not installed; auth.respond, auth.cancel: no such authentication request (or it is over).
  static const notFound = 3010;

  /// A downgrading base switch without acknowledge_downgrade: true. (channel.set takes the rev the owner confirmed after channel.check instead.)
  static const needsAcknowledgement = 3011;

  /// polkit would allow the action only after interactive authentication (auth_admin: the admin password), and it did not happen: no authentication agent is registered for the caller (no session daemon agent, or another client than the session daemon called), or the user cancelled the prompt or did not answer in time.
  static const authenticationRequired = 3012;

  /// apps.install: id conflicts with conflicts_with (installed or also requested). apps.remove: conflicts_with, which stays installed, depends on id.
  static const appConflict = 3013;

  /// profiles.create with the most profiles there may be (8; the guest does not count).
  static const profileLimit = 3015;

  /// A PIN is missing or wrong: the caller's own (self), the admin profile's (admin) or the profile being entered (target). retry_after_ms while the backoff lock is on (3 free failures, then 1 s doubling to 5 min, per profile). The admin profile's PIN has no wait but 10 wrong tries a boot (counted from every path, the greeter's included): after them every check of it, also with the right PIN, is refused with reboot_required: true until the box restarts (a new PIN, the admin password's profiles.reset_pin or root's reset-pin clears it).
  static const pinRequired = 3016;

  /// apps.install: app id has vendor terms and accepted_terms does not name their current version (show the terms, then retry with it).
  static const termsRequired = 3014;

  /// A relayed method could not reach the system service: it is down (reason down) or speaks another system API version (reason version_mismatch, e.g. after a switch until the session restarts). The session API keeps working.
  static const systemUnavailable = 3001;

  /// A runtime-settings method needs a service that is not there (not installed, not running, no permission to reach it, or no such hardware). Also store.list without a readable catalog index (service catalog), session.restart without a greetd session on seat0 (service logind), and auth.respond when polkit's agent helper cannot be run (service polkit). The relayed Server section methods: service jellyfin, plex, tailscale or cloudflare with reason off or not_ready (system.jellyfin.client_token also unreachable or sign_in_refused). System.base.set to a base that is not built: service base, reason not_built.
  static const unavailable = 4001;

  /// The service accepted the request but the operation failed (a connection or pairing attempt, a mode change). The message says why in words; reason is for code.
  static const deviceFailed = 4002;

  /// wifi.connect: the network refused the password.
  static const wrongPassword = 4003;

  /// The service's polkit policy refused the session user (not the active local session, or the system's polkit rules are missing); auth.respond and auth.cancel from a client other than the launcher.
  static const notAuthorized = 4004;

  /// logind refused suspend, reboot or power off because an inhibitor lock blocks it (a system job is switching over). The message is logind's.
  static const powerInhibited = 4005;
}

/// MAJOR.MINOR
typedef ApiVersion = String;

/// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
typedef AppId = String;

/// A running app's id, or null for the launcher.
typedef FocusTarget = String;

/// A sandbox permission: gamepad (controllers), mic (a sound socket that may record), downloads (the profile's Downloads folder), lan (the local network: other devices at home and this box's own services). More may come; show unknown names as they are.
typedef PermissionName = String;

/// A remappable controller button, by its Xbox label: a, b, x, y, lb, rb, lt, rt, view, menu (input.settings.get buttons). Guide and the directions are not remappable.
typedef ControllerButton = String;

/// A button pressed during input.capture: a ControllerButton or a direction (up, down, left, right).
typedef CapturedButton = String;

/// An action a button or key can do: the remappable NavActions (accept, back, context, secondary, menu, view, page_left, page_right, trigger_left, trigger_right); for keyboard-mode apps also up, down, left, right.
typedef ControllerAction = String;

/// A key with optional modifiers, modifiers first: 'enter', 'alt+left', 'ctrl+shift+t'; or 'none' (the action sends nothing).
typedef KeyComboName = String;

/// Action to button.
typedef ButtonMap = Map<String, Object?>;

/// Action to key of a keyboard-mode app.
typedef Keymap = Map<String, Object?>;

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

/// A profile id.
typedef ProfileId = String;

/// A display name: 1 to 32 characters, trimmed, no control or format characters.
typedef ProfileName = String;

/// 4 to 8 digits. Never logged.
typedef Pin = String;

/// Catalog app id (state.json apps).
typedef CatalogId = String;

/// A vendor terms version from the catalog.
typedef TermsVersion = String;

/// polkit's cookie for one authentication request.
typedef AuthCookie = String;

/// Generations to keep (the running, booted and current ones always stay).
typedef Keep = int;

/// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
typedef ZoneName = String;

/// Seconds east of UTC.
typedef OffsetSeconds = int;

/// A profile id or guest.
typedef StorageHomeId = String;

/// A Jellyfin item id.
typedef JellyfinId = String;

/// 1 to 64 characters after trimming, without control or format characters or /\:*?"&lt;&gt;|.
typedef LibraryName = String;

/// A folder below /srv/media, as its path relative to it (media.folders).
typedef FolderId = String;

/// A plex.tv/claim code. Never logged.
typedef PlexClaimCode = String;

/// A Cloudflare tunnel token (standard padded base64). Never logged.
typedef TunnelToken = String;

/// A Bluetooth address, upper case.
typedef BtAddress = String;

/// Opaque: a network in wifi.list, for wifi.connect and wifi.forget (one id per raw SSID and security; stable while they stay the same). Clients must not build or parse it.
typedef WifiNetworkId = String;

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
  oskChanged('osk_changed'),
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
  lockChanged('lock_changed'),
  profilesChanged('profiles_changed'),
  greeterPrompt('greeter_prompt'),
  greeterResult('greeter_result'),
  timeZoneChanged('time_zone_changed'),
  inputCaptured('input_captured');

  const EventName(this.value);
  final String value;

  factory EventName.fromJson(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () => throw FormatException('not a EventName', value),
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

  factory AppSource.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory ExitReason.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory NavAction.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory NavPhase.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory AppKind.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// The app came with the starter set and this profile has not accepted its vendor terms yet. Show the full text (file) on first launch; accept with system.apps.accept_terms {id, version}, decline leaves it installed and unlaunched (offer Remove). apps.launch refuses it with terms_required meanwhile.
class AppNeedsTerms {
  const AppNeedsTerms({
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

  /// Absolute path of the full text on this box.
  final String file;

  factory AppNeedsTerms.fromJson(Map<String, dynamic> json) => AppNeedsTerms(
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
      other is AppNeedsTerms &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppNeedsTerms(${jsonEncode(toJson())})';
}

/// A permission the app declares in the catalog, and this profile's choice. Only permissions this box enforces are listed.
class AppPermission {
  const AppPermission({
    required this.name,
    required this.required,
    required this.granted,
  });

  /// A sandbox permission: gamepad (controllers), mic (a sound socket that may record), downloads (the profile's Downloads folder), lan (the local network: other devices at home and this box's own services). More may come; show unknown names as they are.
  final String name;

  /// Cannot be switched off (no switch).
  final bool required;

  /// The app gets it the next time it starts. Always true when required.
  final bool granted;

  factory AppPermission.fromJson(Map<String, dynamic> json) => AppPermission(
    name: json['name'] as String,
    required: json['required'] as bool,
    granted: json['granted'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'required': required,
    'granted': granted,
  };

  @override
  bool operator ==(Object other) =>
      other is AppPermission &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppPermission(${jsonEncode(toJson())})';
}

class App {
  const App({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    this.needsTerms,
    required this.permissions,
  });

  /// Stable identifier, used by apps.launch.
  final String id;

  /// Display name.
  final String name;

  /// How the app is launched. Clients must treat unknown values like 'native'.
  final AppKind kind;

  /// Absolute path to a local icon image file (PNG, SVG, ICO, JPEG, WebP), if any. Resolved by the daemon at runtime: an explicit path from the config, else the icon the app's .desktop file names, found in the installed icon themes, else (web apps) a cached download of the site's own icon. It may appear later (see apps_changed) or change. Absent: draw a placeholder, e.g. the first letter of the name.
  final String? icon;

  /// The app came with the starter set and this profile has not accepted its vendor terms yet. Show the full text (file) on first launch; accept with system.apps.accept_terms {id, version}, decline leaves it installed and unlaunched (offer Remove). apps.launch refuses it with terms_required meanwhile.
  final AppNeedsTerms? needsTerms;

  /// What the app may use in its sandbox, in catalog order. Empty for Steam and for apps that run without a sandbox.
  final List<AppPermission> permissions;

  factory App.fromJson(Map<String, dynamic> json) => App(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: AppKind.fromJson(json['kind'] as String),
    icon: json['icon'] == null ? null : json['icon'] as String,
    needsTerms: json['needs_terms'] == null
        ? null
        : AppNeedsTerms.fromJson(
            (json['needs_terms'] as Map).cast<String, dynamic>(),
          ),
    permissions: (json['permissions'] as List)
        .map((x) => AppPermission.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.toJson(),
    'icon': ?icon,
    if (needsTerms != null) 'needs_terms': needsTerms!.toJson(),
    'permissions': permissions.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is App && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'App(${jsonEncode(toJson())})';
}

/// How many apps can run at once (apps.displays.get).
class AppDisplays {
  const AppDisplays({
    required this.count,
    required this.active,
    required this.min,
    required this.max,
  });

  /// The setting: what the next session starts with.
  final int count;

  /// What this session has; null: apps do not get displays of their own.
  final int? active;
  final int min;
  final int max;

  factory AppDisplays.fromJson(Map<String, dynamic> json) => AppDisplays(
    count: json['count'] as int,
    active: json['active'] == null ? null : json['active'] as int,
    min: json['min'] as int,
    max: json['max'] as int,
  );

  Map<String, dynamic> toJson() => {
    'count': count,
    'active': active,
    'min': min,
    'max': max,
  };

  @override
  bool operator ==(Object other) =>
      other is AppDisplays &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppDisplays(${jsonEncode(toJson())})';
}

/// The pointer of pointer apps. speed: percent of the configured pointer speed. swap_sticks: the left stick moves the pointer, the right stick gives the directions. left_click, right_click: physical buttons (before the general map), never the same.
class PointerSettings {
  const PointerSettings({
    this.speed,
    this.swapSticks,
    this.leftClick,
    this.rightClick,
  });

  final int? speed;
  final bool? swapSticks;

  /// A remappable controller button, by its Xbox label: a, b, x, y, lb, rb, lt, rt, view, menu (input.settings.get buttons). Guide and the directions are not remappable.
  final String? leftClick;

  /// A remappable controller button, by its Xbox label: a, b, x, y, lb, rb, lt, rt, view, menu (input.settings.get buttons). Guide and the directions are not remappable.
  final String? rightClick;

  factory PointerSettings.fromJson(Map<String, dynamic> json) =>
      PointerSettings(
        speed: json['speed'] == null ? null : json['speed'] as int,
        swapSticks: json['swap_sticks'] == null
            ? null
            : json['swap_sticks'] as bool,
        leftClick: json['left_click'] == null
            ? null
            : json['left_click'] as String,
        rightClick: json['right_click'] == null
            ? null
            : json['right_click'] as String,
      );

  Map<String, dynamic> toJson() => {
    'speed': ?speed,
    'swap_sticks': ?swapSticks,
    'left_click': ?leftClick,
    'right_click': ?rightClick,
  };

  @override
  bool operator ==(Object other) =>
      other is PointerSettings &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PointerSettings(${jsonEncode(toJson())})';
}

/// The stored controller settings of a profile: only what the user changed. general: over defaults.general, the result one button per action and one action per button. keyboard: the keys of every keyboard-mode app. apps: per app id, over everything else for that app.
class ControllerSettings {
  const ControllerSettings({
    this.general,
    this.keyboard,
    this.apps,
    this.pointer,
  });

  /// Action to button.
  final Map<String, Object?>? general;

  /// Action to key of a keyboard-mode app.
  final Map<String, Object?>? keyboard;
  final Map<String, Object?>? apps;

  /// The pointer of pointer apps. speed: percent of the configured pointer speed. swap_sticks: the left stick moves the pointer, the right stick gives the directions. left_click, right_click: physical buttons (before the general map), never the same.
  final PointerSettings? pointer;

  factory ControllerSettings.fromJson(Map<String, dynamic> json) =>
      ControllerSettings(
        general: json['general'] == null
            ? null
            : (json['general'] as Map).cast<String, Object?>(),
        keyboard: json['keyboard'] == null
            ? null
            : (json['keyboard'] as Map).cast<String, Object?>(),
        apps: json['apps'] == null
            ? null
            : (json['apps'] as Map).cast<String, Object?>(),
        pointer: json['pointer'] == null
            ? null
            : PointerSettings.fromJson(
                (json['pointer'] as Map).cast<String, dynamic>(),
              ),
      );

  Map<String, dynamic> toJson() => {
    'general': ?general,
    'keyboard': ?keyboard,
    'apps': ?apps,
    if (pointer != null) 'pointer': pointer!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is ControllerSettings &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ControllerSettings(${jsonEncode(toJson())})';
}

/// The built-in controller settings. pointer has all four fields.
class ControllerDefaults {
  const ControllerDefaults({
    required this.general,
    required this.keyboard,
    required this.pointer,
  });

  /// Action to button.
  final Map<String, Object?> general;

  /// Action to key of a keyboard-mode app.
  final Map<String, Object?> keyboard;

  /// The pointer of pointer apps. speed: percent of the configured pointer speed. swap_sticks: the left stick moves the pointer, the right stick gives the directions. left_click, right_click: physical buttons (before the general map), never the same.
  final PointerSettings pointer;

  factory ControllerDefaults.fromJson(Map<String, dynamic> json) =>
      ControllerDefaults(
        general: (json['general'] as Map).cast<String, Object?>(),
        keyboard: (json['keyboard'] as Map).cast<String, Object?>(),
        pointer: PointerSettings.fromJson(
          (json['pointer'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'general': general,
    'keyboard': keyboard,
    'pointer': pointer.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is ControllerDefaults &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ControllerDefaults(${jsonEncode(toJson())})';
}

/// A keyboard-mode app of the profile. keymap: only the app's own catalog or config entries (back key, keymap, address bar keys).
class KeyboardApp {
  const KeyboardApp({
    required this.id,
    required this.name,
    required this.keymap,
  });

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;
  final String name;

  /// Action to key of a keyboard-mode app.
  final Map<String, Object?> keymap;

  factory KeyboardApp.fromJson(Map<String, dynamic> json) => KeyboardApp(
    id: json['id'] as String,
    name: json['name'] as String,
    keymap: (json['keymap'] as Map).cast<String, Object?>(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'keymap': keymap};

  @override
  bool operator ==(Object other) =>
      other is KeyboardApp &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'KeyboardApp(${jsonEncode(toJson())})';
}

class InputSettingsSpeed {
  const InputSettingsSpeed({
    required this.min,
    required this.max,
    required this.step,
  });

  final int min;
  final int max;
  final int step;

  factory InputSettingsSpeed.fromJson(Map<String, dynamic> json) =>
      InputSettingsSpeed(
        min: json['min'] as int,
        max: json['max'] as int,
        step: json['step'] as int,
      );

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'step': step};

  @override
  bool operator ==(Object other) =>
      other is InputSettingsSpeed &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsSpeed(${jsonEncode(toJson())})';
}

/// The controller settings of this profile (input.settings.get).
class InputSettings {
  const InputSettings({
    required this.settings,
    required this.defaults,
    required this.buttons,
    required this.actions,
    required this.keyActions,
    required this.keys,
    required this.modifiers,
    required this.speed,
    required this.apps,
  });

  /// The stored controller settings of a profile: only what the user changed. general: over defaults.general, the result one button per action and one action per button. keyboard: the keys of every keyboard-mode app. apps: per app id, over everything else for that app.
  final ControllerSettings settings;

  /// The built-in controller settings. pointer has all four fields.
  final ControllerDefaults defaults;
  final List<String> buttons;

  /// The actions of general, in display order.
  final List<String> actions;

  /// The actions of a keymap, in display order.
  final List<String> keyActions;

  /// Key names a KeyComboName may end with.
  final List<String> keys;
  final List<String> modifiers;
  final InputSettingsSpeed speed;
  final List<KeyboardApp> apps;

  factory InputSettings.fromJson(Map<String, dynamic> json) => InputSettings(
    settings: ControllerSettings.fromJson(
      (json['settings'] as Map).cast<String, dynamic>(),
    ),
    defaults: ControllerDefaults.fromJson(
      (json['defaults'] as Map).cast<String, dynamic>(),
    ),
    buttons: (json['buttons'] as List).map((x) => x as String).toList(),
    actions: (json['actions'] as List).map((x) => x as String).toList(),
    keyActions: (json['key_actions'] as List).map((x) => x as String).toList(),
    keys: (json['keys'] as List).map((x) => x as String).toList(),
    modifiers: (json['modifiers'] as List).map((x) => x as String).toList(),
    speed: InputSettingsSpeed.fromJson(
      (json['speed'] as Map).cast<String, dynamic>(),
    ),
    apps: (json['apps'] as List)
        .map((x) => KeyboardApp.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'settings': settings.toJson(),
    'defaults': defaults.toJson(),
    'buttons': buttons,
    'actions': actions,
    'key_actions': keyActions,
    'keys': keys,
    'modifiers': modifiers,
    'speed': speed.toJson(),
    'apps': apps.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is InputSettings &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettings(${jsonEncode(toJson())})';
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

  factory InstallState.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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
    required this.steamAppId,
    required this.name,
    required this.installState,
    required this.sizeBytes,
    required this.lastPlayed,
    required this.artwork,
  });

  /// Steam app id. Launch with apps.launch {url: 'steam://rungameid/&lt;appid&gt;'}; it then runs as 'steam-&lt;appid&gt;'.
  final int steamAppId;

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
    steamAppId: json['steam_app_id'] as int,
    name: json['name'] as String,
    installState: InstallState.fromJson(json['install_state'] as String),
    sizeBytes: json['size_bytes'] as int,
    lastPlayed: json['last_played'] == null ? null : json['last_played'] as int,
    artwork: GameArtwork.fromJson(
      (json['artwork'] as Map).cast<String, dynamic>(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'steam_app_id': steamAppId,
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
  mute('mute');

  const Key(this.value);
  final String value;

  factory Key.fromJson(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () => throw FormatException('not a Key', value),
  );

  String toJson() => value;
}

/// A modifier held while a key is pressed.
enum Modifier {
  shift('shift'),
  ctrl('ctrl'),
  alt('alt'),
  meta('meta');

  const Modifier(this.value);
  final String value;

  factory Modifier.fromJson(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () => throw FormatException('not a Modifier', value),
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
  end('end');

  const KeyAction(this.value);
  final String value;

  factory KeyAction.fromJson(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () => throw FormatException('not a KeyAction', value),
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

  factory Channel.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

enum Base {
  stable('stable'),
  unstable('unstable'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Base(this.value);
  final String value;

  factory Base.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// unknown: a kind of a later version (a server sends it after a rollback, for a job a later version started).
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
  starterSet('starter_set'),
  profilesCreate('profiles_create'),
  profilesRemove('profiles_remove'),
  guestSet('guest_set'),
  guestEnd('guest_end'),
  storageMeasure('storage_measure'),
  cleanupSystem('cleanup_system'),
  cleanupProfiles('cleanup_profiles'),
  cleanupSet('cleanup_set'),
  channelCheck('channel_check'),
  servicesEnable('services_enable'),
  servicesDisable('services_disable'),
  jellyfinLibraryAdd('jellyfin_library_add'),
  jellyfinLibraryRemove('jellyfin_library_remove'),
  plexClaim('plex_claim'),
  tailscaleLogin('tailscale_login'),
  tailscaleLogout('tailscale_logout'),
  cloudflareSetToken('cloudflare_set_token'),
  cloudflareClearToken('cloudflare_clear_token'),
  appsClearData('apps_clear_data'),
  unknown('unknown');

  const JobKind(this.value);
  final String value;

  factory JobKind.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

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

  factory ProfileColor.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class ProfileUsage {
  const ProfileUsage({
    required this.totalBytes,
    required this.steamGamesBytes,
    required this.at,
  });

  final int totalBytes;
  final int steamGamesBytes;
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

enum SwitchStage {
  closingApps('closing_apps'),
  closingSteam('closing_steam'),
  ending('ending'),
  cancelled('cancelled'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const SwitchStage(this.value);
  final String value;

  factory SwitchStage.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class ProfileInfo {
  const ProfileInfo({
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
    required this.pinSet,
  });

  /// A profile id.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;
  final ProfileColor color;
  final String user;
  final bool admin;
  final bool locked;
  final int? lockedUntil;
  final bool active;
  final int? lastUsedAt;
  final ProfileUsage? usage;
  final bool pinSet;

  factory ProfileInfo.fromJson(Map<String, dynamic> json) => ProfileInfo(
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
    pinSet: json['pin_set'] as bool,
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
    'pin_set': pinSet,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfileInfo &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ProfileInfo(${jsonEncode(toJson())})';
}

/// A box feature: box-wide configuration an app needs, turned on when any owner has such an app.
enum BoxFeature {
  graphics32('graphics32'),
  steamDevices('steam-devices'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const BoxFeature(this.value);
  final String value;

  factory BoxFeature.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory AuthOutcome.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// leftover: not installed and removed from the catalog, its data still in this profile's home; only Clear data is offered.
enum StoreState {
  available('available'),
  installed('installed'),
  installing('installing'),
  removing('removing'),
  retired('retired'),
  unavailable('unavailable'),
  leftover('leftover'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const StoreState(this.value);
  final String value;

  factory StoreState.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory CatalogStatus.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// How an app reaches the box. download: from the binary cache. build: fetched from the vendor and prepared on this box during install (a few minutes, needs internet).
enum Delivery {
  download('download'),
  build('build'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Delivery(this.value);
  final String value;

  factory Delivery.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  /// The resolved icon on this box (absolute path to an image), when there is one: the installed app's desktop file and icon theme, or downloaded from icon_url / site_url and cached (https only; same cache, size limits and refresh as apps.list icons). Absent until resolved; store_changed is sent when it appears.
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

/// The upstream project's README (Markdown, at most 64 KiB), shown on the app's Store page. Absent when the app has none.
class StoreAppReadme {
  const StoreAppReadme({
    required this.url,
    required this.retrieved,
    required this.file,
  });

  /// The upstream file at the commit it was copied from.
  final String url;
  final String retrieved;

  /// Absolute path of the Markdown file on this box.
  final String file;

  factory StoreAppReadme.fromJson(Map<String, dynamic> json) => StoreAppReadme(
    url: json['url'] as String,
    retrieved: json['retrieved'] as String,
    file: json['file'] as String,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'retrieved': retrieved,
    'file': file,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreAppReadme &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreAppReadme(${jsonEncode(toJson())})';
}

/// A catalog entry (hinteros-catalog index version 4, fields in snake_case) with its state on this box. Removed entries (tombstones) only have id, name, status_reason and data_paths; the other fields are empty.
class StoreApp {
  const StoreApp({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.category,
    required this.homepage,
    required this.sizeMib,
    required this.icon,
    required this.boxFeatures,
    required this.depends,
    required this.conflicts,
    required this.onIso,
    required this.dataPaths,
    required this.terms,
    this.readme,
    required this.unfree,
    required this.delivery,
    required this.status,
    required this.statusReason,
    required this.state,
    required this.permissions,
    required this.hasData,
    required this.fullAccess,
  });

  /// Catalog app id (state.json apps).
  final String id;
  final String name;
  final String summary;
  final String description;

  /// games, video, music, photos, utilities; anything else: Other.
  final String category;
  final String homepage;

  /// Approximate download plus disk use.
  final int sizeMib;

  /// Where the real icon is (HinterOS ships no logos): the installed app's desktop file, the vendor's logo URL, discovery on site_url, or the kiosk profile's favicon.
  final StoreAppIcon icon;

  /// Box features the app needs.
  final List<String> boxFeatures;
  final List<String> depends;
  final List<String> conflicts;
  final bool onIso;

  /// Deleted in every profile's home by system.apps.remove {delete_data: true}.
  final List<String> dataPaths;

  /// The vendor's terms, shown in full before install; null if none.
  final StoreAppTerms? terms;

  /// The upstream project's README (Markdown, at most 64 KiB), shown on the app's Store page. Absent when the app has none.
  final StoreAppReadme? readme;

  /// Not free software: vendor terms are required.
  final bool unfree;

  /// How an app reaches the box. download: from the binary cache. build: fetched from the vendor and prepared on this box during install (a few minutes, needs internet).
  final Delivery delivery;
  final CatalogStatus status;
  final String? statusReason;

  /// leftover: not installed and removed from the catalog, its data still in this profile's home; only Clear data is offered.
  final StoreState state;

  /// What the app may use in its sandbox, in catalog order. Not installed: the stored choice for its install (default granted). Empty for Steam, apps without a sandbox and tombstones.
  final List<AppPermission> permissions;

  /// One of the app's dataPaths exists in this profile's home, installed or not (a remove can leave data behind): system.apps.clear_data has something to delete.
  final bool hasData;

  /// Runs without the app sandbox (Steam, apps with sandbox = false, or every app while the sandbox is off on this box): it can use everything the profile can. The install sheet warns. False for tombstones.
  final bool fullAccess;

  factory StoreApp.fromJson(Map<String, dynamic> json) => StoreApp(
    id: json['id'] as String,
    name: json['name'] as String,
    summary: json['summary'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    homepage: json['homepage'] as String,
    sizeMib: json['size_mib'] as int,
    icon: StoreAppIcon.fromJson((json['icon'] as Map).cast<String, dynamic>()),
    boxFeatures: (json['box_features'] as List)
        .map((x) => x as String)
        .toList(),
    depends: (json['depends'] as List).map((x) => x as String).toList(),
    conflicts: (json['conflicts'] as List).map((x) => x as String).toList(),
    onIso: json['on_iso'] as bool,
    dataPaths: (json['data_paths'] as List).map((x) => x as String).toList(),
    terms: json['terms'] == null
        ? null
        : StoreAppTerms.fromJson(
            (json['terms'] as Map).cast<String, dynamic>(),
          ),
    readme: json['readme'] == null
        ? null
        : StoreAppReadme.fromJson(
            (json['readme'] as Map).cast<String, dynamic>(),
          ),
    unfree: json['unfree'] as bool,
    delivery: Delivery.fromJson(json['delivery'] as String),
    status: CatalogStatus.fromJson(json['status'] as String),
    statusReason: json['status_reason'] == null
        ? null
        : json['status_reason'] as String,
    state: StoreState.fromJson(json['state'] as String),
    permissions: (json['permissions'] as List)
        .map((x) => AppPermission.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
    hasData: json['has_data'] as bool,
    fullAccess: json['full_access'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'summary': summary,
    'description': description,
    'category': category,
    'homepage': homepage,
    'size_mib': sizeMib,
    'icon': icon.toJson(),
    'box_features': boxFeatures,
    'depends': depends,
    'conflicts': conflicts,
    'on_iso': onIso,
    'data_paths': dataPaths,
    'terms': terms == null ? null : terms!.toJson(),
    if (readme != null) 'readme': readme!.toJson(),
    'unfree': unfree,
    'delivery': delivery.toJson(),
    'status': status.toJson(),
    'status_reason': statusReason,
    'state': state.toJson(),
    'permissions': permissions.map((x) => x.toJson()).toList(),
    'has_data': hasData,
    'full_access': fullAccess,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreApp && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StoreApp(${jsonEncode(toJson())})';
}

/// unknown: a state of a later version (a server may send it after a rollback, for a job a later version started).
enum JobState {
  running('running'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),
  unknown('unknown');

  const JobState(this.value);
  final String value;

  factory JobState.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// unknown: a stage of a later version (a server may send it after a rollback, in job_failed's stage; job_progress and jobs.get leave it out).
enum Stage {
  preparing('preparing'),
  fetching('fetching'),
  verifying('verifying'),
  box('box'),
  measuring('measuring'),
  evaluating('evaluating'),
  downloading('downloading'),
  building('building'),
  activating('activating'),
  cleaning('cleaning'),
  collecting('collecting'),
  apps('apps'),
  configuring('configuring'),
  signingIn('signing_in'),
  finishing('finishing'),
  unknown('unknown');

  const Stage(this.value);
  final String value;

  factory Stage.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory Severity.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

class GenerationProfile {
  const GenerationProfile({required this.id, required this.name});

  /// A profile id.
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
    this.readdsFeatures,
  });

  final int generation;

  /// Created (Unix time, seconds).
  final int date;

  /// System repo revision in its config snapshot, if any.
  final String? rev;
  final bool current;
  final bool booted;

  /// The accounts in that generation's state.json with their current names (null: no longer a profile); absent if its state.json cannot be read. The rollback screen lists the profiles a rollback would drop or bring back empty.
  final List<GenerationProfile>? profiles;

  /// Box features a rollback to this generation would turn back on: the profiles' apps need them and its state.json lacks them (the rollback job re-adds them in a box stage; the rollback screen says so). Absent when there are none or it is unknown (schema 1, unreadable state.json).
  final List<BoxFeature>? readdsFeatures;

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
    readdsFeatures: json['readds_features'] == null
        ? null
        : (json['readds_features'] as List)
              .map((x) => BoxFeature.fromJson(x as String))
              .toList(),
  );

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'date': date,
    'rev': rev,
    'current': current,
    'booted': booted,
    if (profiles != null) 'profiles': profiles!.map((x) => x.toJson()).toList(),
    if (readdsFeatures != null)
      'readds_features': readdsFeatures!.map((x) => x.toJson()).toList(),
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
    this.version,
    this.securitySummary,
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

  /// Apps the update makes installable (in the target's catalog, not available in the running one), by id; null if the target's catalog could not be read. The Store says 'More apps are available after the next update'.
  final List<CatalogApp>? newApps;

  /// Installed apps the update takes away (removed from, or missing in, the target's catalog); null if unknown. The update screen names them with the reason.
  final List<RemovedApp>? removedApps;

  /// (Session API 0.11; optional in system API 0.3.) The release rev carries: its release/version file if that matches ^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$ (at most 32 characters), otherwise the first 12 hex digits of rev. The launcher shows 'HinterOS &lt;version&gt;'. Absent from older services: show the short rev.
  final String? version;

  /// (Session API 0.11; optional in system API 0.3.) The newest Security-Summary: trailer among the new commits: one line (control characters removed), at most 120 characters; the security notice shows it under the severity. Null if none; absent from older services.
  final String? securitySummary;

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
        version: json['version'] == null ? null : json['version'] as String,
        securitySummary: json['security_summary'] == null
            ? null
            : json['security_summary'] as String,
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
    'version': ?version,
    'security_summary': ?securitySummary,
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

/// A channel_check job's result: the verified tip of the target channel.
class ChannelCheckResult {
  const ChannelCheckResult({
    required this.channel,
    required this.currentRev,
    required this.target,
    required this.older,
    required this.checkedAt,
  });

  /// The target channel.
  final Channel channel;

  /// The locked revision when the check ran.
  final String? currentRev;

  /// The target's verified tip; commits and security count the commits the locked revision does not have. new_apps and removed_apps are null (not read).
  final AvailableUpdate target;

  /// target.rev does not descend from the locked revision: the switch may go back to an older version.
  final bool older;
  final int checkedAt;

  factory ChannelCheckResult.fromJson(Map<String, dynamic> json) =>
      ChannelCheckResult(
        channel: Channel.fromJson(json['channel'] as String),
        currentRev: json['current_rev'] == null
            ? null
            : json['current_rev'] as String,
        target: AvailableUpdate.fromJson(
          (json['target'] as Map).cast<String, dynamic>(),
        ),
        older: json['older'] as bool,
        checkedAt: json['checked_at'] as int,
      );

  Map<String, dynamic> toJson() => {
    'channel': channel.toJson(),
    'current_rev': currentRev,
    'target': target.toJson(),
    'older': older,
    'checked_at': checkedAt,
  };

  @override
  bool operator ==(Object other) =>
      other is ChannelCheckResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ChannelCheckResult(${jsonEncode(toJson())})';
}

class AppliedResultAppsNotUpdatedItem {
  const AppliedResultAppsNotUpdatedItem({
    required this.owner,
    required this.ids,
    required this.reason,
  });

  /// A profile id, starter or guest.
  final String owner;
  final List<String> ids;
  final String reason;

  factory AppliedResultAppsNotUpdatedItem.fromJson(Map<String, dynamic> json) =>
      AppliedResultAppsNotUpdatedItem(
        owner: json['owner'] as String,
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        reason: json['reason'] as String,
      );

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'ids': ids,
    'reason': reason,
  };

  @override
  bool operator ==(Object other) =>
      other is AppliedResultAppsNotUpdatedItem &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'AppliedResultAppsNotUpdatedItem(${jsonEncode(toJson())})';
}

class AppliedResult {
  const AppliedResult({
    required this.generation,
    required this.rev,
    this.appsNotUpdated,
    this.featuresReadded,
  });

  final int? generation;
  final String? rev;

  /// App envs the final apps stage could not rebuild; each keeps its previous generation, which still works. Absent when there were none.
  final List<AppliedResultAppsNotUpdatedItem>? appsNotUpdated;

  /// Rollback jobs: box features turned back on after the rollback, because the profiles' apps need them and the restored generation lacked them. Absent when there were none.
  final List<BoxFeature>? featuresReadded;

  factory AppliedResult.fromJson(Map<String, dynamic> json) => AppliedResult(
    generation: json['generation'] == null ? null : json['generation'] as int,
    rev: json['rev'] == null ? null : json['rev'] as String,
    appsNotUpdated: json['apps_not_updated'] == null
        ? null
        : (json['apps_not_updated'] as List)
              .map(
                (x) => AppliedResultAppsNotUpdatedItem.fromJson(
                  (x as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
    featuresReadded: json['features_readded'] == null
        ? null
        : (json['features_readded'] as List)
              .map((x) => BoxFeature.fromJson(x as String))
              .toList(),
  );

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'rev': rev,
    if (appsNotUpdated != null)
      'apps_not_updated': appsNotUpdated!.map((x) => x.toJson()).toList(),
    if (featuresReadded != null)
      'features_readded': featuresReadded!.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is AppliedResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppliedResult(${jsonEncode(toJson())})';
}

class CleanupParams {
  const CleanupParams({required this.keep, this.adminPin});

  /// Generations to keep (the running, booted and current ones always stay).
  final int keep;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory CleanupParams.fromJson(Map<String, dynamic> json) => CleanupParams(
    keep: json['keep'] as int,
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
  );

  Map<String, dynamic> toJson() => {'keep': keep, 'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is CleanupParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'CleanupParams(${jsonEncode(toJson())})';
}

enum CleanupFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const CleanupFrequency(this.value);
  final String value;

  factory CleanupFrequency.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class TimeZoneInfo {
  const TimeZoneInfo({
    required this.zone,
    required this.offsetS,
    required this.standardOffsetS,
    required this.offsetValidUntil,
  });

  /// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
  final String zone;

  /// Seconds east of UTC.
  final int offsetS;

  /// Seconds east of UTC.
  final int standardOffsetS;

  /// Unix time of the next offset change; null when there is none.
  final int? offsetValidUntil;

  factory TimeZoneInfo.fromJson(Map<String, dynamic> json) => TimeZoneInfo(
    zone: json['zone'] as String,
    offsetS: json['offset_s'] as int,
    standardOffsetS: json['standard_offset_s'] as int,
    offsetValidUntil: json['offset_valid_until'] == null
        ? null
        : json['offset_valid_until'] as int,
  );

  Map<String, dynamic> toJson() => {
    'zone': zone,
    'offset_s': offsetS,
    'standard_offset_s': standardOffsetS,
    'offset_valid_until': offsetValidUntil,
  };

  @override
  bool operator ==(Object other) =>
      other is TimeZoneInfo &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'TimeZoneInfo(${jsonEncode(toJson())})';
}

class TimeZoneEntry {
  const TimeZoneEntry({
    required this.zone,
    required this.offsetS,
    required this.standardOffsetS,
  });

  /// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
  final String zone;

  /// Seconds east of UTC.
  final int offsetS;

  /// Seconds east of UTC.
  final int standardOffsetS;

  factory TimeZoneEntry.fromJson(Map<String, dynamic> json) => TimeZoneEntry(
    zone: json['zone'] as String,
    offsetS: json['offset_s'] as int,
    standardOffsetS: json['standard_offset_s'] as int,
  );

  Map<String, dynamic> toJson() => {
    'zone': zone,
    'offset_s': offsetS,
    'standard_offset_s': standardOffsetS,
  };

  @override
  bool operator ==(Object other) =>
      other is TimeZoneEntry &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'TimeZoneEntry(${jsonEncode(toJson())})';
}

class CleanupSettings {
  const CleanupSettings({
    required this.enabled,
    required this.frequency,
    required this.keepSystem,
    required this.keepProfiles,
  });

  final bool enabled;
  final CleanupFrequency frequency;

  /// Generations to keep (the running, booted and current ones always stay).
  final int keepSystem;

  /// Generations to keep (the running, booted and current ones always stay).
  final int keepProfiles;

  factory CleanupSettings.fromJson(Map<String, dynamic> json) =>
      CleanupSettings(
        enabled: json['enabled'] as bool,
        frequency: CleanupFrequency.fromJson(json['frequency'] as String),
        keepSystem: json['keep_system'] as int,
        keepProfiles: json['keep_profiles'] as int,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'frequency': frequency.toJson(),
    'keep_system': keepSystem,
    'keep_profiles': keepProfiles,
  };

  @override
  bool operator ==(Object other) =>
      other is CleanupSettings &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'CleanupSettings(${jsonEncode(toJson())})';
}

/// What a storage node stands for: disk (the top-level root), system, apps, profile (id), guest, media (/srv: its total, no children; only when not empty), other (what none of the others explains: other store paths, garbage, filesystem overhead), free; generation (what only that generation holds), common (what two or more generations of the parent hold), app_env (one owner's app envs outside the system; id: a profile id, starter or guest), shared (app store paths in two or more owners' envs, counted once); dir (name), files (loose files and folders too small or deep to show), steam (the installed games), steam_game (name, app_id).
enum NodeKind {
  disk('disk'),
  system('system'),
  apps('apps'),
  profile('profile'),
  guest('guest'),
  media('media'),
  other('other'),
  free('free'),
  generation('generation'),
  common('common'),
  appEnv('app_env'),
  shared('shared'),
  dir('dir'),
  files('files'),
  steam('steam'),
  steamGame('steam_game'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const NodeKind(this.value);
  final String value;

  factory NodeKind.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// A segment of the storage ring. Children always add up to bytes (the disk root: to the filesystem's size, unless the measured parts exceed it). Zero-byte nodes are left out except app_env, profile, guest and free. Order: generations newest first, other named nodes largest first, then common, shared, files, other, free. The launcher names kinds itself; name is data (a folder or a game).
class StorageNode {
  const StorageNode({
    required this.kind,
    required this.bytes,
    required this.children,
    this.id,
    this.name,
    this.generation,
    this.date,
    this.current,
    this.booted,
    this.appId,
  });

  /// What a storage node stands for: disk (the top-level root), system, apps, profile (id), guest, media (/srv: its total, no children; only when not empty), other (what none of the others explains: other store paths, garbage, filesystem overhead), free; generation (what only that generation holds), common (what two or more generations of the parent hold), app_env (one owner's app envs outside the system; id: a profile id, starter or guest), shared (app store paths in two or more owners' envs, counted once); dir (name), files (loose files and folders too small or deep to show), steam (the installed games), steam_game (name, app_id).
  final NodeKind kind;
  final int bytes;
  final List<StorageNode> children;

  /// profile: its id; app_env: a profile id, starter or guest; a profile tree's root.
  final String? id;

  /// dir: the folder's name; steam_game: the game's name.
  final String? name;
  final int? generation;

  /// generation: created (Unix seconds).
  final int? date;

  /// generation: the running system, or the owner's current apps.
  final bool? current;

  /// generation: the booted system.
  final bool? booted;

  /// steam_game: Steam's appid.
  final int? appId;

  factory StorageNode.fromJson(Map<String, dynamic> json) => StorageNode(
    kind: NodeKind.fromJson(json['kind'] as String),
    bytes: json['bytes'] as int,
    children: (json['children'] as List)
        .map((x) => StorageNode.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
    id: json['id'] == null ? null : json['id'] as String,
    name: json['name'] == null ? null : json['name'] as String,
    generation: json['generation'] == null ? null : json['generation'] as int,
    date: json['date'] == null ? null : json['date'] as int,
    current: json['current'] == null ? null : json['current'] as bool,
    booted: json['booted'] == null ? null : json['booted'] as bool,
    appId: json['app_id'] == null ? null : json['app_id'] as int,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.toJson(),
    'bytes': bytes,
    'children': children.map((x) => x.toJson()).toList(),
    'id': ?id,
    'name': ?name,
    'generation': ?generation,
    'date': ?date,
    'current': ?current,
    'booted': ?booted,
    'app_id': ?appId,
  };

  @override
  bool operator ==(Object other) =>
      other is StorageNode &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'StorageNode(${jsonEncode(toJson())})';
}

/// The Nix store's filesystem: used = total minus available blocks (f_bavail), free = available blocks, so used + free = total. Blocks reserved for root count as used.
class DiskUsage {
  const DiskUsage({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });

  final int totalBytes;
  final int usedBytes;
  final int freeBytes;

  factory DiskUsage.fromJson(Map<String, dynamic> json) => DiskUsage(
    totalBytes: json['total_bytes'] as int,
    usedBytes: json['used_bytes'] as int,
    freeBytes: json['free_bytes'] as int,
  );

  Map<String, dynamic> toJson() => {
    'total_bytes': totalBytes,
    'used_bytes': usedBytes,
    'free_bytes': freeBytes,
  };

  @override
  bool operator ==(Object other) =>
      other is DiskUsage && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'DiskUsage(${jsonEncode(toJson())})';
}

class CleanupEstimate {
  const CleanupEstimate({
    required this.keep,
    required this.generations,
    required this.bytes,
  });

  /// Generations to keep (the running, booted and current ones always stay).
  final int keep;

  /// Generations that clean-up would remove now.
  final int generations;

  /// About what it would free (garbage included).
  final int bytes;

  factory CleanupEstimate.fromJson(Map<String, dynamic> json) =>
      CleanupEstimate(
        keep: json['keep'] as int,
        generations: json['generations'] as int,
        bytes: json['bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
    'keep': keep,
    'generations': generations,
    'bytes': bytes,
  };

  @override
  bool operator ==(Object other) =>
      other is CleanupEstimate &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'CleanupEstimate(${jsonEncode(toJson())})';
}

class MeasurementEstimates {
  const MeasurementEstimates({required this.system, required this.profiles});

  /// keep 1 to 10, in order.
  final List<CleanupEstimate> system;

  /// keep 1 to 10, in order.
  final List<CleanupEstimate> profiles;

  factory MeasurementEstimates.fromJson(Map<String, dynamic> json) =>
      MeasurementEstimates(
        system: (json['system'] as List)
            .map(
              (x) =>
                  CleanupEstimate.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
        profiles: (json['profiles'] as List)
            .map(
              (x) =>
                  CleanupEstimate.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'system': system.map((x) => x.toJson()).toList(),
    'profiles': profiles.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is MeasurementEstimates &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'MeasurementEstimates(${jsonEncode(toJson())})';
}

class Measurement {
  const Measurement({
    required this.measuredAt,
    required this.disk,
    required this.root,
    required this.garbageBytes,
    required this.estimates,
  });

  /// When it finished (Unix seconds).
  final int measuredAt;

  /// The Nix store's filesystem: used = total minus available blocks (f_bavail), free = available blocks, so used + free = total. Blocks reserved for root count as used.
  final DiskUsage disk;

  /// A segment of the storage ring. Children always add up to bytes (the disk root: to the filesystem's size, unless the measured parts exceed it). Zero-byte nodes are left out except app_env, profile, guest and free. Order: generations newest first, other named nodes largest first, then common, shared, files, other, free. The launcher names kinds itself; name is data (a folder or a game).
  final StorageNode root;

  /// Store paths no GC root reaches now.
  final int garbageBytes;
  final MeasurementEstimates estimates;

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    measuredAt: json['measured_at'] as int,
    disk: DiskUsage.fromJson((json['disk'] as Map).cast<String, dynamic>()),
    root: StorageNode.fromJson((json['root'] as Map).cast<String, dynamic>()),
    garbageBytes: json['garbage_bytes'] as int,
    estimates: MeasurementEstimates.fromJson(
      (json['estimates'] as Map).cast<String, dynamic>(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'measured_at': measuredAt,
    'disk': disk.toJson(),
    'root': root.toJson(),
    'garbage_bytes': garbageBytes,
    'estimates': estimates.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is Measurement &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Measurement(${jsonEncode(toJson())})';
}

/// storage_measure jobs.
class MeasuredResult {
  const MeasuredResult({required this.measuredAt});

  final int measuredAt;

  factory MeasuredResult.fromJson(Map<String, dynamic> json) =>
      MeasuredResult(measuredAt: json['measured_at'] as int);

  Map<String, dynamic> toJson() => {'measured_at': measuredAt};

  @override
  bool operator ==(Object other) =>
      other is MeasuredResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'MeasuredResult(${jsonEncode(toJson())})';
}

/// cleanup_system and cleanup_profiles jobs. freed_bytes: free space after minus before on the store's filesystem (never negative).
class CleanedResult {
  const CleanedResult({
    required this.freedBytes,
    required this.generationsRemoved,
  });

  final int freedBytes;
  final int generationsRemoved;

  factory CleanedResult.fromJson(Map<String, dynamic> json) => CleanedResult(
    freedBytes: json['freed_bytes'] as int,
    generationsRemoved: json['generations_removed'] as int,
  );

  Map<String, dynamic> toJson() => {
    'freed_bytes': freedBytes,
    'generations_removed': generationsRemoved,
  };

  @override
  bool operator ==(Object other) =>
      other is CleanedResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'CleanedResult(${jsonEncode(toJson())})';
}

/// The most recently started derivation that is still building. name and version from the .drv name (nix's rule: the version starts at the first dash followed by a non-letter); phase is nix's build phase without the Phase suffix (unpack, patch, configure, build, check, install, fixup, ...), absent until nix reports one.
class Building {
  const Building({required this.name, this.version, this.phase, this.percent});

  final String name;
  final String? version;
  final String? phase;

  /// How far this derivation is, from the last standard stdenv phase it started (unpack 0, patch 5, updateAutotoolsGnuConfigScripts 8, configure 10, build 20, check 80, install 88, fixup 94, installCheck 98, dist 99; other phases keep the value); never goes back; below 100. Absent before the first standard phase and for builders without phases.
  final int? percent;

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    name: json['name'] as String,
    version: json['version'] == null ? null : json['version'] as String,
    phase: json['phase'] == null ? null : json['phase'] as String,
    percent: json['percent'] == null ? null : json['percent'] as int,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': ?version,
    'phase': ?phase,
    'percent': ?percent,
  };

  @override
  bool operator ==(Object other) =>
      other is Building && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'Building(${jsonEncode(toJson())})';
}

class ProgressDetail {
  const ProgressDetail({
    this.pathsDone,
    this.pathsTotal,
    this.bytesDone,
    this.bytesTotal,
    this.buildsDone,
    this.buildsTotal,
    this.buildsRunning,
    this.building,
    this.authUrl,
  });

  final int? pathsDone;
  final int? pathsTotal;
  final int? bytesDone;
  final int? bytesTotal;

  /// Derivations built so far in this nix run.
  final int? buildsDone;

  /// Derivations nix expects to build (may grow while nix discovers more).
  final int? buildsTotal;

  /// Derivations building at once.
  final int? buildsRunning;

  /// The most recently started derivation that is still building. name and version from the .drv name (nix's rule: the version starts at the first dash followed by a non-letter); phase is nix's build phase without the Phase suffix (unpack, patch, configure, build, check, install, fixup, ...), absent until nix reports one.
  final Building? building;

  /// Tailscale_login, stage signing_in: the URL to sign in at (https, printable ASCII; shown as a QR code).
  final String? authUrl;

  factory ProgressDetail.fromJson(Map<String, dynamic> json) => ProgressDetail(
    pathsDone: json['paths_done'] == null ? null : json['paths_done'] as int,
    pathsTotal: json['paths_total'] == null ? null : json['paths_total'] as int,
    bytesDone: json['bytes_done'] == null ? null : json['bytes_done'] as int,
    bytesTotal: json['bytes_total'] == null ? null : json['bytes_total'] as int,
    buildsDone: json['builds_done'] == null ? null : json['builds_done'] as int,
    buildsTotal: json['builds_total'] == null
        ? null
        : json['builds_total'] as int,
    buildsRunning: json['builds_running'] == null
        ? null
        : json['builds_running'] as int,
    building: json['building'] == null
        ? null
        : Building.fromJson((json['building'] as Map).cast<String, dynamic>()),
    authUrl: json['auth_url'] == null ? null : json['auth_url'] as String,
  );

  Map<String, dynamic> toJson() => {
    'paths_done': ?pathsDone,
    'paths_total': ?pathsTotal,
    'bytes_done': ?bytesDone,
    'bytes_total': ?bytesTotal,
    'builds_done': ?buildsDone,
    'builds_total': ?buildsTotal,
    'builds_running': ?buildsRunning,
    if (building != null) 'building': building!.toJson(),
    'auth_url': ?authUrl,
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

/// A profile a job is for, with its display name when the job started (the id when it has none).
class SubjectProfile {
  const SubjectProfile({required this.id, required this.name});

  final String id;
  final String name;

  factory SubjectProfile.fromJson(Map<String, dynamic> json) =>
      SubjectProfile(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is SubjectProfile &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SubjectProfile(${jsonEncode(toJson())})';
}

/// What a new Jellyfin library holds (mixed: movies and shows).
enum LibraryKind {
  movies('movies'),
  shows('shows'),
  music('music'),
  mixed('mixed');

  const LibraryKind(this.value);
  final String value;

  factory LibraryKind.fromJson(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () => throw FormatException('not a LibraryKind', value),
  );

  String toJson() => value;
}

/// The library a Jellyfin job is about (id: known for a removal, and for an addition once Jellyfin made it).
class SubjectLibrary {
  const SubjectLibrary({this.id, required this.name, this.kind, this.folder});

  /// A Jellyfin item id.
  final String? id;
  final String name;

  /// What a new Jellyfin library holds (mixed: movies and shows).
  final LibraryKind? kind;

  /// A folder below /srv/media, as its path relative to it (media.folders).
  final String? folder;

  factory SubjectLibrary.fromJson(Map<String, dynamic> json) => SubjectLibrary(
    id: json['id'] == null ? null : json['id'] as String,
    name: json['name'] as String,
    kind: json['kind'] == null
        ? null
        : LibraryKind.fromJson(json['kind'] as String),
    folder: json['folder'] == null ? null : json['folder'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'name': name,
    if (kind != null) 'kind': kind!.toJson(),
    'folder': ?folder,
  };

  @override
  bool operator ==(Object other) =>
      other is SubjectLibrary &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SubjectLibrary(${jsonEncode(toJson())})';
}

/// What a job is about. Every field optional; which ones each kind sets: README, What a job is about.
class JobSubject {
  const JobSubject({
    this.owner,
    this.profile,
    this.apps,
    this.deleteData,
    this.fromOwner,
    this.generation,
    this.fromGeneration,
    this.rev,
    this.version,
    this.channel,
    this.fromChannel,
    this.fromRev,
    this.fromVersion,
    this.base,
    this.fromBase,
    this.enabled,
    this.keep,
    this.frequency,
    this.keepSystem,
    this.keepProfiles,
    this.services,
    this.library,
  });

  /// Apps jobs: whose apps (a profile id, guest or starter).
  final String? owner;

  /// A profile a job is for, with its display name when the job started (the id when it has none).
  final SubjectProfile? profile;

  /// Apps installed (the new ones), removed or the new starter set; names from the running catalog.
  final List<CatalogApp>? apps;
  final bool? deleteData;

  /// An app env copied from another owner (starter).
  final String? fromOwner;

  /// Rollbacks: the target generation.
  final int? generation;
  final int? fromGeneration;

  /// A full git commit id.
  final String? rev;

  /// The target's release version (AvailableUpdate.version rule).
  final String? version;
  final Channel? channel;
  final Channel? fromChannel;

  /// A full git commit id.
  final String? fromRev;
  final String? fromVersion;
  final Base? base;
  final Base? fromBase;

  /// The new on/off value (ssh, guest_set, cleanup_set).
  final bool? enabled;

  /// Clean-ups: generations kept.
  final int? keep;
  final CleanupFrequency? frequency;
  final int? keepSystem;
  final int? keepProfiles;

  /// Services turned on or off (services_enable, services_disable).
  final List<CatalogApp>? services;

  /// The library a Jellyfin job is about (id: known for a removal, and for an addition once Jellyfin made it).
  final SubjectLibrary? library;

  factory JobSubject.fromJson(Map<String, dynamic> json) => JobSubject(
    owner: json['owner'] == null ? null : json['owner'] as String,
    profile: json['profile'] == null
        ? null
        : SubjectProfile.fromJson(
            (json['profile'] as Map).cast<String, dynamic>(),
          ),
    apps: json['apps'] == null
        ? null
        : (json['apps'] as List)
              .map(
                (x) => CatalogApp.fromJson((x as Map).cast<String, dynamic>()),
              )
              .toList(),
    deleteData: json['delete_data'] == null
        ? null
        : json['delete_data'] as bool,
    fromOwner: json['from_owner'] == null ? null : json['from_owner'] as String,
    generation: json['generation'] == null ? null : json['generation'] as int,
    fromGeneration: json['from_generation'] == null
        ? null
        : json['from_generation'] as int,
    rev: json['rev'] == null ? null : json['rev'] as String,
    version: json['version'] == null ? null : json['version'] as String,
    channel: json['channel'] == null
        ? null
        : Channel.fromJson(json['channel'] as String),
    fromChannel: json['from_channel'] == null
        ? null
        : Channel.fromJson(json['from_channel'] as String),
    fromRev: json['from_rev'] == null ? null : json['from_rev'] as String,
    fromVersion: json['from_version'] == null
        ? null
        : json['from_version'] as String,
    base: json['base'] == null ? null : Base.fromJson(json['base'] as String),
    fromBase: json['from_base'] == null
        ? null
        : Base.fromJson(json['from_base'] as String),
    enabled: json['enabled'] == null ? null : json['enabled'] as bool,
    keep: json['keep'] == null ? null : json['keep'] as int,
    frequency: json['frequency'] == null
        ? null
        : CleanupFrequency.fromJson(json['frequency'] as String),
    keepSystem: json['keep_system'] == null ? null : json['keep_system'] as int,
    keepProfiles: json['keep_profiles'] == null
        ? null
        : json['keep_profiles'] as int,
    services: json['services'] == null
        ? null
        : (json['services'] as List)
              .map(
                (x) => CatalogApp.fromJson((x as Map).cast<String, dynamic>()),
              )
              .toList(),
    library: json['library'] == null
        ? null
        : SubjectLibrary.fromJson(
            (json['library'] as Map).cast<String, dynamic>(),
          ),
  );

  Map<String, dynamic> toJson() => {
    'owner': ?owner,
    if (profile != null) 'profile': profile!.toJson(),
    if (apps != null) 'apps': apps!.map((x) => x.toJson()).toList(),
    'delete_data': ?deleteData,
    'from_owner': ?fromOwner,
    'generation': ?generation,
    'from_generation': ?fromGeneration,
    'rev': ?rev,
    'version': ?version,
    if (channel != null) 'channel': channel!.toJson(),
    if (fromChannel != null) 'from_channel': fromChannel!.toJson(),
    'from_rev': ?fromRev,
    'from_version': ?fromVersion,
    if (base != null) 'base': base!.toJson(),
    if (fromBase != null) 'from_base': fromBase!.toJson(),
    'enabled': ?enabled,
    'keep': ?keep,
    if (frequency != null) 'frequency': frequency!.toJson(),
    'keep_system': ?keepSystem,
    'keep_profiles': ?keepProfiles,
    if (services != null) 'services': services!.map((x) => x.toJson()).toList(),
    if (library != null) 'library': library!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is JobSubject && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JobSubject(${jsonEncode(toJson())})';
}

/// A service's setup flow in the Server section (catalog setup).
enum Setup {
  jellyfinServer('jellyfin-server'),
  plexMediaServer('plex-media-server'),
  tailscale('tailscale'),
  cloudflareTunnel('cloudflare-tunnel'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const Setup(this.value);
  final String value;

  factory Setup.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// Systemd's ActiveState of a service's unit (unknown: a value this daemon does not know).
enum UnitState {
  active('active'),
  reloading('reloading'),
  inactive('inactive'),
  failed('failed'),
  activating('activating'),
  deactivating('deactivating'),
  maintenance('maintenance'),
  refreshing('refreshing'),
  unknown('unknown');

  const UnitState(this.value);
  final String value;

  factory UnitState.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// A service's vendor terms; file is the absolute path of the text on the box.
class ServiceTerms {
  const ServiceTerms({
    required this.title,
    required this.version,
    required this.url,
    required this.file,
  });

  final String title;

  /// A vendor terms version from the catalog.
  final String version;
  final String url;
  final String file;

  factory ServiceTerms.fromJson(Map<String, dynamic> json) => ServiceTerms(
    title: json['title'] as String,
    version: json['version'] as String,
    url: json['url'] as String,
    file: json['file'] as String,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'version': version,
    'url': url,
    'file': file,
  };

  @override
  bool operator ==(Object other) =>
      other is ServiceTerms &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ServiceTerms(${jsonEncode(toJson())})';
}

/// Where a service's real icon is (HinterOS ships no logos): the catalog entry's desktopId, iconUrl (with sha256: a download with another SHA-256 is not kept) or siteUrl (discovery on the site).
class ServiceIcon {
  const ServiceIcon({
    this.desktopId,
    this.siteUrl,
    this.iconUrl,
    this.sha256,
    required this.firefoxProfile,
    this.path,
  });

  final String? desktopId;
  final String? siteUrl;
  final String? iconUrl;
  final String? sha256;
  final bool firefoxProfile;

  /// The resolved icon on this box (absolute path to an image). Only the session daemon sets it, in system.services.list: the same resolution and cache as store.list's icon.path. Absent until resolved; store_changed is sent when it appears.
  final String? path;

  factory ServiceIcon.fromJson(Map<String, dynamic> json) => ServiceIcon(
    desktopId: json['desktop_id'] == null ? null : json['desktop_id'] as String,
    siteUrl: json['site_url'] == null ? null : json['site_url'] as String,
    iconUrl: json['icon_url'] == null ? null : json['icon_url'] as String,
    sha256: json['sha256'] == null ? null : json['sha256'] as String,
    firefoxProfile: json['firefox_profile'] as bool,
    path: json['path'] == null ? null : json['path'] as String,
  );

  Map<String, dynamic> toJson() => {
    'desktop_id': ?desktopId,
    'site_url': ?siteUrl,
    'icon_url': ?iconUrl,
    'sha256': ?sha256,
    'firefox_profile': firefoxProfile,
    'path': ?path,
  };

  @override
  bool operator ==(Object other) =>
      other is ServiceIcon &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ServiceIcon(${jsonEncode(toJson())})';
}

/// One service of the Server section.
class ServiceInfo {
  const ServiceInfo({
    required this.id,
    required this.name,
    required this.available,
    required this.enabled,
    required this.status,
    required this.setup,
    required this.terms,
    required this.detail,
    this.icon,
    required this.hasData,
  });

  /// Catalog app id (state.json apps).
  final String id;
  final String name;

  /// The catalog offers it (an enabled service the catalog dropped is listed with false).
  final bool available;

  /// In state.json services.
  final bool enabled;
  final UnitState? status;
  final Setup? setup;
  final ServiceTerms? terms;

  /// The detail of the setup flow named by setup; null when off or without setup.
  final Object? detail;

  /// The catalog entry's icon, as store.list shows an app's; absent when the catalog no longer has the entry.
  final ServiceIcon? icon;

  /// services.disable with delete_data has something to delete (the entry has stateDirs; Jellyfin always).
  final bool hasData;

  factory ServiceInfo.fromJson(Map<String, dynamic> json) => ServiceInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    available: json['available'] as bool,
    enabled: json['enabled'] as bool,
    status: json['status'] == null
        ? null
        : UnitState.fromJson(json['status'] as String),
    setup: json['setup'] == null
        ? null
        : Setup.fromJson(json['setup'] as String),
    terms: json['terms'] == null
        ? null
        : ServiceTerms.fromJson((json['terms'] as Map).cast<String, dynamic>()),
    detail: json['detail'] == null ? null : json['detail'],
    icon: json['icon'] == null
        ? null
        : ServiceIcon.fromJson((json['icon'] as Map).cast<String, dynamic>()),
    hasData: json['has_data'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'available': available,
    'enabled': enabled,
    'status': status == null ? null : status!.toJson(),
    'setup': setup == null ? null : setup!.toJson(),
    'terms': terms == null ? null : terms!.toJson(),
    'detail': detail,
    if (icon != null) 'icon': icon!.toJson(),
    'has_data': hasData,
  };

  @override
  bool operator ==(Object other) =>
      other is ServiceInfo &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ServiceInfo(${jsonEncode(toJson())})';
}

/// What a Jellyfin library holds; other: a type made in Jellyfin's dashboard (books, photos, music videos, ...).
enum LibraryKindShown {
  movies('movies'),
  shows('shows'),
  music('music'),
  mixed('mixed'),
  other('other');

  const LibraryKindShown(this.value);
  final String value;

  factory LibraryKindShown.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => other);

  String toJson() => value;
}

class JellyfinLibrary {
  const JellyfinLibrary({
    required this.id,
    required this.name,
    required this.kind,
    required this.folder,
  });

  /// A Jellyfin item id.
  final String id;
  final String name;

  /// What a Jellyfin library holds; other: a type made in Jellyfin's dashboard (books, photos, music videos, ...).
  final LibraryKindShown kind;

  /// The media.folders id of its first folder; null when that is not in /srv/media.
  final String? folder;

  factory JellyfinLibrary.fromJson(Map<String, dynamic> json) =>
      JellyfinLibrary(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: LibraryKindShown.fromJson(json['kind'] as String),
        folder: json['folder'] == null ? null : json['folder'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.toJson(),
    'folder': folder,
  };

  @override
  bool operator ==(Object other) =>
      other is JellyfinLibrary &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JellyfinLibrary(${jsonEncode(toJson())})';
}

class JellyfinDetailUsersItem {
  const JellyfinDetailUsersItem({
    required this.profileId,
    required this.jellyfinUser,
  });

  /// A profile id.
  final String profileId;
  final String jellyfinUser;

  factory JellyfinDetailUsersItem.fromJson(Map<String, dynamic> json) =>
      JellyfinDetailUsersItem(
        profileId: json['profile_id'] as String,
        jellyfinUser: json['jellyfin_user'] as String,
      );

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'jellyfin_user': jellyfinUser,
  };

  @override
  bool operator ==(Object other) =>
      other is JellyfinDetailUsersItem &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JellyfinDetailUsersItem(${jsonEncode(toJson())})';
}

class JellyfinDetail {
  const JellyfinDetail({
    required this.setupDone,
    required this.url,
    required this.libraries,
    required this.users,
  });

  /// HinterOS made Jellyfin's first-run setup (admin user, API key).
  final bool setupDone;

  /// http://&lt;local IP&gt;:&lt;port&gt;, for other devices; null without a local network address.
  final String? url;
  final List<JellyfinLibrary> libraries;

  /// Each profile's Jellyfin user name (passwords: jellyfin.users.reveal).
  final List<JellyfinDetailUsersItem> users;

  factory JellyfinDetail.fromJson(Map<String, dynamic> json) => JellyfinDetail(
    setupDone: json['setup_done'] as bool,
    url: json['url'] == null ? null : json['url'] as String,
    libraries: (json['libraries'] as List)
        .map(
          (x) => JellyfinLibrary.fromJson((x as Map).cast<String, dynamic>()),
        )
        .toList(),
    users: (json['users'] as List)
        .map(
          (x) => JellyfinDetailUsersItem.fromJson(
            (x as Map).cast<String, dynamic>(),
          ),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'setup_done': setupDone,
    'url': url,
    'libraries': libraries.map((x) => x.toJson()).toList(),
    'users': users.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is JellyfinDetail &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JellyfinDetail(${jsonEncode(toJson())})';
}

class MediaFolder {
  const MediaFolder({
    required this.id,
    required this.name,
    required this.hasChildren,
  });

  /// A folder below /srv/media, as its path relative to it (media.folders).
  final String id;
  final String name;
  final bool hasChildren;

  factory MediaFolder.fromJson(Map<String, dynamic> json) => MediaFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    hasChildren: json['has_children'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'has_children': hasChildren,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaFolder &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'MediaFolder(${jsonEncode(toJson())})';
}

class JellyfinAccount {
  const JellyfinAccount({required this.name, required this.password});

  final String name;
  final String password;

  factory JellyfinAccount.fromJson(Map<String, dynamic> json) =>
      JellyfinAccount(
        name: json['name'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'password': password};

  @override
  bool operator ==(Object other) =>
      other is JellyfinAccount &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JellyfinAccount(${jsonEncode(toJson())})';
}

class JellyfinProfileAccount {
  const JellyfinProfileAccount({
    required this.profileId,
    required this.profileName,
    required this.name,
    required this.password,
  });

  /// A profile id.
  final String profileId;
  final String profileName;

  /// The Jellyfin user name.
  final String name;
  final String password;

  factory JellyfinProfileAccount.fromJson(Map<String, dynamic> json) =>
      JellyfinProfileAccount(
        profileId: json['profile_id'] as String,
        profileName: json['profile_name'] as String,
        name: json['name'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'profile_name': profileName,
    'name': name,
    'password': password,
  };

  @override
  bool operator ==(Object other) =>
      other is JellyfinProfileAccount &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'JellyfinProfileAccount(${jsonEncode(toJson())})';
}

class PlexDetail {
  const PlexDetail({
    required this.claimed,
    required this.serverName,
    required this.url,
  });

  /// Linked to a Plex account.
  final bool claimed;
  final String? serverName;
  final String? url;

  factory PlexDetail.fromJson(Map<String, dynamic> json) => PlexDetail(
    claimed: json['claimed'] as bool,
    serverName: json['server_name'] == null
        ? null
        : json['server_name'] as String,
    url: json['url'] == null ? null : json['url'] as String,
  );

  Map<String, dynamic> toJson() => {
    'claimed': claimed,
    'server_name': serverName,
    'url': url,
  };

  @override
  bool operator ==(Object other) =>
      other is PlexDetail && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'PlexDetail(${jsonEncode(toJson())})';
}

/// Needs_login: not signed in; needs_approval: the tailnet's admin must approve the device; unavailable: tailscaled does not answer.
enum TailscaleState {
  needsLogin('needs_login'),
  needsApproval('needs_approval'),
  starting('starting'),
  running('running'),
  stopped('stopped'),
  unavailable('unavailable'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const TailscaleState(this.value);
  final String value;

  factory TailscaleState.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class TailscaleDetail {
  const TailscaleDetail({
    required this.state,
    required this.name,
    required this.ip4,
    required this.dnsName,
    required this.tailnet,
    required this.keyExpiry,
  });

  /// Needs_login: not signed in; needs_approval: the tailnet's admin must approve the device; unavailable: tailscaled does not answer.
  final TailscaleState state;
  final String? name;
  final String? ip4;

  /// The MagicDNS name, without the trailing dot.
  final String? dnsName;
  final String? tailnet;

  /// Unix seconds; null: the key never expires, or unknown.
  final int? keyExpiry;

  factory TailscaleDetail.fromJson(Map<String, dynamic> json) =>
      TailscaleDetail(
        state: TailscaleState.fromJson(json['state'] as String),
        name: json['name'] == null ? null : json['name'] as String,
        ip4: json['ip4'] == null ? null : json['ip4'] as String,
        dnsName: json['dns_name'] == null ? null : json['dns_name'] as String,
        tailnet: json['tailnet'] == null ? null : json['tailnet'] as String,
        keyExpiry: json['key_expiry'] == null
            ? null
            : json['key_expiry'] as int,
      );

  Map<String, dynamic> toJson() => {
    'state': state.toJson(),
    'name': name,
    'ip4': ip4,
    'dns_name': dnsName,
    'tailnet': tailnet,
    'key_expiry': keyExpiry,
  };

  @override
  bool operator ==(Object other) =>
      other is TailscaleDetail &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'TailscaleDetail(${jsonEncode(toJson())})';
}

class CloudflareDetail {
  const CloudflareDetail({
    required this.tokenSet,
    required this.connected,
    required this.localIp,
  });

  final bool tokenSet;

  /// cloudflared reports a connection to Cloudflare (its /ready).
  final bool connected;

  /// The box's IPv4 address on its local network (the subnet of the default route), for the tunnel's private-network route.
  final String? localIp;

  factory CloudflareDetail.fromJson(Map<String, dynamic> json) =>
      CloudflareDetail(
        tokenSet: json['token_set'] as bool,
        connected: json['connected'] as bool,
        localIp: json['local_ip'] == null ? null : json['local_ip'] as String,
      );

  Map<String, dynamic> toJson() => {
    'token_set': tokenSet,
    'connected': connected,
    'local_ip': localIp,
  };

  @override
  bool operator ==(Object other) =>
      other is CloudflareDetail &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'CloudflareDetail(${jsonEncode(toJson())})';
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
    required this.subject,
    required this.startedAt,
    required this.percent,
    required this.detail,
    required this.lastActivityAt,
  });

  /// Server-issued job id.
  final String jobId;

  /// unknown: a kind of a later version (a server sends it after a rollback, for a job a later version started).
  final JobKind kind;

  /// Who started it.
  final int uid;

  /// unknown: a state of a later version (a server may send it after a rollback, for a job a later version started).
  final JobState state;

  /// Current or last reached stage.
  final Stage? stage;
  final int createdAt;
  final int? finishedAt;
  final ErrorObject? error;
  final Object? result;
  final bool sessionRestartRequired;

  /// What a job is about. Every field optional; which ones each kind sets: README, What a job is about.
  final JobSubject subject;

  /// When the job was started (equals created_at).
  final int startedAt;

  /// The latest percent of a running job (null when finished or unknown).
  final int? percent;

  /// The latest progress detail of a running job.
  final ProgressDetail? detail;

  /// The last time a running job's process printed anything.
  final int? lastActivityAt;

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
    subject: JobSubject.fromJson(
      (json['subject'] as Map).cast<String, dynamic>(),
    ),
    startedAt: json['started_at'] as int,
    percent: json['percent'] == null ? null : json['percent'] as int,
    detail: json['detail'] == null
        ? null
        : ProgressDetail.fromJson(
            (json['detail'] as Map).cast<String, dynamic>(),
          ),
    lastActivityAt: json['last_activity_at'] == null
        ? null
        : json['last_activity_at'] as int,
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
    'subject': subject.toJson(),
    'started_at': startedAt,
    'percent': percent,
    'detail': detail == null ? null : detail!.toJson(),
    'last_activity_at': lastActivityAt,
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
  full('full');

  const Connectivity(this.value);
  final String value;

  factory Connectivity.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory WifiSecurity.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class WifiNetwork {
  const WifiNetwork({
    required this.id,
    required this.ssid,
    required this.signal,
    required this.security,
    required this.known,
    required this.connected,
  });

  /// Opaque: a network in wifi.list, for wifi.connect and wifi.forget (one id per raw SSID and security; stable while they stay the same). Clients must not build or parse it.
  final String id;

  /// The name to show: an SSID that is not UTF-8 has U+FFFD in place of its bad bytes, so two networks can show the same name (their ids differ).
  final String ssid;
  final int signal;

  /// wpa is WPA or WPA2 with a passphrase, wpa3 is SAE only, enterprise (802.1X) cannot be joined with a password alone.
  final WifiSecurity security;

  /// A connection for it is stored (no password needed).
  final bool known;
  final bool connected;

  factory WifiNetwork.fromJson(Map<String, dynamic> json) => WifiNetwork(
    id: json['id'] as String,
    ssid: json['ssid'] as String,
    signal: json['signal'] as int,
    security: WifiSecurity.fromJson(json['security'] as String),
    known: json['known'] as bool,
    connected: json['connected'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
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

  factory BtKind.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory AudioKind.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory PowerCapability.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

class AppsSetPermissionParams {
  const AppsSetPermissionParams({
    required this.id,
    required this.permission,
    required this.granted,
  });

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;

  /// A sandbox permission: gamepad (controllers), mic (a sound socket that may record), downloads (the profile's Downloads folder), lan (the local network: other devices at home and this box's own services). More may come; show unknown names as they are.
  final String permission;
  final bool granted;

  factory AppsSetPermissionParams.fromJson(Map<String, dynamic> json) =>
      AppsSetPermissionParams(
        id: json['id'] as String,
        permission: json['permission'] as String,
        granted: json['granted'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'permission': permission,
    'granted': granted,
  };

  @override
  bool operator ==(Object other) =>
      other is AppsSetPermissionParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsSetPermissionParams(${jsonEncode(toJson())})';
}

class AppsSetPermissionResult {
  const AppsSetPermissionResult();

  factory AppsSetPermissionResult.fromJson(Map<String, dynamic> json) =>
      AppsSetPermissionResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AppsSetPermissionResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsSetPermissionResult(${jsonEncode(toJson())})';
}

class AppsDisplaysGetParams {
  const AppsDisplaysGetParams();

  factory AppsDisplaysGetParams.fromJson(Map<String, dynamic> json) =>
      AppsDisplaysGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is AppsDisplaysGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsDisplaysGetParams(${jsonEncode(toJson())})';
}

/// How many apps can run at once (apps.displays.get).
class AppsDisplaysGetResult {
  const AppsDisplaysGetResult({
    required this.count,
    required this.active,
    required this.min,
    required this.max,
  });

  /// The setting: what the next session starts with.
  final int count;

  /// What this session has; null: apps do not get displays of their own.
  final int? active;
  final int min;
  final int max;

  factory AppsDisplaysGetResult.fromJson(Map<String, dynamic> json) =>
      AppsDisplaysGetResult(
        count: json['count'] as int,
        active: json['active'] == null ? null : json['active'] as int,
        min: json['min'] as int,
        max: json['max'] as int,
      );

  Map<String, dynamic> toJson() => {
    'count': count,
    'active': active,
    'min': min,
    'max': max,
  };

  @override
  bool operator ==(Object other) =>
      other is AppsDisplaysGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsDisplaysGetResult(${jsonEncode(toJson())})';
}

class AppsDisplaysSetParams {
  const AppsDisplaysSetParams({required this.count});

  final int count;

  factory AppsDisplaysSetParams.fromJson(Map<String, dynamic> json) =>
      AppsDisplaysSetParams(count: json['count'] as int);

  Map<String, dynamic> toJson() => {'count': count};

  @override
  bool operator ==(Object other) =>
      other is AppsDisplaysSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsDisplaysSetParams(${jsonEncode(toJson())})';
}

/// How many apps can run at once (apps.displays.get).
class AppsDisplaysSetResult {
  const AppsDisplaysSetResult({
    required this.count,
    required this.active,
    required this.min,
    required this.max,
  });

  /// The setting: what the next session starts with.
  final int count;

  /// What this session has; null: apps do not get displays of their own.
  final int? active;
  final int min;
  final int max;

  factory AppsDisplaysSetResult.fromJson(Map<String, dynamic> json) =>
      AppsDisplaysSetResult(
        count: json['count'] as int,
        active: json['active'] == null ? null : json['active'] as int,
        min: json['min'] as int,
        max: json['max'] as int,
      );

  Map<String, dynamic> toJson() => {
    'count': count,
    'active': active,
    'min': min,
    'max': max,
  };

  @override
  bool operator ==(Object other) =>
      other is AppsDisplaysSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'AppsDisplaysSetResult(${jsonEncode(toJson())})';
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
  const AppsCloseParams({required this.id, this.force});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;

  /// Force Stop: SIGKILL now, no request to quit first (also while a close is under way). Steam ('steam_client'): every process of the Steam client and all below it, not just Big Picture.
  final bool? force;

  factory AppsCloseParams.fromJson(Map<String, dynamic> json) =>
      AppsCloseParams(
        id: json['id'] as String,
        force: json['force'] == null ? null : json['force'] as bool,
      );

  Map<String, dynamic> toJson() => {'id': id, 'force': ?force};

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

  /// The keyboard is up for a password field (see osk_changed). Absent when false.
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

  /// The keyboard is up for a password field (see osk_changed). Absent when false.
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
    required this.requirements,
    required this.ssh,
  });

  final Base base;

  /// The box features that are on (read-only).
  final List<BoxFeature> requirements;
  final SystemSettingsGetResultSettingsSsh ssh;

  factory SystemSettingsGetResultSettings.fromJson(Map<String, dynamic> json) =>
      SystemSettingsGetResultSettings(
        base: Base.fromJson(json['base'] as String),
        requirements: (json['requirements'] as List)
            .map((x) => BoxFeature.fromJson(x as String))
            .toList(),
        ssh: SystemSettingsGetResultSettingsSsh.fromJson(
          (json['ssh'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'base': base.toJson(),
    'requirements': requirements.map((x) => x.toJson()).toList(),
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
  const SystemHardwareRedetectParams({this.adminPin});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemHardwareRedetectParams.fromJson(Map<String, dynamic> json) =>
      SystemHardwareRedetectParams(
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin};

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
  const SystemRollbackParams({this.generation, this.adminPin});

  final int? generation;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemRollbackParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemRollbackParams(
    generation: json['generation'] == null ? null : json['generation'] as int,
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
  );

  Map<String, dynamic> toJson() => {
    'generation': ?generation,
    'admin_pin': ?adminPin,
  };

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
  const SystemUpdateApplyParams({required this.rev, this.adminPin});

  /// A full git commit id.
  final String rev;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemUpdateApplyParams.fromJson(Map<String, dynamic> json) =>
      SystemUpdateApplyParams(
        rev: json['rev'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'rev': rev, 'admin_pin': ?adminPin};

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

class SystemChannelCheckParams {
  const SystemChannelCheckParams({required this.channel});

  final Channel channel;

  factory SystemChannelCheckParams.fromJson(Map<String, dynamic> json) =>
      SystemChannelCheckParams(
        channel: Channel.fromJson(json['channel'] as String),
      );

  Map<String, dynamic> toJson() => {'channel': channel.toJson()};

  @override
  bool operator ==(Object other) =>
      other is SystemChannelCheckParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemChannelCheckParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemChannelCheckResult {
  const SystemChannelCheckResult({required this.jobId});

  final String? jobId;

  factory SystemChannelCheckResult.fromJson(Map<String, dynamic> json) =>
      SystemChannelCheckResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemChannelCheckResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemChannelCheckResult(${jsonEncode(toJson())})';
}

class SystemChannelSetParams {
  const SystemChannelSetParams({
    required this.channel,
    this.rev,
    this.adminPin,
  });

  final Channel channel;

  /// A full git commit id.
  final String? rev;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemChannelSetParams.fromJson(Map<String, dynamic> json) =>
      SystemChannelSetParams(
        channel: Channel.fromJson(json['channel'] as String),
        rev: json['rev'] == null ? null : json['rev'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {
    'channel': channel.toJson(),
    'rev': ?rev,
    'admin_pin': ?adminPin,
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
  const SystemBaseSetParams({
    required this.base,
    this.acknowledgeDowngrade,
    this.adminPin,
  });

  final Base base;
  final bool? acknowledgeDowngrade;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemBaseSetParams.fromJson(Map<String, dynamic> json) =>
      SystemBaseSetParams(
        base: Base.fromJson(json['base'] as String),
        acknowledgeDowngrade: json['acknowledge_downgrade'] == null
            ? null
            : json['acknowledge_downgrade'] as bool,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {
    'base': base.toJson(),
    'acknowledge_downgrade': ?acknowledgeDowngrade,
    'admin_pin': ?adminPin,
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
    required this.revision,
    required this.generation,
    required this.ids,
    required this.needsTerms,
    required this.box,
  });

  /// SHA-256 of state.json, hex.
  final String revision;
  final int? generation;
  final List<String> ids;
  final List<String> needsTerms;
  final List<BoxFeature> box;

  factory SystemAppsListResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemAppsListResult(
    revision: json['revision'] as String,
    generation: json['generation'] == null ? null : json['generation'] as int,
    ids: (json['ids'] as List).map((x) => x as String).toList(),
    needsTerms: (json['needs_terms'] as List).map((x) => x as String).toList(),
    box: (json['box'] as List)
        .map((x) => BoxFeature.fromJson(x as String))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'generation': generation,
    'ids': ids,
    'needs_terms': needsTerms,
    'box': box.map((x) => x.toJson()).toList(),
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

class SystemAppsGenerationsResultGenerationsItem {
  const SystemAppsGenerationsResultGenerationsItem({
    required this.generation,
    required this.date,
    required this.ids,
    required this.systemRev,
    required this.current,
  });

  final int generation;
  final int date;
  final List<String> ids;
  final String? systemRev;
  final bool current;

  factory SystemAppsGenerationsResultGenerationsItem.fromJson(
    Map<String, dynamic> json,
  ) => SystemAppsGenerationsResultGenerationsItem(
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
      other is SystemAppsGenerationsResultGenerationsItem &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemAppsGenerationsResultGenerationsItem(${jsonEncode(toJson())})';
}

class SystemAppsGenerationsResult {
  const SystemAppsGenerationsResult({required this.generations});

  final List<SystemAppsGenerationsResultGenerationsItem> generations;

  factory SystemAppsGenerationsResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsGenerationsResult(
        generations: (json['generations'] as List)
            .map(
              (x) => SystemAppsGenerationsResultGenerationsItem.fromJson(
                (x as Map).cast<String, dynamic>(),
              ),
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

class SystemAppsClearDataParams {
  const SystemAppsClearDataParams({required this.id});

  /// Catalog app id (state.json apps).
  final String id;

  factory SystemAppsClearDataParams.fromJson(Map<String, dynamic> json) =>
      SystemAppsClearDataParams(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsClearDataParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsClearDataParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemAppsClearDataResult {
  const SystemAppsClearDataResult({required this.jobId});

  final String? jobId;

  factory SystemAppsClearDataResult.fromJson(Map<String, dynamic> json) =>
      SystemAppsClearDataResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemAppsClearDataResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAppsClearDataResult(${jsonEncode(toJson())})';
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

class SystemProfilesListResultProfilesItem {
  const SystemProfilesListResultProfilesItem({
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
    required this.pinSet,
  });

  /// A profile id.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;
  final ProfileColor color;
  final String user;
  final bool admin;
  final bool locked;

  /// The PIN backoff lock (Unix seconds) while it is on.
  final int? lockedUntil;

  /// Its session is the one on screen.
  final bool active;
  final int? lastUsedAt;
  final ProfileUsage? usage;

  /// false: a profile without a PIN yet (show 'Set your PIN').
  final bool pinSet;

  factory SystemProfilesListResultProfilesItem.fromJson(
    Map<String, dynamic> json,
  ) => SystemProfilesListResultProfilesItem(
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
    pinSet: json['pin_set'] as bool,
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
    'pin_set': pinSet,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesListResultProfilesItem &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemProfilesListResultProfilesItem(${jsonEncode(toJson())})';
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

class SystemProfilesListResultCaller {
  const SystemProfilesListResultCaller({
    required this.id,
    required this.user,
    required this.guest,
    required this.spare,
  });

  final String? id;
  final String user;
  final bool guest;
  final bool spare;

  factory SystemProfilesListResultCaller.fromJson(Map<String, dynamic> json) =>
      SystemProfilesListResultCaller(
        id: json['id'] == null ? null : json['id'] as String,
        user: json['user'] as String,
        guest: json['guest'] as bool,
        spare: json['spare'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user,
    'guest': guest,
    'spare': spare,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesListResultCaller &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemProfilesListResultCaller(${jsonEncode(toJson())})';
}

class SystemProfilesListResult {
  const SystemProfilesListResult({
    required this.profiles,
    required this.guest,
    required this.max,
    required this.firstBoot,
    required this.caller,
  });

  final List<SystemProfilesListResultProfilesItem> profiles;
  final SystemProfilesListResultGuest guest;
  final int max;
  final bool firstBoot;
  final SystemProfilesListResultCaller caller;

  factory SystemProfilesListResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesListResult(
        profiles: (json['profiles'] as List)
            .map(
              (x) => SystemProfilesListResultProfilesItem.fromJson(
                (x as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        guest: SystemProfilesListResultGuest.fromJson(
          (json['guest'] as Map).cast<String, dynamic>(),
        ),
        max: json['max'] as int,
        firstBoot: json['first_boot'] as bool,
        caller: SystemProfilesListResultCaller.fromJson(
          (json['caller'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((x) => x.toJson()).toList(),
    'guest': guest.toJson(),
    'max': max,
    'first_boot': firstBoot,
    'caller': caller.toJson(),
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

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;
  final ProfileColor? color;

  /// 4 to 8 digits. Never logged.
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

class SystemProfilesCreateResult {
  const SystemProfilesCreateResult({required this.jobId, required this.id});

  /// Server-issued job id.
  final String jobId;

  /// A profile id.
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

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;
  final ProfileColor? color;

  /// 4 to 8 digits. Never logged.
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

  /// A profile id.
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
    this.adminPin,
  });

  /// A profile id.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemProfilesRenameParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesRenameParams(
        id: json['id'] as String,
        name: json['name'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'admin_pin': ?adminPin,
  };

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

  /// 4 to 8 digits. Never logged.
  final String pin;

  /// 4 to 8 digits. Never logged.
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

  /// 4 to 8 digits. Never logged.
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

  /// A profile id.
  final String id;

  /// 4 to 8 digits. Never logged.
  final String newPin;

  /// 4 to 8 digits. Never logged.
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
    this.pin,
    this.adminPin,
    required this.revision,
  });

  /// A profile id.
  final String id;

  /// A profile id.
  final String confirmId;

  /// 4 to 8 digits. Never logged.
  final String? pin;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// SHA-256 of state.json, hex.
  final String revision;

  factory SystemProfilesRemoveParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesRemoveParams(
        id: json['id'] as String,
        confirmId: json['confirm_id'] as String,
        pin: json['pin'] == null ? null : json['pin'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
        revision: json['revision'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'confirm_id': confirmId,
    'pin': ?pin,
    'admin_pin': ?adminPin,
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

class SystemProfilesUnlockParams {
  const SystemProfilesUnlockParams({required this.pin});

  /// 4 to 8 digits. Never logged.
  final String pin;

  factory SystemProfilesUnlockParams.fromJson(Map<String, dynamic> json) =>
      SystemProfilesUnlockParams(pin: json['pin'] as String);

  Map<String, dynamic> toJson() => {'pin': pin};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesUnlockParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesUnlockParams(${jsonEncode(toJson())})';
}

class SystemProfilesUnlockResult {
  const SystemProfilesUnlockResult();

  factory SystemProfilesUnlockResult.fromJson(Map<String, dynamic> json) =>
      SystemProfilesUnlockResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemProfilesUnlockResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemProfilesUnlockResult(${jsonEncode(toJson())})';
}

class SystemGuestSetParams {
  const SystemGuestSetParams({required this.enabled, this.adminPin});

  final bool enabled;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemGuestSetParams.fromJson(Map<String, dynamic> json) =>
      SystemGuestSetParams(
        enabled: json['enabled'] as bool,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'admin_pin': ?adminPin};

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

class SystemDisplaySaveModeParams {
  const SystemDisplaySaveModeParams({
    required this.display,
    required this.width,
    required this.height,
    required this.refresh,
  });

  /// The display as gamescope names it in GAMESCOPE_MODE_SAVE_FILE (&lt;make&gt; &lt;model&gt;).
  final String display;
  final int width;
  final int height;
  final int refresh;

  factory SystemDisplaySaveModeParams.fromJson(Map<String, dynamic> json) =>
      SystemDisplaySaveModeParams(
        display: json['display'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        refresh: json['refresh'] as int,
      );

  Map<String, dynamic> toJson() => {
    'display': display,
    'width': width,
    'height': height,
    'refresh': refresh,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemDisplaySaveModeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemDisplaySaveModeParams(${jsonEncode(toJson())})';
}

class SystemDisplaySaveModeResult {
  const SystemDisplaySaveModeResult();

  factory SystemDisplaySaveModeResult.fromJson(Map<String, dynamic> json) =>
      SystemDisplaySaveModeResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemDisplaySaveModeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemDisplaySaveModeResult(${jsonEncode(toJson())})';
}

class SystemAudioSaveOutputParams {
  const SystemAudioSaveOutputParams({required this.node});

  final String node;

  factory SystemAudioSaveOutputParams.fromJson(Map<String, dynamic> json) =>
      SystemAudioSaveOutputParams(node: json['node'] as String);

  Map<String, dynamic> toJson() => {'node': node};

  @override
  bool operator ==(Object other) =>
      other is SystemAudioSaveOutputParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAudioSaveOutputParams(${jsonEncode(toJson())})';
}

class SystemAudioSaveOutputResult {
  const SystemAudioSaveOutputResult();

  factory SystemAudioSaveOutputResult.fromJson(Map<String, dynamic> json) =>
      SystemAudioSaveOutputResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemAudioSaveOutputResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemAudioSaveOutputResult(${jsonEncode(toJson())})';
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
  const SystemStarterSetSetParams({required this.ids, this.adminPin});

  final List<String> ids;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemStarterSetSetParams.fromJson(Map<String, dynamic> json) =>
      SystemStarterSetSetParams(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'ids': ids, 'admin_pin': ?adminPin};

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

class SystemStorageGetParams {
  const SystemStorageGetParams();

  factory SystemStorageGetParams.fromJson(Map<String, dynamic> json) =>
      SystemStorageGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStorageGetParams(${jsonEncode(toJson())})';
}

class SystemStorageGetResult {
  const SystemStorageGetResult({required this.measurement});

  final Measurement? measurement;

  factory SystemStorageGetResult.fromJson(Map<String, dynamic> json) =>
      SystemStorageGetResult(
        measurement: json['measurement'] == null
            ? null
            : Measurement.fromJson(
                (json['measurement'] as Map).cast<String, dynamic>(),
              ),
      );

  Map<String, dynamic> toJson() => {
    'measurement': measurement == null ? null : measurement!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemStorageGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStorageGetResult(${jsonEncode(toJson())})';
}

class SystemStorageMeasureParams {
  const SystemStorageMeasureParams();

  factory SystemStorageMeasureParams.fromJson(Map<String, dynamic> json) =>
      SystemStorageMeasureParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageMeasureParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStorageMeasureParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemStorageMeasureResult {
  const SystemStorageMeasureResult({required this.jobId});

  final String? jobId;

  factory SystemStorageMeasureResult.fromJson(Map<String, dynamic> json) =>
      SystemStorageMeasureResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageMeasureResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStorageMeasureResult(${jsonEncode(toJson())})';
}

class SystemStorageTreeParams {
  const SystemStorageTreeParams({required this.id, this.adminPin});

  /// A profile id or guest.
  final String id;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemStorageTreeParams.fromJson(Map<String, dynamic> json) =>
      SystemStorageTreeParams(
        id: json['id'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageTreeParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStorageTreeParams(${jsonEncode(toJson())})';
}

class SystemStorageTreeResult {
  const SystemStorageTreeResult({
    required this.id,
    required this.measuredAt,
    required this.root,
  });

  /// A profile id or guest.
  final String id;
  final int measuredAt;

  /// A segment of the storage ring. Children always add up to bytes (the disk root: to the filesystem's size, unless the measured parts exceed it). Zero-byte nodes are left out except app_env, profile, guest and free. Order: generations newest first, other named nodes largest first, then common, shared, files, other, free. The launcher names kinds itself; name is data (a folder or a game).
  final StorageNode root;

  factory SystemStorageTreeResult.fromJson(Map<String, dynamic> json) =>
      SystemStorageTreeResult(
        id: json['id'] as String,
        measuredAt: json['measured_at'] as int,
        root: StorageNode.fromJson(
          (json['root'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'measured_at': measuredAt,
    'root': root.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemStorageTreeResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemStorageTreeResult(${jsonEncode(toJson())})';
}

class SystemStorageCleanupSystemParams {
  const SystemStorageCleanupSystemParams({required this.keep, this.adminPin});

  /// Generations to keep (the running, booted and current ones always stay).
  final int keep;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemStorageCleanupSystemParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemStorageCleanupSystemParams(
    keep: json['keep'] as int,
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
  );

  Map<String, dynamic> toJson() => {'keep': keep, 'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageCleanupSystemParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemStorageCleanupSystemParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemStorageCleanupSystemResult {
  const SystemStorageCleanupSystemResult({required this.jobId});

  final String? jobId;

  factory SystemStorageCleanupSystemResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemStorageCleanupSystemResult(
    jobId: json['job_id'] == null ? null : json['job_id'] as String,
  );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageCleanupSystemResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemStorageCleanupSystemResult(${jsonEncode(toJson())})';
}

class SystemStorageCleanupProfilesParams {
  const SystemStorageCleanupProfilesParams({required this.keep, this.adminPin});

  /// Generations to keep (the running, booted and current ones always stay).
  final int keep;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemStorageCleanupProfilesParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemStorageCleanupProfilesParams(
    keep: json['keep'] as int,
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
  );

  Map<String, dynamic> toJson() => {'keep': keep, 'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageCleanupProfilesParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemStorageCleanupProfilesParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemStorageCleanupProfilesResult {
  const SystemStorageCleanupProfilesResult({required this.jobId});

  final String? jobId;

  factory SystemStorageCleanupProfilesResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemStorageCleanupProfilesResult(
    jobId: json['job_id'] == null ? null : json['job_id'] as String,
  );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemStorageCleanupProfilesResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemStorageCleanupProfilesResult(${jsonEncode(toJson())})';
}

class SystemCleanupGetParams {
  const SystemCleanupGetParams();

  factory SystemCleanupGetParams.fromJson(Map<String, dynamic> json) =>
      SystemCleanupGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemCleanupGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemCleanupGetParams(${jsonEncode(toJson())})';
}

class SystemCleanupGetResult {
  const SystemCleanupGetResult({
    required this.enabled,
    required this.frequency,
    required this.keepSystem,
    required this.keepProfiles,
  });

  final bool enabled;
  final CleanupFrequency frequency;

  /// Generations to keep (the running, booted and current ones always stay).
  final int keepSystem;

  /// Generations to keep (the running, booted and current ones always stay).
  final int keepProfiles;

  factory SystemCleanupGetResult.fromJson(Map<String, dynamic> json) =>
      SystemCleanupGetResult(
        enabled: json['enabled'] as bool,
        frequency: CleanupFrequency.fromJson(json['frequency'] as String),
        keepSystem: json['keep_system'] as int,
        keepProfiles: json['keep_profiles'] as int,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'frequency': frequency.toJson(),
    'keep_system': keepSystem,
    'keep_profiles': keepProfiles,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemCleanupGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemCleanupGetResult(${jsonEncode(toJson())})';
}

class SystemCleanupSetParams {
  const SystemCleanupSetParams({
    required this.enabled,
    required this.frequency,
    required this.keepSystem,
    required this.keepProfiles,
    this.adminPin,
  });

  final bool enabled;
  final CleanupFrequency frequency;

  /// Generations to keep (the running, booted and current ones always stay).
  final int keepSystem;

  /// Generations to keep (the running, booted and current ones always stay).
  final int keepProfiles;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemCleanupSetParams.fromJson(Map<String, dynamic> json) =>
      SystemCleanupSetParams(
        enabled: json['enabled'] as bool,
        frequency: CleanupFrequency.fromJson(json['frequency'] as String),
        keepSystem: json['keep_system'] as int,
        keepProfiles: json['keep_profiles'] as int,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'frequency': frequency.toJson(),
    'keep_system': keepSystem,
    'keep_profiles': keepProfiles,
    'admin_pin': ?adminPin,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemCleanupSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemCleanupSetParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemCleanupSetResult {
  const SystemCleanupSetResult({required this.jobId});

  final String? jobId;

  factory SystemCleanupSetResult.fromJson(Map<String, dynamic> json) =>
      SystemCleanupSetResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemCleanupSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemCleanupSetResult(${jsonEncode(toJson())})';
}

class SystemTimeZoneGetParams {
  const SystemTimeZoneGetParams();

  factory SystemTimeZoneGetParams.fromJson(Map<String, dynamic> json) =>
      SystemTimeZoneGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemTimeZoneGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTimeZoneGetParams(${jsonEncode(toJson())})';
}

class SystemTimeZoneGetResult {
  const SystemTimeZoneGetResult({
    required this.zone,
    required this.offsetS,
    required this.standardOffsetS,
    required this.offsetValidUntil,
  });

  /// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
  final String zone;

  /// Seconds east of UTC.
  final int offsetS;

  /// Seconds east of UTC.
  final int standardOffsetS;

  /// Unix time of the next offset change; null when there is none.
  final int? offsetValidUntil;

  factory SystemTimeZoneGetResult.fromJson(Map<String, dynamic> json) =>
      SystemTimeZoneGetResult(
        zone: json['zone'] as String,
        offsetS: json['offset_s'] as int,
        standardOffsetS: json['standard_offset_s'] as int,
        offsetValidUntil: json['offset_valid_until'] == null
            ? null
            : json['offset_valid_until'] as int,
      );

  Map<String, dynamic> toJson() => {
    'zone': zone,
    'offset_s': offsetS,
    'standard_offset_s': standardOffsetS,
    'offset_valid_until': offsetValidUntil,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemTimeZoneGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTimeZoneGetResult(${jsonEncode(toJson())})';
}

class SystemTimeZoneListParams {
  const SystemTimeZoneListParams();

  factory SystemTimeZoneListParams.fromJson(Map<String, dynamic> json) =>
      SystemTimeZoneListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemTimeZoneListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTimeZoneListParams(${jsonEncode(toJson())})';
}

class SystemTimeZoneListResult {
  const SystemTimeZoneListResult({required this.zones});

  final List<TimeZoneEntry> zones;

  factory SystemTimeZoneListResult.fromJson(Map<String, dynamic> json) =>
      SystemTimeZoneListResult(
        zones: (json['zones'] as List)
            .map(
              (x) => TimeZoneEntry.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'zones': zones.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemTimeZoneListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTimeZoneListResult(${jsonEncode(toJson())})';
}

class SystemTimeZoneSetParams {
  const SystemTimeZoneSetParams({required this.zone, this.adminPin});

  /// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
  final String zone;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemTimeZoneSetParams.fromJson(Map<String, dynamic> json) =>
      SystemTimeZoneSetParams(
        zone: json['zone'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'zone': zone, 'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemTimeZoneSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTimeZoneSetParams(${jsonEncode(toJson())})';
}

class SystemTimeZoneSetResult {
  const SystemTimeZoneSetResult({
    required this.zone,
    required this.offsetS,
    required this.standardOffsetS,
    required this.offsetValidUntil,
  });

  /// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
  final String zone;

  /// Seconds east of UTC.
  final int offsetS;

  /// Seconds east of UTC.
  final int standardOffsetS;

  /// Unix time of the next offset change; null when there is none.
  final int? offsetValidUntil;

  factory SystemTimeZoneSetResult.fromJson(Map<String, dynamic> json) =>
      SystemTimeZoneSetResult(
        zone: json['zone'] as String,
        offsetS: json['offset_s'] as int,
        standardOffsetS: json['standard_offset_s'] as int,
        offsetValidUntil: json['offset_valid_until'] == null
            ? null
            : json['offset_valid_until'] as int,
      );

  Map<String, dynamic> toJson() => {
    'zone': zone,
    'offset_s': offsetS,
    'standard_offset_s': standardOffsetS,
    'offset_valid_until': offsetValidUntil,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemTimeZoneSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTimeZoneSetResult(${jsonEncode(toJson())})';
}

class SystemServicesListParams {
  const SystemServicesListParams();

  factory SystemServicesListParams.fromJson(Map<String, dynamic> json) =>
      SystemServicesListParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemServicesListParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemServicesListParams(${jsonEncode(toJson())})';
}

class SystemServicesListResult {
  const SystemServicesListResult({
    required this.revision,
    required this.services,
  });

  /// SHA-256 of state.json, hex.
  final String revision;
  final List<ServiceInfo> services;

  factory SystemServicesListResult.fromJson(Map<String, dynamic> json) =>
      SystemServicesListResult(
        revision: json['revision'] as String,
        services: (json['services'] as List)
            .map(
              (x) => ServiceInfo.fromJson((x as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'services': services.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemServicesListResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemServicesListResult(${jsonEncode(toJson())})';
}

class SystemServicesEnableParams {
  const SystemServicesEnableParams({
    required this.ids,
    this.adminPin,
    required this.revision,
    this.acceptedTerms,
  });

  final List<String> ids;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// SHA-256 of state.json, hex.
  final String revision;

  /// Service id to the terms version accepted (after reading the full text).
  final Map<String, Object?>? acceptedTerms;

  factory SystemServicesEnableParams.fromJson(Map<String, dynamic> json) =>
      SystemServicesEnableParams(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
        revision: json['revision'] as String,
        acceptedTerms: json['accepted_terms'] == null
            ? null
            : (json['accepted_terms'] as Map).cast<String, Object?>(),
      );

  Map<String, dynamic> toJson() => {
    'ids': ids,
    'admin_pin': ?adminPin,
    'revision': revision,
    'accepted_terms': ?acceptedTerms,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemServicesEnableParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemServicesEnableParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemServicesEnableResult {
  const SystemServicesEnableResult({required this.jobId});

  final String? jobId;

  factory SystemServicesEnableResult.fromJson(Map<String, dynamic> json) =>
      SystemServicesEnableResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemServicesEnableResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemServicesEnableResult(${jsonEncode(toJson())})';
}

class SystemServicesDisableParams {
  const SystemServicesDisableParams({
    required this.ids,
    this.adminPin,
    required this.revision,
    required this.deleteData,
  });

  final List<String> ids;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// SHA-256 of state.json, hex.
  final String revision;
  final bool deleteData;

  factory SystemServicesDisableParams.fromJson(Map<String, dynamic> json) =>
      SystemServicesDisableParams(
        ids: (json['ids'] as List).map((x) => x as String).toList(),
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
        revision: json['revision'] as String,
        deleteData: json['delete_data'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'ids': ids,
    'admin_pin': ?adminPin,
    'revision': revision,
    'delete_data': deleteData,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemServicesDisableParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemServicesDisableParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemServicesDisableResult {
  const SystemServicesDisableResult({required this.jobId});

  final String? jobId;

  factory SystemServicesDisableResult.fromJson(Map<String, dynamic> json) =>
      SystemServicesDisableResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemServicesDisableResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemServicesDisableResult(${jsonEncode(toJson())})';
}

class SystemMediaFoldersParams {
  const SystemMediaFoldersParams({this.folderId});

  /// A folder below /srv/media, as its path relative to it (media.folders).
  final String? folderId;

  factory SystemMediaFoldersParams.fromJson(Map<String, dynamic> json) =>
      SystemMediaFoldersParams(
        folderId: json['folder_id'] == null
            ? null
            : json['folder_id'] as String,
      );

  Map<String, dynamic> toJson() => {'folder_id': ?folderId};

  @override
  bool operator ==(Object other) =>
      other is SystemMediaFoldersParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemMediaFoldersParams(${jsonEncode(toJson())})';
}

class SystemMediaFoldersResult {
  const SystemMediaFoldersResult({
    required this.folderId,
    required this.folders,
  });

  final String? folderId;
  final List<MediaFolder> folders;

  factory SystemMediaFoldersResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemMediaFoldersResult(
    folderId: json['folder_id'] == null ? null : json['folder_id'] as String,
    folders: (json['folders'] as List)
        .map((x) => MediaFolder.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'folder_id': folderId,
    'folders': folders.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemMediaFoldersResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemMediaFoldersResult(${jsonEncode(toJson())})';
}

class SystemJellyfinLibrariesAddParams {
  const SystemJellyfinLibrariesAddParams({
    this.adminPin,
    required this.name,
    required this.kind,
    required this.folder,
  });

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// 1 to 64 characters after trimming, without control or format characters or /\:*?"&lt;&gt;|.
  final String name;

  /// What a new Jellyfin library holds (mixed: movies and shows).
  final LibraryKind kind;

  /// A folder below /srv/media, as its path relative to it (media.folders).
  final String folder;

  factory SystemJellyfinLibrariesAddParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemJellyfinLibrariesAddParams(
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
    name: json['name'] as String,
    kind: LibraryKind.fromJson(json['kind'] as String),
    folder: json['folder'] as String,
  );

  Map<String, dynamic> toJson() => {
    'admin_pin': ?adminPin,
    'name': name,
    'kind': kind.toJson(),
    'folder': folder,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinLibrariesAddParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinLibrariesAddParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemJellyfinLibrariesAddResult {
  const SystemJellyfinLibrariesAddResult({required this.jobId});

  final String? jobId;

  factory SystemJellyfinLibrariesAddResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemJellyfinLibrariesAddResult(
    jobId: json['job_id'] == null ? null : json['job_id'] as String,
  );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinLibrariesAddResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinLibrariesAddResult(${jsonEncode(toJson())})';
}

class SystemJellyfinLibrariesRemoveParams {
  const SystemJellyfinLibrariesRemoveParams({
    this.adminPin,
    required this.libraryId,
  });

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// A Jellyfin item id.
  final String libraryId;

  factory SystemJellyfinLibrariesRemoveParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemJellyfinLibrariesRemoveParams(
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
    libraryId: json['library_id'] as String,
  );

  Map<String, dynamic> toJson() => {
    'admin_pin': ?adminPin,
    'library_id': libraryId,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinLibrariesRemoveParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinLibrariesRemoveParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemJellyfinLibrariesRemoveResult {
  const SystemJellyfinLibrariesRemoveResult({required this.jobId});

  final String? jobId;

  factory SystemJellyfinLibrariesRemoveResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemJellyfinLibrariesRemoveResult(
    jobId: json['job_id'] == null ? null : json['job_id'] as String,
  );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinLibrariesRemoveResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinLibrariesRemoveResult(${jsonEncode(toJson())})';
}

class SystemJellyfinUsersRevealParams {
  const SystemJellyfinUsersRevealParams({this.adminPin});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemJellyfinUsersRevealParams.fromJson(Map<String, dynamic> json) =>
      SystemJellyfinUsersRevealParams(
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinUsersRevealParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinUsersRevealParams(${jsonEncode(toJson())})';
}

class SystemJellyfinUsersRevealResult {
  const SystemJellyfinUsersRevealResult({
    required this.admin,
    required this.users,
  });

  final JellyfinAccount? admin;
  final List<JellyfinProfileAccount> users;

  factory SystemJellyfinUsersRevealResult.fromJson(Map<String, dynamic> json) =>
      SystemJellyfinUsersRevealResult(
        admin: json['admin'] == null
            ? null
            : JellyfinAccount.fromJson(
                (json['admin'] as Map).cast<String, dynamic>(),
              ),
        users: (json['users'] as List)
            .map(
              (x) => JellyfinProfileAccount.fromJson(
                (x as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'admin': admin == null ? null : admin!.toJson(),
    'users': users.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinUsersRevealResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinUsersRevealResult(${jsonEncode(toJson())})';
}

class SystemJellyfinClientTokenParams {
  const SystemJellyfinClientTokenParams();

  factory SystemJellyfinClientTokenParams.fromJson(Map<String, dynamic> json) =>
      SystemJellyfinClientTokenParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinClientTokenParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinClientTokenParams(${jsonEncode(toJson())})';
}

class SystemJellyfinClientTokenResult {
  const SystemJellyfinClientTokenResult({
    required this.serverId,
    required this.userId,
    required this.deviceId,
    required this.accessToken,
  });

  /// A Jellyfin item id.
  final String serverId;

  /// A Jellyfin item id.
  final String userId;
  final String deviceId;
  final String accessToken;

  factory SystemJellyfinClientTokenResult.fromJson(Map<String, dynamic> json) =>
      SystemJellyfinClientTokenResult(
        serverId: json['server_id'] as String,
        userId: json['user_id'] as String,
        deviceId: json['device_id'] as String,
        accessToken: json['access_token'] as String,
      );

  Map<String, dynamic> toJson() => {
    'server_id': serverId,
    'user_id': userId,
    'device_id': deviceId,
    'access_token': accessToken,
  };

  @override
  bool operator ==(Object other) =>
      other is SystemJellyfinClientTokenResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemJellyfinClientTokenResult(${jsonEncode(toJson())})';
}

class SystemPlexClaimParams {
  const SystemPlexClaimParams({this.adminPin, required this.code});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// A plex.tv/claim code. Never logged.
  final String code;

  factory SystemPlexClaimParams.fromJson(Map<String, dynamic> json) =>
      SystemPlexClaimParams(
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
        code: json['code'] as String,
      );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin, 'code': code};

  @override
  bool operator ==(Object other) =>
      other is SystemPlexClaimParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemPlexClaimParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemPlexClaimResult {
  const SystemPlexClaimResult({required this.jobId});

  final String? jobId;

  factory SystemPlexClaimResult.fromJson(Map<String, dynamic> json) =>
      SystemPlexClaimResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemPlexClaimResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemPlexClaimResult(${jsonEncode(toJson())})';
}

class SystemTailscaleLoginParams {
  const SystemTailscaleLoginParams({this.adminPin});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemTailscaleLoginParams.fromJson(Map<String, dynamic> json) =>
      SystemTailscaleLoginParams(
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemTailscaleLoginParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTailscaleLoginParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemTailscaleLoginResult {
  const SystemTailscaleLoginResult({required this.jobId});

  final String? jobId;

  factory SystemTailscaleLoginResult.fromJson(Map<String, dynamic> json) =>
      SystemTailscaleLoginResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemTailscaleLoginResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTailscaleLoginResult(${jsonEncode(toJson())})';
}

class SystemTailscaleLogoutParams {
  const SystemTailscaleLogoutParams({this.adminPin});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemTailscaleLogoutParams.fromJson(Map<String, dynamic> json) =>
      SystemTailscaleLogoutParams(
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemTailscaleLogoutParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTailscaleLogoutParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemTailscaleLogoutResult {
  const SystemTailscaleLogoutResult({required this.jobId});

  final String? jobId;

  factory SystemTailscaleLogoutResult.fromJson(Map<String, dynamic> json) =>
      SystemTailscaleLogoutResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemTailscaleLogoutResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SystemTailscaleLogoutResult(${jsonEncode(toJson())})';
}

class SystemCloudflareSetTokenParams {
  const SystemCloudflareSetTokenParams({this.adminPin, required this.token});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  /// A Cloudflare tunnel token (standard padded base64). Never logged.
  final String token;

  factory SystemCloudflareSetTokenParams.fromJson(Map<String, dynamic> json) =>
      SystemCloudflareSetTokenParams(
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
        token: json['token'] as String,
      );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin, 'token': token};

  @override
  bool operator ==(Object other) =>
      other is SystemCloudflareSetTokenParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemCloudflareSetTokenParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemCloudflareSetTokenResult {
  const SystemCloudflareSetTokenResult({required this.jobId});

  final String? jobId;

  factory SystemCloudflareSetTokenResult.fromJson(Map<String, dynamic> json) =>
      SystemCloudflareSetTokenResult(
        jobId: json['job_id'] == null ? null : json['job_id'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemCloudflareSetTokenResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemCloudflareSetTokenResult(${jsonEncode(toJson())})';
}

class SystemCloudflareClearTokenParams {
  const SystemCloudflareClearTokenParams({this.adminPin});

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemCloudflareClearTokenParams.fromJson(
    Map<String, dynamic> json,
  ) => SystemCloudflareClearTokenParams(
    adminPin: json['admin_pin'] == null ? null : json['admin_pin'] as String,
  );

  Map<String, dynamic> toJson() => {'admin_pin': ?adminPin};

  @override
  bool operator ==(Object other) =>
      other is SystemCloudflareClearTokenParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemCloudflareClearTokenParams(${jsonEncode(toJson())})';
}

/// A started job, or null when there was nothing to do.
class SystemCloudflareClearTokenResult {
  const SystemCloudflareClearTokenResult({required this.jobId});

  final String? jobId;

  factory SystemCloudflareClearTokenResult.fromJson(
    Map<String, dynamic> json,
  ) => SystemCloudflareClearTokenResult(
    jobId: json['job_id'] == null ? null : json['job_id'] as String,
  );

  Map<String, dynamic> toJson() => {'job_id': jobId};

  @override
  bool operator ==(Object other) =>
      other is SystemCloudflareClearTokenResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() =>
      'SystemCloudflareClearTokenResult(${jsonEncode(toJson())})';
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
  const SystemJobsCancelParams({required this.jobId, this.adminPin});

  /// Server-issued job id.
  final String jobId;

  /// 4 to 8 digits. Never logged.
  final String? adminPin;

  factory SystemJobsCancelParams.fromJson(Map<String, dynamic> json) =>
      SystemJobsCancelParams(
        jobId: json['job_id'] as String,
        adminPin: json['admin_pin'] == null
            ? null
            : json['admin_pin'] as String,
      );

  Map<String, dynamic> toJson() => {'job_id': jobId, 'admin_pin': ?adminPin};

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
  const WifiConnectParams({required this.id, this.password});

  /// Opaque: a network in wifi.list, for wifi.connect and wifi.forget (one id per raw SSID and security; stable while they stay the same). Clients must not build or parse it.
  final String id;

  /// 8 to 63 characters (WPA), or 64 hex digits (the raw key).
  final String? password;

  factory WifiConnectParams.fromJson(Map<String, dynamic> json) =>
      WifiConnectParams(
        id: json['id'] as String,
        password: json['password'] == null ? null : json['password'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'password': ?password};

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
  const WifiForgetParams({required this.id});

  /// Opaque: a network in wifi.list, for wifi.connect and wifi.forget (one id per raw SSID and security; stable while they stay the same). Clients must not build or parse it.
  final String id;

  factory WifiForgetParams.fromJson(Map<String, dynamic> json) =>
      WifiForgetParams(id: json['id'] as String);

  Map<String, dynamic> toJson() => {'id': id};

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

  final String? id;
  final String? name;
  final ProfileColor? color;
  final bool admin;
  final bool locked;
  final bool guest;
  final bool setupRequired;
  final bool pinSet;
  final bool screenLocked;

  factory ProfileCurrentResult.fromJson(Map<String, dynamic> json) =>
      ProfileCurrentResult(
        id: json['id'] == null ? null : json['id'] as String,
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
  const SessionSwitchProfileParams({required this.id, this.pin});

  final Object id;

  /// 4 to 8 digits. Never logged.
  final String? pin;

  factory SessionSwitchProfileParams.fromJson(Map<String, dynamic> json) =>
      SessionSwitchProfileParams(
        id: json['id'],
        pin: json['pin'] == null ? null : json['pin'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'pin': ?pin};

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

class SessionLockStateParams {
  const SessionLockStateParams();

  factory SessionLockStateParams.fromJson(Map<String, dynamic> json) =>
      SessionLockStateParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is SessionLockStateParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionLockStateParams(${jsonEncode(toJson())})';
}

class SessionLockStateResult {
  const SessionLockStateResult({required this.locked});

  final bool locked;

  factory SessionLockStateResult.fromJson(Map<String, dynamic> json) =>
      SessionLockStateResult(locked: json['locked'] as bool);

  Map<String, dynamic> toJson() => {'locked': locked};

  @override
  bool operator ==(Object other) =>
      other is SessionLockStateResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SessionLockStateResult(${jsonEncode(toJson())})';
}

class SessionUnlockParams {
  const SessionUnlockParams({required this.pin});

  /// 4 to 8 digits. Never logged.
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

class GreeterListResultProfilesItem {
  const GreeterListResultProfilesItem({
    required this.id,
    required this.name,
    required this.color,
    required this.locked,
    required this.admin,
    required this.lockedUntil,
  });

  /// A profile id.
  final String id;

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;
  final ProfileColor color;
  final bool locked;
  final bool admin;
  final int? lockedUntil;

  factory GreeterListResultProfilesItem.fromJson(Map<String, dynamic> json) =>
      GreeterListResultProfilesItem(
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
      other is GreeterListResultProfilesItem &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterListResultProfilesItem(${jsonEncode(toJson())})';
}

class GreeterListResultAppearance {
  const GreeterListResultAppearance({
    required this.textScale,
    required this.highContrast,
    required this.reduceMotion,
  });

  final num textScale;
  final bool highContrast;
  final bool reduceMotion;

  factory GreeterListResultAppearance.fromJson(Map<String, dynamic> json) =>
      GreeterListResultAppearance(
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
      other is GreeterListResultAppearance &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'GreeterListResultAppearance(${jsonEncode(toJson())})';
}

class GreeterListResult {
  const GreeterListResult({
    required this.profiles,
    required this.guest,
    required this.firstBoot,
    required this.focus,
    this.switchTo,
    required this.appearance,
  });

  final List<GreeterListResultProfilesItem> profiles;
  final bool guest;
  final bool firstBoot;
  final Object? focus;

  /// A switch from a profile's session to this profile is pending (an unexpired hint whose fast path did not apply, e.g. a locked target): the picker goes straight to it (its PIN pad) instead of showing the tiles first. Absent or null: none.
  final Object? switchTo;
  final GreeterListResultAppearance appearance;

  factory GreeterListResult.fromJson(Map<String, dynamic> json) =>
      GreeterListResult(
        profiles: (json['profiles'] as List)
            .map(
              (x) => GreeterListResultProfilesItem.fromJson(
                (x as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        guest: json['guest'] as bool,
        firstBoot: json['first_boot'] as bool,
        focus: json['focus'] == null ? null : json['focus'],
        switchTo: json['switch_to'] == null ? null : json['switch_to'],
        appearance: GreeterListResultAppearance.fromJson(
          (json['appearance'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((x) => x.toJson()).toList(),
    'guest': guest,
    'first_boot': firstBoot,
    'focus': focus,
    'switch_to': ?switchTo,
    'appearance': appearance.toJson(),
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

  final Object id;

  factory GreeterLoginParams.fromJson(Map<String, dynamic> json) =>
      GreeterLoginParams(id: json['id']);

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

  /// 4 to 8 digits. Never logged.
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

  /// A display name: 1 to 32 characters, trimmed, no control or format characters.
  final String name;
  final ProfileColor? color;

  /// 4 to 8 digits. Never logged.
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

class GreeterCreateResult {
  const GreeterCreateResult({required this.jobId, required this.id});

  /// Server-issued job id.
  final String jobId;

  /// A profile id.
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

class InputSettingsGetParams {
  const InputSettingsGetParams();

  factory InputSettingsGetParams.fromJson(Map<String, dynamic> json) =>
      InputSettingsGetParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is InputSettingsGetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsGetParams(${jsonEncode(toJson())})';
}

class InputSettingsGetResultSpeed {
  const InputSettingsGetResultSpeed({
    required this.min,
    required this.max,
    required this.step,
  });

  final int min;
  final int max;
  final int step;

  factory InputSettingsGetResultSpeed.fromJson(Map<String, dynamic> json) =>
      InputSettingsGetResultSpeed(
        min: json['min'] as int,
        max: json['max'] as int,
        step: json['step'] as int,
      );

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'step': step};

  @override
  bool operator ==(Object other) =>
      other is InputSettingsGetResultSpeed &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsGetResultSpeed(${jsonEncode(toJson())})';
}

/// The controller settings of this profile (input.settings.get).
class InputSettingsGetResult {
  const InputSettingsGetResult({
    required this.settings,
    required this.defaults,
    required this.buttons,
    required this.actions,
    required this.keyActions,
    required this.keys,
    required this.modifiers,
    required this.speed,
    required this.apps,
  });

  /// The stored controller settings of a profile: only what the user changed. general: over defaults.general, the result one button per action and one action per button. keyboard: the keys of every keyboard-mode app. apps: per app id, over everything else for that app.
  final ControllerSettings settings;

  /// The built-in controller settings. pointer has all four fields.
  final ControllerDefaults defaults;
  final List<String> buttons;

  /// The actions of general, in display order.
  final List<String> actions;

  /// The actions of a keymap, in display order.
  final List<String> keyActions;

  /// Key names a KeyComboName may end with.
  final List<String> keys;
  final List<String> modifiers;
  final InputSettingsGetResultSpeed speed;
  final List<KeyboardApp> apps;

  factory InputSettingsGetResult.fromJson(
    Map<String, dynamic> json,
  ) => InputSettingsGetResult(
    settings: ControllerSettings.fromJson(
      (json['settings'] as Map).cast<String, dynamic>(),
    ),
    defaults: ControllerDefaults.fromJson(
      (json['defaults'] as Map).cast<String, dynamic>(),
    ),
    buttons: (json['buttons'] as List).map((x) => x as String).toList(),
    actions: (json['actions'] as List).map((x) => x as String).toList(),
    keyActions: (json['key_actions'] as List).map((x) => x as String).toList(),
    keys: (json['keys'] as List).map((x) => x as String).toList(),
    modifiers: (json['modifiers'] as List).map((x) => x as String).toList(),
    speed: InputSettingsGetResultSpeed.fromJson(
      (json['speed'] as Map).cast<String, dynamic>(),
    ),
    apps: (json['apps'] as List)
        .map((x) => KeyboardApp.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'settings': settings.toJson(),
    'defaults': defaults.toJson(),
    'buttons': buttons,
    'actions': actions,
    'key_actions': keyActions,
    'keys': keys,
    'modifiers': modifiers,
    'speed': speed.toJson(),
    'apps': apps.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is InputSettingsGetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsGetResult(${jsonEncode(toJson())})';
}

class InputSettingsSetParams {
  const InputSettingsSetParams({required this.settings});

  /// The stored controller settings of a profile: only what the user changed. general: over defaults.general, the result one button per action and one action per button. keyboard: the keys of every keyboard-mode app. apps: per app id, over everything else for that app.
  final ControllerSettings settings;

  factory InputSettingsSetParams.fromJson(Map<String, dynamic> json) =>
      InputSettingsSetParams(
        settings: ControllerSettings.fromJson(
          (json['settings'] as Map).cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toJson() => {'settings': settings.toJson()};

  @override
  bool operator ==(Object other) =>
      other is InputSettingsSetParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsSetParams(${jsonEncode(toJson())})';
}

class InputSettingsSetResultSpeed {
  const InputSettingsSetResultSpeed({
    required this.min,
    required this.max,
    required this.step,
  });

  final int min;
  final int max;
  final int step;

  factory InputSettingsSetResultSpeed.fromJson(Map<String, dynamic> json) =>
      InputSettingsSetResultSpeed(
        min: json['min'] as int,
        max: json['max'] as int,
        step: json['step'] as int,
      );

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'step': step};

  @override
  bool operator ==(Object other) =>
      other is InputSettingsSetResultSpeed &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsSetResultSpeed(${jsonEncode(toJson())})';
}

/// The controller settings of this profile (input.settings.get).
class InputSettingsSetResult {
  const InputSettingsSetResult({
    required this.settings,
    required this.defaults,
    required this.buttons,
    required this.actions,
    required this.keyActions,
    required this.keys,
    required this.modifiers,
    required this.speed,
    required this.apps,
  });

  /// The stored controller settings of a profile: only what the user changed. general: over defaults.general, the result one button per action and one action per button. keyboard: the keys of every keyboard-mode app. apps: per app id, over everything else for that app.
  final ControllerSettings settings;

  /// The built-in controller settings. pointer has all four fields.
  final ControllerDefaults defaults;
  final List<String> buttons;

  /// The actions of general, in display order.
  final List<String> actions;

  /// The actions of a keymap, in display order.
  final List<String> keyActions;

  /// Key names a KeyComboName may end with.
  final List<String> keys;
  final List<String> modifiers;
  final InputSettingsSetResultSpeed speed;
  final List<KeyboardApp> apps;

  factory InputSettingsSetResult.fromJson(
    Map<String, dynamic> json,
  ) => InputSettingsSetResult(
    settings: ControllerSettings.fromJson(
      (json['settings'] as Map).cast<String, dynamic>(),
    ),
    defaults: ControllerDefaults.fromJson(
      (json['defaults'] as Map).cast<String, dynamic>(),
    ),
    buttons: (json['buttons'] as List).map((x) => x as String).toList(),
    actions: (json['actions'] as List).map((x) => x as String).toList(),
    keyActions: (json['key_actions'] as List).map((x) => x as String).toList(),
    keys: (json['keys'] as List).map((x) => x as String).toList(),
    modifiers: (json['modifiers'] as List).map((x) => x as String).toList(),
    speed: InputSettingsSetResultSpeed.fromJson(
      (json['speed'] as Map).cast<String, dynamic>(),
    ),
    apps: (json['apps'] as List)
        .map((x) => KeyboardApp.fromJson((x as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'settings': settings.toJson(),
    'defaults': defaults.toJson(),
    'buttons': buttons,
    'actions': actions,
    'key_actions': keyActions,
    'keys': keys,
    'modifiers': modifiers,
    'speed': speed.toJson(),
    'apps': apps.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is InputSettingsSetResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputSettingsSetResult(${jsonEncode(toJson())})';
}

class InputCaptureParams {
  const InputCaptureParams();

  factory InputCaptureParams.fromJson(Map<String, dynamic> json) =>
      InputCaptureParams();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is InputCaptureParams &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputCaptureParams(${jsonEncode(toJson())})';
}

class InputCaptureResult {
  const InputCaptureResult();

  factory InputCaptureResult.fromJson(Map<String, dynamic> json) =>
      InputCaptureResult();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) =>
      other is InputCaptureResult &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputCaptureResult(${jsonEncode(toJson())})';
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

/// The apps.list result changed: an app's resolved icon became available or changed (for example a web app's icon finished downloading), or the daemon reloaded its app list after a switch installed or removed apps, or apps.set_permission changed a permission. Call apps.list again.
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
final class OskChangedEvent extends SessionEvent {
  const OskChangedEvent({required this.visible, this.password});

  final bool visible;

  /// The keyboard is up for a password field. Absent when false.
  final bool? password;

  factory OskChangedEvent.fromJson(Map<String, dynamic> json) =>
      OskChangedEvent(
        visible: json['visible'] as bool,
        password: json['password'] == null ? null : json['password'] as bool,
      );

  Map<String, dynamic> toJson() => {'visible': visible, 'password': ?password};

  @override
  String get name => 'osk_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is OskChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'OskChangedEvent(${jsonEncode(toJson())})';
}

/// Relayed from the system service. The box's time zone changed (time_zone.set, or a rollback restored another zone): the new zone and its offsets, as time_zone.get.
final class TimeZoneChangedEvent extends SessionEvent {
  const TimeZoneChangedEvent({
    required this.zone,
    required this.offsetS,
    required this.standardOffsetS,
    required this.offsetValidUntil,
  });

  /// An IANA time zone name (UTC, America/Chicago): '/'-separated parts that each start with an ASCII capital letter, followed by ASCII letters, digits, '_', '+' and '-' (the system repo's rule; it keeps out '..', absolute paths and tzdata's other files).
  final String zone;

  /// Seconds east of UTC.
  final int offsetS;

  /// Seconds east of UTC.
  final int standardOffsetS;

  /// Unix time of the next offset change; null when there is none.
  final int? offsetValidUntil;

  factory TimeZoneChangedEvent.fromJson(Map<String, dynamic> json) =>
      TimeZoneChangedEvent(
        zone: json['zone'] as String,
        offsetS: json['offset_s'] as int,
        standardOffsetS: json['standard_offset_s'] as int,
        offsetValidUntil: json['offset_valid_until'] == null
            ? null
            : json['offset_valid_until'] as int,
      );

  Map<String, dynamic> toJson() => {
    'zone': zone,
    'offset_s': offsetS,
    'standard_offset_s': standardOffsetS,
    'offset_valid_until': offsetValidUntil,
  };

  @override
  String get name => 'time_zone_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is TimeZoneChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'TimeZoneChangedEvent(${jsonEncode(toJson())})';
}

/// Relayed from the system service. A job was started (by any caller). Subject (what the job is about) and started_at.
final class JobStartedEvent extends SessionEvent {
  const JobStartedEvent({
    required this.jobId,
    required this.kind,
    required this.uid,
    required this.subject,
    required this.startedAt,
  });

  /// Server-issued job id.
  final String jobId;

  /// unknown: a kind of a later version (a server sends it after a rollback, for a job a later version started).
  final JobKind kind;
  final int uid;

  /// What a job is about. Every field optional; which ones each kind sets: README, What a job is about.
  final JobSubject subject;
  final int startedAt;

  factory JobStartedEvent.fromJson(Map<String, dynamic> json) =>
      JobStartedEvent(
        jobId: json['job_id'] as String,
        kind: JobKind.fromJson(json['kind'] as String),
        uid: json['uid'] as int,
        subject: JobSubject.fromJson(
          (json['subject'] as Map).cast<String, dynamic>(),
        ),
        startedAt: json['started_at'] as int,
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'kind': kind.toJson(),
    'uid': uid,
    'subject': subject.toJson(),
    'started_at': startedAt,
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

/// Relayed from the system service. A job reached a stage or made progress (at most 4 per second), and at least every 2 s while the job runs (a heartbeat repeats the latest values). percent where meaningful: downloading and building (never goes back within a stage run, below 100 while nix runs), measuring. last_activity_at: the last time the job's process printed anything (nix log lines included). subject only when it changed during the job (it replaces the one from job_started). stage is left out when it is unknown (a job a later version started, after a rollback).
final class JobProgressEvent extends SessionEvent {
  const JobProgressEvent({
    required this.jobId,
    required this.kind,
    this.stage,
    this.percent,
    this.detail,
    required this.startedAt,
    this.lastActivityAt,
    this.subject,
  });

  /// Server-issued job id.
  final String jobId;

  /// unknown: a kind of a later version (a server sends it after a rollback, for a job a later version started).
  final JobKind kind;

  /// unknown: a stage of a later version (a server may send it after a rollback, in job_failed's stage; job_progress and jobs.get leave it out).
  final Stage? stage;
  final int? percent;
  final ProgressDetail? detail;
  final int startedAt;
  final int? lastActivityAt;

  /// What a job is about. Every field optional; which ones each kind sets: README, What a job is about.
  final JobSubject? subject;

  factory JobProgressEvent.fromJson(Map<String, dynamic> json) =>
      JobProgressEvent(
        jobId: json['job_id'] as String,
        kind: JobKind.fromJson(json['kind'] as String),
        stage: json['stage'] == null
            ? null
            : Stage.fromJson(json['stage'] as String),
        percent: json['percent'] == null ? null : json['percent'] as int,
        detail: json['detail'] == null
            ? null
            : ProgressDetail.fromJson(
                (json['detail'] as Map).cast<String, dynamic>(),
              ),
        startedAt: json['started_at'] as int,
        lastActivityAt: json['last_activity_at'] == null
            ? null
            : json['last_activity_at'] as int,
        subject: json['subject'] == null
            ? null
            : JobSubject.fromJson(
                (json['subject'] as Map).cast<String, dynamic>(),
              ),
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'kind': kind.toJson(),
    if (stage != null) 'stage': stage!.toJson(),
    'percent': ?percent,
    if (detail != null) 'detail': detail!.toJson(),
    'started_at': startedAt,
    'last_activity_at': ?lastActivityAt,
    if (subject != null) 'subject': subject!.toJson(),
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

/// Relayed from the system service. A job ended. session_restart_required: the switch replaced the system service's API or the session daemon, so the launcher should offer a session restart. Subject (as the job last knew it), started_at, finished_at.
final class JobFinishedEvent extends SessionEvent {
  const JobFinishedEvent({
    required this.jobId,
    required this.kind,
    required this.ok,
    this.error,
    this.result,
    required this.sessionRestartRequired,
    required this.subject,
    required this.startedAt,
    required this.finishedAt,
  });

  /// Server-issued job id.
  final String jobId;

  /// unknown: a kind of a later version (a server sends it after a rollback, for a job a later version started).
  final JobKind kind;
  final bool ok;

  /// A JSON-RPC error object (codes from this document's errors).
  final ErrorObject? error;

  /// The shape is set by the job's kind, not by its fields: update_check jobs: an UpdateCheckResult; jobs that change the system: an AppliedResult; storage_measure: a MeasuredResult; cleanup_system and cleanup_profiles: a CleanedResult; channel_check: a ChannelCheckResult. Pick the shape by kind; a later minor may add a kind with a new shape that has the same required fields as another (a kind this client does not know: ignore the result).
  final Object? result;
  final bool sessionRestartRequired;

  /// What a job is about. Every field optional; which ones each kind sets: README, What a job is about.
  final JobSubject subject;
  final int startedAt;
  final int finishedAt;

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
        subject: JobSubject.fromJson(
          (json['subject'] as Map).cast<String, dynamic>(),
        ),
        startedAt: json['started_at'] as int,
        finishedAt: json['finished_at'] as int,
      );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'kind': kind.toJson(),
    'ok': ok,
    if (error != null) 'error': error!.toJson(),
    'result': ?result,
    'session_restart_required': sessionRestartRequired,
    'subject': subject.toJson(),
    'started_at': startedAt,
    'finished_at': finishedAt,
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

  factory BluetoothConfirmEventMode.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

/// What store.list returns may have changed: an apps job started or finished, any other job that switched the system finished, or an update check changed more_after_update, or a catalog app's icon was resolved (icon.path), or apps.set_permission changed a permission. Query store.list again.
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

class SwitchProgressEventApp {
  const SwitchProgressEventApp({required this.id, required this.name});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;
  final String name;

  factory SwitchProgressEventApp.fromJson(Map<String, dynamic> json) =>
      SwitchProgressEventApp(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is SwitchProgressEventApp &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SwitchProgressEventApp(${jsonEncode(toJson())})';
}

/// A profile switch is closing apps, closing Steam, ending the session, or was cancelled. app: the app being closed.
final class SwitchProgressEvent extends SessionEvent {
  const SwitchProgressEvent({required this.stage, this.app});

  final SwitchStage stage;
  final SwitchProgressEventApp? app;

  factory SwitchProgressEvent.fromJson(Map<String, dynamic> json) =>
      SwitchProgressEvent(
        stage: SwitchStage.fromJson(json['stage'] as String),
        app: json['app'] == null
            ? null
            : SwitchProgressEventApp.fromJson(
                (json['app'] as Map).cast<String, dynamic>(),
              ),
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

class SwitchBlockedEventApp {
  const SwitchBlockedEventApp({required this.id, required this.name});

  /// App identifier: an apps.list id, or for running apps started by command or Steam URL 'cmd-&lt;n&gt;' / 'steam-&lt;appid&gt;'. 'steam' is Steam itself (Big Picture and its other windows).
  final String id;
  final String name;

  factory SwitchBlockedEventApp.fromJson(Map<String, dynamic> json) =>
      SwitchBlockedEventApp(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is SwitchBlockedEventApp &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'SwitchBlockedEventApp(${jsonEncode(toJson())})';
}

/// An app has not closed after waited_s seconds. Show 'X isn't responding (N s). Force-closing it may lose unsaved data.' with Keep waiting (session.switch_wait), Force close (session.switch_force_close) and Cancel switch (session.switch_cancel). Nothing is killed until Force close.
final class SwitchBlockedEvent extends SessionEvent {
  const SwitchBlockedEvent({required this.app, required this.waitedS});

  final SwitchBlockedEventApp app;
  final int waitedS;

  factory SwitchBlockedEvent.fromJson(Map<String, dynamic> json) =>
      SwitchBlockedEvent(
        app: SwitchBlockedEventApp.fromJson(
          (json['app'] as Map).cast<String, dynamic>(),
        ),
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

/// The sleep lock went up (before the box sleeps, for a locked profile) or down (session.unlock).
final class LockChangedEvent extends SessionEvent {
  const LockChangedEvent({required this.locked});

  final bool locked;

  factory LockChangedEvent.fromJson(Map<String, dynamic> json) =>
      LockChangedEvent(locked: json['locked'] as bool);

  Map<String, dynamic> toJson() => {'locked': locked};

  @override
  String get name => 'lock_changed';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is LockChangedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'LockChangedEvent(${jsonEncode(toJson())})';
}

enum GreeterPromptEventKind {
  pin('pin'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const GreeterPromptEventKind(this.value);
  final String value;

  factory GreeterPromptEventKind.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

/// Greeter mode: greetd asks for the profile's PIN; show the PIN pad.
final class GreeterPromptEvent extends SessionEvent {
  const GreeterPromptEvent({required this.kind});

  final GreeterPromptEventKind kind;

  factory GreeterPromptEvent.fromJson(Map<String, dynamic> json) =>
      GreeterPromptEvent(
        kind: GreeterPromptEventKind.fromJson(json['kind'] as String),
      );

  Map<String, dynamic> toJson() => {'kind': kind.toJson()};

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

/// Greeter mode: the login ended: ok (the session starts, the greeter goes away) or not (wrong PIN; locked_s during the backoff: 'Too many tries. Try again in N seconds'). Reboot_required: true when the admin profile's PIN is refused until the box restarts (10 wrong tries this boot).
final class GreeterResultEvent extends SessionEvent {
  const GreeterResultEvent({
    required this.ok,
    this.lockedS,
    this.rebootRequired,
  });

  final bool ok;
  final int? lockedS;
  final bool? rebootRequired;

  factory GreeterResultEvent.fromJson(Map<String, dynamic> json) =>
      GreeterResultEvent(
        ok: json['ok'] as bool,
        lockedS: json['locked_s'] == null ? null : json['locked_s'] as int,
        rebootRequired: json['reboot_required'] == null
            ? null
            : json['reboot_required'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'locked_s': ?lockedS,
    'reboot_required': ?rebootRequired,
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

/// The profiles changed (a profile job, a rename, a PIN, lock or appearance change); profiles as system.profiles.list's.
final class ProfilesChangedEvent extends SessionEvent {
  const ProfilesChangedEvent({required this.profiles});

  final List<ProfileInfo> profiles;

  factory ProfilesChangedEvent.fromJson(Map<String, dynamic> json) =>
      ProfilesChangedEvent(
        profiles: (json['profiles'] as List)
            .map(
              (x) => ProfileInfo.fromJson((x as Map).cast<String, dynamic>()),
            )
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

/// The button pressed during input.capture (the physical button: a, b, x, y, lb, rb, lt, rt, view, menu, or a direction up, down, left, right), or null when capture ended without one (Guide, 10 s).
final class InputCapturedEvent extends SessionEvent {
  const InputCapturedEvent({required this.button});

  final String? button;

  factory InputCapturedEvent.fromJson(Map<String, dynamic> json) =>
      InputCapturedEvent(
        button: json['button'] == null ? null : json['button'] as String,
      );

  Map<String, dynamic> toJson() => {'button': button};

  @override
  String get name => 'input_captured';

  @override
  Map<String, dynamic> get params => toJson();

  @override
  bool operator ==(Object other) =>
      other is InputCapturedEvent &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'InputCapturedEvent(${jsonEncode(toJson())})';
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

class NoAppDisplayData {
  const NoAppDisplayData({required this.apps});

  final List<RunningApp> apps;

  factory NoAppDisplayData.fromJson(Map<String, dynamic> json) =>
      NoAppDisplayData(
        apps: (json['apps'] as List)
            .map((x) => RunningApp.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'apps': apps.map((x) => x.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is NoAppDisplayData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'NoAppDisplayData(${jsonEncode(toJson())})';
}

enum PermissionDeniedDataReason {
  seat('seat'),
  polkit('polkit'),
  peer('peer'),
  profile('profile'),
  starter('starter'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const PermissionDeniedDataReason(this.value);
  final String value;

  factory PermissionDeniedDataReason.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

enum JobFailedDataReason {
  cancelled('cancelled'),
  unreachable('unreachable'),
  notReady('not_ready'),
  refused('refused'),
  timeout('timeout'),
  notConnected('not_connected'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const JobFailedDataReason(this.value);
  final String value;

  factory JobFailedDataReason.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class JobFailedData {
  const JobFailedData({
    required this.stage,
    required this.logHint,
    this.reason,
  });

  /// unknown: a stage of a later version (a server may send it after a rollback, in job_failed's stage; job_progress and jobs.get leave it out).
  final Stage stage;
  final String logHint;
  final JobFailedDataReason? reason;

  factory JobFailedData.fromJson(Map<String, dynamic> json) => JobFailedData(
    stage: Stage.fromJson(json['stage'] as String),
    logHint: json['log_hint'] as String,
    reason: json['reason'] == null
        ? null
        : JobFailedDataReason.fromJson(json['reason'] as String),
  );

  Map<String, dynamic> toJson() => {
    'stage': stage.toJson(),
    'log_hint': logHint,
    if (reason != null) 'reason': reason!.toJson(),
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
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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
  channelRev('channel_rev'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const StateConflictDataReason(this.value);
  final String value;

  factory StateConflictDataReason.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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
  olderThanSeen('older_than_seen'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const UpdateVerificationFailedDataReason(this.value);
  final String value;

  factory UpdateVerificationFailedDataReason.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

  factory PinRequiredDataPin.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

  String toJson() => value;
}

class PinRequiredData {
  const PinRequiredData({
    required this.pin,
    this.retryAfterMs,
    this.rebootRequired,
  });

  final PinRequiredDataPin pin;
  final int? retryAfterMs;
  final bool? rebootRequired;

  factory PinRequiredData.fromJson(Map<String, dynamic> json) =>
      PinRequiredData(
        pin: PinRequiredDataPin.fromJson(json['pin'] as String),
        retryAfterMs: json['retry_after_ms'] == null
            ? null
            : json['retry_after_ms'] as int,
        rebootRequired: json['reboot_required'] == null
            ? null
            : json['reboot_required'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'pin': pin.toJson(),
    'retry_after_ms': ?retryAfterMs,
    'reboot_required': ?rebootRequired,
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
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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
  base('base'),
  jellyfin('jellyfin'),
  plex('plex'),
  tailscale('tailscale'),
  cloudflare('cloudflare'),

  /// A value this client does not know (newer daemon).
  unknown('unknown');

  const UnavailableDataService(this.value);
  final String value;

  factory UnavailableDataService.fromJson(String value) =>
      values.firstWhere((e) => e.value == value, orElse: () => unknown);

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

/// Typed calls for every method of the session API.
///
/// Implementors provide [rpc], which sends one request and returns its
/// result object (or throws).
mixin SessionApiMethods {
  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params);

  /// Version handshake. Must be the first request on a connection.
  ///
  /// The client sends the API version it was built against. The server takes the same major and an equal or lower minor. The result carries the negotiated version: the client's. On a mismatch the server answers with version_mismatch and closes the connection; it reads api_version first, so a client of another version gets version_mismatch even when its params have fields this server does not know. The client name 'hinteros-osk' is reserved for the on-screen keyboard: such connections receive input_nav while the keyboard is visible, and only then.
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

  /// Apps the launcher can show and launch: the built-in 'steam' entry (Steam's Big Picture mode), then the apps from the daemon's config, or a fixed stub list when none are configured.
  ///
  /// Installed Steam games are listed by games.list, not here.
  Future<AppsListResult> appsList([
    AppsListParams params = const AppsListParams(),
  ]) async => AppsListResult.fromJson(await rpc('apps.list', params.toJson()));

  /// Grant or deny one optional permission of an app, for this profile. Applies the next time the app starts.
  ///
  /// id: an installed app (apps.list) or a catalog app that is not installed yet (store.list): the launcher calls this for each permission switched off on the install sheet, then system.apps.install. The choice is kept per profile ($XDG_STATE_HOME/hinteros/permissions.json); only denials are stored, so an app without a stored choice has every permission. Emits apps_changed and store_changed. Errors: app_not_found (not installed and not in the catalog), unknown_permission (the app does not declare it, or it is not enforced on this box), permission_required (granted false for a required one). Granting a required one is accepted and changes nothing.
  Future<AppsSetPermissionResult> appsSetPermission(
    AppsSetPermissionParams params,
  ) async => AppsSetPermissionResult.fromJson(
    await rpc('apps.set_permission', params.toJson()),
  );

  /// How many apps can run at once. Each app the daemon starts gets an X display of its own, from a fixed set.
  ///
  /// count: the setting, which the next session starts with (kept per profile in $XDG_STATE_HOME/hinteros/app-displays; default 4). active: the number this session started with (gamescope makes its Xwaylands at start only), null when apps do not get displays of their own (no gamescope; then nothing limits them). Steam and its games never use one. A display is free again once every process of its app has ended. apps.launch answers no_app_display while all are in use.
  Future<AppsDisplaysGetResult> appsDisplaysGet([
    AppsDisplaysGetParams params = const AppsDisplaysGetParams(),
  ]) async => AppsDisplaysGetResult.fromJson(
    await rpc('apps.displays.get', params.toJson()),
  );

  /// Set how many apps can run at once. Applies at the next session start (session.restart).
  ///
  /// Saves count for this profile and answers with apps.displays.get's result: active stays what this session started with, so count != active means a session restart is needed. invalid_params for a count outside min..max.
  Future<AppsDisplaysSetResult> appsDisplaysSet(
    AppsDisplaysSetParams params,
  ) async => AppsDisplaysSetResult.fromJson(
    await rpc('apps.displays.set', params.toJson()),
  );

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
  /// Exactly one of: 'id' (an app from apps.list), 'command' (argv, run as the session user), or 'url' (a Steam game, handed to the running Steam client; use it for games.list entries). If the app is already running it is focused instead and the result describes the running instance. Its windows are shown as soon as they appear; until then the launcher stays visible. Progress is reported through app_started, focus_changed and app_exited. The built-in id 'steam' opens Steam's Big Picture mode (steam://open/bigpicture, or 'steam -gamepadui' when Steam is not running) and shows Steam's own windows; it runs as the app 'steam' with source 'steam_client'. A Steam game's name comes from its Steam library manifest when it is installed. An app the daemon starts itself (from apps.list, or a command) gets an X display of its own (apps.displays.get); while all are in use it is not started: no_app_display names the running apps that hold one (close one with apps.close, wait for its app_exited, then launch again).
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
  /// The on-screen keyboard is a separate client (hinteros-osk) whose window the daemon shows as a gamescope overlay; it never takes focus, so typed keys reach the focused app. While it is visible, InputPlumber is in intercept mode ALL and input_nav goes only to the connection whose hello client name is 'hinteros-osk' (not to the launcher). osk_changed follows if the visibility changed. Showing it again does nothing. The user can also summon it with the controller (Guide + Y by default, or A on a focused text field in a keyboard-profile Firefox app), and B hides it whatever has focus (the keyboard client never receives back while visible).
  Future<OskShowResult> oskShow([
    OskShowParams params = const OskShowParams(),
  ]) async => OskShowResult.fromJson(await rpc('osk.show', params.toJson()));

  /// Hide the on-screen keyboard.
  ///
  /// Restores the previous input routing: InputPlumber's mode for whatever has focus, input_nav to the launcher while it has focus. osk_changed follows if the visibility changed. Home and focus changes also hide it.
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
  /// changes is a closed, typed object: each settable state.json field is a property here (bool, enum, bounded integer), never free-form. It has no properties (SSH, base and channel have their own methods), so any field is invalid_params with data {field, reason: unknown_field}, and an empty changes object returns job_id null. revision must equal settings.get's, else state_conflict. The service writes state.json from its own typed state, never the caller's bytes.
  Future<SystemSettingsSetResult> systemSettingsSet(
    SystemSettingsSetParams params,
  ) async => SystemSettingsSetResult.fromJson(
    await rpc('system.settings.set', params.toJson()),
  );

  /// Relayed to the system service's ssh.set. Turn SSH (sshd) on or off (job). Action org.hinteros.system.ssh, which needs the admin password (auth_admin).
  ///
  /// Login over SSH is the admin account with its password; the system repo configures sshd. polkit's default for this action is auth_admin. The service checks it with AllowUserInteraction: polkit asks the authentication agent registered for the calling process (the session daemon's, which shows the launcher a password prompt) and the call waits until the user answered (at most 5 minutes). Without an agent the call gets authentication_required; a cancelled or timed-out prompt also gives authentication_required, too many wrong passwords permission_denied (reason polkit). Returns job_id null if SSH already is in that state.
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
  ///
  /// The admin profile's PIN is needed in admin_pin (pin_required {pin: admin} when it is missing or wrong, or when there is no admin profile yet); an admin profile without a PIN yet passes. Not needed from root.
  Future<SystemHardwareRedetectResult> systemHardwareRedetect([
    SystemHardwareRedetectParams params = const SystemHardwareRedetectParams(),
  ]) async => SystemHardwareRedetectResult.fromJson(
    await rpc('system.hardware.redetect', params.toJson()),
  );

  /// Relayed to the system service's rollback. Switch to an earlier generation (default: the one before the current), then restore /etc/hinteros from its snapshot (job). Action org.hinteros.system.rollback.
  ///
  /// The admin profile's PIN is needed in admin_pin (pin_required {pin: admin} when it is missing or wrong, or when there is no admin profile yet); an admin profile without a PIN yet passes. Not needed from root. After the switch and the apps stage, box features that the owners' current app envs need and the restored generation lacks are turned back on in a box stage: the apply flow on the restored configuration with requirements = what the envs need (a second, mostly cached build; a new generation). The result then lists them in features_readded; generations.list names them beforehand per generation (readds_features). If that build fails the job fails at stage box (the rollback itself stays).
  Future<SystemRollbackResult> systemRollback([
    SystemRollbackParams params = const SystemRollbackParams(),
  ]) async => SystemRollbackResult.fromJson(
    await rpc('system.rollback', params.toJson()),
  );

  /// Relayed to the system service's update.check. Look for a newer signed revision of the channel (job), or, within 60 s of the last check, return that result without a job. Action org.hinteros.system.update.check.
  ///
  /// The job lists the channel branch (git ls-remote of the URL from the running generation's channel table), fetches it into a root-owned bare repo, verifies the tip's SSH signature against the allowed signers shipped in the running generation, requires it to descend from the locked revision, and reads the highest Security: &lt;low|medium|high|critical&gt; trailer among the new commits. It also requires the tip to descend from the newest verified tip this box saw on the branch (older_than_seen), and fetches and verifies the other channels' branches of the table to record their newest verified tips (root-only state that rollbacks and channel switches never lower; their failures do not fail the check). The job's result is an UpdateCheckResult; failures are job_failed, update_unreachable or update_verification_failed in job_finished.error.
  Future<SystemUpdateCheckResult> systemUpdateCheck([
    SystemUpdateCheckParams params = const SystemUpdateCheckParams(),
  ]) async => SystemUpdateCheckResult.fromJson(
    await rpc('system.update.check', params.toJson()),
  );

  /// Relayed to the system service's update.apply. Install the revision found by the last update.check (job). Action org.hinteros.system.update.apply.
  ///
  /// rev must equal the last verified check result's available.rev for the current channel and locked revision, else state_conflict. The job re-verifies it, locks the hinteros input to ?rev=&lt;rev&gt; (never re-fetching the branch) and runs the apply flow. The admin profile's PIN is needed in admin_pin, from every profile (the guest's included): pin_required {pin: admin} when it is missing or wrong, or when there is no admin profile yet; an admin profile without a PIN yet passes. Not needed from root. The PIN is checked before rev is compared with the last check. system.update.check needs no PIN.
  Future<SystemUpdateApplyResult> systemUpdateApply(
    SystemUpdateApplyParams params,
  ) async => SystemUpdateApplyResult.fromJson(
    await rpc('system.update.apply', params.toJson()),
  );

  /// Relayed to the system service's channel.check. Verify the tip of another channel before switching to it (job). Action org.hinteros.system.update.check (no PIN).
  ///
  /// The job fetches the target channel's branch (URL from the running generation's channel table), verifies the tip's SSH signature against the allowed signers shipped in the running generation, and requires it to descend from (or equal) the newest verified tip this box saw on that branch (update_verification_failed {reason: older_than_seen} otherwise). It does not need to descend from the locked revision: older is true when it does not (the switch may go back to an older version). The job's result is a ChannelCheckResult; the launcher shows target.version and target.date and asks the owner to confirm, then calls channel.set with target.rev. Returns job_id null if the channel is already the current one. Failures are job_failed, update_unreachable or update_verification_failed in job_finished.error.
  Future<SystemChannelCheckResult> systemChannelCheck(
    SystemChannelCheckParams params,
  ) async => SystemChannelCheckResult.fromJson(
    await rpc('system.channel.check', params.toJson()),
  );

  /// Relayed to the system service's channel.set. Follow another channel (job), at the revision channel.check verified. Action org.hinteros.system.channel.
  ///
  /// The URL comes from the running generation's channel table, never from params. Returns job_id null if the channel is already the current one. Otherwise rev is needed and must equal the last channel.check result's target.rev for this channel and the locked revision, else state_conflict {reason: channel_rev}: the owner confirmed that version. The job re-verifies rev (an allowed signer; it must descend from the newest verified tip this box saw on the target branch, else update_verification_failed {reason: older_than_seen}), locks the hinteros input to it on the target branch and runs the apply flow. rev may be older than the locked revision (beta to stable). The admin profile's PIN is needed in admin_pin (pin_required {pin: admin} when it is missing or wrong, or when there is no admin profile yet); an admin profile without a PIN yet passes. Not needed from root. The PIN is checked first.
  Future<SystemChannelSetResult> systemChannelSet(
    SystemChannelSetParams params,
  ) async => SystemChannelSetResult.fromJson(
    await rpc('system.channel.set', params.toJson()),
  );

  /// Relayed to the system service's base.set. Switch the nixpkgs base (job). Action org.hinteros.system.channel. A base that is not built is refused: unavailable {service: base, reason: not_built} (only unstable today). unstable to stable needs acknowledge_downgrade: true.
  ///
  /// The admin profile's PIN is needed in admin_pin (pin_required {pin: admin} when it is missing or wrong, or when there is no admin profile yet); an admin profile without a PIN yet passes. Not needed from root. The PIN is checked before anything else, also when the base is already the requested one.
  Future<SystemBaseSetResult> systemBaseSet(SystemBaseSetParams params) async =>
      SystemBaseSetResult.fromJson(
        await rpc('system.base.set', params.toJson()),
      );

  /// Relayed to the system service's apps.install. Install Store apps (job). Action org.hinteros.system.apps.
  ///
  /// ids (1 to 8 catalog ids) must be in the running generation's catalog index (/run/current-system/sw/share/hinteros/catalog.json, never the caller's copy) with status available; their depends are added (transitively). Ids already installed are skipped; if nothing is left the result is job_id null. A conflict between a new app and an installed or requested one is app_conflict. Every new app with vendor terms needs accepted_terms[id] equal to the catalog's terms.version, else terms_required (the box records the acceptance: id, version, time, uid and profile, in the audit log and /var/lib/hinteros/terms-accepted.json). revision is the app revision from apps.list (state_conflict otherwise), and the apps are installed into the caller's own profile (a new generation of its Nix profile, no system rebuild unless a box feature must be turned on first: stage box). Free disk space must cover the new apps' sizeMiB plus the usual rebuild margin (insufficient_resources). The job writes state.json's apps from the service's typed state and runs the apply flow.
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

  /// Relayed to the system service's apps.list. The caller's own apps: its current app env.
  ///
  /// Read-only. The caller is resolved from its uid: a profile (or the guest). revision stands for the current app generation; pass it to apps.install/apps.remove as revision. needs_terms: ids whose vendor terms this profile has not accepted at the catalog's current version (apps that came with the starter set); the launcher shows the terms on first launch and calls apps.accept_terms. A spare account gets an empty list.
  Future<SystemAppsListResult> systemAppsList([
    SystemAppsListParams params = const SystemAppsListParams(),
  ]) async => SystemAppsListResult.fromJson(
    await rpc('system.apps.list', params.toJson()),
  );

  /// Relayed to the system service's apps.generations. The caller's app generations, newest first.
  ///
  /// Read-only. Every generation of the caller's Nix profile of apps (the newest 3 plus the current one are kept), with the ids of its env and the system revision it was built against. apps.rollback takes one of them.
  Future<SystemAppsGenerationsResult> systemAppsGenerations([
    SystemAppsGenerationsParams params = const SystemAppsGenerationsParams(),
  ]) async => SystemAppsGenerationsResult.fromJson(
    await rpc('system.apps.generations', params.toJson()),
  );

  /// Relayed to the system service's apps.rollback. Switch the caller's apps back to an earlier generation (job). Action org.hinteros.system.apps.
  ///
  /// generation must be one of apps.generations and not the current one (not_found otherwise). If its env needs box features that are off, the job first runs the box stage (a system rebuild). Job kind apps_rollback.
  Future<SystemAppsRollbackResult> systemAppsRollback(
    SystemAppsRollbackParams params,
  ) async => SystemAppsRollbackResult.fromJson(
    await rpc('system.apps.rollback', params.toJson()),
  );

  /// Relayed to the system service's apps.accept_terms. Accept an installed app's vendor terms for the caller's profile. Action org.hinteros.system.apps.
  ///
  /// For apps that reached the profile without an acceptance (the starter set): id must be in the caller's env and have terms, version must be the running catalog's terms.version (invalid_params otherwise). Records {version, accepted_at, by: &lt;user&gt;, profile: &lt;id&gt;} in terms-accepted.json and the audit log; then the id leaves apps.list's needs_terms. Accepting what is already accepted is a no-op.
  Future<SystemAppsAcceptTermsResult> systemAppsAcceptTerms(
    SystemAppsAcceptTermsParams params,
  ) async => SystemAppsAcceptTermsResult.fromJson(
    await rpc('system.apps.accept_terms', params.toJson()),
  );

  /// Relayed to the system service's apps.clear_data. Delete a Store app's data in the caller's profile (job apps_clear_data). Action org.hinteros.system.apps.
  ///
  /// id must be a catalog app (installed or not: data a remove left behind). The job deletes the app's dataPaths in the caller's own home, as system.apps.remove {delete_data} does; other profiles' data is never touched. Stop the app first (apps.close {force}). store_changed follows when the job ends (has_data).
  Future<SystemAppsClearDataResult> systemAppsClearData(
    SystemAppsClearDataParams params,
  ) async => SystemAppsClearDataResult.fromJson(
    await rpc('system.apps.clear_data', params.toJson()),
  );

  /// Relayed to the system service's profiles.list. The profiles. Read-only; starts a usage scan when the data is older than an hour.
  ///
  /// Every account of the running state.json that has metadata, with the caller (spares are not listed; first_boot: no admin profile exists).
  Future<SystemProfilesListResult> systemProfilesList([
    SystemProfilesListParams params = const SystemProfilesListParams(),
  ]) async => SystemProfilesListResult.fromJson(
    await rpc('system.profiles.list', params.toJson()),
  );

  /// Relayed to the system service's profiles.create. Create a profile (job, a rebuild that adds the account). Action org.hinteros.system.profiles.create; also on greeter.sock.
  ///
  /// name 1 to 32 characters (trimmed, no control or format characters; duplicates allowed), color one of ProfileColor (default teal), pin 4 to 8 digits, locked as chosen, revision = settings.get's. At 8 profiles: profile_limit. The id is taken from the counter at once (never reused, even if the job fails). On success the job writes the metadata and the PIN hash, gives the account the starter env, and (from the greeter) a one-time token so the greeter enters it without the PIN. Job kind profiles_create.
  Future<SystemProfilesCreateResult> systemProfilesCreate(
    SystemProfilesCreateParams params,
  ) async => SystemProfilesCreateResult.fromJson(
    await rpc('system.profiles.create', params.toJson()),
  );

  /// Relayed to the system service's profiles.setup_admin. First-boot mode: make the caller's spare account the admin profile. No job, no rebuild, no network.
  ///
  /// Only a spare caller, only while no admin profile exists (else permission_denied {reason: profile}). Writes the metadata (admin) and the PIN hash; the account's app profile is set to the starter env right after (a short apps job when the box is idle).
  Future<SystemProfilesSetupAdminResult> systemProfilesSetupAdmin(
    SystemProfilesSetupAdminParams params,
  ) async => SystemProfilesSetupAdminResult.fromJson(
    await rpc('system.profiles.setup_admin', params.toJson()),
  );

  /// Relayed to the system service's profiles.rename. Rename a profile. Own: no PIN; another: the admin PIN.
  ///
  /// pin_required {pin: admin} (with retry_after_ms during the backoff lock) when renaming another profile without the right admin_pin.
  Future<SystemProfilesRenameResult> systemProfilesRename(
    SystemProfilesRenameParams params,
  ) async => SystemProfilesRenameResult.fromJson(
    await rpc('system.profiles.rename', params.toJson()),
  );

  /// Relayed to the system service's profiles.set_appearance. The caller's colour and the appearance mirrored for the picker.
  ///
  /// text_scale 0.5 to 3.0. The picker uses the most accessible combination of all profiles' values.
  Future<SystemProfilesSetAppearanceResult> systemProfilesSetAppearance([
    SystemProfilesSetAppearanceParams params =
        const SystemProfilesSetAppearanceParams(),
  ]) async => SystemProfilesSetAppearanceResult.fromJson(
    await rpc('system.profiles.set_appearance', params.toJson()),
  );

  /// Relayed to the system service's profiles.set_pin. Change the caller's PIN. current_pin is required once a PIN is set (a profile without one sets its first PIN without it).
  ///
  /// pin_required {pin: self} for a missing or wrong current_pin (with the backoff).
  Future<SystemProfilesSetPinResult> systemProfilesSetPin(
    SystemProfilesSetPinParams params,
  ) async => SystemProfilesSetPinResult.fromJson(
    await rpc('system.profiles.set_pin', params.toJson()),
  );

  /// Relayed to the system service's profiles.set_locked. Whether the caller's profile asks for its PIN to enter. Own PIN.
  Future<SystemProfilesSetLockedResult> systemProfilesSetLocked(
    SystemProfilesSetLockedParams params,
  ) async => SystemProfilesSetLockedResult.fromJson(
    await rpc('system.profiles.set_locked', params.toJson()),
  );

  /// Relayed to the system service's profiles.reset_pin. Set another profile's PIN with the admin PIN. The admin profile's own: the admin account's password (polkit org.hinteros.system.profiles.recover, interactive) instead.
  ///
  /// For the admin profile admin_pin is not used; the service asks polkit for org.hinteros.system.profiles.recover with the session daemon's agent (authentication_required when dismissed). The target's backoff is reset.
  Future<SystemProfilesResetPinResult> systemProfilesResetPin(
    SystemProfilesResetPinParams params,
  ) async => SystemProfilesResetPinResult.fromJson(
    await rpc('system.profiles.reset_pin', params.toJson()),
  );

  /// Relayed to the system service's profiles.remove. Remove a profile, its home and its apps (job, a rebuild). Own PIN for yourself, the admin PIN for others; never the admin profile.
  ///
  /// confirm_id must equal id. The job kills every process of the account, rebuilds without it, then deletes the home (no symlink is followed, one filesystem), the PIN, the metadata, the app profile links and the registry entry. A failed or cancelled job deletes nothing. Removing your own profile: end the session first (the launcher switches to the picker). invalid_params {field: id, reason: admin} for the admin profile. pin: the caller's own PIN, to remove the caller's own profile (pin_required {pin: self}). admin_pin: the admin PIN, to remove another profile (pin_required {pin: admin}). Job kind profiles_remove.
  Future<SystemProfilesRemoveResult> systemProfilesRemove(
    SystemProfilesRemoveParams params,
  ) async => SystemProfilesRemoveResult.fromJson(
    await rpc('system.profiles.remove', params.toJson()),
  );

  /// Relayed to the system service's profiles.unlock. The caller's PIN after sleep: the lock screen of a locked profile.
  ///
  /// pin_required {pin: self, retry_after_ms?} when wrong or during the backoff lock.
  Future<SystemProfilesUnlockResult> systemProfilesUnlock(
    SystemProfilesUnlockParams params,
  ) async => SystemProfilesUnlockResult.fromJson(
    await rpc('system.profiles.unlock', params.toJson()),
  );

  /// Relayed to the system service's guest.set. Turn the guest account on or off (job, a rebuild). Admin PIN. Action org.hinteros.system.starter.
  ///
  /// job_id null when it is already so. Job kind guest_set.
  Future<SystemGuestSetResult> systemGuestSet(
    SystemGuestSetParams params,
  ) async => SystemGuestSetResult.fromJson(
    await rpc('system.guest.set', params.toJson()),
  );

  /// Relayed to the system service's display.save_mode. Make a display mode the box's: stored in runtime.json, published as /run/hinteros/gamescope-modes for every profile's session. Action org.hinteros.system.settings.
  Future<SystemDisplaySaveModeResult> systemDisplaySaveMode(
    SystemDisplaySaveModeParams params,
  ) async => SystemDisplaySaveModeResult.fromJson(
    await rpc('system.display.save_mode', params.toJson()),
  );

  /// Relayed to the system service's audio.save_output. Make an audio output the box's: stored in runtime.json, published as /run/hinteros/audio-output. Action org.hinteros.system.settings.
  ///
  /// node is a PipeWire node name.
  Future<SystemAudioSaveOutputResult> systemAudioSaveOutput(
    SystemAudioSaveOutputParams params,
  ) async => SystemAudioSaveOutputResult.fromJson(
    await rpc('system.audio.save_output', params.toJson()),
  );

  /// Relayed to the system service's starter_set.get. The starter set: the apps every new profile and guest session starts with. Read-only.
  Future<SystemStarterSetGetResult> systemStarterSetGet([
    SystemStarterSetGetParams params = const SystemStarterSetGetParams(),
  ]) async => SystemStarterSetGetResult.fromJson(
    await rpc('system.starter_set.get', params.toJson()),
  );

  /// Relayed to the system service's starter_set.set. Change the starter set (job). Admin PIN; ids must be apps the admin profile has now. Action org.hinteros.system.starter.
  ///
  /// 0 to 16 ids, each in the admin profile's current env, else invalid_params {field: ids, reason: not_in_admin_profile}. The job builds the new starter env (an evaluation only), with the box stage when a feature is off. Only profiles and guest sessions created afterwards get it. Job kind starter_set.
  Future<SystemStarterSetSetResult> systemStarterSetSet(
    SystemStarterSetSetParams params,
  ) async => SystemStarterSetSetResult.fromJson(
    await rpc('system.starter_set.set', params.toJson()),
  );

  /// Relayed to the system service's storage.get. the last storage measurement (storage.md): the disk, the top level of the ring, every profile's total, the system and apps breakdown, garbage and the clean-up estimates. Read-only, open to every caller.
  ///
  /// Null until the first storage_measure job has finished. Kept in /var/lib/hinteros/storage.json (root, 0600) with its time. Never contains a file, folder or Steam game name or an app id: profile and guest nodes have no children here (storage.tree gives a home's detailed tree). estimates.system[keep-1] and estimates.profiles[keep-1] (keep 1 to 10) say how many generations storage.cleanup_system / storage.cleanup_profiles with that keep would remove now and about how many bytes it frees (garbage_bytes included; NAR sizes), from this measurement.
  Future<SystemStorageGetResult> systemStorageGet([
    SystemStorageGetParams params = const SystemStorageGetParams(),
  ]) async => SystemStorageGetResult.fromJson(
    await rpc('system.storage.get', params.toJson()),
  );

  /// Relayed to the system service's storage.measure. measure what uses the disk (job storage_measure). Any profile or the guest; no PIN. Action org.hinteros.system.settings.
  ///
  /// A storage_measure job that is already running is the answer (its job_id, no new job); another job running is job_busy. Stages preparing, measuring (with percent), finishing; cancellable at any time (the last measurement stays). Measures: statvfs of the store's filesystem; nix path-info --all -s (NAR sizes) and nix-store --gc --print-live (garbage = all minus live); nix-store -qR of every system and app generation; every home with a walk that never follows a symlink, never leaves the home's filesystem and never reads a file (only Steam's libraryfolders.vdf and appmanifest_*.acf, for the games' names). The result is {measured_at}; then call storage.get. Nothing a caller can read (events, results, the job's log) names a file of a home.
  Future<SystemStorageMeasureResult> systemStorageMeasure([
    SystemStorageMeasureParams params = const SystemStorageMeasureParams(),
  ]) async => SystemStorageMeasureResult.fromJson(
    await rpc('system.storage.measure', params.toJson()),
  );

  /// Relayed to the system service's storage.tree. one home's detailed tree from the last measurement: its folders and its Steam games. The caller's own home: open; another profile's or the guest's: the admin PIN. Action org.hinteros.system.settings.
  ///
  /// id: a profile id or guest (else invalid_params {field: id, reason: bad_format}). The caller's own account (or the guest asking for guest) needs no PIN; anything else needs admin_pin, checked like every box-wide action (pin_required {pin: admin} when missing or wrong, or without an admin profile; an admin profile without a PIN yet passes; root is exempt). not_found: nothing measured yet, or that home was not measured (measure again). The root is kind profile (with id) or guest; its bytes equal the top level's. Children: steam (its children: steam_game, one per installed game, named from appmanifest_&lt;appid&gt;.acf in each Steam library folder inside the home; the game folders are not counted again among the folders), dir (recursively) and files (files directly in a folder, and folders too small or deep to show). At most 6 folder levels, folders of at least max(1 MiB, 0.5 % of the home), at most 16 per folder, at most 400 nodes; names at most 128 characters, control characters replaced by U+FFFD.
  Future<SystemStorageTreeResult> systemStorageTree(
    SystemStorageTreeParams params,
  ) async => SystemStorageTreeResult.fromJson(
    await rpc('system.storage.tree', params.toJson()),
  );

  /// Relayed to the system service's storage.cleanup_system. clean up the system (job cleanup_system): remove the system generations older than the newest keep (never the running or the booted one), rewrite the boot menu, collect garbage. Admin PIN every time. Action org.hinteros.system.rebuild.
  ///
  /// keep: 1 to 10 (else invalid_params {field: keep, reason: out_of_range}). admin_pin as for every box-wide action. Always a job (garbage is collected even when no generation goes). Stages preparing, cleaning (removing generations with nix-env --delete-generations, then switch-to-configuration boot of the default generation so no boot entry points at a removed one; not cancellable from here), collecting (nix-store --gc), finishing. Result {freed_bytes, generations_removed}: freed_bytes is the store filesystem's free space after minus before. The estimate comes from storage.get's estimates.system. Below 2 the launcher warns that there is no older version to roll back to.
  Future<SystemStorageCleanupSystemResult> systemStorageCleanupSystem(
    SystemStorageCleanupSystemParams params,
  ) async => SystemStorageCleanupSystemResult.fromJson(
    await rpc('system.storage.cleanup_system', params.toJson()),
  );

  /// Relayed to the system service's storage.cleanup_profiles. clean up profiles (job cleanup_profiles): in every profile's app env and the starter set's, remove the generations older than the newest keep (never the current one), then collect garbage. Admin PIN every time. Action org.hinteros.system.rebuild.
  ///
  /// keep: 1 to 10. The guest's env (a single link) is not touched. Stages preparing, cleaning, collecting, finishing; result {freed_bytes, generations_removed}. The estimate comes from storage.get's estimates.profiles. Below 2 the launcher warns that app rollback in those profiles is gone.
  Future<SystemStorageCleanupProfilesResult> systemStorageCleanupProfiles(
    SystemStorageCleanupProfilesParams params,
  ) async => SystemStorageCleanupProfilesResult.fromJson(
    await rpc('system.storage.cleanup_profiles', params.toJson()),
  );

  /// Relayed to the system service's cleanup.get. the automatic clean-up setting (state.json settings.cleanup; defaults when absent: on, weekly, keep 5 and 5). Read-only.
  Future<SystemCleanupGetResult> systemCleanupGet([
    SystemCleanupGetParams params = const SystemCleanupGetParams(),
  ]) async => SystemCleanupGetResult.fromJson(
    await rpc('system.cleanup.get', params.toJson()),
  );

  /// Relayed to the system service's cleanup.set. change the automatic clean-up (job cleanup_set, a rebuild like ssh.set). Admin PIN. Action org.hinteros.system.settings.
  ///
  /// All four fields; keep_system and keep_profiles 1 to 10 (else invalid_params {field, reason: out_of_range}). Writes settings.cleanup {enable, frequency, keepSystem, keepProfiles} to state.json through the apply flow; job_id null when nothing changes (also when it was absent and the defaults are asked for). The system's nix-gc timer and the boot menu limit follow it.
  Future<SystemCleanupSetResult> systemCleanupSet(
    SystemCleanupSetParams params,
  ) async => SystemCleanupSetResult.fromJson(
    await rpc('system.cleanup.set', params.toJson()),
  );

  /// Relayed to the system service's time_zone.get. the box's time zone (state.json settings.timeZone; UTC when absent) and its offsets now. Read-only.
  ///
  /// Offsets come from the system's tzdata (/etc/zoneinfo), the same files /etc/localtime points into. offset_s: seconds east of UTC now (DST included). standard_offset_s: the zone's standard offset now: the lower of its two offsets while it observes DST (so tzdata's negative DST, e.g. Europe/Dublin, gives its winter offset, as the map's bands do), otherwise offset_s. offset_valid_until: Unix time of the next change of offset_s (the next DST change), null when the zone has none. The launcher's clock shows UTC plus offset_s and gets the zone again at offset_valid_until and on time_zone_changed. A zone in state.json that tzdata does not have (or a bad one) reads as UTC.
  Future<SystemTimeZoneGetResult> systemTimeZoneGet([
    SystemTimeZoneGetParams params = const SystemTimeZoneGetParams(),
  ]) async => SystemTimeZoneGetResult.fromJson(
    await rpc('system.time_zone.get', params.toJson()),
  );

  /// Relayed to the system service's time_zone.list. every zone the picker offers: tzdata's zone1970.tab zones plus UTC, sorted by name, each with its offsets now. Read-only.
  ///
  /// Offsets as in time_zone.get. A zone1970.tab entry whose file is missing or unreadable is left out (and logged).
  Future<SystemTimeZoneListResult> systemTimeZoneList([
    SystemTimeZoneListParams params = const SystemTimeZoneListParams(),
  ]) async => SystemTimeZoneListResult.fromJson(
    await rpc('system.time_zone.list', params.toJson()),
  );

  /// Relayed to the system service's time_zone.set. set the box's time zone at once (no job, no rebuild). Admin PIN, except in first-boot mode. Action org.hinteros.system.settings.
  ///
  /// zone: an IANA name that the system's tzdata has (a TZif file under /etc/zoneinfo; UTC always). A badly formed name is invalid_params {field: zone, reason: bad_format}; a well-formed name tzdata does not have is invalid_params {field: zone, reason: unknown}. The admin PIN is needed (pin_required {pin: admin} when it is missing or wrong) except in first-boot mode (no admin profile yet, the rule of profiles.setup_admin). Writes settings.timeZone to state.json (atomically; a running job's own state.json keeps the new zone) and points /etc/localtime at /etc/zoneinfo/&lt;zone&gt; (a new link renamed over the old one), through the oneshot hinteros-time-zone-apply.service (the service waits for it, up to 30 s; else internal_error). Processes started later see the new zone. Then time_zone_changed. The result is the new zone and its offsets; setting the current zone again changes nothing and sends no event.
  Future<SystemTimeZoneSetResult> systemTimeZoneSet(
    SystemTimeZoneSetParams params,
  ) async => SystemTimeZoneSetResult.fromJson(
    await rpc('system.time_zone.set', params.toJson()),
  );

  /// Relayed to the system service's services.list. the Server section: every service the catalog offers (kind service, status available) and every enabled one, with its unit's state and its setup flow's detail. Read-only, open to every caller.
  ///
  /// revision is the hash of state.json (pass it to services.enable/services.disable). status: systemd's ActiveState of the service's unit (jellyfin.service, plex.service, tailscaled.service, hinteros-cloudflared.service; inactive when not loaded), null when the service is off or has no known unit. setup: the catalog's setup flow (null: none, or one this daemon does not know: show only on/off). terms: the vendor terms to show before services.enable (file: the absolute path of the text next to the running catalog). detail: null unless the service is on and has a setup flow; no secrets. Jellyfin: setup_done (the first-run setup by HinterOS is done), url (http://&lt;local IP&gt;:&lt;port&gt;), libraries (from Jellyfin's API on loopback, or the last list a job or read saw while Jellyfin does not answer), users (each profile's Jellyfin user name). Plex: claimed (linked to a Plex account), server_name, url. Tailscale: state from tailscaled (unavailable: it does not answer), name, tailnet IPv4, MagicDNS name, tailnet, key_expiry (Unix seconds; null: never or unknown); all null unless signed in. Cloudflare: token_set, connected (cloudflared has a connection), local_ip (the box's address on its local network, for the private-network route). Each service is asked with a 1 s timeout.
  Future<SystemServicesListResult> systemServicesList([
    SystemServicesListParams params = const SystemServicesListParams(),
  ]) async => SystemServicesListResult.fromJson(
    await rpc('system.services.list', params.toJson()),
  );

  /// Relayed to the system service's services.enable. turn services on (job services_enable, a rebuild). Admin PIN. Action org.hinteros.system.services.
  ///
  /// ids: 1 to 8 different catalog ids, each kind service with status available in the running generation's catalog (not_found: not in the catalog; invalid_params {field: ids, reason: not_a_service | not_available}). Ids already on are skipped; job_id null when nothing is left. revision: services.list's (state_conflict otherwise). A service with vendor terms (Plex) needs accepted_terms[id] equal to the catalog's terms.version (terms_required {id, version}; terms for ids not being turned on: invalid_params {field: accepted_terms, reason: not_requested}); the acceptance is audited and recorded in /var/lib/hinteros/terms-accepted.json by the caller's user, with the admin profile's id. The job writes state.json's services and runs the apply flow (stages preparing, evaluating, downloading, building, activating, finishing); for jellyfin-server it then waits up to 3 minutes for HinterOS's first-run setup (stage configuring) and makes each profile's Jellyfin user (best effort: jellyfin.users.reveal and every Jellyfin job make missing users too). Result: the applied generation.
  Future<SystemServicesEnableResult> systemServicesEnable(
    SystemServicesEnableParams params,
  ) async => SystemServicesEnableResult.fromJson(
    await rpc('system.services.enable', params.toJson()),
  );

  /// Relayed to the system service's services.disable. turn services off (job services_disable, a rebuild), their data deleted on request. Admin PIN. Action org.hinteros.system.services.
  ///
  /// ids: 1 to 8 different ids, each on (not_found otherwise). revision: services.list's. The job writes state.json without them and runs the apply flow. With delete_data (the launcher confirms twice), after a successful switch it deletes each service's catalog stateDirs below /var/lib, and for jellyfin-server also /var/cache/jellyfin and /var/lib/hinteros/services/jellyfin-server (admin password, API key, profile users), as root without following a symlink anywhere and without entering another filesystem; anything outside /var/lib and /var/cache is refused. Media files in /srv/media are never deleted. Without delete_data the data stays and turning the service on again finds it.
  Future<SystemServicesDisableResult> systemServicesDisable(
    SystemServicesDisableParams params,
  ) async => SystemServicesDisableResult.fromJson(
    await rpc('system.services.disable', params.toJson()),
  );

  /// Relayed to the system service's media.folders. one level of folders under /srv/media, for a Jellyfin library. Read-only, open to every caller.
  ///
  /// Without folder_id: the folders directly in /srv/media (an empty list when it does not exist); with it: the folders in that folder. An id is the folder's path relative to /srv/media (no empty, . or .. component, no component starting with a dot, no control characters, at most 1024 bytes; else invalid_params {field: folder_id}). Every component is opened without following symlinks: a symlink is neither listed nor entered (not_found), so no id leads out of /srv/media. Hidden folders, files, symlinks and names that are not UTF-8 are left out. Sorted by name, at most 500. has_children: the folder has folders of its own.
  Future<SystemMediaFoldersResult> systemMediaFolders([
    SystemMediaFoldersParams params = const SystemMediaFoldersParams(),
  ]) async => SystemMediaFoldersResult.fromJson(
    await rpc('system.media.folders', params.toJson()),
  );

  /// Relayed to the system service's jellyfin.libraries.add. add a Jellyfin library on a folder in /srv/media (job jellyfin_library_add). Admin PIN. Action org.hinteros.system.services.
  ///
  /// name: 1 to 64 characters after trimming, no control or format characters, none of /\:*?"&lt;&gt;| (invalid_params {field: name, reason: bad_length | bad_name}); a library with the same name (any case) is invalid_params {field: name, reason: exists} when Jellyfin answers in time, else the job fails. kind: movies, shows, music or mixed (Jellyfin's collection types movies, tvshows, music, and none for mixed). folder: a media.folders id, resolved again (no symlink followed) when the request comes and again in the job (not_found: no such folder). Jellyfin off: unavailable {service: jellyfin, reason: off}; its first-run setup not done: unavailable {service: jellyfin, reason: not_ready}. The job (stages preparing, configuring, finishing) waits up to 90 s for Jellyfin, makes missing profile users, adds the library and starts its scan; job_progress's subject then gains library.id. Failures: job_failed with reason unreachable, not_ready or refused.
  Future<SystemJellyfinLibrariesAddResult> systemJellyfinLibrariesAdd(
    SystemJellyfinLibrariesAddParams params,
  ) async => SystemJellyfinLibrariesAddResult.fromJson(
    await rpc('system.jellyfin.libraries.add', params.toJson()),
  );

  /// Relayed to the system service's jellyfin.libraries.remove. remove a Jellyfin library (job jellyfin_library_remove); the media files stay. Admin PIN. Action org.hinteros.system.services.
  ///
  /// library_id: a library id from services.list (not_found when Jellyfin answers in time and has no such library; else the job fails with reason refused). Jellyfin removes its own folder for the library (links, options), never the media. unavailable as for jellyfin.libraries.add.
  Future<SystemJellyfinLibrariesRemoveResult> systemJellyfinLibrariesRemove(
    SystemJellyfinLibrariesRemoveParams params,
  ) async => SystemJellyfinLibrariesRemoveResult.fromJson(
    await rpc('system.jellyfin.libraries.remove', params.toJson()),
  );

  /// Relayed to the system service's jellyfin.users.reveal. the Jellyfin passwords, for other devices: the admin user's and each profile's (admin PIN; not a job). Action org.hinteros.system.services.
  ///
  /// Makes missing profile users first (one Jellyfin user per profile, not the guest; named after the profile: letters, digits, space and _-'.@+ kept, unique in any case with a number added; not an administrator, no media deletion; random 16-character password), when Jellyfin answers within 3 s. admin: null until HinterOS's first-run setup wrote it. users: every profile that has a user, with the profile's name now. The answer is never logged; the audit records only that it was asked. Jellyfin off: unavailable {service: jellyfin, reason: off}.
  Future<SystemJellyfinUsersRevealResult> systemJellyfinUsersReveal([
    SystemJellyfinUsersRevealParams params =
        const SystemJellyfinUsersRevealParams(),
  ]) async => SystemJellyfinUsersRevealResult.fromJson(
    await rpc('system.jellyfin.users.reveal', params.toJson()),
  );

  /// Relayed to the system service's jellyfin.client_token. a Jellyfin access token for the caller's own profile, so the Jellyfin app on the box signs in by itself (spike S1). No PIN; read-only for the caller (no seat check, no rate limit).
  ///
  /// The profile comes from the caller's uid (SO_PEERCRED): the guest, spare accounts and other users get permission_denied {reason: profile}. Jellyfin off or not set up: unavailable {service: jellyfin, reason: off | not_ready}; Jellyfin does not answer or refuses: unavailable {service: jellyfin, reason: unreachable}; it refuses the profile's sign-in (401) even after the user was made again and its recorded password set back: unavailable {service: jellyfin, reason: sign_in_refused}. The profile's Jellyfin user is made first if it has none. The token is made with POST /Users/AuthenticateByName as device hinteros-&lt;profile id&gt; (Jellyfin ends that device's older token, so a profile has one live token), kept in users.json (root only) and made again when Jellyfin answers 401 to it. Never logged.
  Future<SystemJellyfinClientTokenResult> systemJellyfinClientToken([
    SystemJellyfinClientTokenParams params =
        const SystemJellyfinClientTokenParams(),
  ]) async => SystemJellyfinClientTokenResult.fromJson(
    await rpc('system.jellyfin.client_token', params.toJson()),
  );

  /// Relayed to the system service's plex.claim. link Plex Media Server to the owner's Plex account with a code from plex.tv/claim (job plex_claim). Admin PIN. Action org.hinteros.system.services.
  ///
  /// code: claim- and 20 letters, digits, _ or - (what plex.tv/claim gives; valid about 4 minutes; never logged). Plex off: unavailable {service: plex, reason: off}; already linked: job_id null. The job (stages preparing, configuring, finishing) waits up to 90 s for Plex on 127.0.0.1:32400, posts the code to Plex's own /myplex/claim (Plex exchanges it with plex.tv), and succeeds once Preferences.xml has the account token (at most 30 s). Failures: job_failed with reason unreachable (Plex does not answer) or refused (Plex refused the code, e.g. it expired). Plex libraries are added in Plex's own app afterwards.
  Future<SystemPlexClaimResult> systemPlexClaim(
    SystemPlexClaimParams params,
  ) async => SystemPlexClaimResult.fromJson(
    await rpc('system.plex.claim', params.toJson()),
  );

  /// Relayed to the system service's tailscale.login. sign the box in to Tailscale (job tailscale_login). Admin PIN. Action org.hinteros.system.services.
  ///
  /// Tailscale off: unavailable {service: tailscale, reason: off}; signed in already (Running): job_id null. The job runs tailscale up --reset --json --timeout=600s (the defaults: no exit node, no subnet routes, no Tailscale SSH; --force-reauth when an expired key needs a new sign-in). When Tailscale has the sign-in URL, job_progress has stage signing_in and detail.auth_url (https, at most 512 printable ASCII characters; the launcher shows it as a QR code; jobs.get's detail has it too); a newer URL comes in a new job_progress. The job succeeds when tailscaled is Running (the person signed in, and the tailnet approved the device if it must). jobs.cancel stops the wait. Failures: job_failed with reason timeout (nobody signed in within 10 minutes), refused (the CLI failed; log_hint says why) or unreachable (no tailscale CLI).
  Future<SystemTailscaleLoginResult> systemTailscaleLogin([
    SystemTailscaleLoginParams params = const SystemTailscaleLoginParams(),
  ]) async => SystemTailscaleLoginResult.fromJson(
    await rpc('system.tailscale.login', params.toJson()),
  );

  /// Relayed to the system service's tailscale.logout. sign the box out of Tailscale (job tailscale_logout; tailscale logout). Admin PIN. Action org.hinteros.system.services.
  ///
  /// Tailscale off: unavailable {service: tailscale, reason: off}; signed out already (NeedsLogin): job_id null. Stages preparing, configuring, finishing.
  Future<SystemTailscaleLogoutResult> systemTailscaleLogout([
    SystemTailscaleLogoutParams params = const SystemTailscaleLogoutParams(),
  ]) async => SystemTailscaleLogoutResult.fromJson(
    await rpc('system.tailscale.logout', params.toJson()),
  );

  /// Relayed to the system service's cloudflare.set_token. set the Cloudflare tunnel token and (re)start the tunnel (job cloudflare_set_token). Admin PIN. Action org.hinteros.system.services.
  ///
  /// token: the token of a remotely managed tunnel from the Zero Trust dashboard, checked strictly: at most 512 characters, standard padded base64 of a JSON object with a (account tag, 32 hex digits), t (tunnel id, a UUID), s (secret: base64 of 32 to 256 bytes) and optionally e (endpoint, 1 to 16 lower-case letters), each at most once; other keys are ignored (a later cloudflared may add some); else invalid_params {field: token, reason: bad_length | not_base64 | not_a_token | bad_account | bad_tunnel_id | bad_secret | bad_endpoint}. Never logged. Cloudflare off: unavailable {service: cloudflare, reason: off}. The service writes it to /var/lib/hinteros/services/cloudflare-tunnel/token (0600 root, atomically); the job restarts hinteros-cloudflared.service and waits up to 30 s for a connection (stages configuring, finishing). Failures: job_failed with reason not_connected (the token is kept: check it, or clear it) or unreachable (systemd refused the restart).
  Future<SystemCloudflareSetTokenResult> systemCloudflareSetToken(
    SystemCloudflareSetTokenParams params,
  ) async => SystemCloudflareSetTokenResult.fromJson(
    await rpc('system.cloudflare.set_token', params.toJson()),
  );

  /// Relayed to the system service's cloudflare.clear_token. stop the Cloudflare tunnel and delete its token (job cloudflare_clear_token). Admin PIN. Action org.hinteros.system.services.
  ///
  /// No token: job_id null. Cloudflare off: unavailable {service: cloudflare, reason: off}. Stages configuring, finishing.
  Future<SystemCloudflareClearTokenResult> systemCloudflareClearToken([
    SystemCloudflareClearTokenParams params =
        const SystemCloudflareClearTokenParams(),
  ]) async => SystemCloudflareClearTokenResult.fromJson(
    await rpc('system.cloudflare.clear_token', params.toJson()),
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
  ///
  /// Without admin_pin only the job's starter, root and the admin profile may cancel it; anyone else gets permission_denied {reason: starter}. With admin_pin (the admin profile's PIN) any profile may: pin_required {pin: admin} when it is wrong (it counts toward the admin PIN's tries). The cancelled job ends with job_finished, ok false, error job_failed with data.reason cancelled.
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
  /// id: the network's id from wifi.list or wifi.scan (not_found when no access point with that SSID and security is in range; invalid_params {field: id, reason: bad_format} when it is not an id). The password is needed unless the network is open or already known; it is stored in NetworkManager's system connection (readable by the session user, as accepted in the threat model) and is never logged by the daemon. Returns when the connection is up (or has failed, at most about 45 s). A failed new connection is removed again. 802.1X (enterprise) and WEP networks are refused with invalid_params {field: id, reason: unsupported_security}.
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
  /// id: the network's id from wifi.list (invalid_params {field: id, reason: bad_format} when it is not an id). Deletes every stored connection with that SSID. Disconnects if it is the network in use. Forgetting a network that is not stored is not an error.
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

  /// Who this session is. The launcher asks at start: setup_required starts the first-boot wizard; pin_set false shows the unskippable 'Set your PIN' screen; screen_locked shows the lock screen.
  Future<ProfileCurrentResult> profileCurrent([
    ProfileCurrentParams params = const ProfileCurrentParams(),
  ]) async => ProfileCurrentResult.fromJson(
    await rpc('profile.current', params.toJson()),
  );

  /// Switch to another profile: writes the switch hint (system.profiles.switch with the PIN of a locked target; a wrong or missing PIN is pin_required {pin: target} and nothing closes), then closes every app (SIGTERM, no silent force-close) and Steam (steam -shutdown), and ends this session; the greeter takes over. Answers once the hint is written; progress comes as switch_progress, a stuck app as switch_blocked.
  ///
  /// invalid_params {field: id, reason: same} for the own profile. While a switch runs a second one is invalid_params {reason: busy}. pin: the target's PIN, needed for a locked profile (asked in the session before anything closes); the hint then carries a one-time token, so the greeter enters the target with no UI. While closing takes long the daemon extends the token; switch_cancel drops it.
  Future<SessionSwitchProfileResult> sessionSwitchProfile(
    SessionSwitchProfileParams params,
  ) async => SessionSwitchProfileResult.fromJson(
    await rpc('session.switch_profile', params.toJson()),
  );

  /// Keep waiting for the blocked app (another switch.wait_s, 10 s).
  Future<SessionSwitchWaitResult> sessionSwitchWait([
    SessionSwitchWaitParams params = const SessionSwitchWaitParams(),
  ]) async => SessionSwitchWaitResult.fromJson(
    await rpc('session.switch_wait', params.toJson()),
  );

  /// Force-close the blocked app (SIGKILL of its process group; for Steam, its processes). Unsaved data may be lost.
  Future<SessionSwitchForceCloseResult> sessionSwitchForceClose(
    SessionSwitchForceCloseParams params,
  ) async => SessionSwitchForceCloseResult.fromJson(
    await rpc('session.switch_force_close', params.toJson()),
  );

  /// Stop the switch: this profile stays (what already closed is gone). switch_progress {stage: cancelled} follows.
  Future<SessionSwitchCancelResult> sessionSwitchCancel([
    SessionSwitchCancelParams params = const SessionSwitchCancelParams(),
  ]) async => SessionSwitchCancelResult.fromJson(
    await rpc('session.switch_cancel', params.toJson()),
  );

  /// Whether the sleep lock is up.
  Future<SessionLockStateResult> sessionLockState([
    SessionLockStateParams params = const SessionLockStateParams(),
  ]) async => SessionLockStateResult.fromJson(
    await rpc('session.lock_state', params.toJson()),
  );

  /// The PIN on the sleep lock screen (relays system.profiles.unlock); lock_changed {locked: false} follows.
  Future<SessionUnlockResult> sessionUnlock(SessionUnlockParams params) async =>
      SessionUnlockResult.fromJson(
        await rpc('session.unlock', params.toJson()),
      );

  /// Guest only: end the guest session now (like a switch, to the picker) and wipe the guest now.
  ///
  /// Answers {} at once; switch_progress events follow as on a switch (closing_apps, closing_steam, ending; switch_wait, switch_force_close and switch_cancel work the same). Once every app is closed the daemon calls system.guest.end: that job ends this session itself and wipes the guest's home, app env (back to the starter set), terms acceptances and usage; the boot-time wipe stays. While another job runs the daemon retries for 15 s; if the wipe cannot start it ends the session anyway and the guest is wiped at the next boot.
  Future<SessionEndGuestResult> sessionEndGuest([
    SessionEndGuestParams params = const SessionEndGuestParams(),
  ]) async => SessionEndGuestResult.fromJson(
    await rpc('session.end_guest', params.toJson()),
  );

  /// The picker's profiles (the service's public view). Greeter mode only (hinteros-session --greeter); only the hinteros-launcher connection may call it (else not_authorized).
  Future<GreeterListResult> greeterList([
    GreeterListParams params = const GreeterListParams(),
  ]) async =>
      GreeterListResult.fromJson(await rpc('greeter.list', params.toJson()));

  /// Enter a profile (or the guest) through greetd. An unlocked one starts at once (greeter_result {ok: true}); a locked one asks for its PIN (greeter_prompt {kind: pin}). Greeter mode only (hinteros-session --greeter); only the hinteros-launcher connection may call it (else not_authorized).
  Future<GreeterLoginResult> greeterLogin(GreeterLoginParams params) async =>
      GreeterLoginResult.fromJson(await rpc('greeter.login', params.toJson()));

  /// Answer the PIN prompt. greeter_result follows: ok, or not ok with locked_s during the backoff (the greetd conversation is then over; log in again). Greeter mode only (hinteros-session --greeter); only the hinteros-launcher connection may call it (else not_authorized).
  Future<GreeterPinResult> greeterPin(GreeterPinParams params) async =>
      GreeterPinResult.fromJson(await rpc('greeter.pin', params.toJson()));

  /// Back from the PIN pad: cancel the greetd conversation. Greeter mode only (hinteros-session --greeter); only the hinteros-launcher connection may call it (else not_authorized).
  Future<GreeterCancelResult> greeterCancel([
    GreeterCancelParams params = const GreeterCancelParams(),
  ]) async => GreeterCancelResult.fromJson(
    await rpc('greeter.cancel', params.toJson()),
  );

  /// Add profile from the picker (system profiles.create over greeter.sock; a rebuild of about a minute). Job events follow; on success call greeter.login {id} (a one-time token: no PIN prompt). Greeter mode only (hinteros-session --greeter); only the hinteros-launcher connection may call it (else not_authorized).
  Future<GreeterCreateResult> greeterCreate(GreeterCreateParams params) async =>
      GreeterCreateResult.fromJson(
        await rpc('greeter.create', params.toJson()),
      );

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
  /// From the catalog index of the running generation (/run/current-system/sw/share/hinteros/catalog.json) and system.settings.get's installed apps. Lists available apps and installed ones whatever their catalog status (retired: still works, can be removed; removed: the next update takes it away), and removed apps that are not installed but whose data (dataPaths) is still in this profile's home (state leftover: only Clear data, system.apps.clear_data, is offered), sorted by name; apps being installed or removed through this daemon have state installing/removing. Terms carry the full text's path on this box, so the launcher can show it offline before system.apps.install. more_after_update: the last update check found apps that the next update makes installable. unavailable {service: catalog}: no index, or an index version this daemon does not read.
  Future<StoreListResult> storeList([
    StoreListParams params = const StoreListParams(),
  ]) async =>
      StoreListResult.fromJson(await rpc('store.list', params.toJson()));

  /// This profile's controller settings: the button map, the keys of keyboard-mode apps, the pointer.
  ///
  /// settings: what the user changed, exactly as stored ($XDG_STATE_HOME/hinteros/controller.json; missing or unreadable = {}). defaults: the built-in values. The effective button map is defaults.general with settings.general over it. An app's effective keymap is, lowest to highest: defaults.keyboard, settings.keyboard, the app's own keymap (apps[].keymap), settings.apps[id]. buttons, actions, key_actions, keys, modifiers and speed list what set accepts. apps: the profile's keyboard-mode apps. Guide and the directions are never remappable.
  Future<InputSettingsGetResult> inputSettingsGet([
    InputSettingsGetParams params = const InputSettingsGetParams(),
  ]) async => InputSettingsGetResult.fromJson(
    await rpc('input.settings.get', params.toJson()),
  );

  /// Replace this profile's controller settings (the stored form of input.settings.get) and apply them at once.
  ///
  /// Answers with input.settings.get's result. invalid_params (data.field names the part) for unknown buttons, actions or app ids, keys that do not parse, a general map that is not one button per action and one action per button, equal click buttons, or a speed outside speed.min..max or off speed.step. Written atomically; the running session uses it at once.
  Future<InputSettingsSetResult> inputSettingsSet(
    InputSettingsSetParams params,
  ) async => InputSettingsSetResult.fromJson(
    await rpc('input.settings.set', params.toJson()),
  );

  /// The next button press goes to the launcher as input_captured instead of being acted on (press to assign).
  ///
  /// The next press of one of the ten buttons or a direction (up, down, left, right) is not acted on: it is sent as input_captured {button} (the physical button, before the general map) and capture ends. Guide during capture ends it with {button: null} and goes Home as usual; so does 10 s without a press. A second call while one runs restarts the 10 s. Launcher only.
  Future<InputCaptureResult> inputCapture([
    InputCaptureParams params = const InputCaptureParams(),
  ]) async =>
      InputCaptureResult.fromJson(await rpc('input.capture', params.toJson()));
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
    'osk_changed' => OskChangedEvent.fromJson(params),
    'time_zone_changed' => TimeZoneChangedEvent.fromJson(params),
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
    'lock_changed' => LockChangedEvent.fromJson(params),
    'greeter_prompt' => GreeterPromptEvent.fromJson(params),
    'greeter_result' => GreeterResultEvent.fromJson(params),
    'profiles_changed' => ProfilesChangedEvent.fromJson(params),
    'input_captured' => InputCapturedEvent.fromJson(params),
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
