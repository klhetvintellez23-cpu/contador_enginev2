import 'payment.dart';
import 'transaction.dart';

/// Detalle de cómo se repartió un cobro concreto entre interés y capital.
///
/// Se usa tanto para el historial de cobros (mostrar cuánto de cada pago
/// fue interés y cuánto abonó al capital) como para estimar el interés
/// cobrado en un período (p. ej. el cierre del día).
class PaymentBreakdown {
  final Payment payment;

  /// Parte del pago que se aplicó a intereses pendientes.
  final double toInterest;

  /// Parte del pago que amortizó capital (solo después de cubrir el interés).
  final double toCapital;

  /// Capital pendiente justo antes de aplicar este pago.
  final double capitalBefore;

  /// Capital pendiente justo después de aplicar este pago.
  final double capitalAfter;

  /// Interés pendiente (generado y no pagado) justo antes de este pago.
  final double interestPendingBefore;

  const PaymentBreakdown({
    required this.payment,
    required this.toInterest,
    required this.toCapital,
    required this.capitalBefore,
    required this.capitalAfter,
    required this.interestPendingBefore,
  });
}

/// Registro de una generación de interés en una fecha de vencimiento, para
/// auditoría y trazabilidad (historial del préstamo).
class InterestAccrual {
  /// Fecha de vencimiento en la que se generó el interés.
  final DateTime date;

  /// Número de período (1 = primer período, generado al crear el préstamo).
  final int periodIndex;

  /// Capital pendiente usado como base del cálculo.
  final double capitalBase;

  /// true si la tasa es porcentaje; false si es un monto fijo por período.
  final bool isPercentage;

  /// Valor de la tasa: el porcentaje (p. ej. 15) o el monto fijo por período.
  final double rate;

  /// Interés efectivamente generado en este vencimiento.
  final double interestGenerated;

  const InterestAccrual({
    required this.date,
    required this.periodIndex,
    required this.capitalBase,
    required this.isPercentage,
    required this.rate,
    required this.interestGenerated,
  });
}

/// Estado financiero de un préstamo a una fecha dada, calculado siempre
/// sobre el SALDO DE CAPITAL PENDIENTE (nunca sobre el monto original).
class LoanAccountState {
  /// Capital que todavía se debe (monto inicial menos lo amortizado).
  final double outstandingCapital;

  /// Interés ya generado pero aún no pagado.
  final double pendingInterest;

  /// Deuda total pendiente = capital pendiente + interés pendiente.
  final double totalDebt;

  /// Interés total generado a la fecha (pagado + pendiente).
  final double accruedInterest;

  /// Interés ya liquidado por el cliente.
  final double interestPaid;

  /// Capital ya amortizado.
  final double capitalPaid;

  /// Total abonado (interés pagado + capital pagado).
  final double totalPaid;

  /// Dinero recibido que no corresponde a capital ni a intereses.
  final double creditBalance;

  /// Desglose interés/capital de cada cobro, en orden cronológico.
  final List<PaymentBreakdown> breakdowns;

  /// Historial de generaciones de interés (una por vencimiento cumplido).
  final List<InterestAccrual> accruals;

  const LoanAccountState({
    required this.outstandingCapital,
    required this.pendingInterest,
    required this.totalDebt,
    required this.accruedInterest,
    required this.interestPaid,
    required this.capitalPaid,
    required this.totalPaid,
    required this.breakdowns,
    required this.accruals,
    this.creditBalance = 0,
  });

  /// El préstamo está saldado cuando no queda ni capital ni interés.
  bool get isSettled => totalDebt <= 0.01;
}

/// Motor único de cálculo de préstamos con amortización de capital, al estilo
/// de un prestamista tradicional.
///
/// Reglas (aplicadas de forma consistente en toda la app):
///  1. El interés se genera SIEMPRE sobre el capital pendiente, no sobre el
///     monto original.
///  2. El interés del primer período se genera al CREAR el préstamo; los
///     siguientes solo al llegar cada fecha de vencimiento (nunca al registrar
///     o editar un pago, ni al recalcular).
///  3. Cada cobro paga primero todo el interés pendiente; solo el sobrante
///     amortiza capital. Mientras quede interés pendiente, ningún pago reduce
///     el capital.
///  4. El interés ya pagado queda liquidado y no vuelve a contarse.
///  5. Si al llegar un vencimiento todavía hay interés vencido pendiente, la
///     política es POR PRÉSTAMO ([LoanTransaction.accumulateOverdueInterest]):
///     - Opción B (por defecto, = true): se genera igual y se acumula. La base
///       sigue siendo el capital pendiente, nunca el total adeudado.
///     - Opción A (= false): NO se genera interés nuevo hasta saldarlo.
///     El parámetro [accumulateOverdueInterest] de [compute] solo sirve para
///     forzar la política en pruebas o cálculos puntuales.
class LoanCalculator {
  static DateTime nextUnpaidDueDate(
      LoanTransaction loan, LoanAccountState state) {
    var covered = state.interestPaid;
    for (final accrual in state.accruals) {
      if (covered + 0.001 < accrual.interestGenerated) {
        return loan.incrementPeriod.dateAt(loan.startDate, accrual.periodIndex);
      }
      covered -= accrual.interestGenerated;
    }
    return loan.incrementPeriod.dateAt(loan.startDate,
        state.accruals.isEmpty ? 1 : state.accruals.last.periodIndex + 1);
  }

  /// Fechas de vencimiento en las que se genera interés y que ya ocurrieron a
  /// la fecha [now]. Incluye la creación (k=0): el interés del primer período
  /// se genera de inmediato al crear el préstamo; los siguientes en cada
  /// vencimiento (startDate + k·período).
  static List<DateTime> _dueDates(LoanTransaction loan, DateTime now) {
    final periodDays = loan.incrementPeriod.lengthInDays;
    if (loan.incrementValue <= 0 || periodDays <= 0) return const [];
    final dates = <DateTime>[];
    var k = 0;
    while (true) {
      final d = loan.incrementPeriod.dateAt(loan.startDate, k);
      if (d.isAfter(now)) break;
      dates.add(d);
      k++;
      if (k > 100000) break; // salvaguarda ante fechas corruptas
    }
    return dates;
  }

  /// Calcula el estado del préstamo a la fecha [asOf] (por defecto, ahora).
  ///
  /// Fusiona cronológicamente los vencimientos (que generan interés) y los
  /// cobros (que pagan interés y luego capital). Ante un empate de fecha,
  /// primero se genera el interés del vencimiento y después se aplica el cobro.
  ///
  /// [accumulateOverdueInterest] activa la Opción B (ver reglas de la clase).
  static LoanAccountState compute(
    LoanTransaction loan,
    Iterable<Payment> loanPayments, {
    DateTime? asOf,
    bool? accumulateOverdueInterest,
  }) {
    // La política es por préstamo; el parámetro solo permite forzarla en
    // pruebas o cálculos puntuales. Por defecto se usa la del propio préstamo.
    final accumulate =
        accumulateOverdueInterest ?? loan.accumulateOverdueInterest;
    final now = asOf ?? DateTime.now();
    if (!loan.initialAmount.isFinite ||
        loan.initialAmount <= 0 ||
        !loan.incrementValue.isFinite ||
        loan.incrementValue < 0) {
      throw ArgumentError('Monto o tasa inválidos.');
    }
    for (final payment in loanPayments) {
      if (!payment.amount.isFinite ||
          payment.amount <= 0 ||
          payment.date.isBefore(loan.startDate)) {
        throw ArgumentError('Pago inválido o anterior al préstamo.');
      }
    }
    final payments = loanPayments.where((p) => !p.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final dueDates = _dueDates(loan, now);

    double capital = loan.initialAmount;
    double accrued = 0.0;
    double interestPaid = 0.0;
    double capitalPaid = 0.0;
    double creditBalance = 0.0;
    final breakdowns = <PaymentBreakdown>[];
    final accruals = <InterestAccrual>[];

    var bi = 0;
    var pi = 0;
    while (bi < dueDates.length || pi < payments.length) {
      final nextDue = bi < dueDates.length ? dueDates[bi] : null;
      final nextPayment = pi < payments.length ? payments[pi] : null;

      // Se toma el vencimiento cuando no queda cobro pendiente o cuando ocurre
      // en la misma fecha o antes que el próximo cobro (interés primero).
      final takeDue = nextPayment == null ||
          (nextDue != null && !nextDue.isAfter(nextPayment.date));

      if (takeDue) {
        final pendingInterest = accrued - interestPaid;
        final hasOverdueInterest = pendingInterest > 0.01;
        // Opción A: si hay interés vencido pendiente, no se genera uno nuevo.
        final shouldGenerate = accumulate || !hasOverdueInterest;
        if (shouldGenerate) {
          final interest = perPeriodInterest(loan, capital);
          if (interest > 0) {
            accrued += interest;
            accruals.add(InterestAccrual(
              date: nextDue!,
              periodIndex: bi + 1,
              capitalBase: capital,
              isPercentage: loan.incrementType == IncrementType.percentage,
              rate: loan.incrementValue,
              interestGenerated: interest,
            ));
          }
        }
        bi++;
      } else {
        final p = nextPayment;
        // Reparte el cobro: primero el interés pendiente, luego capital.
        final pending = accrued - interestPaid;
        final interestOwed = pending > 0 ? pending : 0.0;
        final toInterest = p.amount < interestOwed ? p.amount : interestOwed;
        interestPaid += toInterest;

        final remainder = p.amount - toInterest;
        final toCapital = remainder < capital ? remainder : capital;
        creditBalance += remainder - toCapital;
        final capitalBefore = capital;
        capital -= toCapital;
        if (capital < 0) capital = 0.0;
        capitalPaid += toCapital;

        breakdowns.add(PaymentBreakdown(
          payment: p,
          toInterest: toInterest,
          toCapital: toCapital,
          capitalBefore: capitalBefore,
          capitalAfter: capital,
          interestPendingBefore: interestOwed,
        ));
        pi++;
      }
    }

    final pending = accrued - interestPaid;
    final pendingInterest = pending > 0 ? pending : 0.0;
    final outstandingCapital = capital > 0 ? capital : 0.0;

    return LoanAccountState(
      outstandingCapital: outstandingCapital,
      pendingInterest: pendingInterest,
      totalDebt: outstandingCapital + pendingInterest,
      accruedInterest: accrued,
      interestPaid: interestPaid,
      capitalPaid: capitalPaid,
      totalPaid: interestPaid + capitalPaid + creditBalance,
      creditBalance: creditBalance,
      breakdowns: breakdowns,
      accruals: accruals,
    );
  }

  /// Interés que se genera en un período completo sobre [outstandingCapital],
  /// útil para sugerir cuánto cobrar (al menos el interés del período).
  static double perPeriodInterest(
      LoanTransaction loan, double outstandingCapital) {
    if (loan.incrementValue <= 0 || outstandingCapital <= 0) return 0.0;
    return loan.incrementType == IncrementType.percentage
        ? outstandingCapital * (loan.incrementValue / 100)
        : loan.incrementValue;
  }
}
