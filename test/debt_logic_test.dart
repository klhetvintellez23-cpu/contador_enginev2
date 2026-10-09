import 'package:flutter_test/flutter_test.dart';
import 'package:contador_engine/models/transaction.dart';
import 'package:contador_engine/models/payment.dart';
import 'package:contador_engine/models/loan_calculator.dart';

/// Fecha de inicio fija para que las quincenas caigan en días exactos:
/// venc. 0 (creación) = 01-ene, venc. 1 = 16-ene, venc. 2 = 31-ene.
final _start = DateTime(2025, 1, 1);

LoanTransaction _loan({
  double capital = 100.0,
  double rate = 15.0,
  IncrementType type = IncrementType.percentage,
  IncrementPeriod period = IncrementPeriod.biweekly,
  bool accumulate = true, // Opción B por defecto (por préstamo)
}) =>
    LoanTransaction(
      customerId: 1,
      title: 'Préstamo',
      initialAmount: capital,
      startDate: _start,
      incrementType: type,
      incrementValue: rate,
      incrementPeriod: period,
      accumulateOverdueInterest: accumulate,
    );

Payment _pay(double amount, DateTime date) => Payment(
    id: 'p${date.millisecondsSinceEpoch}',
    loanId: 1,
    amount: amount,
    date: date);

void main() {
  group('1. Creación del préstamo', () {
    test('Genera el interés del primer período de inmediato', () {
      final state = LoanCalculator.compute(_loan(), const [], asOf: _start);
      expect(state.outstandingCapital, closeTo(100.0, 0.0001));
      expect(state.pendingInterest, closeTo(15.0, 0.0001));
      expect(state.totalDebt, closeTo(115.0, 0.0001));
      // Debe quedar registrado en el historial de interés.
      expect(state.accruals.length, 1);
      expect(state.accruals.first.capitalBase, closeTo(100.0, 0.0001));
      expect(state.accruals.first.interestGenerated, closeTo(15.0, 0.0001));
      expect(state.accruals.first.periodIndex, 1);
    });

    test('A mitad de período no aparece interés adicional', () {
      final state = LoanCalculator.compute(_loan(), const [],
          asOf: DateTime(2025, 1, 10));
      expect(state.pendingInterest, closeTo(15.0, 0.0001));
      expect(state.totalDebt, closeTo(115.0, 0.0001));
      expect(state.accruals.length, 1);
    });
  });

  group('2. Pago solo de intereses', () {
    test('Paga el interés y en el siguiente vencimiento se genera de nuevo',
        () {
      // Paga $15 a mitad del primer período; consulta tras el 2º vencimiento.
      final state = LoanCalculator.compute(
        _loan(),
        [_pay(15.0, DateTime(2025, 1, 5))],
        asOf: DateTime(2025, 1, 20),
      );
      expect(state.interestPaid, closeTo(15.0, 0.0001));
      expect(state.capitalPaid, closeTo(0.0, 0.0001));
      expect(state.outstandingCapital, closeTo(100.0, 0.0001));
      // Nuevo interés del 2º período sobre el capital intacto.
      expect(state.pendingInterest, closeTo(15.0, 0.0001));
      expect(state.totalDebt, closeTo(115.0, 0.0001));
    });
  });

  group('3. Pago de intereses y capital', () {
    test('Paga interés y amortiza; el siguiente interés baja', () {
      // 100 + 15 de interés. Paga 50 → 15 interés + 35 capital → capital 65.
      final state = LoanCalculator.compute(
        _loan(),
        [_pay(50.0, DateTime(2025, 1, 5))],
        asOf: DateTime(2025, 1, 20),
      );
      expect(state.interestPaid, closeTo(15.0, 0.0001));
      expect(state.capitalPaid, closeTo(35.0, 0.0001));
      expect(state.outstandingCapital, closeTo(65.0, 0.0001));
      // 2º vencimiento: 15% de 65 = 9.75.
      expect(state.pendingInterest, closeTo(9.75, 0.0001));
      expect(state.totalDebt, closeTo(74.75, 0.0001));
    });
  });

  group('5. Pago parcial del interés', () {
    test('Opción A (préstamo con accumulate=false): no genera interés nuevo',
        () {
      // Interés 15, paga 10 → pendiente 5, capital 100.
      final state = LoanCalculator.compute(
        _loan(accumulate: false),
        [_pay(10.0, DateTime(2025, 1, 5))],
        asOf: DateTime(2025, 1, 20),
      );
      expect(state.interestPaid, closeTo(10.0, 0.0001));
      expect(state.outstandingCapital, closeTo(100.0, 0.0001));
      expect(state.pendingInterest, closeTo(5.0, 0.0001));
      expect(state.totalDebt, closeTo(105.0, 0.0001));
    });

    test('Opción B (por defecto): acumula el interés del nuevo vencimiento',
        () {
      // Sin pasar el parámetro: usa la política del propio préstamo (B).
      final state = LoanCalculator.compute(
        _loan(),
        [_pay(10.0, DateTime(2025, 1, 5))],
        asOf: DateTime(2025, 1, 20),
      );
      // Pendiente 5 previo + 15 nuevo = 20.
      expect(state.pendingInterest, closeTo(20.0, 0.0001));
      expect(state.totalDebt, closeTo(120.0, 0.0001));
    });
  });

  group('4. Pago total del préstamo', () {
    test('Queda saldado y no genera más interés', () {
      final state = LoanCalculator.compute(
        _loan(),
        [_pay(115.0, DateTime(2025, 1, 5))],
        asOf: DateTime(2025, 1, 31),
      );
      expect(state.outstandingCapital, closeTo(0.0, 0.0001));
      expect(state.pendingInterest, closeTo(0.0, 0.0001));
      expect(state.totalDebt, closeTo(0.0, 0.0001));
      expect(state.isSettled, isTrue);
    });
  });

  group('6. Interés sobre saldo pendiente (ejemplo \$500)', () {
    test('El nuevo interés usa el capital restante, no el original', () {
      // Capital 500, interés 75. Paga 200 → 75 interés + 125 capital → 375.
      final state = LoanCalculator.compute(
        _loan(capital: 500.0),
        [_pay(200.0, DateTime(2025, 1, 5))],
        asOf: DateTime(2025, 1, 20),
      );
      expect(state.outstandingCapital, closeTo(375.0, 0.0001));
      // 2º vencimiento: 15% de 375 = 56.25 (nunca 15% de 500).
      expect(state.pendingInterest, closeTo(56.25, 0.0001));
      expect(state.totalDebt, closeTo(431.25, 0.0001));
    });
  });

  group('8. Múltiples períodos consecutivos', () {
    test('Opción A (accumulate=false) sin pagos: interés no se acumula', () {
      final state = LoanCalculator.compute(_loan(accumulate: false), const [],
          asOf: DateTime(2025, 1, 31)); // 3 vencimientos: 1,16,31 ene
      expect(state.pendingInterest, closeTo(15.0, 0.0001));
      expect(state.totalDebt, closeTo(115.0, 0.0001));
    });

    test('Opción B (por defecto) sin pagos: acumula un interés por vencimiento',
        () {
      // Sin parámetro: el préstamo trae Opción B por defecto.
      final state = LoanCalculator.compute(_loan(), const [],
          asOf: DateTime(2025, 1, 31));
      // 3 vencimientos × 15% de 100 = 45.
      expect(state.pendingInterest, closeTo(45.0, 0.0001));
      expect(state.accruals.length, 3);
    });

    test(
        'Con interés vencido, el nuevo interés se calcula sobre el capital, '
        'NO sobre capital+interés (sin capitalización)', () {
      // Venc1 (01-ene): 15% de 100 = 15 → total 115. No paga.
      // Venc2 (16-ene): con Opción B se genera otro interés, pero la base debe
      // ser el capital pendiente (100), NO el total adeudado (115).
      //   Correcto:   15% de 100 = 15  → total 130
      //   Incorrecto: 15% de 115 = 17.25 → total 132.25 (capitalización)
      final state = LoanCalculator.compute(
        _loan(), // Opción B por defecto
        const [],
        asOf: DateTime(2025, 1, 16),
      );
      expect(state.outstandingCapital, closeTo(100.0, 0.0001));
      expect(
          state.pendingInterest, closeTo(30.0, 0.0001)); // 15 + 15, nunca 32.25
      expect(state.totalDebt, closeTo(130.0, 0.0001)); // nunca 132.25
      // Cada generación usó el capital pendiente (100) como base, no 115.
      expect(state.accruals.length, 2);
      expect(state.accruals[0].capitalBase, closeTo(100.0, 0.0001));
      expect(state.accruals[0].interestGenerated, closeTo(15.0, 0.0001));
      expect(state.accruals[1].capitalBase, closeTo(100.0, 0.0001));
      expect(state.accruals[1].interestGenerated, closeTo(15.0, 0.0001));
    });

    test('Pagando cada quincena el interés se genera sobre capital menor', () {
      // Paga 25 en cada vencimiento cumplido.
      final state = LoanCalculator.compute(
        _loan(),
        [
          _pay(25.0, DateTime(2025, 1, 2)), // cubre interés 15 + 10 capital
          _pay(25.0, DateTime(2025, 1, 17)), // tras 2º venc (15% de 90 = 13.5)
        ],
        asOf: DateTime(2025, 1, 17),
      );
      // Venc1: 15 sobre 100. Pago1: 15 int + 10 cap → cap 90.
      // Venc2: 13.5 sobre 90. Pago2: 13.5 int + 11.5 cap → cap 78.5.
      expect(state.interestPaid, closeTo(28.5, 0.0001));
      expect(state.capitalPaid, closeTo(21.5, 0.0001));
      expect(state.outstandingCapital, closeTo(78.5, 0.0001));
      expect(state.pendingInterest, closeTo(0.0, 0.0001));
    });
  });

  group('Casos borde', () {
    test('Préstamo sin interés: el pago amortiza capital directamente', () {
      final state = LoanCalculator.compute(
        _loan(rate: 0.0),
        [_pay(40.0, DateTime(2025, 1, 10))],
        asOf: DateTime(2025, 1, 31),
      );
      expect(state.pendingInterest, closeTo(0.0, 0.0001));
      expect(state.capitalPaid, closeTo(40.0, 0.0001));
      expect(state.totalDebt, closeTo(60.0, 0.0001));
      expect(state.accruals, isEmpty);
    });

    test('Monto fijo: genera el cargo del primer período al crear', () {
      final state = LoanCalculator.compute(
        _loan(rate: 20.0, type: IncrementType.fixed),
        const [],
        asOf: _start,
      );
      expect(state.pendingInterest, closeTo(20.0, 0.0001));
      expect(state.totalDebt, closeTo(120.0, 0.0001));
    });
  });

  group('Política por préstamo (persistencia)', () {
    test('Un préstamo nuevo trae Opción B por defecto', () {
      expect(_loan().accumulateOverdueInterest, isTrue);
    });

    test('toMap/fromMap conserva la política (snake_case y camelCase)', () {
      final a = _loan(accumulate: false).toMap(snakeCase: true);
      expect(a['accumulate_overdue_interest'], isFalse);
      expect(LoanTransaction.fromMap(a).accumulateOverdueInterest, isFalse);

      final b = _loan().toMap();
      expect(LoanTransaction.fromMap(b).accumulateOverdueInterest, isTrue);
    });

    test('Préstamo antiguo sin la columna adopta Opción B', () {
      final legacy = {
        'customerId': 1,
        'title': 'Viejo',
        'initialAmount': 100.0,
        'startDate': _start.toIso8601String(),
        'incrementType': 1,
        'incrementValue': 15.0,
        'incrementPeriod': 2,
        'amountPaid': 0.0,
      };
      expect(LoanTransaction.fromMap(legacy).accumulateOverdueInterest, isTrue);
    });
  });
}
