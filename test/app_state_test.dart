import 'dart:convert';

import 'package:birrwise/app_state.dart';
import 'package:birrwise/domain.dart';
import 'package:birrwise/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;
  // Accounts and tracking start at 09:00; test alerts arrive from 10:00.
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 22, 9);
    state = AppState(clock: () => now);
    await state.load();
    await state.chooseBanks(SmsParser.institutions.toSet());
  });

  test('derives account balances and keeps transfers out of income totals',
      () async {
    await state.addAccount(
      name: 'Wallet',
      institution: 'Telebirr',
      openingBalance: 10000,
    );
    await state.addAccount(
      name: 'Cash',
      institution: 'Cash',
      openingBalance: 20000,
    );
    final from = state.accounts[0];
    final to = state.accounts[1];

    await state.addEntry(
      accountId: from.id,
      type: EntryType.income,
      amount: 5000,
      category: 'salary',
    );
    await state.addEntry(
      accountId: from.id,
      type: EntryType.expense,
      amount: 1000,
      category: 'food_groceries',
    );
    await state.addTransfer(
      fromAccountId: from.id,
      toAccountId: to.id,
      amount: 4000,
    );

    expect(state.balanceFor(from.id), 10000);
    expect(state.balanceFor(to.id), 24000);
    expect(state.totalBalance, 34000);
    expect(state.monthIncome, 5000);
    expect(state.monthExpenses, 1000);
  });

  test('SMS confirmation and duplicate handling are idempotent', () async {
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 0,
    );
    const body = 'You received ETB 50.00. TXN ID: CBE123456';
    expect(await state.ingestSms('CBE', body), isTrue);
    expect(await state.ingestSms('CBE', body), isFalse);

    final pending = state.messages.single;
    expect(
      await state.confirmSms(
        pending.id,
        accountId: state.accounts.single.id,
      ),
      isTrue,
    );
    expect(
      await state.confirmSms(
        pending.id,
        accountId: state.accounts.single.id,
      ),
      isFalse,
    );
    expect(state.entries.length, 1);
    expect(state.balanceFor(state.accounts.single.id), 5000);
  });

  test('imports clear SMS automatically only with one matching account',
      () async {
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);

    final summary = await state.ingestBankSms([
      BankSms(
        id: 'history:1',
        sender: 'CBE',
        body: 'You received ETB 50.00. TXN ID: CBE123456',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
      BankSms(
        id: 'history:2',
        sender: 'CBE',
        body: 'You paid ETB 20.00 at a shop.',
        receivedAt: DateTime(2026, 10, 22, 11),
      ),
      BankSms(
        id: 'history:3',
        sender: 'CBE',
        body: 'ETB 90.00 transaction ref CBE789012',
        receivedAt: DateTime(2026, 10, 22, 12),
      ),
      BankSms(
        id: 'history:4',
        sender: 'unknown',
        body: 'You received ETB 500.00. TXN ID: X1',
        receivedAt: DateTime(2026, 10, 22, 13),
      ),
    ]);

    expect(summary.imported, 2);
    expect(summary.scanned, 4);
    expect(summary.recognized, 3);
    expect(summary.pending, 1);
    expect(summary.ignored, 1);
    expect(summary.duplicates, 0);
    expect(state.entries, hasLength(2));
    expect(state.entries.every((entry) => entry.source == EntrySource.sms),
        isTrue);
    expect(
      state.entries.map((entry) => entry.type),
      containsAll([EntryType.income, EntryType.expense]),
    );
    expect(state.balanceFor(state.accounts.single.id), 3000);
    expect(state.messages.where((message) => message.status == 'pending'),
        hasLength(1));
  });

  test('keeps clear bank alerts for review when accounts are ambiguous',
      () async {
    await state.addAccount(
      name: 'CBE One',
      institution: 'CBE',
      openingBalance: 0,
    );
    await state.addAccount(
      name: 'CBE Two',
      institution: 'CBE',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);

    final summary = await state.ingestBankSms([
      BankSms(
        id: 'history:5',
        sender: 'CBE',
        body: 'You received ETB 50.00. TXN ID: CBE123457',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
    ]);

    expect(summary.imported, 0);
    expect(summary.pending, 1);
    expect(state.entries, isEmpty);
  });

  test('deduplicates an inbox message and its live SMS broadcast', () async {
    await state.addAccount(
      name: 'Telebirr',
      institution: 'Telebirr',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);
    const body = 'You received ETB 50.00. TXN ID: TB1234567';
    final first = await state.ingestBankSms([
      BankSms(
        id: 'inbox:1',
        sender: '127',
        body: body,
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
    ]);
    final second = await state.ingestBankSms([
      BankSms(
        id: 'incoming:hash',
        sender: '127',
        body: body,
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
    ]);

    expect(first.imported, 1);
    expect(second.duplicates, 1);
    expect(state.entries, hasLength(1));
    expect(state.messages, hasLength(1));
  });

  test('deduplicates reference-free SMS after auto-import clears the body',
      () async {
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);
    const body = 'You received ETB 50.00 from Hana.';
    final receivedAt = DateTime(2026, 10, 22, 10);

    final first = await state.ingestBankSms([
      BankSms(
        id: 'inbox:reference-free',
        sender: 'CBE',
        body: body,
        receivedAt: receivedAt,
      ),
    ]);
    final second = await state.ingestBankSms([
      BankSms(
        id: 'incoming:reference-free',
        sender: 'CBE',
        body: body,
        receivedAt: receivedAt,
      ),
    ]);

    expect(first.imported, 1);
    expect(second.duplicates, 1);
    expect(state.entries, hasLength(1));
    expect(state.messages.single.body, isEmpty);
    expect(state.messages.single.sourceFingerprint, isNotNull);
  });

  test('creates the bank account and matches the balance the bank reports',
      () async {
    await state.setBankSmsAutomationEnabled(true);
    final summary = await state.ingestBankSms([
      BankSms(
        id: 'inbox:newer',
        sender: '127',
        body: 'You have paid ETB 30.00. Your transaction number is HX12AB34CD. '
            'Your current balance is ETB 970.00.',
        receivedAt: DateTime(2026, 10, 22, 11),
      ),
      BankSms(
        id: 'inbox:older',
        sender: '127',
        body: 'You have received ETB 200.00. Your transaction number is '
            'HX56CD78EF. Your current balance is ETB 1,000.00.',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
      BankSms(
        id: 'inbox:unclear',
        sender: '127',
        body: 'Transaction of ETB 5.00 processed. Ref: HX90GH12IJ',
        receivedAt: DateTime(2026, 10, 22, 12),
      ),
    ]);

    final account = state.accounts.single;
    expect(account.name, 'Telebirr');
    expect(summary.imported, 2);
    expect(summary.pending, 1);
    expect(state.balanceFor(account.id), 97000);
    expect(state.monthIncome, 20000);
    expect(state.monthExpenses, 3000);
  });

  test('older alerts are added without double-counting a typed balance',
      () async {
    // The opening balance entered at 11:00 already includes the 10:00 alert.
    now = DateTime(2026, 10, 22, 11);
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 100000,
    );
    await state.setBankSmsAutomationEnabled(true);

    final summary = await state.ingestBankSms([
      BankSms(
        id: 'inbox:before-account',
        sender: 'CBE',
        body: 'You received ETB 42.00 from Hana. Ref: FT24009ABCDE. '
            'Your balance is ETB 1,000.00',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
    ]);

    expect(summary.imported, 1);
    expect(state.pendingCount, 0);
    expect(state.balanceFor(state.accounts.single.id), 100000);
    expect(state.monthIncome, 4200);
  });

  test('alerts left waiting by an older version are added on load', () async {
    final waiting = PendingSms(
      id: 'inbox:old',
      sender: '127',
      institution: 'Telebirr',
      body: 'You have paid ETB 30.00.',
      amount: 3000,
      direction: SmsDirection.expense,
      party: 'Telebirr',
      reference: null,
      balanceAfter: 50000,
      receivedAt: DateTime(2026, 10, 20),
      confidence: SmsConfidence.medium,
      automaticallyFetched: true,
    );
    SharedPreferences.setMockInitialValues({
      'bankSmsAutomationEnabled': true,
      'messages': jsonEncode([waiting.toJson()]),
    });
    final reopened = AppState(clock: () => now);
    await reopened.load();
    // They wait until the person says which banks are theirs.
    expect(reopened.pendingCount, 1);
    await reopened.chooseBanks({'Telebirr'});

    expect(reopened.pendingCount, 0);
    expect(reopened.balanceFor(reopened.accounts.single.id), 50000);

    // The import is saved, so it is not repeated on the next launch.
    final again = AppState(clock: () => now);
    await again.load();
    expect(again.accounts, hasLength(1));
    expect(again.entries, hasLength(2));
  });

  test('two different Telebirr alerts are both imported', () async {
    await state.addAccount(
      name: 'Telebirr',
      institution: 'Telebirr',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);

    final summary = await state.ingestBankSms([
      BankSms(
        id: 'incoming:a',
        sender: '127',
        body: 'You have paid ETB 30.00. Your transaction number is CJA11BB22C',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
      BankSms(
        id: 'incoming:b',
        sender: '127',
        body: 'You have paid ETB 45.00. Your transaction number is CJD33EE44F',
        receivedAt: DateTime(2026, 10, 22, 10, 5),
      ),
    ]);

    expect(summary.imported, 2);
    expect(summary.duplicates, 0);
    expect(state.balanceFor(state.accounts.single.id), -7500);
  });

  test('same reference-free alert with timestamps minutes apart is deduped',
      () async {
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);
    const body = 'You received ETB 50.00 from Hana.';

    await state.ingestBankSms([
      BankSms(
        id: 'incoming:live',
        sender: 'CBE',
        body: body,
        receivedAt: DateTime(2026, 10, 22, 10, 0, 30),
      ),
    ]);
    final rescan = await state.ingestBankSms([
      BankSms(
        id: 'inbox:77',
        sender: 'CBE',
        body: body,
        receivedAt: DateTime(2026, 10, 22, 10, 2, 10),
      ),
    ]);

    expect(rescan.duplicates, 1);
    expect(state.entries, hasLength(1));
  });

  test('transfer legs have distinct IDs and are removed together', () async {
    await state.addAccount(name: 'A', institution: 'Cash', openingBalance: 0);
    await state.addAccount(name: 'B', institution: 'Cash', openingBalance: 0);
    await state.addTransfer(
      fromAccountId: state.accounts[0].id,
      toAccountId: state.accounts[1].id,
      amount: 500,
    );

    expect(state.entries.map((e) => e.id).toSet(), hasLength(2));
    final removed = await state.removeEntry(state.entries.first.id);
    expect(removed, hasLength(2));
    expect(state.entries, isEmpty);
    await state.restoreEntries(removed!);
    expect(state.entries, hasLength(2));
  });

  test('repairs duplicate entry IDs and missing account dates on load',
      () async {
    final entry = {
      'id': '1',
      'accountId': 'a',
      'type': 'income',
      'amount': 100,
      'date': DateTime(2026, 10, 1).millisecondsSinceEpoch,
    };
    SharedPreferences.setMockInitialValues({
      'accounts': jsonEncode([
        {'id': 'a', 'name': 'Cash', 'institution': 'Cash', 'openingBalance': 0}
      ]),
      'entries': jsonEncode([entry, entry]),
    });
    final migrated = AppState(clock: () => DateTime(2026, 10, 22, 9));
    await migrated.load();

    expect(migrated.entries.map((e) => e.id).toSet(), hasLength(2));
    expect(migrated.accounts.single.createdAt, DateTime(2026, 10, 22, 9));

    // The migration is saved, so the date does not move on later launches.
    final reopened = AppState(clock: () => DateTime(2026, 10, 25));
    await reopened.load();
    expect(reopened.accounts.single.createdAt, DateTime(2026, 10, 22, 9));
    expect(reopened.entries.map((e) => e.id).toSet(), hasLength(2));
  });

  test('reconcile records a signed adjustment outside income and expenses',
      () async {
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 10000,
    );
    final id = state.accounts.single.id;

    expect(await state.reconcileAccount(id, 8000), -2000);
    expect(state.balanceFor(id), 8000);
    expect(state.entries.single.type, EntryType.adjustment);
    expect(state.monthIncome, 0);
    expect(state.monthExpenses, 0);
    expect(await state.reconcileAccount(id, 8000), 0);
    expect(state.entries, hasLength(1));
  });

  test('archived accounts leave the total balance', () async {
    await state.addAccount(name: 'A', institution: 'Cash', openingBalance: 100);
    await state.addAccount(name: 'B', institution: 'CBE', openingBalance: 50);
    await state.setAccountArchived(state.accounts[1].id, true);
    expect(state.totalBalance, 100);
    await state.setAccountArchived(state.accounts[1].id, false);
    expect(state.totalBalance, 150);
  });

  test('manual SMS imports always stay in review', () async {
    await state.addAccount(
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 0,
    );
    await state.setBankSmsAutomationEnabled(true);

    expect(
      await state.ingestSms(
        'CBE',
        'You received ETB 50.00. TXN ID: CBE123458',
      ),
      isTrue,
    );
    expect(state.entries, isEmpty);
    expect(state.pendingCount, 1);
  });

  test('bill pay and undo are idempotent', () async {
    await state.addAccount(
      name: 'Cash',
      institution: 'Cash',
      openingBalance: 100000,
    );
    await state.createBill(
      title: 'Internet',
      amount: 2500,
      dueDay: 5,
      accountId: state.accounts.single.id,
    );
    final bill = state.bills.single;

    await state.payBill(bill);
    await state.payBill(bill);
    expect(state.entries.length, 1);
    expect(state.balanceFor(state.accounts.single.id), 97500);

    await state.undoBillPayment(bill);
    expect(state.entries, isEmpty);
    expect(state.balanceFor(state.accounts.single.id), 100000);
  });

  test('saves and restores ledger data locally', () async {
    await state.addAccount(
      name: 'Cash',
      institution: 'Cash',
      openingBalance: 12345,
    );
    final restored = AppState();
    await restored.load();
    expect(restored.accounts.single.name, 'Cash');
    expect(restored.totalBalance, 12345);
  });

  test('persists that the first-run SMS explanation was already shown',
      () async {
    await state.markSmsAutomationPrompted();
    final restored = AppState();
    await restored.load();
    expect(restored.smsAutomationPrompted, isTrue);
  });

  test('budgets, targets and loans persist; a 0 limit removes a budget',
      () async {
    await state.setBudget('transport', 300000);
    await state.setBudget('rent', 800000);
    await state.setBudget('rent', 0);
    await state.setMonthlyTargets(income: 3500000, spending: 2200000);
    await state.addLoan(person: 'Dawit', lent: true, amount: 450000);
    await state.recordLoanPayment(state.loans.single.id, 150000);

    final reopened = AppState(clock: () => now);
    await reopened.load();
    expect(reopened.budgets, {'transport': 300000});
    expect(reopened.incomeTarget, 3500000);
    expect(reopened.plannedSpending, 2200000);
    expect(reopened.loans.single.remaining, 300000);

    // Paying more than is owed settles the loan without going negative.
    await reopened.recordLoanPayment(reopened.loans.single.id, 999999);
    expect(reopened.loans.single.remaining, 0);
    expect(reopened.loans.single.settled, isTrue);
  });

  test('PIN is checked without being stored in plain text', () async {
    await state.setPin('2580');
    expect(state.pinHash, isNot(contains('2580')));
    expect(state.checkPin('2580'), isTrue);
    expect(state.checkPin('0000'), isFalse);
    expect(() => state.setPin('12a4'), throwsArgumentError);
    await state.clearPin();
    expect(state.hasPin, isFalse);
  });

  test('backup round-trips the ledger and a bad file changes nothing',
      () async {
    await state.addAccount(name: 'CBE', institution: 'CBE', openingBalance: 5);
    await state.setBudget('rent', 100);
    await state.addLoan(person: 'Hana', lent: false, amount: 900);
    await state.setPin('1111');
    final backup = state.exportBackup();

    await state.clearAllData();
    expect(state.accounts, isEmpty);
    expect(state.hasPin, isFalse);

    expect(await state.restoreBackup('{"app":"BirrWise","accounts":[{}]}'),
        isFalse);
    expect(await state.restoreBackup('not json'), isFalse);
    expect(state.accounts, isEmpty);

    expect(await state.restoreBackup(backup), isTrue);
    expect(state.accounts.single.name, 'CBE');
    expect(state.budgets, {'rent': 100});
    expect(state.loans.single.person, 'Hana');
    // The PIN is a device setting and is never restored from a file.
    expect(state.hasPin, isFalse);
  });

  test('saved CBE Birr alerts filed under CBE move to their own wallet',
      () async {
    final saved = PendingSms(
      id: 'inbox:wallet',
      sender: 'CBEBirr',
      institution: 'CBE',
      body: 'You have paid ETB 100.00. Trans ID: CB2481023. '
          'Current balance is ETB 840.00.',
      amount: 10000,
      direction: SmsDirection.expense,
      party: 'CBE',
      reference: 'CB2481023',
      balanceAfter: 84000,
      receivedAt: DateTime(2026, 10, 21),
      confidence: SmsConfidence.high,
      automaticallyFetched: true,
    );
    final bank = Account(
      id: 'bank',
      name: 'CBE',
      institution: 'CBE',
      openingBalance: 500000,
      createdAt: DateTime(2026, 10, 1),
    );
    SharedPreferences.setMockInitialValues({
      'bankSmsAutomationEnabled': true,
      'banksChosen': true,
      'accounts': jsonEncode([bank.toJson()]),
      'messages': jsonEncode([saved.toJson()]),
    });
    final reopened = AppState(clock: () => now);
    await reopened.load();

    expect(reopened.balanceFor('bank'), 500000);
    final wallet =
        reopened.accounts.singleWhere((a) => a.institution == 'CBE Birr');
    expect(reopened.balanceFor(wallet.id), 84000);

    // A rescan of the same alert is recognized as already seen.
    final rescan = await reopened.ingestBankSms([
      BankSms(
        id: 'inbox:wallet-again',
        sender: 'CBEBirr',
        body: saved.body,
        receivedAt: DateTime(2026, 10, 21),
      ),
    ]);
    expect(rescan.duplicates, 1);
  });

  test('a bank marked not mine is taken out, and comes back if re-ticked',
      () async {
    await state.setBankSmsAutomationEnabled(true);
    // Created by BirrWise from alerts, and holding only alert entries.
    await state.ingestBankSms([
      BankSms(
        id: 'inbox:dashen',
        sender: 'DashenBank',
        body: 'Dashen Alert: A/C *1048 Debited ETB 1,200.00. Txn Ref: DB772314.',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
    ]);
    // Added by the person, with a balance they typed.
    await state.addAccount(
        name: 'My BOA', institution: 'BOA', openingBalance: 9000);
    expect(state.accounts.map((a) => a.institution), ['Dashen', 'BOA']);

    await state.chooseBanks({'Telebirr', 'CBE'});
    expect(state.accounts.single.name, 'My BOA');
    expect(state.accounts.single.archived, isTrue);
    expect(state.entries, isEmpty);
    expect(state.messages.single.status, 'dismissed');
    expect(state.totalBalance, 0);

    await state.chooseBanks({'Telebirr', 'CBE', 'BOA'});
    expect(state.accounts.single.archived, isFalse);
  });

  test('alerts from an unticked bank are ignored', () async {
    await state.setBankSmsAutomationEnabled(true);
    await state.chooseBanks({'Telebirr'});
    final summary = await state.ingestBankSms([
      BankSms(
        id: 'inbox:ignored',
        sender: 'CBE',
        body: 'You received ETB 50.00. Ref: FT24001ABCDE',
        receivedAt: DateTime(2026, 10, 22, 10),
      ),
    ]);
    expect(summary.ignored, 1);
    expect(state.messages, isEmpty);
    expect(state.accounts, isEmpty);
  });
}
