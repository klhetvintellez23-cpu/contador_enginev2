import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/models/credit_engine.dart';
import 'package:contador_engine/screens/credit_portal_screen.dart';
import 'package:contador_engine/services/credit_service.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/utils/app_theme.dart';
import 'package:contador_engine/widgets/finance_ui.dart';
import 'package:contador_engine/widgets/morphing_navigation.dart';
import 'support/ui_preview.dart';

void main() {
  final db = LocalDatabaseService();
  final service = CreditService();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('workspace_refinement_');
    Hive.init(directory.path);
    await db.init();
    await db.signIn('cliente@contador.local', 'ContadorLocal2026!');
    final submitted = await service.create(
        'Equipo para el negocio',
        const CreditTerms(principal: 1000, annualRate: 12, months: 12),
        const FinancialProfile(income: 2500, expenses: 500, debtPayments: 0));
    await service.submit(submitted);
    await service.create(
        'Ampliación del local',
        const CreditTerms(principal: 2000, annualRate: 12, months: 24),
        const FinancialProfile(income: 2500, expenses: 500, debtPayments: 0));
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
      'Indicadores completos en Solicitudes, Inicio compacto y contenido sobre el menú',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final capture = Platform.environment['SAVE_UI_PREVIEW'] == '1';
    {
      await (FontLoader('AppRoboto')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
    final preview = GlobalKey();
    for (final role in ['admin', 'cliente']) {
      await tester.runAsync(
          () => db.signIn('$role@contador.local', 'ContadorLocal2026!'));
      final dataBefore = jsonEncode(db.readWorkflow());
      for (final width in [320.0, 390.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(RepaintBoundary(
            key: preview,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(width == 320 ? 1.4 : 1),
                      disableAnimations: true),
                  child: child!),
              home: const CreditPortalScreen(),
            )));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('request-summary')), findsNothing);
        expect(find.text('Activadas'), findsNothing);
        final scroll = find.byType(Scrollable).first;
        final recent = find.byKey(
            ValueKey('recent-application-${service.applications.first['id']}'));
        await tester.scrollUntilVisible(recent, 250, scrollable: scroll);
        await Scrollable.ensureVisible(tester.element(recent), alignment: 1);
        await tester.pumpAndSettle();
        expect(
            tester.getRect(recent).bottom,
            lessThanOrEqualTo(
                tester.getRect(find.byType(MorphingNavigation)).top));
        await tester.drag(scroll, const Offset(0, 3000));
        await tester.pumpAndSettle();
        if (capture) {
          await saveUiPreview(
              tester, preview, 'neutral-$role-inicio-${width.toInt()}');
        }
        await tester.tap(find.byKey(MorphingNavigation.destinationKey(1)));
        await tester.pumpAndSettle();
        final summary = find.byKey(const ValueKey('request-summary'));
        expect(summary, findsOneWidget);
        for (var i = 0; i < 3; i++) {
          final metric = find.byKey(ValueKey('request-metric-$i'));
          expect(
              find.descendant(
                  of: metric, matching: find.text(['2', '1', '0'][i])),
              findsOneWidget);
        }
        if (width >= 390) {
          final top = tester
              .getTopLeft(find.byKey(const ValueKey('request-metric-0')))
              .dy;
          expect(
              tester
                  .getTopLeft(find.byKey(const ValueKey('request-metric-2')))
                  .dy,
              top);
        }
        final medallion = find
            .descendant(of: summary, matching: find.byType(IconMedallion))
            .first;
        final box = tester.widget<Container>(find
            .descendant(of: medallion, matching: find.byType(Container))
            .first);
        expect(
            (box.decoration as BoxDecoration).color, const Color(0xFFF1F1F1));
        expect(
            tester
                .widget<Icon>(
                    find.descendant(of: medallion, matching: find.byType(Icon)))
                .color,
            AppTheme.primary);
        expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF7F7F7));
        if (capture) {
          await saveUiPreview(
              tester, preview, 'neutral-$role-solicitudes-${width.toInt()}');
        }
        // The counters remain global while the existing list filter changes.
        await tester
            .ensureVisible(find.widgetWithText(ChoiceChip, 'En revisión'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'En revisión'));
        await tester.pumpAndSettle();
        expect(find.text('1 solicitud'), findsOneWidget);
        expect(find.descendant(of: summary, matching: find.text('2')),
            findsOneWidget);
        expect(jsonEncode(db.readWorkflow()), dataBefore);
        expect(tester.takeException(), isNull, reason: '$role / $width');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
