/// The admin password prompt over session API 0.8: the session daemon is
/// polkit's authentication agent for the calls it relays, so the launcher
/// only has to show the prompt and answer it.
library;

import 'dart:async';

import '../api/api.dart' as api;
import '../log.dart';
import 'daemon_errors.dart';
import 'models.dart';
import 'repositories.dart';

AuthOutcome _outcome(api.AuthOutcome o) => switch (o) {
  api.AuthOutcome.authorized => AuthOutcome.authorized,
  api.AuthOutcome.failed => AuthOutcome.failed,
  api.AuthOutcome.cancelled || api.AuthOutcome.unknown => AuthOutcome.cancelled,
};

class DaemonAuth implements AuthRepository {
  DaemonAuth(this._conn) {
    _events = _conn.events.listen(_onEvent);
    unawaited(
      _conn
          .subscribeTo(const [
            api.EventName.authenticationRequested,
            api.EventName.authenticationFinished,
          ])
          .then((_) {}, onError: (_) {}),
    );
  }

  final api.DaemonConnection _conn;
  late final StreamSubscription<api.SessionEvent> _events;
  final _requests = StreamController<AuthRequest>.broadcast();
  final _finished = StreamController<AuthFinished>.broadcast();

  @override
  Stream<AuthRequest> get requests => _requests.stream;
  @override
  Stream<AuthFinished> get finished => _finished.stream;

  void _onEvent(api.SessionEvent ev) {
    switch (ev) {
      case api.AuthenticationRequestedEvent():
        _requests.add(
          AuthRequest(
            cookie: ev.cookie,
            action: ev.action,
            message: ev.message,
            // The daemon authenticates as the first identity.
            account: ev.identities.first.name,
          ),
        );
      case api.AuthenticationFinishedEvent():
        _finished.add(AuthFinished(ev.cookie, _outcome(ev.outcome)));
      default:
    }
  }

  @override
  Future<AuthAnswer> respond(String cookie, String password) =>
      guardCall(() async {
        final r = await _conn.authRespond(
          api.AuthRespondParams(cookie: cookie, password: password),
        );
        return AuthAnswer(ok: r.ok, attemptsLeft: r.attemptsLeft);
      });

  @override
  Future<void> cancel(String cookie) async {
    try {
      await _conn.authCancel(api.AuthCancelParams(cookie: cookie));
    } on api.ApiException catch (e) {
      // Over already (answered, timed out, cancelled elsewhere).
      if (e.code != api.ApiErrorCode.notFound) {
        logFailure('auth.cancel', e);
        throw systemExceptionFrom(e);
      }
    } on api.DaemonUnavailableException {
      // The daemon is gone; its prompt went with it.
    }
  }

  Future<void> dispose() async {
    await _events.cancel();
    await _requests.close();
    await _finished.close();
  }
}
