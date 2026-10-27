import 'package:birrwise/app_state.dart';
import 'package:birrwise/sms_inbox_screen.dart';
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

  Future<void> pumpInbox(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: SmsInboxScreen(state: state)));
    await tester.pumpAndSettle();
  }

  testWidgets('dismiss hides the card at once and Undo brings it back',
      (tester) async {
    await state.ingestSms('CBE', 'You received ETB 50.00. Ref: FT24001ABCDE');
    await state.ingestSms('CBE', 'You paid ETB 20.00. Ref: FT24002ABCDE');
    await pumpInbox(tester);
    expect(find.text('Dismiss'), findsNWidgets(2));

    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();
    expect(find.text('Dismiss'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Dismiss'), findsNWidgets(2));
  });

  testWidgets('confirming offers to match the balance the bank reports',
      (tester) async {
    await state.addAccount(name: 'CBE', institution: 'CBE', openingBalance: 0);
    await state.ingestSms(
      'CBE',
      'You received ETB 50.00 from Hana. Ref: FT24003ABCDE. '
          'Your balance is ETB 1,000.00',
    );
    await pumpInbox(tester);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(state.balanceFor(state.accounts.single.id), 5000);
    expect(find.textContaining('ETB 1,000.00'), findsOneWidget);

    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();
    expect(state.balanceFor(state.accounts.single.id), 100000);
    expect(state.monthIncome, 5000);
  });

  testWidgets('an alert with unknown direction shows the direction picker',
      (tester) async {
    await state.ingestSms(
        'CBE', 'Transaction of ETB 300.00 processed. Ref: FT0099XYZ12');
    await pumpInbox(tester);

    expect(find.text('Money in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
