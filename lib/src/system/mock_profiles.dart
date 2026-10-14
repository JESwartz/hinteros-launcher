/// In-process fakes of the profile repositories (session and greeter side),
/// in the spirit of the other mocks: the service's rules (which PIN each
/// action needs, the backoff after three wrong PINs, the limit of 8, never
/// removing the admin profile, jobs for create, remove, guest and the
/// starter set) on placeholder data. Driven from tests and `--mock`.
library;

import 'dart:async';

import 'mock_system.dart' show MockJobs;
import 'models.dart';
import 'profiles.dart';

/// One profile of the fake box, with its PIN.
class MockProfile {
  MockProfile({
    required this.id,
    required this.name,
    required this.color,
    required this.pin,
    this.admin = false,
    this.locked = false,
    this.usage,
    this.lastUsedAt,
  });

  final String id;
  String name;
  ProfileColor color;

  /// Null: a profile migrated without a PIN.
  String? pin;
  final bool admin;
  bool locked;
  ProfileUsage? usage;
  DateTime? lastUsedAt;
  int failures = 0;
  DateTime? lockedUntil;
}

/// The PINs, profiles and backoff the session and greeter fakes share (one
/// box).
class MockProfileBox {
  MockProfileBox({
    List<MockProfile>? profiles,
    this.guestEnabled = true,
    this.max = 8,
    DateTime Function()? now,
    this.firstLock = const Duration(seconds: 30),
  }) : now = now ?? DateTime.now,
       profiles = profiles ?? defaultProfiles();

  /// James (the admin profile, PIN 2468, unlocked) and Sam (PIN 1357,
  /// locked), with storage numbers.
  static List<MockProfile> defaultProfiles() => [
    MockProfile(
      id: 'p1',
      name: 'James',
      color: ProfileColor.teal,
      pin: '2468',
      admin: true,
      usage: ProfileUsage(
        totalBytes: 52000000000,
        steamGamesBytes: 48000000000,
        at: DateTime(2026, 10, 7, 21),
      ),
      lastUsedAt: DateTime(2026, 10, 7, 22),
    ),
    MockProfile(
      id: 'p3',
      name: 'Sam',
      color: ProfileColor.orange,
      pin: '1357',
      locked: true,
      usage: ProfileUsage(
        totalBytes: 34000000000,
        steamGamesBytes: 31000000000,
        at: DateTime(2026, 10, 7, 21),
      ),
      lastUsedAt: DateTime(2026, 10, 6, 19),
    ),
  ];

  final List<MockProfile> profiles;
  bool guestEnabled;
  final int max;
  final DateTime Function() now;

  /// How long the first backoff lock lasts (then doubling up to 5 min). The
  /// real one starts at 1 s; the mock's matches the design's example.
  final Duration firstLock;

  /// The counter for new ids (never goes back).
  int next = 4;

  MockProfile? byId(String id) => profiles.where((p) => p.id == id).firstOrNull;
  MockProfile get admin => profiles.firstWhere((p) => p.admin);

  /// Checks [pin] against profile [p] as the service does: 3 free failures,
  /// then a lock that doubles; none for the admin profile's PIN, which has 10
  /// wrong tries a boot, then refuses every PIN until [reboot]. Throws
  /// `pin_required` naming [kind].
  void checkPin(MockProfile p, String? pin, PinKind kind) {
    if (p.admin) {
      p.lockedUntil = null;
      if (pin == null) throw _pinRequired(kind, null);
      if (p.failures >= adminTries) throw _rebootRequired(kind);
      if (pin == p.pin) {
        p.failures = 0;
        return;
      }
      p.failures++;
      if (p.failures >= adminTries) throw _rebootRequired(kind);
      throw _pinRequired(kind, null);
    }
    final t = now();
    final until = p.lockedUntil;
    if (until != null && t.isBefore(until)) {
      throw _pinRequired(kind, until.difference(t));
    }
    if (pin != null && pin == p.pin) {
      p.failures = 0;
      p.lockedUntil = null;
      return;
    }
    if (pin == null) throw _pinRequired(kind, null);
    p.failures++;
    if (p.failures > 3) {
      var d = firstLock * (1 << (p.failures - 4).clamp(0, 16));
      if (d > const Duration(minutes: 5)) d = const Duration(minutes: 5);
      p.lockedUntil = t.add(d);
      throw _pinRequired(kind, d);
    }
    throw _pinRequired(kind, null);
  }

  /// No profiles or PINs yet (before the migration): the box-wide actions
  /// need no PIN.
  bool schema1 = false;

  /// The admin PIN of the box-wide actions (update, rollback, channel,
  /// base, hardware; session API 0.13): none on a schema-1 box or while the
  /// admin profile has no PIN; `pin_required {pin: admin}` when it is missing or
  /// wrong, or when there is no admin profile.
  void checkBoxAdmin(String? pin) {
    if (schema1) return;
    final a = profiles.where((p) => p.admin).firstOrNull;
    if (a == null) {
      throw const SystemException(
        SystemErrorKind.pinRequired,
        'There is no admin profile.',
        data: {'pin': 'admin'},
      );
    }
    if (a.pin == null) return;
    checkPin(a, pin, PinKind.admin);
  }

  /// Wrong admin-PIN tries a boot.
  static const adminTries = 10;

  /// A restart of the box: the admin PIN may be tried again.
  void reboot() {
    for (final p in profiles.where((p) => p.admin)) {
      p.failures = 0;
    }
  }

  static SystemException _rebootRequired(PinKind kind) => SystemException(
    SystemErrorKind.pinRequired,
    'Too many wrong PINs. Restart the box to try again.',
    data: {'pin': kind.name, 'reboot_required': true},
  );

  static SystemException _pinRequired(PinKind kind, Duration? wait) =>
      SystemException(
        SystemErrorKind.pinRequired,
        wait == null ? "That PIN didn't match." : 'Too many tries.',
        data: {
          'pin': kind.name,
          if (wait != null) 'retry_after_ms': wait.inMilliseconds,
        },
      );

  ProfileInfo info(MockProfile p, {String? activeId}) => ProfileInfo(
    id: p.id,
    name: p.name,
    color: p.color,
    admin: p.admin,
    locked: p.locked,
    lockedUntil: p.lockedUntil,
    active: p.id == activeId,
    lastUsedAt: p.lastUsedAt,
    usage: p.usage,
    pinSet: p.pin != null,
  );
}

/// The session side: one profile's session on the fake box.
class MockProfiles implements ProfilesRepository {
  MockProfiles(
    this.jobs, {
    MockProfileBox? box,
    this.currentId = 'p1',
    this.setupRequired = false,
    Set<String> Function()? adminApps,
    this.switchStepDelay = const Duration(milliseconds: 600),
  }) : box = box ?? MockProfileBox(),
       _adminApps = adminApps ?? (() => const {'firefox', 'youtube', 'steam'});

  final MockJobs jobs;
  final MockProfileBox box;

  /// Whose session this is: a profile id, or `guest`.
  String currentId;

  /// First-boot mode: the session's account is a spare (no profile yet).
  bool setupRequired;

  /// The admin profile's installed apps (what the starter set may hold).
  final Set<String> Function() _adminApps;

  /// Time between switch stages.
  Duration switchStepDelay;

  /// The app that does not close on a switch (the not-responding pop-up),
  /// by id and name.
  ({String id, String name})? blockingApp;

  /// The sleep lock is up.
  bool screenLocked = false;

  StarterSet starter = StarterSet(const [
    'firefox',
    'youtube',
  ], updatedAt: DateTime(2026, 10, 1));

  /// The next mutating call fails with this.
  SystemException? failNext;

  /// What happened, in order (`rename:p3:Samantha`, `switch:p3`,
  /// `force_close:youtube`, ...). Never a PIN.
  final List<String> log = [];

  final _changes = StreamController<List<ProfileInfo>>.broadcast();
  final _lock = StreamController<bool>.broadcast();
  final _switch = StreamController<SwitchEvent>.broadcast();
  Timer? _switchTimer;
  bool _switching = false;

  /// Where a switch went (set when it reached `ending`).
  String? switchedTo;

  @override
  Stream<List<ProfileInfo>> get changes => _changes.stream;
  @override
  Stream<bool> get lockChanges => _lock.stream;
  @override
  Stream<SwitchEvent> get switchEvents => _switch.stream;

  bool get isGuest => currentId == CurrentProfile.guestId;
  MockProfile? get _me => box.byId(currentId);

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  void _changed() => _changes.add([
    for (final p in box.profiles) box.info(p, activeId: currentId),
  ]);

  /// The next `profile.current` fails (no daemon).
  bool failNextCurrent = false;

  @override
  Future<CurrentProfile> current() async {
    if (failNextCurrent) {
      failNextCurrent = false;
      throw const SystemException(
        SystemErrorKind.unavailable,
        'The launcher is not connected to HinterOS.',
      );
    }
    if (isGuest) {
      return CurrentProfile(
        id: CurrentProfile.guestId,
        name: 'Guest',
        guest: true,
        pinSet: false,
        screenLocked: screenLocked,
      );
    }
    final me = _me;
    if (setupRequired || me == null) {
      return CurrentProfile(
        id: currentId,
        setupRequired: true,
        pinSet: false,
        screenLocked: screenLocked,
      );
    }
    return CurrentProfile(
      id: me.id,
      name: me.name,
      color: me.color,
      admin: me.admin,
      locked: me.locked,
      pinSet: me.pin != null,
      screenLocked: screenLocked,
    );
  }

  @override
  Future<ProfilesState> list() async => ProfilesState(
    profiles: [for (final p in box.profiles) box.info(p, activeId: currentId)],
    guestEnabled: box.guestEnabled,
    guestUsage: box.guestEnabled
        ? ProfileUsage(
            totalBytes: 1200000000,
            steamGamesBytes: 0,
            at: DateTime(2026, 10, 7, 21),
          )
        : null,
    max: box.max,
    firstBoot: !box.profiles.any((p) => p.admin),
  );

  MockProfile _profile(String id) =>
      box.byId(id) ??
      (throw SystemException(SystemErrorKind.notFound, 'No profile $id.'));

  @override
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) async {
    _maybeFail();
    if (box.profiles.length >= box.max) {
      throw SystemException(
        SystemErrorKind.profileLimit,
        'This box already has ${box.max} profiles.',
        data: {'max': box.max},
      );
    }
    final id = 'p${box.next++}';
    log.add('create:$id:${name.trim()}');
    final h = jobs.start(
      JobKind.profileCreate,
      subject: JobSubject(profileId: id, profileName: name.trim()),
      onSuccess: () {
        box.profiles.add(
          MockProfile(
            id: id,
            name: name.trim(),
            color: color,
            pin: pin,
            locked: locked,
          ),
        );
        _changed();
      },
    );
    return ProfileJob(h, id);
  }

  @override
  Future<void> setupAdmin({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) async {
    _maybeFail();
    if (box.profiles.any((p) => p.admin)) {
      throw const SystemException(
        SystemErrorKind.permissionDenied,
        'This box has an admin profile already.',
      );
    }
    log.add('setup_admin:$currentId:${name.trim()}');
    box.profiles.insert(
      0,
      MockProfile(
        id: currentId,
        name: name.trim(),
        color: color,
        pin: pin,
        admin: true,
        locked: locked,
      ),
    );
    setupRequired = false;
    _changed();
  }

  @override
  Future<void> rename(String id, String name, {String? adminPin}) async {
    _maybeFail();
    final p = _profile(id);
    if (id != currentId) box.checkPin(box.admin, adminPin, PinKind.admin);
    log.add('rename:$id:${name.trim()}');
    p.name = name.trim();
    _changed();
  }

  @override
  Future<void> setColor(ProfileColor color) async {
    _maybeFail();
    final me = _me;
    if (me == null) return;
    log.add('color:${color.name}');
    me.color = color;
    _changed();
  }

  /// The appearance the picker mirrors, as last sent.
  ({double textScale, bool highContrast, bool reduceMotion})? appearance;

  @override
  Future<void> mirrorAppearance({
    required double textScale,
    required bool highContrast,
    required bool reduceMotion,
  }) async {
    appearance = (
      textScale: textScale,
      highContrast: highContrast,
      reduceMotion: reduceMotion,
    );
  }

  @override
  Future<void> setPin(String pin, {String? currentPin}) async {
    _maybeFail();
    final me = _me!;
    if (me.pin != null) box.checkPin(me, currentPin, PinKind.self);
    log.add('set_pin:${me.id}');
    me.pin = pin;
    _changed();
  }

  @override
  Future<void> setLocked(bool locked, String pin) async {
    _maybeFail();
    final me = _me!;
    box.checkPin(me, pin, PinKind.self);
    log.add('set_locked:${me.id}:$locked');
    me.locked = locked;
    _changed();
  }

  @override
  Future<void> resetPin(
    String id,
    String newPin, {
    required String adminPin,
  }) async {
    _maybeFail();
    final p = _profile(id);
    box.checkPin(box.admin, adminPin, PinKind.admin);
    log.add('reset_pin:$id');
    p
      ..pin = newPin
      ..failures = 0
      ..lockedUntil = null;
    _changed();
  }

  @override
  Future<JobHandle> remove(String id, String pin) async {
    _maybeFail();
    final p = _profile(id);
    if (p.admin) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'The admin profile cannot be removed.',
        data: {'field': 'id', 'reason': 'admin'},
      );
    }
    if (id == currentId) {
      box.checkPin(p, pin, PinKind.self);
    } else {
      box.checkPin(box.admin, pin, PinKind.admin);
    }
    log.add('remove:$id');
    return jobs.start(
      JobKind.profileRemove,
      subject: JobSubject(profileId: id, profileName: p.name),
      onSuccess: () {
        box.profiles.remove(p);
        _changed();
      },
    );
  }

  @override
  Future<JobHandle?> setGuest(bool enabled, String adminPin) async {
    _maybeFail();
    box.checkPin(box.admin, adminPin, PinKind.admin);
    if (box.guestEnabled == enabled) return null;
    log.add('guest:$enabled');
    return jobs.start(
      JobKind.guest,
      subject: JobSubject(enabled: enabled),
      onSuccess: () {
        box.guestEnabled = enabled;
        _changed();
      },
    );
  }

  @override
  Future<StarterSet> starterSet() async => starter;

  @override
  Future<JobHandle?> setStarterSet(List<String> ids, String adminPin) async {
    _maybeFail();
    box.checkPin(box.admin, adminPin, PinKind.admin);
    final have = _adminApps();
    for (final id in ids) {
      if (!have.contains(id)) {
        throw SystemException(
          SystemErrorKind.invalidParams,
          '$id is not installed in the admin profile.',
          data: {'field': 'ids', 'reason': 'not_in_admin_profile'},
        );
      }
    }
    final sorted = [...ids]..sort();
    final before = [...starter.ids]..sort();
    if (sorted.join(',') == before.join(',')) return null;
    log.add('starter:${sorted.join(',')}');
    return jobs.start(
      JobKind.starterSet,
      subject: JobSubject(
        owner: 'starter',
        apps: [for (final id in sorted) (id: id, name: id)],
      ),
      onSuccess: () => starter = StarterSet(sorted, updatedAt: box.now()),
    );
  }

  @override
  Future<void> switchTo(String id, {String? pin}) async {
    _maybeFail();
    if (id == currentId) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'That is this profile.',
        data: {'field': 'id', 'reason': 'same'},
      );
    }
    if (id != CurrentProfile.guestId) {
      final p = _profile(id);
      // A locked target: its PIN first, before anything closes.
      if (p.locked && p.pin != null) box.checkPin(p, pin, PinKind.target);
    }
    if (_switching) {
      throw const SystemException(
        SystemErrorKind.jobBusy,
        'A switch is already under way.',
      );
    }
    log.add('switch:$id');
    _startSwitch(id);
  }

  void _startSwitch(String target) {
    _switching = true;
    final block = blockingApp;
    _step(() {
      _switch.add(
        SwitchProgress(
          SwitchStage.closingApps,
          appId: block?.id,
          appName: block?.name,
        ),
      );
      if (block != null) {
        _step(
          () => _switch.add(
            SwitchBlocked(
              appId: block.id,
              appName: block.name,
              waited: const Duration(seconds: 10),
            ),
          ),
        );
        _pendingTarget = target;
        return;
      }
      _finishSwitch(target);
    });
  }

  String? _pendingTarget;

  void _step(void Function() f) {
    _switchTimer?.cancel();
    _switchTimer = Timer(switchStepDelay, f);
  }

  void _finishSwitch(String target) {
    _step(() {
      _switch.add(const SwitchProgress(SwitchStage.closingSteam));
      _step(() {
        _switch.add(const SwitchProgress(SwitchStage.ending));
        switchedTo = target;
        _switching = false;
      });
    });
  }

  void _needBlocked() {
    if (_pendingTarget == null) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'No switch is waiting.',
      );
    }
  }

  @override
  Future<void> keepWaiting() async {
    _needBlocked();
    log.add('switch_wait');
    final b = blockingApp!;
    _step(
      () => _switch.add(
        SwitchBlocked(
          appId: b.id,
          appName: b.name,
          waited: const Duration(seconds: 20),
        ),
      ),
    );
  }

  @override
  Future<void> forceClose(String appId) async {
    _needBlocked();
    log.add('force_close:$appId');
    final t = _pendingTarget!;
    _pendingTarget = null;
    blockingApp = null;
    _finishSwitch(t);
  }

  @override
  Future<void> cancelSwitch() async {
    if (!_switching) {
      throw const SystemException(
        SystemErrorKind.notFound,
        'No switch is under way.',
      );
    }
    log.add('switch_cancel');
    _switchTimer?.cancel();
    _pendingTarget = null;
    _switching = false;
  }

  /// The box goes to sleep while a locked profile is on screen.
  void sleep() {
    if (_me?.locked != true) return;
    screenLocked = true;
    _lock.add(true);
  }

  @override
  Future<void> unlock(String pin) async {
    final me = _me;
    if (me == null || !screenLocked) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'The screen is not locked.',
        data: {'field': 'pin', 'reason': 'not_locked'},
      );
    }
    box.checkPin(me, pin, PinKind.self);
    log.add('unlock');
    screenLocked = false;
    _lock.add(false);
  }

  @override
  Future<void> endGuest() async {
    if (!isGuest) {
      throw const SystemException(
        SystemErrorKind.invalidParams,
        'Only the guest session can be ended this way.',
      );
    }
    log.add('end_guest');
    _switching = true;
    _step(() {
      _switch.add(const SwitchProgress(SwitchStage.closingApps));
      _finishSwitch('');
    });
  }

  void dispose() {
    _switchTimer?.cancel();
  }
}

/// The greeter side: the picker of the same fake box.
class MockGreeter implements GreeterRepository {
  MockGreeter(
    this.jobs, {
    MockProfileBox? box,
    this.focus = 'p1',
    this.switchTo,
  }) : box = box ?? MockProfileBox();

  final MockJobs jobs;
  final MockProfileBox box;
  String? focus;

  /// A pending switch (greeter.list `switch_to`).
  String? switchTo;

  /// Profiles that may be entered once without their PIN (just created).
  final Set<String> _tokens = {};

  /// The profile whose session started (the greeter would exit now).
  String? entered;

  /// What happened (`login:p3`, `pin:p3:wrong`, `create:p4`...). Never a PIN.
  final List<String> log = [];

  /// The next this many loads fail as if the daemon were not connected yet.
  int failLoads = 0;

  @override
  Future<PickerView> load() async {
    if (failLoads > 0) {
      failLoads--;
      throw const SystemException(
        SystemErrorKind.unavailable,
        'The launcher is not connected to HinterOS.',
      );
    }
    return _view();
  }

  PickerView _view() => PickerView(
    profiles: [
      for (final p in box.profiles)
        PickerProfile(
          id: p.id,
          name: p.name,
          color: p.color,
          locked: p.locked,
          admin: p.admin,
          lockedUntil: p.lockedUntil,
        ),
    ],
    guest: box.guestEnabled,
    firstBoot: !box.profiles.any((p) => p.admin),
    focus: focus,
    switchTo: switchTo,
  );

  @override
  Future<LoginOutcome> login(String id, {String? pin}) async {
    log.add('login:$id');
    if (id == CurrentProfile.guestId) {
      if (!box.guestEnabled) {
        throw const SystemException(
          SystemErrorKind.notFound,
          'The guest is turned off.',
        );
      }
      entered = id;
      return const LoginStarted();
    }
    final p =
        box.byId(id) ??
        (throw SystemException(SystemErrorKind.notFound, 'No profile $id.'));
    if (!p.locked || _tokens.remove(id)) {
      entered = id;
      return const LoginStarted();
    }
    if (pin == null) return const LoginNeedsPin();
    try {
      box.checkPin(p, pin, PinKind.target);
    } on SystemException catch (e) {
      log.add('pin:$id:refused');
      final r = PinRefusal.of(e, now: box.now);
      return LoginRefused(
        retryAt: r?.retryAt,
        rebootRequired: r?.rebootRequired ?? false,
      );
    }
    log.add('pin:$id:ok');
    entered = id;
    return const LoginStarted();
  }

  @override
  Future<void> cancel() async => log.add('cancel');

  @override
  Future<ProfileJob> create({
    required String name,
    required ProfileColor color,
    required String pin,
    required bool locked,
  }) async {
    if (box.profiles.length >= box.max) {
      throw SystemException(
        SystemErrorKind.profileLimit,
        'This box already has ${box.max} profiles.',
        data: {'max': box.max},
      );
    }
    final id = 'p${box.next++}';
    log.add('create:$id');
    final h = jobs.start(
      JobKind.profileCreate,
      subject: JobSubject(profileId: id, profileName: name.trim()),
      onSuccess: () {
        box.profiles.add(
          MockProfile(
            id: id,
            name: name.trim(),
            color: color,
            pin: pin,
            locked: locked,
          ),
        );
        _tokens.add(id);
      },
    );
    return ProfileJob(h, id);
  }
}
