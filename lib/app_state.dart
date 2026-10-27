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
  String language = 'en';
  bool soundEnabled = true;
  bool hapticsEnabled = true;
  bool hideBalances = false;
  bool darkMode = false;
  bool useEthiopianCalendar = false;
  bool bankSmsAutomationEnabled = false;
  bool smsHistoryScanned = false;
  bool smsAutomationPrompted = false;

  /// Alerts received before automation was turned on go to review instead of
  /// being added automatically, so they cannot double-count existing entries.
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
    if (_migrate()) await _save();
    ready = true;
    notifyListeners();
  }

  /// Repairs data written by older versions. Returns true if anything changed.
  bool _migrate() {
    var changed = false;
    final now = _now();
    // Older versions did not record when an account was added. Treat it as
    // now, so only alerts from here on are auto-imported into it.
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
      {required String field}) {
    if (json == null) return [];
    try {
      final value = jsonDecode(json);
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
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final writes = <Future<bool>>[
      prefs.setString('accounts', encodeList(accounts, (a) => a.toJson())),
      prefs.setString('entries', encodeList(entries, (e) => e.toJson())),
      prefs.setString('messages', encodeList(messages, (m) => m.toJson())),
      prefs.setString('goals', encodeList(goals, (g) => g.toJson())),
      prefs.setString('bills', encodeList(bills, (b) => b.toJson())),
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

  int balanceFor(String accountId) {
    var total = accounts
        .where((account) => account.id == accountId)
        .fold<int>(0, (sum, account) => sum + account.openingBalance);
    for (final entry
        in entries.where((entry) => entry.accountId == accountId)) {
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
    final difference = balance - balanceFor(accountId);
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
        date: _now(),
      ),
    ];
    await _changed();
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

    for (final sms in incoming) {
      final parsed = SmsParser.parse(sms.sender, sms.body);
      if (parsed == null) {
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
      final account = _accountForSms(candidate);
      if (autoImport &&
          bankSmsAutomationEnabled &&
          account != null &&
          _canAutoImport(candidate, account)) {
        if (_confirmSms(candidate.id, accountId: account.id, clearBody: true)) {
          imported++;
        } else {
          duplicates++;
        }
      } else {
        pending++;
      }
    }

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

  /// Clear alerts are added without review only if they arrived after the
  /// account was added and after tracking was turned on. Anything older is
  /// probably already part of the opening balance or entered by hand.
  bool _canAutoImport(PendingSms message, Account account) {
    if (message.confidence == SmsConfidence.low ||
        message.direction == SmsDirection.unknown) {
      return false;
    }
    final createdAt = account.createdAt;
    final enabledAt = smsAutomationEnabledAt;
    if (createdAt == null || enabledAt == null) return false;
    return !message.receivedAt.isBefore(createdAt) &&
        !message.receivedAt.isBefore(enabledAt);
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
    if (!bankSmsAutomationEnabled) return 0;
    var imported = 0;
    for (final message in messages.toList()) {
      if (!message.automaticallyFetched || message.status != 'pending') {
        continue;
      }
      final account = _accountForSms(message);
      if (account != null &&
          _canAutoImport(message, account) &&
          _confirmSms(message.id, accountId: account.id, clearBody: true)) {
        imported++;
      }
    }
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
    }
    await _changed();
  }

  Future<void> _changed() async {
    await _save();
    notifyListeners();
  }

  // Several IDs are often created within the same microsecond (both legs of a
  // transfer, a batch of SMS), so a counter keeps them unique.
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
}
