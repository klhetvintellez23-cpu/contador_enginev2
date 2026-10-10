import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/services/local_cache_service.dart';
import 'package:contador_engine/providers/debt_provider.dart';
import 'package:contador_engine/screens/add_loan_screen.dart';
import 'package:contador_engine/screens/installment_simulator_screen.dart';
import 'package:contador_engine/utils/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('installment_ui_');
    await LocalCacheService().init(directory: temp.path);
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  testWidgets('Simular desde el formulario, comparar métodos y volver',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = DebtProvider();
    addTearDown(provider.dispose);
    final previewKey = GlobalKey();
    final savePreview = Platform.environment['SAVE_INSTALLMENT_PREVIEW'] == '1';
    if (savePreview) {
      final fonts = FontLoader('AppRoboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      await fonts.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
    Future<void> capture(String name) async {
      if (!savePreview) return;
      await tester.runAsync(() async {
        final boundary = previewKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('.review/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: RepaintBoundary(
        key: previewKey,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: const AddLoanScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    await capture('paso-1-nuevo-prestamo');
    await tester.tap(find.text('Simular cuotas'));
    await tester.pumpAndSettle();
    expect(find.byType(InstallmentSimulatorScreen), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '1000');
    await tester.enterText(fields.at(1), '12');
    await tester.tap(find.text('Calcular cuotas'));
    await tester.pumpAndSettle();
    expect(find.text('\$88.85'), findsOneWidget);
    expect(find.text('Tu simulación'), findsOneWidget);
    await capture('paso-1-simulador');
    await tester.tap(find.text('Alemán'));
    await tester.pumpAndSettle();
    expect(find.text('Tu simulación'), findsNothing);
    await tester.tap(find.text('Calcular cuotas'));
    await tester.pumpAndSettle();
    expect(find.text('\$93.33'), findsOneWidget);
    expect(provider.allLoans, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AddLoanScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rechaza valores inválidos en pantalla estrecha', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const InstallmentSimulatorScreen(initialAmount: 500),
    ));
    final fields = find.byType(TextFormField);
    expect(find.text('500.00'), findsOneWidget);
    await tester.enterText(fields.at(1), 'NaN');
    await tester.enterText(fields.at(2), '0');
    await tester.ensureVisible(find.text('Calcular cuotas'));
    await tester.tap(find.text('Calcular cuotas'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa una tasa de 0 a 100%.'), findsOneWidget);
    expect(find.text('Ingresa entre 1 y 360 meses.'), findsOneWidget);
    expect(find.text('Tu simulación'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
