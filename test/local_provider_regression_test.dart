import 'support/panama_contract_fixture.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:contador_engine/main.dart';
import 'package:contador_engine/models/transaction.dart';
import 'package:contador_engine/screens/home_screen.dart';
import 'package:contador_engine/screens/credit_portal_screen.dart';
import 'package:contador_engine/providers/debt_provider.dart';
import 'package:contador_engine/services/local_cache_service.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/models/credit_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = LocalDatabaseService(), cache = LocalCacheService();
  late Directory dir;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    dir = await Directory.systemTemp.createTemp('provider_regression');
    await cache.init(directory: dir.path);
    await db.init();
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('Administración entra directamente a la aplicación original',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final provider = DebtProvider();
    await tester.runAsync(provider.fetchAll);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const ContadorEngineApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CreditPortalScreen), findsOneWidget);
    expect(find.text('Cartera'), findsOneWidget);
    expect(find.text('Solicitudes'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  test('Crear préstamo desde la cartera actualiza capital y permite cobrar',
      () async {
    final provider = DebtProvider();
    addTearDown(provider.dispose);
    await provider.fetchAll();
    await provider.addCustomer('Cliente cartera', '', '');
    await provider.addCapitalEntry(500, 'Capital inicial');
    await provider.addLoan(
      customerId: provider.customers.single.id,
      title: 'Préstamo directo',
      initialAmount: 100,
      incrementType: IncrementType.fixed,
      incrementValue: 0,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(provider.allLoans, hasLength(1));
    expect(provider.moneyInHand, 400);
    await provider.registerPayment(
        provider.allLoans.single.id, 25, 'Cliente cartera');
    await provider.fetchAll();
    expect(provider.moneyInHand, 425);
    expect((await db.getAllLoans()).single['amount_paid'], 25);
  });
  test('Cerrar sesión conserva preferencias y comprobantes', () async {
    await cache.saveBusinessLogoPath('logo.png');
    await cache.setOverdueAlertsEnabled(false);
    await cache.saveReceiptRecord(
        {'id': 'r', 'paymentId': 'p', 'customerId': 'c', 'date': '2026-01-01'});
    final provider = DebtProvider();
    await db.signOut();
    await provider.clearData();
    expect(cache.readBusinessLogoPath(), 'logo.png');
    expect(cache.overdueAlertsEnabled, false);
    expect(cache.receiptForPayment('p'), isNotNull);
    provider.dispose();
  });
  test('Cartera común refresca desembolso y cobro sin duplicarlos en el cierre',
      () async {
    final service = CreditService();
    await db.saveSetting('initial_capital', '2000');
    await db.insertCustomer({'id': 'c', 'name': 'Cliente verificado'});
    await db.signIn('cliente@contador.local', 'ContadorLocal2026!');
    final id = await service.create(
        'Comprar equipo',
        const CreditTerms(principal: 1000, annualRate: 12, months: 12),
        const FinancialProfile(income: 2000, expenses: 500, debtPayments: 0));
    await service.submit(id);
    await db.signIn('analista@contador.local', 'ContadorLocal2026!');
    await service.evaluate(id);
    await service.decide(id, 'advance', 'Análisis favorable');
    await db.signIn('cumplimiento@contador.local', 'ContadorLocal2026!');
    await service.decide(id, 'advance', 'Documentación conforme');
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await service.decide(id, 'advance', 'Aprobación registrada');
    final provider = DebtProvider();
    addTearDown(provider.dispose);
    await provider.fetchAll();
    expect(provider.moneyInHand, 2000);
    expect(provider.activeCapital, 0);
    await service.formalize(id, 'c', 'Acuerdo firmado',
        contract: testPanamaContract);
    await service.disburse(id, DateTime.now(), 'Entrega 001');
    await Future.wait([provider.fetchAll(), provider.fetchAll()]);
    expect(provider.moneyInHand, 1000);
    expect(provider.activeCapital, 1000);
    expect(provider.dailyClosing.newLoansToday, 1);
    expect(provider.dailyClosing.capitalDeliveredToday, 1000);
    await service.pay(id, 100, 'Recibo 001');
    await provider.fetchAll();
    expect(provider.moneyInHand, 1100);
    expect(provider.portfolioPayments, hasLength(1));
    expect(provider.dailyClosing.totalCollectedToday, 100);
    expect(provider.dailyClosing.paymentsCountToday, 1);
    expect(
        provider.dailyClosing.estimatedInterestToday, provider.realizedProfit);
    expect(provider.allLoans, isEmpty);
    await service.voidPayment(service.payments(id).single['id'] as String,
        'Recibo registrado por error');
    await provider.fetchAll();
    expect(provider.moneyInHand, 1000);
    expect(provider.dailyClosing.totalCollectedToday, 0);
    expect(provider.portfolioPayments, isEmpty);
  });
  test(
      'Desactivar alertas y abonar poco no elimina el atraso ni cambia el scoring',
      () async {
    final start = DateTime.now().subtract(const Duration(days: 40));
    await db.importLegacyBackup({
      'version': 1,
      'customers': [
        {'id': 'c', 'name': 'Prueba'}
      ],
      'loans': [
        {
          'id': 'l',
          'customerId': 'c',
          'title': 'Anterior',
          'initialAmount': 100,
          'incrementValue': 10,
          'incrementType': 1,
          'incrementPeriod': 2,
          'startDate': start.toIso8601String()
        }
      ],
      'payments': [],
      'capitalHistory': []
    });
    final provider = DebtProvider();
    await provider.fetchAll();
    expect(provider.overdueCount, 1);
    final score = provider.trustScoreForCustomer('c');
    await cache.setOverdueAlertsEnabled(false);
    expect(provider.trustScoreForCustomer('c'), score);
    await provider.registerPayment('l', 1, 'Prueba');
    expect(provider.overdueCount, 1);
    expect(provider.realizedProfit, 1);
    await expectLater(
        provider.registerPayment('l', 100000, 'Prueba'), throwsArgumentError);
    provider.dispose();
  });
}
