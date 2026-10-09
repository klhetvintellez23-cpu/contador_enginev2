/// La app está pensada para Panamá: el teléfono se guarda siempre con el
/// código de país +507 para que el envío directo a WhatsApp
/// (ver receipt_share_helper.dart) funcione sin que el usuario tenga que
/// escribirlo cada vez.
const String panamaCountryCode = '+507';

/// Convierte lo que la persona escribe (solo el número local) en el
/// teléfono completo a guardar. Si ya escribió un "+" (por ejemplo pegó un
/// número de otro país), se respeta tal cual.
String normalizePanamaPhone(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('+')) return trimmed;
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return trimmed;
  return '$panamaCountryCode$digits';
}

/// Para mostrar en el campo de edición: si el teléfono guardado tiene el
/// prefijo de Panamá, se quita para que la persona solo vea/edite el
/// número local (el prefijo se muestra aparte, fijo, en el campo).
String displayLocalPhone(String? phone) {
  if (phone == null) return '';
  if (phone.startsWith(panamaCountryCode)) {
    return phone.substring(panamaCountryCode.length);
  }
  return phone;
}
