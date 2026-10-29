import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'health_score.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({
    required this.state,
    required this.onInbox,
    required this.onBills,
    super.key,
  });

  final AppState state;
  final VoidCallback onInbox;
  final VoidCallback onBills;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final theme = Theme.of(context);
    final score = computeHealthScore(state.healthInputs());
    final income = state.monthIncome;
    final expenses = state.monthExpenses;
    final categories = state.monthExpensesByCategory();
    final top = (categories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    final suggestions = recommendations(
      monthIncome: income,
      monthExpenses: expenses,
      expensesByCategory: categories,
      billsDueWithin3Days: state.billsDueWithin3Days,
      pendingSmsOlderThan3Days: state.pendingSmsOlderThan3Days,
    );
    final weakest = score.weakestFactorKey;
    final summary = score.total == null
        ? t(lang, 'scoreNotEnoughHint')
        : weakest == null
            ? t(lang, 'scoreAllStrong')
            : tf(lang, 'scoreWeakest', {'factor': t(lang, weakest)});
    String points(int value, int max) =>
        score.total == null ? '—' : '$value/$max';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BirrColors.forest, BirrColors.forestDark],
            ),
          ),
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              _ScoreGauge(score: score.total),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(lang, 'healthScore'),
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: BirrColors.goldOnDark)),
                    const SizedBox(height: 5),
                    Text(t(lang, score.labelKey),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: BirrColors.heroText)),
                    const SizedBox(height: 5),
                    Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BirrColors.heroText.withValues(alpha: .8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionHeading(t(lang, 'monthlySnapshot')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: t(lang, 'income'),
                value: income,
                color: BirrColors.income,
                hidden: state.hideBalances,
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: t(lang, 'expenses'),
                value: expenses,
                color: BirrColors.expense,
                hidden: state.hideBalances,
                icon: Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeading(t(lang, 'cashFlowTrend')),
        const SizedBox(height: 10),
        BirrCard(child: _CashFlowChart(state: state)),
        const SizedBox(height: 20),
        SectionHeading(t(lang, 'scoreHowMade')),
        const SizedBox(height: 9),
        BirrCard(
          child: Column(
            children: [
              _ScoreFactor(
                title: t(lang, 'factorSavings'),
                value: score.savings / HealthScore.savingsMax,
                points: points(score.savings, HealthScore.savingsMax),
              ),
              const Divider(height: 22),
              _ScoreFactor(
                title: t(lang, 'factorBills'),
                value: score.bills / HealthScore.billsMax,
                points: points(score.bills, HealthScore.billsMax),
              ),
              const Divider(height: 22),
              _ScoreFactor(
                title: t(lang, 'factorEmergency'),
                value: score.emergency / HealthScore.emergencyMax,
                points: points(score.emergency, HealthScore.emergencyMax),
              ),
              const Divider(height: 22),
              _ScoreFactor(
                title: t(lang, 'factorStability'),
                value: score.stability / HealthScore.stabilityMax,
                points: points(score.stability, HealthScore.stabilityMax),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeading(t(lang, 'suggestions')),
        const SizedBox(height: 9),
        if (suggestions.isEmpty)
          _SuggestionCard(
            icon: Icons.check_circle_outline,
            text: t(lang, 'recAllGood'),
          )
        else
          for (final suggestion in suggestions)
            _SuggestionCard(
              icon: switch (suggestion.key) {
                'recBillsSoon' => Icons.event_note_outlined,
                'recOldPending' => Icons.mark_email_unread_outlined,
                'recLowSavings' => Icons.savings_outlined,
                _ => Icons.pie_chart_outline,
              },
              text: tf(lang, suggestion.key, {
                ...suggestion.values,
                if (suggestion.values['category'] case final String key)
                  'category': t(lang, key),
              }),
              actionLabel: switch (suggestion.action) {
                'bills' => t(lang, 'reviewBills'),
                'inbox' => t(lang, 'review'),
                _ => null,
              },
              onAction: switch (suggestion.action) {
                'bills' => onBills,
                'inbox' => onInbox,
                _ => null,
              },
            ),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeading(t(lang, 'whereMoneyWent')),
          const SizedBox(height: 8),
          BirrCard(
            child: Column(
              children: [
                for (final item in top) ...[
                  Row(
                    children: [
                      Icon(categoryIcon(item.key),
                          size: 19, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t(lang, item.key),
                            style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        '${formatEtb(item.value, hidden: state.hideBalances, withCode: false)}'
                        ' · ${(item.value * 100 / expenses).round()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: item.value / top.first.value,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (item != top.last) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Income and spending side by side for the last four months.
class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final months = [
      for (var ago = 3; ago >= 0; ago--)
        (
          label: monthLabel(state.monthBounds(ago).start,
              ethiopian: state.useEthiopianCalendar, language: lang),
          income: state.monthTotal(EntryType.income, ago),
          expense: state.monthTotal(EntryType.expense, ago),
        ),
    ];
    final highest = months.fold<int>(
        1, (top, m) => math.max(top, math.max(m.income, m.expense)));
    Widget bar(int value, Color color) => Container(
          width: 14,
          height: 4 + 96 * value / highest,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        );
    return Column(
      children: [
        SizedBox(
          height: 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final month in months)
                Semantics(
                  label: state.hideBalances
                      ? month.label
                      : '${month.label}: ${t(lang, 'income')} '
                          '${formatEtb(month.income)}, ${t(lang, 'expenses')} '
                          '${formatEtb(month.expense)}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          bar(month.income, BirrColors.income),
                          const SizedBox(width: 4),
                          bar(month.expense, BirrColors.goldDecor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        month.label.characters.take(3).toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (color, key) in [
              (BirrColors.income, 'income'),
              (BirrColors.goldDecor, 'expenses'),
            ]) ...[
              Container(width: 10, height: 10, color: color),
              const SizedBox(width: 6),
              Text(t(lang, key), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 16),
            ],
          ],
        ),
      ],
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        height: 96,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (score ?? 0) / 100),
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 900),
          curve: Curves.fastOutSlowIn,
          builder: (context, progress, child) => CustomPaint(
            painter: _GaugePainter(progress: progress),
            child: child,
          ),
          child: Center(
            child: Text(
              score?.toString() ?? '—',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: BirrColors.heroText,
                    fontSize: 26,
                  ),
            ),
          ),
        ),
      );
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = BirrColors.heroText.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final active = Paint()
      ..color = BirrColors.goldOnDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * .75, math.pi * 1.5, false, track);
    if (progress > 0) {
      canvas.drawArc(
          rect, math.pi * .75, math.pi * 1.5 * progress, false, active);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.hidden,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final bool hidden;
  final IconData icon;

  @override
  Widget build(BuildContext context) => BirrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatEtb(value, hidden: hidden),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontFamily: 'serif',
                    ),
              ),
            ),
          ],
        ),
      );
}

class _ScoreFactor extends StatelessWidget {
  const _ScoreFactor(
      {required this.title, required this.value, required this.points});

  final String title;
  final double value;
  final String points;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(points, style: Theme.of(context).textTheme.labelLarge),
        ],
      );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: BirrCard(
          padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 11),
              Expanded(child: Text(text)),
              if (actionLabel != null && onAction != null)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      );
}
