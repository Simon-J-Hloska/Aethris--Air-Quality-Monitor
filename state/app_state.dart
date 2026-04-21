import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';
import '../config/app_config.dart';
import '../services/api/api_service.dart';
import '../services/api/sensor_service.dart';
import '../services/chatbot_service.dart';
import 'dart:async';

// Hlavní App State s ChangeNotifier
class AppState extends ChangeNotifier {
  // Services
  late ApiService _apiService;
  late SensorService _sensorService;
  late ChatbotService _chatbotService;

  // Stream subscriptions (for safe reinitialization)
  StreamSubscription<SensorData>? _dataSub;
  StreamSubscription<SensorStats>? _statsSub;
  StreamSubscription<bool>? _connectionSub;

  // Nastavení
  AppSettings _settings = AppSettings();

  AppState({AppSettings? initialSettings}) {
    if (initialSettings != null) {
      _settings = initialSettings;
    }
  }

  // Current data
  SensorData? _currentSensorData;
  SensorStats _sensorStats = SensorStats.empty();
  bool _isOnline = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Dispose services
  Future<void> _disposeServices() async {
    await _dataSub?.cancel();
    await _statsSub?.cancel();
    await _connectionSub?.cancel();

    _dataSub = null;
    _statsSub = null;
    _connectionSub = null;

    _sensorService.dispose();
  }

  // Chat history
  final List<ChatMessage> _chatHistory = [];

  // Getters
  AppSettings get settings => _settings;
  SensorData? get currentSensorData => _currentSensorData;
  SensorStats get sensorStats => _sensorStats;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  // Getters pro services (pro přímý přístup pokud potřeba)
  SensorService get sensorService => _sensorService;
  ChatbotService get chatbotService => _chatbotService;

  // Inicializace
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_dataSub != null || _statsSub != null || _connectionSub != null) {
        await _disposeServices();
      }

      _apiService = ApiService(appSettings: _settings);
      _sensorService = SensorService(_apiService);
      _chatbotService = ChatbotService(
        sensorService: _sensorService,
      );

      // Nastavení listenerů pro streamy
      _setupStreamListeners();

      // Inicializace sensor service
      await _sensorService.initialize();

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Chyba při inicializaci: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Nastavení stream listenerů
  void _setupStreamListeners() {
    // Sensor data stream
    _dataSub = _sensorService.dataStream.listen((data) {
      _currentSensorData = data;
      _errorMessage = null;
      notifyListeners();
    });

    // Stats stream
    _statsSub = _sensorService.statsStream.listen((stats) {
      _sensorStats = stats;
      notifyListeners();
    });

    // Connection stream
    _connectionSub = _sensorService.connectionStream.listen((isOnline) {
      _isOnline = isOnline;
      _errorMessage = isOnline ? null : 'Ztraceno spojení s ESP zařízením';
      notifyListeners();
    });
  }

  // Aktualizace nastavení
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;

    // Reinicializace API service s novou URL
    _apiService = ApiService(appSettings: _settings);
    _sensorService = SensorService(_apiService);
    _chatbotService = ChatbotService(
      sensorService: _sensorService,
    );

    // Změna intervalu refreshe
    _sensorService.setRefreshInterval(_settings.refreshInterval);

    // Reinicializace
    await _sensorService.initialize();

    notifyListeners();
  }

  Future<void> updateEspIp(String newIp) async {
    _settings = _settings.copyWith(espIpAddress: newIp);

    // Reinitialize API and services
    _apiService = ApiService(appSettings: _settings);
    _sensorService = SensorService(_apiService);
    _chatbotService = ChatbotService(
      sensorService: _sensorService,
    );

    // Setup stream listeners again
    _setupStreamListeners();

    // Initialize sensor service
    await _sensorService.initialize();

    notifyListeners();
  }

  // Manuální refresh dat
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _sensorService.fetchData();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Chyba při načítání dat: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset statistik
  Future<void> resetStatistics() async {
    await _sensorService.resetStats();
    notifyListeners();
  }

  // Odeslání zprávy chatbotu
  Future<void> sendChatMessage(String message) async {
    // Přidání uživatelské zprávy
    _chatHistory.add(
      ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
    );
    notifyListeners();

    // Zpracování odpovědi
    try {
      final response = await _chatbotService.processMessage(message);

      _chatHistory.add(
        ChatMessage(
          text: response.message,
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: response.suggestions,
        ),
      );
    } catch (e) {
      _chatHistory.add(
        ChatMessage(
          text: 'Omlouvám se, došlo k chybě při zpracování vaší zprávy.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    }

    notifyListeners();
  }

  // Vymazání historie chatu
  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    _disposeServices();
    super.dispose();
  }

  void setWorkflowMode(WorkflowMode mode) {
    AppSettings.instance.workflowM = mode;
    notifyListeners();
  }
}

// Model pro zprávu v chatu
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? suggestions;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
