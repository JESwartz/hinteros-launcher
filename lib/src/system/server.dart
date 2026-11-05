/// The Server section (session API 0.19, system API 0.11; design in
/// hinteros-docs `design/server.md`): the box-wide services of the catalog
/// (Jellyfin, Plex, Tailscale, Cloudflare Tunnel), their state and their
/// setup. Everyone sees the state; every change takes the admin profile's
/// PIN and runs as a job.
library;

import 'package:flutter/foundation.dart';

import 'models.dart';

/// What the Server tab says about a service.
enum ServiceState {
  off('Off'),
  starting('Starting'),
  running('Running'),
  needsSetup('Needs setup'),
  error('Error');

  const ServiceState(this.label);
  final String label;
}

/// The setup flow the catalog gives a service; [none]: only on and off.
enum ServiceSetup {
  jellyfinServer,
  plexMediaServer,
  tailscale,
  cloudflareTunnel,
  none,
}

/// systemd's `ActiveState` of the service's unit.
enum UnitStatus {
  active,
  reloading,
  inactive,
  failed,
  activating,
  deactivating,
  maintenance,
  refreshing,
  unknown,
}

/// What a Jellyfin library holds. [other]: a type made in Jellyfin's own
/// dashboard (books, photos); the launcher cannot make one.
enum LibraryKind {
  movies('Movies'),
  shows('Shows'),
  music('Music'),
  mixed('Mixed'),
  other('Other');

  const LibraryKind(this.label);
  final String label;

  /// The kinds a new library can have.
  static const choices = [movies, shows, music, mixed];
}

@immutable
class JellyfinLibrary {
  const JellyfinLibrary({
    required this.id,
    required this.name,
    required this.kind,
    this.folder,
  });

  final String id;
  final String name;
  final LibraryKind kind;

  /// Its first folder, relative to `/srv/media`; null when that is
  /// somewhere else.
  final String? folder;
}

/// A setup flow's state (`services.list`'s `detail`): no secrets.
@immutable
sealed class ServiceDetail {
  const ServiceDetail();
}

@immutable
class JellyfinDetail extends ServiceDetail {
  const JellyfinDetail({
    required this.setupDone,
    this.url,
    this.libraries = const [],
    this.users = const {},
  });

  /// HinterOS made Jellyfin's first-run setup (admin user, API key).
  final bool setupDone;

  /// The address for other devices (`http://<local IP>:8096`).
  final String? url;
  final List<JellyfinLibrary> libraries;

  /// Profile id to its Jellyfin user name.
  final Map<String, String> users;
}

@immutable
class PlexDetail extends ServiceDetail {
  const PlexDetail({required this.claimed, this.serverName, this.url});

  /// Linked to a Plex account.
  final bool claimed;
  final String? serverName;
  final String? url;
}

enum TailscaleState {
  needsLogin,
  needsApproval,
  starting,
  running,
  stopped,
  unavailable,
}

@immutable
class TailscaleDetail extends ServiceDetail {
  const TailscaleDetail({
    required this.state,
    this.name,
    this.ip4,
    this.dnsName,
    this.tailnet,
    this.keyExpiry,
  });

  final TailscaleState state;
  final String? name;
  final String? ip4;

  /// The MagicDNS name.
  final String? dnsName;
  final String? tailnet;

  /// Null: the key never expires, or not known.
  final DateTime? keyExpiry;
}

@immutable
class CloudflareDetail extends ServiceDetail {
  const CloudflareDetail({
    required this.tokenSet,
    required this.connected,
    this.localIp,
  });

  final bool tokenSet;

  /// cloudflared has a connection to Cloudflare.
  final bool connected;

  /// The box's address on the local network: the route to add in Zero
  /// Trust.
  final String? localIp;
}

/// One service of the Server section.
@immutable
class ServerService {
  const ServerService({
    required this.id,
    required this.name,
    this.available = true,
    this.enabled = false,
    this.status,
    this.setup = ServiceSetup.none,
    this.terms,
    this.termsMissing = false,
    this.detail,
    this.iconPath,
    this.hasData = false,
  });

  /// The catalog id (`jellyfin-server`).
  final String id;
  final String name;

  /// The catalog offers it (an enabled service it dropped: false).
  final bool available;

  /// On (in state.json).
  final bool enabled;

  /// The unit's state; null while off or without a known unit.
  final UnitStatus? status;
  final ServiceSetup setup;

  /// The vendor terms to accept before it is turned on (Plex), with the
  /// text read from the box.
  final VendorTerms? terms;

  /// It has vendor terms, but their text cannot be read on this box: it
  /// cannot be turned on from here.
  final bool termsMissing;
  final ServiceDetail? detail;

  /// The icon the daemon resolved (`icon.path`); null: the letter tile.
  final String? iconPath;

  /// Turning it off can also delete its data (`has_data`).
  final bool hasData;

  /// What the Server tab shows.
  ServiceState get state {
    if (!enabled) return ServiceState.off;
    switch (status) {
      case UnitStatus.failed:
        return ServiceState.error;
      case UnitStatus.activating ||
          UnitStatus.reloading ||
          UnitStatus.refreshing:
        return ServiceState.starting;
      default:
    }
    switch (detail) {
      // HinterOS does Jellyfin's first run by itself.
      case JellyfinDetail(setupDone: false):
        return ServiceState.starting;
      case PlexDetail(claimed: false):
        return ServiceState.needsSetup;
      case TailscaleDetail(
        state: TailscaleState.needsLogin ||
            TailscaleState.needsApproval ||
            TailscaleState.stopped,
      ):
        return ServiceState.needsSetup;
      case TailscaleDetail(state: TailscaleState.starting):
        return ServiceState.starting;
      case TailscaleDetail(state: TailscaleState.unavailable):
        return ServiceState.error;
      case CloudflareDetail(tokenSet: false):
        return ServiceState.needsSetup;
      case CloudflareDetail(connected: false):
        return ServiceState.error;
      default:
    }
    return switch (status) {
      UnitStatus.inactive ||
      UnitStatus.deactivating ||
      UnitStatus.maintenance => ServiceState.error,
      _ => ServiceState.running,
    };
  }
}

/// `services.list`: the services and the state.json revision that turning
/// one on or off needs.
@immutable
class ServerList {
  const ServerList({required this.revision, required this.services});

  final String revision;
  final List<ServerService> services;

  ServerService? byId(String id) =>
      services.where((s) => s.id == id).firstOrNull;
}

/// A folder below `/srv/media` (`media.folders`).
@immutable
class MediaFolder {
  const MediaFolder({
    required this.id,
    required this.name,
    this.hasChildren = false,
  });

  /// Its path relative to `/srv/media` (`Movies/Kids`).
  final String id;
  final String name;

  /// It has folders of its own.
  final bool hasChildren;
}

/// A Jellyfin user and its password (`jellyfin.users.reveal`).
@immutable
class JellyfinAccount {
  const JellyfinAccount({
    required this.name,
    required this.password,
    this.profileName,
  });

  /// The Jellyfin user name.
  final String name;
  final String password;

  /// The profile it belongs to; null for the admin user.
  final String? profileName;
}

/// `jellyfin.users.reveal`: the admin user (null until the first run made
/// it) and one user per profile.
@immutable
class JellyfinAccounts {
  const JellyfinAccounts({this.admin, this.users = const []});

  final JellyfinAccount? admin;
  final List<JellyfinAccount> users;
}

/// The Server tab. Every change takes the admin PIN ([pin]; null or wrong
/// gives [SystemErrorKind.pinRequired] with `pin: admin`) and starts a
/// job. A service that is off or not set up yet gives
/// [SystemErrorKind.unavailable] (`data`: `service`, `reason` `off` or
/// `not_ready`).
abstract class ServerRepository {
  /// `services.list`.
  Future<ServerList> list();

  /// A job of the Server section ended (also one another client started),
  /// or the connection came back, or (daemon) `store_changed` (a
  /// service's icon may have arrived): read [list] again.
  Stream<void> get changes;

  /// `media.folders`: the folders directly in `/srv/media` ([folderId]
  /// null) or in one of its folders. [SystemErrorKind.notFound]: no such
  /// folder (any more).
  Future<List<MediaFolder>> folders([String? folderId]);

  /// `services.enable {ids: [id], pin, revision, accepted_terms}`; a stale
  /// revision is read again and the call made once more.
  /// [SystemErrorKind.termsRequired] (`id`, `version`) when [acceptedTerms]
  /// lacks the version of its terms; [SystemErrorKind.nothingToDo] when it
  /// is on already.
  Future<JobHandle> enable(
    String id, {
    String? pin,
    Map<String, String> acceptedTerms = const {},
  });

  /// `services.disable {ids: [id], pin, revision, delete_data}`.
  Future<JobHandle> disable(String id, {String? pin, bool deleteData = false});

  /// `jellyfin.libraries.add`. [SystemErrorKind.invalidParams] with
  /// `reason: exists` when a library has that name.
  Future<JobHandle> addLibrary({
    required String name,
    required LibraryKind kind,
    required String folder,
    String? pin,
  });

  /// `jellyfin.libraries.remove`: the media files stay.
  Future<JobHandle> removeLibrary(String libraryId, {String? pin});

  /// `jellyfin.users.reveal` (no job): the passwords, for other devices.
  /// Never kept or logged.
  Future<JellyfinAccounts> revealAccounts({String? pin});

  /// `plex.claim {code}`: a code from plex.tv/claim (`claim-` and 20
  /// characters). [SystemErrorKind.nothingToDo]: linked already.
  Future<JobHandle> claimPlex(String code, {String? pin});

  /// `tailscale.login`: the job's progress carries the sign-in address
  /// ([JobSnapshot.authUrl]). [SystemErrorKind.nothingToDo]: signed in.
  Future<JobHandle> tailscaleLogin({String? pin});

  /// `tailscale.logout`.
  Future<JobHandle> tailscaleLogout({String? pin});

  /// `cloudflare.set_token`. [SystemErrorKind.invalidParams] (`field:
  /// token`) for something that is not a tunnel token.
  Future<JobHandle> setCloudflareToken(String token, {String? pin});

  /// `cloudflare.clear_token`.
  Future<JobHandle> clearCloudflareToken({String? pin});
}

/// What plex.tv/claim gives: `claim-` and 20 letters, digits, `_` or `-`.
final plexClaimCode = RegExp(r'^claim-[A-Za-z0-9_-]{20}$');

/// The address plex.tv gives a claim code at.
const plexClaimUrl = 'https://plex.tv/claim';

/// The job kinds of the Server section: when one ends the list changes.
const serverJobKinds = {
  JobKind.servicesEnable,
  JobKind.servicesDisable,
  JobKind.libraryAdd,
  JobKind.libraryRemove,
  JobKind.plexClaim,
  JobKind.tailscaleLogin,
  JobKind.tailscaleLogout,
  JobKind.cloudflareSetToken,
  JobKind.cloudflareClearToken,
};

/// Why a job of the Server section failed (`job_failed.data.reason`), as
/// the job page says it; null for another reason.
String? serverFailureText(Object? reason) => switch (reason) {
  'unreachable' => 'The service does not answer. Try again later.',
  'not_ready' => 'The service is not ready. Try again in a moment.',
  'refused' => 'The service did not accept it.',
  'timeout' => 'Nobody signed in in time.',
  'not_connected' => 'The tunnel did not connect. Check the token.',
  _ => null,
};

/// What the screen says when the service refuses a Server section request
/// as `invalid_params` ([SystemErrorKind.invalidParams]): by its field.
SystemException serverRefusal(SystemException e) {
  if (e.kind != SystemErrorKind.invalidParams) return e;
  final text = switch ((e.data['field'], e.data['reason'])) {
    ('name', 'exists') => 'A library has this name.',
    ('name', 'bad_length') => 'Type a name of 1 to 64 characters.',
    ('name', _) => 'The name has a character that is not allowed.',
    ('token', _) => 'This is not a tunnel token.',
    ('code', _) => 'The code is not correct.',
    ('folder_id' || 'folder', _) => 'That folder is not there.',
    _ => null,
  };
  return text == null ? e : SystemException(e.kind, text, data: e.data);
}
