/// API version rules (hinteros-docs/design/api.md, "Handshake and versioning").
library;

/// A parsed `MAJOR.MINOR` API version.
class ApiVersionNumber implements Comparable<ApiVersionNumber> {
  const ApiVersionNumber(this.major, this.minor);

  factory ApiVersionNumber.parse(String s) {
    final m = RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$').firstMatch(s);
    if (m == null) throw FormatException('not a MAJOR.MINOR API version', s);
    return ApiVersionNumber(int.parse(m[1]!), int.parse(m[2]!));
  }

  final int major;
  final int minor;

  /// Majors must be equal; while the major is 0 every minor is breaking, so
  /// the minors must match too.
  bool isCompatibleWith(ApiVersionNumber other) =>
      major == other.major && (major != 0 || minor == other.minor);

  /// The version both sides restrict themselves to: the lower of the two.
  ApiVersionNumber negotiate(ApiVersionNumber other) =>
      compareTo(other) <= 0 ? this : other;

  @override
  int compareTo(ApiVersionNumber other) => major != other.major
      ? major.compareTo(other.major)
      : minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) =>
      other is ApiVersionNumber && other.major == major && other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}
