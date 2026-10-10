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
import '../utils/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/app_search_field.dart';
import 'installment_simulator_screen.dart';

class AddLoanScreen extends StatefulWidget {
  final Customer? initialCustomer;
  const AddLoanScreen({super.key, this.initialCustomer});

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
    _selectedCustomer = widget.initialCustomer;
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
    final provider = context.read<DebtProvider>();
    return Scaffold(
      body: PageFrame(
          maxWidth: 720,
          child: Column(children: [
            const PageHeading(
                title: 'Nuevo préstamo',
                subtitle: 'Define el monto y cómo se cobrará.',
                back: true),
            Expanded(
                child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          TextButton.icon(
                              onPressed: _openQuickCalculator,
                              icon: const Icon(Icons.calculate_outlined,
                                  size: 18),
                              label: const Text('Calculadora rápida')),
                          TextButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          InstallmentSimulatorScreen(
                                              initialAmount: double.tryParse(
                                                  _amountController.text
                                                      .trim()
                                                      .replaceAll(',', '.'))))),
                              icon: const Icon(Icons.view_timeline_outlined,
                                  size: 18),
                              label: const Text('Simular cuotas')),
                        ]),
                        const SizedBox(height: 16),
                        const Text('Cliente',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        PillSelector(
                            icon: Icons.person_outline_rounded,
                            label: _selectedCustomer?.name ??
                                'Seleccionar cliente',
                            isPlaceholder: _selectedCustomer == null,
                            onTap: () => _showCustomerPicker(
                                context, provider.customers)),
                        const SizedBox(height: 24),
                        TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                                labelText: 'Monto a prestar',
                                prefixText: '\$ '),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa el monto.'
                                : null),
                        const SizedBox(height: 8),
                        _buildBudgetHint(provider.moneyInHand),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                                labelText: 'Concepto',
                                hintText: 'Ej. Capital de trabajo'),
                            textCapitalization: TextCapitalization.sentences,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa un concepto.'
                                : null),
                        const SizedBox(height: 20),
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Cobrar intereses',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            value: _hasInterest,
                            onChanged: (value) =>
                                setState(() => _hasInterest = value)),
                        AnimatedSize(
                            duration: AppMotion.duration(context),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: !_hasInterest
                                ? const SizedBox(width: double.infinity)
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<
                                                IncrementPeriod>(
                                            initialValue: _incrementPeriod,
                                            key: ValueKey(_incrementPeriod),
                                            decoration: const InputDecoration(
                                                labelText:
                                                    'Frecuencia de cobro'),
                                            items: [
                                              for (final period
                                                  in IncrementPeriod.values)
                                                DropdownMenuItem(
                                                    value: period,
                                                    child: Text(period.label))
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() =>
                                                    _incrementPeriod = value);
                                              }
                                            }),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                            controller: _incrementController,
                                            decoration: InputDecoration(
                                                labelText: _incrementType ==
                                                        IncrementType.percentage
                                                    ? 'Interés por período'
                                                    : 'Interés fijo por período',
                                                suffixText: _incrementType ==
                                                        IncrementType.percentage
                                                    ? '%'
                                                    : 'USD'),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            validator: (v) =>
                                                v == null || v.trim().isEmpty
                                                    ? 'Ingresa el interés.'
                                                    : null),
                                        const SizedBox(height: 12),
                                        Text(_buildPreviewText(),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.muted,
                                                height: 1.5)),
                                        const SizedBox(height: 16),
                                        SettingsGroup(
                                            title: 'Opciones avanzadas',
                                            subtitle:
                                                '${_incrementType == IncrementType.percentage ? 'Porcentaje' : 'Monto fijo'} · ${_accumulateOverdueInterest ? 'Acumula interés vencido' : 'Sin acumulación'}',
                                            children: [
                                              DropdownButtonFormField<
                                                      IncrementType>(
                                                  initialValue: _incrementType,
                                                  key: ValueKey(_incrementType),
                                                  decoration: const InputDecoration(
                                                      labelText:
                                                          'Forma de calcular el interés'),
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: IncrementType
                                                            .percentage,
                                                        child:
                                                            Text('Porcentaje')),
                                                    DropdownMenuItem(
                                                        value:
                                                            IncrementType.fixed,
                                                        child:
                                                            Text('Monto fijo'))
                                                  ],
                                                  onChanged: (value) {
                                                    if (value != null) {
                                                      setState(() =>
                                                          _incrementType =
                                                              value);
                                                    }
                                                  }),
                                              const SizedBox(height: 12),
                                              SwitchListTile.adaptive(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  value:
                                                      _accumulateOverdueInterest,
                                                  onChanged: (value) =>
                                                      setState(() =>
                                                          _accumulateOverdueInterest =
                                                              value),
                                                  title: const Text(
                                                      'Acumular interés vencido'),
                                                  subtitle: Text(
                                                      _accumulateOverdueInterest
                                                          ? 'Genera interés en cada vencimiento sobre el capital pendiente.'
                                                          : 'Espera a liquidar el interés pendiente antes de generar otro.')),
                                            ]),
                                      ])),
                      ],
                    ))),
            SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: _saving ? null : _submit,
                            child: AnimatedSwitcher(
                                duration: AppMotion.duration(context, 180),
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Crear préstamo')))))),
          ])),
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
              style: AppFonts.inter(fontSize: 13, color: AppTheme.muted),
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
              AppSearchField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _query = val.trim().toLowerCase()),
                hint: 'Buscar cliente',
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
