import 'app_state.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'strings.dart';

/// The lines of a monthly report, in order. Android draws them into a PDF
/// (PdfReport.kt). Kinds: 'title', 'sub', 'h' (heading) and 'text' carry
/// 't'; 'row' carries 'c' (2 to 4 cells, the last one right-aligned) and
/// 'b' for a bold header row.
List<Map<String, Object>> reportBlocks(AppState state, int monthsAgo,
    {DateTime? createdAt}) {
  final lang = state.language;
  final ethiopian = state.useEthiopianCalendar;
  final bounds = state.monthBounds(monthsAgo);
  String date(DateTime d) => dateLabel(d, ethiopian: ethiopian, language: lang);
  Map<String, Object> row(List<String> cells, {bool bold = false}) =>
      {'k': 'row', 'c': cells, 'b': bold};

  final income = state.monthTotal(EntryType.income, monthsAgo);
  final expenses = state.monthTotal(EntryType.expense, monthsAgo);
  final categories = state.monthExpensesByCategory(monthsAgo).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final entries = state.entries
      .where((e) => !e.date.isBefore(bounds.start) && e.date.isBefore(bounds.end))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  // Balances as they stood when the month ended, or today for this month.
  final balancesAt = monthsAgo == 0
      ? null
      : bounds.end.subtract(const Duration(microseconds: 1));
  final accounts = state.accounts.where((a) => !a.archived).toList();
  String accountName(String id) =>
      state.accounts.where((a) => a.id == id).firstOrNull?.name ?? '';

  return [
    {'k': 'title', 't': t(lang, 'reportTitle')},
    {
      'k': 'sub',
      't': '${monthLabel(bounds.start, ethiopian: ethiopian, language: lang)}'
          ' · ${tf(lang, 'reportCreated', {'date': date(createdAt ?? DateTime.now())})}',
    },
    {'k': 'h', 't': t(lang, 'summary')},
    row([t(lang, 'income'), formatEtb(income)]),
    row([t(lang, 'expenses'), formatEtb(expenses)]),
    row([t(lang, 'net'), formatEtb(income - expenses)], bold: true),
    if (categories.isNotEmpty) ...[
      {'k': 'h', 't': t(lang, 'byCategory')},
      for (final c in categories)
        row([
          t(lang, c.key),
          '${(c.value * 100 / expenses).round()}%',
          formatEtb(c.value),
        ]),
    ],
    if (accounts.isNotEmpty) ...[
      {
        'k': 'h',
        't': tf(lang, 'balancesOn', {
          'date': date(balancesAt ?? createdAt ?? DateTime.now()),
        }),
      },
      for (final a in accounts)
        row([a.name, formatEtb(state.balanceFor(a.id, at: balancesAt))]),
    ],
    {'k': 'h', 't': t(lang, 'transactions')},
    if (entries.isEmpty)
      {'k': 'text', 't': t(lang, 'noTransactionsMonth')}
    else ...[
      row([
        t(lang, 'date'),
        t(lang, 'description'),
        t(lang, 'category'),
        t(lang, 'amount'),
      ], bold: true),
      for (final e in entries)
        row([
          date(e.date),
          [
            if (e.party.isNotEmpty) e.party,
            accountName(e.accountId),
          ].where((part) => part.isNotEmpty).join(' · '),
          switch (e.type) {
            EntryType.adjustment => t(lang, 'adjustment'),
            EntryType.transferIn || EntryType.transferOut => t(lang, 'transfer'),
            _ => t(lang, e.category),
          },
          _signed(e),
        ]),
    ],
  ];
}

String _signed(FinanceEntry e) {
  final value = switch (e.type) {
    EntryType.income || EntryType.transferIn || EntryType.adjustment => e.amount,
    _ => -e.amount,
  };
  return value > 0 ? '+${formatEtb(value)}' : formatEtb(value);
}
