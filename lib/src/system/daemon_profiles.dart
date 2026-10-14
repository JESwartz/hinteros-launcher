/// Profiles over session API 0.12: `profile.current`, the relayed
/// `system.profiles.*`, `system.guest.set` and `system.starter_set.*`, the
/// switch (`session.switch_*`, `switch_progress`, `switch_blocked`), the sleep
/// lock (`lock_state`, `session.unlock`), and the greeter-mode methods
/// (`greeter.*`, `greeter_prompt`, `greeter_result`).
library;

import 'dart:async';

import '../api/api.dart' as api;
import 'daemon_errors.dart';
import 'daemon_system.dart' show DaemonJobs;
import 'models.dart';
import 'profiles.dart';

ProfileColor _color(api.ProfileColor? c) => ProfileColor.parse(c?.value);

api.ProfileColor _wireColor(ProfileColor c) =>
    api.ProfileColor.fromJson(c.name);

DateTime? _time(int? seconds) => seconds == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

ProfileUsage? _usage(api.ProfileUsage? u) => u == null
    ? null
    : ProfileUsage(
        totalBytes: u.totalBytes,
        steamGamesBytes: u.steamGamesBytes,
        at: _time(u.at)!,
      );

ProfileInfo _profile(api.ProfileInfo p) => ProfileInfo(
  id: p.id,
  name: p.name,
  color: _color(p.color),
  admin: p.admin,
  locked: p.locked,
  lockedUntil: _time(p.lockedUntil),
  active: p.active,
  lastUsedAt: _time(p.lastUsedAt),
  usage: _usage(p.usage),
  pinSet: p.pinSet,
);

/// The session side over the session daemon.
class DaemonProfiles implements ProfilesRepository {
  DaemonProfiles(this._conn, this._jobs) {
    _events = _conn.events.listen(_onEvent);
    unawaited(
      _conn
          .subscribeTo(const [
            api.EventName.profilesChanged,
            api.EventName.lockState,
            api.EventName.switchProgress,
            api.EventName.switchBlocked,
          ])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;
  late final StreamSubscription<api.SessionEvent> _events;
  final _changes = StreamController<List<ProfileInfo>>.broadcast();
  final _lock = StreamController<bool>.broadcast();
  final _switch = StreamController<SwitchEvent>.broadcast();

  @override
  Stream<List<ProfileInfo>> get changes => _changes.stream;
  @override
  Stream<bool> get lockChanges => _lock.stream;
  @override
  Stream<SwitchEvent> get switchEvents => _switch.stream;

  void _onEvent(api.SessionEvent e) {
    switch (e) {
      case api.ProfilesChangedEvent():
        _changes.add([for (final p in e.profiles) _profile(p)]);
      case api.LockStateEvent():
        _lock.add(e.locked);
      case api.SwitchProgressEvent():
        _switch.add(
          SwitchProgress(
            switch (e.stage) {
              api.SwitchStage.closingSteam => SwitchStage.closingSteam,
              api.SwitchStage.ending => SwitchStage.ending,
              api.SwitchStage.cancelled => SwitchStage.cancelled,
              _ => SwitchStage.closingApps,
            },
            appId: e.app?.id,
            appName: e.app?.name,
          ),
        );
      case api.SwitchBlockedEvent():
        _switch.add(
          SwitchBlocked(
            appId: e.app.id,
            appName: e.app.name,
            waited: Duration(seconds: e.waitedS),
          ),
        );
      default:
        break;
    }
  }

  @override
  Future<CurrentProfile> current() => guardCall(() async {
    final r = await _conn.profileCurrent();
    return CurrentProfile(
      // The guest and a spare account have no profile id.
      id: r.id ?? (r.guest ? CurrentProfile.guestId : ''),
      name: r.name,
      color: r.color == null ? null : _color(r.color),
      admin: r.admin,
      locked: r.locked,
      guest: r.guest,
      setupRequired: r.setupRequired,
      pinSet: r.pinSet,
      screenLocked: r.screenLocked,
    );
  });

  @override
  Future<ProfilesState> list() => guardCall(() async {
    final r = await _conn.systemProfilesList();
    return ProfilesState(
      // The same shape as profiles_changed's ProfileInfo (inlined in the
      // schema, so a separate generated class).
      profiles: [
        for (final p in r.profiles)
          _profile(api.ProfileInfo.fromJson(p.toJson())),
      ],
      guestEnabled: r.guest.enabled,
      guestUsage: _usage(r.guest.usage),
      max: r.max,
      firstBoot: r.firstBoot,
    );
  });

  /// `settings.get`'s revision; a stale one is fetched again once.
  Future<T> _withRevision<T>(Future<T> Function(String revision) call) async {
    for (var attempt = 0; ; attempt++) {
      final revision = (await _conn.systemSettingsGet()).revision;
      try {
        return await call(revision);
      } on api.ApiException catch (e) {
        if (e.code == api.ApiErrorCode.stateConflict && attempt == 0) continue;
        rethrow;
      }
    }
  }

  @override
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) async {
    String? id;
    final h = await _jobs.start(
      JobKind.profileCreate,
      () => _withRevision((revision) async {
        final r = await _conn.systemProfilesCreate(
          api.SystemProfilesCreateParams(
            name: name.trim(),
            color: _wireColor(color),
            pin: pin,
            locked: locked,
            revision: revision,
          ),
        );
        id = r.id;
        return r.jobId;
      }),
    );
    return ProfileJob(h, id!);
  }

  @override
  Future<void> setupAdmin({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) => guardCall(
    () => _conn.systemProfilesSetupAdmin(
      api.SystemProfilesSetupAdminParams(
        name: name.trim(),
        color: _wireColor(color),
        pin: pin,
        locked: locked,
      ),
    ),
  );

  @override
  Future<void> rename(String id, String name, {String? adminPin}) => guardCall(
    () => _conn.systemProfilesRename(
      api.SystemProfilesRenameParams(id: id, name: name.trim(), pin: adminPin),
    ),
  );

  @override
  Future<void> setColor(ProfileColor color) => guardCall(
    () => _conn.systemProfilesSetAppearance(
      api.SystemProfilesSetAppearanceParams(color: _wireColor(color)),
    ),
  );

  @override
  Future<void> mirrorAppearance({
    required double textScale,
    required bool highContrast,
    required bool reduceMotion,
  }) => guardCall(
    () => _conn.systemProfilesSetAppearance(
      api.SystemProfilesSetAppearanceParams(
        textScale: textScale,
        highContrast: highContrast,
        reduceMotion: reduceMotion,
      ),
    ),
  );

  @override
  Future<void> setPin(String pin, {String? currentPin}) => guardCall(
    () => _conn.systemProfilesSetPin(
      api.SystemProfilesSetPinParams(pin: pin, currentPin: currentPin),
    ),
  );

  @override
  Future<void> setLocked(bool locked, String pin) => guardCall(
    () => _conn.systemProfilesSetLocked(
      api.SystemProfilesSetLockedParams(locked: locked, pin: pin),
    ),
  );

  @override
  Future<void> resetPin(String id, String newPin, {required String adminPin}) =>
      guardCall(
        () => _conn.systemProfilesResetPin(
          api.SystemProfilesResetPinParams(
            id: id,
            newPin: newPin,
            adminPin: adminPin,
          ),
        ),
      );

  @override
  Future<JobHandle> remove(String id, String pin) => _jobs.start(
    JobKind.profileRemove,
    () => _withRevision(
      (revision) async => (await _conn.systemProfilesRemove(
        api.SystemProfilesRemoveParams(
          id: id,
          confirmId: id,
          pin: pin,
          revision: revision,
        ),
      )).jobId,
    ),
  );

  @override
  Future<JobHandle?> setGuest(bool enabled, String adminPin) async {
    try {
      return await _jobs.start(
        JobKind.guest,
        () async => (await _conn.systemGuestSet(
          api.SystemGuestSetParams(enabled: enabled, adminPin: adminPin),
        )).jobId,
      );
    } on SystemException catch (e) {
      if (e.kind == SystemErrorKind.nothingToDo) return null;
      rethrow;
    }
  }

  @override
  Future<StarterSet> starterSet() => guardCall(() async {
    final r = await _conn.systemStarterSetGet();
    return StarterSet(r.ids, updatedAt: _time(r.updatedAt));
  });

  @override
  Future<JobHandle?> setStarterSet(List<String> ids, String adminPin) async {
    try {
      return await _jobs.start(
        JobKind.starterSet,
        () async => (await _conn.systemStarterSetSet(
          api.SystemStarterSetSetParams(ids: ids, pin: adminPin),
        )).jobId,
      );
    } on SystemException catch (e) {
      if (e.kind == SystemErrorKind.nothingToDo) return null;
      rethrow;
    }
  }

  @override
  Future<void> switchTo(String id, {String? pin}) => guardCall(
    () => _conn.sessionSwitchProfile(
      api.SessionSwitchProfileParams(id: id, pin: pin),
    ),
  );

  @override
  Future<void> keepWaiting() => guardCall(() => _conn.sessionSwitchWait());

  @override
  Future<void> forceClose(String appId) => guardCall(
    () => _conn.sessionSwitchForceClose(
      api.SessionSwitchForceCloseParams(app: appId),
    ),
  );

  @override
  Future<void> cancelSwitch() => guardCall(() => _conn.sessionSwitchCancel());

  @override
  Future<void> unlock(String pin) =>
      guardCall(() => _conn.sessionUnlock(api.SessionUnlockParams(pin: pin)));

  @override
  Future<void> endGuest() => guardCall(() => _conn.sessionEndGuest());

  Future<void> dispose() async {
    await _events.cancel();
  }
}

// ---------------------------------------------------------------- greeter

/// The picker over the greeter-mode session daemon.
class DaemonGreeter implements GreeterRepository {
  DaemonGreeter(
    this._conn,
    this._jobs, {
    this.answerTimeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _events = _conn.events.listen(_onEvent);
    unawaited(
      _conn
          .subscribeTo(const [
            api.EventName.greeterPrompt,
            api.EventName.greeterResult,
          ])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;
  final DateTime Function() _now;

  /// How long greetd may take to answer a login or a PIN.
  final Duration answerTimeout;
  late final StreamSubscription<api.SessionEvent> _events;
  final _answers = StreamController<api.SessionEvent>.broadcast(sync: true);

  /// The profile whose PIN greetd is waiting for.
  String? _prompted;

  void _onEvent(api.SessionEvent e) {
    if (e is api.GreeterPromptEvent || e is api.GreeterResultEvent) {
      _answers.add(e);
    }
  }

  @override
  Future<PickerView> load() => guardCall(() async {
    final r = await _conn.greeterList();
    return PickerView(
      profiles: [
        for (final p in r.profiles)
          PickerProfile(
            id: p.id,
            name: p.name,
            color: _color(p.color),
            locked: p.locked,
            admin: p.admin,
            lockedUntil: _time(p.lockedUntil),
          ),
      ],
      guest: r.guest,
      firstBoot: r.firstBoot,
      focus: r.focus as String?,
      switchTo: r.switchTo as String?,
      appearance: PickerAppearance(
        textScale: r.appearance.textScale.toDouble(),
        highContrast: r.appearance.highContrast,
        reduceMotion: r.appearance.reduceMotion,
      ),
    );
  });

  /// The next prompt (a PIN) or result. The daemon runs one greetd
  /// conversation at a time, so the events carry no profile id.
  Future<api.SessionEvent> _nextAnswer() => _answers.stream
      .where(
        (e) => switch (e) {
          api.GreeterPromptEvent() => e.kind == api.GreeterPromptEventKind.pin,
          api.GreeterResultEvent() => true,
          _ => false,
        },
      )
      .first
      .timeout(answerTimeout);

  LoginOutcome _result(api.GreeterResultEvent r) {
    _prompted = null;
    if (r.ok) return const LoginStarted();
    final s = r.lockedSeconds;
    return LoginRefused(
      retryAt: s == null || s == 0 ? null : _now().add(Duration(seconds: s)),
      rebootRequired: r.rebootRequired ?? false,
    );
  }

  @override
  Future<LoginOutcome> login(String id, {String? pin}) => guardCall(() async {
    if (_prompted != id) {
      final answer = _nextAnswer();
      await _conn.greeterLogin(api.GreeterLoginParams(id: id));
      final a = await answer;
      if (a is api.GreeterResultEvent) return _result(a);
      _prompted = id;
    }
    if (pin == null) return const LoginNeedsPin();
    final answer = _answers.stream
        .whereType<api.GreeterResultEvent>()
        .first
        .timeout(answerTimeout);
    await _conn.greeterPin(api.GreeterPinParams(pin: pin));
    return _result(await answer);
  });

  @override
  Future<void> cancel() async {
    _prompted = null;
    await guardCall(() => _conn.greeterCancel());
  }

  @override
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) async {
    String? id;
    final h = await _jobs.start(JobKind.profileCreate, () async {
      final r = await _conn.greeterCreate(
        api.GreeterCreateParams(
          name: name.trim(),
          color: _wireColor(color),
          pin: pin,
          locked: locked,
        ),
      );
      id = r.id;
      return r.jobId;
    });
    return ProfileJob(h, id!);
  }

  Future<void> dispose() async {
    await _events.cancel();
    await _answers.close();
  }
}

extension<T> on Stream<T> {
  Stream<S> whereType<S>() => where((e) => e is S).cast<S>();
}
