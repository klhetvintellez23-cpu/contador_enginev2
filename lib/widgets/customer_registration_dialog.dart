import 'package:flutter/material.dart';
import '../services/local_database_service.dart';
import '../utils/phone_helper.dart';

class CustomerRegistrationDialog extends StatefulWidget {
  final String initialName;
  const CustomerRegistrationDialog({super.key, required this.initialName});

  @override
  State<CustomerRegistrationDialog> createState() =>
      _CustomerRegistrationDialogState();
}

class _CustomerRegistrationDialogState
    extends State<CustomerRegistrationDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initialName);
  final identification = TextEditingController();
  final phone = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    identification.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final id = await LocalDatabaseService().registerCustomer(
          name: name.text,
          identification: identification.text,
          phone: normalizePanamaPhone(phone.text));
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString().replaceFirst(RegExp(r'^\w+(?: \w+)*: '), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: AlertDialog(
          scrollable: true,
          title: const Text('Registrar cliente'),
          content: SizedBox(
              width: 400,
              child: Form(
                  key: form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Confirma los datos del solicitante para crear su ficha en Cartera.'),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: name,
                            enabled: !saving,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Nombre completo'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Escribe el nombre del cliente.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: identification,
                            enabled: !saving,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Cédula o pasaporte'),
                            validator: (v) => v == null ||
                                    v.replaceAll(RegExp(r'[\s-]'), '').isEmpty
                                ? 'Escribe la identificación del cliente.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: phone,
                            enabled: !saving,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                                labelText: 'Teléfono (opcional)',
                                prefixText: '+507 ')),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)))),
                      ]))),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Guardando…' : 'Guardar y seleccionar')),
          ]));
}
