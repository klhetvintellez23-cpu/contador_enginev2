import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/models/credit_engine.dart';
import 'package:contador_engine/screens/credit_portal_screen.dart';
import 'package:contador_engine/screens/auth_screen.dart';
import 'package:contador_engine/utils/app_theme.dart';

void main() {
  final db = LocalDatabaseService();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('credit_ui');
    Hive.init(dir.path);
    await db.init();
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets('Solicitante ve expediente y puede enviarlo desde la interfaz',
      (tester) async {
    await tester.runAsync(() async {
      await db.signIn('cliente@contador.local', 'ContadorLocal2026!');
      await CreditService().create(
          'Compra de equipo',
          const CreditTerms(principal: 1000, annualRate: 12, months: 12),
          const FinancialProfile(income: 2000, expenses: 500, debtPayments: 0));
    });
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const CreditPortalScreen()));
    await tester.scrollUntilVisible(find.text('Compra de equipo'), 250,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Compra de equipo'), findsOneWidget);
    expect(find.text('Auditoría'), findsNothing);
    await tester.tap(find.text('Compra de equipo'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar a análisis'), findsOneWidget);
    await tester.ensureVisible(find.text('Enviar a análisis'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Enviar a análisis'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(CreditService().applications.single['status'], 'submitted');
    expect(find.text('Enviar a análisis'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Formulario muestra error para ingresos inválidos',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreditApplicationForm())));
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Revisa los campos.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Gerencia tiene auditoría y respaldo en pantalla móvil',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    });
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const CreditPortalScreen()));
    expect(find.text('Auditoría'), findsNothing);
    await tester.tap(find.text('Herramientas'));
    await tester.pumpAndSettle();
    expect(find.text('Auditoría'), findsOneWidget);
    expect(find.text('Respaldar'), findsOneWidget);
    expect(find.text('Nueva solicitud'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Acceso estrecho valida campos y muestra 2FA solo cuando se necesita',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AuthScreen()));
    expect(find.text('Código de 6 dígitos'), findsNothing);
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('Código de 6 dígitos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Windows ancho permite navegar a cuenta y cancelar cierre de sesión',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    });
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const CreditPortalScreen()));
    await tester.tap(find.text('Mi cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('admin@contador.local'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(db.currentUser, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Formulario estrecho no desborda con texto ampliado',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: const Scaffold(body: CreditApplicationForm())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
