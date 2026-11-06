/// API version rules: parsing `MAJOR.MINOR` and the handshake's compatibility
/// check.
library;

/// A parsed `MAJOR.MINOR` API version.
class ApiVersionNumber {
  const ApiVersionNumber(this.major, this.minor);

  factory ApiVersionNumber.parse(String s) {
    final m = RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$').firstMatch(s);
    if (m == null) throw FormatException('not a MAJOR.MINOR API version', s);
    return ApiVersionNumber(int.parse(m[1]!), int.parse(m[2]!));
  }

  final int major;
  final int minor;

  /// Whether a client built against [client] can talk to a server of this
  /// version: the same major and an equal or higher minor. A client ignores
  /// what it does not know, so it reads a newer server of its major.
  bool isCompatibleWith(ApiVersionNumber client) =>
      major == client.major && minor >= client.minor;

  @override
  bool operator ==(Object other) =>
      other is ApiVersionNumber && other.major == major && other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}

/// The launcher's build version, which `hello` sends as `client.version`: the
/// Nix build passes the package version
/// (`--dart-define=HINTEROS_LAUNCHER_VERSION=...`); `dev` without it.
const launcherVersion = String.fromEnvironment(
  'HINTEROS_LAUNCHER_VERSION',
  defaultValue: 'dev',
);
