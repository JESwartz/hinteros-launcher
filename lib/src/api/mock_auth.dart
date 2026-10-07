/// The polkit authentication agent of [MockDaemon] (session API 0.8): a relayed
/// call that polkit wants the admin password for (`system.ssh.set`) sends
/// `authentication_requested` to the launcher and waits for `auth.respond` or
/// `auth.cancel`, like the real daemon (3 tries, `authentication_finished`
/// at the end). The call that waits and the `auth.*` calls run concurrently,
/// so responses arrive out of order.
library;

import 'dart:async';

import 'errors.dart';
import 'generated.dart';

class _Pending {
  _Pending(this.cookie, this.attemptsLeft);

  final String cookie;
  int attemptsLeft;
  final done = Completer<AuthOutcome>();
}

class MockAuthAgent {
  MockAuthAgent({required this.emit, required this.isLauncher});

  /// Sends an event to the launcher (the daemon's `emitRaw`).
  final void Function(String name, Map<String, dynamic> params) emit;

  /// Whether this connection is the launcher (`hinteros-launcher`): only it
  /// gets the events and may answer.
  final bool Function() isLauncher;

  /// The admin account polkit asks for.
  String adminName = 'admin';

  /// Its password (placeholder).
  String adminPassword = 'correct horse';

  /// Wrong passwords per request.
  int maxAttempts = 3;

  /// False: no authentication agent is registered, so a call that needs the
  /// password is `authentication_required` at once.
  bool agentRegistered = true;

  /// The password prompt was dismissed without anyone answering (polkit's
  /// timeout): the next request ends as soon as it starts.
  bool timeoutNext = false;

  /// How many passwords were checked (never which).
  int attempts = 0;

  final _pending = <String, _Pending>{};
  int _n = 2;

  /// Cookies of the requests that wait for an answer.
  List<String> get pendingCookies => _pending.keys.toList();

  static bool handles(String method) => method.startsWith('auth.');

  /// polkit asks for the admin password for [action]. Completes when the
  /// request was authorized; throws `authentication_required` when it was
  /// cancelled, dismissed or timed out and `permission_denied {reason:
  /// polkit}` after too many wrong passwords. [cookie] fixes the cookie
  /// (the schema examples use one).
  Future<void> authorize({
    required String action,
    required String message,
    String? cookie,
  }) async {
    if (!agentRegistered) throw _required(action);
    final id = cookie ?? '${++_n}-6f1c0e2a9b7d4c58-1-0a9f3e1d2c4b5a69';
    final p = _Pending(id, maxAttempts);
    _pending[id] = p;
    if (isLauncher()) {
      emit(
        'authentication_requested',
        AuthenticationRequestedEvent(
          cookie: id,
          action: action,
          message: message,
          identities: [
            AuthenticationRequestedEventIdentitiesItem(
              uid: 1001,
              name: adminName,
            ),
          ],
        ).toJson(),
      );
    }
    if (timeoutNext) {
      timeoutNext = false;
      _finish(p, AuthOutcome.cancelled);
    }
    switch (await p.done.future) {
      case AuthOutcome.authorized:
        return;
      case AuthOutcome.failed:
        throw const ApiException(
          ApiErrorCode.permissionDenied,
          'authentication failed',
          {'reason': 'polkit'},
        );
      default:
        throw _required(action);
    }
  }

  ApiException _required(String action) => ApiException(
    ApiErrorCode.authenticationRequired,
    '$action needs interactive authentication',
    {'action': action},
  );

  void _finish(_Pending p, AuthOutcome outcome) {
    if (_pending.remove(p.cookie) == null) return;
    if (isLauncher()) {
      emit(
        'authentication_finished',
        AuthenticationFinishedEvent(
          cookie: p.cookie,
          outcome: outcome,
        ).toJson(),
      );
    }
    p.done.complete(outcome);
  }

  _Pending _find(String cookie) =>
      _pending[cookie] ??
      (throw ApiException(
        ApiErrorCode.notFound,
        'no authentication request $cookie',
      ));

  void _launcherOnly() {
    if (!isLauncher()) {
      throw const ApiException(
        ApiErrorCode.notAuthorized,
        'only the launcher answers authentication requests',
      );
    }
  }

  Map<String, dynamic> call(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'auth.respond':
        _launcherOnly();
        final r = AuthRespondParams.fromJson(params);
        final p = _find(r.cookie);
        attempts++;
        p.attemptsLeft--;
        final ok = r.password == adminPassword;
        // The reply goes out before the call that waited resumes.
        final reply = AuthRespondResult(
          ok: ok,
          attemptsLeft: p.attemptsLeft,
        ).toJson();
        if (ok) {
          _finish(p, AuthOutcome.authorized);
        } else if (p.attemptsLeft <= 0) {
          _finish(p, AuthOutcome.failed);
        }
        return reply;
      case 'auth.cancel':
        _launcherOnly();
        _finish(
          _find(AuthCancelParams.fromJson(params).cookie),
          AuthOutcome.cancelled,
        );
        return const AuthCancelResult().toJson();
    }
    throw ApiException(ApiErrorCode.methodNotFound, 'unknown method $method');
  }

  /// A prompt nobody answers any more (polkit cancelled it).
  void cancelFromPolkit(String cookie) {
    final p = _pending[cookie];
    if (p != null) _finish(p, AuthOutcome.cancelled);
  }
}
