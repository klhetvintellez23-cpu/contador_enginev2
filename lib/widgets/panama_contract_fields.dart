import 'package:flutter/material.dart';
import '../models/panama_credit.dart';

class PanamaContractFields extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onChanged;
  const PanamaContractFields({super.key, required this.onChanged});
  @override
  State<PanamaContractFields> createState() => _PanamaContractFieldsState();
}

class _PanamaContractFieldsState extends State<PanamaContractFields> {
  final values = <String, dynamic>{'product': 'personalMonthlyVoluntary'};
  void update(String key, Object? value) {
    setState(() => values[key] = value);
    widget.onChanged(Map<String, dynamic>.from(values));
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Documento contractual',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'Crédito personal en USD, cuotas mensuales y pago voluntario. Para descuentos de salario, hipotecas, refinanciamientos u otros productos se necesita un contrato específico.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de prestamista'),
            items: const [
              DropdownMenuItem(
                  value: 'financiera', child: Text('Financiera · MICI')),
              DropdownMenuItem(
                  value: 'particular',
                  child: Text('Particular o negocio propio')),
              DropdownMenuItem(value: 'banco', child: Text('Banco · SBP')),
            ],
            validator: (v) =>
                v == null ? 'Selecciona el régimen aplicable.' : null,
            onChanged: (v) => update('lenderType', v)),
        for (final field in PanamaContract.fields.entries)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                  decoration: InputDecoration(labelText: field.value),
                  onChanged: (v) => update(field.key, v.trim()),
                  validator: (v) => (v?.trim().length ?? 0) < 3
                      ? 'Completa este dato.'
                      : null)),
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextFormField(
                decoration: const InputDecoration(
                    labelText:
                        'Aseguradora, póliza y devolución de primas (si hay seguro)'),
                onChanged: (v) => update('insuranceEvidence', v.trim()))),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
                'Verifiqué la identidad del deudor y las facultades del firmante.'),
            value: values['identityVerified'] == true,
            onChanged: (v) => update('identityVerified', v)),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
                'Ambas partes aceptaron y firmaron estas condiciones; entregué copia completa al deudor.'),
            subtitle: const Text(
                'Esta constancia registra evidencia externa; no sustituye las firmas.'),
            value: values['accepted'] == true,
            onChanged: (v) => update('accepted', v)),
      ]);
}
