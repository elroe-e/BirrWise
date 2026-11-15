import 'domain.dart';
import 'sms_parser.dart';

/// What BirrWise could read from a receipt. Anything may be missing; the
/// person checks it all before saving.
class ReceiptFields {
  const ReceiptFields({
    this.amount,
    this.direction = SmsDirection.unknown,
    this.party,
    this.date,
    this.reference,
  });

  final int? amount;
  final SmsDirection direction;
  final String? party;
  final DateTime? date;
  final String? reference;
}

/// Reads the text of a scanned receipt or transaction screenshot.
ReceiptFields readReceipt(String text, {DateTime? now}) {
  // "500.00 (ETB)" becomes "500.00 ETB", the way the SMS rules read money.
  final clean = text.replaceAllMapped(
      RegExp(r'\(\s*(ETB|Birr|Br)\s*\)', caseSensitive: false),
      (m) => ' ${m[1]}');
  // A failed or declined transaction moved no money.
  if (SmsParser.movesNoMoney(clean)) return const ReceiptFields();
  final parsed = SmsParser.parseText(clean);
  final party = _labelled(_partyLabel, clean) ??
      ((parsed?.party.isNotEmpty ?? false) ? parsed!.party : null);
  final labelledAmount = _labelled(_amountLabel, clean);
  return ReceiptFields(
    amount: parsed?.amount ??
        (labelledAmount == null ? null : parseEtbToSantim(labelledAmount)),
    direction: parsed?.direction ?? SmsDirection.unknown,
    party: party,
    date: _date(clean, now ?? DateTime.now()),
    reference: parsed?.reference ?? SmsParser.findReference(clean),
  );
}

final _partyLabel = RegExp(
  r'^[ \t]*(?:receiver|recipient|beneficiary|credited\s+party|merchant|paid\s+to'
  r'|transaction\s+to|transferred\s+to|to)(?:\s+name)?[ \t]*[:\-][ \t]*'
  r"([A-Za-zሀ-፿][A-Za-zሀ-፿0-9 &'.\-]{1,39})[ \t]*$",
  caseSensitive: false,
  multiLine: true,
);

final _amountLabel = RegExp(
  r'(?:total\s+paid\s+amount|paid\s+amount|settled\s+amount|transferred\s+amount'
  r'|total\s+amount|amount|total|ጠቅላላ|መጠን)[ \t]*(?:\((?:ETB|Birr)\))?[ \t]*[:\-]?'
  r'[ \t]*(?:ETB|Birr|Br)?\.?[ \t]*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
  caseSensitive: false,
);

String? _labelled(RegExp label, String text) =>
    label.firstMatch(text)?.group(1)?.trim();

const _months = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun',
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

/// The receipt's date. Day-first and month-first dates are both used, so an
/// ambiguous one takes the reading closest to today that is not in the future.
DateTime? _date(String text, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime? valid(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    if (date.month != month || date.isAfter(today)) return null;
    return date;
  }

  final month = _months.join('|');
  final patterns = <RegExp, List<DateTime?> Function(Match)>{
    RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b'): (m) =>
        [valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!))],
    RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b'): (m) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
      return [valid(y, b, a), valid(y, a, b)];
    },
    RegExp('\\b(\\d{1,2})[\\s-]+($month)[a-z]*\\.?[\\s,-]+(\\d{4})\\b',
        caseSensitive: false): (m) => [
          valid(int.parse(m[3]!), _months.indexOf(m[2]!.toLowerCase()) + 1,
              int.parse(m[1]!))
        ],
    RegExp('\\b($month)[a-z]*\\.?\\s+(\\d{1,2}),?\\s+(\\d{4})\\b',
        caseSensitive: false): (m) => [
          valid(int.parse(m[3]!), _months.indexOf(m[1]!.toLowerCase()) + 1,
              int.parse(m[2]!))
        ],
  };
  // The first date in the receipt, in whichever format it is written.
  ({int at, DateTime date})? best;
  patterns.forEach((pattern, read) {
    for (final match in pattern.allMatches(text)) {
      final dates = read(match).whereType<DateTime>().toList()
        ..sort((x, y) => y.compareTo(x));
      if (dates.isEmpty) continue;
      if (best == null || match.start < best!.at) {
        best = (at: match.start, date: dates.first);
      }
      break;
    }
  });
  final date = best?.date;
  if (date == null) return null;
  return date == today ? now : DateTime(date.year, date.month, date.day, 12);
}
