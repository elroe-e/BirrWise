import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'dialogs.dart';
import 'domain.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

/// Monthly targets and per-category limits. Spending is always worked out
/// from this month's ledger, never stored.
class BudgetView extends StatelessWidget {
  const BudgetView({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final spent = state.monthExpensesByCategory();
    final hidden = state.hideBalances;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      children: [
        SectionHeading(
          t(lang, 'monthlyTarget'),
          action: t(lang, 'edit'),
          onAction: () => _editTargets(context),
        ),
        const SizedBox(height: 12),
        BirrCard(
          padding: const EdgeInsets.all(17),
          child: Column(
            children: [
              _ProgressLine(
                label: t(lang, 'targetIncome'),
                value: state.monthIncome,
                limit: state.incomeTarget,
                hidden: hidden,
                goodWhenFull: true,
              ),
              const SizedBox(height: 14),
              _ProgressLine(
                label: t(lang, 'plannedSpending'),
                value: state.monthExpenses,
                limit: state.plannedSpending,
                hidden: hidden,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionHeading(
          t(lang, 'categoryBudgets'),
          action: t(lang, 'add'),
          onAction: () => _editBudget(context, null),
        ),
        const SizedBox(height: 12),
        if (state.budgets.isEmpty)
          Text(t(lang, 'noBudgets'),
              style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final MapEntry(key: category, value: limit)
              in state.budgets.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BirrCard(
                onTap: () => _editBudget(context, category),
                padding: const EdgeInsets.all(15),
                child: _ProgressLine(
                  icon: categoryIcon(category),
                  label: t(lang, category),
                  value: spent[category] ?? 0,
                  limit: limit,
                  hidden: hidden,
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _editTargets(BuildContext context) async {
    final lang = state.language;
    final values = await _amountSheet(
      context,
      title: t(lang, 'monthlyTarget'),
      fields: [
        (t(lang, 'targetIncome'), state.incomeTarget),
        (t(lang, 'plannedSpending'), state.plannedSpending),
      ],
      language: lang,
    );
    if (values == null) return;
    await state.setMonthlyTargets(income: values[0], spending: values[1]);
  }

  Future<void> _editBudget(BuildContext context, String? existing) async {
    final lang = state.language;
    var category = existing ??
        financeCategories.keys.firstWhere(
          (key) => !state.budgets.containsKey(key),
          orElse: () => 'other',
        );
    final values = await _amountSheet(
      context,
      title: t(lang, 'setBudget'),
      fields: [(t(lang, 'monthlyLimit'), state.budgets[category] ?? 0)],
      language: lang,
      header: existing != null
          ? null
          : StatefulBuilder(
              builder: (context, setHeaderState) =>
                  DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: t(lang, 'category')),
                items: financeCategories.keys
                    .map((key) =>
                        DropdownMenuItem(value: key, child: Text(t(lang, key))))
                    .toList(),
                onChanged: (value) =>
                    setHeaderState(() => category = value ?? category),
              ),
            ),
      removable: existing != null,
    );
    if (values == null) return;
    await state.setBudget(category, values[0]);
  }
}

/// People you lent money to or borrowed from.
class LoansView extends StatelessWidget {
  const LoansView({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final hidden = state.hideBalances;
    final active = state.loans.where((loan) => !loan.settled).toList();
    final settled = state.loans.where((loan) => loan.settled).toList();
    int owed(bool lent) => active
        .where((loan) => loan.lent == lent)
        .fold(0, (sum, loan) => sum + loan.remaining);
    if (state.loans.isEmpty) {
      return EmptyState(
        title: t(lang, 'loans'),
        message: t(lang, 'loansHint'),
        action: t(lang, 'addLoan'),
        onAction: () => _addLoan(context),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      children: [
        SectionHeading(
          t(lang, 'loans'),
          action: t(lang, 'add'),
          onAction: () => _addLoan(context),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Total(
                label: t(lang, 'owedToYou'),
                amount: formatEtb(owed(true), hidden: hidden),
                color: BirrColors.income,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Total(
                label: t(lang, 'youOwe'),
                amount: formatEtb(owed(false), hidden: hidden),
                color: BirrColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final loan in [...active, ...settled])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BirrCard(
              padding: const EdgeInsets.fromLTRB(15, 12, 6, 12),
              child: Row(
                children: [
                  Icon(
                    loan.lent
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded,
                    color: loan.lent ? BirrColors.income : BirrColors.expense,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loan.person,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          loan.settled
                              ? t(lang, 'settled')
                              : '${t(lang, loan.lent ? 'lent' : 'borrowed')} · '
                                  '${formatEtb(loan.remaining, hidden: hidden)} '
                                  '${t(lang, 'left')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => switch (value) {
                      'pay' => _recordPayment(context, loan),
                      'settle' =>
                        state.recordLoanPayment(loan.id, loan.remaining),
                      _ => state.removeLoan(loan.id),
                    },
                    itemBuilder: (context) => [
                      if (!loan.settled) ...[
                        PopupMenuItem(
                            value: 'pay', child: Text(t(lang, 'recordPayment'))),
                        PopupMenuItem(
                            value: 'settle', child: Text(t(lang, 'markSettled'))),
                      ],
                      PopupMenuItem(value: 'delete', child: Text(t(lang, 'delete'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addLoan(BuildContext context) async {
    final lang = state.language;
    final person = TextEditingController();
    var lent = true;
    final values = await _amountSheet(
      context,
      title: t(lang, 'addLoan'),
      fields: [(t(lang, 'amountLabel'), 0)],
      language: lang,
      header: StatefulBuilder(
        builder: (context, setHeaderState) => Column(
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(t(lang, 'lent'))),
                ButtonSegment(value: false, label: Text(t(lang, 'borrowed'))),
              ],
              selected: {lent},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setHeaderState(() => lent = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: person,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: t(lang, 'personName')),
            ),
          ],
        ),
      ),
      validate: (values) => person.text.trim().isEmpty || values[0] <= 0
          ? t(lang, 'loanInvalid')
          : null,
    );
    final name = person.text;
    person.dispose();
    if (values == null) return;
    await state.addLoan(person: name, lent: lent, amount: values[0]);
    unawaited(confirmFeedback(state));
  }

  Future<void> _recordPayment(BuildContext context, Loan loan) async {
    final values = await _amountSheet(
      context,
      title: '${t(state.language, 'recordPayment')} · ${loan.person}',
      fields: [(t(state.language, 'amountLabel'), loan.remaining)],
      language: state.language,
      validate: (values) =>
          values[0] <= 0 ? t(state.language, 'invalidAmount') : null,
    );
    if (values == null) return;
    await state.recordLoanPayment(loan.id, values[0]);
    unawaited(confirmFeedback(state));
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.amount, required this.color});

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => BirrCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              amount,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontFamily: 'serif'),
            ),
          ],
        ),
      );
}

/// "spent / limit" with a bar. Over the limit turns red, unless reaching the
/// limit is the point (an income target).
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.limit,
    required this.hidden,
    this.icon,
    this.goodWhenFull = false,
  });

  final String label;
  final int value;
  final int limit;
  final bool hidden;
  final IconData? icon;
  final bool goodWhenFull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = !goodWhenFull && limit > 0 && value > limit;
    final progress = limit <= 0 ? 0.0 : (value / limit).clamp(0.0, 1.0);
    final color = over
        ? BirrColors.expense
        : goodWhenFull
            ? BirrColors.income
            : theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              limit <= 0
                  ? formatEtb(value, hidden: hidden)
                  : '${formatEtb(value, hidden: hidden)} / '
                      '${formatEtb(limit, withCode: false, hidden: hidden)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: over ? BirrColors.expense : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            semanticsLabel: label,
          ),
        ),
      ],
    );
  }
}

/// A bottom sheet with one or more ETB amount fields. Returns the amounts in
/// santim, or null if cancelled. A removable sheet can return 0 to delete.
Future<List<int>?> _amountSheet(
  BuildContext context, {
  required String title,
  required List<(String, int)> fields,
  required String language,
  Widget? header,
  bool removable = false,
  String? Function(List<int> values)? validate,
}) async {
  final controllers = [
    for (final (_, value) in fields)
      TextEditingController(
        text: value <= 0 ? '' : formatEtb(value, withCode: false).replaceAll(',', ''),
      ),
  ];
  String? error;
  final result = await showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (header != null) ...[header, const SizedBox(height: 14)],
              for (final (index, (label, _)) in fields.indexed) ...[
                TextField(
                  controller: controllers[index],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: label,
                    prefixText: 'ETB  ',
                    errorText: index == fields.length - 1 ? error : null,
                  ),
                  onChanged: (_) => setSheetState(() => error = null),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (removable)
                    TextButton(
                      onPressed: () => Navigator.pop(context, [0]),
                      child: Text(t(language, 'remove')),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final values = [
                        for (final controller in controllers)
                          controller.text.trim().isEmpty
                              ? 0
                              : parseEtbToSantim(controller.text) ?? -1,
                      ];
                      final problem = values.any((v) => v < 0)
                          ? t(language, 'invalidAmount')
                          : validate?.call(values);
                      if (problem != null) {
                        setSheetState(() => error = problem);
                        return;
                      }
                      Navigator.pop(context, values);
                    },
                    child: Text(t(language, 'save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  for (final controller in controllers) {
    controller.dispose();
  }
  return result;
}
