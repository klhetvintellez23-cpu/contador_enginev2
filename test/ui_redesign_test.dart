import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ui_preview.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:contador_engine/models/transaction.dart';
import 'package:contador_engine/providers/debt_provider.dart';
import 'package:contador_engine/services/local_cache_service.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/screens/home_screen.dart';
import 'package:contador_engine/screens/add_loan_screen.dart';
import 'package:contador_engine/screens/customer_detail_screen.dart';
import 'package:contador_engine/screens/todays_collections_screen.dart';
import 'package:contador_engine/screens/daily_closing_screen.dart';
import 'package:contador_engine/screens/capital_history_screen.dart';
import 'package:contador_engine/screens/customer_receipts_screen.dart';
import 'package:contador_engine/screens/account_settings_screen.dart';
import 'package:contador_engine/screens/lock_screen.dart';
import 'package:contador_engine/screens/auth_screen.dart';
import 'package:contador_engine/utils/app_theme.dart';
import 'package:contador_engine/widgets/app_ui.dart';
import 'package:contador_engine/widgets/morphing_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DebtProvider provider;
  final db = LocalDatabaseService();
  final capture = Platform.environment['SAVE_UI_PREVIEW'] == '1';
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    directory = await Directory.systemTemp.createTemp('redesign_');
    await LocalCacheService().init(directory: directory.path);
    await LocalCacheService().setAutoShareReceipt(false);
    await db.init();
    await db.signIn('admin@contador.local', 'ContadorLocal2026!');
    await db.saveSetting('business_name', 'Mi negocio');
    await db.insertCapitalEntry({'id': 'capital', 'amount': 8500});
    for (var i = 0; i < 3; i++) {
      await db.insertCustomer({
        'id': 'c$i',
        'name': ['Ana Martínez', 'Carlos Pérez', 'Lucía Gómez'][i],
        'cedula': '8-100-$i',
        'phone': '+50761234567'
      });
      await db.insertLoan(LoanTransaction(
              id: 'l$i',
              customerId: 'c$i',
              title: 'Capital de trabajo',
              initialAmount: 500 + i * 250,
              startDate: DateTime.now().subtract(const Duration(days: 20)),
              incrementType: IncrementType.percentage,
              incrementValue: 5,
              incrementPeriod: IncrementPeriod.monthly)
          .toMap(snakeCase: true));
    }
    FlutterSecureStorage.setMockInitialValues({});
    provider = DebtProvider();
    await provider.fetchAll();
    await Future<void>.delayed(Duration.zero);
    debugDefaultTargetPlatformOverride = null;
  });
  tearDown(() async {
    provider.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('Navegación adaptable y pantallas operativas en móvil y Windows',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    {
      final fonts = FontLoader('AppRoboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      await fonts.load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
    final preview = GlobalKey();
    Future<void> screenshot(String name) async {
      if (capture) await saveUiPreview(tester, preview, name);
    }

    Future<void> show(Widget screen, {double scale = 1}) async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: provider,
          child: RepaintBoundary(
              key: preview,
              child: MaterialApp(
                  key: UniqueKey(),
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: screen))));
      await tester.pumpAndSettle();
      if (capture) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp));
          for (final width in [88, 144, 192]) {
            await precacheImage(
                ResizeImage(
                    const AssetImage(
                        'assets/icons/contador_engine_icon_source.png'),
                    width: width),
                context);
          }
        });
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: '${screen.runtimeType} a escala $scale');
    }

    for (final width in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await show(const HomeScreen());
      expect(find.byKey(const ValueKey('request-summary')), findsNothing);
      await screenshot('admin-${width.toInt()}');
      await tester.tap(find.byKey(MorphingNavigation.destinationKey(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('request-summary')), findsOneWidget);
      await screenshot('solicitudes-${width.toInt()}');
      await tester.tap(find.byKey(MorphingNavigation.destinationKey(2)));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo préstamo'), findsOneWidget);
      expect(find.byType(MorphingNavigation), findsOneWidget);
      await screenshot('inicio-${width.toInt()}');
      await tester.enterText(find.byType(TextField).first, '8-100-1');
      await tester.pumpAndSettle();
      expect(find.text('Carlos Pérez'), findsOneWidget);
      expect(find.text('Ana Martínez'), findsNothing);
      await screenshot('busqueda-activa-${width.toInt()}');
      await tester.tap(find.byKey(MorphingNavigation.destinationKey(3)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes del negocio'));
      await tester.pumpAndSettle();
      expect(find.text('Exportar respaldo'), findsNothing);
      expect(find.text('Respaldo'), findsOneWidget);
      await screenshot('ajustes-${width.toInt()}');
      await tester.ensureVisible(find.text('Respaldo'));
      await tester.tap(find.text('Respaldo'));
      await tester.pumpAndSettle();
      expect(find.text('Exportar respaldo'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MorphingNavigation.destinationKey(2)));
      await tester.pumpAndSettle();
      expect(find.text('Carlos Pérez'), findsOneWidget);
      expect(find.text('Ana Martínez'), findsNothing);
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Martínez'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Carlos Pérez'), 120,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Carlos Pérez'), findsOneWidget);
      await tester.tap(find.text('Informes').last);
      await tester.pumpAndSettle();
      await screenshot('informes-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cobros').last);
      await tester.pumpAndSettle();
      expect(find.text('Comprobantes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenshot('cobros-${width.toInt()}');
      final screens = <String, Widget>{
        'prestamo': const AddLoanScreen(),
        'cliente': CustomerDetailScreen(customer: provider.customers.first),
        'cobros-hoy': const TodaysCollectionsScreen(),
        'cierre': const DailyClosingScreen(),
        'capital': const CapitalHistoryScreen(),
        'comprobantes':
            CustomerReceiptsScreen(customer: provider.customers.first),
        'cuenta': const AccountSettingsScreen(),
        'acceso': const AuthScreen(),
        'bloqueo': LockScreen(onUnlocked: () {}),
      };
      for (final entry in screens.entries) {
        await show(entry.value);
        await screenshot('${entry.key}-${width.toInt()}');
      }
    }
    tester.view.physicalSize = const Size(360, 900);
    for (final screen in [
      const AddLoanScreen(),
      const DailyClosingScreen(),
      const CapitalHistoryScreen(),
      CustomerDetailScreen(customer: provider.customers.first)
    ]) {
      await show(screen, scale: 1.4);
    }
    for (final width in [320.0, 980.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await show(const HomeScreen(), scale: 1.4);
      final destinations = {
        'Solicitudes': Icons.description_outlined,
        'Perfil': Icons.person_outline,
        'Cartera': Icons.account_balance_wallet_outlined,
        'Inicio': Icons.home_outlined
      };
      for (final destination in destinations.entries) {
        final navigation = find.byType(MorphingNavigation);
        final selectedIndex = ['Inicio', 'Solicitudes', 'Cartera', 'Perfil']
            .indexOf(destination.key);
        await tester
            .tap(find.byKey(MorphingNavigation.destinationKey(selectedIndex)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason:
                '${destination.key} a ${width.toInt()} px y texto ampliado');
        expect(
            tester.widget<MorphingNavigation>(navigation).index, selectedIndex);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('El nuevo formulario conserva creación y validación del préstamo',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MorphingNavigation.destinationKey(2)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo préstamo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear préstamo'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa el monto.'), findsOneWidget);
    await tester.tap(find.text('Seleccionar cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Martínez').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '250');
    await tester.enterText(fields.at(1), 'Prueba de interfaz');
    await tester.enterText(fields.at(2), '5');
    await tester.ensureVisible(find.text('Crear préstamo'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Crear préstamo'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(provider.allLoans, hasLength(4));
    expect(provider.allLoans.last.title, 'Prueba de interfaz');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ana Martínez'));
    await tester.tap(find.text('Ana Martínez'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registrar cobro').first);
    await tester.tap(find.text('Registrar cobro').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '25');
    await tester.runAsync(() async {
      await tester.tap(find.text('Cobrar'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(await db.getAllPayments(), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('El movimiento reducido omite la animación de entrada',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child:
                WelcomeEntrance(child: const Scaffold(body: Text('Listo'))))));
    await tester.pump();
    expect(find.text('Listo'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
