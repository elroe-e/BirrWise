import 'domain.dart';

class ParsedSms {
  const ParsedSms({
    required this.institution,
    required this.sender,
    required this.amount,
    required this.direction,
    required this.party,
    required this.reference,
    required this.balanceAfter,
    required this.confidence,
    required this.body,
  });

  final String institution;
  final String sender;
  final int amount;
  final SmsDirection direction;
  final String party;
  final String? reference;
  final int? balanceAfter;
  final SmsConfidence confidence;
  final String body;

  PendingSms toPending({
    String? id,
    DateTime? receivedAt,
    bool automaticallyFetched = false,
    String? sourceFingerprint,
    String? bodyHash,
  }) =>
      PendingSms(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        sender: sender,
        institution: institution,
        body: body,
        amount: amount,
        direction: direction,
        party: party,
        reference: reference,
        balanceAfter: balanceAfter,
        receivedAt: receivedAt ?? DateTime.now(),
        confidence: confidence,
        automaticallyFetched: automaticallyFetched,
        sourceFingerprint: sourceFingerprint,
        bodyHash: bodyHash,
      );
}

class SmsParser {
  // Keep in sync with BankSmsInbox.trustedSenders on the Android side.
  // Wallets are separate from their bank: each reports its own balance, and
  // one account per institution is matched to it.
  static const _trustedSenders = <String, Set<String>>{
    'Telebirr': {'127', 'telebirr', 'telebirrsc'},
    'CBE': {'cbe'},
    'CBE Birr': {'cbebirr'},
    'Awash': {'awash', 'awashbank', 'awashbanksc'},
    'Awash Birr': {'awashbirr'},
    'BOA': {'boa', 'abyssinia', 'bankofabyssinia'},
    'Dashen': {'dashen', 'dashenbank'},
    'Amole': {'amole'},
    'M-PESA': {'mpesa'},
    'Coopay': {'coopay', 'ebirr'},
    'Coop Bank': {'coopbank'},
    'Berhan': {'berhan', 'berhanbank'},
    'Bunna': {'bunna', 'bunnabank'},
    'Hibret': {'hibret', 'hibretbank', 'unitedbank'},
    'Ahadu': {'ahadu', 'ahadubank'},
  };

  /// Every bank and wallet whose alerts BirrWise reads.
  static Iterable<String> get institutions => _trustedSenders.keys;

  static const _number = r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';

  // A currency word must not be glued to other letters, so "telebirr 0911…"
  // or "1234 Branch" are never read as money.
  static final _moneyBefore = RegExp(
    '(?<![A-Za-z])(?:ETB|Birr|Br|ብር)\\.?\\s*$_number',
    caseSensitive: false,
  );
  // Amount-after-currency must have two decimals ("2,000.50 Birr") so dates
  // and IDs that happen to sit before a currency word are not misread.
  // Amharic phrasing ("500 ብር") is the exception.
  static final _moneyAfter = RegExp(
    r'(?<![0-9/:.\-])([0-9][0-9,]*\.[0-9]{2})\s*(?:ETB|Birr|Br)(?![A-Za-z])'
    r'|(?<![0-9/:.\-])([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*ብር',
    caseSensitive: false,
  );

  // Drop messages that deliver a code. A "never share your PIN" footer on a
  // real transaction alert must not trigger this.
  static final _codeDelivery = RegExp(
    r'\b(?:otp|one[\s-]?time[\s-]?(?:password|pin|code)|verification\s+code)\b'
    r'|\b(?:pin|password|passcode|security\s+code)\s*(?:is|:)?\s*[0-9]{4,8}\b',
    caseSensitive: false,
  );
  static final _promo = RegExp(
    r'\b(?:promo|promotional|promotion)\b',
    caseSensitive: false,
  );

  static final _income = RegExp(
    r'\b(receiv(?:ed|e)|credit(?:ed)?|deposit(?:ed)?|cash[\s-]*in|top[\s-]*up)\b|ገቢ|ገብቷል|ተቀበሉ|ተቀብለዋል',
    caseSensitive: false,
  );
  static final _expense = RegExp(
    r'\b(paid|debit(?:ed)?|transferred|sent|withdraw(?:n|al)?|purchase|bought|airtime|cash[\s-]*out|bill[\s-]*pay)\b|ወጪ|ተቀንሷል|ወጥቷል|ከፍለዋል|ተከፍሏል|ተላልፏል',
    caseSensitive: false,
  );

  // The label may be followed by "is", ":" or "#" before the value, and the
  // value itself must look like a real reference (6+ characters with a digit).
  // Dart's \b only knows ASCII letters, so the Amharic label sits outside it.
  static final _reference = RegExp(
    r'(?:\b(?:transaction\s*(?:id|number|no\.?|ref(?:erence)?)'
    r'|txn\s*(?:id|no\.?)?'
    r'|trans\.?\s*(?:id|ref(?:erence)?)'
    r'|m-?pesa\s*id'
    r'|ref(?:erence)?\s*(?:id|no\.?|number)?'
    r'|receipt\s*(?:id|no\.?|number)?)(?![A-Za-z])'
    r'|የማጣቀሻ\s*ቁጥር)'
    r'\s*(?:is\s+|[:#\-፡]\s*)?([A-Za-z0-9]{6,})\b',
    caseSensitive: false,
  );
  // CBE debit alerts only carry the FT reference inside the receipt link.
  static final _cbeFt = RegExp(r'\b(FT[0-9][A-Z0-9]{7,})\b');

  static final _party = RegExp(
    r"\b(?:to|from)\s+([A-Za-z][A-Za-z0-9 &'\-]{1,40}?)"
    r'(?=\s*\(|\s+(?:on|at|via|with|using|ref|txn|transaction|for|balance|fee|vat|charge|has|is)\b|[.,;\n]|$)',
    caseSensitive: false,
  );
  static final _notAParty = RegExp(
    r'^(?:your|you|my|the|an?)\b',
    caseSensitive: false,
  );

  /// The bank or wallet a sender ID belongs to, or null if it is not trusted.
  static String? institutionFor(String sender) {
    final normalized = sender.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    for (final entry in _trustedSenders.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  static ParsedSms? parse(String sender, String body) {
    final institution = institutionFor(sender);
    if (institution == null) return null;
    if (_codeDelivery.hasMatch(body)) return null;

    final hasIncome = _income.hasMatch(body);
    final hasExpense = _expense.hasMatch(body);
    if (!hasIncome && !hasExpense && _promo.hasMatch(body)) return null;

    final values = <({int amount, String label, int start})>[];
    for (final pattern in [_moneyBefore, _moneyAfter]) {
      for (final match in pattern.allMatches(body)) {
        final groupIndex = match.group(1) != null ? 1 : 2;
        final rawAmount = match.group(groupIndex);
        if (rawAmount == null) continue;
        final amount = parseEtbToSantim(rawAmount);
        if (amount == null) continue;
        final prefix = body.substring(0, match.start).toLowerCase();
        final label =
            prefix.substring(prefix.length > 45 ? prefix.length - 45 : 0);
        values.add((
          amount: amount,
          label: label,
          start: match.start + match.group(0)!.indexOf(rawAmount),
        ));
      }
    }
    values.sort((a, b) => a.start.compareTo(b.start));
    final unique = <({int amount, String label, int start})>[];
    for (final value in values) {
      if (!unique.any((item) => item.start == value.start)) unique.add(value);
    }

    // ቀሪ ("remaining"), not ሒሳብ: "ሒሳብ ቁጥር" is the account number label.
    bool isBalance(String label) =>
        RegExp(r'\b(balance|bal|remaining|available)\b|ቀሪ').hasMatch(label);
    bool isFee(String label) =>
        RegExp(r'\b(charge|fee|vat|tax|commission|limit)\b').hasMatch(label);
    final balance = unique.where((item) => isBalance(item.label)).lastOrNull;
    final amountCandidate = unique
        .where((item) => !isBalance(item.label) && !isFee(item.label))
        .firstOrNull;
    if (amountCandidate == null) return null;

    final direction = hasIncome == hasExpense
        ? SmsDirection.unknown
        : hasIncome
            ? SmsDirection.income
            : SmsDirection.expense;

    final reference = _findReference(body);
    final party = _findParty(body);
    final confidence = direction == SmsDirection.unknown
        ? SmsConfidence.low
        : reference == null
            ? SmsConfidence.medium
            : SmsConfidence.high;

    return ParsedSms(
      institution: institution,
      sender: sender,
      amount: amountCandidate.amount,
      direction: direction,
      party: party ?? institution,
      reference: reference,
      balanceAfter: balance?.amount,
      confidence: confidence,
      body: body,
    );
  }

  static String? _findReference(String body) {
    for (final match in _reference.allMatches(body)) {
      final value = match.group(1)!;
      if (value.contains(RegExp('[0-9]'))) return value.toUpperCase();
    }
    return _cbeFt.firstMatch(body)?.group(1);
  }

  static String? _findParty(String body) {
    for (final match in _party.allMatches(body)) {
      final value = match.group(1)!.trim();
      if (value.isNotEmpty && !_notAParty.hasMatch(value)) return value;
    }
    return null;
  }
}
