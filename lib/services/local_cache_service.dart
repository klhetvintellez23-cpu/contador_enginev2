import 'package:hive_flutter/hive_flutter.dart';

/// Cache local + cola de sincronización para que la app funcione sin
/// conexión: guarda una copia de la última data conocida de cada tabla
/// (para poder leer offline) y una cola de escrituras pendientes (para
/// poder escribir offline y subirlas solas cuando vuelva la señal).
class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  static const List<String> _mirrorTables = [
    'customers',
    'loans',
    'payments',
    'capital_history',
  ];
  static const String _settingsBoxName = 'local_v1_cache_settings';
  static const String _outboxBoxName = 'local_v1_pending_mutations';
  static const String _receiptsBoxName = 'local_v1_receipt_history';

  bool _initialized = false;

  Future<void> init({String? directory}) async {
    if (_initialized && Hive.isBoxOpen(_settingsBoxName)) return;
    if (directory == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directory);
    }
    for (final table in _mirrorTables) {
      await Hive.openBox(_mirrorBoxName(table));
    }
    await Hive.openBox(_settingsBoxName);
    await Hive.openBox(_outboxBoxName);
    await Hive.openBox(_receiptsBoxName);
    _initialized = true;
  }

  String _mirrorBoxName(String table) => 'local_v1_cache_$table';
  Box _box(String name) => Hive.box(name);

  // ---------------- Espejos (última copia conocida de cada tabla) ----------------

  Future<void> replaceMirror(
      String table, List<Map<String, dynamic>> rows) async {
    final box = _box(_mirrorBoxName(table));
    await box.clear();
    await box.putAll({for (final row in rows) row['id'].toString(): row});
  }

  List<Map<String, dynamic>> readMirror(String table) {
    final box = _box(_mirrorBoxName(table));
    return box.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }

  Future<void> upsertMirrorRow(String table, Map<String, dynamic> row) async {
    final id = row['id'];
    if (id == null) return;
    await _box(_mirrorBoxName(table)).put(id.toString(), row);
  }

  Future<void> mergeMirrorRow(
      String table, String id, Map<String, dynamic> patch) async {
    final box = _box(_mirrorBoxName(table));
    final existing = box.get(id);
    final merged = {
      if (existing != null) ...Map<String, dynamic>.from(existing as Map),
      ...patch,
      'id': id,
    };
    await box.put(id, merged);
  }

  Future<void> removeMirrorRow(String table, String id) async {
    await _box(_mirrorBoxName(table)).delete(id);
  }

  // ---------------- Capital inicial (fallback simple, no relacional) ----------------

  Future<void> saveInitialCapitalFallback(double value) async {
    await _box(_settingsBoxName).put('initial_capital', value);
  }

  double? readInitialCapitalFallback() {
    final v = _box(_settingsBoxName).get('initial_capital');
    return v == null ? null : (v as num).toDouble();
  }

  // ---------------- Nombre del negocio (fallback simple, no relacional) ----------------

  Future<void> saveBusinessNameFallback(String value) async {
    await _box(_settingsBoxName).put('business_name', value);
  }

  String? readBusinessNameFallback() {
    return _box(_settingsBoxName).get('business_name') as String?;
  }

  // ---------------- Logo del negocio (solo local, no se sincroniza) ----------------

  Future<void> saveBusinessLogoPath(String? path) async {
    if (path == null) {
      await _box(_settingsBoxName).delete('business_logo_path');
    } else {
      await _box(_settingsBoxName).put('business_logo_path', path);
    }
  }

  String? readBusinessLogoPath() {
    return _box(_settingsBoxName).get('business_logo_path') as String?;
  }

  // ---------------- Preferencias de dispositivo (no son datos del negocio) ----------------

  static const String _autoShareReceiptKey = 'auto_share_receipt';

  Future<void> setAutoShareReceipt(bool value) async {
    await _box(_settingsBoxName).put(_autoShareReceiptKey, value);
  }

  /// Activado por defecto: al registrar un cobro se ofrece enviar el
  /// comprobante enseguida (WhatsApp / compartir).
  bool get autoShareReceipt =>
      (_box(_settingsBoxName).get(_autoShareReceiptKey) as bool?) ?? true;

  static const String _overdueGraceDaysKey = 'overdue_grace_days';

  Future<void> setOverdueGraceDays(int days) async {
    await _box(_settingsBoxName).put(_overdueGraceDaysKey, days);
  }

  /// Días extra de tolerancia antes de marcar un préstamo como atrasado,
  /// además de su propio ciclo (diario/semanal/etc). 0 por defecto.
  int get overdueGraceDays =>
      (_box(_settingsBoxName).get(_overdueGraceDaysKey) as int?) ?? 0;

  static const String _overdueAlertsEnabledKey = 'overdue_alerts_enabled';

  Future<void> setOverdueAlertsEnabled(bool value) async {
    await _box(_settingsBoxName).put(_overdueAlertsEnabledKey, value);
  }

  /// Activado por defecto: marca préstamos como atrasados y muestra sus
  /// avisos (campanita, alertas de capital, punto rojo en clientes).
  bool get overdueAlertsEnabled =>
      (_box(_settingsBoxName).get(_overdueAlertsEnabledKey) as bool?) ?? true;

  static const String _dailyReminderEnabledKey = 'daily_reminder_enabled';

  Future<void> setDailyReminderEnabled(bool value) async {
    await _box(_settingsBoxName).put(_dailyReminderEnabledKey, value);
  }

  /// Activado por defecto: avisa por notificación (aunque la app esté
  /// cerrada) cuántos clientes tocan cobrar hoy.
  bool get dailyReminderEnabled =>
      (_box(_settingsBoxName).get(_dailyReminderEnabledKey) as bool?) ?? true;

  // ---------------- Historial de comprobantes generados (solo local, por cliente) ----------------
  // La imagen queda guardada en el celular; aquí solo se indexa para poder
  // listarla/reenviarla ordenada por cliente. No se sincroniza a la nube.

  Future<void> saveReceiptRecord(Map<String, dynamic> record) async {
    final id = record['id'] as String;
    await _box(_receiptsBoxName).put(id, record);
  }

  /// Comprobante ya guardado para un cobro puntual (si existe), para
  /// reutilizarlo en vez de regenerar la imagen cada vez que se comparte.
  Map<String, dynamic>? receiptForPayment(String paymentId) {
    for (final v in _box(_receiptsBoxName).values) {
      final r = Map<String, dynamic>.from(v as Map);
      if (r['paymentId'].toString() == paymentId) return r;
    }
    return null;
  }

  List<Map<String, dynamic>> receiptsForCustomer(String customerId) {
    final receipts = _box(_receiptsBoxName)
        .values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((r) => r['customerId'].toString() == customerId)
        .toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return receipts;
  }

  // ---------------- Cola de escrituras pendientes (outbox) ----------------

  Future<void> enqueueMutation(String type, Map<String, dynamic> args) async {
    await _box(_outboxBoxName).add({
      'type': type,
      'args': args,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Mutaciones pendientes en orden FIFO (orden de creación == orden de
  /// las llaves autoincrementales que da Hive con `box.add`).
  List<MapEntry<dynamic, Map<String, dynamic>>> pendingMutations() {
    final box = _box(_outboxBoxName);
    return box.keys.map((key) {
      final raw = Map<String, dynamic>.from(box.get(key) as Map);
      return MapEntry(key, {
        'type': raw['type'] as String,
        'args': Map<String, dynamic>.from(raw['args'] as Map),
      });
    }).toList();
  }

  Future<void> removeMutation(dynamic key) async {
    await _box(_outboxBoxName).delete(key);
  }

  int get pendingCount => _initialized ? _box(_outboxBoxName).length : 0;

  Future<void> clearAll() async {
    for (final table in _mirrorTables) {
      await _box(_mirrorBoxName(table)).clear();
    }
    await _box(_settingsBoxName).clear();
    await _box(_outboxBoxName).clear();
    await _box(_receiptsBoxName).clear();
  }
}
