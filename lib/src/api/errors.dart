import 'generated.dart';

/// A JSON-RPC error object returned by the daemon (or the mock).
class ApiException implements Exception {
  const ApiException(this.code, this.message, [this.data]);

  final int code;
  final String message;
  final Object? data;

  /// The typed `version_mismatch` data, if this is that error.
  VersionMismatchData? get versionMismatch {
    final d = data;
    if (code != ApiErrorCode.versionMismatch || d is! Map) return null;
    try {
      return VersionMismatchData.fromJson(d.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ApiException($code: $message)';
}

/// The daemon is not connected (yet, or any more).
class DaemonUnavailableException implements Exception {
  const DaemonUnavailableException([this.reason = 'not connected']);

  final String reason;

  @override
  String toString() => 'DaemonUnavailableException($reason)';
}
