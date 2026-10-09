import 'document_files.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'local_fonts.dart';
import 'package:provider/provider.dart';
import '../models/backup_preview.dart';
import '../providers/debt_provider.dart';
import 'sensitive_action_guard.dart';
import 'shared_styles.dart';

/// Flujo completo de "Importar respaldo": elige el archivo JSON, valida su
/// formato, muestra un resumen de lo que se va a importar, pide PIN/
/// biometría y recién ahí restaura los datos a través de [DebtProvider].
Future<void> showImportBackupFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  Map<String, dynamic> data;
  try {
    final bytes = await DocumentFiles.pickJson();
    if (bytes == null) return;
    final content = utf8.decode(bytes);
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El archivo no tiene el formato esperado.');
    }
    data = decoded;
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('El archivo elegido no es un respaldo JSON válido.'),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final provider = Provider.of<DebtProvider>(context, listen: false);

  if (!provider.isValidBackupData(data)) {
    messenger.showSnackBar(
      const SnackBar(
        content:
            Text('Este archivo no parece ser un respaldo de Contador Engine.'),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
    return;
  }

  final preview = provider.previewBackup(data);

  if (preview.totalNew == 0) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
            'Este respaldo no tiene registros nuevos: todo ya existe en tu cuenta.'),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final confirmed = await showBlurDialog<bool>(
    context: context,
    builder: (dialogContext) => _ImportPreviewDialog(preview: preview),
  );
  if (confirmed != true || !context.mounted) return;

  requireSensitiveActionUnlock(
    context,
    reason:
        'Vas a importar ${preview.totalNew} registro(s) nuevos a tu cuenta.',
    onUnlocked: () async {
      messenger.showSnackBar(
        const SnackBar(content: Text('Importando respaldo...')),
      );
      try {
        await provider.importBackup(data);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                'Respaldo importado: ${preview.newCustomers} cliente(s), ${preview.newLoans} préstamo(s), ${preview.newPayments} pago(s).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo completar la importación. Intenta nuevamente.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    },
  );
}

class _ImportPreviewDialog extends StatelessWidget {
  final BackupPreview preview;
  const _ImportPreviewDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: dialogShape(),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Text('Importar respaldo',
          style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
      content: dialogContent([
        Text(
          'Se importarán ${preview.newCustomers} cliente(s), ${preview.newLoans} préstamo(s), '
          '${preview.newPayments} pago(s) y ${preview.newCapitalEntries} movimiento(s) de capital.',
          style: AppFonts.inter(fontSize: 13, color: Colors.grey[500]),
        ),
        if (preview.totalDuplicates > 0) ...[
          const SizedBox(height: 12),
          Text(
            '${preview.totalDuplicates} registro(s) ya existen y se omitirán (no se duplican).',
            style: AppFonts.inter(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ]),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Text('Cancelar',
              style: AppFonts.inter(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: solidActionButtonStyle(context),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}
