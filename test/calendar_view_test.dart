import 'package:birrwise/app_state.dart';
import 'package:birrwise/calendar_view.dart';
import 'package:birrwise/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FinanceEntry entry(EntryType type, int amount, DateTime date) => FinanceEntry(
      id: '$type$date',
      accountId: 'a',
      type: type,
      amount: amount,
      category: 'food',
      party: 'Shop',
      note: '',
      date: date,
    );

void main() {
  test('counts income and spending per day inside the month only', () {
    final state = AppState(clock: () => DateTime(2026, 10, 22, 9));
    final bounds = state.monthBounds();
    final days = calendarDays([
      entry(EntryType.income, 50000, DateTime(2026, 10, 1, 8)),
      entry(EntryType.expense, 20000, DateTime(2026, 10, 31, 23, 30)),
      entry(EntryType.expense, 5000, DateTime(2026, 10, 31, 9)),
      entry(EntryType.expense, 10000, DateTime(2026, 11, 1)),
      entry(EntryType.transferOut, 7000, DateTime(2026, 10, 5)),
    ], bounds.start, bounds.end);
    expect(days, hasLength(31));
    expect(days.first.income, 50000);
    expect(days.last.expense, 25000);
    expect(days[4].expense, 0, reason: 'transfers are not spending');
  });

  test('follows the Ethiopian calendar, including Pagume', () {
    final state = AppState(clock: () => DateTime(2026, 9, 8))
      ..useEthiopianCalendar = true;
    final bounds = state.monthBounds();
    final days = calendarDays([], bounds.start, bounds.end);
    expect(days, hasLength(5));
    expect(days.first.day, DateTime(2026, 9, 6));
    expect(days.last.day, DateTime(2026, 9, 10));
  });

  test('shortens amounts to fit a cell', () {
    expect(compactEtb(85000), '850');
    expect(compactEtb(100000), '1k');
    expect(compactEtb(123400), '1.2k');
    expect(compactEtb(1500000), '15k');
    expect(compactEtb(340000000), '3.4M');
  });

  testWidgets('shows a day\'s transactions when it is tapped', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final now = DateTime.now();
    state.entries = [
      entry(EntryType.expense, 250000, DateTime(now.year, now.month, now.day, 9)),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 360, child: CalendarView(state: state)),
        ),
      ),
    ));
    expect(find.text('−2.5k'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget, reason: 'today is selected');
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    expect(find.text('Shop'), findsNothing);
  });
}
