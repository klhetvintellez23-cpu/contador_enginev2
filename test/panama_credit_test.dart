import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/models/credit_engine.dart';
import 'package:contador_engine/models/credit_account.dart';
import 'package:contador_engine/models/panama_credit.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/utils/credit_documents.dart';
import 'support/panama_contract_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const terms = CreditTerms(principal: 1000, annualRate: 12, months: 2);
  final start = DateTime(2026, 1, 1);
  List<Map<String, dynamic>> plan(CreditTerms t) =>
      CreditEngine.schedule(t, start).map((r) => r.toMap()).toList();
  Map<String, dynamic> quote(DateTime at,
          {List<Map<String, dynamic>> payments = const []}) =>
      CreditSettlement.quote(
          terms: terms,
          schedule: plan(terms),
          payments: payments,
          start: start,
          at: at);

  test('TIR anualizada: interés cero, nominal mensual y comisión retenida', () {
    expect(
        CreditEngine.effectiveAnnualRate(
            const CreditTerms(principal: 1000, annualRate: 0, months: 12)),
        0);
    expect(
        CreditEngine.effectiveAnnualRate(
            const CreditTerms(principal: 1000, annualRate: 12, months: 1)),
        closeTo(12.682503, .000001));
    expect(
        CreditEngine.effectiveAnnualRate(const CreditTerms(
            principal: 1000, annualRate: 0, months: 1, openingFee: 100)),
        closeTo(213.8428377, .00001));
    const withInsurance = CreditTerms(
        principal: 1000, annualRate: 12, months: 2, monthlyInsurance: 20);
    expect(CreditEngine.effectiveAnnualRate(withInsurance),
        CreditEngine.effectiveAnnualRate(terms));
    expect(
        CreditEngine.effectiveAnnualRate(withInsurance,
            includeThirdParties: true),
        greaterThan(CreditEngine.effectiveAnnualRate(terms)));
  });
  test(
      'FECI se calcula sobre saldo, separado de intereses y con umbral estricto',
      () {
    const feci = CreditTerms(
        principal: 6000,
        annualRate: 12,
        months: 2,
        method: AmortizationMethod.german,
        feciTreatment: FeciTreatment.applies);
    final rows = CreditEngine.schedule(feci, start);
    expect(rows.map((r) => r.feciCents), [500, 250]);
    expect(rows.map((r) => r.totalCents), [306500, 303250]);
    expect(
        CreditEngine.schedule(
                const CreditTerms(
                    principal: 5000,
                    annualRate: 12,
                    months: 2,
                    feciTreatment: FeciTreatment.applies),
                start)
            .first
            .feciCents,
        0);
    expect(
        CreditEngine.schedule(
                const CreditTerms(
                    principal: 5000.01,
                    annualRate: 0,
                    months: 1,
                    feciTreatment: FeciTreatment.applies),
                start)
            .first
            .feciCents,
        417);
    expect(
        () => const CreditTerms(principal: 6000, annualRate: 12, months: 2)
            .validateForContract(),
        throwsArgumentError);
    expect(
        () => const CreditTerms(
                principal: 6000,
                annualRate: 12,
                months: 2,
                feciTreatment: FeciTreatment.exempt)
            .validateForContract(),
        throwsArgumentError);
    const CreditTerms(
            principal: 6000,
            annualRate: 12,
            months: 2,
            feciTreatment: FeciTreatment.exempt,
            feciEvidence: 'Fundamento y prueba de exención')
        .validateForContract();
  });
  test(
      'Cancelación al desembolsar y a mitad del período elimina intereses futuros',
      () {
    expect(quote(start)['netCents'], 100000);
    final mid = quote(DateTime(2026, 1, 16));
    expect(mid['interestCents'], 484);
    expect(mid['netCents'], 100484);
    expect(mid['interestWaivedCents'], 1018);
    expect(mid['penaltyCents'], 0);
    expect(quote(DateTime(2026, 2, 1))['netCents'], 101000);
  });
  test(
      'Después de pagar la primera cuota la cancelación cobra solo capital pendiente',
      () {
    final result = quote(DateTime(2026, 2, 1, 15), payments: [
      {'amountCents': 50751, 'date': '2026-02-01T10:00:00', 'voided': false}
    ]);
    expect(result['principalOutstandingCents'], 50249);
    expect(result['netCents'], 50249);
    expect(result['interestWaivedCents'], 502);
  });
  test(
      'Intereses pagados por adelantado pueden producir devolución, no ganancia',
      () {
    final result = quote(DateTime(2026, 1, 1, 15), payments: [
      {'amountCents': 101502, 'date': '2026-01-01T10:00:00', 'voided': false}
    ]);
    expect(result['netCents'], -1502);
    expect(result['interestCents'], 0);
  });
  test('Pago futuro/anulado no cambia la liquidación y mora no se capitaliza',
      () {
    expect(
        quote(start, payments: [
          {'amountCents': 10000, 'date': '2026-01-03', 'voided': false},
          {'amountCents': 10000, 'date': '2026-01-01', 'voided': true}
        ])['netCents'],
        100000);
    const t = CreditTerms(
        principal: 100, annualRate: 0, months: 1, lateFeePercent: 10);
    final p = [
      {'amountCents': 5000, 'date': '2026-02-01'}
    ];
    final balance = CreditEngine.balances(plan(t), p, 0, DateTime(2026, 3));
    expect(balance.single['lateCents'], 500);
    expect(balance.single['interestCents'], 0);
  });
  test('Formato histórico sin versión conserva exactamente sus claves', () {
    final old = terms.toMap()
      ..remove('policyVersion')
      ..remove('feciTreatment')
      ..remove('feciEvidence')
      ..remove('lateFeePercent');
    final restored = CreditTerms.fromMap(old);
    expect(restored.policyVersion, 1);
    expect(restored.toMap(), old);
    expect(plan(restored).first.containsKey('feciCents'), false);
  });

  group('Operaciones, evidencia, caja y restauración', () {
    final db = LocalDatabaseService();
    final service = CreditService();
    late Directory dir;
    Future<void> login(String name) =>
        db.signIn('$name@contador.local', 'ContadorLocal2026!');
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('panama_credit');
      Hive.init(dir.path);
      await db.init();
      await login('admin');
      await db.insertCustomer(
          {'id': 'c', 'name': 'Cliente de prueba', 'cedula': '8-1-2'});
      await db.saveSetting('initial_capital', '2000');
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    Future<String> originate() async {
      final id = await service.createManaged('c', 'Compra de equipo', terms,
          const FinancialProfile(income: 3000, expenses: 500, debtPayments: 0));
      await service.formalize(id, 'c', 'Contrato TEST-01',
          contract: testPanamaContract);
      await service.disburse(id, DateTime.now(), 'Entrega TEST-01');
      return id;
    }

    test('Contrato y FECI no pueden omitirse; no mueve caja al fallar',
        () async {
      final id = await service.createManaged('c', 'Compra de equipo', terms,
          const FinancialProfile(income: 3000, expenses: 500, debtPayments: 0));
      await expectLater(service.formalize(id, 'c', 'Contrato sin evidencia'),
          throwsArgumentError);
      await expectLater(
          service.formalize(id, 'c', 'Contrato TEST',
              contract: {...testPanamaContract, 'accepted': false}),
          throwsArgumentError);
      expect(service.account(id), isNull);
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
      await login('cliente');
      await expectLater(
          service.createManaged(
              'c',
              'Compra de equipo',
              terms,
              const FinancialProfile(
                  income: 3000, expenses: 0, debtPayments: 0)),
          throwsStateError);
    });
    test(
        'Cancelación liquida saldo, conserva plan, restaura y se anula con trazabilidad',
        () async {
      final id = await originate();
      final original = jsonEncode(service.account(id)!['schedule']);
      final result = service.settlementQuote(id);
      await service.settle(id, result, 'Cancelación TEST');
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
      expect(
          service
              .balance(service.applications.single)
              .every((r) => r['remainingCents'] == 0),
          true);
      expect(jsonEncode(service.account(id)!['schedule']), original);
      await expectLater(service.pay(id, 1, 'Duplicado'), throwsStateError);
      await expectLater(
          service.settle(id, result, 'Duplicado'), throwsStateError);
      final backup = jsonDecode(jsonEncode(db.exportBusinessBackup()))
          as Map<String, dynamic>;
      await db.restoreBusinessBackup(backup);
      final pdf =
          await CreditDocuments.pdfBytes(service, service.applications.single);
      expect(ascii.decode(pdf.take(4).toList()), '%PDF');
      final broken = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
      broken['business']['credit_accounts'][0]['settlement']['netCents'] = 1;
      await expectLater(db.restoreBusinessBackup(broken), throwsArgumentError);
      await service.voidPayment(service.payments(id).single['id'] as String,
          'Corrección documentada');
      expect(service.account(id)!['settlement'], isNull);
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 1000);
      expect(service.settlementQuote(id)['netCents'], 100000);
    });
    test(
        'Cotización alterada, desactualizada o usada por otro rol no se registra',
        () async {
      final id = await originate();
      final result = service.settlementQuote(id);
      await expectLater(
          service.settle(id, {...result, 'netCents': 1}, 'Alterada'),
          throwsStateError);
      await service.pay(id, 100, 'Parcial TEST');
      await expectLater(
          service.settle(id, result, 'Desactualizada'), throwsStateError);
      final current = service.settlementQuote(id);
      await login('analista');
      await expectLater(
          service.settle(id, current, 'Sin permiso'), throwsStateError);
      await login('admin');
      await service.settle(id, current, 'Cancelación final');
      await expectLater(
          service.voidPayment(service.payments(id).first['id'] as String,
              'Intento fuera de orden'),
          throwsStateError);
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
    });
    test(
        'Devolución de anticipos históricos sale de caja y sobrevive al respaldo',
        () async {
      final id = await originate();
      final record = service.account(id)!;
      final total = (record['schedule'] as List)
          .fold<int>(0, (s, r) => s + (r['totalCents'] as int));
      await db.transaction('fixture:anticipo_historico', (s) {
        s['credit_payments'] = [
          {
            'id': 'old-advance',
            'applicationId': id,
            'accountId': record['id'],
            'amountCents': total,
            'reference': 'Anticipo importado',
            'date': DateTime.now().toIso8601String(),
            'voided': false
          }
        ];
      });
      final result = service.settlementQuote(id);
      expect(result['netCents'], -1502);
      await service.settle(id, result, 'Devolución TEST');
      expect(service.payments(id).last['direction'], 'refund');
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
      expect(service.portfolioSummary['interestPaidCents'], 0);
      await db.restoreBusinessBackup(db.exportBusinessBackup());
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
      await service.voidPayment(
          service.payments(id).last['id'] as String, 'Revertir devolución');
      expect(PortfolioLedger.availableCash(db.readSnapshot()), 2015.02);
    });
    test(
        'Rechaza contrato alterado y cierre futuro; preserva estado histórico antes de cerrar',
        () async {
      final id = await originate();
      final before = DateTime.now();
      final result = service.settlementQuote(id);
      await service.settle(id, result, 'Cierre TEST');
      expect(
          service
              .balance(service.applications.single, asOf: before)
              .any((r) => (r['remainingCents'] as int) > 0),
          true);
      final backup = jsonDecode(jsonEncode(db.exportBusinessBackup()))
          as Map<String, dynamic>;
      backup['business']['credit_accounts'][0]['contract']['borrowerId'] =
          'Otro deudor';
      await expectLater(db.restoreBusinessBackup(backup), throwsArgumentError);
    });
  });
}
