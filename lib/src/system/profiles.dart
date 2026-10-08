/// Profiles (M7): the data types and repository interfaces of the profile
/// screens (`hinteros-docs/design/profiles.md`). The session side
/// ([ProfilesRepository]: the current profile, the box's profiles, switching,
/// the sleep lock, the starter set) and the greeter side ([GreeterRepository]:
/// the picker before any profile's session runs). Implementations:
/// `daemon_profiles.dart` (session API 0.12) and `mock_profiles.dart`.
library;

import 'package:flutter/foundation.dart';

import 'models.dart';

// ---------------------------------------------------------------- models

/// A profile's colour: the tile, the chip, the avatar. A closed set of names
/// on the wire; the UI maps them to its palette.
enum ProfileColor {
  teal,
  blue,
  purple,
  pink,
  red,
  orange,
  yellow,
  green;

  /// An unknown name (a newer box) is teal.
  static ProfileColor parse(String? s) =>
      values.firstWhere((c) => c.name == s, orElse: () => teal);

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

/// Which PIN a refused call wanted (`pin_required.pin`).
enum PinKind {
  /// The caller's own.
  self,

  /// The admin profile's.
  admin,

  /// The profile being entered.
  target;

  static PinKind parse(Object? s) =>
      values.firstWhere((k) => k.name == s, orElse: () => self);
}

/// The PIN rules (profiles.md): 4 to 8 digits.
bool validPin(String pin) => RegExp(r'^[0-9]{4,8}$').hasMatch(pin);

/// A display name the service accepts: 1 to 32 characters once trimmed, no
/// control characters. Returns the problem in words, or null.
String? nameProblem(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'Type a name.';
  if (n.runes.length > 32) return 'Use at most 32 characters.';
  if (n.runes.any((r) => r < 0x20 || (r >= 0x7f && r < 0xa0))) {
    return 'Use letters, numbers and spaces.';
  }
  return null;
}

/// What a refused PIN means for the person typing it: [retryAt] while the
/// profile's backoff lock lasts ("Try again in 30 seconds").
@immutable
class PinRefusal {
  const PinRefusal({required this.kind, this.retryAt});

  final PinKind kind;
  final DateTime? retryAt;

  /// From a [SystemErrorKind.pinRequired] exception; null for any other.
  static PinRefusal? of(Object e, {DateTime Function() now = DateTime.now}) {
    if (e is! SystemException || e.kind != SystemErrorKind.pinRequired) {
      return null;
    }
    final ms = e.data['retry_after_ms'];
    return PinRefusal(
      kind: PinKind.parse(e.data['pin']),
      retryAt: ms is int && ms > 0
          ? now().add(Duration(milliseconds: ms))
          : null,
    );
  }
}

/// Disk use of one profile's home (`usage`).
@immutable
class ProfileUsage {
  const ProfileUsage({
    required this.totalBytes,
    required this.steamGamesBytes,
    required this.at,
  });

  final int totalBytes;
  final int steamGamesBytes;
  final DateTime at;
}

/// "34 GB", "800 MB".
String bytesLabel(int bytes) {
  const gb = 1000 * 1000 * 1000;
  if (bytes >= 10 * gb) return '${(bytes / gb).round()} GB';
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  final mb = (bytes / (1000 * 1000)).round();
  return '$mb MB';
}

/// One profile of this box (`profiles.list`).
@immutable
class ProfileInfo {
  const ProfileInfo({
    required this.id,
    required this.name,
    required this.color,
    this.admin = false,
    this.locked = false,
    this.lockedUntil,
    this.active = false,
    this.lastUsedAt,
    this.usage,
  });

  final String id;
  final String name;
  final ProfileColor color;
  final bool admin;

  /// Asks for its PIN to enter (picker, after sleep).
  final bool locked;

  /// The PIN backoff lock lasts until then.
  final DateTime? lockedUntil;

  /// On screen now (the caller's own profile, in a session).
  final bool active;
  final DateTime? lastUsedAt;
  final ProfileUsage? usage;

  String get initial =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  ProfileInfo copyWith({
    String? name,
    ProfileColor? color,
    bool? locked,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    bool? active,
    DateTime? lastUsedAt,
    ProfileUsage? usage,
  }) => ProfileInfo(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    admin: admin,
    locked: locked ?? this.locked,
    lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    active: active ?? this.active,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    usage: usage ?? this.usage,
  );
}

/// `profiles.list`: the profiles, the guest and the limit.
@immutable
class ProfilesState {
  const ProfilesState({
    required this.profiles,
    this.guestEnabled = true,
    this.guestUsage,
    this.max = 8,
    this.firstBoot = false,
  });

  final List<ProfileInfo> profiles;
  final bool guestEnabled;
  final ProfileUsage? guestUsage;
  final int max;
  final bool firstBoot;

  ProfileInfo? byId(String id) => profiles.where((p) => p.id == id).firstOrNull;
  ProfileInfo? get admin => profiles.where((p) => p.admin).firstOrNull;
  bool get full => profiles.length >= max;
}

/// The profile this session belongs to (`profile.current`).
@immutable
class CurrentProfile {
  const CurrentProfile({
    required this.id,
    this.name,
    this.color,
    this.admin = false,
    this.locked = false,
    this.guest = false,
    this.setupRequired = false,
    this.pinSet = true,
    this.screenLocked = false,
  });

  static const guestId = 'guest';

  final String id;

  /// Null for a spare account in first-boot mode.
  final String? name;
  final ProfileColor? color;
  final bool admin;
  final bool locked;
  final bool guest;

  /// First-boot mode: no admin profile exists; the wizard creates it.
  final bool setupRequired;

  /// False: a profile migrated from a single-user box that has no PIN yet.
  final bool pinSet;

  /// The sleep lock is up.
  final bool screenLocked;

  String get displayName => name ?? (guest ? 'Guest' : 'This profile');
  String get initial => displayName.isEmpty
      ? '?'
      : String.fromCharCode(displayName.runes.first).toUpperCase();

  CurrentProfile copyWith({
    String? name,
    ProfileColor? color,
    bool? admin,
    bool? locked,
    bool? setupRequired,
    bool? pinSet,
    bool? screenLocked,
  }) => CurrentProfile(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    admin: admin ?? this.admin,
    locked: locked ?? this.locked,
    guest: guest,
    setupRequired: setupRequired ?? this.setupRequired,
    pinSet: pinSet ?? this.pinSet,
    screenLocked: screenLocked ?? this.screenLocked,
  );
}

/// A profile job just started ([ProfilesRepository.create]) and the id the
/// new profile will have.
@immutable
class ProfileJob {
  const ProfileJob(this.job, this.id);

  final JobHandle job;
  final String id;
}

/// What a profile switch is doing (`switch_progress` / `switch_blocked`).
sealed class SwitchEvent {
  const SwitchEvent();
}

enum SwitchStage { closingApps, closingSteam, ending }

final class SwitchProgress extends SwitchEvent {
  const SwitchProgress(this.stage, {this.appId, this.appName});

  final SwitchStage stage;
  final String? appId;
  final String? appName;
}

/// An app has not closed after [waited] (the not-responding pop-up).
final class SwitchBlocked extends SwitchEvent {
  const SwitchBlocked({
    required this.appId,
    required this.appName,
    required this.waited,
  });

  final String appId;
  final String appName;
  final Duration waited;
}

/// The starter set (`starter_set.get`).
@immutable
class StarterSet {
  const StarterSet(this.ids, {this.updatedAt});

  final List<String> ids;
  final DateTime? updatedAt;
}

/// The caller's own apps (`apps.list`, per profile).
@immutable
class ProfileApps {
  const ProfileApps({
    required this.generation,
    required this.ids,
    this.needsTerms = const [],
  });

  final int generation;
  final List<String> ids;

  /// Starter-set apps whose vendor terms this profile has not accepted yet.
  final List<String> needsTerms;
}

/// One generation of the caller's apps (`apps.generations`).
@immutable
class AppGeneration {
  const AppGeneration({
    required this.generation,
    required this.date,
    required this.ids,
    this.systemRev,
    this.current = false,
  });

  final int generation;
  final DateTime date;
  final List<String> ids;
  final String? systemRev;
  final bool current;
}

// ---------------------------------------------------------------- session side

/// Profiles as seen from a profile's session. Every call can throw
/// [SystemException]: [SystemErrorKind.pinRequired] for a missing or wrong
/// PIN (see [PinRefusal.of]), [SystemErrorKind.profileLimit],
/// [SystemErrorKind.jobBusy], [SystemErrorKind.unavailable].
abstract class ProfilesRepository {
  /// `profile.current`.
  Future<CurrentProfile> current();

  /// `profiles.list`.
  Future<ProfilesState> list();

  /// `profiles_changed`: the profiles after a change (also the current
  /// profile's name, colour, lock flag).
  Stream<List<ProfileInfo>> get changes;

  /// `lock_state`: the sleep lock went up (true) or down.
  Stream<bool> get lockChanges;

  /// `profiles.create` (a job of about a minute; the revision is fetched).
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  });

  /// `profiles.setup_admin`: first-boot mode turns this session's spare
  /// account into the admin profile. No job.
  Future<void> setupAdmin({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  });

  /// `profiles.rename`; [adminPin] for another profile.
  Future<void> rename(String id, String name, {String? adminPin});

  /// `profiles.set_appearance {color}` (own profile).
  Future<void> setColor(ProfileColor color);

  /// `profiles.set_appearance {text_scale, high_contrast, reduce_motion}`:
  /// the three launcher settings the picker mirrors (own profile).
  Future<void> mirrorAppearance({
    required double textScale,
    required bool highContrast,
    required bool reduceMotion,
  });

  /// `profiles.set_pin`; [currentPin] null only while no PIN is set.
  Future<void> setPin(String pin, {String? currentPin});

  /// `profiles.set_locked` with the own PIN.
  Future<void> setLocked(bool locked, String pin);

  /// `profiles.reset_pin` of another profile, with the admin PIN.
  Future<void> resetPin(String id, String newPin, {required String adminPin});

  /// `profiles.remove` (a job): the own PIN for the own profile, else the
  /// admin PIN.
  Future<JobHandle> remove(String id, String pin);

  /// `guest.set` with the admin PIN. Null when it already was so.
  Future<JobHandle?> setGuest(bool enabled, String adminPin);

  /// `starter_set.get`.
  Future<StarterSet> starterSet();

  /// `starter_set.set` with the admin PIN. Null: nothing changed.
  Future<JobHandle?> setStarterSet(List<String> ids, String adminPin);

  /// `session.switch_profile`. The session ends afterwards; follow
  /// [switchEvents] until then.
  Future<void> switchTo(String id);

  /// `switch_progress` and `switch_blocked`.
  Stream<SwitchEvent> get switchEvents;

  /// The not-responding pop-up: `session.switch_wait`,
  /// `session.switch_force_close`, `session.switch_cancel`.
  Future<void> keepWaiting();
  Future<void> forceClose(String appId);
  Future<void> cancelSwitch();

  /// `session.unlock` (the sleep lock screen).
  Future<void> unlock(String pin);

  /// `session.end_guest`.
  Future<void> endGuest();
}

// ---------------------------------------------------------------- greeter side

/// A profile as the picker sees it (the public view).
@immutable
class PickerProfile {
  const PickerProfile({
    required this.id,
    required this.name,
    required this.color,
    this.locked = false,
    this.admin = false,
    this.lockedUntil,
  });

  final String id;
  final String name;
  final ProfileColor color;
  final bool locked;
  final bool admin;
  final DateTime? lockedUntil;

  String get initial =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
}

/// The appearance the picker uses (the most accessible combination of the
/// profiles' own).
@immutable
class PickerAppearance {
  const PickerAppearance({
    this.textScale = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
  });

  final double textScale;
  final bool highContrast;
  final bool reduceMotion;
}

/// `greeter.list`.
@immutable
class PickerView {
  const PickerView({
    required this.profiles,
    this.guest = true,
    this.firstBoot = false,
    this.focus,
    this.appearance = const PickerAppearance(),
    this.jobId,
  });

  final List<PickerProfile> profiles;
  final bool guest;
  final bool firstBoot;

  /// The profile to focus first: a switch's target, else the last used.
  final String? focus;
  final PickerAppearance appearance;

  /// A profile job to show (the removal that ended the last session).
  final String? jobId;

  PickerProfile? byId(String id) =>
      profiles.where((p) => p.id == id).firstOrNull;
}

/// How an attempt to enter a profile ended.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// The session starts; the greeter is done.
final class LoginStarted extends LoginOutcome {
  const LoginStarted();
}

/// The profile is locked: ask for its PIN and call [GreeterRepository.login]
/// again with it.
final class LoginNeedsPin extends LoginOutcome {
  const LoginNeedsPin();
}

/// The PIN did not match. [retryAt] while the backoff lock lasts.
final class LoginRefused extends LoginOutcome {
  const LoginRefused({this.retryAt});

  final DateTime? retryAt;
}

/// The picker (`--greeter`): talks to the greeter-mode session daemon only.
abstract class GreeterRepository {
  /// `greeter.list`.
  Future<PickerView> load();

  /// Enter profile [id] (or `guest`). Without [pin], a locked profile answers
  /// [LoginNeedsPin]; with it, the PIN goes to greetd.
  Future<LoginOutcome> login(String id, {String? pin});

  /// `greeter.cancel`: Back on the PIN pad.
  Future<void> cancel();

  /// `greeter.create` (Add profile; a job of about a minute).
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  });
}
