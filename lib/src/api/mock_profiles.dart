/// The profiles side of [MockDaemon] (session API 0.12): `profile.current`,
/// the switch (`session.switch_*`, `switch_progress`, `switch_blocked`), the
/// sleep lock (`session.unlock`, `lock_state`), `session.end_guest`, the
/// greeter-mode methods (`greeter.*`, `greeter_prompt`, `greeter_result`) and
/// the relayed `system.profiles.*`, `system.guest.set`, `system.apps.list` /
/// `generations` / `rollback` / `accept_terms` and `system.starter_set.*`,
/// with the service's PIN rules (self, admin, target; three free failures,
/// then a lock). Jobs go through [MockSystemRelay]. Placeholder data.
library;

import 'dart:async';

import 'errors.dart';
import 'generated.dart';
import 'mock_system_relay.dart';

/// One profile of the mock box, with its PIN.
class MockWireProfile {
  MockWireProfile({
    required this.id,
    required this.name,
    required this.color,
    required this.pin,
    this.admin = false,
    this.locked = false,
  });

  final String id;
  String name;
  ProfileColor color;
  String? pin;
  final bool admin;
  bool locked;
  int failures = 0;
  int? lockedUntil;

  String get user => id == 'p1' ? 'hinteros' : 'hinteros-$id';
}

class MockProfileSession {
  MockProfileSession({
    required this.emit,
    required this.relay,
    required this.isLauncher,
    DateTime Function()? now,
    this.onTermsAccepted,
  }) : _now = now ?? DateTime.now;

  /// The profile accepted app [id]'s terms (its `apps.list` entry loses
  /// `needs_terms`).
  final void Function(String id)? onTermsAccepted;

  final void Function(String name, Map<String, dynamic> params) emit;
  final MockSystemRelay relay;
  final bool Function() isLauncher;
  final DateTime Function() _now;

  // ---- the box

  /// James (admin, PIN 2468, unlocked) and Sam (PIN 1357, locked).
  final List<MockWireProfile> profiles = [
    MockWireProfile(
      id: 'p1',
      name: 'James',
      color: ProfileColor.teal,
      pin: '2468',
      admin: true,
    ),
    MockWireProfile(
      id: 'p3',
      name: 'Sam',
      color: ProfileColor.orange,
      pin: '1357',
      locked: true,
    ),
  ];
  int next = 4;
  int max = 8;
  bool guestEnabled = true;

  /// Whose session this is: a profile id or `guest`.
  String current = 'p1';

  /// The session's account is a spare in first-boot mode.
  bool setupRequired = false;

  /// This daemon runs the greeter (`greeter.*` work, nothing else needs to).
  bool greeterMode = false;

  /// greeter.list `switch_to`: a pending switch to this profile.
  String? switchTo;

  /// The sleep lock is up.
  bool screenLocked = false;

  /// The box still has box-wide apps (`system.apps.*` are unavailable).
  bool schema1 = false;

  /// Starter-set apps whose terms this profile has not accepted.
  final Set<String> needsTerms = {};
  List<String> starter = ['firefox', 'youtube'];

  /// Earlier app generations of the caller: generation number to ids.
  final Map<int, List<String>> appGenerations = {
    1: ['firefox', 'youtube'],
  };
  int appGeneration = 2;

  /// The app a switch waits for (`switch_blocked`); null: nothing blocks.
  ({String id, String name})? blockingApp;

  /// What happened, in order (`switch:p3`, `force_close:youtube`...). Never
  /// a PIN.
  final List<String> log = [];

  bool _switching = false;
  bool _blocked = false;
  String? _greeterPending;
  bool _greeterPrompted = false;
  final Set<String> _tokens = {};

  MockWireProfile? byId(String id) =>
      profiles.where((p) => p.id == id).firstOrNull;
  MockWireProfile get admin => profiles.firstWhere((p) => p.admin);

  static const _sessionMethods = {
    'profile.current',
    'session.switch_profile',
    'session.switch_wait',
    'session.switch_force_close',
    'session.switch_cancel',
    'session.unlock',
    'session.end_guest',
    'session.lock_state',
  };

  static bool handles(String method) =>
      _sessionMethods.contains(method) ||
      method.startsWith('greeter.') ||
      method.startsWith('system.profiles.') ||
      method == 'system.guest.set' ||
      method == 'system.apps.list' ||
      method == 'system.apps.generations' ||
      method == 'system.apps.rollback' ||
      method == 'system.apps.accept_terms' ||
      method.startsWith('system.starter_set.') ||
      method == 'system.display.save_mode' ||
      method == 'system.audio.save_output';

  int get _nowS => _now().millisecondsSinceEpoch ~/ 1000;

  ProfileInfo _wire(MockWireProfile p) => ProfileInfo(
    id: p.id,
    name: p.name,
    color: p.color,
    user: p.user,
    admin: p.admin,
    locked: p.locked,
    lockedUntil: p.lockedUntil,
    active: p.id == current,
    lastUsedAt: p.id == current ? _nowS : null,
    usage: null,
    pinSet: p.pin != null,
  );

  void _changed() => emit(
    'profiles_changed',
    ProfilesChangedEvent(profiles: [for (final p in profiles) _wire(p)])
        .toJson(),
  );

  ApiException _pinRequired(String which, [int? retryMs]) => ApiException(
    ApiErrorCode.pinRequired,
    retryMs == null ? 'wrong PIN' : 'too many wrong PINs, try again later',
    PinRequiredData(
      pin: PinRequiredDataPin.fromJson(which),
      retryAfterMs: retryMs,
    ).toJson(),
  );

  /// The service's PIN check with its backoff: 3 free failures, then 30 s
  /// (the mock's first lock), doubling.
  void _check(MockWireProfile p, String? pin, String which) {
    final until = p.lockedUntil;
    if (until != null && _nowS < until) {
      throw _pinRequired(which, (until - _nowS) * 1000);
    }
    if (pin != null && pin == p.pin) {
      p
        ..failures = 0
        ..lockedUntil = null;
      return;
    }
    if (pin == null) throw _pinRequired(which);
    p.failures++;
    if (p.failures > 3) {
      final s = (30 << (p.failures - 4)).clamp(30, 300);
      p.lockedUntil = _nowS + s;
      throw _pinRequired(which, s * 1000);
    }
    throw _pinRequired(which);
  }

  MockWireProfile _profile(String id) =>
      byId(id) ?? (throw ApiException(ApiErrorCode.notFound, 'no profile $id'));

  void _greeterOnly() {
    if (!isLauncher()) {
      throw const ApiException(
        ApiErrorCode.notAuthorized,
        'only the launcher may use the greeter',
      );
    }
    if (!greeterMode) {
      throw const ApiException(
        ApiErrorCode.unavailable,
        'this daemon is not in greeter mode',
        {'service': 'logind', 'reason': 'not_greeter'},
      );
    }
  }

  void _relayUp() {
    final u = relay.unavailable;
    if (u != null) {
      throw ApiException(
        ApiErrorCode.systemUnavailable,
        'the system service is not running',
        SystemUnavailableData(reason: u).toJson(),
      );
    }
  }

  void _appsAvailable() {
    if (schema1) {
      throw const ApiException(
        ApiErrorCode.unavailable,
        'this box still has box-wide apps',
        {'service': 'profiles', 'reason': 'schema1'},
      );
    }
  }

  void _staleRevision(String revision) {
    if (revision != relay.revision) {
      throw const ApiException(
        ApiErrorCode.stateConflict,
        'state.json changed since settings.get',
        {'reason': 'revision'},
      );
    }
  }

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> p,
  ) async {
    if (method.startsWith('system.')) _relayUp();
    switch (method) {
      case 'session.lock_state':
        return SessionLockStateResult(locked: screenLocked).toJson();
      case 'profile.current':
        return _current().toJson();
      case 'session.switch_profile':
        return _switchTo(SessionSwitchProfileParams.fromJson(p).id as String);
      case 'session.switch_wait':
        if (!_blocked) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'no switch is running',
            {'field': 'switch', 'reason': 'no_switch'},
          );
        }
        log.add('switch_wait');
        _emitBlocked(20);
        return const SessionSwitchWaitResult().toJson();
      case 'session.switch_force_close':
        final app = SessionSwitchForceCloseParams.fromJson(p).app;
        if (!_blocked || blockingApp?.id != app) {
          throw ApiException(
            ApiErrorCode.notFound,
            '$app is not blocking the switch',
          );
        }
        log.add('force_close:$app');
        _blocked = false;
        blockingApp = null;
        _ending();
        return const SessionSwitchForceCloseResult().toJson();
      case 'session.switch_cancel':
        if (!_switching) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'no switch is running',
            {'field': 'switch', 'reason': 'no_switch'},
          );
        }
        log.add('switch_cancel');
        _switching = false;
        _blocked = false;
        emit(
          'switch_progress',
          const SwitchProgressEvent(stage: SwitchStage.cancelled).toJson(),
        );
        return const SessionSwitchCancelResult().toJson();
      case 'session.unlock':
        final pin = SessionUnlockParams.fromJson(p).pin;
        final me = byId(current);
        if (!screenLocked || me == null) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'the screen is not locked',
            {'field': 'pin', 'reason': 'not_locked'},
          );
        }
        _check(me, pin, 'self');
        screenLocked = false;
        log.add('unlock');
        emit('lock_state', const LockStateEvent(locked: false).toJson());
        return const SessionUnlockResult().toJson();
      case 'session.end_guest':
        if (current != 'guest') {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'only the guest session can be ended this way',
            {'field': 'session', 'reason': 'not_guest'},
          );
        }
        log.add('end_guest');
        _switching = true;
        _ending();
        return const SessionEndGuestResult().toJson();
      case 'greeter.list':
        _greeterOnly();
        return _greeterList().toJson();
      case 'greeter.login':
        _greeterOnly();
        return _greeterLogin(GreeterLoginParams.fromJson(p).id as String);
      case 'greeter.pin':
        _greeterOnly();
        return _greeterPin(GreeterPinParams.fromJson(p).pin);
      case 'greeter.cancel':
        _greeterOnly();
        _greeterPending = null;
        _greeterPrompted = false;
        log.add('greeter_cancel');
        return const GreeterCancelResult().toJson();
      case 'greeter.create':
        _greeterOnly();
        final c = GreeterCreateParams.fromJson(p);
        return _create(c.name, c.color, c.pin, c.locked, token: true);
      case 'system.profiles.list':
        return SystemProfilesListResult(
          profiles: [
            for (final x in profiles)
              SystemProfilesListResultProfilesItem.fromJson(_wire(x).toJson()),
          ],
          guest: SystemProfilesListResultGuest(
            enabled: guestEnabled,
            usage: null,
          ),
          max: max,
          firstBoot: !profiles.any((x) => x.admin),
          caller: SystemProfilesListResultCaller(
            id: current == 'guest' ? null : current,
            user: current == 'guest'
                ? 'hinteros-guest'
                : (byId(current)?.user ?? 'hinteros'),
            guest: current == 'guest',
            spare: byId(current) == null && current != 'guest',
          ),
        ).toJson();
      case 'system.profiles.create':
        final c = SystemProfilesCreateParams.fromJson(p);
        _staleRevision(c.revision);
        return _create(c.name, c.color, c.pin, c.locked);
      case 'system.profiles.setup_admin':
        final c = SystemProfilesSetupAdminParams.fromJson(p);
        if (!setupRequired || profiles.any((x) => x.admin)) {
          throw const ApiException(
            ApiErrorCode.permissionDenied,
            'an admin profile exists already',
            {'action': 'org.hinteros.system.profiles', 'reason': 'polkit'},
          );
        }
        profiles.insert(
          0,
          MockWireProfile(
            id: current,
            name: c.name.trim(),
            color: c.color ?? ProfileColor.teal,
            pin: c.pin,
            admin: true,
            locked: c.locked,
          ),
        );
        setupRequired = false;
        log.add('setup_admin:$current');
        _changed();
        return SystemProfilesSetupAdminResult(id: current).toJson();
      case 'system.profiles.rename':
        final c = SystemProfilesRenameParams.fromJson(p);
        final x = _profile(c.id);
        if (c.id != current) _check(admin, c.pin, 'admin');
        x.name = c.name.trim();
        log.add('rename:${c.id}');
        _changed();
        return const SystemProfilesRenameResult().toJson();
      case 'system.profiles.set_appearance':
        final c = SystemProfilesSetAppearanceParams.fromJson(p);
        final me = byId(current);
        if (me != null && c.color != null) me.color = c.color!;
        log.add('set_appearance');
        _changed();
        return const SystemProfilesSetAppearanceResult().toJson();
      case 'system.profiles.set_pin':
        final c = SystemProfilesSetPinParams.fromJson(p);
        final me = _profile(current);
        if (me.pin != null) _check(me, c.currentPin, 'self');
        me.pin = c.pin;
        log.add('set_pin');
        _changed();
        return const SystemProfilesSetPinResult().toJson();
      case 'system.profiles.set_locked':
        final c = SystemProfilesSetLockedParams.fromJson(p);
        final me = _profile(current);
        _check(me, c.pin, 'self');
        me.locked = c.locked;
        log.add('set_locked:${c.locked}');
        _changed();
        return const SystemProfilesSetLockedResult().toJson();
      case 'system.profiles.reset_pin':
        final c = SystemProfilesResetPinParams.fromJson(p);
        final x = _profile(c.id);
        _check(admin, c.adminPin, 'admin');
        x
          ..pin = c.newPin
          ..failures = 0
          ..lockedUntil = null;
        log.add('reset_pin:${c.id}');
        _changed();
        return const SystemProfilesResetPinResult().toJson();
      case 'system.profiles.remove':
        final c = SystemProfilesRemoveParams.fromJson(p);
        final x = _profile(c.id);
        if (c.confirmId != c.id) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'confirm_id must equal id',
            {'field': 'confirm_id', 'reason': 'mismatch'},
          );
        }
        if (x.admin) {
          throw const ApiException(
            ApiErrorCode.invalidParams,
            'the admin profile cannot be removed',
            {'field': 'id', 'reason': 'admin'},
          );
        }
        _check(
          c.id == current ? x : admin,
          c.pin,
          c.id == current ? 'self' : 'admin',
        );
        _staleRevision(c.revision);
        log.add('remove:${c.id}');
        return JobRef(
          jobId: relay.startJob(
            JobKind.profilesRemove,
            onSuccess: () {
              profiles.remove(x);
              _changed();
            },
          ),
        ).toJson();
      case 'system.guest.set':
        final c = SystemGuestSetParams.fromJson(p);
        _check(admin, c.adminPin, 'admin');
        if (c.enabled == guestEnabled) {
          return const JobRef(jobId: null).toJson();
        }
        log.add('guest:${c.enabled}');
        return JobRef(
          jobId: relay.startJob(
            JobKind.guestSet,
            onSuccess: () => guestEnabled = c.enabled,
          ),
        ).toJson();
      case 'system.apps.list':
        _appsAvailable();
        final ids = [...relay.installedApps]..sort();
        return SystemAppsListResult(
          generation: appGeneration,
          revision: relay.revision,
          ids: ids,
          needsTerms: [
            for (final id in ids)
              if (needsTerms.contains(id)) id,
          ],
          box: ids.contains('steam')
              ? const [BoxFeature.graphics32, BoxFeature.steamDevices]
              : const [],
        ).toJson();
      case 'system.apps.generations':
        _appsAvailable();
        final earlier = appGenerations.keys.toList()..sort((a, b) => b - a);
        return SystemAppsGenerationsResult(
          generations: [
            SystemAppsGenerationsResultGenerationsItem(
              generation: appGeneration,
              date: _nowS,
              ids: [...relay.installedApps]..sort(),
              systemRev: relay.rev,
              current: true,
            ),
            for (final g in earlier)
              SystemAppsGenerationsResultGenerationsItem(
                generation: g,
                date: _nowS - (appGeneration - g) * 86400,
                ids: appGenerations[g]!,
                systemRev: null,
                current: false,
              ),
          ],
        ).toJson();
      case 'system.apps.rollback':
        _appsAvailable();
        final g = SystemAppsRollbackParams.fromJson(p).generation;
        final ids = appGenerations[g];
        if (ids == null) {
          throw ApiException(
            ApiErrorCode.notFound,
            g == appGeneration
                ? 'generation $g is the current one'
                : 'no generation $g',
          );
        }
        log.add('apps_rollback:$g');
        return JobRef(
          jobId: relay.startJob(
            JobKind.appsRollback,
            onSuccess: () {
              appGenerations[appGeneration] = [...relay.installedApps];
              appGeneration++;
              relay.installedApps
                ..clear()
                ..addAll(ids);
            },
          ),
        ).toJson();
      case 'system.apps.accept_terms':
        _appsAvailable();
        final c = SystemAppsAcceptTermsParams.fromJson(p);
        final app = relay.catalog.where((a) => a.id == c.id).firstOrNull;
        if (!needsTerms.contains(c.id) || app?.terms == null) {
          throw ApiException(
            ApiErrorCode.notFound,
            '${c.id} has no terms waiting',
          );
        }
        final version = app!.terms!.version;
        if (c.version != version) {
          throw ApiException(
            ApiErrorCode.invalidParams,
            'the current terms version of ${c.id} is $version',
            {'field': 'version', 'reason': 'not_current'},
          );
        }
        needsTerms.remove(c.id);
        relay.acceptances.add('${c.id}=$version');
        log.add('accept_terms:${c.id}');
        onTermsAccepted?.call(c.id);
        return const SystemAppsAcceptTermsResult().toJson();
      case 'system.profiles.switch':
        final id = SystemProfilesSwitchParams.fromJson(p).id as String;
        if (id != 'guest') _profile(id);
        log.add('switch_hint:$id');
        return const SystemProfilesSwitchResult().toJson();
      case 'system.profiles.unlock':
        final c = SystemProfilesUnlockParams.fromJson(p);
        _check(_profile(current), c.pin, 'self');
        log.add('unlock');
        return const SystemProfilesUnlockResult().toJson();
      case 'system.display.save_mode':
        final c = SystemDisplaySaveModeParams.fromJson(p);
        log.add('save_mode:${c.width}x${c.height}@${c.refresh}');
        return const SystemDisplaySaveModeResult().toJson();
      case 'system.audio.save_output':
        log.add('save_output:${SystemAudioSaveOutputParams.fromJson(p).node}');
        return const SystemAudioSaveOutputResult().toJson();
      case 'system.starter_set.get':
        return SystemStarterSetGetResult(
          ids: List.of(starter),
          updatedAt: 1790000000,
        ).toJson();
      case 'system.starter_set.set':
        final c = SystemStarterSetSetParams.fromJson(p);
        _check(admin, c.pin, 'admin');
        for (final id in c.ids) {
          if (!relay.installedApps.contains(id)) {
            throw ApiException(
              ApiErrorCode.invalidParams,
              '$id is not in the admin profile',
              {'field': 'ids', 'reason': 'not_in_admin_profile'},
            );
          }
        }
        final want = [...c.ids]..sort();
        if (want.join(',') == ([...starter]..sort()).join(',')) {
          return const JobRef(jobId: null).toJson();
        }
        log.add('starter:${want.join(',')}');
        return JobRef(
          jobId: relay.startJob(
            JobKind.starterSet,
            onSuccess: () => starter = want,
          ),
        ).toJson();
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  ProfileCurrentResult _current() {
    if (current == 'guest') {
      return ProfileCurrentResult(
        id: null,
        name: null,
        color: null,
        admin: false,
        locked: false,
        guest: true,
        setupRequired: false,
        pinSet: false,
        screenLocked: false,
      );
    }
    final me = byId(current);
    if (setupRequired || me == null) {
      return ProfileCurrentResult(
        id: null,
        name: null,
        color: null,
        admin: false,
        locked: false,
        guest: false,
        setupRequired: true,
        pinSet: false,
        screenLocked: screenLocked,
      );
    }
    return ProfileCurrentResult(
      id: me.id,
      name: me.name,
      color: me.color,
      admin: me.admin,
      locked: me.locked,
      guest: false,
      setupRequired: false,
      pinSet: me.pin != null,
      screenLocked: screenLocked,
    );
  }

  Map<String, dynamic> _create(
    String name,
    ProfileColor? color,
    String pin,
    bool locked, {
    bool token = false,
  }) {
    if (profiles.length >= max) {
      throw ApiException(
        ApiErrorCode.profileLimit,
        'this box already has $max profiles',
        ProfileLimitData(max: max).toJson(),
      );
    }
    final id = 'p${next++}';
    log.add('create:$id');
    final job = relay.startJob(
      JobKind.profilesCreate,
      onSuccess: () {
        profiles.add(
          MockWireProfile(
            id: id,
            name: name.trim(),
            color: color ?? ProfileColor.teal,
            pin: pin,
            locked: locked,
          ),
        );
        if (token) _tokens.add(id);
        _changed();
      },
    );
    return SystemProfilesCreateResult(jobId: job, id: id).toJson();
  }

  // ---- the switch

  Map<String, dynamic> _switchTo(String id) {
    if (id == current) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        "that is this session's profile",
        {'field': 'id', 'reason': 'same'},
      );
    }
    if (id != 'guest') _profile(id);
    if (_switching) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        'a switch is already running',
        {'field': 'id', 'reason': 'busy'},
      );
    }
    log.add('switch:$id');
    _switching = true;
    final b = blockingApp;
    scheduleMicrotask(() {
      if (!_switching) return;
      emit(
        'switch_progress',
        SwitchProgressEvent(
          stage: SwitchStage.closingApps,
          app: b == null
              ? null
              : SwitchProgressEventApp(id: b.id, name: b.name),
        ).toJson(),
      );
      if (b != null) {
        _blocked = true;
        _emitBlocked(10);
      } else {
        _ending();
      }
    });
    return const SessionSwitchProfileResult().toJson();
  }

  /// Starts a switch to [id] that waits for [app] (contract tests).
  void blockSwitch(String id, ({String id, String name}) app) {
    blockingApp = app;
    _switching = true;
    _blocked = true;
    log.add('switch:$id');
  }

  void _emitBlocked(int waited) {
    final b = blockingApp;
    if (b == null) return;
    emit(
      'switch_blocked',
      SwitchBlockedEvent(
        app: SwitchBlockedEventApp(id: b.id, name: b.name),
        waitedS: waited,
      ).toJson(),
    );
  }

  void _ending() {
    emit(
      'switch_progress',
      const SwitchProgressEvent(stage: SwitchStage.closingSteam).toJson(),
    );
    emit(
      'switch_progress',
      const SwitchProgressEvent(stage: SwitchStage.ending).toJson(),
    );
    _switching = false;
  }

  /// The box goes to sleep while a locked profile is on screen.
  void sleep() {
    if (byId(current)?.locked != true) return;
    screenLocked = true;
    emit('lock_state', const LockStateEvent(locked: true).toJson());
  }

  // ---- the greeter

  GreeterListResult _greeterList() => GreeterListResult(
    profiles: [
      for (final x in profiles)
        GreeterListResultProfilesItem(
          id: x.id,
          name: x.name,
          color: x.color,
          locked: x.locked,
          admin: x.admin,
          lockedUntil: x.lockedUntil,
        ),
    ],
    guest: guestEnabled,
    firstBoot: !profiles.any((x) => x.admin),
    focus: profiles.isEmpty ? null : profiles.first.id,
    switchTo: switchTo,
    appearance: const GreeterListResultAppearance(
      textScale: 1.0,
      highContrast: false,
      reduceMotion: false,
    ),
  );

  Map<String, dynamic> _greeterLogin(String id) {
    if (id != 'guest') _profile(id);
    log.add('greeter_login:$id');
    _greeterPending = id;
    _greeterPrompted = false;
    final x = byId(id);
    scheduleMicrotask(() {
      if (_greeterPending != id) return;
      if (x == null || !x.locked || _tokens.remove(id)) {
        _greeterPending = null;
        emit('greeter_result', GreeterResultEvent(ok: true).toJson());
      } else {
        _greeterPrompted = true;
        emit(
          'greeter_prompt',
          GreeterPromptEvent(kind: GreeterPromptEventKind.pin).toJson(),
        );
      }
    });
    return const GreeterLoginResult().toJson();
  }

  /// A login waiting for its PIN (contract tests).
  void promptFor(String id) {
    _greeterPending = id;
    _greeterPrompted = true;
  }

  Map<String, dynamic> _greeterPin(String pin) {
    final id = _greeterPending;
    if (id == null || !_greeterPrompted) {
      throw const ApiException(
        ApiErrorCode.invalidParams,
        'no PIN prompt is waiting',
        {'field': 'pin', 'reason': 'no_prompt'},
      );
    }
    _greeterPending = null;
    _greeterPrompted = false;
    final x = _profile(id);
    int? locked;
    var ok = true;
    try {
      _check(x, pin, 'self');
    } on ApiException catch (e) {
      ok = false;
      final ms = (e.data as Map?)?['retry_after_ms'] as int?;
      if (ms != null) locked = (ms / 1000).ceil();
    }
    log.add('greeter_pin:$id:${ok ? 'ok' : 'refused'}');
    scheduleMicrotask(
      () => emit(
        'greeter_result',
        GreeterResultEvent(ok: ok, lockedSeconds: locked).toJson(),
      ),
    );
    return const GreeterPinResult().toJson();
  }
}
