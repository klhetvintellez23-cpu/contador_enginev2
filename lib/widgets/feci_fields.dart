import 'package:flutter/material.dart';
import '../models/credit_engine.dart';

class FeciFields extends StatelessWidget {
  final FeciTreatment treatment;
  final String evidence;
  final void Function(FeciTreatment, String) onChanged;
  const FeciFields(
      {super.key,
      required this.treatment,
      required this.evidence,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(children: [
        DropdownButtonFormField<FeciTreatment>(
            initialValue: treatment,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Tratamiento FECI (si supera USD 5,000)'),
            items: const [
              DropdownMenuItem(
                  value: FeciTreatment.pending,
                  child: Text('Pendiente de revisión')),
              DropdownMenuItem(
                  value: FeciTreatment.applies,
                  child: Text('Aplica · 1% anual sobre saldo')),
              DropdownMenuItem(
                  value: FeciTreatment.exempt,
                  child: Text('Exención documentada')),
              DropdownMenuItem(
                  value: FeciTreatment.outsideScope,
                  child: Text('Operación no sujeta documentada')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v, evidence);
            }),
        if ([FeciTreatment.exempt, FeciTreatment.outsideScope]
            .contains(treatment))
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                  initialValue: evidence,
                  decoration: const InputDecoration(
                      labelText:
                          'Fundamento legal y referencia de evidencia FECI'),
                  onChanged: (v) => onChanged(treatment, v),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? 'Documenta el fundamento y la evidencia.'
                      : null)),
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'No se presume una exención por el nombre o monto de la cuota. La clasificación debe verificarse antes de formalizar.')),
      ]);
}
