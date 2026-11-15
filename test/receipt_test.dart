import 'package:birrwise/domain.dart';
import 'package:birrwise/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 25, 9, 30);

  test('reads a wallet transfer receipt', () {
    final fields = readReceipt('''
telebirr
Transaction Successful
-500.00 (ETB)
Transaction Time: 2026/10/22 14:31:05
Transaction Type: Transfer Money
Transaction To: Abebe Kebede
Transaction Number: CJM4XYZ12A
Total Paid Amount: 500.00 (ETB)''', now: now);
    expect(fields.amount, 50000);
    expect(fields.direction, SmsDirection.expense);
    expect(fields.party, 'Abebe Kebede');
    expect(fields.date, DateTime(2026, 10, 22, 12));
    expect(fields.reference, 'CJM4XYZ12A');
  });

  test('reads a bank transfer receipt with a month-first date', () {
    final fields = readReceipt('''
Commercial Bank of Ethiopia
Payer: ABEBE KEBEDE
Receiver: TOMOCA COFFEE
Payment Date & Time: 10/22/2026, 2:31:05 PM
Reference No. (VAT Invoice No): FT26295ABCDE
Transferred Amount: 450.00 ETB
Commission or Service Charge: 0.00 ETB''', now: now);
    expect(fields.amount, 45000);
    expect(fields.party, 'TOMOCA COFFEE');
    expect(fields.date, DateTime(2026, 10, 22, 12));
    expect(fields.reference, 'FT26295ABCDE');
  });

  test('an ambiguous date takes the reading closest to today', () {
    expect(readReceipt('Date: 05/10/2026 Total: 20.00 ETB', now: now).date,
        DateTime(2026, 10, 5, 12));
    expect(readReceipt('22 Oct 2026', now: now).date, DateTime(2026, 10, 22, 12));
    expect(readReceipt('Oct 25, 2026', now: now).date, now);
    expect(readReceipt('Date: 01/12/2026', now: now).date, DateTime(2026, 1, 12, 12),
        reason: 'December is still in the future');
  });

  test('finds an amount by its label when no currency is written', () {
    expect(readReceipt('Total: 1,250.50', now: now).amount, 125050);
  });

  test('a failed transaction or an unrelated picture gives no amount', () {
    expect(readReceipt('Transaction failed\nAmount: 300.00 ETB', now: now).amount,
        isNull);
    expect(readReceipt('A photo of a cat', now: now).amount, isNull);
  });
}
