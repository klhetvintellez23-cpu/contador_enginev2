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
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateLabel = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20,
              left: 12,
              right: 28,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Cierre del día',
                      style: AppFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    dateLabel,
                    style: AppFonts.inter(
                        color: Colors.white.withAlpha(204), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<DebtProvider>(
              builder: (context, provider, child) {
                final closing = provider.dailyClosing;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero: Cobrado hoy
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3310B981),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -12,
                              right: -8,
                              child: Icon(
                                Icons.payments_rounded,
                                size: 90,
                                color: Colors.white.withAlpha(30),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(38),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.wb_sunny_rounded,
                                          color: Colors.white, size: 12),
                                      const SizedBox(width: 5),
                                      Text(
                                        'COBRADO HOY',
                                        style: AppFonts.inter(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  currency.format(closing.totalCollectedToday),
                                  style: AppFonts.inter(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  closing.paymentsCountToday == 0
                                      ? 'Sin pagos registrados hoy'
                                      : '${closing.paymentsCountToday} pago${closing.paymentsCountToday == 1 ? '' : 's'} registrado${closing.paymentsCountToday == 1 ? '' : 's'}',
                                  style: AppFonts.inter(
                                    color: Colors.white.withAlpha(210),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Grid 2x2 métricas secundarias
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.3,
                        children: [
                          _MetricCard(
                            icon: Icons.add_chart_rounded,
                            color: const Color(0xFF8B5CF6),
                            label: 'Préstamos nuevos',
                            value: '${closing.newLoansToday}',
                          ),
                          _MetricCard(
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF6D28D9),
                            label: 'Capital entregado',
                            value:
                                currency.format(closing.capitalDeliveredToday),
                          ),
                          _MetricCard(
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEF4444),
                            label: 'Clientes atrasados',
                            value: '${closing.overdueCustomersCount}',
                          ),
                          _MetricCard(
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFFF59E0B),
                            label: 'Ganancia (interés)*',
                            value:
                                currency.format(closing.estimatedInterestToday),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(
                        '* Interés cobrado hoy: la parte de cada pago que cubrió intereses antes de amortizar capital.',
                        style: AppFonts.inter(
                            fontSize: 11, color: Colors.grey[400]),
                      ),

                      const SizedBox(height: 28),
                      Text('RESUMEN', style: sectionCaptionStyle()),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(6),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              icon: Icons.payments_rounded,
                              color: const Color(0xFF10B981),
                              label: 'Cobrado hoy',
                              value:
                                  currency.format(closing.totalCollectedToday),
                            ),
                            _SummaryRow(
                              icon: Icons.receipt_long_rounded,
                              color: const Color(0xFF3B82F6),
                              label: 'Pagos registrados',
                              value: '${closing.paymentsCountToday}',
                            ),
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
                              isLast: true,
                            ),
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
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(7),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: const Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style:
                      AppFonts.inter(fontSize: 11.5, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
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
