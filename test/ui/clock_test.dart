import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/ui/shell.dart' show untilNextMinute;

void main() {
  test('the clock ticks just after the next minute starts', () {
    const margin = Duration(milliseconds: 50);
    expect(
      untilNextMinute(DateTime.utc(2026, 1, 1, 20, 0, 5)),
      const Duration(seconds: 55) + margin,
    );
    expect(
      untilNextMinute(DateTime.utc(2026, 1, 1, 19, 59, 59, 999)),
      const Duration(milliseconds: 1) + margin,
    );
    expect(
      untilNextMinute(DateTime.utc(2026, 1, 1, 20)),
      const Duration(minutes: 1) + margin,
    );
  });
}
