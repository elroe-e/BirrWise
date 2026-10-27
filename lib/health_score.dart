/// Financial health score and suggestions. Pure Dart: no Flutter imports, so
/// every rule is covered by plain unit tests.
library;

class HealthScoreInputs {
  const HealthScoreInputs({
    required this.monthIncome,
    required this.monthExpenses,
    required this.monthTransactionCount,
    required this.billsDue,
    required this.billsPaidOnTime,
    required this.savedInGoals,
    required this.averageMonthlyExpense,
  });

  /// Santim, current month.
  final int monthIncome;
  final int monthExpenses;

  /// Income and expense entries this month.
  final int monthTransactionCount;

  /// Bills whose due date has passed this month, or that were already paid.
  final int billsDue;
  final int billsPaidOnTime;

  /// Santim saved across all savings goals.
  final int savedInGoals;

  /// Average expenses of the previous months that had activity (up to 3), or
  /// null if there is no history yet.
  final int? averageMonthlyExpense;
}

class HealthScore {
  const HealthScore({
    required this.total,
    required this.savings,
    required this.bills,
    required this.emergency,
    required this.stability,
  });

  static const savingsMax = 40;
  static const billsMax = 20;
  static const emergencyMax = 25;
  static const stabilityMax = 15;

  /// Null when there is not enough data this month to judge.
  final int? total;
  final int savings;
  final int bills;
  final int emergency;
  final int stability;

  /// String key for the score band.
  String get labelKey => switch (total) {
        null => 'notEnoughData',
        < 40 => 'scoreNeedsAttention',
        < 60 => 'scoreFair',
        < 80 => 'scoreGood',
        _ => 'scoreExcellent',
      };

  /// String key of the component furthest below its maximum, or null if all
  /// are at least 80% of their maximum.
  String? get weakestFactorKey {
    final ratios = {
      'factorSavings': savings / savingsMax,
      'factorBills': bills / billsMax,
      'factorEmergency': emergency / emergencyMax,
      'factorStability': stability / stabilityMax,
    };
    final weakest =
        ratios.entries.reduce((a, b) => b.value < a.value ? b : a);
    return weakest.value >= .8 ? null : weakest.key;
  }
}

HealthScore computeHealthScore(HealthScoreInputs input) {
  final income = input.monthIncome;
  final expenses = input.monthExpenses;

  // Saving 20% or more of this month's income earns full points.
  // (Divisions are arranged on whole santim so boundaries round exactly.)
  final savings = income <= 0
      ? 0
      : _scaled((income - expenses) * 5 / income, HealthScore.savingsMax);

  // Full points if nothing was due yet.
  final bills = input.billsDue == 0
      ? HealthScore.billsMax
      : _scaled(input.billsPaidOnTime / input.billsDue, HealthScore.billsMax);

  // Six months of typical spending saved in goals earns full points.
  final baseline = input.averageMonthlyExpense ?? expenses;
  final monthsCovered = baseline <= 0
      ? (input.savedInGoals > 0 ? 6.0 : 0.0)
      : input.savedInGoals / baseline;
  final emergency = _scaled(monthsCovered / 6, HealthScore.emergencyMax);

  // Full points up to 110% of the usual monthly spend, none at 200% or more.
  final average = input.averageMonthlyExpense;
  final stability = average == null || average <= 0
      ? HealthScore.stabilityMax
      : _scaled((average * 20 - expenses * 10) / (average * 9),
          HealthScore.stabilityMax);

  final enoughData = input.monthTransactionCount >= 3 && income > 0;
  return HealthScore(
    total: enoughData ? savings + bills + emergency + stability : null,
    savings: savings,
    bills: bills,
    emergency: emergency,
    stability: stability,
  );
}

int _scaled(double fraction, int max) =>
    (fraction.clamp(0.0, 1.0) * max).round();

class Recommendation {
  const Recommendation(this.key, [this.values = const {}, this.action]);

  /// String key; [values] fill its placeholders.
  final String key;
  final Map<String, Object> values;

  /// Optional action: 'bills' or 'inbox'.
  final String? action;
}

/// Up to three plain suggestions, most urgent first.
List<Recommendation> recommendations({
  required int monthIncome,
  required int monthExpenses,
  required Map<String, int> expensesByCategory,
  required int billsDueWithin3Days,
  required int pendingSmsOlderThan3Days,
}) {
  final result = <Recommendation>[];
  if (billsDueWithin3Days > 0) {
    result.add(Recommendation(
        'recBillsSoon', {'count': billsDueWithin3Days}, 'bills'));
  }
  if (pendingSmsOlderThan3Days > 0) {
    result.add(const Recommendation('recOldPending', {}, 'inbox'));
  }
  if (monthIncome > 0) {
    final rate = (monthIncome - monthExpenses) / monthIncome;
    if (rate < .1) {
      final percent = (rate.clamp(0.0, 1.0) * 100).round();
      result.add(Recommendation('recLowSavings', {'percent': percent}));
    }
  }
  if (monthExpenses > 0 && expensesByCategory.isNotEmpty) {
    final top = expensesByCategory.entries
        .reduce((a, b) => b.value > a.value ? b : a);
    final share = top.value / monthExpenses;
    if (share > .35) {
      result.add(Recommendation('recTopCategory', {
        'category': top.key,
        'percent': (share * 100).round(),
      }));
    }
  }
  return result.take(3).toList();
}
