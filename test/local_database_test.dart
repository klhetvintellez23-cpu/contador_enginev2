import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/services/local_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final db = LocalDatabaseService();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('contador_test_');
    Hive.init(directory.path);
    await db.init();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('Registrar cliente valida identidad, rol y duplicados concurrentes',
      () async {
    await db.signIn('cliente@contador.local', 'ContadorLocal2026!');
    await expectLater(db.registerCustomer(name: 'Ana', identification: '8-1-2'),
        throwsStateError);
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await expectLater(db.registerCustomer(name: 'Ana', identification: ' - '),
        throwsArgumentError);
    await expectLater(db.registerCustomer(name: ' ', identification: '8-1-2'),
        throwsArgumentError);
    final results = await Future.wait([
      db.registerCustomer(
          name: ' Ana ', identification: '8-1-2', phone: '+50761234567'),
      db
          .registerCustomer(name: 'Otra ficha', identification: '8 - 1 - 2')
          .then<String>((_) => 'duplicado', onError: (Object e) {
        expect(e, isA<StateError>());
        return 'rechazado';
      }),
    ]);
    expect(results.last, 'rechazado');
    final customer = (await db.getCustomers()).single;
    expect(customer['id'], results.first);
    expect(customer['name'], 'Ana');
    expect(customer['cedula'], '8-1-2');
    expect(customer['phone'], '+50761234567');
    await Hive.close();
    await db.init();
    expect((await db.getCustomers()).single['id'], results.first);
    expect(db.auditLog().where((e) => e['action'] == 'crear:customers'),
        hasLength(1));
  });
  test('Authentication, persistence, pagination, cascades and reset', () async {
    expect(db.currentUser, isNull);
    await expectLater(db.getCustomers(), throwsStateError);
    await expectLater(
        db.signIn('admin@contador.local', 'incorrecta'), throwsStateError);
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await db.insertCustomer({'id': 'c1', 'name': 'Ana'});
    await db.insertCustomer({'id': 'c2', 'name': 'Beatriz'});
    await db.importLegacyBackup({
      'version': 1,
      'customers': [],
      'payments': [],
      'capitalHistory': [],
      'loans': [
        {
          'id': 'l1',
          'customer_id': 'c1',
          'initial_amount': 100,
          'start_date': '2026-01-01T00:00:00',
          'increment_value': 0
        }
      ]
    });
    await db.insertPayment({
      'id': 'p1',
      'loan_id': 'l1',
      'customer_name': 'Ana',
      'amount': 25,
      'date': '2026-02-01T12:00:00'
    });
    await db.insertCapitalEntry({'id': 'capital', 'amount': 100});
    await db.saveSetting('business_name', 'Mi negocio');
    await db.updateCustomer('c1', {'name': 'Andrea'});
    await db.updateLoanPayment('l1', 25);
    expect((await db.getAllLoans()).single['amount_paid'], 25);
    expect((await db.getCustomersPaginated(searchQuery: 'AND')).single['name'],
        'Andrea');
    expect(await db.getCustomersPaginated(offset: 1, limit: 1), hasLength(1));
    expect(await db.getPaymentsPaginated(endDate: DateTime(2026, 10, 9)),
        hasLength(1));
    expect(await db.getPaymentsPaginated(startDate: DateTime(2026, 10, 10)),
        isEmpty);
    await Hive.close();
    await db.init();
    expect(db.currentUser, isNotNull);
    expect(await db.getCustomers(), hasLength(2));
    expect(await db.getSetting('business_name'), 'Mi negocio');
    await db.signOut();
    await expectLater(db.getAllLoans(), throwsStateError);
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    expect(await db.getCustomers(), hasLength(2));
    await expectLater(db.deleteCustomer('c1'), throwsStateError);
    await expectLater(db.deleteLoan('l1'), throwsStateError);
    await db.deletePayment('p1');
    expect((await db.getAllLoans()).single['amount_paid'], 0);
    await db.deleteLoan('l1');
    await db.deleteCustomer('c1');
    expect(await db.getAllLoans(), isEmpty);
    expect(await db.getAllPayments(), isEmpty);
    expect(await db.getCustomers(), hasLength(1));
    await db.clearAllUserData();
    expect(await db.getCustomers(), isEmpty);
    expect(await db.getCapitalHistory(), isEmpty);
    expect(await db.getSetting('business_name'), isNull);
    expect(db.currentUser, isNotNull);
    expect(db.auditLog().any((e) => e['action'] == 'anular_pago:p1'), isTrue);
  });
  test('Una importación inválida no deja cambios parciales', () async {
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await expectLater(
        db.importLegacyBackup({
          'version': 1,
          'customers': [
            {'id': 'c', 'name': 'Prueba'}
          ],
          'loans': [
            {
              'id': 'l',
              'customerId': 'no-existe',
              'initialAmount': 100,
              'startDate': '2026-01-01',
              'incrementValue': 0
            }
          ],
          'payments': [],
          'capitalHistory': [],
        }),
        throwsArgumentError);
    expect(await db.getCustomers(), isEmpty);
    expect(db.auditLog(), isEmpty);
  });
  test('La cartera permite crear préstamos y conserva pagos al reiniciar',
      () async {
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await db.insertCustomer({'id': 'original-c', 'name': 'Cliente original'});
    await db.saveSetting('initial_capital', '500');
    final loan = {
      'id': 'original-l',
      'customer_id': 'original-c',
      'initial_amount': 100,
      'increment_value': 0,
      'start_date': '2026-01-01T00:00:00',
    };
    await db.insertLoan(loan);
    await db.insertPayment({
      'id': 'original-p',
      'loan_id': 'original-l',
      'customer_name': 'Cliente original',
      'amount': 25,
      'date': '2026-02-01T12:00:00',
    });
    await Hive.close();
    await db.init();
    expect((await db.getAllLoans()).single['amount_paid'], 25);
    expect(await db.getAllPayments(), hasLength(1));
    expect(db.auditLog().any((e) => e['action'] == 'crear:loans'), isTrue);
    await expectLater(db.insertLoan(loan), throwsStateError);
    await expectLater(
        db.insertLoan({...loan, 'id': 'invalid', 'initial_amount': -1}),
        throwsArgumentError);
    await db.signOut();
    await db.signIn('cliente@contador.local', 'ContadorLocal2026!');
    await expectLater(
        db.insertLoan({...loan, 'id': 'unauthorized'}), throwsStateError);
  });
  test('Escrituras simultáneas conservan registros y bitácora', () async {
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await Future.wait(List.generate(
        10, (i) => db.insertCustomer({'id': 'c$i', 'name': 'Cliente $i'})));
    expect(await db.getCustomers(), hasLength(10));
    expect(db.auditLog(), hasLength(10));
  });
}
