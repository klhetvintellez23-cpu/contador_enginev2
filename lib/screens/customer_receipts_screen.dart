import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/customer.dart';
import '../services/local_cache_service.dart';

/// Historial de comprobantes generados para un cliente, ordenados del más
/// reciente al más antiguo, para poder revisarlos o reenviarlos sin tener
/// que ir cobro por cobro.
class CustomerReceiptsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerReceiptsScreen({super.key, required this.customer});

  @override
  State<CustomerReceiptsScreen> createState() => _CustomerReceiptsScreenState();
}

class _CustomerReceiptsScreenState extends State<CustomerReceiptsScreen> {
  late final List<Map<String, dynamic>> _receipts =
      LocalCacheService().receiptsForCustomer(widget.customer.id.toString());
  DateTimeRange? _selectedRange;

  List<Map<String, dynamic>> get _filteredReceipts {
    final range = _selectedRange;
    if (range == null) return _receipts;
    final start =
        DateTime(range.start.year, range.start.month, range.start.day);
    final end =
        DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    return _receipts.where((r) {
      final date = DateTime.tryParse(r['date'] as String? ?? '');
      if (date == null) return false;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      helpText: 'Filtrar por fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (range != null) setState(() => _selectedRange = range);
  }

  void _clearDateRange() => setState(() => _selectedRange = null);

  Future<void> _resend(Map<String, dynamic> receipt) async {
    final path = receipt['filePath'] as String?;
    if (path == null || !await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Este comprobante ya no está disponible en el celular.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM, yyyy - hh:mm a');
    final rangeFormat = DateFormat('dd/MM/yyyy');
    final receipts = _filteredReceipts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20,
              left: 12,
              right: 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Comprobantes de ${widget.customer.name.split(' ').first}',
                    style: AppFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedRange != null)
                  IconButton(
                    icon:
                        const Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: 'Quitar filtro de fecha',
                    onPressed: _clearDateRange,
                  ),
                IconButton(
                  icon: Icon(Icons.calendar_today_rounded,
                      color: _selectedRange != null
                          ? Colors.white
                          : Colors.white.withAlpha(179)),
                  tooltip: 'Filtrar por fecha',
                  onPressed: _pickDateRange,
                ),
              ],
            ),
          ),
          if (_selectedRange != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Del ${rangeFormat.format(_selectedRange!.start)} al ${rangeFormat.format(_selectedRange!.end)}',
                    style:
                        AppFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _receipts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Todavía no hay comprobantes generados para este cliente.',
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : receipts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No hay comprobantes en ese rango de fechas.',
                                textAlign: TextAlign.center,
                                style: AppFonts.inter(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _clearDateRange,
                                child: const Text('Restablecer filtro'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        itemCount: receipts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final receipt = receipts[index];
                          final date = DateTime.tryParse(
                              receipt['date'] as String? ?? '');
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.primary.withAlpha(26),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.receipt_long_rounded,
                                      color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currency.format(
                                            (receipt['amount'] as num)
                                                .toDouble()),
                                        style: AppFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      Text(
                                        receipt['loanTitle'] as String? ??
                                            'Préstamo',
                                        style: AppFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (date != null)
                                        Text(
                                          dateFormat.format(date),
                                          style: AppFonts.inter(
                                              fontSize: 11,
                                              color: Colors.grey[400]),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.ios_share_rounded,
                                      color: theme.colorScheme.primary),
                                  tooltip: 'Reenviar',
                                  onPressed: () => _resend(receipt),
                                ),
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
