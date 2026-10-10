import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../services/credit_service.dart';
import '../models/credit_account.dart';
import 'document_files.dart';

class CreditDocuments {
  static Map<String, dynamic> report(
          CreditService service, Map<String, dynamic> app) =>
      {
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'application': app,
        if (app['status'] == 'approved')
          'financialStatus': service.lifecycle(app).name,
        'creditAccount': service.account(app['id'] as String),
        'payments': service.payments(app['id'] as String),
        if (app['status'] == 'approved' &&
            [CreditLifecycle.active, CreditLifecycle.legacy]
                .contains(service.lifecycle(app)))
          'balances': service.balance(app),
      };
  static Future<String?> export(CreditService service, Map<String, dynamic> app,
      {required bool pdf}) async {
    final data = report(service, app);
    final name =
        'Credito_${app['id']}_${DateTime.now().millisecondsSinceEpoch}';
    if (!pdf) {
      return DocumentFiles.save('$name.json',
          utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    }
    return DocumentFiles.save('$name.pdf', await pdfBytes(service, app));
  }

  static Future<List<int>> pdfBytes(
      CreditService service, Map<String, dynamic> app) async {
    final data = report(service, app);
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final doc =
        pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final terms = app['terms'] as Map;
    final eval = app['evaluation'] as Map?;
    final rows = (data['balances'] as List?) ?? [];
    doc.addPage(pw.MultiPage(
        build: (_) => [
              pw.Text('ContadorEngine - Expediente de credito',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Simulacion academica - ${app['id']}'),
              pw.Text(
                  'Solicitante: ${app['applicant']} | Estado: ${app['status']}'),
              if (app['status'] == 'approved')
                pw.Text('Estado financiero: ${service.lifecycle(app).label}'),
              if (service.account(app['id'] as String)?['status'] == 'active')
                pw.Text(
                    'Desembolso registrado: ${service.account(app['id'] as String)!['disbursedAt']} | Referencia: ${service.account(app['id'] as String)!['disbursementReference']}'),
              pw.Text(
                  'Monto: ${terms['principal']} | Tasa nominal anual: ${terms['annualRate']}% | Meses: ${terms['months']} | Sistema: ${terms['method']}'),
              pw.Text(
                  'Seguro mensual: ${terms['monthlyInsurance']} | Comision inicial: ${terms['openingFee']} | Mora por cuota: ${terms['lateFee']}'),
              if (eval != null)
                pw.Text(
                    'DTI: ${((eval['dti'] as num) * 100).toStringAsFixed(2)}% | Puntaje: ${eval['score']} | Reglas v${eval['rulesVersion']}'),
              pw.SizedBox(height: 12),
              if (rows.isNotEmpty)
                pw.TableHelper.fromTextArray(
                    headers: [
                      'Cuota',
                      'Vence',
                      'Capital',
                      'Interes',
                      'Seguro',
                      'Comision',
                      'Mora',
                      'Pendiente'
                    ],
                    data: rows.map((raw) {
                      final r = raw as Map;
                      return [
                        r['number'],
                        r['due'].toString().substring(0, 10),
                        ...[
                          'principalCents',
                          'interestCents',
                          'insuranceCents',
                          'feeCents',
                          'lateCents',
                          'remainingCents'
                        ].map((k) => ((r[k] as num) / 100).toStringAsFixed(2))
                      ];
                    }).toList(),
                    cellStyle: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 12),
              pw.Text('Decisiones y motivos'),
              ...((app['decisions'] as List?) ?? []).map((d) => pw.Text(
                  '${d['date']} | ${d['role']} | ${d['to']} | ${d['reason']}')),
              pw.SizedBox(height: 12),
              pw.Text('Pagos (incluye anulaciones)'),
              ...service.payments(app['id'] as String).map((p) => pw.Text(
                  '${p['date']} | ${p['reference']} | ${((p['amountCents'] as num) / 100).toStringAsFixed(2)} | ${p['voided'] == true ? 'ANULADO: ${p['voidReason']}' : 'Registrado'}')),
            ]));
    return doc.save();
  }
}
