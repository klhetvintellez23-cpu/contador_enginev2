import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Local academic prototype only. A production implementation must validate
/// and deliver codes on a trusted server instead of exposing them in the UI.
/// This object owns the only timer, current code, deadline and validation.
class PrototypeVerificationCode extends ChangeNotifier {
  static const lifetime = Duration(seconds: 60);
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final DateTime Function() _now;
  final Random _random;
  Timer? _timer;
  late String _code;
  late DateTime _expiresAt;
  late DateTime _resendAvailableAt;
  int _remainingSeconds = 60;
  int _resendRemainingSeconds = 60;
  int _revision = 0;
  bool _stopped = false;
  bool _disposed = false;

  PrototypeVerificationCode({DateTime Function()? now, Random? random})
      : _now = now ?? DateTime.now,
        _random = random ?? _secureRandom() {
    _code = _generate();
    _expiresAt = _now().add(lifetime);
    _resendAvailableAt = _expiresAt;
    _scheduleTick();
  }

  String get code => _code;
  DateTime get expiresAt => _expiresAt;
  int get remainingSeconds => _remainingSeconds;
  int get revision => _revision;
  int get resendRemainingSeconds => _resendRemainingSeconds;
  bool get canResend => !_stopped && !_disposed && _resendRemainingSeconds == 0;

  static Random _secureRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      // Platforms without a secure source still support the local demo.
      return Random();
    }
  }

  String _generate([String? previous]) {
    String candidate;
    do {
      candidate =
          List.generate(4, (_) => _alphabet[_random.nextInt(_alphabet.length)])
              .join();
    } while (candidate == previous);
    return candidate;
  }

  void _scheduleTick() {
    _timer?.cancel();
    if (_stopped || _disposed) return;
    final remaining = _expiresAt.difference(_now()).inMicroseconds;
    // Schedule the next displayed second against the deadline. Manual resends
    // and late callbacks never shift renewal by the old timer's partial second.
    final delay = remaining > 0 ? (remaining - 1) % 1000000 + 1 : 0;
    _timer = Timer(Duration(microseconds: delay), refresh);
  }

  /// Recompute from the deadline, never from a number of delivered callbacks.
  /// Background time and delayed frames therefore cannot extend validity.
  void refresh() {
    if (_stopped || _disposed) return;
    final now = _now();
    var changed = false;
    if (!now.isBefore(_expiresAt)) {
      final elapsedWindows =
          now.difference(_expiresAt).inMicroseconds ~/ lifetime.inMicroseconds +
              1;
      _expiresAt = _expiresAt.add(
          Duration(microseconds: lifetime.inMicroseconds * elapsedWindows));
      _code = _generate(_code);
      _revision++;
      changed = true;
    }
    final seconds = (_expiresAt.difference(now).inMicroseconds / 1000000)
        .ceil()
        .clamp(0, 60);
    if (seconds != _remainingSeconds) {
      _remainingSeconds = seconds;
      changed = true;
    }
    final resendSeconds =
        (_resendAvailableAt.difference(now).inMicroseconds / 1000000)
            .ceil()
            .clamp(0, 60);
    if (resendSeconds != _resendRemainingSeconds) {
      _resendRemainingSeconds = resendSeconds;
      changed = true;
    }
    if (changed) notifyListeners();
    _scheduleTick();
  }

  /// Manual resend invalidates the previous code and starts a full minute.
  /// Cancels the pending tick before scheduling another; timers never overlap.
  bool renew() {
    final now = _now();
    if (_stopped || _disposed || now.isBefore(_resendAvailableAt)) return false;
    _code = _generate(_code);
    _expiresAt = now.add(lifetime);
    _resendAvailableAt = _expiresAt;
    _remainingSeconds = 60;
    _resendRemainingSeconds = 60;
    _revision++;
    notifyListeners();
    _scheduleTick();
    return true;
  }

  bool matches(String candidate) {
    if (_stopped || _disposed) return false;
    refresh(); // Recheck even if the UI's last timer callback was delayed.
    return candidate == _code;
  }

  void stop() {
    if (_stopped || _disposed) return;
    _stopped = true;
    _timer?.cancel();
  }

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    super.dispose();
  }
}
