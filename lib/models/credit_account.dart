import 'credit_engine.dart';

/// Read adapters keep periodic loans and amortized contracts in their own stores.
abstract final class PortfolioLedger {
  static List<Map<String, dynamic>> rows(Map state, String key) =>
      ((state[key] as List?) ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  static int activePayments(Map state, String applicationId) => rows(
          state, 'credit_payments')
      .where((p) => p['applicationId'] == applicationId && p['voided'] != true)
      .fold(
          0,
          (sum, p) =>
              sum +
              (p['direction'] == 'refund' ? -1 : 1) *
                  (p['amountCents'] as int));

  /// A reconciled opening balance may already include historical cash movements.
  /// Baselines remain fixed so later voids correctly reverse the cash received.
  static int creditCashImpact(Map state) => rows(state, 'credit_accounts')
      .where((account) => account['status'] == 'active')
      .fold(
          0,
          (sum, account) =>
              sum -
              (account['cashPrincipalCents'] as int) +
              activePayments(state, account['applicationId'] as String) -
              (account['cashPaymentBaselineCents'] as int));

  static double availableCash(Map state) {
    final capital = rows(state, 'capital_history');
    final initial = capital.isNotEmpty
        ? capital.fold<double>(
            0, (sum, row) => sum + (row['amount'] as num).toDouble())
        : double.tryParse(
                ((state['settings'] as Map?)?['initial_capital'] ?? '0')
                    .toString()) ??
            0;
    final delivered = rows(state, 'loans').fold<double>(
        0, (sum, row) => sum + (row['initial_amount'] as num).toDouble());
    final collected = rows(state, 'payments')
        .fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble());
    return initial - delivered + collected + creditCashImpact(state) / 100;
  }

  static List<Map<String, dynamic>> accountBalance(Map state, Map account,
      {DateTime? asOf}) {
    final at = asOf ?? DateTime.now();
    final settlement = account['settlement'] as Map?;
    if (settlement != null &&
        !DateTime.parse(settlement['date'] as String).isAfter(at)) {
      return rows(settlement, 'closingRows');
    }
    return CreditEngine.balances(
        rows(account, 'schedule'),
        rows(state, 'credit_payments')
            .where((p) =>
                p['applicationId'] == account['applicationId'] &&
                p['kind'] != 'settlement')
            .toList(),
        (((account['terms'] as Map)['lateFee'] as num) * 100).round(),
        at);
  }
}

enum CreditLifecycle { awaitingFormalization, formalized, active, legacy }

extension CreditLifecycleLabel on CreditLifecycle {
  String get label => switch (this) {
        CreditLifecycle.awaitingFormalization => 'Pendiente de formalización',
        CreditLifecycle.formalized => 'Pendiente de desembolso',
        CreditLifecycle.active => 'Crédito activo',
        CreditLifecycle.legacy => 'Pendiente de conciliación',
      };
}
