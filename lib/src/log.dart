/// Failure log: one line per failure on stderr, which the session sends to
/// the journal (`journalctl --user -t hinteros-launcher`, or over SSH), so
/// what went wrong can be read even when the screen is hard to read.
library;

import 'dart:io';

import 'api/api.dart' show ApiException, DaemonUnavailableException;

/// Where lines go. Tests replace it to capture them.
void Function(String line) logSink = _toStderr;

void _toStderr(String line) {
  try {
    stderr.writeln(line);
  } catch (_) {
    // No stderr (closed pipe): nothing else to do.
  }
}

/// Logs that [what] failed with [error]: the daemon's error code and message
/// when there is one, else whatever was thrown.
void logFailure(String what, Object error) {
  final String detail;
  if (error is ApiException) {
    detail = 'error ${error.code}: ${error.message}';
  } else if (error is DaemonUnavailableException) {
    detail = 'daemon not connected (${error.reason})';
  } else {
    detail = '$error';
  }
  logSink('hinteros-launcher: $what failed: $detail');
}
