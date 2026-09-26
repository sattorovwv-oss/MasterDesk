import 'package:flutter_test/flutter_test.dart';
import 'package:masterdesk/core/money.dart';

void main() {
  group('Money', () {
    test('parses major values to integer minor units', () {
      expect(Money.parseMinor('100.25'), 10025);
      expect(Money.parseMinor('1 250,50'), 125050);
      expect(Money.parseMinor('10'), 1000);
      expect(Money.parseMinor(''), 0);
    });

    test('rejects values with more than two decimal places', () {
      expect(() => Money.parseMinor('10.009'), throwsFormatException);
    });

    test('rounds percentage discount half-up', () {
      expect(Money.percentDiscount(10005, 1000), 1001);
      expect(10005 - Money.percentDiscount(10005, 1000), 9004);
    });

    test('formats ru and en values', () {
      expect(Money.format(125050, 'TJS', 'ru'), '1 250,50 TJS');
      expect(Money.format(125050, 'TJS', 'en'), '1,250.50 TJS');
    });
  });
}
