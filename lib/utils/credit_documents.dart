import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../services/credit_service.dart';
import '../models/credit_account.dart';
import '../models/credit_engine.dart';
import '../models/panama_credit.dart';
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
        'paymentBreakdowns': {
          for (final p in service.payments(app['id'] as String))
            p['id']: service.paymentBreakdown(p)
        },
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
    final typedTerms = CreditTerms.fromMap(Map<String, dynamic>.from(terms));
    final contract = service.account(app['id'] as String)?['contract'] as Map?;
    final settlement =
        service.account(app['id'] as String)?['settlement'] as Map?;
    final eval = app['evaluation'] as Map?;
    final rows = (data['balances'] as List?) ?? [];
    doc.addPage(pw.MultiPage(
        build: (_) => [
              pw.Text('ContadorEngine - Expediente de credito',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  'Expediente ${app['id']} - ${contract == null ? 'Sin documento contractual registrado' : 'Condiciones y evidencia contractual registradas'}'),
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
                  'Seguro mensual: ${terms['monthlyInsurance']} | Comision propia inicial: ${terms['openingFee']}'),
              ..._conditions(typedTerms),
              if (contract != null) ..._contract(contract),
              if (settlement != null) ...[
                pw.SizedBox(height: 12),
                pw.Text('CANCELACION TOTAL - ${settlement['date']}'),
                pw.Text(
                    'Neto cobrado (negativo = devuelto): USD ${((settlement['netCents'] as int) / 100).toStringAsFixed(2)}'),
                pw.Text(
                    'Intereses eliminados: USD ${((settlement['interestWaivedCents'] as int) / 100).toStringAsFixed(2)} | FECI eliminado: USD ${((settlement['feciWaivedCents'] as int) / 100).toStringAsFixed(2)} | Seguro futuro eliminado: USD ${((settlement['insuranceWaivedCents'] as int) / 100).toStringAsFixed(2)} | Penalizacion: 0.00'),
                pw.Text(
                    'La tabla siguiente muestra la liquidacion; el plan original se conserva en el expediente JSON.'),
              ],
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
                      'FECI',
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
                          'feciCents',
                          'feeCents',
                          'lateCents',
                          'remainingCents'
                        ].map((k) =>
                            (((r[k] as num?) ?? 0) / 100).toStringAsFixed(2))
                      ];
                    }).toList(),
                    cellStyle: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 12),
              pw.Text('Decisiones y motivos'),
              ...((app['decisions'] as List?) ?? []).map((d) => pw.Text(
                  '${d['date']} | ${d['role']} | ${d['to']} | ${d['reason']}')),
              pw.SizedBox(height: 12),
              pw.Text('Pagos (incluye anulaciones)'),
              ...service.payments(app['id'] as String).expand((p) {
                final breakdown = service.paymentBreakdown(p);
                return [
                  pw.Text(
                      '${p['date']} | ${p['reference']} | ${p['direction'] == 'refund' ? 'Devolucion' : 'Cobro'} USD ${((p['amountCents'] as num) / 100).toStringAsFixed(2)} | ${p['voided'] == true ? 'ANULADO: ${p['voidReason']}' : 'Registrado'}'),
                  if (breakdown.isNotEmpty)
                    pw.Text(
                        'Capital: ${_usd(breakdown['principalCents'])}; interes: ${_usd(breakdown['interestCents'])}; seguro: ${_usd(breakdown['insuranceCents'])}; comision: ${_usd(breakdown['feeCents'])}; FECI: ${_usd(breakdown['feciCents'])}; mora: ${_usd(breakdown['lateCents'])}; saldo capital: ${_usd(breakdown['principalBalanceCents'])}; saldo contractual: ${_usd(breakdown['balanceCents'])}'),
                  if (p['kind'] == 'settlement')
                    pw.Text(
                        'Importes negativos en el desglose representan ajustes o devoluciones de cargos previamente pagados.'),
                  pw.SizedBox(height: 8)
                ];
              }),
            ]));
    return doc.save();
  }

  static String _usd(num? cents) =>
      'USD ${((cents ?? 0) / 100).toStringAsFixed(2)}';
  static List<pw.Widget> _conditions(CreditTerms terms) => [
        pw.Text(
            'Interes total programado: ${_usd(CreditEngine.schedule(terms, DateTime(2024, 1, 1)).fold<int>(0, (s, r) => s + r.interestCents))}. Total contractual sin mora: ${_usd(CreditEngine.schedule(terms, DateTime(2024, 1, 1)).fold<int>(0, (s, r) => s + r.totalCents))}. Numero de cuotas: ${terms.months}.'),
        pw.Text(
            'Tasa efectiva anual (TIR mensual anualizada; interes y comision propia): ${CreditEngine.effectiveAnnualRate(terms).toStringAsFixed(4)}%'),
        pw.Text(
            'Costo efectivo anual incluyendo primas de seguro de terceros y FECI: ${CreditEngine.effectiveAnnualRate(terms, includeThirdParties: true).toStringAsFixed(4)}%'),
        pw.Text(
            'FECI: ${terms.principal <= 5000 ? 'No aplica por monto' : terms.chargesFeci ? '1% anual sobre saldo, dividido entre 12' : '${terms.feciTreatment.name}: ${terms.feciEvidence}'}'),
        pw.Text(
            'Mora: ${terms.policyVersion >= 2 ? '${terms.lateFeePercent}% una sola vez sobre capital impago al vencer la cuota' : '${terms.lateFee} por cuota, condiciones anteriores'}.'),
        pw.Text(
            'Cancelacion total sin penalizacion. Se eliminan intereses y FECI no devengados y primas de periodos futuros. Prorrateo diario dentro del periodo mensual, sin capitalizar intereses. Las devoluciones adicionales de seguro dependen de la poliza.'),
        pw.Text(
            'Pagos ordinarios: mora, comision propia, seguro de terceros, FECI, interes y capital. Adelantar cuotas es distinto de cancelar el prestamo.'),
      ];

  static List<pw.Widget> _contract(Map data) => [
        pw.SizedBox(height: 16),
        pw.Text(
            'DOCUMENTO CONTRACTUAL - ${data['templateVersion'] ?? PanamaContract.version}'),
        for (final entry in PanamaContract.fields.entries)
          pw.Text(
              '${entry.value}: ${data[entry.key]?.toString().trim().isNotEmpty == true ? data[entry.key] : 'PENDIENTE'}'),
        pw.Text(
            'Regimen: ${data['lenderType'] ?? 'PENDIENTE'} | Deudor: ${data['borrowerName'] ?? 'PENDIENTE'}'),
        pw.Text(
            'Fecha: ${data['date'] ?? 'PENDIENTE'} | Destino: ${data['purpose'] ?? 'PENDIENTE'}'),
        pw.Text('La propuesta tiene vigencia durante el dia de emision. Una vez aceptada, rigen el plazo y las condiciones pactadas.'),
        pw.Text(
            'Desembolso neto: ${_usd(data['netDisbursementCents'] as num?)}. Sin retenciones ni cancelaciones de otras deudas.'),
        pw.Text('Seguro: ${data['insuranceEvidence'] ?? 'No contratado'}'),
        pw.Text(
            'Pago voluntario mensual; primera cuota un mes despues del desembolso y restantes en el mismo dia, ajustado al ultimo dia del mes cuando corresponda. El calendario de entrega se incorpora al expediente.'),
        pw.Text(
            'Comision propia en primera cuota. Primas de seguro y FECI se destinan integramente a terceros. Sin garantias reales ni codeudores en este producto.'),
        pw.Text(
            'Aceptacion y firmas verificadas: ${data['accepted'] == true ? 'Registradas con evidencia externa' : 'PENDIENTES'}'),
        if (data['sha256'] != null)
          pw.Text('Huella del documento registrado: ${data['sha256']}',
              style: const pw.TextStyle(fontSize: 8)),
      ];

  static Future<String?> exportContractDraft(Map<String, dynamic> app,
      Map<String, dynamic> data, String borrower) async {
    final terms =
        CreditTerms.fromMap(Map<String, dynamic>.from(app['terms'] as Map));
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font));
    final plan = CreditEngine.schedule(terms, DateTime.now());
    final body = {
      ...data,
      'borrowerName': borrower,
      'purpose': app['purpose'],
      'date': DateTime.now().toIso8601String(),
      'netDisbursementCents': (terms.principal * 100).round(),
      'accepted': false
    };
    doc.addPage(pw.MultiPage(
        build: (_) => [
              pw.Text(
                  'BORRADOR CONTRACTUAL - revisar y completar antes de firmar'),
              pw.Text(
                  'Referencia: ${app['id']} | Monto ${terms.principal} USD | Plazo ${terms.months} meses | Tasa nominal anual ${terms.annualRate}%'),
              ..._conditions(terms),
              ..._contract(body),
              pw.Text(
                  'Total contractual sin mora: ${_usd(plan.fold<int>(0, (s, r) => s + r.totalCents))}'),
              pw.TableHelper.fromTextArray(
                  headers: [
                    'Cuota',
                    'Capital',
                    'Interes',
                    'Seguro',
                    'Comision',
                    'FECI',
                    'Total'
                  ],
                  data: plan
                      .map((r) => [
                            r.number,
                            ...[
                              r.principalCents,
                              r.interestCents,
                              r.insuranceCents,
                              r.feeCents,
                              r.feciCents,
                              r.totalCents
                            ].map((v) => (v / 100).toStringAsFixed(2))
                          ])
                      .toList(),
                  cellStyle: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 24),
              pw.Text(
                  'Firma del deudor: ____________________  Fecha: __________'),
              pw.SizedBox(height: 24),
              pw.Text(
                  'Firma del prestamista: ________________  Fecha: __________'),
            ]));
    return DocumentFiles.save(
        'Contrato_borrador_${app['id']}.pdf', await doc.save());
  }
}
