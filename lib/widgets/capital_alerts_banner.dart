import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/insights.dart';
import '../providers/debt_provider.dart';
import '../screens/customer_detail_screen.dart';

/// Lista de alertas inteligentes sobre el capital/cartera, mostrada en el
/// dashboard. Se oculta por completo si no hay nada que avisar.
class CapitalAlertsBanner extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  /// Llamado justo antes de navegar al cliente relacionado (ej: para cerrar
  /// el bottom sheet de notificaciones que contiene esta lista).
  final VoidCallback? onTapAlert;

  const CapitalAlertsBanner({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 8),
    this.onTapAlert,
  });

  Color _colorFor(CapitalAlertSeverity severity) {
    switch (severity) {
      case CapitalAlertSeverity.critical:
        return const Color(0xFFEF4444);
      case CapitalAlertSeverity.warning:
        return const Color(0xFFF59E0B);
      case CapitalAlertSeverity.info:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _iconFor(CapitalAlertType type) {
    switch (type) {
      case CapitalAlertType.lowCapital:
        return Icons.account_balance_wallet_rounded;
      case CapitalAlertType.overLent:
        return Icons.trending_up_rounded;
      case CapitalAlertType.riskConcentration:
        return Icons.pie_chart_rounded;
      case CapitalAlertType.manyOverdue:
        return Icons.report_gmailerrorred_rounded;
      case CapitalAlertType.lowWeeklyRecovery:
        return Icons.trending_down_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, provider, child) {
        final alerts = provider.capitalAlerts;
        if (alerts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: padding,
          child: Column(
            children: alerts.map((alert) {
              final color = _colorFor(alert.severity);
              Customer? relatedCustomer;
              if (alert.relatedCustomerId != null) {
                relatedCustomer =
                    provider.getCustomerById(alert.relatedCustomerId);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: relatedCustomer == null
                        ? null
                        : () {
                            onTapAlert?.call();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(
                                    customer: relatedCustomer!),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withAlpha(64)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_iconFor(alert.type), color: color, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: AppFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alert.message,
                                  style: AppFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (relatedCustomer != null)
                            Icon(Icons.chevron_right_rounded,
                                color: color, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
