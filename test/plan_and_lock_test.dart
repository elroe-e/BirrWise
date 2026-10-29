import 'package:birrwise/app_state.dart';
import 'package:birrwise/budget_loans.dart';
import 'package:birrwise/domain.dart';
import 'package:birrwise/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState();
    await state.load();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('the lock screen only opens with the right PIN', (tester) async {
    await state.setPin('2580');
    var unlocked = false;
    await pump(
        tester, PinLockScreen(state: state, onUnlock: () => unlocked = true));

    for (final digit in ['1', '1', '1', '1']) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();
    expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    expect(unlocked, isFalse);

    for (final digit in ['2', '5', '8', '0']) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();
    expect(unlocked, isTrue);
  });

  testWidgets('a budget shows this month\'s spending against its limit',
      (tester) async {
    await state.addAccount(name: 'Cash', institution: 'Cash', openingBalance: 0);
    await state.addEntry(
      accountId: state.accounts.single.id,
      type: EntryType.expense,
      amount: 40000,
      category: 'transport',
    );
    await state.setBudget('transport', 30000);
    await pump(tester, BudgetView(state: state));

    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('ETB 400.00 / 300.00'), findsOneWidget);
  });

  testWidgets('loans add up what is owed each way', (tester) async {
    await state.addLoan(person: 'Dawit', lent: true, amount: 450000);
    await state.addLoan(person: 'Hana', lent: false, amount: 100000);
    await pump(tester, LoansView(state: state));

    expect(find.text('ETB 4,500.00'), findsOneWidget);
    expect(find.text('ETB 1,000.00'), findsOneWidget);
    expect(find.text('Dawit'), findsOneWidget);
  });
}
