import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/credit_engine.dart';
import '../utils/app_theme.dart';
import 'finance_ui.dart';
import 'credit_conditions.dart';

class CreditOverview extends StatelessWidget {
  final Map<String, dynamic> application;
  final Widget badge;
  final Widget? progress;
  final String? lifecycle;
  const CreditOverview(
      {super.key,
      required this.application,
      required this.badge,
      this.progress,
      this.lifecycle});
  @override
  Widget build(BuildContext context) {
    final name = application['applicant'] as String;
    final terms = application['terms'] as Map;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.neutral,
            foregroundColor: AppTheme.ink,
            child: Text(name.isEmpty ? '?' : name[0],
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(application['purpose'] as String,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
        ])),
      ]),
      const SizedBox(height: 16),
      Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            badge,
            if (lifecycle != null)
              Text(lifecycle!,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))
          ]),
      const SizedBox(height: 20),
      const Text('Monto solicitado',
          style: TextStyle(color: AppTheme.muted, fontSize: 13)),
      const SizedBox(height: 6),
      Text(money.format(terms['principal']),
          style: const TextStyle(
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4)),
    ]);
    final metrics = FinanceGrid(children: [
      FinanceMetric(
          label: 'Plazo',
          value: '${terms['months']} meses',
          icon: Icons.schedule_rounded),
      FinanceMetric(
          label: 'Tasa nominal anual',
          value: '${terms['annualRate']}%',
          icon: Icons.percent_rounded),
    ]);
    return FinanceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 680
              ? Row(children: [
                  Expanded(child: identity),
                  const SizedBox(width: 24),
                  Expanded(child: metrics)
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 20), metrics])),
      if (progress != null) ...[const SizedBox(height: 22), progress!],
    ]));
  }
}

class CreditFinancialSummary extends StatelessWidget {
  final Map<String, dynamic> application;
  const CreditFinancialSummary({super.key, required this.application});
  @override
  Widget build(BuildContext context) {
    final profile = application['profile'] as Map;
    final evaluation = application['evaluation'] as Map?;
    final money = NumberFormat.currency(symbol: 'USD ', decimalDigits: 2);
    return FinanceGrid(minItemWidth: 340, children: [
      FinanceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          IconMedallion(Icons.receipt_long_outlined),
          SizedBox(width: 12),
          Expanded(
              child: Text('Condiciones del crédito',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))
        ]),
        const SizedBox(height: 20),
        CreditConditions(
            terms: CreditTerms.fromMap(
                Map<String, dynamic>.from(application['terms'] as Map))),
      ])),
      Column(children: [
        FinanceCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            IconMedallion(Icons.account_balance_wallet_outlined),
            SizedBox(width: 12),
            Expanded(
                child: Text('Capacidad de pago',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))
          ]),
          const SizedBox(height: 18),
          DetailRows({
            'Ingresos mensuales': money.format(profile['income']),
            'Gastos mensuales': money.format(profile['expenses']),
            'Cuotas de otras deudas': money.format(profile['debtPayments']),
          }),
        ])),
        if (evaluation != null) ...[
          const SizedBox(height: 12),
          FinanceCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Evaluación financiera',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                FinanceGrid(children: [
                  FinanceMetric(
                      label: 'DTI · deuda / ingresos',
                      value:
                          '${((evaluation['dti'] as num) * 100).toStringAsFixed(2)}%'),
                  FinanceMetric(
                      label: 'Puntaje sobre 100',
                      value: '${evaluation['score']}'),
                ]),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                    value: (evaluation['dti'] as num).toDouble().clamp(0, 1),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.neutral,
                    semanticsLabel: 'Relación entre deuda e ingresos'),
                const SizedBox(height: 12),
                DetailRows({
                  'Disponible tras cuota':
                      money.format(evaluation['disposableIncome'])
                }),
                const SizedBox(height: 8),
                Text(
                    evaluation['eligible'] == true
                        ? 'Recomendación favorable'
                        : 'Recomendación no favorable',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    'Reglas v${evaluation['rulesVersion']}: ${evaluation['explanation']}',
                    style: const TextStyle(
                        color: AppTheme.muted, fontSize: 12, height: 1.5)),
              ])),
        ],
      ]),
    ]);
  }
}
