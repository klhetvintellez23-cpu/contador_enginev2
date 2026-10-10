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
      'Primera cuota estimada': money(plan.first.totalCents),
      'Última cuota estimada': money(plan.last.totalCents),
      'Interés total': money(plan.fold<int>(0, (s, r) => s + r.interestCents)),
      'Seguro mensual': money((terms.monthlyInsurance * 100).round()),
      'Comisión inicial': money((terms.openingFee * 100).round()),
      'Mora por cuota vencida': money((terms.lateFee * 100).round()),
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
          'Las fechas se fijan al desembolsar. Los anticipos cubren cuotas; el motor actual no recalcula intereses por prepago.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5))
    ]);
  }
}
