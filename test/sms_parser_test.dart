import 'package:birrwise/domain.dart';
import 'package:birrwise/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SMS parser', () {
    test('accepts trusted sender and captures expense, reference, and balance',
        () {
      final result = SmsParser.parse(
        'CBE',
        'You paid ETB 450.00 to Kaldis. Fee ETB 5.00. '
            'Balance ETB 1,200.00. TXN ID: CBE1234567',
      );
      expect(result, isNotNull);
      expect(result!.institution, 'CBE');
      expect(result.amount, 45000);
      expect(result.direction, SmsDirection.expense);
      expect(result.balanceAfter, 120000);
      expect(result.reference, 'CBE1234567');
      expect(result.party, startsWith('Kaldis'));
    });

    test('recognizes money before or after the currency token', () {
      expect(
        SmsParser.parse('127', 'You received 2,000.50 Birr from Hana.')?.amount,
        200050,
      );
      expect(
        SmsParser.parse('telebirr', 'You paid ETB 25.00 to a shop.')?.amount,
        2500,
      );
    });

    test('recognizes all supported exact sender IDs', () {
      for (final sender in ['127', 'telebirr', 'telebirrsc']) {
        expect(SmsParser.parse(sender, 'You received ETB 30.00.'), isNotNull);
      }
      for (final sender in ['CBE', 'cbebirr']) {
        expect(SmsParser.parse(sender, 'You received ETB 30.00.'), isNotNull);
      }
      for (final sender in ['Awash', 'awashbank', 'awashbanksc']) {
        expect(SmsParser.parse(sender, 'You received ETB 30.00.'), isNotNull);
      }
      for (final sender in ['BOA', 'Abyssinia']) {
        expect(SmsParser.parse(sender, 'You received ETB 30.00.'), isNotNull);
      }
      for (final sender in ['Dashen', 'dashenbank']) {
        expect(SmsParser.parse(sender, 'You received ETB 30.00.'), isNotNull);
      }
    });

    test('supports Birr, Br and Amharic currency tokens', () {
      expect(SmsParser.parse('CBE', 'You paid 12.50 Birr.')?.amount, 1250);
      expect(SmsParser.parse('Awash', 'You paid Br. 12.50.')?.amount, 1250);
      expect(SmsParser.parse('Dashen', 'You paid 12.50 ብር.')?.amount, 1250);
    });

    test('recognizes lower-case directions and receives', () {
      expect(SmsParser.parse('cbe', 'credited etb 8,000.00')?.direction,
          SmsDirection.income);
      expect(SmsParser.parse('cbe', 'debited etb 850.00')?.direction,
          SmsDirection.expense);
    });

    test('does not trust a bank name in message text or partial sender match',
        () {
      expect(SmsParser.parse('unknown', 'CBE says you paid ETB 50.00'), isNull);
      expect(SmsParser.parse('1270', 'You paid ETB 50.00'), isNull);
      expect(SmsParser.parse('+25112700000', 'You paid ETB 50.00'), isNull);
    });

    test('captures the value after TXN ID, not the ID label', () {
      final result =
          SmsParser.parse('CBE', 'You received ETB 20.00. TXN ID: TB9823412');
      expect(result?.reference, 'TB9823412');
      // Too short to be a real reference, so it must not be used for dedupe.
      expect(
        SmsParser.parse('CBE', 'You received ETB 20.00. TXN ID: X')?.reference,
        isNull,
      );
    });

    test('ignores untrusted senders, OTP, promotions, and balance-only SMS',
        () {
      expect(
        SmsParser.parse('25112700000', 'You paid ETB 10.00.'),
        isNull,
      );
      expect(
        SmsParser.parse('CBE', 'Your OTP is 442211 for ETB 10.00.'),
        isNull,
      );
      expect(
        SmsParser.parse('CBE', 'Promo! Claim ETB 500 today.'),
        isNull,
      );
      expect(
        SmsParser.parse('CBE', 'Your balance is ETB 1,000.00.'),
        isNull,
      );
    });

    test('unknown direction requires review', () {
      final result =
          SmsParser.parse('Awash', 'ETB 90.00 transaction ref AW12345');
      expect(result?.direction, SmsDirection.unknown);
      expect(result?.confidence, SmsConfidence.low);
    });
  });
}
