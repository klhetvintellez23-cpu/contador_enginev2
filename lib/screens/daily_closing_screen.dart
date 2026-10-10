import '../utils/app_theme.dart';
import '../widgets/app_ui.dart';
import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/debt_provider.dart';
import '../utils/shared_styles.dart';

class DailyClosingScreen extends StatelessWidget {
  const DailyClosingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateLabel = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: PageFrame(
          child: Column(
        children: [
          PageHeading(title: 'Cierre del día', subtitle: dateLabel, back: true),
          Expanded(
            child: Consumer<DebtProvider>(
              builder: (context, provider, child) {
                final closing = provider.dailyClosing;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero: Cobrado hoy
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Cobrado hoy',
                                        style:
                                            TextStyle(color: AppTheme.muted)),
                                    const SizedBox(height: 10),
                                    Text(
                                        currency.format(
                                            closing.totalCollectedToday),
                                        style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Text(
                                        '${closing.paymentsCountToday} pagos registrados',
                                        style: const TextStyle(
                                            color: AppTheme.muted)),
                                  ]))),

                      const SizedBox(height: 20),

                      Text('RESUMEN', style: sectionCaptionStyle()),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [],
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              icon: Icons.add_chart_rounded,
                              color: const Color(0xFF8B5CF6),
                              label: 'Préstamos nuevos',
                              value: '${closing.newLoansToday}',
                            ),
                            _SummaryRow(
                              icon: Icons.account_balance_wallet_rounded,
                              color: const Color(0xFF6D28D9),
                              label: 'Capital entregado',
                              value: currency
                                  .format(closing.capitalDeliveredToday),
                            ),
                            _SummaryRow(
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFEF4444),
                              label: 'Clientes atrasados',
                              value: '${closing.overdueCustomersCount}',
                            ),
                            _SummaryRow(
                                icon: Icons.trending_up_rounded,
                                color: AppTheme.primary,
                                label: 'Interés cobrado',
                                value: currency
                                    .format(closing.estimatedInterestToday),
                                isLast: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(text: closing.reportText),
                            );
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Compartir cierre del día'),
                          style: solidActionButtonStyle(context).copyWith(
                            minimumSize: WidgetStateProperty.all(
                                const Size(double.infinity, 54)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isLast;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                value,
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Colors.grey.shade100),
      ],
    );
  }
}
