import 'customer.dart';
import 'transaction.dart';

/// Modelos de solo lectura calculados en memoria por [DebtProvider] a partir
/// de los datos existentes (clientes, préstamos, pagos). No se persisten ni
/// tienen su propia tabla: se recalculan cada vez que se consultan.

enum CollectionStatus { overdue, dueToday, upcoming }

extension CollectionStatusX on CollectionStatus {
  String get label {
    switch (this) {
      case CollectionStatus.overdue:
        return 'Atrasado';
      case CollectionStatus.dueToday:
        return 'Toca hoy';
      case CollectionStatus.upcoming:
        return 'Próximo';
    }
  }
}

/// Un préstamo que probablemente toca cobrar hoy (o muy pronto), con el
/// monto sugerido a cobrar en esta visita.
class CollectionForecastItem {
  final Customer customer;
  final LoanTransaction loan;
  final double suggestedAmount;
  final double pendingBalance;
  final int daysSinceLastPayment;
  final CollectionStatus status;

  const CollectionForecastItem({
    required this.customer,
    required this.loan,
    required this.suggestedAmount,
    required this.pendingBalance,
    required this.daysSinceLastPayment,
    required this.status,
  });
}

enum TrustLevel { excellent, good, regular, risky }

extension TrustLevelX on TrustLevel {
  String get label {
    switch (this) {
      case TrustLevel.excellent:
        return 'Excelente';
      case TrustLevel.good:
        return 'Bueno';
      case TrustLevel.regular:
        return 'Regular';
      case TrustLevel.risky:
        return 'Riesgoso';
    }
  }
}

enum CapitalAlertSeverity { info, warning, critical }

enum CapitalAlertType {
  lowCapital,
  overLent,
  riskConcentration,
  manyOverdue,
  lowWeeklyRecovery,
}

/// Alerta accionable sobre el estado del capital/cartera, mostrada en el
/// dashboard. [relatedCustomerId] permite saltar directo al cliente
/// involucrado cuando aplica (ej: concentración de riesgo).
class CapitalAlert {
  final CapitalAlertType type;
  final CapitalAlertSeverity severity;
  final String title;
  final String message;
  final dynamic relatedCustomerId;

  const CapitalAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.relatedCustomerId,
  });
}

/// Resumen del cierre del día: cobros, préstamos nuevos y capital movido
/// desde la medianoche hasta ahora.
class DailyClosingSummary {
  final double totalCollectedToday;
  final int paymentsCountToday;
  final int newLoansToday;
  final double capitalDeliveredToday;
  final int overdueCustomersCount;
  final double estimatedInterestToday;
  final String reportText;

  const DailyClosingSummary({
    required this.totalCollectedToday,
    required this.paymentsCountToday,
    required this.newLoansToday,
    required this.capitalDeliveredToday,
    required this.overdueCustomersCount,
    required this.estimatedInterestToday,
    required this.reportText,
  });
}
