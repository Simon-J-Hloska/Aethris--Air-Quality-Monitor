import 'package:air_quality_app/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vocative.dart';

class AppConfig {
  // Privátní konstruktor
  AppConfig._privateConstructor();

  // Jediná instance
  static final AppConfig _instance = AppConfig._privateConstructor();

  // Factory konstruktor
  factory AppConfig() {
    return _instance;
  }

  // Getter pro explicitní přístup
  static AppConfig get instance => _instance;

  // API konfigurace
  String defaultEspIp = AppSettings().espIpAddress;
  int defaultEspPort = AppSettings().espPort;
  String apiEndpoint = '/sensors';
  String espName = 'Aethris';
  String userName = AppSettings().userProfile?.name ?? 'Uživatel';
  Gender gender = AppSettings().userProfile?.gender ?? Gender.male;
  String get userVocative => "${CzechVocative.getVocative(userName)}!";

  // Intervaly
  Duration defaultRefreshInterval = const Duration(seconds: 10);
  Duration connectionTimeout = const Duration(seconds: 5);

  // Limity a prahy senzorů
  int co2GoodThreshold = 800;
  int co2WarningThreshold = 1200;

  double tempMinGood = 18.0;
  double tempMaxGood = 22.0;
  double tempMinWarning = 16.0;
  double tempMaxWarning = 25.0;

  double humidityMinGood = 40.0;
  double humidityMaxGood = 60.0;
  double humidityMinWarning = 30.0;
  double humidityMaxWarning = 70.0;

  // Spánek
  int minimumSleepDurationMinutes = 360; // 6 hodin
  int optimalSleepDurationMinutes = 480; // 8 hodin

  // UI konstanty
  double cardBorderRadius = 16.0;
  double cardPadding = 16.0;
  double screenPadding = 20.0;

  // Barvy podle kvality
  Map<String, int> qualityColors = {
    'good': 0xFF4CAF50, // Zelená
    'warning': 0xFFFF9800, // Oranžová
    'critical': 0xFFF44336, // Červená
  };

  // Popisky senzorů
  Map<String, String> sensorDescriptions = {
    'co2':
        'Oxid uhličitý (CO₂) měří kvalitu vzduchu. Vysoké hodnoty mohou způsobit únavu a špatnou koncentraci.',
    'temperature':
        'Ideální teplota pro spánek je 18-22°C. Příliš vysoká nebo nízká teplota negativně ovlivňuje kvalitu spánku.',
    'humidity':
        'Optimální vlhkost vzduchu je 40-60%. Nízká vlhkost vysušuje sliznice, vysoká podporuje růst plísní či podporuje bakterie.',
    'pressure':
        'Atmosférický tlak ovlivňuje pocit pohody. Náhlé změny mohou způsobit bolesti hlavy.',
    'gas':
        'Senzor, který sleduje, jak moc je vzduch chemicky znečištěný. Třeba od prachu v pokoji. Nízké hodnoty indikují přítomnost nečistot.',
    'iaq':
        "Index kvality vzduchu (IAQ) kombinuje data z různých senzorů, aby poskytl celkový přehled o kvalitě vzduchu. Nižší hodnoty znamenají horší kvalitu, naopak vyšší hodnoty indikují lepší kvalitu vzduchu.",
  };

  // Chatbot odpovědi - šablony
  List<String> getChatbotGreetings() {
    return [
      'Ahoj $userVocative! Jak ti můžu pomoci s kvalitou vzduchu?',
      'Zdravím $userVocative! Mám pro tebe aktuální data o vzduchu.',
      'Zdravím $userVocative! Podíváme se spolu na stav vzduchu v okolí.',
      'Ahoj $userVocative! Máš zájem o aktuální informace o ovzduší kolem?',
      'Dobrý den $userVocative! Kvalita vzduchu je připravena ke kontrole.',
      'Zdravím $userVocative! Rád ti poskytnu přehled o vzduchu, který dýcháš.',
      'Ahoj $userVocative! Mám pro tebe přehledné informace o stavu ovzduší.',
      'Vítej $userVocative! Podívejme se společně na kvalitu vzduchu.',
      'Ahoj $userVocative! Sleduji kvalitu vzduchu a rád se s tebou podělím o data.',
      'Dobrý den $userVocative! Jsem připraven ti ukázat, jak na tom je vzduch v tvém prostředí.',
      'Ahoj $userVocative! Chceš vědět, zda je teď vhodné větrat?',
    ];
  }
}
// Model pro uživatelská nastavení

class AppSettings extends ChangeNotifier {
  String espIpAddress = '192.168.4.1';
  int espPort = 80;
  Duration refreshInterval = const Duration(seconds: 30);
  bool chatbotEnabled = true;
  bool notificationsEnabled = false;
  WorkflowMode workflowM = WorkflowMode.relax;
  bool setupComplete = false;
  UserProfile? userProfile;

  set espI(String value) => espIpAddress = value;
  set espP(int value) => espPort = value;
  set workflow_mode(WorkflowMode value) => workflowM = value;
  set setup_status(bool value) => setupComplete = value;
  set user_profile(UserProfile? value) => userProfile = value;
  set chatbot_enabled(bool value) {
    chatbotEnabled = value;
    notifyListeners();
  }

  bool get isChatbotEnabled => chatbotEnabled;

  AppSettings._privateConstructor();

  static final AppSettings _instance = AppSettings._privateConstructor();

  factory AppSettings() {
    return _instance;
  }

  String get baseUrl => 'http://$espIpAddress:$espPort';
  static AppSettings get instance => _instance;

  Map<String, dynamic> toJson() {
    return {
      'espIpAddress': espIpAddress,
      'espPort': espPort,
      'refreshInterval': refreshInterval.inSeconds,
      'chatbotEnabled': chatbotEnabled,
      'notificationsEnabled': notificationsEnabled,
      'workflowM': workflowM.toString(),
    };
  }

  AppSettings fromJson(Map<String, dynamic> json) {
    espIpAddress = json['espIpAddress'] as String? ?? espIpAddress;
    espPort = json['espPort'] as int? ?? espPort;
    refreshInterval = Duration(seconds: json['refreshInterval'] as int? ?? 10);
    chatbot_enabled = json['chatbotEnabled'] as bool? ?? chatbotEnabled;
    notificationsEnabled =
        json['notificationsEnabled'] as bool? ?? notificationsEnabled;
    workflowM = WorkflowMode.values.firstWhere(
      (v) => v.toString() == json['workflowM'],
      orElse: () => WorkflowMode.relax,
    );
    return this;
  }

  AppSettings copyWith({
    String? espIpAddress,
    int? espPort,
    Duration? refreshInterval,
    bool? chatbotEnabled,
    bool? notificationsEnabled,
    WorkflowMode? workflowM,
  }) {
    this.espIpAddress = espIpAddress ?? this.espIpAddress;
    this.espPort = espPort ?? this.espPort;
    this.refreshInterval = refreshInterval ?? this.refreshInterval;
    chatbot_enabled = chatbotEnabled ?? this.chatbotEnabled;
    this.notificationsEnabled =
        notificationsEnabled ?? this.notificationsEnabled;
    this.workflowM = workflowM ?? this.workflowM;
    return this;
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp_ip', espIpAddress);
    await prefs.setInt('esp_port', espPort);
    await prefs.setInt('refresh_interval', refreshInterval.inSeconds);
    await prefs.setBool('chatbot_enabled', chatbotEnabled);
    await prefs.setBool('notifications_enabled', notificationsEnabled);
    await prefs.setString('workflow_mode', workflowM.toString());
    await prefs.setInt('prev_co2', 1);
    await prefs.remove('prev_co2');
    await prefs.setDouble('prev_temperature', 1.0);
    await prefs.remove('prev_temperature');
    await prefs.setDouble('prev_humidity', 1.0);
    await prefs.remove('prev_humidity');
  }
}

enum WorkflowMode {
  work,
  relax,
  sleep,
}

//final provider = ThresholdProvider(workflowManager);
//final thresholds = provider.thresholds;

class WorkflowManager {
  WorkflowMode getCurrentWorkflow() {
    return AppSettings().workflowM;
  }
}
