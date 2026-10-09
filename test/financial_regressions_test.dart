import 'package:flutter_test/flutter_test.dart';
import 'package:contador_engine/models/loan_calculator.dart';
import 'package:contador_engine/models/transaction.dart';
import 'package:contador_engine/models/payment.dart';

void main() {
  final start = DateTime(2026, 1, 1);
  LoanTransaction loan() => LoanTransaction(
      id: 'l',
      customerId: 'c',
      title: 'Prueba',
      initialAmount: 100,
      startDate: start,
      incrementType: IncrementType.percentage,
      incrementValue: 0);
  Payment payment(double amount, DateTime date) =>
      Payment(id: 'p', loanId: 'l', amount: amount, date: date);
  test('El saldo histórico excluye pagos futuros', () {
    final state = LoanCalculator.compute(
        loan(), [payment(40, DateTime(2026, 2, 1))],
        asOf: DateTime(2026, 1, 10));
    expect(state.totalDebt, 100);
    expect(state.totalPaid, 0);
  });
  test('El excedente es saldo a favor y nunca interés', () {
    final state =
        LoanCalculator.compute(loan(), [payment(150, start)], asOf: start);
    expect(state.totalPaid, 150);
    expect(state.capitalPaid, 100);
    expect(state.interestPaid, 0);
    expect(state.creditBalance, 50);
  });
  test('Rechaza pagos negativos, no finitos y anteriores al préstamo', () {
    for (final value in [-1.0, 0.0, double.nan, double.infinity]) {
      expect(() => LoanCalculator.compute(loan(), [payment(value, start)]),
          throwsArgumentError);
    }
    expect(() => LoanCalculator.compute(loan(), [payment(1, DateTime(2025))]),
        throwsArgumentError);
  });
  test('Vencimientos mensuales mantienen el día original y ajustan fin de mes',
      () {
    final date = DateTime(2026, 1, 31);
    expect(IncrementPeriod.monthly.dateAt(date, 1), DateTime(2026, 2, 28));
    expect(IncrementPeriod.monthly.dateAt(date, 2), DateTime(2026, 3, 31));
    expect(IncrementPeriod.monthly.dateAt(DateTime(2024, 1, 31), 1),
        DateTime(2024, 2, 29));
  });
}
