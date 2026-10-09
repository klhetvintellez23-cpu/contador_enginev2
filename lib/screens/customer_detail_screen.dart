import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/local_fonts.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../providers/debt_provider.dart';
import '../models/transaction.dart';

import '../utils/receipt_share_helper.dart';
import '../utils/phone_helper.dart';
import '../utils/sensitive_action_guard.dart';
import '../utils/shared_styles.dart';
import 'customer_receipts_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // Header Background and Content
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 18,
              left: 20,
              right: 16,
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(102)),
                  ),
                  child: Center(
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: AppFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer.name,
                        style: AppFonts.inter(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.cedula != null && customer.cedula!.isNotEmpty
                            ? 'ID: ${customer.cedula}'
                            : 'Sin identificación',
                        style: AppFonts.inter(
                          color: Colors.white.withAlpha(204),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerReceiptsScreen(customer: customer),
                    ),
                  ),
                  tooltip: 'Comprobantes',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white, size: 22),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditCustomerDialog(context);
                    } else if (value == 'delete') {
                      requireSensitiveActionUnlock(
                        context,
                        reason:
                            'Vas a eliminar a ${customer.name} y todo su historial.',
                        onUnlocked: () => _showDeleteConfirmation(context),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          const Text('Editar cliente'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: Color(0xFFEF4444)),
                          SizedBox(width: 10),
                          Text('Eliminar cliente',
                              style: TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                Consumer<DebtProvider>(
                  builder: (context, provider, child) {
                    final loans = provider.getLoansByCustomer(customer.id!);

                    if (loans.isEmpty) {
                      final t = Theme.of(context);
                      return SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: t.colorScheme.primary.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    size: 40,
                                    color: t.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sin préstamos activos',
                                  style: AppFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: const Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Registrá el primer préstamo de ${customer.name} desde el botón "+" del inicio.',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.inter(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _LoanCard(
                              loan: loans[index],
                              customer: customer,
                              currencyFormat: currencyFormat,
                            );
                          },
                          childCount: loans.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: dialogShape(),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        title: Text('¿Eliminar cliente?',
            style: AppFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFFEF4444))),
        content: dialogContent([
          Text(
            'Esta acción eliminará permanentemente a ${customer.name} y todo su historial de préstamos y cobros. Esta acción no se puede deshacer.',
            style: AppFonts.inter(fontSize: 13, color: Colors.grey[500]),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text('Cancelar',
                style: AppFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Provider.of<DebtProvider>(context, listen: false)
                    .deleteCustomer(customer.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Cliente eliminado: ${customer.name}'),
                      backgroundColor: const Color(0xFFEF4444)),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Error al eliminar: puede que el cliente tenga deudas activas.'),
                      backgroundColor: Color(0xFFF59E0B)),
                );
              }
            },
            style:
                solidActionButtonStyle(context, color: const Color(0xFFEF4444)),
            child: const Text('Eliminar Cliente'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController =
        TextEditingController(text: displayLocalPhone(customer.phone));
    final cedulaController = TextEditingController(text: customer.cedula);

    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: dialogShape(),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        title: Text('Editar cliente',
            style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        content: dialogContent([
          Text('Actualiza los datos de ${customer.name}.',
              style: AppFonts.inter(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: minimalFieldDecoration(label: 'Nombre completo'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: phoneController,
            decoration: minimalFieldDecoration(
              label: 'Teléfono',
              hint: 'Ej: 61234567',
              helper: 'Se guarda como +507 para enviar por WhatsApp',
              prefixText: '$panamaCountryCode  ',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: cedulaController,
            decoration: minimalFieldDecoration(label: 'Cédula / ID'),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text('Cancelar',
                style: AppFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Provider.of<DebtProvider>(context, listen: false)
                    .updateCustomer(
                        customer.id,
                        nameController.text,
                        normalizePanamaPhone(phoneController.text),
                        cedulaController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cliente actualizado')),
                );
              }
            },
            style: solidActionButtonStyle(context),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
      cedulaController.dispose();
    });
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppFonts.inter(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value,
            style: AppFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _LoanCard extends StatefulWidget {
  final LoanTransaction loan;
  final Customer customer;
  final NumberFormat currencyFormat;

  const _LoanCard({
    required this.loan,
    required this.customer,
    required this.currencyFormat,
  });

  @override
  State<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<_LoanCard> {
  bool _savingPayment = false;

  bool _isExpanded = false;

  String _rateLabel() {
    final loan = widget.loan;
    final periodLabel = loan.incrementPeriod.label.toLowerCase();
    if (loan.incrementType == IncrementType.percentage) {
      final pct = loan.incrementValue;
      final pctStr = pct == pct.roundToDouble()
          ? pct.toStringAsFixed(0)
          : pct.toStringAsFixed(2);
      return '$pctStr% cada $periodLabel';
    }
    return '${widget.currencyFormat.format(loan.incrementValue)} cada $periodLabel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<DebtProvider>().loanState(widget.loan);
    final currentDebt = state.totalDebt;
    final isFullyPaid = state.isSettled;
    final hasInterest = widget.loan.incrementValue > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.loan.title,
                      style: AppFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: _isExpanded ? null : 2,
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (widget.loan.incrementValue > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _rateLabel(),
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (widget.loan.title.length > 30)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _isExpanded ? 'Ver menos' : 'Ver más...',
                            style: AppFonts.inter(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isFullyPaid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B))
                      .withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFullyPaid ? 'LIQUIDADO' : 'PENDIENTE',
                  style: AppFonts.inter(
                    color: isFullyPaid
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.grey[400], size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'delete') {
                    requireSensitiveActionUnlock(
                      context,
                      reason:
                          'Vas a eliminar el préstamo "${widget.loan.title}".',
                      onUnlocked: () => _confirmDeleteLoan(context),
                    );
                  } else if (value == 'toggle_accumulate') {
                    final newValue = !widget.loan.accumulateOverdueInterest;
                    context
                        .read<DebtProvider>()
                        .setAccumulateOverdueInterest(widget.loan.id, newValue);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newValue
                            ? 'Este préstamo acumulará el interés vencido (Opción B).'
                            : 'Este préstamo NO acumulará interés vencido (Opción A).'),
                        backgroundColor: const Color(0xFF7C3AED),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (hasInterest)
                    PopupMenuItem(
                      value: 'toggle_accumulate',
                      child: Row(
                        children: [
                          Icon(
                            widget.loan.accumulateOverdueInterest
                                ? Icons.layers_clear_rounded
                                : Icons.layers_rounded,
                            size: 18,
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 10),
                          Text(widget.loan.accumulateOverdueInterest
                              ? 'No acumular interés vencido'
                              : 'Acumular interés vencido'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFEF4444)),
                        SizedBox(width: 10),
                        Text('Eliminar préstamo'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailItem(
                  label: 'Monto Inicial',
                  value:
                      widget.currencyFormat.format(widget.loan.initialAmount)),
              _DetailItem(
                  label: 'Abonado',
                  value: widget.currencyFormat.format(state.totalPaid)),
            ],
          ),
          if (hasInterest) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DetailItem(
                    label: 'Capital pendiente',
                    value:
                        widget.currencyFormat.format(state.outstandingCapital)),
                _DetailItem(
                    label: 'Interés pendiente',
                    value: widget.currencyFormat.format(state.pendingInterest)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Por cobrar',
                        style: AppFonts.inter(
                            color: Colors.grey[600], fontSize: 12)),
                    if (!isFullyPaid && hasInterest)
                      Text('Capital + interés sobre saldo',
                          style: AppFonts.inter(
                              fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
                Text(
                  // Nunca se muestra en negativo: un préstamo saldado (o
                  // pagado de más) confunde al prestamista si parece una
                  // pérdida en vez de una deuda en $0.
                  widget.currencyFormat
                      .format(currentDebt > 0 ? currentDebt : 0),
                  style: AppFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isFullyPaid
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!isFullyPaid)
            ElevatedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _innerShowPaymentDialog(context, widget.loan, widget.customer);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withAlpha(77),
              ),
              child: const Text('COBRAR PAGO',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            )
          else
            ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('DEUDA CANCELADA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: const Color(0xFF10B981).withAlpha(31),
                disabledForegroundColor: const Color(0xFF059669),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          _PaymentHistorySection(
            loan: widget.loan,
            currencyFormat: widget.currencyFormat,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLoan(BuildContext context) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: dialogShape(),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        title: Text('¿Eliminar préstamo?',
            style: AppFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFFEF4444))),
        content: dialogContent([
          Text(
            'Se eliminará "${widget.loan.title}" junto con todos sus cobros registrados. Esta acción no se puede deshacer.',
            style: AppFonts.inter(fontSize: 13, color: Colors.grey[500]),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text('Cancelar',
                style: AppFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await Provider.of<DebtProvider>(context, listen: false)
                  .deleteLoan(widget.loan.id);
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                    content: Text('Préstamo eliminado.'),
                    backgroundColor: Color(0xFFEF4444)),
              );
            },
            style:
                solidActionButtonStyle(context, color: const Color(0xFFEF4444)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _innerShowPaymentDialog(
      BuildContext context, LoanTransaction loan, Customer customer) {
    final controller = TextEditingController();
    final provider = Provider.of<DebtProvider>(context, listen: false);

    showBlurDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: dialogShape(),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        title: Text('Registrar cobro a ${customer.name.split(' ')[0]}',
            style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        content: dialogContent([
          Text('Registra el cobro recibido de ${customer.name}:',
              style: AppFonts.inter(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: minimalFieldDecoration(label: 'Monto USD'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text('Cancelar',
                style: AppFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_savingPayment) return;
              final amount =
                  double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (amount == null || !amount.isFinite || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Ingresa un monto válido mayor que cero.')));
                return;
              }
              _savingPayment = true;
              try {
                final payment = await provider.registerPayment(
                    loan.id!, amount, customer.name);
                if (!context.mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Cobro guardado correctamente.')));
                await ReceiptShareHelper.shareReceiptForPayment(
                    context: context,
                    payment: payment,
                    loan: loan,
                    customer: customer,
                    remaining: provider.currentDebt(loan),
                    businessName: provider.businessName,
                    businessLogoPath: provider.businessLogoPath);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              } finally {
                _savingPayment = false;
              }
            },
            style: solidActionButtonStyle(context),
            child: const Text('Cobrar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _PaymentHistorySection extends StatefulWidget {
  final LoanTransaction loan;
  final NumberFormat currencyFormat;

  const _PaymentHistorySection(
      {required this.loan, required this.currencyFormat});

  @override
  State<_PaymentHistorySection> createState() => _PaymentHistorySectionState();
}

class _PaymentHistorySectionState extends State<_PaymentHistorySection> {
  bool _expanded = false;
  bool _interestExpanded = false;

  void _showEditPaymentDialog(BuildContext context, Payment payment) {
    final amountController =
        TextEditingController(text: payment.amount.toStringAsFixed(2));
    DateTime selectedDate = payment.date;

    showBlurDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: dialogShape(),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            title: Text('Editar cobro',
                style:
                    AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
            content: dialogContent([
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration:
                    minimalFieldDecoration(label: 'Monto', prefixText: '\$ '),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        selectedDate.hour,
                        selectedDate.minute,
                      );
                    });
                  }
                },
                child: InputDecorator(
                  decoration: minimalFieldDecoration(label: 'Fecha'),
                  child: Text(
                    DateFormat('dd MMM, yyyy').format(selectedDate),
                    style: AppFonts.inter(fontSize: 14),
                  ),
                ),
              ),
            ]),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: Text('Cancelar',
                    style: AppFonts.inter(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newAmount =
                      double.tryParse(amountController.text.trim());
                  if (newAmount == null || newAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Ingresa un monto válido.'),
                          backgroundColor: Color(0xFFEF4444)),
                    );
                    return;
                  }
                  final navigator = Navigator.of(context);
                  await Provider.of<DebtProvider>(context, listen: false)
                      .editPayment(
                    payment.id,
                    widget.loan.id,
                    oldAmount: payment.amount,
                    newAmount: newAmount,
                    newDate: selectedDate,
                  );
                  navigator.pop();
                },
                style: solidActionButtonStyle(context),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(amountController.dispose);
  }

  void _confirmDelete(BuildContext context, Payment payment) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: dialogShape(),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        title: Text('¿Deshacer este cobro?',
            style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        content: dialogContent([
          Text(
            'Se eliminará el cobro de ${widget.currencyFormat.format(payment.amount)} y se restará del saldo abonado de este préstamo.',
            style: AppFonts.inter(fontSize: 13, color: Colors.grey[500]),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text('Cancelar',
                style: AppFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await Provider.of<DebtProvider>(context, listen: false)
                  .deletePayment(payment.id, widget.loan.id, payment.amount);
              navigator.pop();
            },
            style:
                solidActionButtonStyle(context, color: const Color(0xFFEF4444)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, provider, child) {
        final payments = provider.allPayments
            .where((p) => p.loanId == widget.loan.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        // Desglose interés/capital de cada cobro, para mostrarlo en la lista.
        final state = provider.loanState(widget.loan);
        final breakdownByPayment = {
          for (final b in state.breakdowns) b.payment.id: b,
        };
        final hasInterest = widget.loan.incrementValue > 0;
        // Historial de generación de interés (más reciente primero).
        final accruals = state.accruals.reversed.toList();

        if (payments.isEmpty && accruals.isEmpty) {
          return const SizedBox.shrink();
        }

        final dateFormat = DateFormat('dd MMM, yyyy - hh:mm a');

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payments.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text('Historial de cobros (${payments.length})',
                          style: AppFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                      const Spacer(),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    children: payments.map((p) {
                      final b = breakdownByPayment[p.id];
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.arrow_downward_rounded,
                                  size: 14, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateFormat.format(p.date),
                                      style: AppFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  if (hasInterest && b != null)
                                    Text(
                                      'Interés ${widget.currencyFormat.format(b.toInterest)} · Capital ${widget.currencyFormat.format(b.toCapital)}',
                                      style: AppFonts.inter(
                                          fontSize: 10.5,
                                          color: Colors.grey[400]),
                                    ),
                                ],
                              ),
                            ),
                            Text(widget.currencyFormat.format(p.amount),
                                style: AppFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF059669))),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 15, color: Colors.grey),
                              onPressed: () => requireSensitiveActionUnlock(
                                context,
                                reason: 'Vas a editar un cobro registrado.',
                                onUnlocked: () =>
                                    _showEditPaymentDialog(context, p),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 16, color: Colors.grey),
                              onPressed: () => requireSensitiveActionUnlock(
                                context,
                                reason: 'Vas a deshacer un cobro registrado.',
                                onUnlocked: () => _confirmDelete(context, p),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
              if (hasInterest && accruals.isNotEmpty) ...[
                if (payments.isNotEmpty) const SizedBox(height: 14),
                GestureDetector(
                  onTap: () =>
                      setState(() => _interestExpanded = !_interestExpanded),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text('Intereses generados (${accruals.length})',
                          style: AppFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                      const Spacer(),
                      Icon(
                        _interestExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    children: accruals.map((a) {
                      final rateLabel = a.isPercentage
                          ? '${a.rate.toStringAsFixed(a.rate == a.rate.roundToDouble() ? 0 : 2)}%'
                          : widget.currencyFormat.format(a.rate);
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.trending_up_rounded,
                                  size: 14, color: Color(0xFFF59E0B)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${dateFormat.format(a.date)} · ${widget.loan.incrementPeriod.label.toLowerCase()} ${a.periodIndex}',
                                      style: AppFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  Text(
                                    '$rateLabel sobre ${widget.currencyFormat.format(a.capitalBase)} de capital',
                                    style: AppFonts.inter(
                                        fontSize: 10.5,
                                        color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                                '+${widget.currencyFormat.format(a.interestGenerated)}',
                                style: AppFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD97706))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  crossFadeState: _interestExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
