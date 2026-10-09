import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/providers/debt_provider.dart';
import 'package:contador_engine/services/local_cache_service.dart';
import 'package:contador_engine/services/local_database_service.dart';

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
