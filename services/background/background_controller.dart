import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:air_quality_app/config/app_config.dart';
import 'package:air_quality_app/models/sensor_data.dart';
import 'package:air_quality_app/services/api/api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'aethris_foreground',
    'Aethris Monitoring', // User visible name
    description: 'Běží na pozadí pro sledování kvality vzduchu',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // This links to the function below
      autoStart: true,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId:
          'aethris_foreground', // The persistent "App is running" notification
      initialNotificationTitle: 'Aethris Monitoring',
      initialNotificationContent: 'Sleduji data pomocí Aethris...',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final notifications = FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Reconstruct your API Service using stored data
  final settings = AppSettings();
  settings.setup_status = prefs.getBool('setup_complete') ?? false;
  final raw = prefs.getString('user_profile');
  if (raw != null) {
    settings.user_profile = jsonDecode(raw);
  }
  settings.espI = prefs.getString('esp_ip') ?? '192.168.4.1';
  settings.espP = prefs.getInt('esp_port') ?? 80;
  settings.refreshInterval =
      Duration(seconds: prefs.getInt('refresh_interval') ?? 10);
  settings.chatbotEnabled = prefs.getBool('chatbot_enabled') ?? true;
  settings.notificationsEnabled =
      prefs.getBool('notifications_enabled') ?? false;
  settings.workflowM = WorkflowMode.values.firstWhere(
    (v) => v.toString() == prefs.getString('workflow_mode'),
    orElse: () => WorkflowMode.relax,
  );

  final apiService = ApiService(appSettings: settings);
  if (prefs.getBool('notifications_enabled') == true) {
    // The 5-minute heart-beat
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        await prefs.reload();
        final SensorData data = await apiService.getSensorData();
        //co2
        int prevCo2 = prefs.getInt('prev_co2') ?? data.co2;
        SensorQuality currentCo2Quality = data.co2Quality();
        if (data.co2Quality(co2_new: prevCo2) != currentCo2Quality) {
          await prefs.setInt('prev_co2', data.co2);
          _sendNotification(notifications,
              "CO2 změnilo kvalitu na ${currentCo2Quality.displayName}!");
        }
        //temperature
        double prevTemperatureQuality =
            prefs.getDouble('prev_temperature') ?? data.temperature;
        SensorQuality currentTemperatureQuality = data.temperatureQuality();
        if ((data.temperatureQuality(temp_new: prevTemperatureQuality) !=
            currentTemperatureQuality)) {
          await prefs.setDouble('prev_temperature', data.temperature);
          _sendNotification(notifications,
              "Teplota změnila kvalitu na ${currentTemperatureQuality.displayName}!");
        }
        //humidity
        double prevHumidityQuality =
            prefs.getDouble('prev_humidity') ?? data.humidity;
        SensorQuality currentHumidityQuality = data.humidityQuality();
        if ((data.humidityQuality(humidity_new: prevHumidityQuality) !=
            currentHumidityQuality)) {
          await prefs.setDouble('prev_humidity', data.humidity);
          _sendNotification(notifications,
              "Vlhkost změnila kvalitu na ${currentHumidityQuality.displayName}!");
        }
      } catch (e) {
        print('Background Error: $e');
      }
    });
  }
}

// Keep your helper function here
void _sendNotification(
    FlutterLocalNotificationsPlugin plugin, String msg) async {
  await plugin.show(
    1, // ID
    'Upozornění senzoru', // Title
    msg, // Content
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'sensor_alerts',
        'Senzory',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// Required for iOS
@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}
