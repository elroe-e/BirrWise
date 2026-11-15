import 'package:birrwise/app_state.dart';
import 'package:birrwise/domain.dart';
import 'package:birrwise/pdf_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(clock: () => DateTime(2026, 10, 22, 9));
    await state.load();
    await state.addAccount(
        name: 'Wallet', institution: 'Telebirr', openingBalance: 100000);
    final id = state.accounts.single.id;
    await state.addEntry(
        accountId: id,
        type: EntryType.income,
        amount: 500000,
        category: 'salary',
        party: 'Employer',
        date: DateTime(2026, 10, 1, 9));
    await state.addEntry(
        accountId: id,
        type: EntryType.expense,
        amount: 150000,
        category: 'food_groceries',
        party: 'Shola market',
        date: DateTime(2026, 10, 3, 9));
    await state.addEntry(
        accountId: id,
        type: EntryType.expense,
        amount: 50000,
        category: 'transport',
        date: DateTime(2026, 9, 30, 9));
  });

  List<String> rows(List<Map<String, Object>> blocks) => [
        for (final b in blocks)
          if (b['k'] == 'row') (b['c']! as List<String>).join(' | ')
      ];

  test('this month: totals, categories, balances and signed transactions', () {
    final blocks =
        reportBlocks(state, 0, createdAt: DateTime(2026, 10, 22));
    expect(blocks.first, {'k': 'title', 't': 'BirrWise report'});
    expect(blocks[1]['t'], 'October 2026 · Created 22/10/2026');
    final table = rows(blocks);
    expect(table, contains(['Income', 'ETB 5,000.00'].join(' | ')));
    expect(table, contains(['Expenses', 'ETB 1,500.00'].join(' | ')));
    expect(table, contains(['Net savings', 'ETB 3,500.00'].join(' | ')));
    expect(table, contains(['Food & groceries', '100%', 'ETB 1,500.00'].join(' | ')));
    expect(table, contains(['Wallet', 'ETB 4,000.00'].join(' | ')));
    expect(table, contains(['1/10/2026', 'Employer · Wallet', 'Salary', '+ETB 5,000.00'].join(' | ')));
    expect(table,
        contains(['3/10/2026', 'Shola market · Wallet', 'Food & groceries', '−ETB 1,500.00'].join(' | ')));
    expect(table.where((r) => r.startsWith('30/9/2026')), isEmpty,
        reason: 'last month stays out');
  });

  test('does not repeat a payee that is also the account name', () async {
    await state.addEntry(
        accountId: state.accounts.single.id,
        type: EntryType.expense,
        amount: 1000,
        category: 'other',
        party: 'Wallet',
        date: DateTime(2026, 10, 4, 9));
    final table = rows(reportBlocks(state, 0));
    expect(table.where((r) => r.contains('Wallet · Wallet')), isEmpty);
    expect(table.where((r) => r.startsWith('4/10/2026 | Wallet |')), hasLength(1));
  });

  test('last month: balances as the month ended', () {
    final table = rows(reportBlocks(state, 1));
    expect(table, contains(['Expenses', 'ETB 500.00'].join(' | ')));
    expect(table, contains(['Wallet', 'ETB 500.00'].join(' | ')));
  });
}
