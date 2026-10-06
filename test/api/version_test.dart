import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';

void main() {
  ApiVersionNumber v(String s) => ApiVersionNumber.parse(s);

  test('parse rejects non MAJOR.MINOR', () {
    for (final bad in ['1', '1.2.3', 'a.b', '01.1', '']) {
      expect(() => ApiVersionNumber.parse(bad), throwsFormatException);
    }
  });

  test('0.x needs an exact match', () {
    expect(v('0.1').isCompatibleWith(v('0.1')), isTrue);
    expect(v('0.1').isCompatibleWith(v('0.2')), isFalse);
    expect(v('0.2').isCompatibleWith(v('0.1')), isFalse);
  });

  test('from 1.0 on only majors must match', () {
    expect(v('1.0').isCompatibleWith(v('1.4')), isTrue);
    expect(v('1.0').isCompatibleWith(v('2.0')), isFalse);
    expect(v('0.1').isCompatibleWith(v('1.0')), isFalse);
  });

  test('negotiated version is the lower one', () {
    expect(v('1.4').negotiate(v('1.2')), v('1.2'));
    expect(v('1.2').negotiate(v('1.4')), v('1.2'));
    expect(v('0.1').negotiate(v('0.1')).toString(), '0.1');
  });
}
