import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/insights.dart';
import '../providers/debt_provider.dart';
import '../utils/phone_helper.dart';
import 'customer_detail_screen.dart';

/// Predicción de cobros del día: préstamos que, según su frecuencia y la
/// fecha del último cobro (o de inicio si aún no tiene ninguno), toca
/// visitar hoy — ya sea porque están atrasados, cumplen su ciclo hoy, o lo
/// cumplen mañana (aviso anticipado).
class TodaysCollectionsScreen extends StatefulWidget {
  const TodaysCollectionsScreen({super.key});

  @override
  State<TodaysCollectionsScreen> createState() =>
      _TodaysCollectionsScreenState();
}

class _TodaysCollectionsScreenState extends State<TodaysCollectionsScreen> {
  CollectionStatus? _filter;

  Color _statusColor(CollectionStatus status) {
    switch (status) {
      case CollectionStatus.overdue:
        return const Color(0xFFEF4444);
      case CollectionStatus.dueToday:
        return const Color(0xFF10B981);
      case CollectionStatus.upcoming:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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
                      'Cobros de hoy',
                      style: AppFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Clientes que probablemente toca visitar hoy.',
                  style: AppFonts.inter(
                      color: Colors.white.withAlpha(204), fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todos',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Atrasados',
                    color: _statusColor(CollectionStatus.overdue),
                    selected: _filter == CollectionStatus.overdue,
                    onTap: () =>
                        setState(() => _filter = CollectionStatus.overdue),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Toca hoy',
                    color: _statusColor(CollectionStatus.dueToday),
                    selected: _filter == CollectionStatus.dueToday,
                    onTap: () =>
                        setState(() => _filter = CollectionStatus.dueToday),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Próximos',
                    color: _statusColor(CollectionStatus.upcoming),
                    selected: _filter == CollectionStatus.upcoming,
                    onTap: () =>
                        setState(() => _filter = CollectionStatus.upcoming),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer<DebtProvider>(
              builder: (context, provider, child) {
                final items = provider.todaysCollections
                    .where((i) => _filter == null || i.status == _filter)
                    .toList();

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_rounded,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'Nada que cobrar por ahora.',
                            style: AppFonts.inter(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final color = _statusColor(item.status);

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailScreen(customer: item.customer),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withAlpha(8),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.customer.name,
                                      style: AppFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(26),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.status.label,
                                      style: AppFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: color),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.customer.phone != null &&
                                  item.customer.phone!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.phone_outlined,
                                        size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 3),
                                    Text(
                                      displayLocalPhone(item.customer.phone),
                                      style: AppFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Sugerido',
                                          style: AppFonts.inter(
                                              fontSize: 10,
                                              color: Colors.grey[500])),
                                      Text(
                                        currency.format(item.suggestedAmount),
                                        style: AppFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: theme.colorScheme.primary),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Saldo pendiente',
                                          style: AppFonts.inter(
                                              fontSize: 10,
                                              color: Colors.grey[500])),
                                      Text(
                                        currency.format(item.pendingBalance),
                                        style: AppFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: const Color(0xFF475569)),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Último cobro',
                                          style: AppFonts.inter(
                                              fontSize: 10,
                                              color: Colors.grey[500])),
                                      Text(
                                        item.daysSinceLastPayment == 0
                                            ? 'Hoy'
                                            : 'Hace ${item.daysSinceLastPayment}d',
                                        style: AppFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: const Color(0xFF475569)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? chipColor : Colors.grey[200]!),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
