import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/credit_account.dart';
import '../services/credit_service.dart';
import '../services/local_database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/credit_conditions.dart';
import '../widgets/customer_registration_dialog.dart';
import '../models/credit_engine.dart';
import '../widgets/panama_contract_fields.dart';
import '../utils/credit_documents.dart';

class CreditActivationScreen extends StatefulWidget {
  final String applicationId;
  const CreditActivationScreen({super.key, required this.applicationId});
  @override
  State<CreditActivationScreen> createState() => _CreditActivationScreenState();
}

class _CreditActivationScreenState extends State<CreditActivationScreen> {
  final service = CreditService();
  final form = GlobalKey<FormState>();
  final reference = TextEditingController();
  Map<String, dynamic> contractData = {};
  String? customerId, error;
  DateTime? date;
  bool verified = false, busy = false;
  bool? alreadyIncluded;
  final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  @override
  void initState() {
    super.initState();
    final app =
        service.applications.firstWhere((a) => a['id'] == widget.applicationId);
    final linkedId = app['customerId']?.toString();
    if (LocalDatabaseService.rowsOf(service.db.readPortfolio(), 'customers')
        .any((c) => c['id'].toString() == linkedId)) {
      customerId = linkedId;
    }
  }

  Future<void> registerCustomer(String applicant) async {
    final id = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CustomerRegistrationDialog(initialName: applicant));
    if (id != null && mounted) {
      setState(() {
        customerId = id;
        verified = false;
        error = null;
      });
    }
  }

  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  Future<void> pickDate(CreditLifecycle state) async {
    final now = DateTime.now();
    final first = state == CreditLifecycle.legacy
        ? DateTime(1900)
        : DateTime.parse(
            service.account(widget.applicationId)!['formalizedAt'] as String);
    final picked = await showDatePicker(
        context: context,
        initialDate: date ?? now,
        firstDate: DateTime(first.year, first.month, first.day),
        lastDate: now);
    if (picked != null && mounted) setState(() => date = picked);
  }

  Future<void> submit(CreditLifecycle state) async {
    if (busy || !form.currentState!.validate()) return;
    if (!verified ||
        ((state == CreditLifecycle.formalized ||
                state == CreditLifecycle.legacy) &&
            date == null) ||
        (state == CreditLifecycle.legacy && alreadyIncluded == null)) {
      setState(() => error =
          'Verifica la información, selecciona la fecha y confirma la operación.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      switch (state) {
        case CreditLifecycle.awaitingFormalization:
          await service.formalize(
              widget.applicationId, customerId!, reference.text,
              contract: contractData);
          break;
        case CreditLifecycle.formalized:
          await service.disburse(widget.applicationId, date!, reference.text);
          break;
        case CreditLifecycle.legacy:
          await service.reconcileLegacy(
              widget.applicationId, customerId!, date!, reference.text,
              cashAlreadyIncluded: alreadyIncluded!);
          break;
        case CreditLifecycle.active:
          throw StateError('El crédito ya está activo.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state == CreditLifecycle.awaitingFormalization
                ? 'Acuerdo registrado. El crédito está pendiente de desembolso.'
                : state == CreditLifecycle.legacy
                    ? 'Crédito conciliado. Se conservaron su plan y pagos.'
                    : 'Desembolso registrado. El crédito está activo.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e.toString().replaceFirst(RegExp(r'^\w+(?: \w+)*: '), ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app =
        service.applications.firstWhere((a) => a['id'] == widget.applicationId);
    final state = service.lifecycle(app);
    final snapshot = service.db.readPortfolio();
    final customers = LocalDatabaseService.rowsOf(snapshot, 'customers');
    final terms = app['terms'] as Map;
    final principal = (terms['principal'] as num).toDouble();
    final available = PortfolioLedger.availableCash(snapshot);
    final paid =
        PortfolioLedger.activePayments(snapshot, widget.applicationId) / 100;
    final impact = state == CreditLifecycle.legacy
        ? (alreadyIncluded == false ? -principal + paid : 0)
        : state == CreditLifecycle.formalized
            ? -principal
            : 0;
    final title = switch (state) {
      CreditLifecycle.awaitingFormalization => 'Formalizar crédito',
      CreditLifecycle.formalized => 'Registrar desembolso',
      CreditLifecycle.legacy => 'Conciliar crédito anterior',
      _ => 'Crédito activo'
    };
    return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: PageFrame(
            maxWidth: 720,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                children: [
                  Form(
                      key: form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(app['applicant'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(
                                '${money.format(principal)} · ${terms['months']} meses · ${terms['annualRate']}% nominal anual',
                                style: const TextStyle(color: AppTheme.muted)),
                            const SizedBox(height: 20),
                            CreditConditions(
                                terms: CreditTerms.fromMap(
                                    Map<String, dynamic>.from(terms))),
                            const SizedBox(height: 20),
                            if (state ==
                                    CreditLifecycle.awaitingFormalization ||
                                state == CreditLifecycle.legacy) ...[
                              const Text(
                                  'Vincula el expediente con el cliente correcto. Verifica su identidad; el nombre no establece una coincidencia automática.',
                                  style: TextStyle(color: AppTheme.muted)),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                  key:
                                      ValueKey('verified-customer-$customerId'),
                                  initialValue: customerId,
                                  isExpanded: true,
                                  hint: Text(customers.isEmpty
                                      ? 'Sin clientes registrados'
                                      : 'Selecciona un cliente'),
                                  decoration: const InputDecoration(
                                      labelText: 'Cliente verificado'),
                                  items: customers
                                      .map((c) => DropdownMenuItem(
                                          value: c['id'].toString(),
                                          child: Text(
                                              '${c['name']} · ${c['cedula'] ?? "Sin cédula"}',
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  validator: (v) => v == null
                                      ? 'Selecciona un cliente.'
                                      : null,
                                  onChanged: busy || customers.isEmpty
                                      ? null
                                      : (v) => setState(() {
                                            customerId = v;
                                            verified = false;
                                          })),
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(customers.isEmpty
                                      ? 'Aún no hay clientes en Cartera. Registra al solicitante aquí para continuar.'
                                      : 'Si el solicitante no aparece, registra su ficha de cliente.')),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => registerCustomer(
                                          app['applicant'] as String),
                                  icon: const Icon(Icons.person_add_outlined),
                                  label: const Text('Registrar cliente')),
                              const SizedBox(height: 18),
                            ],
                            if (state ==
                                CreditLifecycle.awaitingFormalization) ...[
                              PanamaContractFields(
                                  onChanged: (data) => contractData = data),
                              OutlinedButton.icon(
                                  icon: const Icon(Icons.download),
                                  label: const Text(
                                      'Descargar borrador contractual'),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          try {
                                            final selected = customers
                                                .where((c) =>
                                                    c['id'].toString() ==
                                                    customerId)
                                                .firstOrNull;
                                            final path = await CreditDocuments
                                                .exportContractDraft(
                                                    app,
                                                    contractData,
                                                    selected?['name']
                                                            as String? ??
                                                        app['applicant']
                                                            as String);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          'Borrador guardado: $path')));
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text('$e')));
                                            }
                                          }
                                        }),
                              const SizedBox(height: 20),
                            ],
                            TextFormField(
                                controller: reference,
                                enabled: !busy,
                                decoration: InputDecoration(
                                    labelText: state ==
                                            CreditLifecycle
                                                .awaitingFormalization
                                        ? 'Referencia del acuerdo aceptado'
                                        : state == CreditLifecycle.legacy
                                            ? 'Evidencia del desembolso anterior'
                                            : 'Referencia de la entrega'),
                                validator: (v) => (v?.trim().length ?? 0) <
                                        (state == CreditLifecycle.formalized
                                            ? 3
                                            : 5)
                                    ? 'Escribe una referencia válida.'
                                    : null),
                            if (state == CreditLifecycle.formalized ||
                                state == CreditLifecycle.legacy) ...[
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                  onPressed:
                                      busy ? null : () => pickDate(state),
                                  icon:
                                      const Icon(Icons.calendar_today_outlined),
                                  label: Text(date == null
                                      ? 'Seleccionar fecha real de entrega'
                                      : DateFormat('dd/MM/yyyy')
                                          .format(date!))),
                            ],
                            if (state == CreditLifecycle.legacy) ...[
                              const SizedBox(height: 20),
                              const Text(
                                  'Se conservarán el plan anterior y sus pagos. Indica si la entrega y los cobros anteriores ya están reflejados en tu disponible.'),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<bool>(
                                  initialValue: alreadyIncluded,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Tratamiento de caja'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: true,
                                        child: Text(
                                            'Ya están incluidos en el disponible')),
                                    DropdownMenuItem(
                                        value: false,
                                        child:
                                            Text('Todavía no están incluidos'))
                                  ],
                                  onChanged: busy
                                      ? null
                                      : (v) =>
                                          setState(() => alreadyIncluded = v),
                                  validator: (v) => v == null
                                      ? 'Selecciona el tratamiento de caja.'
                                      : null),
                            ],
                            const SizedBox(height: 20),
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              state ==
                                                      CreditLifecycle
                                                          .awaitingFormalization
                                                  ? 'La formalización no mueve capital'
                                                  : 'Efecto en el disponible',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Disponible actual: ${money.format(available)}'),
                                          Text(
                                              'Cambio de caja: ${money.format(impact)}'),
                                          Text(
                                              'Disponible resultante: ${money.format(available + impact)}'),
                                        ]))),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: verified,
                                onChanged: busy
                                    ? null
                                    : (v) =>
                                        setState(() => verified = v ?? false),
                                title: Text(state ==
                                        CreditLifecycle.awaitingFormalization
                                    ? 'Verifiqué al cliente y el acuerdo aceptado con estas condiciones.'
                                    : state == CreditLifecycle.legacy
                                        ? 'Verifiqué la entrega y la caja. Este crédito no está registrado también como préstamo directo.'
                                        : 'Confirmo que el monto fue entregado en la fecha indicada.'),
                                subtitle: state == CreditLifecycle.formalized
                                    ? const Text(
                                        'Este registro no realiza una transferencia bancaria.')
                                    : null),
                            if (error != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Semantics(
                                      liveRegion: true,
                                      child: Text(error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error)))),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: busy ? null : () => submit(state),
                                child: busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(title)),
                          ]))
                ])));
  }
}
