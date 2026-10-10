import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/credit_engine.dart';
import '../utils/app_theme.dart';

/// Consulta el motor de amortización sin modificar la cartera ni el formulario.
class InstallmentSimulatorScreen extends StatefulWidget {
  final double? initialAmount;

  const InstallmentSimulatorScreen({super.key, this.initialAmount});

  @override
  State<InstallmentSimulatorScreen> createState() =>
      _InstallmentSimulatorScreenState();
}

class _InstallmentSimulatorScreenState
    extends State<InstallmentSimulatorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _rate = TextEditingController();
  final _months = TextEditingController(text: '12');
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  AmortizationMethod _method = AmortizationMethod.french;
  List<ScheduledInstallment>? _schedule;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: widget.initialAmount?.toStringAsFixed(2) ?? '');
    for (final controller in [_amount, _rate, _months]) {
      controller.addListener(_clearResult);
    }
  }

  void _clearResult() {
    if (_schedule != null) setState(() => _schedule = null);
  }

  double? _number(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  void _calculate() {
    if (!_form.currentState!.validate()) return;
    final terms = CreditTerms(
      principal: _number(_amount.text)!,
      annualRate: _number(_rate.text)!,
      months: int.parse(_months.text.trim()),
      method: _method,
    );
    setState(() => _schedule = CreditEngine.schedule(terms, DateTime.now()));
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    for (final controller in [_amount, _rate, _months]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _money(int cents) => _currency.format(cents / 100);

  Widget _metric(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Simular cuotas'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.ink,
        titleTextStyle: const TextStyle(
            fontFamily: 'AppRoboto', fontSize: 22, fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Explora cómo quedarían los pagos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Compara un plan de cuotas mensuales para tu cliente.',
                  style: TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _amount,
                          decoration: const InputDecoration(
                              labelText: 'Monto a prestar', prefixText: '\$ '),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (text) {
                            final value = _number(text);
                            return value == null ||
                                    !value.isFinite ||
                                    value < 1 ||
                                    value > 10000000
                                ? 'Ingresa un monto entre 1 y 10 millones.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _rate,
                          decoration: const InputDecoration(
                              labelText: 'Tasa anual',
                              suffixText: '%',
                              helperText:
                                  'Tasa nominal anual; se divide entre 12.'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (text) {
                            final value = _number(text);
                            return value == null ||
                                    !value.isFinite ||
                                    value < 0 ||
                                    value > 100
                                ? 'Ingresa una tasa de 0 a 100%.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _months,
                          decoration: const InputDecoration(
                              labelText: 'Plazo', suffixText: 'meses'),
                          keyboardType: TextInputType.number,
                          validator: (text) {
                            final value = int.tryParse((text ?? '').trim());
                            return value == null || value < 1 || value > 360
                                ? 'Ingresa entre 1 y 360 meses.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text('Método de pago',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 10, runSpacing: 8, children: [
                          for (final method in AmortizationMethod.values)
                            ChoiceChip(
                              label: Text(method == AmortizationMethod.french
                                  ? 'Francés'
                                  : 'Alemán'),
                              selected: _method == method,
                              onSelected: (_) => setState(() {
                                _method = method;
                                _schedule = null;
                              }),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          _method == AmortizationMethod.french
                              ? 'Cuotas constantes, con ajuste de redondeo al final.'
                              : 'Abonas el mismo capital y las cuotas van bajando.',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _calculate,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Calcular cuotas'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (schedule != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFFF0EBFC),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Tu simulación',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        _metric(
                            'Primera cuota', _money(schedule.first.totalCents)),
                        _metric(
                            'Última cuota', _money(schedule.last.totalCents)),
                        _metric(
                            'Intereses totales',
                            _money(schedule.fold(
                                0, (sum, row) => sum + row.interestCents))),
                        const Divider(),
                        _metric(
                            'Total a pagar',
                            _money(schedule.fold(
                                0, (sum, row) => sum + row.totalCents))),
                        const SizedBox(height: 8),
                        const Text('Sin seguros, comisiones ni mora.',
                            style:
                                TextStyle(fontSize: 12, color: AppTheme.muted)),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Ver todas las cuotas'),
                          children: [
                            for (final row in schedule)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                    'Cuota ${row.number} · ${DateFormat('dd/MM/yyyy').format(row.due)}'),
                                subtitle: Text(
                                    'Capital ${_money(row.principalCents)} · Interés ${_money(row.interestCents)}\nSaldo ${_money(row.balanceCents)}'),
                                trailing: Text(_money(row.totalCents),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                isThreeLine: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                  'Solo simulación. No registra un préstamo ni modifica tu cartera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
