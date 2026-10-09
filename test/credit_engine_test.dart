import 'package:flutter_test/flutter_test.dart';
import 'package:contador_engine/models/credit_engine.dart';

void main() {
  final start = DateTime(2026, 1, 31);
  test('Francés: referencia 1000 al 12% anual, dos cuotas', () {
    final plan = CreditEngine.schedule(
        const CreditTerms(principal: 1000, annualRate: 12, months: 2), start);
    expect(plan.map((r) => r.totalCents), [50751, 50751]);
    expect(plan.map((r) => r.interestCents), [1000, 502]);
    expect(plan.last.balanceCents, 0);
    expect(plan.first.due, DateTime(2026, 2, 28));
  });
  test('Alemán: capital constante y cuotas decrecientes', () {
    final plan = CreditEngine.schedule(
        const CreditTerms(
            principal: 1000,
            annualRate: 12,
            months: 2,
            method: AmortizationMethod.german),
        start);
    expect(plan.map((r) => r.totalCents), [51000, 50500]);
    expect(plan.map((r) => r.principalCents), [50000, 50000]);
  });
  test('Redondeo, tasa cero y cargos separados', () {
    final plan = CreditEngine.schedule(
        const CreditTerms(
            principal: 100,
            annualRate: 0,
            months: 3,
            monthlyInsurance: 2,
            openingFee: 5),
        start);
    expect(plan.fold<int>(0, (sum, r) => sum + r.principalCents), 10000);
    expect(plan.last.balanceCents, 0);
    expect(plan.first.totalCents, 4033);
    expect(plan.last.totalCents, 3534);
  });
  test('Mora única, pagos parciales, corte histórico y exceso', () {
    final plan = CreditEngine.schedule(
            const CreditTerms(principal: 100, annualRate: 0, months: 1), start)
        .map((r) => r.toMap())
        .toList();
    final payment = {'amountCents': 4000, 'date': '2026-03-01T12:00:00'};
    final before =
        CreditEngine.balances(plan, [payment], 500, DateTime(2026, 2, 28));
    expect(before.single['remainingCents'], 10000);
    final after =
        CreditEngine.balances(plan, [payment], 500, DateTime(2026, 4));
    expect(after.single['remainingCents'], 6500);
    expect(after.single['lateCents'], 500);
    expect(
        () => CreditEngine.balances(
            plan,
            [
              {'amountCents': 20000, 'date': '2026-02-01'}
            ],
            500,
            DateTime(2026, 4)),
        throwsArgumentError);
  });
  test('DTI y capacidad determinan recomendación explicable', () {
    final result = const ScoringRules().evaluate(
        const FinancialProfile(income: 2000, expenses: 1000, debtPayments: 200),
        400);
    expect(result['dti'], 0.3);
    expect(result['disposableIncome'], 400);
    expect(result['eligible'], true);
    expect(
        const ScoringRules().evaluate(
            const FinancialProfile(
                income: 1000, expenses: 900, debtPayments: 0),
            200)['eligible'],
        false);
    expect(
        () => const ScoringRules().evaluate(
            const FinancialProfile(income: 0, expenses: 0, debtPayments: 0),
            200),
        throwsArgumentError);
  });
  test('Evaluación bajo tres segundos con plan de 360 meses', () {
    final clock = Stopwatch()..start();
    final plan = CreditEngine.schedule(
        const CreditTerms(principal: 100000, annualRate: 12, months: 360),
        start);
    const ScoringRules().evaluate(
        const FinancialProfile(
            income: 10000, expenses: 1000, debtPayments: 100),
        plan.first.totalCents / 100);
    expect(clock.elapsedMilliseconds, lessThan(3000));
  });
}
