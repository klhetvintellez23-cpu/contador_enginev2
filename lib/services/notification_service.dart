import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio local diario de "toca cobrar hoy". No depende de un backend
/// de push: se reprograma cada vez que la app sincroniza datos (ver
/// [DebtProvider.fetchAll]), usando el conteo de cobros del día más
/// reciente que la app conoce. Si el celular pasa varios días sin abrir la
/// app, el aviso puede quedar desactualizado hasta la próxima sincronización.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _dailyReminderId = 1001;
  static const int _defaultHour = 8;
  static const int _defaultMinute = 0;

  /// El recordatorio es una función pensada para celular (Android/iOS). En
  /// escritorio (Windows/Linux/macOS) o web se hace un no-op en vez de exigir
  /// la configuración nativa propia de esas plataformas, que no aplica aquí.
  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init() async {
    if (_initialized) return;
    if (!_isSupportedPlatform) {
      _initialized = true;
      return;
    }
    tz_data.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Si no se puede detectar la zona horaria del dispositivo, se sigue
      // con la zona por defecto en vez de bloquear el arranque de la app.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  /// Pide permiso de notificaciones. En Android solo hace falta desde la
  /// versión 13 (API 33); en versiones anteriores no hace nada.
  Future<void> requestPermission() async {
    await init();
    if (!_isSupportedPlatform) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Reprograma (o cancela, si [count] es 0) el aviso diario de cobros.
  Future<void> scheduleDailyCollectionsReminder(int count) async {
    await init();
    if (!_isSupportedPlatform) return;
    await _plugin.cancel(id: _dailyReminderId);
    if (count <= 0) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, _defaultHour, _defaultMinute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final body = count == 1
        ? 'Tienes 1 cliente por cobrar hoy.'
        : 'Tienes $count clientes por cobrar hoy.';

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      scheduledDate: scheduled,
      title: 'Cobros de hoy',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_collections',
          'Cobros de hoy',
          channelDescription: 'Recordatorio diario de clientes por cobrar.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelDailyReminder() async {
    await init();
    if (!_isSupportedPlatform) return;
    await _plugin.cancel(id: _dailyReminderId);
  }
}
