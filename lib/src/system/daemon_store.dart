/// The Store over session API 0.8 and 0.9 (icons): `store.list` (the running
/// generation's catalog merged with what is installed), `store_changed`, and the relayed
/// `system.apps.install` / `system.apps.remove` with their job events.
library;

import 'dart:async';
import 'dart:io';

import '../api/api.dart' as api;
import 'catalog.dart';
import 'daemon_errors.dart';
import 'daemon_system.dart' show DaemonJobs;
import 'models.dart';
import 'repositories.dart';

StoreState _state(api.StoreState s) => switch (s) {
  api.StoreState.available || api.StoreState.unknown => StoreState.available,
  api.StoreState.installed => StoreState.installed,
  api.StoreState.installing => StoreState.installing,
  api.StoreState.removing => StoreState.removing,
  api.StoreState.retired => StoreState.retired,
  api.StoreState.unavailable => StoreState.unavailable,
};

/// Reads the text a terms entry names (an absolute path on this box); null
/// when it is missing or unreadable.
typedef TermsFileReader = String? Function(String path);

String? _readTermsFile(String path) {
  try {
    final t = File(path).readAsStringSync();
    return t.isEmpty ? null : t;
  } on FileSystemException {
    return null;
  }
}

class DaemonStore implements StoreRepository {
  DaemonStore(this._conn, this._jobs, {this.readTerms = _readTermsFile}) {
    _events = _conn.events.listen((e) {
      if (e is api.StoreChangedEvent) {
        _refresh();
      } else if (e is api.AppsChangedEvent) {
        _icons = null;
        if (_loaded) _changes.add(null);
      }
    });
    _status = _conn.statusChanges.listen((s) {
      if (s is api.Connected) _refresh();
    });
    unawaited(
      _conn
          .subscribeTo(const [
            api.EventName.storeChanged,
            api.EventName.appsChanged,
          ])
          .then((_) {}, onError: (_) {}),
    );
    if (_conn.status is api.Connected) _refresh();
  }

  final api.DaemonConnection _conn;
  final DaemonJobs _jobs;
  final TermsFileReader readTerms;
  late final StreamSubscription<api.SessionEvent> _events;
  late final StreamSubscription<api.ConnectionStatus> _status;
  final _changes = StreamController<void>.broadcast();

  List<StoreApp> _apps = const [];
  bool _loaded = false;
  bool _more = false;

  /// Listings requested and applied: replies can overtake each other, and
  /// only the newest request's answer is kept.
  int _requested = 0;
  int _applied = 0;
  Future<Map<String, String?>>? _icons;

  @override
  bool get loaded => _loaded;
  @override
  List<StoreApp> get apps => _apps;
  @override
  Set<String> get installed => {
    for (final a in _apps)
      if (a.state.isInstalled) a.id,
  };
  @override
  StoreState stateOf(String id) =>
      _apps.where((a) => a.id == id).firstOrNull?.state ?? StoreState.available;
  @override
  Stream<void> get changes => _changes.stream;
  @override
  bool get moreAfterUpdate => _more;

  /// A refresh nobody waits for (an event, a reconnect): a failure is just
  /// the listing staying as it was.
  void _refresh() => unawaited(_load().then((_) {}, onError: (_) {}));

  /// `store.list`, applied if no later request was answered first.
  Future<void> _load() async {
    final seq = ++_requested;
    final api.StoreListResult r;
    r = await guardCall(() => _conn.storeList());
    if (seq < _applied) return;
    _applied = seq;
    _apps = [for (final a in r.apps) ?_app(a)];
    _more = r.moreAfterUpdate;
    _loaded = true;
    _icons = null;
    _changes.add(null);
  }

  @override
  Future<List<StoreApp>> catalog() async {
    await _load();
    return _apps;
  }

  /// One wire app as the launcher's model. The terms text is read from the
  /// file the daemon names; an unfree app that could be installed but whose
  /// terms cannot be read is left out (it could not be accepted).
  StoreApp? _app(api.StoreApp a) {
    final state = _state(a.state);
    VendorTerms? terms;
    final t = a.terms;
    if (t != null) {
      final text = readTerms(t.file);
      if (text != null) {
        terms = VendorTerms(
          title: t.title,
          version: t.version,
          url: t.url,
          retrieved: t.retrieved,
          file: t.file,
          text: text,
        );
      }
    }
    if (state == StoreState.available && !a.free && terms == null) return null;
    return StoreApp(
      id: a.id,
      name: a.name,
      summary: a.summary,
      description: a.description,
      category: StoreCategory.parse(a.category),
      sizeMiB: a.sizeMib,
      homepage: a.homepage,
      isWeb: a.kind == api.AppKind.web,
      depends: a.depends,
      conflicts: a.conflicts,
      terms: terms,
      free: a.free,
      installer: a.installer,
      installerDefault: a.installerDefault,
      onIso: a.onIso,
      buildsOnDevice: a.buildsOnDevice,
      dataPaths: a.dataPaths,
      icon: StoreIcon(
        desktopId: a.icon.desktopId,
        iconUrl: a.icon.iconUrl,
        siteUrl: a.icon.siteUrl,
        firefoxProfile: a.icon.firefoxProfile,
        path: a.icon.path,
      ),
      removeDataWarning: removeDataWarningFor(a.dataPaths),
      state: state,
      statusReason: a.statusReason,
    );
  }

  /// The icon the daemon resolved: `store.list`'s `icon.path` (0.9, installed
  /// or not; `store_changed` says when one arrives), else the app's own icon
  /// from `apps.list`. The launcher never fetches an icon itself, so an app
  /// with neither gets the letter tile.
  @override
  Future<String?> resolveIcon(StoreApp app) async {
    final path = app.icon.path;
    if (path != null) return path;
    final icons = _icons ??= _loadIcons();
    return (await icons)[app.id];
  }

  Future<Map<String, String?>> _loadIcons() async {
    try {
      return {for (final a in (await _conn.appsList()).apps) a.id: a.icon};
    } catch (_) {
      _icons = null;
      return const {};
    }
  }

  /// Runs [call] with `settings.get`'s revision. A stale one
  /// (`state_conflict`: something else changed the settings in between) is
  /// fetched again and the call made once more, after the listing is
  /// refreshed.
  Future<T> _withRevision<T>(Future<T> Function(String revision) call) async {
    for (var attempt = 0; ; attempt++) {
      final revision = (await _conn.systemSettingsGet()).revision;
      try {
        return await call(revision);
      } on api.ApiException catch (e) {
        if (e.code == api.ApiErrorCode.stateConflict && attempt == 0) {
          _refresh();
          continue;
        }
        rethrow;
      }
    }
  }

  @override
  Future<JobHandle> install(
    String id, {
    Map<String, String> acceptedTerms = const {},
  }) => _jobs.start(
    JobKind.install,
    () => _withRevision(
      (revision) async => (await _conn.systemAppsInstall(
        api.SystemAppsInstallParams(
          ids: [id],
          revision: revision,
          acceptedTerms: acceptedTerms.isEmpty ? null : {...acceptedTerms},
        ),
      )).jobId,
    ),
    nothingToDo: 'That app is already installed.',
  );

  @override
  Future<JobHandle> remove(String id, {bool deleteData = false}) => _jobs.start(
    JobKind.remove,
    () => _withRevision(
      (revision) async => (await _conn.systemAppsRemove(
        api.SystemAppsRemoveParams(
          ids: [id],
          revision: revision,
          deleteData: deleteData,
        ),
      )).jobId,
    ),
    nothingToDo: 'That app is already removed.',
  );

  Future<void> dispose() async {
    await _events.cancel();
    await _status.cancel();
    await _changes.close();
  }
}
