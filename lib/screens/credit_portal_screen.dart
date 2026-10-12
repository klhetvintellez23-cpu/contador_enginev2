import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/credit_engine.dart';
import '../services/credit_service.dart';
import '../services/local_database_service.dart';
import '../services/totp_service.dart';
import '../utils/app_theme.dart';
import '../utils/credit_documents.dart';
import 'credit_workspace.dart';
import '../models/credit_account.dart';
import '../widgets/app_ui.dart';
import '../widgets/finance_ui.dart';
import '../widgets/credit_overview.dart';
import '../utils/shared_styles.dart';
import 'credit_activation_screen.dart';
import 'credit_settlement_screen.dart';
import '../widgets/feci_fields.dart';
import '../widgets/credit_conditions.dart';

class CreditPortalScreen extends StatelessWidget {
  final bool embedded;
  final int initialTab;
  final ValueChanged<int>? onNavigate;
  const CreditPortalScreen(
      {super.key, this.embedded = false, this.initialTab = 0, this.onNavigate});
  @override
  Widget build(BuildContext context) => CreditWorkspace(
      embedded: embedded, initialTab: initialTab, onNavigate: onNavigate);
}

class CreditStatusBadge extends StatelessWidget {
  final String status;
  const CreditStatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => const Color(0xFF176C4A),
      'rejected' => const Color(0xFFB3261E),
      'returned' => const Color(0xFF8A5100),
      _ => AppTheme.primary
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
              child: Text(ApplicationStatus.values.byName(status).label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12))),
        ]));
  }
}

class CreditProgress extends StatelessWidget {
  final String status;
  const CreditProgress({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final current = switch (status) {
      'submitted' => 1,
      'compliance' => 2,
      'management' => 3,
      'approved' => 4,
      _ => 0,
    };
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final (index, label) in [
        'Solicitud',
        'Análisis',
        'Cumplimiento',
        'Gerencia',
        'Aprobación'
      ].indexed)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              index < current
                  ? Icons.check_circle
                  : index == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 18,
              color: index <= current ? AppTheme.primary : AppTheme.muted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: index <= current ? AppTheme.primary : AppTheme.muted)),
        ]),
    ]);
  }
}

Future<String?> requestText(BuildContext context, String title, String label,
    {int minLength = 1, String? explanation}) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showBlurDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
              title: Text(title),
              scrollable: true,
              content: Form(
                  key: form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (explanation != null) ...[
                          Text(explanation),
                          const SizedBox(height: 16)
                        ],
                        TextFormField(
                            controller: controller,
                            decoration: InputDecoration(labelText: label),
                            validator: (v) =>
                                (v?.trim().length ?? 0) < minLength
                                    ? 'Escribe al menos $minLength caracteres.'
                                    : null,
                            autofocus: true)
                      ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(dialog, controller.text.trim());
                      }
                    },
                    child: const Text('Confirmar'))
              ]));
  controller.dispose();
  return result;
}

class CreditDetailScreen extends StatefulWidget {
  final String id;
  const CreditDetailScreen({super.key, required this.id});
  @override
  State<CreditDetailScreen> createState() => _CreditDetailScreenState();
}

class _CreditDetailScreenState extends State<CreditDetailScreen> {
  final service = CreditService();
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = service.applications.firstWhere((a) => a['id'] == widget.id);
    final role = service.db.currentUser!.role;
    final status = app['status'];
    final lifecycle = status == 'approved' ? service.lifecycle(app) : null;
    final canDecide = (role == UserRole.analyst && status == 'submitted') ||
        (role == UserRole.compliance && status == 'compliance') ||
        (role == UserRole.manager && status == 'management');
    final balances =
        status == 'approved' ? service.balance(app) : <Map<String, dynamic>>[];
    final total =
        balances.fold<int>(0, (sum, r) => sum + (r['remainingCents'] as int));
    return Scaffold(
      appBar: AppBar(title: const Text('Expediente de crédito')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (busy) const LinearProgressIndicator(),
                        CreditOverview(
                            application: app,
                            badge: CreditStatusBadge(status: status as String),
                            lifecycle: lifecycle?.label,
                            progress: ['rejected', 'returned'].contains(status)
                                ? null
                                : CreditProgress(status: status)),
                        const SizedBox(height: 14),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('¿Qué sigue?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 6),
                                      Text(
                                          switch (status) {
                                            'draft' =>
                                              'Revisa tus datos y pulsa Enviar a análisis. Mientras sea un borrador puedes editarlo.',
                                            'returned' =>
                                              'Revisa el motivo de devolución al final del expediente y corrige la solicitud para enviarla de nuevo.',
                                            'submitted' =>
                                              'El analista debe calcular la capacidad de pago y registrar su decisión.',
                                            'compliance' =>
                                              'Cumplimiento revisará el expediente antes de enviarlo a gerencia.',
                                            'management' =>
                                              'Gerencia debe revisar el expediente y registrar la decisión final.',
                                            'approved' => switch (lifecycle) {
                                                CreditLifecycle
                                                      .awaitingFormalization =>
                                                  'La solicitud está aprobada. Falta registrar el acuerdo y el desembolso para activar el crédito.',
                                                CreditLifecycle.formalized =>
                                                  'El acuerdo está registrado. Falta registrar la entrega real para activar el crédito.',
                                                CreditLifecycle.legacy =>
                                                  'Se conservan el plan y los pagos anteriores. Gerencia debe verificar el desembolso y conciliar la caja antes de registrar nuevos cobros.',
                                                _ =>
                                                  'Consulta el plan de cuotas y los cobros del crédito activo.',
                                              },
                                            _ =>
                                              'Esta solicitud fue rechazada. Consulta el motivo en el historial de decisiones.',
                                          },
                                          style: const TextStyle(
                                              color: AppTheme.muted,
                                              height: 1.5)),
                                    ]))),
                        const SizedBox(height: 12),
                        CreditFinancialSummary(application: app),
                        const SectionHeading('Acciones del expediente'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (role == UserRole.client &&
                              ['draft', 'returned'].contains(status))
                            OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                          final data = await Navigator.push<
                                                  Map<String, dynamic>>(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      CreditApplicationForm(
                                                          application: app)));
                                          if (data != null) {
                                            await service.revise(
                                                widget.id,
                                                data['purpose'] as String,
                                                data['terms'] as CreditTerms,
                                                data['profile']
                                                    as FinancialProfile);
                                          }
                                        }),
                                child: const Text('Editar solicitud')),
                          if (role == UserRole.client && status == 'draft')
                            FilledButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                        run(() => service.submit(widget.id)),
                                child: const Text('Enviar a análisis')),
                          if (role == UserRole.analyst && status == 'submitted')
                            FilledButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                        run(() => service.evaluate(widget.id)),
                                child: const Text('Calcular DTI y scoring')),
                          if (canDecide)
                            ...{
                              'advance': role == UserRole.manager
                                  ? 'Aprobar solicitud'
                                  : 'Aprobar etapa',
                              'return': 'Devolver',
                              'reject': 'Rechazar'
                            }.entries.map((e) => OutlinedButton(
                                style: e.key == 'reject'
                                    ? OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(context).colorScheme.error,
                                        side: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error))
                                    : null,
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final reason = await requestText(
                                            context,
                                            e.value,
                                            'Motivo obligatorio',
                                            minLength: 5,
                                            explanation: e.key == 'advance' &&
                                                    role == UserRole.manager
                                                ? 'Confirmar la aprobación no registra un desembolso. Después deberás formalizar el acuerdo y registrar la entrega real.'
                                                : e.key == 'reject'
                                                    ? 'La solicitud quedará rechazada. El solicitante podrá consultar este motivo.'
                                                    : 'Registra la decisión y su motivo para continuar el expediente.');
                                        if (reason != null) {
                                          await run(() => service.decide(
                                              widget.id, e.key, reason));
                                        }
                                      },
                                child: Text(e.value))),
                          ...[false, true].map((pdf) => OutlinedButton.icon(
                              icon: const Icon(Icons.download),
                              label:
                                  Text(pdf ? 'Exportar PDF' : 'Exportar JSON'),
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        final path =
                                            await CreditDocuments.export(
                                                service, app,
                                                pdf: pdf);
                                        if (path == null) {
                                          throw StateError(
                                              'No se pudo exportar.');
                                        }
                                        if (!path.startsWith('download:')) {
                                          await SharePlus.instance.share(
                                              ShareParams(
                                                  files: [XFile(path)]));
                                        }
                                      }))),
                        ]),
                        if (status == 'approved' &&
                            role == UserRole.manager &&
                            lifecycle != CreditLifecycle.active) ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              icon: const Icon(Icons.assignment_outlined),
                              label: Text(switch (lifecycle) {
                                CreditLifecycle.awaitingFormalization =>
                                  'Formalizar crédito',
                                CreditLifecycle.formalized =>
                                  'Registrar desembolso',
                                _ => 'Conciliar crédito anterior'
                              }),
                              onPressed: busy
                                  ? null
                                  : () => run(() => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              CreditActivationScreen(
                                                  applicationId: widget.id))))),
                        ],
                        if (status == 'approved' &&
                            [CreditLifecycle.active, CreditLifecycle.legacy]
                                .contains(lifecycle)) ...[
                          const SizedBox(height: 16),
                          Text(
                              total == 0
                                  ? 'Préstamo saldado'
                                  : 'Saldo contractual: USD ${(total / 100).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge),
                          const Text(
                              'El saldo contractual incluye cuotas futuras. Para terminar el préstamo, usa Cancelar préstamo y revisa el descuento de intereses futuros.'),
                          if (role == UserRole.manager &&
                              lifecycle == CreditLifecycle.active &&
                              service.account(widget.id)?['settlement'] == null)
                            OutlinedButton.icon(
                                icon: const Icon(Icons.task_alt),
                                label: const Text('Cancelar préstamo'),
                                onPressed: busy
                                    ? null
                                    : () => run(() => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                CreditSettlementScreen(
                                                    applicationId:
                                                        widget.id))))),
                          if (role == UserRole.manager &&
                              total > 0 &&
                              lifecycle == CreditLifecycle.active)
                            FilledButton.icon(
                                icon: const Icon(Icons.payments),
                                label: const Text('Registrar pago'),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final amount = await requestText(
                                            context,
                                            'Registrar pago',
                                            'Monto USD');
                                        if (amount == null) return;
                                        if (!context.mounted) return;
                                        final ref = await requestText(
                                            context,
                                            'Referencia del pago',
                                            'Recibo o referencia única',
                                            minLength: 3);
                                        if (ref == null) return;
                                        await run(() => service.pay(
                                            widget.id,
                                            double.parse(
                                                amount.replaceAll(',', '.')),
                                            ref));
                                      }),
                          const SizedBox(height: 16),
                          if (MediaQuery.sizeOf(context).width < 650)
                            ...balances.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                    child: ExpansionTile(
                                  title: Text(
                                      'Cuota ${r['number']} · USD ${((r['remainingCents'] as num) / 100).toStringAsFixed(2)}'),
                                  subtitle: Text(
                                      'Vence ${r['due'].toString().substring(0, 10)}'),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [
                                    for (final item in {
                                      'principalCents': 'Capital',
                                      'interestCents': 'Interés',
                                      'insuranceCents': 'Seguro',
                                      'feciCents': 'FECI',
                                      'feeCents': 'Comisión',
                                      'lateCents': 'Mora'
                                    }.entries)
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Row(children: [
                                            Expanded(child: Text(item.value)),
                                            Text(
                                                'USD ${((r[item.key] as num? ?? 0) / 100).toStringAsFixed(2)}'),
                                          ])),
                                  ],
                                ))))
                          else
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                    columns: [
                                      'Cuota',
                                      'Vence',
                                      'Capital',
                                      'Interés',
                                      'Seguro',
                                      'FECI',
                                      'Comisión',
                                      'Mora',
                                      'Pendiente'
                                    ]
                                        .map((s) => DataColumn(label: Text(s)))
                                        .toList(),
                                    rows: balances
                                        .map((r) => DataRow(cells: [
                                              DataCell(Text('${r['number']}')),
                                              DataCell(Text(r['due']
                                                  .toString()
                                                  .substring(0, 10))),
                                              ...[
                                                'principalCents',
                                                'interestCents',
                                                'insuranceCents',
                                                'feciCents',
                                                'feeCents',
                                                'lateCents',
                                                'remainingCents'
                                              ].map((k) => DataCell(Text(
                                                  ((r[k] as num? ?? 0) / 100)
                                                      .toStringAsFixed(2)))),
                                            ]))
                                        .toList())),
                          const SizedBox(height: 16),
                          Text('Historial de pagos',
                              style: Theme.of(context).textTheme.titleLarge),
                          ...service.payments(widget.id).map((p) => ListTile(
                              title: Text(
                                  '${p['reference']} · ${p['direction'] == 'refund' ? 'Devolución' : 'Cobro'} USD ${((p['amountCents'] as num) / 100).toStringAsFixed(2)}'),
                              subtitle: Text(
                                  '${p['date']} · ${p['voided'] == true ? 'Anulado: ${p['voidReason']}' : 'Registrado'}'),
                              trailing: role == UserRole.manager &&
                                      p['voided'] != true
                                  ? TextButton(
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              final reason = await requestText(
                                                  context,
                                                  'Anular pago',
                                                  'Motivo obligatorio',
                                                  minLength: 5);
                                              if (reason != null) {
                                                await run(() =>
                                                    service.voidPayment(
                                                        p['id'] as String,
                                                        reason));
                                              }
                                            },
                                      child: const Text('Anular'))
                                  : null)),
                        ],
                        const SizedBox(height: 20),
                        Text('Historial de decisiones',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (((app['decisions'] as List?) ?? []).isEmpty)
                          const Text('Todavía no se han registrado decisiones.',
                              style: TextStyle(color: AppTheme.muted)),
                        ...((app['decisions'] as List?) ?? []).map((d) => ListTile(
                            leading: const Icon(Icons.fact_check),
                            title: Text(
                                '${UserRole.values.byName(d['role'] as String).label} · ${ApplicationStatus.values.byName(d['to'] as String).label}'),
                            subtitle: Text(
                                '${d['reason']}\n${d['date']} · ${d['actor']}'))),
                        const SizedBox(height: 24),
                        SelectableText('Referencia: ${app['id']}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.muted)),
                      ])))),
    );
  }
}

class CreditApplicationForm extends StatefulWidget {
  final Map<String, dynamic>? application;
  final bool managed;
  const CreditApplicationForm(
      {super.key, this.application, this.managed = false});
  @override
  State<CreditApplicationForm> createState() => _CreditApplicationFormState();
}

class _CreditApplicationFormState extends State<CreditApplicationForm> {
  final fields = <String, TextEditingController>{};
  final form = GlobalKey<FormState>();
  AmortizationMethod method = AmortizationMethod.french;
  FeciTreatment feciTreatment = FeciTreatment.pending;
  String feciEvidence = '';
  int step = 0;
  bool finished = false;
  String? error;
  static const labels = {
    'purpose': '¿Para qué lo necesitas?',
    'principal': 'Monto solicitado (USD)',
    'annualRate': 'Tasa nominal anual (%)',
    'months': 'Plazo en meses',
    'income': 'Ingresos mensuales (USD)',
    'expenses': 'Gastos sin deudas (USD)',
    'debtPayments': 'Cuotas de otras deudas (USD)',
    'monthlyInsurance': 'Seguro mensual (USD)',
    'openingFee': 'Comisión inicial (USD)',
    'lateFee': 'Mora única sobre capital vencido (%)',
  };
  @override
  void initState() {
    super.initState();
    final a = widget.application;
    final values = <String, dynamic>{
      'principal': 1000,
      'annualRate': 12,
      'months': 12,
      'monthlyInsurance': 0,
      'openingFee': 0,
      'lateFee': 0,
      if (a != null) ...Map<String, dynamic>.from(a['terms'] as Map),
      if (a != null) ...Map<String, dynamic>.from(a['profile'] as Map),
      if (a != null) 'purpose': a['purpose']
    };
    for (final key in labels.keys) {
      fields[key] = TextEditingController(text: values[key]?.toString() ?? '');
    }
    if (a != null) {
      feciTreatment = FeciTreatment.values
          .byName((a['terms'] as Map)['feciTreatment'] as String? ?? 'pending');
      feciEvidence = (a['terms'] as Map)['feciEvidence'] as String? ?? '';
      fields['lateFee']!.text =
          ((a['terms'] as Map)['lateFeePercent'] ?? 0).toString();
      method = AmortizationMethod.values
          .byName((a['terms'] as Map)['method'] as String);
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  double number(String key) =>
      double.parse(fields[key]!.text.trim().replaceAll(',', '.'));
  CreditTerms get terms => CreditTerms(
      principal: number('principal'),
      annualRate: number('annualRate'),
      months: int.parse(fields['months']!.text.trim()),
      method: method,
      monthlyInsurance: number('monthlyInsurance'),
      openingFee: number('openingFee'),
      lateFeePercent: number('lateFee'),
      feciTreatment: feciTreatment,
      feciEvidence: feciEvidence);
  FinancialProfile get profile => FinancialProfile(
      income: number('income'),
      expenses: number('expenses'),
      debtPayments: number('debtPayments'));
  void next() {
    if (!form.currentState!.validate()) return;
    try {
      if (step == 0) {
        terms.validate();
      } else {
        profile.validate();
      }
      setState(() {
        step++;
        error = null;
      });
    } catch (e) {
      setState(() =>
          error = e.toString().replaceFirst(RegExp(r'^\w+(?: \w+)*: '), ''));
    }
  }

  void submit(bool send) {
    if (finished) return;
    try {
      terms.validate();
      if (send || widget.managed) terms.validateForContract();
      profile.validate();
      if (fields['purpose']!.text.trim().length < 5) {
        throw ArgumentError('Explica el destino del crédito.');
      }
      finished = true;
      Navigator.pop(context, {
        'purpose': fields['purpose']!.text.trim(),
        'terms': terms,
        'profile': profile,
        'send': send
      });
    } catch (e) {
      setState(() => error = 'Revisa tus datos. $e');
    }
  }

  Widget field(String key) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: TextFormField(
          controller: fields[key],
          textInputAction: TextInputAction.next,
          maxLines: key == 'purpose' ? 2 : 1,
          decoration: InputDecoration(
              labelText: labels[key],
              hintText:
                  key == 'purpose' ? 'Compra de equipo para mi negocio' : '0'),
          keyboardType: key == 'purpose'
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          validator: (text) {
            if (key == 'purpose') {
              return (text?.trim().length ?? 0) < 5
                  ? 'Explica el destino (mínimo 5 caracteres).'
                  : null;
            }
            final value =
                double.tryParse((text ?? '').trim().replaceAll(',', '.'));
            if (value == null || !value.isFinite || value < 0) {
              return 'Ingresa un importe válido.';
            }
            if (['principal', 'income', 'months'].contains(key) && value <= 0) {
              return 'Debe ser mayor que cero.';
            }
            if (key == 'months' && int.tryParse((text ?? '').trim()) == null) {
              return 'Ingresa meses completos.';
            }
            return null;
          }));
  Widget value(String label, String amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label, style: const TextStyle(color: AppTheme.muted))),
        const SizedBox(width: 16),
        Flexible(
            child: Text(amount,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700)))
      ]));
  Widget review() {
    final plan = CreditEngine.schedule(terms, DateTime.now());
    final maximum =
        plan.map((r) => r.totalCents).reduce((a, b) => a > b ? a : b);
    String usd(num cents) => 'USD ${(cents / 100).toStringAsFixed(2)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fields['purpose']!.text.trim(),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    value('Monto solicitado',
                        usd((terms.principal * 100).round())),
                    value('Plazo', '${terms.months} meses'),
                    value(
                        'Modalidad',
                        method == AmortizationMethod.french
                            ? 'Francés · Cuota base fija'
                            : 'Alemán · Capital constante'),
                    value('Tasa nominal anual', '${terms.annualRate}%'),
                    value('Primera cuota estimada', usd(plan.first.totalCents)),
                    value('Cuota máxima estimada', usd(maximum)),
                    value('Última cuota estimada', usd(plan.last.totalCents)),
                    value('Total estimado sin mora',
                        usd(plan.fold<int>(0, (s, r) => s + r.totalCents))),
                    value('Interés total estimado',
                        usd(plan.fold<int>(0, (s, r) => s + r.interestCents))),
                    value('Seguro por mes',
                        usd((terms.monthlyInsurance * 100).round())),
                    value('Comisión inicial',
                        usd((terms.openingFee * 100).round())),
                    value('Mora sobre capital vencido',
                        '${terms.lateFeePercent}%'),
                    CreditConditions(terms: terms),
                  ]))),
      const SizedBox(height: 18),
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Tu capacidad de pago'),
          children: [
            value('Ingresos mensuales',
                'USD ${profile.income.toStringAsFixed(2)}'),
            value('Gastos sin deudas',
                'USD ${profile.expenses.toStringAsFixed(2)}'),
            value('Otras cuotas',
                'USD ${profile.debtPayments.toStringAsFixed(2)}')
          ]),
      const SizedBox(height: 18),
      const Text(
          'Las fechas finales se fijan al registrar el desembolso. La cancelación total descuenta intereses futuros y no tiene penalización. Enviar la solicitud no garantiza aprobación ni entrega de fondos.',
          style: TextStyle(color: AppTheme.muted, height: 1.5)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Tu próximo proyecto',
      'Tu capacidad de pago',
      'Revisa tu solicitud'
    ];
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.managed
                ? 'Condiciones del nuevo crédito'
                : widget.application == null
                    ? 'Solicitar préstamo'
                    : 'Corregir solicitud'),
            leading: BackButton(
                onPressed: () => step > 0
                    ? setState(() => step--)
                    : Navigator.pop(context))),
        body: PageFrame(
            maxWidth: 720,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Semantics(
                  label: 'Paso ${step + 1} de 3',
                  child: Row(children: [
                    Expanded(
                        child: Text('Paso ${step + 1} de 3',
                            style: const TextStyle(color: AppTheme.muted))),
                    TextButton(
                        onPressed: () {
                          if (step > 0) setState(() => step = 0);
                        },
                        child: const Text('Condiciones'))
                  ])),
              TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1 / 3, end: (step + 1) / 3),
                  duration: AppMotion.duration(context),
                  builder: (_, progress, __) => LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 24),
              Text(titles[step],
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                  step == 0
                      ? 'Cuéntanos qué necesitas para avanzar.'
                      : step == 1
                          ? 'Indica los valores mensuales en USD. Escribe 0 cuando corresponda.'
                          : 'Comprueba las condiciones y tus datos antes de enviar.',
                  style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 20),
              Form(
                  key: form,
                  child: AnimatedSize(
                      duration: AppMotion.duration(context),
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                          duration: AppMotion.duration(context, 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Column(
                              key: ValueKey(step),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (step == 0) ...[
                                  field('principal'),
                                  field('purpose'),
                                  field('months'),
                                  const SizedBox(height: 18),
                                  DropdownButtonFormField<AmortizationMethod>(
                                      initialValue: method,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Modalidad de cuotas'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: AmortizationMethod.french,
                                            child: Text(
                                                'Francés · Cuota base fija')),
                                        DropdownMenuItem(
                                            value: AmortizationMethod.german,
                                            child: Text(
                                                'Alemán · Capital constante'))
                                      ],
                                      onChanged: (value) =>
                                          setState(() => method = value!)),
                                  field('annualRate'),
                                  const SizedBox(height: 16),
                                  FeciFields(
                                      treatment: feciTreatment,
                                      evidence: feciEvidence,
                                      onChanged: (treatment, evidence) =>
                                          setState(() {
                                            feciTreatment = treatment;
                                            feciEvidence = evidence;
                                          })),
                                  ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      maintainState: true,
                                      title: const Text('Cargos y condiciones'),
                                      subtitle: const Text(
                                          'Seguro, comisión y mora; se muestran al revisar'),
                                      children: [
                                        field('monthlyInsurance'),
                                        field('openingFee'),
                                        field('lateFee')
                                      ]),
                                ] else if (step == 1) ...[
                                  field('income'),
                                  field('expenses'),
                                  field('debtPayments')
                                ] else
                                  review(),
                              ])))),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)))),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: finished
                      ? null
                      : step < 2
                          ? next
                          : () => submit(widget.application == null),
                  child: Text(step < 2
                      ? 'Continuar'
                      : widget.managed
                          ? 'Aprobar condiciones y formalizar'
                          : widget.application == null
                              ? 'Enviar solicitud'
                              : 'Guardar corrección')),
              if (step == 2 && widget.application == null && !widget.managed)
                TextButton(
                    onPressed: finished ? null : () => submit(false),
                    child: const Text('Guardar como borrador')),
              if (step > 0)
                TextButton(
                    onPressed: () => setState(() => step--),
                    child: const Text('Paso anterior')),
            ])));
  }
}

class AccountSecurityDialog extends StatefulWidget {
  const AccountSecurityDialog({super.key});
  @override
  State<AccountSecurityDialog> createState() => _AccountSecurityDialogState();
}

class _AccountSecurityDialogState extends State<AccountSecurityDialog> {
  final old = TextEditingController(),
      next = TextEditingController(),
      code = TextEditingController();
  String? secret, message;
  bool busy = false;
  @override
  void dispose() {
    old.dispose();
    next.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => message = 'Cambio guardado.');
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Seguridad de cuenta'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: old,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Contraseña actual')),
                const SizedBox(height: 18),
                TextField(
                    controller: next,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                        helperText: 'Usa al menos 12 caracteres.')),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() => LocalDatabaseService()
                            .changePassword(old.text, next.text)),
                    child: const Text('Cambiar contraseña')),
                const Divider(height: 32),
                const Text(
                    'Segundo factor con aplicación autenticadora (TOTP). Guarda el secreto en un lugar seguro para recuperar el acceso.'),
                if (secret == null)
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => secret = TotpService.secret()),
                      child: const Text('Configurar autenticador')),
                if (secret != null) ...[
                  SelectableText(secret!),
                  TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: secret!)),
                      child: const Text('Copiar secreto')),
                  const Text(
                      'Añade esta clave manualmente al autenticador: TOTP, 6 dígitos, 30 segundos, SHA1.'),
                  TextField(
                      controller: code,
                      decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos'),
                      keyboardType: TextInputType.number),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () => run(() => LocalDatabaseService()
                              .enableTotp(secret!, code.text.trim())),
                      child: const Text('Activar 2FA')),
                ],
                if (message != null) Text(message!),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'))
          ]);
}
