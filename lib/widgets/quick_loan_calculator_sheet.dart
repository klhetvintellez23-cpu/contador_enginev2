import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/local_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../utils/shared_styles.dart';

/// Resultado de la calculadora, listo para volcarse en el formulario de
/// AddLoanScreen sin que el usuario tenga que reescribir nada.
class QuickLoanCalculatorResult {
  final double amount;
  final IncrementType incrementType;
  final double incrementValue;
  final IncrementPeriod incrementPeriod;

  const QuickLoanCalculatorResult({
    required this.amount,
    required this.incrementType,
    required this.incrementValue,
    required this.incrementPeriod,
  });
}

/// Calculadora rápida: a partir de monto, interés/ganancia, frecuencia y
/// número de cuotas, muestra la cuota sugerida, el total a pagar, la
/// ganancia estimada y la fecha estimada de finalización. Es puramente
/// informativa — no crea nada por sí sola, pero puede devolver los valores
/// para precargar el formulario de nuevo préstamo.
class QuickLoanCalculatorSheet extends StatefulWidget {
  final DateTime initialStartDate;

  const QuickLoanCalculatorSheet({super.key, required this.initialStartDate});

  static Future<QuickLoanCalculatorResult?> show(
    BuildContext context, {
    required DateTime startDate,
  }) {
    return showModalBottomSheet<QuickLoanCalculatorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => QuickLoanCalculatorSheet(initialStartDate: startDate),
    );
  }

  @override
  State<QuickLoanCalculatorSheet> createState() =>
      _QuickLoanCalculatorSheetState();
}

class _QuickLoanCalculatorSheetState extends State<QuickLoanCalculatorSheet> {
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');
  IncrementType _incrementType = IncrementType.percentage;
  IncrementPeriod _incrementPeriod = IncrementPeriod.biweekly;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _amountController,
      _rateController,
      _installmentsController
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());
  double? get _rate => double.tryParse(_rateController.text.trim());
  int get _installments =>
      int.tryParse(_installmentsController.text.trim())?.clamp(1, 999) ?? 1;

  double get _perPeriodCharge {
    final amount = _amount ?? 0;
    final rate = _rate ?? 0;
    return _incrementType == IncrementType.percentage
        ? amount * (rate / 100)
        : rate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final amount = _amount;
    final ready = amount != null && amount > 0;

    final perPeriodCharge = _perPeriodCharge;
    final totalCharge = perPeriodCharge * _installments;
    final totalToPay = (amount ?? 0) + totalCharge;
    final estimatedEndDate = widget.initialStartDate
        .add(Duration(days: _incrementPeriod.lengthInDays * _installments));
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              children: [
                Icon(Icons.calculate_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Calculadora rápida',
                    style: AppFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Simula un préstamo antes de crearlo.',
              style: AppFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: minimalFieldDecoration(label: 'Monto prestado (USD)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<IncrementType>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.colorScheme.primary,
                  selectedForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                segments: const [
                  ButtonSegment(
                      value: IncrementType.percentage,
                      label: Text('% Porcentaje')),
                  ButtonSegment(
                      value: IncrementType.fixed, label: Text('\$ Monto fijo')),
                ],
                selected: {_incrementType},
                onSelectionChanged: (s) =>
                    setState(() => _incrementType = s.first),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: minimalFieldDecoration(
                label: _incrementType == IncrementType.percentage
                    ? 'Interés/ganancia por período (%)'
                    : 'Interés/ganancia por período (\$)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Frecuencia de pago',
                style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<IncrementPeriod>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.colorScheme.primary,
                  selectedForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: AppFonts.inter(fontSize: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                segments: const [
                  ButtonSegment(
                      value: IncrementPeriod.daily, label: Text('Día')),
                  ButtonSegment(
                      value: IncrementPeriod.weekly, label: Text('Semana')),
                  ButtonSegment(
                      value: IncrementPeriod.biweekly, label: Text('Quincena')),
                  ButtonSegment(
                      value: IncrementPeriod.monthly, label: Text('Mes')),
                ],
                selected: {_incrementPeriod},
                onSelectionChanged: (s) =>
                    setState(() => _incrementPeriod = s.first),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _installmentsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  minimalFieldDecoration(label: 'Número de cuotas/períodos'),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: !ready
                  ? Text(
                      'Ingresa el monto y el interés para ver el cálculo.',
                      style:
                          AppFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ResultRow(
                            label: 'Cuota sugerida por período',
                            value: currency.format(perPeriodCharge)),
                        _ResultRow(
                            label: 'Total a pagar',
                            value: currency.format(totalToPay)),
                        _ResultRow(
                            label: 'Ganancia estimada',
                            value: currency.format(totalCharge)),
                        _ResultRow(
                            label: 'Fecha estimada de finalización',
                            value: dateFormat.format(estimatedEndDate)),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: !ready
                  ? null
                  : () {
                      Navigator.pop(
                        context,
                        QuickLoanCalculatorResult(
                          amount: amount,
                          incrementType: _incrementType,
                          incrementValue: _rate ?? 0,
                          incrementPeriod: _incrementPeriod,
                        ),
                      );
                    },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Usar estos valores para crear el préstamo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppFonts.inter(fontSize: 12.5, color: AppTheme.muted)),
          Text(value,
              style: AppFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
