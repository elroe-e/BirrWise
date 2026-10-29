import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'budget_loans.dart';
import 'dialogs.dart';
import 'domain.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    required this.state,
    this.initialSegment = 0,
    super.key,
  });

  final AppState state;
  final int initialSegment;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late int selected = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final lang = state.language;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(t(lang, 'goals'))),
              ButtonSegment(value: 1, label: Text(t(lang, 'bills'))),
              ButtonSegment(value: 2, label: Text(t(lang, 'budget'))),
              ButtonSegment(value: 3, label: Text(t(lang, 'loans'))),
            ],
            selected: {selected},
            onSelectionChanged: (value) =>
                setState(() => selected = value.first),
            showSelectedIcon: false,
          ),
        ),
        Expanded(
          child: switch (selected) {
            0 => _goals(context, state),
            1 => _bills(context, state),
            2 => BudgetView(state: state),
            _ => LoansView(state: state),
          },
        ),
      ],
    );
  }

  Widget _goals(BuildContext context, AppState state) {
    final goals = state.goals;
    return goals.isEmpty
        ? EmptyState(
            title: t(state.language, 'noGoals'),
            message: t(state.language, 'notEnoughHint'),
            action: t(state.language, 'addGoal'),
            onAction: () => showAddGoalDialog(context, state),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
            children: [
              SectionHeading(
                t(state.language, 'goals'),
                action: t(state.language, 'add'),
                onAction: () => showAddGoalDialog(context, state),
              ),
              const SizedBox(height: 12),
              ...goals.map((goal) {
                final saved = state.savedForGoal(goal.id);
                final progress =
                    (saved / goal.target).clamp(0.0, 1.0).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BirrCard(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _ProgressRing(
                              value: progress,
                              label: '${(progress * 100).round()}%',
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(goal.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${formatEtb(saved, hidden: state.hideBalances)} / ${formatEtb(goal.target, hidden: state.hideBalances)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    saved == 0
                                        ? (state.language == 'am'
                                            ? 'በትንሽ ቁጠባ ይጀምሩ'
                                            : 'Start with a small deposit')
                                        : saved >= goal.target
                                            ? (state.language == 'am'
                                                ? 'ግቡ ተሳክቷል!'
                                                : 'Goal reached — well done!')
                                            : (state.language == 'am'
                                                ? '${formatEtb(goal.target - saved, hidden: state.hideBalances)} ቀርቷል'
                                                : '${formatEtb(goal.target - saved, hidden: state.hideBalances)} to go'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        _Milestones(progress: progress),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _deposit(context, state, goal),
                            icon: const Icon(Icons.add),
                            label: Text(t(state.language, 'deposit')),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
  }

  Widget _bills(BuildContext context, AppState state) {
    final bills = [...state.bills.where((bill) => bill.active)]
      ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
    if (bills.isEmpty) {
      return EmptyState(
        title: t(state.language, 'noBills'),
        message: t(state.language, 'notEnoughHint'),
        action: t(state.language, 'addBill'),
        onAction: () => showAddBillDialog(context, state),
      );
    }
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final paid = bills.where((b) => b.lastPaidPeriod == period).toList();
    final unpaid = bills.where((b) => b.lastPaidPeriod != period).toList();
    final overdue = unpaid.where((b) => b.dueDay < now.day).toList();
    final dueSoon = unpaid
        .where((b) => b.dueDay >= now.day && b.dueDay <= now.day + 7)
        .toList();
    final upcoming = unpaid.where((b) => b.dueDay > now.day + 7).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      children: [
        SectionHeading(
          t(state.language, 'bills'),
          action: t(state.language, 'add'),
          onAction: () => showAddBillDialog(context, state),
        ),
        if (overdue.isNotEmpty) ...[
          _BillGroupTitle(
            state.language == 'am' ? 'ያለፈባቸው' : 'Overdue',
            color: BirrColors.expense,
          ),
          ...overdue.map((b) => _BillRow(bill: b, state: state)),
        ],
        if (dueSoon.isNotEmpty) ...[
          _BillGroupTitle(
            state.language == 'am' ? 'በቅርቡ' : 'Due soon',
            color: BirrColors.goldDeep,
          ),
          ...dueSoon.map((b) => _BillRow(bill: b, state: state)),
        ],
        if (upcoming.isNotEmpty) ...[
          _BillGroupTitle(
            state.language == 'am' ? 'የሚቀጥሉ' : 'Upcoming',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          ...upcoming.map((b) => _BillRow(bill: b, state: state)),
        ],
        if (paid.isNotEmpty) ...[
          _BillGroupTitle(t(state.language, 'paid')),
          ...paid.map((b) => _BillRow(bill: b, state: state)),
        ],
      ],
    );
  }

  Future<void> _deposit(
      BuildContext context, AppState state, SavingsGoal goal) async {
    final active = state.accounts.where((a) => !a.archived).toList();
    if (active.isEmpty) {
      await showAddAccountDialog(context, state);
      return;
    }
    var accountId = active.first.id;
    final amountController = TextEditingController(text: '1000');
    var selected = 1000;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t(state.language, 'deposit')} · ${goal.title}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                children: [500, 1000, 5000].map((value) {
                  return ChoiceChip(
                    label:
                        Text('ETB ${formatEtb(value * 100, withCode: false)}'),
                    selected: selected == value,
                    onSelected: (_) {
                      setModalState(() {
                        selected = value;
                        amountController.text = '$value';
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t(state.language, 'amount'),
                  prefixText: 'ETB  ',
                  errorText: error,
                ),
                onChanged: (_) => setModalState(() {
                  selected = -1;
                  error = null;
                }),
              ),
              const SizedBox(height: 14),
              Text(t(state.language, 'fromAccount'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final account in active)
                    ChoiceChip(
                      label: Text(account.name),
                      selected: account.id == accountId,
                      onSelected: (_) =>
                          setModalState(() => accountId = account.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amount = parseEtbToSantim(amountController.text);
                    if (amount == null || amount <= 0) {
                      setModalState(
                          () => error = t(state.language, 'invalidAmount'));
                      return;
                    }
                    await state.depositToGoal(goal.id, accountId, amount);
                    unawaited(confirmFeedback(state, 'goal'));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(t(state.language, 'deposit')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    amountController.dispose();
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        height: 72,
        child: CustomPaint(
          painter: _RingPainter(
            progress: value,
            background: Theme.of(context).colorScheme.surfaceContainerHighest,
            foreground: Theme.of(context).colorScheme.primary,
          ),
          child: Center(
            child: Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: 'serif',
                      fontSize: 14,
                    )),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.background,
    required this.foreground,
  });

  final double progress;
  final Color background;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 5);
    final track = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final active = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, active);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.background != background ||
      oldDelegate.foreground != foreground;
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final milestone in [.25, .5, .75, 1.0])
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: progress >= milestone
                          ? BirrColors.goldDecor
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: progress >= milestone
                          ? BirrColors.goldDecor
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}

class _BillGroupTitle extends StatelessWidget {
  const _BillGroupTitle(this.title, {this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color)),
      );
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.state});

  final Bill bill;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final period =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final paid = bill.lastPaidPeriod == period;
    final overdue = !paid && bill.dueDay < DateTime.now().day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: BirrCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${formatEtb(bill.amount, hidden: state.hideBalances)} · ${t(state.language, 'due')} ${bill.dueDay}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (paid)
              OutlinedButton(
                onPressed: () => state.undoBillPayment(bill),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(t(state.language, 'undo')),
              )
            else
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    await state.payBill(bill);
                  } on StateError {
                    if (context.mounted) showAddAccountDialog(context, state);
                  }
                },
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(overdue
                    ? (state.language == 'am' ? 'ክፈል' : 'Pay')
                    : t(state.language, 'markPaid')),
              ),
          ],
        ),
      ),
    );
  }
}
