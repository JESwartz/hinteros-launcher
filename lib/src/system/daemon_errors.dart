/// Turns what a call on the daemon threw into a [SystemException], for the
/// system relay (3xxx) and the runtime settings (4xxx) alike.
///
/// The daemon's own messages are for the log (see [guardCall]); the
/// [SystemException.message] is always a short line written here.
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
      'Settings are unavailable. The launcher is not connected to HinterOS.',
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
              ? 'Settings are unavailable. Restart the session.'
              : 'Settings are unavailable. The HinterOS system service is '
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
            'not_applied' => 'The display did not change to that mode.',
            'nothing_to_revert' => 'There is no display change to undo.',
            'wifi_disabled' => 'Wi-Fi is off.',
            'no_wifi_device' => 'There is no Wi-Fi adapter in this box.',
            'no_adapter' => 'There is no Bluetooth adapter in this box.',
            'not_in_range' => 'The network is out of range.',
            'no_address' => 'The network gave no address. Try again.',
            'connect_failed' ||
            'activation_failed' => "Can't connect. Try again.",
            'auth_failed' => 'The device did not accept the pairing.',
            'rejected' => 'The pairing was rejected.',
            'canceled' => 'The pairing was cancelled.',
            'timeout' => 'No answer in time. Try again.',
            'in_progress' => 'Bluetooth is busy. Try again in a moment.',
            'not_ready' => 'Bluetooth is not ready. Try again in a moment.',
            'not_available' => 'The device is not available.',
            _ => "That didn't work. Try again.",
          },
          data: data,
        );
      case api.ApiErrorCode.wrongPassword:
        return SystemException(
          SystemErrorKind.wrongPassword,
          'Wrong password. Try again.',
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
          switch (data['reason']) {
            'polkit' =>
              'Wrong admin password too many times. Nothing was changed.',
            'profile' => 'Only a profile can do this.',
            _ => 'This is not allowed on this box right now.',
          },
          data: data,
        );
      case api.ApiErrorCode.authenticationRequired:
        return SystemException(
          SystemErrorKind.authenticationRequired,
          'No admin password was given, so nothing was changed.',
          data: data,
        );
      case api.ApiErrorCode.appConflict:
        return SystemException(
          SystemErrorKind.appConflict,
          "${data['id']} and ${data['conflicts_with']} can't be installed "
          'together.',
          data: data,
        );
      case api.ApiErrorCode.termsRequired:
        return SystemException(
          SystemErrorKind.termsRequired,
          'Accept the terms of ${data['id']} first.',
          data: data,
        );
      case api.ApiErrorCode.insufficientResources:
        return SystemException(
          SystemErrorKind.insufficientResources,
          data['kind'] == 'disk'
              ? 'Not enough free disk space. Remove an app or delete files, '
                    'then try again.'
              : 'Not enough free memory.',
          data: data,
        );
      case api.ApiErrorCode.pinRequired:
        return SystemException(
          SystemErrorKind.pinRequired,
          data['reboot_required'] == true
              ? 'Too many wrong PINs. Restart the box to try again.'
              : data['retry_after_ms'] != null
              ? 'Too many tries with that PIN.'
              : switch (data['pin']) {
                  'admin' => "This needs the admin profile's PIN.",
                  _ => 'Wrong PIN.',
                },
          data: data,
        );
      case api.ApiErrorCode.profileLimit:
        return SystemException(
          SystemErrorKind.profileLimit,
          'This box has the maximum number of profiles '
          '(${data['max'] ?? 8}).',
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
          'Too many changes. Try again in a moment.',
          data: data,
        );
      case api.ApiErrorCode.stateConflict:
        return SystemException(
          SystemErrorKind.stateConflict,
          data['reason'] == 'update_rev'
              ? 'That is not the update that was checked. Check again.'
              : 'The settings changed. Try again.',
          data: data,
        );
      case api.ApiErrorCode.updateUnreachable:
        return SystemException(
          SystemErrorKind.updateUnreachable,
          "Can't reach the update server right now. Try again later.",
          data: data,
        );
      case api.ApiErrorCode.updateVerificationFailed:
        return SystemException(
          SystemErrorKind.updateVerificationFailed,
          'The update failed its safety check. Nothing was changed.',
          data: data,
        );
      case api.ApiErrorCode.notFound:
        return SystemException(
          SystemErrorKind.notFound,
          'That is not there any more.',
          data: data,
        );
      case api.ApiErrorCode.needsAcknowledgement:
        return SystemException(
          SystemErrorKind.needsAcknowledgement,
          'This is a downgrade.',
          data: data,
        );
      case api.ApiErrorCode.invalidParams:
        return SystemException(
          SystemErrorKind.invalidParams,
          switch (data['reason']) {
            'unsupported_security' =>
              "This type of network (WEP or a business login) isn't "
                  'supported.',
            'not_available' =>
              'That app is not available in this version of HinterOS.',
            'not_in_admin_profile' =>
              'That app is not installed in the admin profile.',
            _ => "HinterOS can't do that.",
          },
          data: data,
        );
      case api.ApiErrorCode.methodNotFound:
        return const SystemException(
          SystemErrorKind.unavailable,
          'This needs a newer HinterOS service.',
        );
    }
    return SystemException(
      SystemErrorKind.failed,
      'Something went wrong. Try again.',
      data: data,
    );
  }
  return const SystemException(
    SystemErrorKind.failed,
    'Something went wrong. Try again.',
  );
}

/// Runs [call]; a failure is logged with the daemon's own message and
/// rethrown as a [SystemException] with a short message for the screen.
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
  'profiles' => 'Profiles',
  'polkit' => 'The admin password check',
  _ => 'This',
};
