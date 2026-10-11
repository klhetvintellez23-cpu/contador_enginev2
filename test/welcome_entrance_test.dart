import 'dart:io';

import 'package:contador_engine/screens/auth_screen.dart';
import 'package:contador_engine/utils/app_theme.dart';
import 'package:contador_engine/widgets/welcome_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_preview.dart';

void main() {
  final capture = Platform.environment['SAVE_INTRO_PREVIEW'] == '1';
  const logo = ResizeImage(
    AssetImage('assets/icons/contador_engine_icon_source.png'),
    width: 480,
  );

  Future<void> start(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(() =>
        precacheImage(logo, tester.element(find.byType(WelcomeEntrance))));
    // Establish the animation's first vsync after image decoding completes.
    await tester.pump();
  }

  Widget app({bool reduced = false, Widget child = const AuthScreen()}) =>
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: WelcomeEntrance(child: navigator!),
        ),
        home: child,
      );

  testWidgets('Hidden login ignores clicks, keyboard focus and semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester, app());
      final email = find.byKey(const ValueKey('auth-email'));
      await tester.tap(email, warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .focusNode
              .hasFocus,
          isFalse);
      expect(find.bySemanticsLabel('Correo electrónico'), findsNothing);
      expect(find.bySemanticsLabel('Contador Engine'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3400));
      // Flutter reports completed on the vsync after the duration boundary.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.enterText(email, 'persona@ejemplo.com');
      expect(find.text('persona@ejemplo.com'), findsOneWidget);
      expect(find.bySemanticsLabel('Correo electrónico'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Completion and parent rebuilds preserve the real login state',
      (tester) async {
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);
    await start(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (context, value, child) => app(),
      ),
    );
    final original = tester.state(find.byType(AuthScreen));
    await tester.pump(const Duration(milliseconds: 1500));
    rebuild.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.state(find.byType(AuthScreen)), same(original));
    await tester.enterText(
        find.byKey(const ValueKey('auth-email')), 'conservar@ejemplo.com');
    rebuild.value++;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(AuthScreen)), same(original));
    expect(find.text('conservar@ejemplo.com'), findsOneWidget);
    expect(find.text('Iniciar sesión').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Reduced motion reveals the login immediately without tickers',
      (tester) async {
    await tester.pumpWidget(app(reduced: true));
    await tester.pump();
    expect(find.text('Iniciar sesión').hitTestable(), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.enterText(
        find.byKey(const ValueKey('auth-email')), 'acceso@ejemplo.com');
    expect(find.text('acceso@ejemplo.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Enabling reduced motion during the intro finishes it once',
      (tester) async {
    await start(tester, app());
    await tester.pump(const Duration(milliseconds: 500));
    final original = tester.state(find.byType(AuthScreen));
    await tester.pumpWidget(app(reduced: true));
    await tester.pump();
    expect(tester.state(find.byType(AuthScreen)), same(original));
    expect(find.text('Iniciar sesión').hitTestable(), findsOneWidget);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(find.text('Iniciar sesión').hitTestable(), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(390, 844),
    const Size(1280, 860),
    const Size(320, 568),
  ]) {
    testWidgets('Continuous reveal and final layout at ${size.width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = size;
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
      final boundary = GlobalKey();
      await start(tester, RepaintBoundary(key: boundary, child: app()));
      final original = tester.state(find.byType(AuthScreen));
      var elapsed = 0;
      for (final time in [0, 450, 950, 1500, 2100, 2500, 2900, 3400]) {
        await tester.pump(Duration(milliseconds: time - elapsed));
        elapsed = time;
        expect(tester.takeException(), isNull);
        if (capture) {
          await saveUiPreview(
              tester, boundary, 'intro-${size.width.toInt()}-$time');
        }
      }
      final email = find.byKey(const ValueKey('auth-email'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.state(find.byType(AuthScreen)), same(original));
      await tester.ensureVisible(email);
      await tester.enterText(email, 'listo@ejemplo.com');
      expect(find.text('listo@ejemplo.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Resizing during the curtain reveal keeps the login mounted',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await start(tester, app());
    final original = tester.state(find.byType(AuthScreen));
    await tester.pump(const Duration(milliseconds: 2300));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.state(find.byType(AuthScreen)), same(original));
    await tester.ensureVisible(find.text('Iniciar sesión'));
    expect(find.text('Iniciar sesión').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Disposing while the logo is being decoded is safe',
      (tester) async {
    tester.binding.imageCache.clear();
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
