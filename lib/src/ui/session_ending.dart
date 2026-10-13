/// The session is ending on purpose: the current profile is being removed,
/// the guest session ends, a switch has begun, the box restarts or shuts
/// down, or the session restarts. The session daemon goes away with the
/// session, so from then on a lost connection is expected: the shell shows
/// the "Removing Sam…" page (the loading page's style) instead of "Can't
/// reach the HinterOS service", and takes no more input while it shows.
library;

import 'package:flutter/material.dart';

import '../system/models.dart';
import 'profiles/profile_loading.dart';

/// What the ending page shows.
@immutable
class SessionEnding {
  const SessionEnding({
    required this.title,
    this.detail,
    this.identity = const LoadingIdentity(),
    this.cover = true,
  });

  /// "Removing Sam…".
  final String title;

  /// "You'll be taken to the profile picker."
  final String? detail;

  /// Whose avatar the page shows.
  final LoadingIdentity identity;

  /// True: the page covers the launcher at once. False: another page (the
  /// Switching page) shows what happens while the service still answers, and
  /// this page only once the connection is gone.
  final bool cover;
}

/// The one "session ending" state of a launcher.
class SessionEndingController extends ChangeNotifier {
  SessionEndingController({bool Function()? connected})
    : _connected = connected ?? (() => true);

  final bool Function() _connected;

  /// The service answers now.
  bool get connected => _connected();

  SessionEnding? _ending;
  bool _final = false;

  /// Null: the session is not ending.
  SessionEnding? get ending => _ending;

  /// The connection went while ending: nothing undoes it any more.
  bool get isFinal => _final;

  /// The session is ending from now on (replaces an earlier ending).
  void begin(SessionEnding e) {
    if (_final) return;
    _ending = e;
    notifyListeners();
  }

  /// It did not end after all (the removal failed, the switch was
  /// cancelled), as long as the service still answered: only [e], the one
  /// begun, is undone.
  void abandon(SessionEnding e) {
    if (_final || !identical(_ending, e)) return;
    _ending = null;
    notifyListeners();
  }

  /// The connection was lost while ending: the page stays for the rest of
  /// this launcher's life.
  void connectionLost() {
    if (_ending == null || _final) return;
    _final = true;
    notifyListeners();
  }

  /// Whether the ending page is up, given whether the service answers.
  bool showsPage({required bool connected}) {
    final e = _ending;
    return e != null && (e.cover || _final || !connected);
  }
}

/// Makes the shell's [SessionEndingController] reachable from its pages
/// (Settings, the modals).
class SessionEndingScope extends InheritedWidget {
  const SessionEndingScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SessionEndingController controller;

  /// Null outside a shell (tests that show a page alone).
  static SessionEndingController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionEndingScope>()?.controller;

  @override
  bool updateShouldNotify(SessionEndingScope old) =>
      controller != old.controller;
}

/// The page: [ProfileLoadingPage] with the ending's words.
class SessionEndingPage extends StatelessWidget {
  const SessionEndingPage({super.key, required this.ending});

  final SessionEnding ending;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey('session-ending'),
    child: ProfileLoadingPage(
      identity: ending.identity,
      title: ending.title,
      detail: ending.detail,
    ),
  );
}

/// Runs [call], an action that ends the session (restart, shut down, a
/// session restart), with [e] up from the start: the answer may never come,
/// since the service goes away with the session. A refusal while the service
/// answers takes the page away again and is rethrown; the connection going
/// away during the call is the action working.
Future<void> endSessionWith(
  BuildContext context,
  SessionEnding e,
  Future<void> Function() call,
) async {
  final c = SessionEndingScope.maybeOf(context);
  if (c == null) return call();
  final wasConnected = c.connected;
  c.begin(e);
  try {
    await call();
  } catch (err) {
    final gone =
        wasConnected &&
        err is SystemException &&
        err.kind == SystemErrorKind.unavailable &&
        err.data['reason'] == 'down';
    if (gone) {
      c.connectionLost();
      return;
    }
    c.abandon(e);
    rethrow;
  }
}

/// Restart or Shut down: the ending page with its words.
SessionEnding powerEnding(PowerAction a) => SessionEnding(
  title: switch (a) {
    PowerAction.restart => 'Restarting…',
    PowerAction.shutdown => 'Shutting down…',
    PowerAction.sleep => 'Going to sleep…',
  },
);
