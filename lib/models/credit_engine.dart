import 'dart:math';
import 'transaction.dart';

enum AmortizationMethod { french, german }

enum FeciTreatment { pending, applies, exempt, outsideScope }

class CreditTerms {
  final double principal, annualRate, monthlyInsurance, openingFee, lateFee;
  final int months;
  final AmortizationMethod method;
  final int policyVersion;
  final FeciTreatment feciTreatment;
  final String feciEvidence;
  final double lateFeePercent;
  const CreditTerms(
      {required this.principal,
      required this.annualRate,
      required this.months,
      this.method = AmortizationMethod.french,
      this.monthlyInsurance = 0,
      this.openingFee = 0,
      this.lateFee = 0,
      this.policyVersion = 2,
      this.feciTreatment = FeciTreatment.pending,
      this.feciEvidence = '',
      this.lateFeePercent = 0});
  bool get chargesFeci =>
      principal > 5000 && feciTreatment == FeciTreatment.applies;
  void validateForContract() {
    validate();
    if (policyVersion != 2) {
      throw ArgumentError(
          'Actualiza las condiciones antes de formalizar un crédito nuevo.');
    }
    if (principal > 5000 &&
        (feciTreatment == FeciTreatment.pending ||
            (feciTreatment != FeciTreatment.applies &&
                feciEvidence.trim().length < 10))) {
      throw ArgumentError(
          'Documenta la aplicación, exención o no sujeción al FECI.');
    }
    if (lateFee != 0) {
      throw ArgumentError(
          'Los créditos nuevos usan mora porcentual sobre capital vencido.');
    }
  }

  void validate() {
    if (policyVersion >= 2 &&
        [principal, monthlyInsurance, openingFee, lateFee].any((v) =>
            v.isFinite && (v * 100 - (v * 100).round()).abs() > .00001)) {
      throw ArgumentError(
          'Los importes monetarios admiten como máximo dos decimales.');
    }
    if (![1, 2].contains(policyVersion) ||
        !lateFeePercent.isFinite ||
        lateFeePercent < 0 ||
        lateFeePercent > 100 ||
        !principal.isFinite ||
        principal < 1 ||
        principal > 10000000 ||
        !annualRate.isFinite ||
        annualRate < 0 ||
        annualRate > 100 ||
        months < 1 ||
        months > 360 ||
        [monthlyInsurance, openingFee, lateFee]
            .any((v) => !v.isFinite || v < 0 || v > 1000000)) {
      throw ArgumentError(
          'Revisa monto (1–10 millones), tasa anual (0–100%), plazo (1–360 meses) y cargos.');
    }
  }

  Map<String, dynamic> toMap() => {
        'principal': principal,
        'annualRate': annualRate,
        'months': months,
        'method': method.name,
        'monthlyInsurance': monthlyInsurance,
        'openingFee': openingFee,
        'lateFee': lateFee,
        if (policyVersion >= 2) ...{
          'policyVersion': policyVersion,
          'feciTreatment': feciTreatment.name,
          'feciEvidence': feciEvidence,
          'lateFeePercent': lateFeePercent,
        }
      };
  factory CreditTerms.fromMap(Map<String, dynamic> m) => CreditTerms(
      principal: (m['principal'] as num).toDouble(),
      annualRate: (m['annualRate'] as num).toDouble(),
      months: m['months'] as int,
      method: AmortizationMethod.values.byName(m['method'] as String),
      monthlyInsurance: (m['monthlyInsurance'] as num? ?? 0).toDouble(),
      openingFee: (m['openingFee'] as num? ?? 0).toDouble(),
      lateFee: (m['lateFee'] as num? ?? 0).toDouble(),
      policyVersion: m['policyVersion'] as int? ?? 1,
      feciTreatment: FeciTreatment.values
          .byName(m['feciTreatment'] as String? ?? 'pending'),
      feciEvidence: m['feciEvidence'] as String? ?? '',
      lateFeePercent: (m['lateFeePercent'] as num? ?? 0).toDouble());
}

class ScheduledInstallment {
  final int number,
      principalCents,
      interestCents,
      insuranceCents,
      feeCents,
      balanceCents;
  final DateTime due;
  final int feciCents;
  final int? lateFeeCents;
  const ScheduledInstallment(
      {required this.number,
      required this.due,
      required this.principalCents,
      required this.interestCents,
      required this.insuranceCents,
      required this.feeCents,
      required this.balanceCents,
      this.feciCents = 0,
      this.lateFeeCents});
  int get totalCents =>
      principalCents + interestCents + insuranceCents + feeCents + feciCents;
  Map<String, dynamic> toMap() => {
        'number': number,
        'due': due.toIso8601String(),
        'principalCents': principalCents,
        'interestCents': interestCents,
        'insuranceCents': insuranceCents,
        'feeCents': feeCents,
        'balanceCents': balanceCents,
        'totalCents': totalCents,
        if (lateFeeCents != null) 'lateFeeCents': lateFeeCents,
        if (lateFeeCents != null || feciCents != 0) 'feciCents': feciCents,
      };
}

class CreditEngine {
  static List<ScheduledInstallment> schedule(
      CreditTerms terms, DateTime start) {
    terms.validate();
    final initial = (terms.principal * 100).round();
    final rate = terms.annualRate / 1200;
    final fixed = rate == 0
        ? initial / terms.months
        : initial * rate / (1 - pow(1 + rate, -terms.months));
    int balance = initial;
    return List.generate(terms.months, (index) {
      final interest = (balance * rate).round();
      final feci = terms.chargesFeci ? (balance / 1200).round() : 0;
      final principal = index == terms.months - 1
          ? balance
          : min(
              balance,
              terms.method == AmortizationMethod.german
                  ? (initial / terms.months).round()
                  : fixed.round() - interest);
      if (principal < 0) throw StateError('La cuota no cubre el interés.');
      balance -= principal;
      return ScheduledInstallment(
          number: index + 1,
          due: IncrementPeriod.monthly.dateAt(start, index + 1),
          principalCents: principal,
          interestCents: interest,
          insuranceCents: (terms.monthlyInsurance * 100).round(),
          feeCents: index == 0 ? (terms.openingFee * 100).round() : 0,
          feciCents: feci,
          lateFeeCents: terms.policyVersion >= 2
              ? (principal * terms.lateFeePercent / 100).round()
              : null,
          balanceCents: balance);
    });
  }

  /// Distribución cronológica de pagos: cargos, interés, capital; permite adelantar cuotas.
  /// La mora es un cargo fijo único por cuota vencida, sin capitalización.
  static List<Map<String, dynamic>> balances(
      List<Map<String, dynamic>> schedule,
      List<Map<String, dynamic>> payments,
      int lateFeeCents,
      DateTime asOf) {
    if (lateFeeCents < 0) throw ArgumentError('Mora inválida.');
    for (final payment in payments) {
      if (payment['voided'] == true) continue;
      if (payment['amountCents'] is! int ||
          (payment['amountCents'] as int) <= 0) {
        throw ArgumentError('El pago debe expresarse en centavos positivos.');
      }
    }
    final result = schedule
        .map((r) => {...r, 'paidCents': 0, 'lateCents': 0, 'latePaidCents': 0})
        .toList();
    final ordered = payments
        .where((p) =>
            p['voided'] != true &&
            !DateTime.parse(p['date'] as String).isAfter(asOf))
        .toList()
      ..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    void accrue(DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      for (final row in result) {
        final d = DateTime.parse(row['due'] as String);
        if (DateTime(d.year, d.month, d.day).isBefore(day) &&
            (row['paidCents'] as int) < (row['totalCents'] as int)) {
          // The charge is fixed once delinquency begins, on unpaid principal.
          if ((row['lateCents'] as int) == 0) {
            final charges =
                (row['totalCents'] as int) - (row['principalCents'] as int);
            final paidPrincipal = max(0, (row['paidCents'] as int) - charges);
            final principal = row['principalCents'] as int;
            row['lateCents'] = row.containsKey('lateFeeCents')
                ? (principal == 0
                    ? 0
                    : ((row['lateFeeCents'] as int) *
                            (principal - paidPrincipal) /
                            principal)
                        .round())
                : lateFeeCents;
          }
        }
      }
    }

    for (final payment in ordered) {
      accrue(DateTime.parse(payment['date'] as String));
      var remaining = payment['amountCents'] as int;
      for (final row in result) {
        final late = min(remaining,
            (row['lateCents'] as int) - (row['latePaidCents'] as int));
        row['latePaidCents'] = (row['latePaidCents'] as int) + late;
        remaining -= late;
        final applied = min(
            remaining, (row['totalCents'] as int) - (row['paidCents'] as int));
        row['paidCents'] = (row['paidCents'] as int) + applied;
        remaining -= applied;
      }
      if (remaining > 0) {
        throw ArgumentError('El pago supera el saldo contractual.');
      }
    }
    accrue(asOf);
    for (final row in result) {
      row['remainingCents'] = (row['totalCents'] as int) +
          (row['lateCents'] as int) -
          (row['paidCents'] as int) -
          (row['latePaidCents'] as int);
      var paid = row['paidCents'] as int;
      for (final component in [
        'fee',
        'insurance',
        'feci',
        'interest',
        'principal'
      ]) {
        final applied = min(paid, row['${component}Cents'] as int? ?? 0);
        row['${component}PaidCents'] = applied;
        paid -= applied;
      }
    }
    return result;
  }

  /// Monthly IRR annualized with compounding. Third-party insurance and FECI
  /// are disclosed separately; neither is revenue retained by the lender.
  static double effectiveAnnualRate(CreditTerms terms,
      {bool includeThirdParties = false}) {
    final plan = schedule(terms, DateTime(2024, 1, 1));
    final flows = plan
        .map((r) => includeThirdParties
            ? r.totalCents
            : r.principalCents + r.interestCents + r.feeCents)
        .toList();
    final principal = (terms.principal * 100).round();
    if (flows.fold<int>(0, (s, c) => s + c) == principal) return 0;
    double npv(double rate) {
      var value = -principal.toDouble();
      for (var i = 0; i < flows.length; i++) {
        value += flows[i] / pow(1 + rate, i + 1);
      }
      return value;
    }

    var low = 0.0, high = 1.0;
    while (npv(high) > 0) {
      high *= 2;
    }
    for (var i = 0; i < 180; i++) {
      final mid = (low + high) / 2;
      if (npv(mid) > 0) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (pow(1 + (low + high) / 2, 12) - 1) * 100;
  }
}

class FinancialProfile {
  final double income, expenses, debtPayments;
  const FinancialProfile(
      {required this.income,
      required this.expenses,
      required this.debtPayments});
  void validate() {
    if (!income.isFinite ||
        income <= 0 ||
        [expenses, debtPayments].any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError(
          'Ingresos mayores a cero; gastos y deudas no negativos.');
    }
  }

  Map<String, dynamic> toMap() =>
      {'income': income, 'expenses': expenses, 'debtPayments': debtPayments};
  factory FinancialProfile.fromMap(Map<String, dynamic> m) => FinancialProfile(
      income: (m['income'] as num).toDouble(),
      expenses: (m['expenses'] as num).toDouble(),
      debtPayments: (m['debtPayments'] as num).toDouble());
}

class ScoringRules {
  final int version;
  final double maxDti;
  const ScoringRules({this.version = 1, this.maxDti = 0.4});
  Map<String, dynamic> evaluate(
      FinancialProfile profile, double proposedPayment) {
    profile.validate();
    if (!maxDti.isFinite ||
        maxDti <= 0 ||
        maxDti > 1 ||
        !proposedPayment.isFinite ||
        proposedPayment < 0) {
      throw ArgumentError('Reglas inválidas.');
    }
    final dti = (profile.debtPayments + proposedPayment) / profile.income;
    final remaining = profile.income -
        profile.expenses -
        profile.debtPayments -
        proposedPayment;
    final score = ((1 - dti).clamp(0, 1) * 70 +
            (remaining / profile.income).clamp(0, 1) * 30)
        .round();
    return {
      'rulesVersion': version,
      'maxDti': maxDti,
      'dti': dti,
      'disposableIncome': remaining,
      'proposedPayment': proposedPayment,
      'score': score,
      'eligible': dti <= maxDti && remaining >= 0,
      'explanation':
          'DTI incluye deudas mensuales y la cuota máxima propuesta. Se requiere DTI ≤ ${(maxDti * 100).toStringAsFixed(0)}% y capacidad disponible no negativa. Puntaje = 70 × (1 − DTI) + 30 × proporción disponible, componentes limitados a 0–1. Reglas académicas.'
    };
  }
}
