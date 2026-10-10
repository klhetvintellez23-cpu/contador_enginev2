import 'document_files.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/customer.dart';
import '../models/transaction.dart';
import '../models/loan_calculator.dart';
import '../models/payment.dart';
import '../models/capital_entry.dart';
import '../models/credit_account.dart';

class ExportHelper {
  static Future<String?> exportDebtsToCSV(
    List<Customer> customers,
    List<LoanTransaction> allLoans,
    List<Payment> allPayments,
    List<CapitalEntry> capitalHistory,
    double initialCapital, {
    Map<String, dynamic>? portfolioState,
  }) async {
    try {
      final StringBuffer csv = StringBuffer();

      // Excel hint for the separator
      csv.writeln('sep=;');

      // BOM for UTF-8 in Excel
      csv.write('\uFEFF');

      // ═══ SECCIÓN 1: LIBRO DE MOVIMIENTOS ═══
      csv.writeln('MOVIMIENTOS DE CAJA');
      csv.writeln('FECHA;DESCRIPCIÓN;CLIENTE;INGRESOS;EGRESOS;SALDO EN CAJA');

      final List<_Movement> movements = [];

      // 1. Inyecciones de capital (INGRESOS) - Filtramos las que ya están incluidas en initialCapital si es necesario
      // Pero mejor asumimos que capitalHistory son todas las entradas/salidas de capital
      for (var entry in capitalHistory) {
        movements.add(_Movement(
          date: entry.createdAt,
          description: entry.note ?? 'Inyección de capital',
          client: '---',
          income: entry.amount > 0 ? entry.amount : 0,
          expense: entry.amount < 0 ? entry.amount.abs() : 0,
        ));
      }

      // 2. Préstamos otorgados (EGRESOS)
      for (var loan in allLoans) {
        final customer =
            customers.where((c) => c.id == loan.customerId).toList();
        final name = customer.isNotEmpty ? customer.first.name : 'Cliente';

        movements.add(_Movement(
          date: loan.startDate,
          description: 'Préstamo: ${loan.title}',
          client: name,
          income: 0,
          expense: loan.initialAmount,
        ));
      }

      // 3. Cobros / Abonos recibidos (INGRESOS)
      for (var payment in allPayments) {
        final loan = allLoans.where((l) => l.id == payment.loanId).toList();
        final loanTitle = loan.isNotEmpty ? loan.first.title : 'Préstamo';

        movements.add(_Movement(
          date: payment.date,
          description: 'Abono recibido — $loanTitle',
          client: payment.customerName ?? 'Cliente',
          income: payment.amount,
          expense: 0,
        ));
      }

      if (portfolioState != null) {
        for (final account
            in PortfolioLedger.rows(portfolioState, 'credit_accounts')
                .where((a) => a['status'] == 'active')) {
          final name = customers
                  .where((c) => c.id.toString() == account['customerId'])
                  .firstOrNull
                  ?.name ??
              'Cliente';
          movements.add(_Movement(
              date: DateTime.parse(account['disbursedAt'] as String),
              description:
                  'Crédito amortizado: ${account['disbursementReference']}',
              client: name,
              income: 0,
              expense: (account['cashPrincipalCents'] as int) / 100));
          final baseline = (account['cashPaymentBaselineCents'] as int) / 100;
          if (baseline > 0) {
            movements.add(_Movement(
                date: DateTime.parse(account['formalizedAt'] as String),
                description:
                    'Conciliación: cobros anteriores ya incluidos en caja',
                client: name,
                income: 0,
                expense: baseline));
          }
          for (final p
              in PortfolioLedger.rows(portfolioState, 'credit_payments').where(
                  (p) =>
                      p['applicationId'] == account['applicationId'] &&
                      p['voided'] != true)) {
            movements.add(_Movement(
                date: DateTime.parse(p['date'] as String),
                description: 'Cobro crédito amortizado: ${p['reference']}',
                client: name,
                income: (p['amountCents'] as int) / 100,
                expense: 0));
          }
        }
      }

      // Ordenar por fecha cronológica
      movements.sort((a, b) => a.date.compareTo(b.date));

      // Escribir fila de Saldo Inicial (si no hay movimientos previos o como punto de partida)
      double runningBalance = capitalHistory.isEmpty ? initialCapital : 0;
      if (capitalHistory.isEmpty) {
        csv.writeln(
            ';;Capital inicial registrado;${initialCapital.toStringAsFixed(2)};;${initialCapital.toStringAsFixed(2)}');
      }

      for (var m in movements) {
        runningBalance += m.income - m.expense;

        final dateStr =
            '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}';

        final desc = _escape(m.description);
        final client = _escape(m.client);

        // Usamos coma como separador decimal para Excel en español si es necesario,
        // pero el punto es más estándar en programación. Usaremos punto.
        final incomeStr = m.income > 0 ? m.income.toStringAsFixed(2) : '';
        final expenseStr = m.expense > 0 ? m.expense.toStringAsFixed(2) : '';
        final balanceStr = runningBalance.toStringAsFixed(2);

        csv.writeln(
            '$dateStr;$desc;$client;$incomeStr;$expenseStr;$balanceStr');
      }

      csv.writeln(';;;;;'); // Fila vacía
      csv.writeln(';;;;TOTAL EN CAJA;$runningBalance');
      csv.writeln(';;;;;'); // Fila vacía
      csv.writeln(';;;;;'); // Fila vacía

      // ═══ SECCIÓN 2: RESUMEN DE CARTERA POR CLIENTE ═══
      csv.writeln('RESUMEN DE CLIENTES Y DEUDAS');
      csv.writeln('CLIENTE;CÉDULA;PRÉSTAMOS;INVERTIDO;COBRADO;DEUDA PENDIENTE');

      for (var customer in customers) {
        final customerLoans =
            allLoans.where((l) => l.customerId == customer.id).toList();
        final accounts = portfolioState == null
            ? <Map<String, dynamic>>[]
            : PortfolioLedger.rows(portfolioState, 'credit_accounts')
                .where((a) =>
                    a['status'] == 'active' &&
                    a['customerId'] == customer.id.toString())
                .toList();
        if (customerLoans.isEmpty && accounts.isEmpty) continue;

        double totalLent = 0;
        double totalPaid = 0;
        double totalDebt = 0;

        for (var loan in customerLoans) {
          final state = LoanCalculator.compute(
              loan, allPayments.where((p) => p.loanId == loan.id));
          totalLent += loan.initialAmount;
          totalPaid += state.totalPaid;
          // Un préstamo saldado (o pagado de más) no debe restar del total
          // pendiente de otros préstamos activos del mismo cliente.
          final debt = state.totalDebt;
          if (debt > 0) totalDebt += debt;
        }
        for (final account in accounts) {
          totalLent +=
              ((account['terms'] as Map)['principal'] as num).toDouble();
          totalPaid += PortfolioLedger.activePayments(
                  portfolioState!, account['applicationId'] as String) /
              100;
          totalDebt += PortfolioLedger.accountBalance(portfolioState, account)
                  .fold<int>(0, (s, r) => s + (r['remainingCents'] as int)) /
              100;
        }

        csv.writeln('${_escape(customer.name)};'
            '${_escape(customer.cedula ?? "N/A")};'
            '${customerLoans.length + accounts.length};'
            '${totalLent.toStringAsFixed(2)};'
            '${totalPaid.toStringAsFixed(2)};'
            '${totalDebt.toStringAsFixed(2)}');
      }
      csv.writeln(
          'ALCANCE;Préstamos directos y créditos activados. El saldo de créditos amortizados incluye cuotas futuras y cargos pactados.');

      // Guardar el archivo
      return DocumentFiles.save(
          'Cuentas_Contador_Engine.csv', utf8.encode(csv.toString()));
    } catch (e) {
      return null;
    }
  }

  /// Reporte en PDF con el mismo resumen de cartera que la sección 2 del
  /// CSV, pensado para imprimir o enviar tal cual.
  static Future<String?> exportDebtsToPDF(
    List<Customer> customers,
    List<LoanTransaction> allLoans,
    List<Payment> allPayments,
    double initialCapital,
    String? businessName, {
    Map<String, dynamic>? portfolioState,
  }) async {
    try {
      final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
      final regular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final bold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      final doc =
          pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

      final rows = <List<String>>[];
      for (var customer in customers) {
        final customerLoans =
            allLoans.where((l) => l.customerId == customer.id).toList();
        final accounts = portfolioState == null
            ? <Map<String, dynamic>>[]
            : PortfolioLedger.rows(portfolioState, 'credit_accounts')
                .where((a) =>
                    a['status'] == 'active' &&
                    a['customerId'] == customer.id.toString())
                .toList();
        if (customerLoans.isEmpty && accounts.isEmpty) continue;

        double totalLent = 0;
        double totalPaid = 0;
        double totalDebt = 0;
        for (var loan in customerLoans) {
          final state = LoanCalculator.compute(
              loan, allPayments.where((p) => p.loanId == loan.id));
          totalLent += loan.initialAmount;
          totalPaid += state.totalPaid;
          // Un préstamo saldado (o pagado de más) no debe restar del total
          // pendiente de otros préstamos activos del mismo cliente.
          final debt = state.totalDebt;
          if (debt > 0) totalDebt += debt;
        }
        for (final account in accounts) {
          totalLent +=
              ((account['terms'] as Map)['principal'] as num).toDouble();
          totalPaid += PortfolioLedger.activePayments(
                  portfolioState!, account['applicationId'] as String) /
              100;
          totalDebt += PortfolioLedger.accountBalance(portfolioState, account)
                  .fold<int>(0, (s, r) => s + (r['remainingCents'] as int)) /
              100;
        }

        rows.add([
          customer.name,
          customer.cedula ?? 'N/A',
          (customerLoans.length + accounts.length).toString(),
          currency.format(totalLent),
          currency.format(totalPaid),
          currency.format(totalDebt),
        ]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              businessName != null && businessName.isNotEmpty
                  ? businessName
                  : 'Contador Engine',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Reporte de cartera — generado el '
              '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            if (portfolioState != null) ...[
              pw.Text(
                  'Disponible: ${currency.format(PortfolioLedger.availableCash(portfolioState))}'),
              pw.Text(
                  'Incluye préstamos directos y créditos activados. El saldo amortizado incluye cuotas futuras y cargos pactados; no equivale al capital pendiente.',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 12),
            ],
            pw.Text('Resumen de clientes y deudas',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Cliente',
                'Cédula',
                'Préstamos',
                'Invertido',
                'Cobrado',
                'Deuda pendiente'
              ],
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
            ),
          ],
        ),
      );

      return DocumentFiles.save(
          'Reporte_Contador_Engine.pdf', await doc.save());
    } catch (e) {
      return null;
    }
  }

  /// Respaldo completo de todos los datos del negocio en JSON, para
  /// guardarlo aparte como copia de seguridad manual.
  static Future<String?> exportBackupToJSON(
    List<Customer> customers,
    List<LoanTransaction> allLoans,
    List<Payment> allPayments,
    List<CapitalEntry> capitalHistory,
    double initialCapital,
    String? businessName,
  ) async {
    try {
      final backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'businessName': businessName,
        'initialCapital': initialCapital,
        'customers': customers.map((c) => c.toMap()).toList(),
        'loans': allLoans.map((l) => l.toMap()).toList(),
        'payments': allPayments.map((p) => p.toMap()).toList(),
        'capitalHistory':
            capitalHistory.map((e) => e.toMap(snakeCase: false)).toList(),
      };

      return DocumentFiles.save('Respaldo_Contador_Engine.json',
          utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)));
    } catch (e) {
      return null;
    }
  }

  static String _escape(String value) {
    // Escapar para CSV con punto y coma
    String result = value.replaceAll(';', ' ');
    if (result.contains('"') || result.contains('\n')) {
      result = '"${result.replaceAll('"', '""')}"';
    }
    return result;
  }
}

class _Movement {
  final DateTime date;
  final String description;
  final String client;
  final double income;
  final double expense;

  _Movement({
    required this.date,
    required this.description,
    required this.client,
    required this.income,
    required this.expense,
  });
}
