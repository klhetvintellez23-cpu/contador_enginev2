import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contador_engine/widgets/morphing_navigation.dart';
import 'package:contador_engine/utils/app_theme.dart';
import 'support/ui_preview.dart';

const labels = ['Inicio', 'Solicitudes', 'Cartera', 'Perfil'];
const icons = [
  Icons.home_outlined,
  Icons.description_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.person_outline
];
const selectedIcons = [
  Icons.home_rounded,
  Icons.description_rounded,
  Icons.account_balance_wallet_rounded,
  Icons.person_rounded
];

void main() {
  late ValueNotifier<int> selected;
  setUp(() => selected = ValueNotifier(0));
  tearDown(() => selected.dispose());

  Future<void> show(WidgetTester tester,
      {double width = 420,
      double scale = 1,
      bool reduced = false,
      bool rtl = false,
      bool client = false,
      GlobalKey? preview}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 160);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
              textScaler: TextScaler.linear(scale), disableAnimations: reduced),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
                body: Center(
                    child: RepaintBoundary(
              key: preview,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ValueListenableBuilder<int>(
                    valueListenable: selected,
                    builder: (context, value, child) => MorphingNavigation(
                        index: value,
                        labels: client
                            ? const ['Inicio', 'Mis solicitudes', 'Perfil']
                            : labels,
                        icons: client
                            ? const [
                                Icons.home_outlined,
                                Icons.description_outlined,
                                Icons.person_outline
                              ]
                            : icons,
                        selectedIcons: client
                            ? const [
                                Icons.home_rounded,
                                Icons.description_rounded,
                                Icons.person_rounded
                              ]
                            : selectedIcons,
                        onSelected: (value) => selected.value = value),
                  )),
            ))),
          ),
        )));
    await tester.pumpAndSettle();
  }

  Rect pill(WidgetTester tester) =>
      tester.getRect(find.byKey(MorphingNavigation.indicatorKey));
  double labelOpacity(WidgetTester tester, String label) => tester
      .widget<Opacity>(find
          .ancestor(of: find.text(label), matching: find.byType(Opacity))
          .first)
      .opacity;

  testWidgets('Una pastilla viaja, se contrae y revela la etiqueta después',
      (tester) async {
    await show(tester);
    final start = pill(tester);
    final iconStart =
        tester.getCenter(find.byIcon(Icons.description_outlined)).dx;
    await tester.tap(find.byKey(MorphingNavigation.destinationKey(1)));
    await tester.pump();
    expect(pill(tester), start);
    await tester.pump(const Duration(milliseconds: 115));
    expect(labelOpacity(tester, 'Inicio'), 0);
    expect(labelOpacity(tester, 'Solicitudes'), 0);
    await tester.pump(const Duration(milliseconds: 165));
    final middle = pill(tester);
    expect(middle.center.dx, greaterThan(start.center.dx));
    expect(tester.getCenter(find.byIcon(Icons.description_outlined)).dx,
        lessThan(iconStart));
    expect(labelOpacity(tester, 'Solicitudes'), greaterThan(0));
    await tester.pumpAndSettle();
    final end = pill(tester);
    expect(middle.width, lessThan(end.width));
    expect(labelOpacity(tester, 'Solicitudes'), 1);
    expect(find.byKey(MorphingNavigation.indicatorKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Clics rápidos retoman la geometría visible y llegan al último destino',
      (tester) async {
    await show(tester);
    for (final index in [3, 0, 2, 1, 3, 0]) {
      final before = pill(tester);
      await tester.tap(find.byKey(MorphingNavigation.destinationKey(index)));
      await tester.pump();
      expect(pill(tester), before,
          reason: 'Sin salto al redirigir hacia $index');
      await tester.pump(const Duration(milliseconds: 70));
      expect(find.byKey(MorphingNavigation.indicatorKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(selected.value, 0);
    final destination =
        tester.getRect(find.byKey(MorphingNavigation.destinationKey(0)));
    expect(pill(tester), destination);
  });

  testWidgets('Recorrido largo se contrae, vuelve y soporta redimensionamiento',
      (tester) async {
    await show(tester);
    selected.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(pill(tester).width, closeTo(pill(tester).height, 1));
    tester.view.physicalSize = const Size(320, 160);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(pill(tester).right, lessThanOrEqualTo(302));
    selected.value = 0;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(pill(tester),
        tester.getRect(find.byKey(MorphingNavigation.destinationKey(0))));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Roles, texto ampliado, RTL y movimiento reducido conservan destinos',
      (tester) async {
    for (final client in [false, true]) {
      for (final rtl in [false, true]) {
        selected.value = 0;
        await show(tester,
            width: 320, scale: 1.6, reduced: true, rtl: rtl, client: client);
        final count = client ? 3 : 4;
        for (var i = 0; i < count; i++) {
          selected.value = i;
          await tester.pump();
          final destination =
              tester.getRect(find.byKey(MorphingNavigation.destinationKey(i)));
          expect(pill(tester), destination);
          for (var j = 0; j < count; j++) {
            final size = tester
                .getSize(find.byKey(MorphingNavigation.destinationKey(j)));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('Hover, teclado y semántica no crean un segundo indicador',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
        tester.getCenter(find.byKey(MorphingNavigation.destinationKey(2))));
    await tester.pumpAndSettle();
    expect(find.byKey(MorphingNavigation.indicatorKey), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected.value, 1);
    expect(
        tester
            .getSemantics(find.bySemanticsLabel('Solicitudes'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(selected.value, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(selected.value, 0);
    await mouse.removePointer();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fotogramas de comparación de ida y retorno', (tester) async {
    if (Platform.environment['SAVE_MENU_PREVIEW'] != '1') return;
    final fonts = FontLoader('AppRoboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final preview = GlobalKey();
    await show(tester, preview: preview);
    for (final target in [1, 3, 0]) {
      selected.value = target;
      await tester.pump();
      for (var t = 0; t <= 600; t += 50) {
        if (t > 0) await tester.pump(const Duration(milliseconds: 50));
        await saveUiPreview(
            tester, preview, 'menu-$target-${t.toString().padLeft(3, '0')}');
      }
    }
  });
}
