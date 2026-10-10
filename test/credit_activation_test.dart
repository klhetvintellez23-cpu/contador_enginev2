import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/models/credit_account.dart';
import 'package:contador_engine/models/credit_engine.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/utils/export_helper.dart';
import 'package:contador_engine/models/customer.dart';
import 'package:contador_engine/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = LocalDatabaseService();
  final service = CreditService();
  late Directory directory;
  const terms = CreditTerms(principal: 1000, annualRate: 12, months: 12);
  Future<void> login(String user) =>
      db.signIn('$user@contador.local', 'ContadorLocal2026!');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('credit_activation');
    Hive.init(directory.path);
    await db.init();
    await login('admin');
    await db.insertCustomer({'id': 'customer', 'name': 'Ana'});
    await db.saveSetting('initial_capital', '2000');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<String> approved() async {
    await login('cliente');
    final id = await service.create('Compra de equipo', terms,
        const FinancialProfile(income: 2000, expenses: 600, debtPayments: 100));
    await service.submit(id);
    await login('analista');
    await service.evaluate(id);
    await service.decide(id, 'advance', 'Análisis favorable');
    await login('cumplimiento');
    await service.decide(id, 'advance', 'Documentación revisada');
    await login('admin');
    await service.decide(id, 'advance', 'Solicitud aprobada');
    return id;
  }

  test(
      'CSV y PDF incluyen ambas carteras y concilian el capital inicial sin historial',
      () async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final id = await approved();
    await service.formalize(id, 'customer', 'Acuerdo firmado');
    await service.disburse(id, DateTime.now(), 'Entrega 001');
    await service.pay(id, 100, 'Recibo 001');
    final loan = LoanTransaction(
        id: 'direct',
        customerId: 'customer',
        title: 'Directo',
        initialAmount: 100,
        incrementType: IncrementType.fixed,
        incrementValue: 0,
        startDate: DateTime.now());
    await db.insertLoan(loan.toMap(snakeCase: true));
    final snapshot = db.readPortfolio();
    final customers = [Customer.fromMap((await db.getCustomers()).single)];
    final csvPath = await ExportHelper.exportDebtsToCSV(
        customers, [loan], [], [], 2000,
        portfolioState: snapshot);
    expect(csvPath, isNotNull);
    final csv = await File(csvPath!).readAsString();
    expect(csv, contains('TOTAL EN CAJA;1000.0'));
    expect(csv, contains(';2;1100.00;100.00;1066.19'));
    expect(csv, contains('Cobro crédito amortizado: Recibo 001'));
    final pdfPath = await ExportHelper.exportDebtsToPDF(
        customers, [loan], [], 2000, 'Negocio',
        portfolioState: snapshot);
    expect(pdfPath, isNotNull);
    expect(ascii.decode((await File(pdfPath!).readAsBytes()).take(4).toList()),
        '%PDF');
  });

  test(
      'Aprobar y formalizar no desembolsa, no genera deuda cobrable ni descuenta caja',
      () async {
    final id = await approved();
    final app = service.applications.single;
    expect(service.lifecycle(app), CreditLifecycle.awaitingFormalization);
    expect(service.balance(app), isEmpty);
    expect(service.portfolioSummary['balanceCents'], 0);
    expect(await db.getAllLoans(), isEmpty);
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
    await expectLater(service.pay(id, 100, 'recibo'), throwsStateError);
    await expectLater(
        service.formalize(id, 'missing', 'acuerdo'), throwsArgumentError);
    await service.formalize(id, 'customer', 'acuerdo-firmado');
    expect(service.lifecycle(app), CreditLifecycle.formalized);
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
    await expectLater(service.pay(id, 100, 'recibo'), throwsStateError);
    await expectLater(
        service.formalize(id, 'customer', 'acuerdo-firmado'), throwsStateError);
  });
  test('Desembolso único, plan efectivo, pagos, anulación y capital compartido',
      () async {
    final id = await approved();
    await service.formalize(id, 'customer', 'acuerdo-firmado');
    final now = DateTime.now();
    await Future.wait([
      service.disburse(id, now, 'entrega-1'),
      service.disburse(id, now, 'entrega-1'),
    ]);
    final account = service.account(id)!;
    expect(PortfolioLedger.rows(db.readSnapshot(), 'credit_accounts'),
        hasLength(1));
    expect(await db.getAllLoans(), isEmpty);
    expect(account['schedule'], hasLength(12));
    expect(
        (account['schedule'] as List).first['due'],
        CreditEngine.schedule(terms, DateTime(now.year, now.month, now.day))
            .first
            .due
            .toIso8601String());
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1000);
    await expectLater(
        service.disburse(id, now, 'otra-entrega'), throwsStateError);
    await service.pay(id, 100, 'recibo-1');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1100);
    await expectLater(service.pay(id, 100, 'recibo-1'), throwsStateError);
    await service.voidPayment(
        service.payments(id).single['id'] as String, 'Corrección del recibo');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1000);
    await expectLater(
        db.insertLoan({
          'id': 'direct',
          'customer_id': 'customer',
          'title': 'Directo',
          'initial_amount': 1100,
          'increment_value': 0,
          'start_date': now.toIso8601String()
        }),
        throwsStateError);
  });
  test(
      'Capital insuficiente revierte toda la activación y preserva la formalización',
      () async {
    final id = await approved();
    await service.formalize(id, 'customer', 'acuerdo-firmado');
    await db.saveSetting('initial_capital', '500');
    final before = jsonEncode(db.readSnapshot());
    await expectLater(
        service.disburse(id, DateTime.now(), 'entrega-1'), throwsStateError);
    expect(jsonEncode(db.readSnapshot()), before);
    expect(service.account(id)!['status'], 'formalized');
    await login('analista');
    await expectLater(
        service.disburse(id, DateTime.now(), 'entrega-1'), throwsStateError);
    await expectLater(
        service.formalize(id, 'customer', 'acuerdo-firmado'), throwsStateError);
  });
  test(
      'Respaldo v3 conserva activación y rechaza plan alterado o crédito duplicado',
      () async {
    final id = await approved();
    await service.formalize(id, 'customer', 'acuerdo-firmado');
    await service.disburse(id, DateTime.now(), 'entrega-1');
    await service.pay(id, 100, 'recibo-1');
    final backup = jsonDecode(jsonEncode(db.exportBusinessBackup()))
        as Map<String, dynamic>;
    expect(backup['version'], 3);
    await db.restoreBusinessBackup(backup);
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1100);
    final broken = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
    broken['business']['credit_accounts'][0]['schedule'][0]['principalCents'] =
        1;
    await expectLater(db.restoreBusinessBackup(broken), throwsArgumentError);
    final duplicated = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
    final copy = Map<String, dynamic>.from(
        duplicated['business']['credit_accounts'][0] as Map)
      ..['id'] = 'other';
    (duplicated['business']['credit_accounts'] as List).add(copy);
    await expectLater(
        db.restoreBusinessBackup(duplicated), throwsArgumentError);
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1100);
  });
  test(
      'Crédito anterior mantiene plan y pagos; conciliación explícita sin doble caja',
      () async {
    final start = DateTime.now().subtract(const Duration(days: 50));
    await db.transaction('fixture:anterior', (s) {
      s['applications'] = [
        {
          'id': 'legacy',
          'ownerId': 'cliente',
          'applicant': 'Solicitante',
          'purpose': 'Crédito anterior',
          'status': 'approved',
          'terms': terms.toMap(),
          'profile': const FinancialProfile(
                  income: 2000, expenses: 600, debtPayments: 100)
              .toMap(),
          'approvedAt': start.toIso8601String(),
          'schedule':
              CreditEngine.schedule(terms, start).map((r) => r.toMap()).toList()
        }
      ];
      s['credit_payments'] = [
        {
          'id': 'old-payment',
          'applicationId': 'legacy',
          'amountCents': 10000,
          'reference': 'old-1',
          'date': DateTime.now().toIso8601String(),
          'voided': false
        }
      ];
    });
    final oldPlan = jsonEncode(service.applications.single['schedule']);
    expect(
        service.lifecycle(service.applications.single), CreditLifecycle.legacy);
    await expectLater(service.pay('legacy', 10, 'nuevo-1'), throwsStateError);
    await service.reconcileLegacy(
        'legacy', 'customer', start, 'Entrega verificada',
        cashAlreadyIncluded: true);
    expect(jsonEncode(service.account('legacy')!['schedule']), oldPlan);
    expect(service.payments('legacy'), hasLength(1));
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
    await service.pay('legacy', 50, 'nuevo-1');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 2050);
    await service.voidPayment('old-payment', 'Corrección del cobro anterior');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1950);
    await expectLater(
        service.reconcileLegacy(
            'legacy', 'customer', start, 'Entrega verificada',
            cashAlreadyIncluded: true),
        throwsStateError);
    await db.restoreBusinessBackup(db.exportBusinessBackup());
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1950);
  });
}
