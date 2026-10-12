import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/credit_engine.dart';
import '../providers/debt_provider.dart';
import '../services/credit_service.dart';
import '../widgets/app_ui.dart';
import 'credit_portal_screen.dart';
import 'installment_simulator_screen.dart';

/// New originations share a finite amortization model; history is preserved.
class AddLoanScreen extends StatefulWidget {
  final Customer? initialCustomer;
  const AddLoanScreen({super.key, this.initialCustomer});
  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  Customer? customer;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    customer = widget.initialCustomer;
  }

  Future<void> create() async {
    if (busy || customer == null) return;
    final data = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => const CreditApplicationForm(managed: true)));
    if (data == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await CreditService().createManaged(
          customer!.id.toString(),
          data['purpose'] as String,
          data['terms'] as CreditTerms,
          data['profile'] as FinancialProfile);
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => CreditDetailScreen(id: id)));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();
    return Scaffold(
        body: PageFrame(
            maxWidth: 720,
            child: Column(children: [
              const PageHeading(
                  title: 'Nuevo préstamo',
                  subtitle: 'Condiciones, contrato y entrega de fondos.',
                  back: true),
              Expanded(
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    const InstallmentSimulatorScreen())),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Simular cuotas'))),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                    initialValue: customer?.id.toString(),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: provider.customers
                        .map((c) => DropdownMenuItem(
                            value: c.id.toString(),
                            child:
                                Text(c.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (id) => setState(() => customer = provider.customers
                            .firstWhere((c) => c.id.toString() == id))),
                const SizedBox(height: 24),
                const Text(
                    'El nuevo crédito tendrá un plazo definido, tasa nominal y efectiva, desglose de cargos y liquidación anticipada. La aprobación de condiciones no registra una entrega de dinero.'),
                const SizedBox(height: 16),
                const Text(
                    'Los préstamos periódicos anteriores conservan su historial. Para conciliar o cambiar sus condiciones debe documentarse un nuevo acuerdo.'),
                if (provider.customers.isEmpty)
                  const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                          'Registra primero al cliente desde Cartera → Clientes.')),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: customer != null && !busy ? create : null,
                    child: Text(busy ? 'Registrando…' : 'Definir condiciones')),
              ])),
            ])));
  }
}
