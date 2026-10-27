import 'package:birrwise/domain.dart';
import 'package:birrwise/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures modelled on real alert wording. Names and numbers are made up.
// Replace or extend them with messages copied from your own phone.
void main() {
  group('Telebirr', () {
    const transfer =
        'Dear Abebe, You have transferred ETB 500.00 to Kebede Alemu '
        '(2519****1234) on 12/10/2024 15:30:21. Your transaction number is '
        'CJC12ABC34. The service fee is ETB 2.00 and 15% VAT on the service '
        'fee is ETB 0.30. Your current E-Money Account balance is ETB '
        '1,234.56. To download your payment information please click this '
        'link: https://transactioninfo.ethiotelecom.et/receipt/CJC12ABC34. '
        'Thank you for using telebirr Ethio telecom';

    test('transfer: amount, fee, VAT, balance, reference and party', () {
      final r = SmsParser.parse('127', transfer)!;
      expect(r.institution, 'Telebirr');
      expect(r.direction, SmsDirection.expense);
      expect(r.amount, 50000);
      expect(r.balanceAfter, 123456);
      expect(r.reference, 'CJC12ABC34');
      expect(r.party, 'Kebede Alemu');
      expect(r.confidence, SmsConfidence.high);
    });

    test('received money', () {
      final r = SmsParser.parse(
        '127',
        'Dear Abebe, You have received ETB 1,000.00 from Sara '
            'Tesfaye(2519****5678) on 12/10/2024 10:01:02. Your transaction '
            'number is CJD45XYZ90. Your current E-Money Account balance is '
            'ETB 2,234.56. Thank you for using telebirr',
      )!;
      expect(r.direction, SmsDirection.income);
      expect(r.amount, 100000);
      expect(r.reference, 'CJD45XYZ90');
      expect(r.party, 'Sara Tesfaye');
    });

    test('"transaction number is X" never yields the word "is"', () {
      final a = SmsParser.parse(
          '127', 'You have paid ETB 10.00. Your transaction number is AA11BB22');
      final b = SmsParser.parse(
          '127', 'You have paid ETB 10.00. Your transaction number is CC33DD44');
      expect(a!.reference, 'AA11BB22');
      expect(b!.reference, 'CC33DD44');
    });

    test('a phone number after "telebirr" is not read as money', () {
      final r = SmsParser.parse(
        '127',
        'You have paid ETB 80.00 to Selam Cafe via telebirr 0911223344. '
            'Transaction ID is DE34FG56HJ.',
      )!;
      expect(r.amount, 8000);
      expect(r.party, 'Selam Cafe');
      expect(r.reference, 'DE34FG56HJ');
    });

    test('airtime purchase is an expense', () {
      final r = SmsParser.parse(
        'telebirr',
        'You have bought airtime of ETB 50.00 for 0911000000. '
            'Your transaction number is CJE12QWE90.',
      )!;
      expect(r.direction, SmsDirection.expense);
      expect(r.amount, 5000);
    });

    test('cashback credit with promo wording is still a transaction', () {
      final r = SmsParser.parse(
        '127',
        'Congratulations! You have received ETB 25.00 cashback from the '
            'telebirr promo. Your transaction number is CJF98ZXC12.',
      )!;
      expect(r.direction, SmsDirection.income);
      expect(r.amount, 2500);
    });
  });

  group('CBE', () {
    test('debit: fee, VAT and total are not the amount; FT ref from link', () {
      final r = SmsParser.parse(
        'CBE',
        'Dear Abebe your Account 1*********1234 has been debited with ETB '
            '500.00. Service charge of ETB 0.50 and VAT(15%) of ETB 0.08 with '
            'a total of ETB 500.58. Your Current Balance is ETB 10,000.00. '
            'Thank you for Banking with CBE! '
            'https://apps.cbe.com.et:100/?id=FT24123ABC12345678',
      )!;
      expect(r.direction, SmsDirection.expense);
      expect(r.amount, 50000);
      expect(r.balanceAfter, 1000000);
      expect(r.reference, 'FT24123ABC12345678');
      expect(r.confidence, SmsConfidence.high);
    });

    test('credit with Ref No and sender name', () {
      final r = SmsParser.parse(
        'CBE',
        'Dear Abebe your Account 1*********1234 has been Credited with ETB '
            '3,000.00 from Kebede Alemu, on 12/10/2024 at 10:22:33 with Ref No '
            'FT24286ABCDE Your Current Balance is ETB 13,000.00. Thank you for '
            'Banking with CBE!',
      )!;
      expect(r.direction, SmsDirection.income);
      expect(r.amount, 300000);
      expect(r.balanceAfter, 1300000);
      expect(r.reference, 'FT24286ABCDE');
      expect(r.party, 'Kebede Alemu');
    });

    test('a date right before the currency is not the amount', () {
      final r = SmsParser.parse(
          'CBE', 'On 12/10/2024 ETB 300.00 was debited. Ref: FT24300XYZ12');
      expect(r!.amount, 30000);
    });
  });

  group('Awash, BOA and Dashen', () {
    test('Awash debit with available balance', () {
      final r = SmsParser.parse(
        'Awash',
        'Dear Customer, your account 0132****01 has been debited ETB 1,500.00 '
            'on 2024-10-12. Ref: AW24H12345. Available balance: ETB 3,000.00',
      )!;
      expect(r.institution, 'Awash');
      expect(r.direction, SmsDirection.expense);
      expect(r.amount, 150000);
      expect(r.balanceAfter, 300000);
      expect(r.reference, 'AW24H12345');
    });

    test('BOA credit with Trans Ref', () {
      final r = SmsParser.parse(
        'BOA',
        'Dear Customer, your account 12****89 has been credited with ETB '
            '2,000.00 by Hana Bekele. Trans Ref: BOA2410ABC1. Your available '
            'balance is ETB 7,500.00.',
      )!;
      expect(r.direction, SmsDirection.income);
      expect(r.amount, 200000);
      expect(r.balanceAfter, 750000);
      expect(r.reference, 'BOA2410ABC1');
    });

    test('Dashen alert with a "never share your PIN" footer is kept', () {
      final r = SmsParser.parse(
        'DashenBank',
        'Dear Customer, ETB 1,000.00 has been debited from your account '
            '****1234 on 12-Oct-2024. Your available balance is ETB 4,000.00. '
            'Never share your PIN with anyone.',
      )!;
      expect(r.direction, SmsDirection.expense);
      expect(r.amount, 100000);
      expect(r.balanceAfter, 400000);
      // "your account" is not a merchant.
      expect(r.party, 'Dashen');
    });
  });

  group('ignored messages', () {
    test('codes are ignored', () {
      expect(SmsParser.parse('127', 'Your telebirr OTP is 123456.'), isNull);
      expect(
        SmsParser.parse('CBE', 'Your PIN is 4821. Use it to pay ETB 10.00.'),
        isNull,
      );
      expect(
        SmsParser.parse('Awash',
            'Your verification code for ETB 100.00 transfer is 552211'),
        isNull,
      );
    });

    test('pure promotions are ignored', () {
      expect(
        SmsParser.parse('127', 'Promotion: win up to ETB 10,000.00 this week!'),
        isNull,
      );
    });
  });

  test('Amharic amount after ብር', () {
    final r = SmsParser.parse('CBE', 'ከሂሳብዎ 500 ብር ተቀንሷል።')!;
    expect(r.amount, 50000);
    expect(r.direction, SmsDirection.expense);
  });
}
