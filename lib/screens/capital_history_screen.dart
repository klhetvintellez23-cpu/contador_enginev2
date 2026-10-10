import '../widgets/app_ui.dart';
import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/debt_provider.dart';

/// Historial completo de movimientos de capital. `capitalHistory` ya está
/// cargado por completo en memoria (lo usa el cálculo de `initialCapital`),
/// así que acá no hace falta paginar contra la base local.
class CapitalHistoryScreen extends StatelessWidget {
  const CapitalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: PageFrame(
          child: Column(
        children: [
          const PageHeading(title: 'Capital', back: true),
          Expanded(
            child: Consumer<DebtProvider>(
              builder: (context, provider, child) {
                final history = provider.capitalHistory;
                if (history.isEmpty) {
                  return Center(
                    child: Text('No hay movimientos registrados aún.',
                        style:
                            AppFonts.inter(fontSize: 13, color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    final isPositive = entry.amount >= 0;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPositive
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: isPositive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.note ?? 'Sin descripción',
                                  style: AppFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B)),
                                ),
                                Text(
                                  DateFormat('dd MMM, yyyy - HH:mm')
                                      .format(entry.createdAt),
                                  style: AppFonts.inter(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isPositive ? '+' : ''}${currencyFormat.format(entry.amount)}',
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPositive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}
