import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'ethiopian_date.dart';
import 'health_score.dart';
import 'sms_parser.dart';

/// How far back the one-time inbox scan looks. Older alerts are already part
/// of the balances people enter when they add an account.
const smsHistoryWindow = Duration(days: 30);

/// The same alert can reach BirrWise twice (inbox scan and live receiver) with
/// slightly different timestamps.
const _sameAlertWindow = Duration(minutes: 10);

class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  int _idCounter = 0;

  List<Account> accounts = [];
  List<FinanceEntry> entries = [];
  List<PendingSms> messages = [];
  List<SavingsGoal> goals = [];
  List<Bill> bills = [];
  List<Loan> loans = [];

  /// Monthly spending limit per category, in santim.
  Map<String, int> budgets = {};
  int incomeTarget = 0;
  int plannedSpending = 0;

  /// Banks and wallets whose alerts are ignored; all others are tracked.
  Set<String> ignoredInstitutions = {};

  /// Whether the person has said which banks and wallets are theirs. Until
  /// then alerts wait in the inbox, so none land in someone else's bank.
  bool banksChosen = false;
  bool merchantMode = false;

  /// "salt:hash" of the app-lock PIN, or null when there is no lock.
  String? pinHash;
  String language = 'en';
  bool soundEnabled = true;
  bool hapticsEnabled = true;
  bool hideBalances = false;
  bool darkMode = false;
  bool useEthiopianCalendar = false;
  bool bankSmsAutomationEnabled = false;
  bool smsHistoryScanned = false;
  bool smsAutomationPrompted = false;

  /// Alerts received before this are flagged when confirmed by hand, since
  /// they may already be part of a balance the person entered.
  DateTime? smsAutomationEnabledAt;
  String? smsAutomationStatus;
  String? smsAutomationError;
  SmsIngestSummary? lastSmsIngestSummary;
  bool ready = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accounts = _readList(
      prefs.getString('accounts'),
      Account.fromJson,
      field: 'accounts',
    );
    entries = _readList(
      prefs.getString('entries'),
      FinanceEntry.fromJson,
      field: 'transactions',
    );
    messages = _readList(
      prefs.getString('messages'),
      PendingSms.fromJson,
      field: 'SMS inbox',
    );
    goals = _readList(
      prefs.getString('goals'),
      SavingsGoal.fromJson,
      field: 'savings goals',
    );
    bills = _readList(
      prefs.getString('bills'),
      Bill.fromJson,
      field: 'bills',
    );
    loans = _readList(prefs.getString('loans'), Loan.fromJson, field: 'loans');
    budgets = _decodeBudgets(_decodeJson(prefs.getString('budgets'), 'budgets'));
    incomeTarget = prefs.getInt('incomeTarget') ?? 0;
    plannedSpending = prefs.getInt('plannedSpending') ?? 0;
    ignoredInstitutions =
        (prefs.getStringList('ignoredInstitutions') ?? const []).toSet();
    banksChosen = prefs.getBool('banksChosen') ?? false;
    merchantMode = prefs.getBool('merchantMode') ?? false;
    pinHash = prefs.getString('pinHash');
    language = prefs.getString('language') ?? 'en';
    soundEnabled = prefs.getBool('soundEnabled') ?? true;
    hapticsEnabled = prefs.getBool('hapticsEnabled') ?? true;
    hideBalances = prefs.getBool('hideBalances') ?? false;
    darkMode = prefs.getBool('darkMode') ?? false;
    useEthiopianCalendar = prefs.getBool('ethiopianCalendar') ?? false;
    bankSmsAutomationEnabled =
        prefs.getBool('bankSmsAutomationEnabled') ?? false;
    smsHistoryScanned = prefs.getBool('smsHistoryScanned') ?? false;
    smsAutomationPrompted = prefs.getBool('smsAutomationPrompted') ?? false;
    final enabledAt = prefs.getInt('smsAutomationEnabledAt');
    smsAutomationEnabledAt = enabledAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(enabledAt);
    final migrated = _migrate();
    // Adds alerts that were left waiting for an account by older versions.
    final imported = _autoImportPendingSms() > 0;
    if (migrated || imported) await _save();
    ready = true;
    notifyListeners();
  }

  /// Repairs data written by older versions. Returns true if anything changed.
  bool _migrate() {
    var changed = false;
    final now = _now();
    // Older versions did not record when an account was added. Treat it as
    // now, so alerts from before it are flagged when confirmed by hand.
    if (accounts.any((account) => account.createdAt == null)) {
      accounts = [
        for (final account in accounts)
          account.createdAt == null ? account.copyWith(createdAt: now) : account
      ];
      changed = true;
    }
    if (bankSmsAutomationEnabled && smsAutomationEnabledAt == null) {
      smsAutomationEnabledAt = now;
      changed = true;
    }
    // Older versions filed CBE Birr wallet alerts under the CBE bank. Without
    // this they would be matched to the bank account and its balance.
    String institutionOf(PendingSms message) =>
        SmsParser.institutionFor(message.sender) ?? message.institution;
    if (messages.any((m) => institutionOf(m) != m.institution)) {
      messages = [
        for (final m in messages) m.copyWith(institution: institutionOf(m))
      ];
      changed = true;
    }
    // Older versions could give both legs of a transfer the same ID, which
    // made deleting or listing one of them affect the other.
    final seen = <String>{};
    if (entries.any((entry) => !seen.add(entry.id))) {
      seen.clear();
      entries = [
        for (final entry in entries)
          seen.add(entry.id) ? entry : entry.withId(_id())
      ];
      changed = true;
    }
    return changed;
  }

  List<T> _readList<T>(String? json, T Function(Map<String, dynamic>) decode,
          {required String field}) =>
      _decodeList(_decodeJson(json, field), decode, field: field);

  Object? _decodeJson(String? json, String field) {
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException('Could not read saved $field.', error);
    }
  }

  List<T> _decodeList<T>(Object? value, T Function(Map<String, dynamic>) decode,
      {required String field}) {
    if (value == null) return [];
    try {
      if (value is! List<dynamic>) {
        throw const FormatException('Expected a list.');
      }
      return value.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Expected a record.');
        }
        return decode(item);
      }).toList();
    } on FormatException catch (error) {
      throw FormatException('Could not read saved $field.', error);
    } on TypeError catch (error) {
      throw FormatException('Could not read saved $field.', error);
    } on ArgumentError catch (error) {
      // An unknown enum name, such as a type from a newer version.
      throw FormatException('Could not read saved $field.', error);
    }
  }

  Map<String, int> _decodeBudgets(Object? value) {
    if (value == null) return {};
    if (value is! Map<String, dynamic> || value.values.any((v) => v is! int)) {
      throw const FormatException('Could not read saved budgets.');
    }
    return value.cast<String, int>();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final writes = <Future<bool>>[
      prefs.setString('accounts', encodeList(accounts, (a) => a.toJson())),
      prefs.setString('entries', encodeList(entries, (e) => e.toJson())),
      prefs.setString('messages', encodeList(messages, (m) => m.toJson())),
      prefs.setString('goals', encodeList(goals, (g) => g.toJson())),
      prefs.setString('bills', encodeList(bills, (b) => b.toJson())),
      prefs.setString('loans', encodeList(loans, (l) => l.toJson())),
      prefs.setString('budgets', jsonEncode(budgets)),
      prefs.setInt('incomeTarget', incomeTarget),
      prefs.setInt('plannedSpending', plannedSpending),
      prefs.setStringList('ignoredInstitutions', ignoredInstitutions.toList()),
      prefs.setBool('banksChosen', banksChosen),
      prefs.setBool('merchantMode', merchantMode),
      if (pinHash case final hash?)
        prefs.setString('pinHash', hash)
      else
        prefs.remove('pinHash'),
      prefs.setString('language', language),
      prefs.setBool('soundEnabled', soundEnabled),
      prefs.setBool('hapticsEnabled', hapticsEnabled),
      prefs.setBool('hideBalances', hideBalances),
      prefs.setBool('darkMode', darkMode),
      prefs.setBool('ethiopianCalendar', useEthiopianCalendar),
      prefs.setBool('bankSmsAutomationEnabled', bankSmsAutomationEnabled),
      prefs.setBool('smsHistoryScanned', smsHistoryScanned),
      prefs.setBool('smsAutomationPrompted', smsAutomationPrompted),
      if (smsAutomationEnabledAt case final enabledAt?)
        prefs.setInt(
            'smsAutomationEnabledAt', enabledAt.millisecondsSinceEpoch)
      else
        prefs.remove('smsAutomationEnabledAt'),
    ];
    final results = await Future.wait(writes);
    if (results.any((saved) => !saved)) {
      throw StateError('BirrWise could not save some local data.');
    }
  }

  /// The account's balance now, or as of [at] if given.
  int balanceFor(String accountId, {DateTime? at}) {
    var total = accounts
        .where((account) => account.id == accountId)
        .fold<int>(0, (sum, account) => sum + account.openingBalance);
    for (final entry in entries.where((entry) =>
        entry.accountId == accountId &&
        (at == null || !entry.date.isAfter(at)))) {
      switch (entry.type) {
        case EntryType.income:
        case EntryType.transferIn:
        case EntryType.adjustment:
          total += entry.amount;
          break;
        case EntryType.expense:
        case EntryType.transferOut:
        case EntryType.savings:
          total -= entry.amount;
          break;
      }
    }
    return total;
  }

  int get totalBalance => accounts
      .where((account) => !account.archived)
      .fold<int>(0, (sum, account) => sum + balanceFor(account.id));

  List<FinanceEntry> get recentEntries {
    final list = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  int get monthIncome => monthTotal(EntryType.income);
  int get monthExpenses => monthTotal(EntryType.expense);

  /// Start (inclusive) and end (exclusive) of the month [monthsAgo] months
  /// before the current one, in the calendar chosen in Settings.
  ({DateTime start, DateTime end}) monthBounds([int monthsAgo = 0]) {
    final now = _now();
    if (!useEthiopianCalendar) {
      return (
        start: DateTime(now.year, now.month - monthsAgo),
        end: DateTime(now.year, now.month - monthsAgo + 1),
      );
    }
    var start = ethiopianMonthStart(now);
    for (var i = 0; i < monthsAgo; i++) {
      start = ethiopianMonthStart(
          DateTime(start.year, start.month, start.day - 1));
    }
    return (start: start, end: nextEthiopianMonthStart(start));
  }

  bool isInCurrentMonth(DateTime date) => isInMonth(date, 0);

  bool isInMonth(DateTime date, int monthsAgo) {
    final bounds = monthBounds(monthsAgo);
    return !date.isBefore(bounds.start) && date.isBefore(bounds.end);
  }

  int monthTotal(EntryType type, [int monthsAgo = 0]) {
    final bounds = monthBounds(monthsAgo);
    return entries
        .where((e) =>
            e.type == type &&
            !e.date.isBefore(bounds.start) &&
            e.date.isBefore(bounds.end))
        .fold<int>(0, (sum, e) => sum + e.amount);
  }

  Map<String, int> monthExpensesByCategory() {
    final totals = <String, int>{};
    for (final entry in entries.where(
        (e) => e.type == EntryType.expense && isInCurrentMonth(e.date))) {
      totals.update(entry.category, (value) => value + entry.amount,
          ifAbsent: () => entry.amount);
    }
    return totals;
  }

  HealthScoreInputs healthInputs() {
    final history = [
      for (var monthsAgo = 1; monthsAgo <= 3; monthsAgo++)
        if (entries.any((e) =>
            (e.type == EntryType.income || e.type == EntryType.expense) &&
            isInMonth(e.date, monthsAgo)))
          monthTotal(EntryType.expense, monthsAgo),
    ];
    final timeliness = billTimeliness();
    return HealthScoreInputs(
      monthIncome: monthIncome,
      monthExpenses: monthExpenses,
      monthTransactionCount: entries
          .where((e) =>
              (e.type == EntryType.income || e.type == EntryType.expense) &&
              isInCurrentMonth(e.date))
          .length,
      billsDue: timeliness.due,
      billsPaidOnTime: timeliness.onTime,
      savedInGoals:
          goals.fold<int>(0, (sum, goal) => sum + savedForGoal(goal.id)),
      averageMonthlyExpense: history.isEmpty
          ? null
          : history.reduce((a, b) => a + b) ~/ history.length,
    );
  }

  /// Bills due so far this month, and how many of them were paid by their
  /// due date.
  ({int due, int onTime}) billTimeliness() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    var due = 0;
    var onTime = 0;
    for (final bill in bills.where((bill) => bill.active)) {
      final dueDate = billDueDate(bill);
      if (bill.lastPaidPeriod == billPeriod) {
        due++;
        final payment = entries
            .where((entry) => entry.id == bill.lastPaymentEntryId)
            .firstOrNull;
        final endOfDueDay =
            DateTime(dueDate.year, dueDate.month, dueDate.day + 1);
        if (payment == null || payment.date.isBefore(endOfDueDay)) onTime++;
      } else if (dueDate.isBefore(today)) {
        due++;
      }
    }
    return (due: due, onTime: onTime);
  }

  DateTime billDueDate(Bill bill) {
    final now = _now();
    final monthLength = DateTime(now.year, now.month + 1, 0).day;
    return DateTime(
        now.year, now.month, bill.dueDay.clamp(1, monthLength).toInt());
  }

  /// Unpaid bills that are overdue or due within the next three days.
  int get billsDueWithin3Days {
    final now = _now();
    final limit = DateTime(now.year, now.month, now.day + 4);
    return bills
        .where((bill) =>
            bill.active &&
            bill.lastPaidPeriod != billPeriod &&
            billDueDate(bill).isBefore(limit))
        .length;
  }

  int get pendingSmsOlderThan3Days {
    final cutoff = _now().subtract(const Duration(days: 3));
    return messages
        .where((m) => m.status == 'pending' && m.receivedAt.isBefore(cutoff))
        .length;
  }

  int savedForGoal(String goalId) => entries
      .where((e) => e.goalId == goalId && e.type == EntryType.savings)
      .fold<int>(0, (sum, e) => sum + e.amount);

  int get pendingCount => messages.where((m) => m.status == 'pending').length;

  Future<void> addAccount({
    required String name,
    required String institution,
    required int openingBalance,
    String maskedNumber = '',
  }) async {
    if (name.trim().isEmpty || openingBalance < 0) {
      throw ArgumentError('Enter a valid account name and opening balance.');
    }
    accounts = [
      ...accounts,
      Account(
        id: _id(),
        name: name.trim(),
        institution: institution,
        openingBalance: openingBalance,
        maskedNumber: maskedNumber,
        createdAt: _now(),
      ),
    ];
    if (bankSmsAutomationEnabled) _autoImportPendingSms();
    await _changed();
  }

  Future<void> setAccountArchived(String accountId, bool archived) async {
    accounts = [
      for (final account in accounts)
        account.id == accountId ? account.copyWith(archived: archived) : account
    ];
    await _changed();
  }

  /// Records the difference between the derived balance and [balance] as an
  /// adjustment, so the account matches what the bank or wallet shows.
  /// Returns the signed difference (0 if it already matched).
  Future<int> reconcileAccount(String accountId, int balance) async {
    if (!accounts.any((account) => account.id == accountId)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    final difference = _reconcile(accountId, balance);
    if (difference != 0) await _changed();
    return difference;
  }

  /// Adds an adjustment dated [at] (default now) so the balance as of then
  /// is [balance]. Returns the signed difference.
  int _reconcile(String accountId, int balance, {DateTime? at}) {
    final difference = balance - balanceFor(accountId, at: at);
    if (difference == 0) return 0;
    entries = [
      ...entries,
      FinanceEntry(
        id: _id(),
        accountId: accountId,
        type: EntryType.adjustment,
        amount: difference,
        category: 'other',
        party: '',
        note: '',
        date: at ?? _now(),
      ),
    ];
    return difference;
  }

  /// True if no entry in [accountId] is dated after [date], i.e. a bank
  /// balance reported at [date] is the account's current balance.
  bool isLatestFor(String accountId, DateTime date) => !entries.any(
      (entry) => entry.accountId == accountId && entry.date.isAfter(date));

  /// True if [message] arrived before [accountId] was added or before SMS
  /// tracking was turned on, so confirming it changes a balance the person
  /// entered themselves.
  bool isOlderThanTracking(PendingSms message, String accountId) {
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    final createdAt = account?.createdAt;
    if (createdAt != null && message.receivedAt.isBefore(createdAt)) {
      return true;
    }
    final enabledAt = smsAutomationEnabledAt;
    return message.automaticallyFetched &&
        enabledAt != null &&
        message.receivedAt.isBefore(enabledAt);
  }

  Future<void> addEntry({
    required String accountId,
    required EntryType type,
    required int amount,
    required String category,
    String party = '',
    String note = '',
    DateTime? date,
    EntrySource source = EntrySource.manual,
    String? institution,
    String? smsReference,
    String? goalId,
    bool business = false,
  }) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    if (!accounts.any((account) => account.id == accountId)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    if (source == EntrySource.sms &&
        institution != null &&
        smsReference != null &&
        entries.any((e) =>
            e.institution == institution && e.smsReference == smsReference)) {
      return;
    }
    final entryId = _id();
    entries = [
      ...entries,
      FinanceEntry(
        id: entryId,
        accountId: accountId,
        type: type,
        amount: amount,
        category: category,
        party: party.trim(),
        note: note.trim(),
        date: date ?? _now(),
        source: source,
        institution: institution,
        smsReference: smsReference,
        goalId: goalId,
        business: business,
      ),
    ];
    await _changed();
  }

  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    String note = '',
    DateTime? date,
  }) async {
    if (amount <= 0 || fromAccountId == toAccountId) {
      throw ArgumentError('Choose two different accounts and a valid amount.');
    }
    if (!accounts.any((account) => account.id == fromAccountId) ||
        !accounts.any((account) => account.id == toAccountId)) {
      throw ArgumentError('Choose two existing accounts.');
    }
    final groupId = _id();
    final now = date ?? _now();
    final out = FinanceEntry(
      id: _id(),
      accountId: fromAccountId,
      type: EntryType.transferOut,
      amount: amount,
      category: 'other',
      party: note,
      note: note,
      date: now,
      transferGroupId: groupId,
    );
    final incoming = FinanceEntry(
      id: _id(),
      accountId: toAccountId,
      type: EntryType.transferIn,
      amount: amount,
      category: 'other',
      party: note,
      note: note,
      date: now,
      transferGroupId: groupId,
    );
    entries = [...entries, out, incoming];
    await _changed();
  }

  Future<List<FinanceEntry>?> removeEntry(String id) async {
    final removed = entries.where((entry) => entry.id == id).firstOrNull;
    if (removed == null) return null;
    final group = removed.transferGroupId;
    final removedEntries = entries
        .where((entry) =>
            entry.id == id || (group != null && entry.transferGroupId == group))
        .toList();
    entries =
        entries.where((entry) => !removedEntries.contains(entry)).toList();
    await _changed();
    return removedEntries;
  }

  Future<void> restoreEntries(List<FinanceEntry> restored) async {
    final existingIds = entries.map((entry) => entry.id).toSet();
    final missing = restored.where((entry) => !existingIds.contains(entry.id));
    entries = [...entries, ...missing];
    await _changed();
  }

  Future<bool> ingestSms(String sender, String body) async {
    final summary = await ingestBankSms([
      BankSms(
        id: 'manual:${_id()}',
        sender: sender,
        body: body,
        receivedAt: _now(),
      ),
    ], autoImport: false);
    return summary.pending + summary.imported > 0;
  }

  Future<SmsIngestSummary> ingestBankSms(
    List<BankSms> incoming, {
    bool autoImport = true,
  }) async {
    var imported = 0;
    var recognized = 0;
    var pending = 0;
    var ignored = 0;
    var duplicates = 0;
    var changed = false;
    final added = <(String, PendingSms)>[];

    for (final sms in incoming) {
      final parsed = SmsParser.parse(sms.sender, sms.body);
      if (parsed == null || ignoredInstitutions.contains(parsed.institution)) {
        ignored++;
        continue;
      }
      recognized++;
      final fingerprint = _smsFingerprint(sms);
      final candidate = parsed.toPending(
        id: sms.id,
        receivedAt: sms.receivedAt,
        automaticallyFetched: autoImport,
        sourceFingerprint: fingerprint,
        bodyHash: _hash(_normalizeBody(sms.body)),
      );
      if (_isDuplicateSms(candidate)) {
        duplicates++;
        continue;
      }
      if (candidate.reference != null &&
          entries.any((entry) =>
              entry.institution == candidate.institution &&
              entry.smsReference == candidate.reference)) {
        duplicates++;
        continue;
      }
      if (entries.any((entry) =>
          entry.institution == candidate.institution &&
          entry.smsReference == 'sms:$fingerprint')) {
        duplicates++;
        continue;
      }

      messages = [...messages, candidate];
      changed = true;
      final account = autoImport && bankSmsAutomationEnabled && banksChosen
          ? _accountForAutoImport(candidate)
          : null;
      if (account != null) {
        if (_confirmSms(candidate.id, accountId: account.id, clearBody: true)) {
          imported++;
          added.add((account.id, candidate));
        } else {
          duplicates++;
        }
      } else {
        pending++;
      }
    }
    _matchBankBalances(added);

    if (changed) await _changed();
    return SmsIngestSummary(
      scanned: incoming.length,
      recognized: recognized,
      imported: imported,
      pending: pending,
      ignored: ignored,
      duplicates: duplicates,
    );
  }

  bool _isDuplicateSms(PendingSms candidate) {
    final normalizedBody = _normalizeBody(candidate.body);
    return messages.any((item) {
      if (item.id == candidate.id) return true;
      if (item.institution != candidate.institution) return false;
      if (candidate.sourceFingerprint != null &&
          item.sourceFingerprint == candidate.sourceFingerprint) {
        return true;
      }
      if (candidate.reference != null && item.reference != null) {
        return candidate.reference == item.reference;
      }
      final closeInTime =
          item.receivedAt.difference(candidate.receivedAt).abs() <=
              _sameAlertWindow;
      if (candidate.bodyHash != null &&
          item.bodyHash == candidate.bodyHash &&
          closeInTime) {
        return true;
      }
      if (item.sender.toLowerCase() != candidate.sender.toLowerCase()) {
        return false;
      }
      final existingBody =
          item.body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      return existingBody == normalizedBody &&
          item.receivedAt.difference(candidate.receivedAt).inMinutes.abs() <= 2;
    });
  }

  /// The account a fetched alert is added to without review: the one active
  /// account for its bank. A bank with no account yet gets one. Null means
  /// the alert waits in review (unclear direction, or several accounts).
  Account? _accountForAutoImport(PendingSms message) {
    final bank = message.institution.toLowerCase();
    if (!accounts.any((account) => account.institution.toLowerCase() == bank)) {
      accounts = [
        ...accounts,
        Account(
          id: _id(),
          name: message.institution,
          institution: message.institution,
          openingBalance: 0,
          createdAt: _now(),
        ),
      ];
    }
    return message.direction == SmsDirection.unknown
        ? null
        : _accountForSms(message);
  }

  /// Makes each account agree with the balance its bank reported in the
  /// newest of the [added] alerts, so alerts that are already part of an
  /// opening balance are not counted twice. The difference is recorded as an
  /// adjustment at that alert's time.
  void _matchBankBalances(List<(String, PendingSms)> added) {
    final newest = <String, PendingSms>{};
    for (final (accountId, message) in added) {
      final current = newest[accountId];
      if (message.balanceAfter != null &&
          (current == null || message.receivedAt.isAfter(current.receivedAt))) {
        newest[accountId] = message;
      }
    }
    newest.forEach((accountId, message) {
      final at = message.receivedAt;
      // shortcut: an alert older than a later adjustment is left alone, so an
      // old alert found by a rescan can leave the balance off by its amount
      // until the next alert or a Correct balance; re-anchor on the newest
      // reported balance overall if that shows up in practice.
      if (entries.any((entry) =>
          entry.accountId == accountId &&
          entry.type == EntryType.adjustment &&
          entry.date.isAfter(at))) {
        return;
      }
      _reconcile(accountId, message.balanceAfter!, at: at);
    });
  }

  Account? _accountForSms(PendingSms message) {
    final matches = accounts
        .where((account) =>
            !account.archived &&
            account.institution.toLowerCase() ==
                message.institution.toLowerCase())
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  int _autoImportPendingSms() {
    if (!bankSmsAutomationEnabled || !banksChosen) return 0;
    final added = <(String, PendingSms)>[];
    for (final message in messages.toList()) {
      if (!message.automaticallyFetched || message.status != 'pending') {
        continue;
      }
      final account = _accountForAutoImport(message);
      if (account != null &&
          _confirmSms(message.id, accountId: account.id, clearBody: true)) {
        added.add((account.id, message));
      }
    }
    _matchBankBalances(added);
    final imported = added.length;
    final previous = lastSmsIngestSummary;
    if (imported > 0 && previous != null) {
      lastSmsIngestSummary = SmsIngestSummary(
        scanned: previous.scanned,
        recognized: previous.recognized,
        imported: previous.imported + imported,
        pending:
            (previous.pending - imported).clamp(0, previous.pending).toInt(),
        ignored: previous.ignored,
        duplicates: previous.duplicates,
      );
    }
    return imported;
  }

  String _smsFingerprint(BankSms sms) => _hash([
        sms.sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        sms.receivedAt.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute,
        _normalizeBody(sms.body),
      ].join('|'));

  static String _normalizeBody(String body) =>
      body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _hash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> setBankSmsAutomationEnabled(bool enabled) async {
    if (enabled && !bankSmsAutomationEnabled) smsAutomationEnabledAt = _now();
    if (!enabled) smsAutomationEnabledAt = null;
    bankSmsAutomationEnabled = enabled;
    smsAutomationStatus = null;
    smsAutomationError = null;
    lastSmsIngestSummary = null;
    await _changed();
  }

  Future<void> markSmsHistoryScanned() async {
    smsHistoryScanned = true;
    await _changed();
  }

  Future<void> markSmsAutomationPrompted() async {
    if (smsAutomationPrompted) return;
    smsAutomationPrompted = true;
    await _changed();
  }

  void setSmsAutomationStatus(String status) {
    if (smsAutomationStatus == status && smsAutomationError == null) return;
    smsAutomationStatus = status;
    smsAutomationError = null;
    notifyListeners();
  }

  void setSmsAutomationError(String error) {
    smsAutomationStatus = 'sync_failed';
    smsAutomationError = error;
    notifyListeners();
  }

  void setSmsAutomationSummary(SmsIngestSummary summary) {
    final previous = lastSmsIngestSummary;
    if (previous != null &&
        previous.imported == summary.imported &&
        previous.pending == summary.pending &&
        previous.ignored == summary.ignored &&
        previous.duplicates == summary.duplicates &&
        previous.scanned == summary.scanned &&
        previous.recognized == summary.recognized) {
      return;
    }
    lastSmsIngestSummary = summary;
    notifyListeners();
  }

  Future<void> updateSms(PendingSms changed) async {
    messages =
        messages.map((item) => item.id == changed.id ? changed : item).toList();
    await _changed();
  }

  Future<bool> confirmSms(String id, {required String accountId}) async {
    final item = messages.where((m) => m.id == id).firstOrNull;
    if (item == null || !_confirmSms(id, accountId: accountId)) return false;
    await _changed();
    return true;
  }

  bool _confirmSms(String id,
      {required String accountId, bool clearBody = false}) {
    final item = messages.where((m) => m.id == id).firstOrNull;
    if (item == null || item.status != 'pending') return false;
    if (item.direction == SmsDirection.unknown) return false;
    if (!accounts.any((account) => account.id == accountId)) return false;
    if (item.reference != null &&
        entries.any((e) =>
            e.institution == item.institution &&
            e.smsReference == item.reference)) {
      messages = messages
          .map((m) => m.id == id
              ? m.copyWith(
                  status: 'confirmed',
                  body: clearBody ? '' : null,
                )
              : m)
          .toList();
      return false;
    }
    final entry = FinanceEntry(
      id: _id(),
      accountId: accountId,
      type: item.direction == SmsDirection.income
          ? EntryType.income
          : EntryType.expense,
      amount: item.amount,
      category: item.category,
      party: item.party,
      note: '',
      date: item.receivedAt,
      source: EntrySource.sms,
      institution: item.institution,
      smsReference: item.reference ??
          (item.sourceFingerprint == null
              ? null
              : 'sms:${item.sourceFingerprint}'),
    );
    entries = [...entries, entry];
    messages = messages
        .map((m) => m.id == id
            ? m.copyWith(
                status: 'confirmed',
                body: clearBody ? '' : null,
              )
            : m)
        .toList();
    return true;
  }

  Future<void> createGoal(String title, int target) async {
    if (title.trim().isEmpty || target <= 0) {
      throw ArgumentError('Enter a goal name and target.');
    }
    goals = [
      ...goals,
      SavingsGoal(
        id: _id(),
        title: title.trim(),
        target: target,
        createdAt: _now(),
      ),
    ];
    await _changed();
  }

  Future<void> depositToGoal(
      String goalId, String accountId, int amount) async {
    await addEntry(
      accountId: accountId,
      type: EntryType.savings,
      amount: amount,
      category: 'other',
      party: goals.where((g) => g.id == goalId).firstOrNull?.title ?? '',
      source: EntrySource.goal,
      goalId: goalId,
    );
  }

  Future<void> createBill({
    required String title,
    required int amount,
    required int dueDay,
    String recurrence = 'monthly',
    String? accountId,
  }) async {
    if (title.trim().isEmpty || amount <= 0) {
      throw ArgumentError('Enter a bill title and a positive amount.');
    }
    bills = [
      ...bills,
      Bill(
        id: _id(),
        title: title.trim(),
        amount: amount,
        dueDay: dueDay.clamp(1, 31).toInt(),
        recurrence: recurrence,
        active: true,
        accountId: accountId,
      ),
    ];
    await _changed();
  }

  Future<void> payBill(Bill bill) async {
    final current = bills.where((item) => item.id == bill.id).firstOrNull;
    if (current == null || !current.active) return;
    final accountId = (current.accountId != null &&
            accounts.any((a) => a.id == current.accountId && !a.archived)
        ? current.accountId
        : accounts.where((a) => !a.archived).firstOrNull?.id);
    if (accountId == null) throw StateError('Add an account first.');
    final period = billPeriod;
    if (current.lastPaidPeriod == period) return;
    final paymentId = _id();
    entries = [
      ...entries,
      FinanceEntry(
        id: paymentId,
        accountId: accountId,
        type: EntryType.expense,
        amount: current.amount,
        category: 'utilities',
        party: current.title,
        note: '',
        date: _now(),
        source: EntrySource.bill,
      ),
    ];
    bills = bills
        .map((b) => b.id == current.id
            ? b.copyWith(
                lastPaidPeriod: period,
                lastPaymentEntryId: paymentId,
              )
            : b)
        .toList();
    await _changed();
  }

  Future<void> undoBillPayment(Bill bill) async {
    final current = bills.where((item) => item.id == bill.id).firstOrNull;
    if (current == null) return;
    if (current.lastPaidPeriod != billPeriod) return;
    final paidEntryId = current.lastPaymentEntryId;
    if (paidEntryId == null) return;
    final paidEntry =
        entries.where((entry) => entry.id == paidEntryId).firstOrNull;
    if (paidEntry == null) return;
    entries = entries.where((entry) => entry.id != paidEntry.id).toList();
    bills = bills
        .map((b) => b.id == current.id ? b.copyWith(clearPayment: true) : b)
        .toList();
    await _changed();
  }

  /// Bills are tracked per Gregorian month.
  String get billPeriod {
    final now = _now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await _changed();
  }

  Future<void> setPreference(String key, bool value) async {
    switch (key) {
      case 'sound':
        soundEnabled = value;
        break;
      case 'haptics':
        hapticsEnabled = value;
        break;
      case 'hide':
        hideBalances = value;
        break;
      case 'dark':
        darkMode = value;
        break;
      case 'ethiopian':
        useEthiopianCalendar = value;
        break;
      case 'merchant':
        merchantMode = value;
        break;
    }
    await _changed();
  }

  /// Sets a category's monthly limit; 0 removes the budget.
  Future<void> setBudget(String category, int limit) async {
    if (limit < 0) throw ArgumentError.value(limit, 'limit');
    budgets = {...budgets, category: limit}..removeWhere((_, v) => v == 0);
    await _changed();
  }

  Future<void> setMonthlyTargets({
    required int income,
    required int spending,
  }) async {
    if (income < 0 || spending < 0) throw ArgumentError('Targets must be >= 0');
    incomeTarget = income;
    plannedSpending = spending;
    await _changed();
  }

  Future<void> addLoan({
    required String person,
    required bool lent,
    required int amount,
  }) async {
    if (person.trim().isEmpty || amount <= 0) {
      throw ArgumentError('Enter a name and an amount.');
    }
    loans = [
      ...loans,
      Loan(
        id: _id(),
        person: person.trim(),
        lent: lent,
        amount: amount,
        paid: 0,
        createdAt: _now(),
      ),
    ];
    await _changed();
  }

  /// Records a repayment, never beyond what is still owed.
  Future<void> recordLoanPayment(String id, int amount) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    loans = [
      for (final loan in loans)
        loan.id == id
            ? loan.withPaid((loan.paid + amount).clamp(0, loan.amount))
            : loan
    ];
    await _changed();
  }

  Future<void> removeLoan(String id) async {
    loans = loans.where((loan) => loan.id != id).toList();
    await _changed();
  }

  /// How many saved alerts came from each bank or wallet.
  Map<String, int> get alertCounts {
    final counts = <String, int>{};
    for (final message in messages) {
      counts.update(message.institution, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Records which banks and wallets are the person's, removes what was
  /// added from the others, and adds the waiting alerts from theirs.
  Future<void> chooseBanks(Set<String> mine) async {
    final before = banksChosen ? ignoredInstitutions : <String>{};
    ignoredInstitutions =
        SmsParser.institutions.where((i) => !mine.contains(i)).toSet();
    banksChosen = true;
    ignoredInstitutions.difference(before).forEach(_removeBank);
    final back = before.difference(ignoredInstitutions);
    accounts = [
      for (final a in accounts)
        back.contains(a.institution) ? a.copyWith(archived: false) : a
    ];
    _autoImportPendingSms();
    await _changed();
  }

  /// Takes a bank that is not the person's out of the ledger. Accounts that
  /// BirrWise created and filled only from its alerts are deleted with those
  /// entries; any other account for it is archived. Its alerts move to
  /// Dismissed, where they can still be restored.
  void _removeBank(String institution) {
    bool automatic(Account a) =>
        a.name == institution &&
        a.openingBalance == 0 &&
        entries.every((e) =>
            e.accountId != a.id ||
            e.source == EntrySource.sms ||
            e.type == EntryType.adjustment);
    final dropped = {
      for (final a in accounts)
        if (a.institution == institution && automatic(a)) a.id
    };
    entries = entries.where((e) => !dropped.contains(e.accountId)).toList();
    accounts = [
      for (final a in accounts)
        if (!dropped.contains(a.id))
          a.institution == institution ? a.copyWith(archived: true) : a
    ];
    messages = [
      for (final m in messages)
        m.institution == institution && m.status != 'dismissed'
            ? m.copyWith(status: 'dismissed')
            : m
    ];
  }

  bool get hasPin => pinHash != null;

  // shortcut: a 4-digit PIN has only 10,000 values, so the hash just keeps it
  // out of plain text; the app sandbox is the real protection. Use a slow
  // KDF if the PIN ever guards data that leaves the device.
  Future<void> setPin(String pin) async {
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      throw ArgumentError('The PIN must be 4 digits.');
    }
    final salt = _hash(_id());
    pinHash = '$salt:${_hash('$salt:$pin')}';
    await _changed();
  }

  bool checkPin(String pin) {
    final parts = pinHash?.split(':');
    if (parts == null || parts.length != 2) return true;
    return _hash('${parts[0]}:$pin') == parts[1];
  }

  Future<void> clearPin() async {
    pinHash = null;
    await _changed();
  }

  /// Everything in the ledger and plan, without device settings or the PIN.
  String exportBackup() => jsonEncode({
        'app': 'BirrWise',
        'version': 1,
        'exportedAt': _now().toIso8601String(),
        'accounts': [for (final a in accounts) a.toJson()],
        'entries': [for (final e in entries) e.toJson()],
        'messages': [for (final m in messages) m.toJson()],
        'goals': [for (final g in goals) g.toJson()],
        'bills': [for (final b in bills) b.toJson()],
        'loans': [for (final l in loans) l.toJson()],
        'budgets': budgets,
        'incomeTarget': incomeTarget,
        'plannedSpending': plannedSpending,
      });

  /// Replaces the ledger and plan with a backup. Nothing changes unless the
  /// whole file reads correctly.
  Future<bool> restoreBackup(String json) async {
    try {
      final data = jsonDecode(json);
      if (data is! Map<String, dynamic> || data['app'] != 'BirrWise') {
        return false;
      }
      final restoredAccounts =
          _decodeList(data['accounts'], Account.fromJson, field: 'accounts');
      final restoredEntries = _decodeList(
          data['entries'], FinanceEntry.fromJson,
          field: 'transactions');
      final restoredMessages =
          _decodeList(data['messages'], PendingSms.fromJson, field: 'SMS');
      final restoredGoals =
          _decodeList(data['goals'], SavingsGoal.fromJson, field: 'goals');
      final restoredBills =
          _decodeList(data['bills'], Bill.fromJson, field: 'bills');
      final restoredLoans =
          _decodeList(data['loans'], Loan.fromJson, field: 'loans');
      final restoredBudgets = _decodeBudgets(data['budgets']);
      final income = data['incomeTarget'] ?? 0;
      final spending = data['plannedSpending'] ?? 0;
      if (income is! int || spending is! int) return false;

      accounts = restoredAccounts;
      entries = restoredEntries;
      messages = restoredMessages;
      goals = restoredGoals;
      bills = restoredBills;
      loans = restoredLoans;
      budgets = restoredBudgets;
      incomeTarget = income;
      plannedSpending = spending;
    } on FormatException {
      return false;
    }
    _migrate();
    await _changed();
    return true;
  }

  /// Erases everything stored by BirrWise. Turn SMS tracking off on the
  /// Android side first, or queued alerts come back in.
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    smsAutomationStatus = null;
    smsAutomationError = null;
    lastSmsIngestSummary = null;
    await load();
  }

  Future<void> _changed() async {
    await _save();
    notifyListeners();
  }

  // Several IDs are often created within the same microsecond (both legs of a
  // transfer, a batch of SMS), so a counter keeps them unique.
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
}
