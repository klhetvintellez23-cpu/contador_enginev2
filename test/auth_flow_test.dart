import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:contador_engine/screens/auth_screen.dart';
import 'package:contador_engine/screens/otp_verification_screen.dart';
import 'package:contador_engine/services/local_database_service.dart';
import 'package:contador_engine/services/totp_service.dart';
import 'package:contador_engine/services/prototype_verification_code.dart';
import 'package:contador_engine/utils/app_theme.dart';
import 'package:contador_engine/widgets/auth_ui.dart';
import 'support/ui_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = LocalDatabaseService();
  late Directory directory;
  const email = 'admin@contador.local';
  const password = 'ContadorLocal2026!';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('contador_auth_');
    Hive.init(directory.path);
    await db.init();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> pressAndFlush(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    // Hive's I/O futures must be created in the real async zone, including
    // the button callback, so closing the box cannot wait on a fake-zone write.
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> login(WidgetTester tester, {String secret = password}) async {
    await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
    await tester.enterText(find.byKey(const ValueKey('auth-password')), secret);
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await pressAndFlush(tester, 'Iniciar sesión');
  }

  String currentCode(WidgetTester tester) => tester
      .widget<OtpVerificationScreen>(find.byType(OtpVerificationScreen))
      .challenge
      .verification
      .code;

  test(
      'La contraseña no abre sesión; el código vigente completa un reto de un solo uso',
      () async {
    final events = <LocalUser?>[];
    final subscription = db.authStateChanges.listen(events.add);
    addTearDown(subscription.cancel);
    await expectLater(
        db.beginPrototypeSignIn(email, 'incorrecta'), throwsStateError);
    final challenge = await db.beginPrototypeSignIn(email, password);
    expect(db.currentUser, isNull);
    expect(Hive.box('contador_local_database_v1').get('session_v2'), isNull);
    expect(events, isEmpty);
    await expectLater(
        db.completePrototypeSignIn(challenge, '----'), throwsArgumentError);
    expect(db.currentUser, isNull);
    await db.completePrototypeSignIn(challenge, challenge.verification.code);
    expect(db.currentUser?.role, UserRole.manager);
    await expectLater(
        db.completePrototypeSignIn(challenge, '1234'), throwsStateError);
    await db.signOut();
    final cancelled = await db.beginPrototypeSignIn(email, password);
    db.cancelPrototypeSignIn(cancelled);
    await expectLater(
        db.completePrototypeSignIn(cancelled, '1234'), throwsStateError);
    expect(db.currentUser, isNull);
  });

  test(
      'El acceso simulado usa su código dinámico y la API existente conserva TOTP',
      () async {
    await db.signIn(email, password);
    final secret = TotpService.secret();
    await db.enableTotp(secret, TotpService.code(secret, DateTime.now()));
    await db.signOut();
    await expectLater(
        db.signIn(email, password, otp: '1234'), throwsStateError);
    final challenge = await db.beginPrototypeSignIn(email, password);
    await db.completePrototypeSignIn(challenge, challenge.verification.code);
    expect(db.currentUser?.email, email);
  });

  testWidgets('Login separado, errores, retorno y acceso solo tras verificar',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: StreamBuilder<LocalUser?>(
            stream: db.authStateChanges,
            builder: (context, snapshot) => snapshot.data == null
                ? const AuthScreen()
                : const Scaffold(body: Text('Sesión verificada')))));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(CheckboxListTile), findsNothing);
    await login(tester, secret: 'incorrecta');
    expect(find.text('Credenciales incorrectas.'), findsOneWidget);
    expect(find.byType(OtpVerificationScreen), findsNothing);
    await login(tester);
    expect(find.text('Verificación de código'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email')), findsNothing);
    expect(db.currentUser, isNull);
    await pressAndFlush(tester, 'Volver al inicio de sesión');
    await tester.pumpAndSettle();
    expect(find.byType(OtpVerificationScreen), findsNothing);
    expect(db.currentUser, isNull);
    await login(tester);
    await tester.tap(find.text('Verificar código'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Completa los 4 caracteres del código.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('otp-input')),
        currentCode(tester) == 'AAAA' ? 'BBBB' : 'AAAA');
    await pressAndFlush(tester, 'Verificar código');
    expect(find.text('Código incorrecto o vencido. Usa el código actual.'),
        findsOneWidget);
    expect(db.currentUser, isNull);
    final previous = currentCode(tester);
    await tester.enterText(find.byKey(const ValueKey('otp-input')), 'K7');
    await tester.tap(find.byKey(const ValueKey('resend-code')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(currentCode(tester), previous);
    expect(
        tester
            .widget<EditableText>(find.byKey(const ValueKey('otp-input')))
            .controller
            .text,
        'K7');
    expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('resend-code')))
            .onPressed,
        isNull);
    expect(db.currentUser, isNull);
    await tester.enterText(find.byKey(const ValueKey('otp-input')),
        currentCode(tester).toLowerCase());
    await pressAndFlush(tester, 'Verificar código');
    await tester.pumpAndSettle();
    expect(db.currentUser?.email, email);
    expect(find.text('Sesión verificada'), findsOneWidget);
    expect(find.byType(OtpVerificationScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Registro conserva la cuenta al volver y también requiere código',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AuthScreen()));
    await tester.tap(find.text('¿Primera vez? Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('auth-name')), 'María López');
    await tester.enterText(
        find.byKey(const ValueKey('auth-email')), 'maria@test.local');
    await tester.enterText(
        find.byKey(const ValueKey('auth-password')), password);
    await tester.ensureVisible(find.text('Crear cuenta'));
    await pressAndFlush(tester, 'Crear cuenta');
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
    expect(db.currentUser, isNull);
    await pressAndFlush(tester, 'Volver al inicio de sesión');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-name')), findsNothing);
    await pressAndFlush(tester, 'Iniciar sesión');
    await tester.enterText(find.byKey(const ValueKey('otp-input')),
        currentCode(tester).toLowerCase());
    await pressAndFlush(tester, 'Verificar código');
    expect(db.currentUser?.email, 'maria@test.local');
    expect(db.currentUser?.role, UserRole.client);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Casillas: avance, borrado, corrección, pegado alfanumérico y mayúsculas',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: OtpCodeInput(
                controller: controller,
                onChanged: (_) {},
                onSubmitted: () {}))));
    await tester.pumpAndSettle();
    int activeCell() {
      for (var i = 0; i < 4; i++) {
        final box = tester
            .widget<AnimatedContainer>(find.byKey(ValueKey('otp-box-$i')));
        if (((box.decoration as BoxDecoration).border as Border).top.width >
            1) {
          return i;
        }
      }
      return -1;
    }

    expect(activeCell(), 0);
    tester.testTextInput.enterText('1');
    await tester.pumpAndSettle();
    expect(activeCell(), 1);
    tester.testTextInput.enterText('12');
    await tester.pumpAndSettle();
    expect(activeCell(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(controller.text, '1');
    expect(activeCell(), 1);
    await tester.enterText(
        find.byKey(const ValueKey('otp-input')), 'k-7m!2 ñ@é 5');
    await tester.pumpAndSettle();
    expect(controller.text, 'K7M2');
    expect(activeCell(), 3);
    await tester.tap(find.byKey(const ValueKey('otp-box-1')));
    await tester.pumpAndSettle();
    expect(activeCell(), 1);
    expect(controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 2));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '1934', selection: TextSelection.collapsed(offset: 2)));
    await tester.pumpAndSettle();
    expect(controller.text, '1934');
    expect(activeCell(), 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Temporizador renueva automáticamente y permite reenvío manual',
      (tester) async {
    final verification =
        PrototypeVerificationCode(now: tester.binding.clock.now);
    addTearDown(verification.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: OtpTimerWidget(
                verification: verification, onResend: verification.renew))));
    final resend = find.byKey(const ValueKey('resend-code'));
    final original = verification.code;
    final deadline = verification.expiresAt;
    expect(find.text('01:00'), findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('00:59'), findsOneWidget);
    // A parent rebuild does not replace the challenge or restart its clock.
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: OtpTimerWidget(
                verification: verification, onResend: verification.renew))));
    expect(verification.expiresAt, deadline);
    expect(verification.code, original);
    await tester.pump(const Duration(seconds: 58));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('00:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('01:00'), findsOneWidget);
    expect(verification.code, isNot(original));
    expect(verification.matches(original), isFalse);
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    final automatic = verification.code;
    await tester.pump(const Duration(seconds: 15));
    await tester.tap(resend);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('01:00'), findsOneWidget);
    expect(verification.code, isNot(automatic));
    expect(verification.matches(automatic), isFalse);
    final manual = verification.code;
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    for (var i = 0; i < 10; i++) {
      await tester.tap(resend);
    }
    expect(verification.code, manual);
    await tester.pump(const Duration(seconds: 59));
    expect(verification.code, manual);
    expect(verification.remainingSeconds, 1);
    await tester.pump(const Duration(milliseconds: 750));
    expect(verification.code, isNot(manual));
    expect(verification.remainingSeconds, 60);
    expect(verification.canResend, isTrue);
    verification.dispose();
    final revision = verification.revision;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
    expect(verification.revision, revision);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login y verificación adaptables con teclado y texto ampliado',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fonts = FontLoader('AppRoboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final preview = GlobalKey();
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1280, 860),
      const Size(640, 420)
    ]) {
      tester.view.physicalSize = size;
      for (final otp in [false, true]) {
        for (final large in [false, true]) {
          await tester.pumpWidget(const SizedBox());
          final challenge = otp
              ? await tester
                  .runAsync(() => db.beginPrototypeSignIn(email, password))
              : null;
          await tester.pumpWidget(RepaintBoundary(
              key: preview,
              child: MaterialApp(
                  key: UniqueKey(),
                  theme: AppTheme.light,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(large ? 1.8 : 1),
                        viewInsets: large
                            ? const EdgeInsets.only(bottom: 280)
                            : EdgeInsets.zero,
                        disableAnimations: large,
                      ),
                      child: child!),
                  home: otp
                      ? OtpVerificationScreen(challenge: challenge!)
                      : const AuthScreen())));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull,
              reason: '$size, OTP=$otp, texto ampliado=$large');
          if (!large && Platform.environment['SAVE_AUTH_PREVIEW'] == '1') {
            await tester.runAsync(() => precacheImage(
                const ResizeImage(
                    AssetImage('assets/icons/contador_engine_icon_source.png'),
                    width: 144),
                tester.element(find.byType(AuthCardContainer))));
            await tester.pump();
            await saveUiPreview(tester, preview,
                'auth-${otp ? 'otp' : 'login'}-${size.width.toInt()}');
          }
          final action = find.text(otp ? 'Verificar código' : 'Iniciar sesión');
          await tester.ensureVisible(action);
          await tester.pump(const Duration(milliseconds: 300));
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
