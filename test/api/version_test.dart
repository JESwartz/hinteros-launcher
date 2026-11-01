import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';

void main() {
  ApiVersionNumber v(String s) => ApiVersionNumber.parse(s);

  test('parse rejects non MAJOR.MINOR', () {
    for (final bad in ['1', '1.2.3', 'a.b', '01.1', '']) {
      expect(() => ApiVersionNumber.parse(bad), throwsFormatException);
    }
  });

  test('a server takes a client of its major and an equal or lower minor', () {
    expect(v('1.0').isCompatibleWith(v('1.0')), isTrue);
    expect(v('1.4').isCompatibleWith(v('1.0')), isTrue);
    expect(v('1.0').isCompatibleWith(v('1.4')), isFalse);
  });

  test('another major is a mismatch', () {
    expect(v('1.0').isCompatibleWith(v('2.0')), isFalse);
    expect(v('2.0').isCompatibleWith(v('1.0')), isFalse);
    expect(v('0.20').isCompatibleWith(v('1.0')), isFalse);
  });
}
