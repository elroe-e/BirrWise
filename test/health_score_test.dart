import 'package:birrwise/health_score.dart';
import 'package:flutter_test/flutter_test.dart';

HealthScore score({
  int income = 1000000,
  int expenses = 800000,
  int count = 10,
  int billsDue = 0,
  int billsOnTime = 0,
  int saved = 0,
  int? average,
}) =>
    computeHealthScore(HealthScoreInputs(
      monthIncome: income,
      monthExpenses: expenses,
      monthTransactionCount: count,
      billsDue: billsDue,
      billsPaidOnTime: billsOnTime,
      savedInGoals: saved,
      averageMonthlyExpense: average,
    ));

void main() {
  group('health score', () {
    test('not enough data without income or with fewer than 3 entries', () {
      expect(score(income: 0).total, isNull);
      expect(score(count: 2).total, isNull);
      expect(score(income: 0).labelKey, 'notEnoughData');
      expect(score(count: 3).total, isNotNull);
    });

    test('savings rate: 20% saved is full, 10% is half, overspending is 0', () {
      expect(score(expenses: 800000).savings, 40);
      expect(score(expenses: 900000).savings, 20);
      expect(score(expenses: 1200000).savings, 0);
    });

    test('bills: full when none are due, proportional otherwise', () {
      expect(score().bills, 20);
      expect(score(billsDue: 2, billsOnTime: 1).bills, 10);
      expect(score(billsDue: 2, billsOnTime: 0).bills, 0);
    });

    test('emergency fund: six months of average spending is full', () {
      expect(score(average: 100000, saved: 600000).emergency, 25);
      expect(score(average: 100000, saved: 300000).emergency, 13);
      expect(score(average: 100000, saved: 0).emergency, 0);
      // No history yet: this month's spending is the baseline.
      expect(score(expenses: 100000, saved: 600000).emergency, 25);
    });

    test('stability: full up to 110% of average, zero at 200%', () {
      expect(score(average: 800000, expenses: 880000).stability, 15);
      expect(score(average: 400000, expenses: 800000).stability, 0);
      expect(score(average: 500000, expenses: 775000).stability, 8);
      expect(score(average: null).stability, 15);
    });

    test('total and label bands', () {
      final best = score(average: 800000, saved: 4800000);
      expect(best.total, 100);
      expect(best.labelKey, 'scoreExcellent');
      expect(best.weakestFactorKey, isNull);

      final weak = score(
          expenses: 1100000, average: 500000, billsDue: 1, billsOnTime: 0);
      expect(weak.total, 0);
      expect(weak.labelKey, 'scoreNeedsAttention');
    });
  });

  group('recommendations', () {
    test('urgent items first and at most three', () {
      final result = recommendations(
        monthIncome: 100000,
        monthExpenses: 95000,
        expensesByCategory: {'rent': 60000, 'transport': 35000},
        billsDueWithin3Days: 2,
        pendingSmsOlderThan3Days: 1,
      );
      expect(result.map((r) => r.key),
          ['recBillsSoon', 'recOldPending', 'recLowSavings']);
      expect(result.first.values['count'], 2);
      expect(result.first.action, 'bills');
    });

    test('top category above 35% of spending', () {
      final result = recommendations(
        monthIncome: 200000,
        monthExpenses: 100000,
        expensesByCategory: {'food_groceries': 40000, 'rent': 30000},
        billsDueWithin3Days: 0,
        pendingSmsOlderThan3Days: 0,
      );
      expect(result.single.key, 'recTopCategory');
      expect(result.single.values,
          {'category': 'food_groceries', 'percent': 40});
    });

    test('nothing to say when all is well', () {
      expect(
        recommendations(
          monthIncome: 200000,
          monthExpenses: 100000,
          expensesByCategory: {'rent': 30000, 'food_groceries': 30000},
          billsDueWithin3Days: 0,
          pendingSmsOlderThan3Days: 0,
        ),
        isEmpty,
      );
    });
  });
}
