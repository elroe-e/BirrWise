import 'dart:convert';

enum EntryType { income, expense, transferOut, transferIn, savings, adjustment }

enum EntrySource { manual, sms, bill, goal }

enum SmsDirection { income, expense, unknown }

enum SmsConfidence { high, medium, low }

class BankSms {
  const BankSms({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;
}

class SmsIngestSummary {
  const SmsIngestSummary({
    required this.scanned,
    required this.recognized,
    required this.imported,
    required this.pending,
    required this.ignored,
    required this.duplicates,
  });

  final int scanned;
  final int recognized;
  final int imported;
  final int pending;
  final int ignored;
  final int duplicates;
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.institution,
    required this.openingBalance,
    this.maskedNumber = '',
    this.archived = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String institution;
  final int openingBalance;
  final String maskedNumber;
  final bool archived;

  /// When the opening balance was recorded. Bank alerts received before this
  /// are already part of the opening balance, so they are never auto-imported.
  /// Null only for data saved by older versions, before migration on load.
  final DateTime? createdAt;

  Account copyWith({bool? archived, DateTime? createdAt}) => Account(
        id: id,
        name: name,
        institution: institution,
        openingBalance: openingBalance,
        maskedNumber: maskedNumber,
        archived: archived ?? this.archived,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'institution': institution,
        'openingBalance': openingBalance,
        'maskedNumber': maskedNumber,
        'archived': archived,
        'createdAt': createdAt?.millisecondsSinceEpoch,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        institution: json['institution'] as String? ?? 'Cash',
        openingBalance: json['openingBalance'] as int? ?? 0,
        maskedNumber: json['maskedNumber'] as String? ?? '',
        archived: json['archived'] as bool? ?? false,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );
}

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.category,
    required this.party,
    required this.note,
    required this.date,
    this.source = EntrySource.manual,
    this.institution,
    this.smsReference,
    this.goalId,
    this.transferGroupId,
    this.business = false,
  });

  final String id;
  final String accountId;
  final EntryType type;
  final int amount;
  final String category;
  final String party;
  final String note;
  final DateTime date;
  final EntrySource source;
  final String? institution;
  final String? smsReference;
  final String? goalId;
  final String? transferGroupId;

  /// Tagged as shop or business money while merchant mode is on.
  final bool business;

  FinanceEntry withId(String newId) => FinanceEntry(
        id: newId,
        accountId: accountId,
        type: type,
        amount: amount,
        category: category,
        party: party,
        note: note,
        date: date,
        source: source,
        institution: institution,
        smsReference: smsReference,
        goalId: goalId,
        transferGroupId: transferGroupId,
        business: business,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'accountId': accountId,
        'type': type.name,
        'amount': amount,
        'category': category,
        'party': party,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'source': source.name,
        'institution': institution,
        'smsReference': smsReference,
        'goalId': goalId,
        'transferGroupId': transferGroupId,
        'business': business,
      };

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        type: EntryType.values.byName(json['type'] as String),
        amount: json['amount'] as int,
        category: json['category'] as String? ?? 'other',
        party: json['party'] as String? ?? '',
        note: json['note'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
        source:
            EntrySource.values.byName(json['source'] as String? ?? 'manual'),
        institution: json['institution'] as String?,
        smsReference: json['smsReference'] as String?,
        goalId: json['goalId'] as String?,
        transferGroupId: json['transferGroupId'] as String?,
        business: json['business'] as bool? ?? false,
      );
}

/// Money lent to or borrowed from a person. Kept off the ledger: the
/// repayment usually arrives as a bank alert too and would count twice.
class Loan {
  const Loan({
    required this.id,
    required this.person,
    required this.lent,
    required this.amount,
    required this.paid,
    required this.createdAt,
  });

  final String id;
  final String person;

  /// True if the person owes you; false if you owe them.
  final bool lent;
  final int amount;
  final int paid;
  final DateTime createdAt;

  int get remaining => amount - paid;
  bool get settled => paid >= amount;

  Loan withPaid(int value) => Loan(
        id: id,
        person: person,
        lent: lent,
        amount: amount,
        paid: value,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'person': person,
        'lent': lent,
        'amount': amount,
        'paid': paid,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as String,
        person: json['person'] as String,
        lent: json['lent'] as bool,
        amount: json['amount'] as int,
        paid: json['paid'] as int? ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );
}

class PendingSms {
  const PendingSms({
    required this.id,
    required this.sender,
    required this.institution,
    required this.body,
    required this.amount,
    required this.direction,
    required this.party,
    required this.reference,
    required this.balanceAfter,
    required this.receivedAt,
    required this.confidence,
    this.automaticallyFetched = false,
    this.sourceFingerprint,
    this.bodyHash,
    this.status = 'pending',
    this.category = 'other',
  });

  final String id;
  final String sender;
  final String institution;
  final String body;
  final int amount;
  final SmsDirection direction;
  final String party;
  final String? reference;
  final int? balanceAfter;
  final DateTime receivedAt;
  final SmsConfidence confidence;
  final bool automaticallyFetched;
  final String? sourceFingerprint;

  /// Hash of the normalized text. Kept after the body is cleared so the same
  /// alert seen from the inbox and from the live receiver is recognized.
  final String? bodyHash;
  final String status;
  final String category;

  PendingSms copyWith({
    String? institution,
    int? amount,
    SmsDirection? direction,
    String? party,
    String? category,
    String? status,
    String? body,
    bool? automaticallyFetched,
  }) =>
      PendingSms(
        id: id,
        sender: sender,
        institution: institution ?? this.institution,
        body: body ?? this.body,
        amount: amount ?? this.amount,
        direction: direction ?? this.direction,
        party: party ?? this.party,
        reference: reference,
        balanceAfter: balanceAfter,
        receivedAt: receivedAt,
        confidence: confidence,
        automaticallyFetched: automaticallyFetched ?? this.automaticallyFetched,
        sourceFingerprint: sourceFingerprint,
        bodyHash: bodyHash,
        status: status ?? this.status,
        category: category ?? this.category,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sender': sender,
        'institution': institution,
        'body': body,
        'amount': amount,
        'direction': direction.name,
        'party': party,
        'reference': reference,
        'balanceAfter': balanceAfter,
        'receivedAt': receivedAt.millisecondsSinceEpoch,
        'confidence': confidence.name,
        'automaticallyFetched': automaticallyFetched,
        'sourceFingerprint': sourceFingerprint,
        'bodyHash': bodyHash,
        'status': status,
        'category': category,
      };

  factory PendingSms.fromJson(Map<String, dynamic> json) => PendingSms(
        id: json['id'] as String,
        sender: json['sender'] as String,
        institution: json['institution'] as String,
        body: json['body'] as String,
        amount: json['amount'] as int,
        direction: SmsDirection.values.byName(json['direction'] as String),
        party: json['party'] as String? ?? '',
        reference: json['reference'] as String?,
        balanceAfter: json['balanceAfter'] as int?,
        receivedAt:
            DateTime.fromMillisecondsSinceEpoch(json['receivedAt'] as int),
        confidence: SmsConfidence.values.byName(json['confidence'] as String),
        automaticallyFetched: json['automaticallyFetched'] as bool? ?? false,
        sourceFingerprint: json['sourceFingerprint'] as String?,
        bodyHash: json['bodyHash'] as String?,
        status: json['status'] as String? ?? 'pending',
        category: json['category'] as String? ?? 'other',
      );
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.target,
    required this.createdAt,
    this.targetDate,
  });

  final String id;
  final String title;
  final int target;
  final DateTime createdAt;
  final DateTime? targetDate;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'target': target,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'targetDate': targetDate?.millisecondsSinceEpoch,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        target: json['target'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        targetDate: json['targetDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['targetDate'] as int),
      );
}

class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.recurrence,
    required this.dueDay,
    required this.active,
    this.accountId,
    this.lastPaidPeriod,
    this.lastPaymentEntryId,
  });

  final String id;
  final String title;
  final int amount;
  final String recurrence;
  final int dueDay;
  final bool active;
  final String? accountId;
  final String? lastPaidPeriod;
  final String? lastPaymentEntryId;

  Bill copyWith({
    String? lastPaidPeriod,
    String? lastPaymentEntryId,
    bool clearPayment = false,
    bool? active,
  }) =>
      Bill(
        id: id,
        title: title,
        amount: amount,
        recurrence: recurrence,
        dueDay: dueDay,
        active: active ?? this.active,
        accountId: accountId,
        lastPaidPeriod:
            clearPayment ? null : lastPaidPeriod ?? this.lastPaidPeriod,
        lastPaymentEntryId:
            clearPayment ? null : lastPaymentEntryId ?? this.lastPaymentEntryId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'recurrence': recurrence,
        'dueDay': dueDay,
        'active': active,
        'accountId': accountId,
        'lastPaidPeriod': lastPaidPeriod,
        'lastPaymentEntryId': lastPaymentEntryId,
      };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: json['amount'] as int,
        recurrence: json['recurrence'] as String? ?? 'monthly',
        dueDay: json['dueDay'] as int? ?? 1,
        active: json['active'] as bool? ?? true,
        accountId: json['accountId'] as String?,
        lastPaidPeriod: json['lastPaidPeriod'] as String?,
        lastPaymentEntryId: json['lastPaymentEntryId'] as String?,
      );
}

String encodeList<T>(List<T> values, Map<String, Object?> Function(T) encode) =>
    jsonEncode(values.map(encode).toList());

int? parseEtbToSantim(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.tryParse(parts[0]);
  final fraction =
      int.tryParse(parts.length == 1 ? '00' : parts[1].padRight(2, '0'));
  if (whole == null || fraction == null) return null;
  return whole * 100 + fraction;
}

String formatEtb(int santim, {bool hidden = false, bool withCode = true}) {
  if (hidden) return withCode ? 'ETB ••••••' : '••••••';
  final absolute = santim.abs();
  final birr = (absolute ~/ 100).toString();
  final grouped = birr.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final amount = '$grouped.${(absolute % 100).toString().padLeft(2, '0')}';
  final sign = santim < 0 ? '−' : '';
  return withCode ? '${sign}ETB $amount' : '$sign$amount';
}

const financeCategories = <String, String>{
  'food_groceries': 'Food & groceries',
  'transport': 'Transport',
  'utilities': 'Utilities',
  'rent': 'Rent',
  'airtime_data': 'Airtime & data',
  'health': 'Health',
  'education': 'Education',
  'family_support': 'Family support',
  'equb_iddir': 'Equb & Iddir',
  'shopping': 'Shopping',
  'entertainment': 'Entertainment',
  'business': 'Business',
  'salary': 'Salary',
  'gift': 'Gift',
  'other': 'Other',
};
