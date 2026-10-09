import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Cerradura local de la app (PIN + huella/Face ID opcional). No tiene
/// nada que ver con la sesión de la base local: es una traba extra sobre el
/// dispositivo, para que no cualquiera que agarre el celular desbloqueado
/// vea los datos financieros. Todo corre en el propio dispositivo, sin
/// ningún servicio pago.
class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'app_lock_enabled';
  static const _useBiometricsKey = 'app_lock_use_biometrics';
  static const _pinHashKey = 'app_lock_pin_hash';
  static const _pinSaltKey = 'app_lock_pin_salt';

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get isEnabled async =>
      (await _storage.read(key: _enabledKey)) == 'true';

  Future<void> setEnabled(bool value) async {
    await _storage.write(key: _enabledKey, value: value.toString());
    if (!value) {
      // Al apagar la cerradura no tiene sentido dejar el PIN guardado.
      await _storage.delete(key: _pinHashKey);
      await _storage.delete(key: _pinSaltKey);
      await _storage.delete(key: _useBiometricsKey);
    }
  }

  Future<bool> get useBiometrics async =>
      (await _storage.read(key: _useBiometricsKey)) == 'true';

  Future<void> setUseBiometrics(bool value) async {
    await _storage.write(key: _useBiometricsKey, value: value.toString());
  }

  Future<bool> hasPinSet() async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final storedHash = await _storage.read(key: _pinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  /// true si el dispositivo tiene huella/Face ID configurado y disponible
  /// para usar (no solo que el hardware exista).
  Future<bool> get canUseBiometrics async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      debugPrint('No se pudo consultar biometría disponible: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirmá tu identidad para entrar a Contador Engine',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Autenticación biométrica falló o fue cancelada: $e');
      return false;
    }
  }
}
