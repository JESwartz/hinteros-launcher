import 'dart:async';

import 'generated.dart';

/// Where the connection to the daemon stands. The UI renders from this.
sealed class ConnectionStatus {
  const ConnectionStatus();
}

/// Connecting or handshaking (also the initial state).
final class Connecting extends ConnectionStatus {
  const Connecting();
}

/// Handshake done; requests work.
final class Connected extends ConnectionStatus {
  const Connected({required this.apiVersion, required this.server});

  /// The negotiated API version.
  final String apiVersion;
  final Peer server;
}

/// No socket, or the connection dropped. The client keeps retrying.
final class Unreachable extends ConnectionStatus {
  const Unreachable(this.reason);

  final String reason;
}

/// The daemon speaks an incompatible API version (error 1002 or a local
/// check). The client keeps retrying, because an update may fix it.
final class VersionMismatch extends ConnectionStatus {
  const VersionMismatch({
    required this.clientApiVersion,
    required this.serverApiVersion,
  });

  final String clientApiVersion;
  final String serverApiVersion;
}

/// What the launcher needs from the daemon. Implemented by the real
/// [DaemonClient] and by [MockDaemon].
abstract class DaemonConnection with SessionApiMethods {
  ConnectionStatus get status;

  /// Emits every status change (broadcast; does not replay [status]).
  Stream<ConnectionStatus> get statusChanges;

  /// Server-pushed events for the subscriptions made with [subscribeTo].
  Stream<SessionEvent> get events;

  /// Starts connecting (and reconnecting). Returns immediately; idempotent.
  void start();

  /// Subscribes to [names] now and again after every reconnect.
  Future<void> subscribeTo(Iterable<EventName> names);

  Future<void> unsubscribeFrom(Iterable<EventName> names);

  Future<void> close();

  /// Completes once connected; throws on [timeout].
  Future<Connected> waitConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    start();
    final s = status;
    if (s is Connected) return s;
    return statusChanges
        .where((s) => s is Connected)
        .cast<Connected>()
        .first
        .timeout(timeout);
  }
}
