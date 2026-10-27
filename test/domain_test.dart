import 'package:birrwise/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ETB money', () {
    test('parses decimal amounts into integer santim', () {
      expect(parseEtbToSantim('4,500.25'), 450025);
      expect(parseEtbToSantim('450'), 45000);
      expect(parseEtbToSantim('12.5'), 1250);
      expect(parseEtbToSantim('0.05'), 5);
    });

    test('rejects malformed values and extra decimal places', () {
      expect(parseEtbToSantim('1.234'), isNull);
      expect(parseEtbToSantim('1.2.3'), isNull);
      expect(parseEtbToSantim('-10'), isNull);
      expect(parseEtbToSantim(''), isNull);
    });

    test('formats values without locale-dependent separators', () {
      expect(formatEtb(123456), 'ETB 1,234.56');
      expect(formatEtb(-900), '−ETB 9.00');
      expect(formatEtb(100, hidden: true), 'ETB ••••••');
    });
  });
}
