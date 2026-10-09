import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/models/credit_engine.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/services/totp_service.dart';
import 'package:contador_engine/utils/credit_documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = LocalDatabaseService();
  final service = CreditService();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('credit_workflow');
    Hive.init(dir.path);
    await db.init();
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Future<void> login(String user) =>
      db.signIn('$user@contador.local', 'ContadorLocal2026!');
  test('Una sesión caducada vuelve al acceso y bloquea operaciones', () async {
    await login('cliente');
    final box=Hive.box('contador_local_database_v1');
    final session=Map<String,dynamic>.from(box.get('session_v2') as Map);
    session['expires']=DateTime.now().subtract(const Duration(seconds:1)).toIso8601String();
    await box.put('session_v2',session);
    expect(db.currentUser,isNull);
    expect(()=>db.readWorkflow(),throwsStateError);
  });
  test('Ciclo completo, permisos, saldo, anulación y persistencia', () async {
    await login('cliente');
    final id = await service.create(
        'Comprar equipo',
        const CreditTerms(principal: 1000, annualRate: 12, months: 12),
        const FinancialProfile(income: 2000, expenses: 600, debtPayments: 100));
    await expectLater(service.evaluate(id), throwsStateError);
    await expectLater(
        db.insertCustomer({'id': 'x', 'name': 'Intruso'}), throwsStateError);
    await service.submit(id);
    await login('admin');
    await expectLater(
        service.decide(id, 'advance', 'Aprobación inválida'), throwsStateError);
    await expectLater(service.pay(id, 10, 'antes'), throwsStateError);
    await login('analista');
    await expectLater(
        service.decide(id, 'advance', 'Sin evaluar'), throwsStateError);
    await service.evaluate(id);
    expect(
        (service.applications.single['evaluation'] as Map)['eligible'], true);
    await service.decide(id, 'advance', 'Evaluación favorable');
    await expectLater(
        service.decide(id, 'advance', 'No puede repetir'), throwsStateError);
    await login('cumplimiento');
    await service.decide(id, 'advance', 'Revisión documental conforme');
    await login('admin');
    await service.decide(id, 'advance', 'Aprobado en simulación');
    final app = service.applications.single;
    expect(app['schedule'], hasLength(12));
    final total = service
        .balance(app)
        .fold<int>(0, (sum, r) => sum + (r['remainingCents'] as int));
    await service.pay(id, 100, 'recibo-1');
    await expectLater(service.pay(id, 100, 'recibo-1'), throwsStateError);
    expect(
        service
            .balance(app)
            .fold<int>(0, (sum, r) => sum + (r['remainingCents'] as int)),
        total - 10000);
    await expectLater(service.pay(id, 100000, 'exceso'), throwsArgumentError);
    await service.voidPayment(service.payments(id).single['id'] as String,
        'Registro duplicado externo');
    expect(
        service
            .balance(app)
            .fold<int>(0, (sum, r) => sum + (r['remainingCents'] as int)),
        total);
    expect(service.payments(id).single['voided'], true);
    expect(db.auditLog().first['role'], 'manager');
    await Hive.close();
    await db.init();
    expect(service.applications.single['status'], 'approved');
    expect(service.payments(id).single['voidReason'],
        'Registro duplicado externo');
    final backup = jsonDecode(jsonEncode(db.exportBusinessBackup()))
        as Map<String, dynamic>;
    await db.restoreBusinessBackup(backup);
    expect(service.applications.single['status'], 'approved');
    expect(service.payments(id).single['voided'], true);
    final report = CreditDocuments.report(service, service.applications.single);
    expect(report['balances'], hasLength(12));
    final bytes =
        await CreditDocuments.pdfBytes(service, service.applications.single);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    final broken = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
    ((broken['business']['applications'][0]['schedule'] as List)[0]
        as Map)['totalCents'] = 1;
    await expectLater(db.restoreBusinessBackup(broken), throwsArgumentError);
    expect(
        service
            .balance(service.applications.single)
            .fold<int>(0, (sum, r) => sum + (r['remainingCents'] as int)),
        total);
  });
  test('Privacidad, devolución e invalidación de la evaluación', () async {
    await login('cliente');
    final id = await service.create(
        'Capital de trabajo',
        const CreditTerms(principal: 100, annualRate: 0, months: 2),
        const FinancialProfile(income: 1000, expenses: 100, debtPayments: 0));
    await service.submit(id);
    await login('analista');
    await service.evaluate(id);
    await service.decide(id, 'return', 'Corregir los ingresos');
    await login('cliente');
    await service.revise(
        id,
        'Capital corregido',
        const CreditTerms(principal: 150, annualRate: 0, months: 2),
        const FinancialProfile(income: 1100, expenses: 100, debtPayments: 0));
    expect(service.applications.single.containsKey('evaluation'), false);
    await db.register(
        'Otra persona', 'otro@contador.local', 'OtraClaveLocal2026!');
    await db.signIn('otro@contador.local', 'OtraClaveLocal2026!');
    expect(service.applications, isEmpty);
    await expectLater(service.submit(id), throwsStateError);
  });
  test('TOTP, cambio de contraseña y cuenta sin privilegios', () async {
    const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    expect(
        TotpService.code(
            secret, DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true)),
        '287082');
    await login('cliente');
    await db.enableTotp(secret, TotpService.code(secret, DateTime.now()));
    await db.changePassword('ContadorLocal2026!', 'NuevaClaveLocal2026!');
    await db.signOut();
    await expectLater(
        db.signIn('cliente@contador.local', 'NuevaClaveLocal2026!'),
        throwsStateError);
    await db.signIn('cliente@contador.local', 'NuevaClaveLocal2026!',
        otp: TotpService.code(secret, DateTime.now()));
    expect(db.currentUser!.role, UserRole.client);
  });
}
