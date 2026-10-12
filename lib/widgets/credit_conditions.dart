import 'package:flutter/material.dart';
import '../models/credit_engine.dart';
import '../utils/app_theme.dart';
import 'finance_ui.dart';

/// Always-visible costs before an administrative decision or agreement.
class CreditConditions extends StatelessWidget {
  final CreditTerms terms;
  const CreditConditions({super.key, required this.terms});
  @override
  Widget build(BuildContext context) {
    final plan = CreditEngine.schedule(terms, DateTime.now());
    String money(int cents) => 'USD ${(cents / 100).toStringAsFixed(2)}';
    final conditions = {
      'Amortización':
          terms.method == AmortizationMethod.french ? 'Francesa' : 'Alemana',
      'Tasa efectiva anual (interés y comisión propia)':
          '${CreditEngine.effectiveAnnualRate(terms).toStringAsFixed(2)}%',
      'Costo efectivo anual con seguro y FECI':
          '${CreditEngine.effectiveAnnualRate(terms, includeThirdParties: true).toStringAsFixed(2)}%',
      'FECI': terms.principal <= 5000
          ? 'No aplica por monto (hasta USD 5,000)'
          : switch (terms.feciTreatment) {
              FeciTreatment.pending =>
                'Pendiente de revisión; no incluido en esta estimación',
              FeciTreatment.applies => '1% anual sobre saldo',
              FeciTreatment.exempt => 'Exención: ${terms.feciEvidence}',
              FeciTreatment.outsideScope => 'No sujeto: ${terms.feciEvidence}',
            },
      'FECI total': money(plan.fold<int>(0, (s, r) => s + r.feciCents)),
      'Primera cuota estimada': money(plan.first.totalCents),
      'Última cuota estimada': money(plan.last.totalCents),
      'Interés total': money(plan.fold<int>(0, (s, r) => s + r.interestCents)),
      'Seguro mensual': money((terms.monthlyInsurance * 100).round()),
      'Comisión inicial': money((terms.openingFee * 100).round()),
      'Mora por cuota vencida': terms.policyVersion >= 2
          ? '${terms.lateFeePercent}% del capital impago'
          : money((terms.lateFee * 100).round()),
      'Total contractual sin mora':
          money(plan.fold<int>(0, (s, r) => s + r.totalCents)),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FinanceGrid(children: [
        FinanceMetric(
            label: 'Primera cuota estimada',
            value: money(plan.first.totalCents)),
        FinanceMetric(
            label: 'Última cuota estimada', value: money(plan.last.totalCents)),
      ]),
      const SizedBox(height: 8),
      DetailRows(Map.fromEntries(conditions.entries.where((e) => ![
            'Primera cuota estimada',
            'Última cuota estimada'
          ].contains(e.key)))),
      const SizedBox(height: 8),
      const Text(
          'Las fechas se fijan al desembolsar. La cancelación total descuenta intereses futuros sin penalización. La tasa efectiva incluye la comisión propia; el costo efectivo agrega seguro destinado a terceros y FECI. Cálculo con flujos mensuales.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5))
    ]);
  }
}
