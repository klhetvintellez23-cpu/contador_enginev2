import 'dart:math';
import 'package:crypto/crypto.dart';

class TotpService {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static String secret() =>
      List.generate(32, (_) => _alphabet[Random.secure().nextInt(32)]).join();
  static String code(String secret, DateTime now) {
    var bits = 0, value = 0;
    final key = <int>[];
    for (final char in secret.toUpperCase().split('')) {
      final digit = _alphabet.indexOf(char);
      if (digit < 0) throw ArgumentError('Secreto TOTP inválido.');
      value = (value << 5) | digit;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        key.add((value >> bits) & 255);
        value &= (1 << bits) - 1;
      }
    }
    var counter = now.millisecondsSinceEpoch ~/ 30000;
    final bytes = List<int>.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      bytes[i] = counter & 255;
      counter >>= 8;
    }
    final digest = Hmac(sha1, key).convert(bytes).bytes;
    final offset = digest.last & 15;
    final number = ((digest[offset] & 127) << 24) |
        (digest[offset + 1] << 16) |
        (digest[offset + 2] << 8) |
        digest[offset + 3];
    return (number % 1000000).toString().padLeft(6, '0');
  }

  static bool verify(String secret, String codeValue, {DateTime? now}) {
    if (!RegExp(r'^\d{6}$').hasMatch(codeValue)) return false;
    final date = now ?? DateTime.now();
    return [-1, 0, 1].any((step) =>
        code(secret, date.add(Duration(seconds: 30 * step))) == codeValue);
  }
}
