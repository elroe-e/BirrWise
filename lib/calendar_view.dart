import 'package:flutter/material.dart';

import 'app_state.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

typedef CalendarDay = ({DateTime day, int income, int expense});

/// Income and spending for each day from [start] (inclusive) to [end]
/// (exclusive), counted the way the monthly totals are.
List<CalendarDay> calendarDays(
    List<FinanceEntry> entries, DateTime start, DateTime end) {
  final days = <DateTime>[
    for (var d = start; d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1))
      d,
  ];
  final income = <DateTime, int>{};
  final expense = <DateTime, int>{};
  for (final e in entries) {
    if (e.date.isBefore(start) || !e.date.isBefore(end)) continue;
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    if (e.type == EntryType.income) income[day] = (income[day] ?? 0) + e.amount;
    if (e.type == EntryType.expense) {
      expense[day] = (expense[day] ?? 0) + e.amount;
    }
  }
  return [
    for (final d in days) (day: d, income: income[d] ?? 0, expense: expense[d] ?? 0)
  ];
}

/// Whole birr, shortened to fit a calendar cell: 850, 1.2k, 3.4M.
String compactEtb(int santim) {
  final birr = santim / 100;
  String short(double value, String unit) =>
      '${value >= 10 ? value.round() : (value * 10).round() / 10}$unit'
          .replaceAll('.0$unit', unit);
  if (birr >= 1000000) return short(birr / 1000000, 'M');
  if (birr >= 1000) return short(birr / 1000, 'k');
  return birr.round().toString();
}

/// A month grid of money in and out per day, in the calendar chosen in
/// Settings. Tapping a day lists its transactions.
class CalendarView extends StatefulWidget {
  const CalendarView({required this.state, super.key});

  final AppState state;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  int monthsAgo = 0;
  DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final lang = state.language;
    final theme = Theme.of(context);
    final bounds = state.monthBounds(monthsAgo);
    final days = calendarDays(state.entries, bounds.start, bounds.end);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosen = selected != null &&
            !selected!.isBefore(bounds.start) &&
            selected!.isBefore(bounds.end)
        ? selected
        : (monthsAgo == 0 ? today : null);
    final weekdays = lang == 'am'
        ? const ['ሰ', 'ማ', 'ረ', 'ሐ', 'ዓ', 'ቅ', 'እ']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final leading = bounds.start.weekday - 1;
    final dayEntries = chosen == null
        ? const <FinanceEntry>[]
        : (state.entries
              .where((e) =>
                  e.date.year == chosen.year &&
                  e.date.month == chosen.month &&
                  e.date.day == chosen.day)
              .toList()
          ..sort((a, b) => b.date.compareTo(a.date)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: t(lang, 'previousMonth'),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => monthsAgo++),
            ),
            Expanded(
              child: Text(
                monthLabel(bounds.start,
                    ethiopian: state.useEthiopianCalendar, language: lang),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: t(lang, 'nextMonth'),
              icon: const Icon(Icons.chevron_right),
              onPressed:
                  monthsAgo == 0 ? null : () => setState(() => monthsAgo--),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(w,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: .72,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (final d in days)
              _DayCell(
                label: state.useEthiopianCalendar
                    ? '${toEthiopianDate(d.day).day}'
                    : '${d.day.day}',
                day: d,
                hidden: state.hideBalances,
                isToday: d.day == today,
                isSelected: d.day == chosen,
                semantics: dateLabel(d.day,
                    ethiopian: state.useEthiopianCalendar, language: lang),
                onTap: () => setState(() => selected = d.day),
              ),
          ],
        ),
        if (chosen != null) ...[
          const Divider(height: 24),
          Text(
            dateLabel(chosen,
                ethiopian: state.useEthiopianCalendar, language: lang),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (dayEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t(lang, 'noEntriesDay'),
                  style: theme.textTheme.bodySmall),
            )
          else
            for (final e in dayEntries) TransactionRow(entry: e, state: state),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.day,
    required this.hidden,
    required this.isToday,
    required this.isSelected,
    required this.semantics,
    required this.onTap,
  });

  final String label;
  final CalendarDay day;
  final bool hidden;
  final bool isToday;
  final bool isSelected;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final incomeColor = dark ? BirrColors.incomeOnDark : BirrColors.income;
    final expenseColor = dark ? BirrColors.expenseOnDark : BirrColors.expense;
    final small = theme.textTheme.labelSmall?.copyWith(fontSize: 10, height: 1.2);
    Widget amount(int value, Color color, String sign) => hidden
        ? Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        : Text('$sign${compactEtb(value)}',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: small?.copyWith(color: color));
    return Semantics(
      button: true,
      selected: isSelected,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? theme.colorScheme.primaryContainer : null,
            border: isToday && !isSelected
                ? Border.all(color: theme.colorScheme.primary)
                : null,
          ),
          padding: const EdgeInsets.only(top: 4),
          alignment: Alignment.topCenter,
          // Large system text shrinks to fit instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                if (day.income > 0) amount(day.income, incomeColor, '+'),
                if (day.expense > 0) amount(day.expense, expenseColor, '−'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
