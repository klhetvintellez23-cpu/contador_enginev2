import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ui_preview.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/models/credit_engine.dart';
import 'package:contador_engine/models/credit_account.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/screens/credit_portal_screen.dart';
import 'package:contador_engine/utils/app_theme.dart';

void main() {
  final db = LocalDatabaseService(), service = CreditService();
  late Directory directory;
  final capture = Platform.environment['SAVE_UI_PREVIEW'] == '1';
  final preview = GlobalKey();
  Future<void> screenshot(WidgetTester tester, String name) async {
    if (capture) await saveUiPreview(tester, preview, name);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('role_credit_ui');
    Hive.init(directory.path);
    await db.init();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<void> login(String name) =>
      db.signIn('$name@contador.local', 'ContadorLocal2026!');
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);
    } else {
      await tester.ensureVisible(finder);
    }
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settle(tester);
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (capture) {
      await (FontLoader('AppRoboto')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
    await tester.pumpWidget(RepaintBoundary(
        key: preview,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const CreditPortalScreen())));
    await settle(tester);
  }

  testWidgets(
      'Solicitante completa los tres pasos y recibe confirmación de envío',
      (tester) async {
    await tester.runAsync(() => login('cliente'));
    await mount(tester);
    await screenshot(tester, 'solicitante-390');
    expect(find.text('Cartera'), findsNothing);
    await tap(tester, find.text('Solicitar préstamo').last);
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Compra de equipo');
    await tap(tester, find.text('Continuar'));
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '2000');
    await tester.enterText(find.byType(TextFormField).at(1), '600');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tap(tester, find.text('Continuar'));
    expect(find.text('Paso 3 de 3'), findsOneWidget);
    await screenshot(tester, 'solicitud-revision-390');
    await tap(tester, find.text('Enviar solicitud'));
    expect(service.applications.single['status'], 'submitted');
    expect(find.text('Solicitud enviada. Puedes consultar su avance.'),
        findsOneWidget);
    expect(
        service.account(service.applications.single['id'] as String), isNull);
    await screenshot(tester, 'solicitud-enviada-390');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Gerencia confirma aprobación, formaliza y registra entrega desde el expediente',
      (tester) async {
    late String id;
    await tester.runAsync(() async {
      await login('cliente');
      id = await service.create(
          'Equipo para negocio',
          const CreditTerms(principal: 1000, annualRate: 12, months: 12),
          const FinancialProfile(
              income: 2000, expenses: 600, debtPayments: 100));
      await service.submit(id);
      await login('analista');
      await service.evaluate(id);
      await service.decide(id, 'advance', 'Evaluación conforme');
      await login('cumplimiento');
      await service.decide(id, 'advance', 'Documentación conforme');
      await login('admin');
      await db.insertCustomer(
          {'id': 'c', 'name': 'Cliente verificado', 'cedula': '8-1-2'});
      await db.saveSetting('initial_capital', '2000');
    });
    await mount(tester);
    await screenshot(tester, 'admin-solicitud-390');
    await tap(tester, find.text('Revisar solicitud'));
    await screenshot(tester, 'expediente-390');
    if (capture) {
      tester.view.physicalSize = const Size(1280, 1000);
      await tester.pumpAndSettle();
      await screenshot(tester, 'expediente-1280');
      tester.view.physicalSize = const Size(390, 1000);
      await tester.pumpAndSettle();
    }
    await tap(tester, find.text('Aprobar solicitud'));
    await tester.enterText(
        find.byType(TextFormField).last, 'Acuerdo administrativo');
    await tap(tester, find.text('Confirmar'));
    expect(service.applications.single['status'], 'approved');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
    expect(find.text('Registrar pago'), findsNothing);
    await tap(tester, find.text('Formalizar crédito'));
    await screenshot(tester, 'formalizacion-390');
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('Cliente verificado · 8-1-2').last);
    await tester.enterText(
        find.byType(TextFormField).last, 'Acuerdo firmado 001');
    await tap(tester, find.byType(CheckboxListTile));
    await tap(tester, find.widgetWithText(FilledButton, 'Formalizar crédito'));
    expect(service.account(id), isNotNull,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    expect(service.account(id)!['status'], 'formalized');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 2000);
    await tap(tester, find.text('Registrar desembolso'));
    await screenshot(tester, 'desembolso-390');
    await tester.enterText(find.byType(TextFormField).last, 'Entrega 001');
    await tap(tester, find.text('Seleccionar fecha real de entrega'));
    await tap(tester, find.text('OK'));
    await tap(tester, find.byType(CheckboxListTile));
    await tap(
        tester, find.widgetWithText(FilledButton, 'Registrar desembolso'));
    expect(service.account(id)!['status'], 'active');
    expect(PortfolioLedger.availableCash(db.readSnapshot()), 1000);
    expect(db.readSnapshot()['loans'] ?? [], isEmpty);
    expect(service.balance(service.applications.single), hasLength(12));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
