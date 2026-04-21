import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/sensor_data.dart';
import '../config/app_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  String _userName = 'uživateli';

  // Tracking pro prevenci spam notifikací
  DateTime? _lastCo2Notification;
  DateTime? _lastHumidityNotification;
  DateTime? _lastSleepNotification;

  static const Duration _notificationCooldown = Duration(minutes: 30);

  Future<void> initialize({String? userName}) async {
    if (_isInitialized) return;

    if (userName != null) {
      _userName = userName;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void setUserName(String name) {
    _userName = name;
  }

  void setEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Navigace po kliknutí na notifikaci
    print('Notification tapped: ${response.payload}');
  }

  // Kontrola cooldown - prevence spamu
  bool _canSendNotification(DateTime? lastNotification) {
    if (lastNotification == null) return true;
    return DateTime.now().difference(lastNotification) > _notificationCooldown;
  }

  // Notifikace pro vysoké CO₂
  Future<void> notifyHighCo2(int co2Value) async {
    if (!_notificationsEnabled) return;
    if (!_canSendNotification(_lastCo2Notification)) return;

    String title = 'Vysoká hladina CO₂!';
    String body = 'Ahoj $_userName, CO₂ je velmi vysoké ($co2Value ppm). '
        'Doporučuji okamžitě vyvětrat místnost.';

    await _showNotification(
      id: 1,
      title: title,
      body: body,
      payload: 'high_co2',
    );

    _lastCo2Notification = DateTime.now();
  }

  // Notifikace pro špatnou vlhkost
  Future<void> notifyHumidity(double humidity, bool isTooHigh) async {
    if (!_notificationsEnabled) return;
    if (!_canSendNotification(_lastHumidityNotification)) return;

    String title = isTooHigh ? 'Vysoká vlhkost' : 'Nízká vlhkost';
    String body =
        'Ahoj $_userName, vlhkost vzduchu je ${humidity.toStringAsFixed(0)}%. ';

    if (isTooHigh) {
      body += 'Doporučuji použít odvlhčovač nebo vyvětrat.';
    } else {
      body += 'Zvažte použití zvlhčovače vzduchu.';
    }

    await _showNotification(
      id: 2,
      title: title,
      body: body,
      payload: 'humidity',
    );

    _lastHumidityNotification = DateTime.now();
  }

  // Notifikace pro špatný vzduch během spánku
  Future<void> notifySleepQuality(String issue, String recommendation) async {
    if (!_notificationsEnabled) return;
    if (!_canSendNotification(_lastSleepNotification)) return;

    String title = 'Kvalita vzduchu během spánku';
    String body = 'Ahoj $_userName, $issue $recommendation';

    await _showNotification(
      id: 3,
      title: title,
      body: body,
      payload: 'sleep_quality',
    );

    _lastSleepNotification = DateTime.now();
  }

  // Scheduled notifikace - připomenutí větrat před spaním
  Future<void> scheduleVentilationReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_notificationsEnabled) return;

    // TODO: Implementovat scheduled notifications
    // Vyžaduje flutter_local_notifications s timezone support

    print('Scheduled ventilation reminder for $hour:$minute');
  }

  // Generická metoda pro zobrazení notifikace
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'air_quality_channel',
      'Kvalita vzduchu',
      channelDescription: 'Upozornění na kvalitu vzduchu',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Monitoring funkce - volá se z SensorService
  void checkSensorThresholds(SensorData data) {
    // CO₂ check
    if (data.co2 >= AppConfig.instance.co2WarningThreshold) {
      notifyHighCo2(data.co2);
    }

    // Vlhkost check
    if (data.humidity > AppConfig.instance.humidityMaxWarning) {
      notifyHumidity(data.humidity, true);
    } else if (data.humidity < AppConfig.instance.humidityMinWarning) {
      notifyHumidity(data.humidity, false);
    }
  }

  // Cancel všech notifikací
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Cancel specifické notifikace
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
