import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/local_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/debt_provider.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../widgets/quick_loan_calculator_sheet.dart';
import '../utils/shared_styles.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  Customer? _selectedCustomer;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _incrementController = TextEditingController();
  IncrementType _incrementType = IncrementType.percentage;
  IncrementPeriod _incrementPeriod = IncrementPeriod.biweekly;
  bool _saving = false;
  bool _hasInterest = true;
  // Opción B por defecto: acumula el interés de cada vencimiento aunque el
  // anterior siga pendiente (la base siempre es el capital pendiente).
  bool _accumulateOverdueInterest = true;

  @override
  void initState() {
    super.initState();
    // Refresca el ejemplo en vivo mientras el usuario escribe.
    _amountController.addListener(_refresh);
    _incrementController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  Future<void> _showCustomerPicker(
      BuildContext context, List<Customer> customers) async {
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => _CustomerPickerSheet(customers: customers),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCustomer = selected);
    }
  }

  Future<void> _openQuickCalculator() async {
    final result = await QuickLoanCalculatorSheet.show(
      context,
      startDate: DateTime.now(),
    );
    if (result == null || !mounted) return;

    setState(() {
      _amountController.text = result.amount.toStringAsFixed(2);
      _hasInterest = result.incrementValue > 0;
      _incrementType = result.incrementType;
      _incrementPeriod = result.incrementPeriod;
      _incrementController.text = result.incrementValue > 0
          ? result.incrementValue.toStringAsFixed(2)
          : '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _incrementController.dispose();
    super.dispose();
  }

  String _buildPreviewText() {
    final amount = double.tryParse(_amountController.text.trim());
    final value = double.tryParse(_incrementController.text.trim());
    final periodLabel = _incrementPeriod.label.toLowerCase();

    if (amount == null || amount <= 0 || value == null || value <= 0) {
      return 'Completa el monto y el valor para ver un ejemplo de cómo crece la deuda.';
    }

    final increase = _incrementType == IncrementType.percentage
        ? amount * (value / 100)
        : value;
    final total = amount + increase;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return 'Ejemplo: después de 1 $periodLabel, la deuda pasaría de ${currency.format(amount)} a ${currency.format(total)}.';
  }

  Widget _buildBudgetHint(double availableBudget) {
    final entered = double.tryParse(_amountController.text.trim());
    final overBudget = entered != null && entered > availableBudget;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(
            overBudget
                ? Icons.error_outline_rounded
                : Icons.account_balance_wallet_outlined,
            size: 14,
            color: overBudget ? const Color(0xFFEF4444) : Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              overBudget
                  ? 'Supera tu presupuesto disponible (${currency.format(availableBudget)}).'
                  : 'Presupuesto disponible: ${currency.format(availableBudget)}',
              style: AppFonts.inter(
                fontSize: 11,
                color: overBudget ? const Color(0xFFEF4444) : Colors.grey[500],
                fontWeight: overBudget ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // listen:false a propósito: esta pantalla es un formulario de un solo uso.
    // Si escuchara al provider, una actualización en tiempo real de la base local
    // (p. ej. otro dispositivo editando clientes) reconstruiría el Dropdown
    // con una lista nueva de clientes y podía perder la selección del usuario
    // a mitad de llenado, causando un fallo al crear el préstamo.
    final provider = Provider.of<DebtProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20,
              left: 8,
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
                    'Nuevo Préstamo',
                    style: AppFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.calculate_rounded, color: Colors.white),
                  tooltip: 'Calculadora rápida',
                  onPressed: _openQuickCalculator,
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text(
                    'Configuración de nuevo préstamo',
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ingrese los detalles de la operación financiera.',
                    style:
                        AppFonts.inter(fontSize: 12.5, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Selección de Cliente',
                    child: PillSelector(
                      icon: Icons.person_rounded,
                      label: _selectedCustomer?.name ?? 'Seleccionar Cliente',
                      isPlaceholder: _selectedCustomer == null,
                      onTap: () =>
                          _showCustomerPicker(context, provider.customers),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Detalles del Préstamo',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: flatFieldDecoration(
                            label: 'Concepto',
                            icon: Icons.edit_note_rounded,
                          ),
                          validator: (val) =>
                              val!.isEmpty ? 'Ingresa un concepto' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _amountController,
                          decoration: flatFieldDecoration(
                            label: 'Monto Inicial (USD)',
                            icon: Icons.attach_money_rounded,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (val) =>
                              val!.isEmpty ? 'El monto es obligatorio' : null,
                        ),
                        const SizedBox(height: 8),
                        _buildBudgetHint(provider.moneyInHand),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Tipo de Préstamo',
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _hasInterest ? 'Con Intereses' : 'Sin Intereses',
                        style: AppFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: _hasInterest
                              ? const Color(0xFF7C3AED)
                              : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        _hasInterest
                            ? 'El préstamo generará cargos según la frecuencia que elijas.'
                            : 'El préstamo es a capital puro, sin intereses.',
                        style: AppFonts.inter(fontSize: 12),
                      ),
                      value: _hasInterest,
                      activeThumbColor: const Color(0xFF7C3AED),
                      onChanged: (val) => setState(() => _hasInterest = val),
                    ),
                  ),
                  if (_hasInterest) ...[
                    const SizedBox(height: 24),
                    _SectionCard(
                      title: 'Configuración de Intereses',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('¿Cómo se calcula?',
                              style: AppFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<IncrementType>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor:
                                    const Color(0xFF7C3AED),
                                selectedForegroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              segments: const [
                                ButtonSegment(
                                    value: IncrementType.percentage,
                                    label: Text('% Porcentaje')),
                                ButtonSegment(
                                    value: IncrementType.fixed,
                                    label: Text('\$ Monto fijo')),
                              ],
                              selected: {_incrementType},
                              onSelectionChanged: (newSelection) {
                                setState(
                                    () => _incrementType = newSelection.first);
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('¿Cada cuánto se cobra?',
                              style: AppFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<IncrementPeriod>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor:
                                    const Color(0xFF7C3AED),
                                selectedForegroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                textStyle: AppFonts.inter(fontSize: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              segments: const [
                                ButtonSegment(
                                    value: IncrementPeriod.daily,
                                    label: Text('Día')),
                                ButtonSegment(
                                    value: IncrementPeriod.weekly,
                                    label: Text('Semana')),
                                ButtonSegment(
                                    value: IncrementPeriod.biweekly,
                                    label: Text('Quincena')),
                                ButtonSegment(
                                    value: IncrementPeriod.monthly,
                                    label: Text('Mes')),
                              ],
                              selected: {_incrementPeriod},
                              onSelectionChanged: (newSelection) {
                                setState(() =>
                                    _incrementPeriod = newSelection.first);
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _incrementController,
                            decoration: flatFieldDecoration(
                              label: _incrementType == IncrementType.percentage
                                  ? 'Porcentaje por ${_incrementPeriod.label.toLowerCase()}'
                                  : 'Dólares por ${_incrementPeriod.label.toLowerCase()}',
                              icon: _incrementType == IncrementType.percentage
                                  ? Icons.auto_graph_rounded
                                  : Icons.add_circle_outline_rounded,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (val) =>
                                val!.isEmpty ? 'Valor requerido' : null,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withAlpha(13),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    color: Color(0xFF7C3AED), size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _buildPreviewText(),
                                    style: AppFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF1E293B),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF7C3AED),
                            value: _accumulateOverdueInterest,
                            onChanged: (val) => setState(
                                () => _accumulateOverdueInterest = val),
                            title: Text('Acumular interés vencido',
                                style: AppFonts.inter(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              _accumulateOverdueInterest
                                  ? 'En cada vencimiento se genera un nuevo interés aunque el anterior siga pendiente. La base siempre es el capital pendiente.'
                                  : 'No se genera interés nuevo mientras haya interés vencido sin pagar.',
                              style: AppFonts.inter(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  shadowColor: const Color(0xFF7C3AED).withAlpha(102),
                ),
                child: Text(
                  'CREAR PRÉSTAMO',
                  style: AppFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final customer = _selectedCustomer;
    final customerId = customer?.id;
    if (customer == null || customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, elige un cliente antes de continuar.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final initialAmount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    final rate = _hasInterest
        ? double.tryParse(_incrementController.text.trim().replaceAll(',', '.'))
        : 0.0;
    if (initialAmount == null ||
        !initialAmount.isFinite ||
        initialAmount <= 0 ||
        rate == null ||
        !rate.isFinite ||
        rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Revisa el monto y la tasa: deben ser números válidos.')));
      return;
    }
    final availableBudget =
        Provider.of<DebtProvider>(context, listen: false).moneyInHand;

    if (initialAmount > availableBudget) {
      final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      showBlurDialog(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: dialogShape(),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          title: Text('Presupuesto insuficiente',
              style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
          content: dialogContent([
            Text(
              'No puedes crear este préstamo: el monto (${currency.format(initialAmount)}) supera tu presupuesto disponible (${currency.format(availableBudget)}).\n\nAgrega más capital desde Configuración antes de continuar.',
              style: AppFonts.inter(fontSize: 13, color: Colors.grey[500]),
            ),
          ]),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: solidActionButtonStyle(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      HapticFeedback.heavyImpact();
      await Provider.of<DebtProvider>(context, listen: false).addLoan(
        customerId: customerId,
        title: _titleController.text,
        initialAmount: initialAmount,
        incrementType: _incrementType,
        incrementValue: rate,
        incrementPeriod: _incrementPeriod,
        startDate: DateTime.now(),
        accumulateOverdueInterest: _accumulateOverdueInterest,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '¡Préstamo creado! La cuenta de ${customer.name} ya está en marcha.'),
          backgroundColor: const Color(0xFF7C3AED),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: sectionCaptionStyle(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) => c.name.toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Seleccionar cliente',
                  style: AppFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _query = val.trim().toLowerCase()),
                decoration: flatFieldDecoration(
                  label: 'Buscar cliente',
                  icon: Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No se encontraron clientes.',
                            style: AppFonts.inter(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withAlpha(26),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  c.name[0].toUpperCase(),
                                  style: AppFonts.inter(
                                    color: const Color(0xFF7C3AED),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(c.name,
                                style: AppFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
