import 'package:flutter/material.dart';
import '../services/credit_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/finance_ui.dart';

class CreditSettlementScreen extends StatefulWidget {
  final String applicationId;
  const CreditSettlementScreen({super.key, required this.applicationId});
  @override
  State<CreditSettlementScreen> createState() => _CreditSettlementScreenState();
}

class _CreditSettlementScreenState extends State<CreditSettlementScreen> {
  final service = CreditService();
  final reference = TextEditingController();
  late Map<String, dynamic> quote;
  String? error;
  bool confirmed = false, busy = false;
  @override
  void initState() {
    super.initState();
    quote = service.settlementQuote(widget.applicationId);
  }

  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  String money(String key) =>
      'USD ${((quote[key] as int) / 100).toStringAsFixed(2)}';
  Future<void> save() async {
    if (busy || !confirmed) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await service.settle(widget.applicationId, quote, reference.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refund = (quote['netCents'] as int) < 0;
    return Scaffold(
        appBar: AppBar(title: const Text('Cancelar préstamo')),
        body: PageFrame(
            maxWidth: 720,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Text(
                  refund ? 'Devolución al cliente' : 'Liquidación total de hoy',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              DetailRows({
                'Capital pendiente antes de liquidar':
                    money('principalOutstandingCents'),
                'Interés devengado total': money('interestCents'),
                'Comisión contractual': money('feeCents'),
                'Seguro de períodos iniciados': money('insuranceCents'),
                'FECI devengado total': money('feciCents'),
                'Mora devengada': money('lateCents'),
                'Pagos recibidos': money('receivedCents'),
                'Intereses eliminados': money('interestWaivedCents'),
                'FECI eliminado': money('feciWaivedCents'),
                'Primas futuras eliminadas': money('insuranceWaivedCents'),
                'Penalización': money('penaltyCents'),
                refund ? 'Importe a devolver' : 'Importe a cobrar':
                    'USD ${((quote['netCents'] as int).abs() / 100).toStringAsFixed(2)}',
              }),
              const SizedBox(height: 16),
              const Text(
                  'El importe neto resulta del capital original más los cargos devengados menos todos los pagos recibidos. Se prorratea el interés dentro del período mensual. La devolución adicional de primas de períodos iniciados se tramita según la póliza.'),
              const SizedBox(height: 20),
              TextField(
                  controller: reference,
                  decoration: InputDecoration(
                      labelText: refund
                          ? 'Referencia de la devolución realizada'
                          : 'Referencia del cobro realizado')),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => confirmed = v ?? false),
                  title: Text(refund
                      ? 'Realicé la devolución y entregué su comprobante.'
                      : 'Recibí el importe indicado y confirmé la cancelación con el cliente.')),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(
                  onPressed: confirmed && !busy ? save : null,
                  child: Text(
                      busy ? 'Registrando…' : 'Registrar cancelación total')),
            ])));
  }
}
