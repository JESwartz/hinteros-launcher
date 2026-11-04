/// Small readers the `daemon_*.dart` repositories share.
library;

/// A Unix time in seconds (the API's times) as a local [DateTime].
DateTime unixTime(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// One line of at most [max] characters, or null when nothing is left:
/// names come from other programs.
String? oneLine(String? s, [int max = 128]) {
  if (s == null) return null;
  final l = s.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
  if (l.isEmpty) return null;
  final r = l.runes.toList();
  return r.length > max ? String.fromCharCodes(r.take(max)) : l;
}
