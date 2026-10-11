import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:contador_engine/services/prototype_verification_code.dart';

void main() {
  test('Genera cuatro caracteres válidos sin repetir consecutivamente', () {
    var now = DateTime.utc(2026, 10, 9);
    final verification =
        PrototypeVerificationCode(random: Random(41), now: () => now);
    addTearDown(verification.dispose);
    final pattern = RegExp(r'^[A-Z0-9]{4}$');
    var previous = verification.code;
    expect(pattern.hasMatch(previous), isTrue);
    for (var i = 0; i < 1000; i++) {
      now = now.add(const Duration(minutes: 1));
      expect(verification.renew(), isTrue);
      expect(pattern.hasMatch(verification.code), isTrue);
      expect(verification.code, isNot(previous));
      previous = verification.code;
    }
  });

  test('En el instante de expiración rechaza el anterior sin esperar un tick',
      () {
    var now = DateTime.utc(2026, 10, 9);
    final verification = PrototypeVerificationCode(now: () => now);
    addTearDown(verification.dispose);
    final original = verification.code;
    expect(verification.remainingSeconds, 60);
    now = now.add(const Duration(seconds: 59, milliseconds: 999));
    expect(verification.matches(original), isTrue);
    expect(verification.remainingSeconds, 1);
    now = now.add(const Duration(milliseconds: 1));
    expect(verification.matches(original), isFalse);
    expect(verification.code, isNot(original));
    expect(verification.remainingSeconds, 60);
    expect(verification.matches(verification.code), isTrue);
    expect(verification.matches('----'), isFalse);
    expect(verification.matches('123'), isFalse);
  });

  test('Al volver de segundo plano usa el vencimiento, no los ticks recibidos',
      () {
    final start = DateTime.utc(2026, 10, 9);
    var now = start;
    final verification = PrototypeVerificationCode(now: () => now);
    addTearDown(verification.dispose);
    final original = verification.code;
    now = start.add(const Duration(minutes: 4, seconds: 17));
    verification.refresh();
    expect(verification.matches(original), isFalse);
    expect(verification.expiresAt, start.add(const Duration(minutes: 5)));
    expect(verification.remainingSeconds, 43);
    final current = verification.code;
    verification.refresh();
    expect(verification.code, current);
    expect(verification.remainingSeconds, 43);
  });

  test('Reenvío reinicia un minuto; detener y liberar impide validar o renovar',
      () {
    var now = DateTime.utc(2026, 10, 9);
    final verification = PrototypeVerificationCode(now: () => now);
    addTearDown(verification.dispose);
    final original = verification.code;
    now = now.add(const Duration(seconds: 27));
    expect(verification.renew(), isFalse);
    expect(verification.code, original);
    now = now.add(const Duration(seconds: 33));
    expect(verification.renew(), isTrue);
    expect(verification.code, isNot(original));
    expect(verification.remainingSeconds, 60);
    expect(verification.expiresAt, now.add(const Duration(minutes: 1)));
    expect(verification.matches(original), isFalse);
    final revision = verification.revision;
    verification.stop();
    now = now.add(const Duration(minutes: 2));
    verification.refresh();
    verification.renew();
    expect(verification.matches(verification.code), isFalse);
    expect(verification.revision, revision);
    verification.dispose();
    verification.dispose();
    expect(verification.matches(verification.code), isFalse);
  });

  test('Reenvíos repetidos no cambian el código ni extienden el bloqueo', () {
    var now = DateTime.utc(2026, 10, 9);
    final verification = PrototypeVerificationCode(now: () => now);
    addTearDown(verification.dispose);
    final original = verification.code;
    final expires = verification.expiresAt;
    for (var i = 0; i < 100; i++) {
      expect(verification.renew(), isFalse);
    }
    expect(verification.code, original);
    expect(verification.expiresAt, expires);
    now = now.add(const Duration(seconds: 59, milliseconds: 999));
    verification.refresh();
    expect(verification.canResend, isFalse);
    expect(verification.renew(), isFalse);
    now = now.add(const Duration(milliseconds: 1));
    verification.refresh();
    expect(verification.canResend, isTrue);
    final automaticallyRenewed = verification.code;
    expect(verification.renew(), isTrue);
    expect(verification.code, isNot(automaticallyRenewed));
    expect(verification.canResend, isFalse);
    final resent = verification.code;
    for (var i = 0; i < 100; i++) {
      expect(verification.renew(), isFalse);
    }
    expect(verification.code, resent);
    now = now.add(const Duration(seconds: 59));
    expect(verification.renew(), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(verification.renew(), isTrue);
  });
}
