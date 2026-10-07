/// Turns what a call on the daemon threw into a [SystemException], for the
/// system relay (3xxx) and the runtime settings (4xxx) alike.
library;

import '../api/api.dart' as api;
import 'models.dart';
import '../log.dart';

// ---------------------------------------------------------------- errors

/// Turns whatever a call on the daemon threw into a [SystemException].
SystemException systemExceptionFrom(Object e) {
  if (e is SystemException) return e;
  if (e is api.DaemonUnavailableException) {
    return const SystemException(
      SystemErrorKind.unavailable,
      'Settings are unavailable: the launcher is not connected to HinterOS.',
      data: {'reason': 'down'},
    );
  }
  if (e is api.ApiException) {
    final data = e.data is Map
        ? (e.data! as Map).cast<String, Object?>()
        : const <String, Object?>{};
    switch (e.code) {
      case api.ApiErrorCode.systemUnavailable:
        final mismatch = data['reason'] == 'version_mismatch';
        return SystemException(
          SystemErrorKind.unavailable,
          mismatch
              ? 'Settings are unavailable until the session restarts: the '
                    'system service was updated.'
              : 'Settings are unavailable: the HinterOS system service is '
                    'not running.',
          data: data,
        );
      case api.ApiErrorCode.unavailable:
        final service = data['service'] as String? ?? '';
        return SystemException(
          SystemErrorKind.unavailable,
          "${runtimeServiceName(service)} isn't available on this box.",
          data: data,
        );
      case api.ApiErrorCode.deviceFailed:
        return SystemException(
          SystemErrorKind.deviceFailed,
          switch (data['reason']) {
            'not_applied' =>
              'The display did not switch to that mode. HinterOS may be '
                  'started with a fixed resolution.',
            'nothing_to_revert' => 'There is no display change to go back.',
            'wifi_disabled' => 'Wi-Fi is turned off.',
            'no_adapter' => 'There is no Bluetooth adapter in this box.',
            _ => e.message,
          },
          data: data,
        );
      case api.ApiErrorCode.wrongPassword:
        return SystemException(
          SystemErrorKind.wrongPassword,
          'That password was not accepted. Try again.',
          data: data,
        );
      case api.ApiErrorCode.notAuthorized:
        return SystemException(
          SystemErrorKind.notAuthorized,
          "HinterOS isn't allowed to change that on this box.",
          data: data,
        );
      case api.ApiErrorCode.powerInhibited:
        return SystemException(
          SystemErrorKind.powerInhibited,
          "Can't do that while an update is being applied.",
          data: data,
        );
      case api.ApiErrorCode.permissionDenied:
        return SystemException(
          SystemErrorKind.permissionDenied,
          data['reason'] == 'polkit'
              ? 'The admin password was wrong too many times. Nothing was '
                    'changed.'
              : 'This is not allowed on this box right now.',
          data: data,
        );
      case api.ApiErrorCode.authenticationRequired:
        return SystemException(
          SystemErrorKind.authenticationRequired,
          'The admin password was not given, so nothing was changed.',
          data: data,
        );
      case api.ApiErrorCode.appConflict:
        return SystemException(
          SystemErrorKind.appConflict,
          '${data['id']} and ${data['conflicts_with']} cannot be on this '
          'box together.',
          data: data,
        );
      case api.ApiErrorCode.termsRequired:
        return SystemException(
          SystemErrorKind.termsRequired,
          'The terms of ${data['id']} have to be accepted first.',
          data: data,
        );
      case api.ApiErrorCode.insufficientResources:
        return SystemException(
          SystemErrorKind.insufficientResources,
          data['kind'] == 'disk'
              ? 'There is not enough free disk space for this. Free some '
                    'space (remove an app or delete files) and try again.'
              : 'There is not enough free memory for this.',
          data: data,
        );
      case api.ApiErrorCode.jobBusy:
        return SystemException(
          SystemErrorKind.jobBusy,
          'Another change is still running.',
          data: data,
        );
      case api.ApiErrorCode.rateLimited:
        return SystemException(
          SystemErrorKind.rateLimited,
          'Too many changes in a short time. Try again in a moment.',
          data: data,
        );
      case api.ApiErrorCode.stateConflict:
        return SystemException(
          SystemErrorKind.stateConflict,
          data['reason'] == 'update_rev'
              ? 'That is not the update that was checked. Check again.'
              : 'The settings changed in the meantime. Try again.',
          data: data,
        );
      case api.ApiErrorCode.updateUnreachable:
        return SystemException(
          SystemErrorKind.updateUnreachable,
          "Can't reach the update server right now.",
          data: data,
        );
      case api.ApiErrorCode.updateVerificationFailed:
        return SystemException(
          SystemErrorKind.updateVerificationFailed,
          'The update did not pass its safety check.',
          data: data,
        );
      case api.ApiErrorCode.notFound:
        return SystemException(SystemErrorKind.notFound, e.message, data: data);
      case api.ApiErrorCode.needsAcknowledgement:
        return SystemException(
          SystemErrorKind.needsAcknowledgement,
          e.message,
          data: data,
        );
      case api.ApiErrorCode.invalidParams:
        return SystemException(
          SystemErrorKind.invalidParams,
          switch (data['reason']) {
            'unsupported_security' =>
              "This kind of network (WEP or a business login) can't be "
                  'joined from here.',
            'not_available' =>
              'That app is not available in this version of HinterOS.',
            _ => e.message,
          },
          data: data,
        );
      case api.ApiErrorCode.methodNotFound:
        return const SystemException(
          SystemErrorKind.unavailable,
          'This needs a newer HinterOS service than the one that is running.',
        );
    }
    return SystemException(SystemErrorKind.failed, e.message, data: data);
  }
  return SystemException(SystemErrorKind.failed, 'Something went wrong ($e).');
}

Future<T> guardCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    logFailure('a system call', e);
    throw systemExceptionFrom(e);
  }
}

/// What the user calls the service a 4001 `unavailable` names.
String runtimeServiceName(String service) => switch (service) {
  'networkmanager' => 'Wi-Fi',
  'bluez' => 'Bluetooth',
  'audio' => 'Audio',
  'display' => 'Display control',
  'logind' => 'Power control',
  'catalog' => 'The Store',
  'polkit' => 'The admin password check',
  _ => 'This',
};
