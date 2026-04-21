import 'dart:async';
import '../../models/sensor_data.dart';
import '../../config/app_config.dart';
import 'api_service.dart';

class SensorService {
  final ApiService apiService;

  SensorData? _currentData;
  SensorStats _stats = SensorStats.empty();
  bool _isOnline = false;

  Timer? _refreshTimer;
  Duration _refreshInterval = AppConfig.instance.defaultRefreshInterval;

  // Stream controllery pro reactive updates
  final _dataController = StreamController<SensorData>.broadcast();
  final _statsController = StreamController<SensorStats>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Public streamy
  Stream<SensorData> get dataStream => _dataController.stream;
  Stream<SensorStats> get statsStream => _statsController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  // Gettery
  SensorData? get currentData => _currentData;
  SensorStats get stats => _stats;
  bool get isOnline => _isOnline;

  SensorService(this.apiService);

  // Inicializace - spustí periodický refresh
  Future<void> initialize() async {
    await checkConnection();
    if (_isOnline) {
      await fetchData();
      startPeriodicRefresh();
    }
  }

  // Kontrola připojení
  Future<void> checkConnection() async {
    try {
      _isOnline = await apiService.testConnection();
    } catch (e) {
      _isOnline = false;
    }
    _connectionController.add(_isOnline);
  }

  // Načtení dat ze senzorů
  Future<void> fetchData() async {
    try {
      final data = await apiService.getSensorData();
      _currentData = data;
      _stats = _stats.updateWith(data);

      _dataController.add(data);
      _statsController.add(_stats);

      _isOnline = true;
      _connectionController.add(true);
    } catch (e) {
      print('Failed to fetch sensor data: $e');
      _isOnline = false;
      _connectionController.add(false);
    }
  }

  // Spuštění periodického refreshe
  void startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) async {
      await fetchData();
    });
  }

  // Zastavení periodického refreshe
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Změna intervalu refreshe
  void setRefreshInterval(Duration interval) {
    _refreshInterval = interval;
    if (_refreshTimer != null) {
      startPeriodicRefresh();
    }
  }

  // Reset statistik
  Future<void> resetStats() async {
    _stats = SensorStats.empty();
    _statsController.add(_stats);

    // Pokusí se resetovat i na ESP
    try {
      await apiService.resetMinMax();
    } catch (e) {
      print('Failed to reset ESP stats: $e');
    }
  }

  // Načtení statistik z ESP (pokud jsou tam uložené)
  Future<void> loadStatsFromEsp() async {
    try {
      final minMaxData = await apiService.getMinMaxData();
      if (minMaxData != null) {
        _stats = SensorStats.fromJson(minMaxData);
        _statsController.add(_stats);
      }
    } catch (e) {
      print('Failed to load stats from ESP: $e');
    }
  }

  // Vyhodnocení aktuální kvality vzduchu
  Map<String, dynamic> evaluateAirQuality() {
    if (_currentData == null) {
      return {
        'overall': 'unknown',
        'message': 'Žádná data k dispozici',
        'recommendations': <String>[],
      };
    }

    final data = _currentData!;
    final recommendations = <String>[];

    // Vyhodnocení CO2
    if (data.co2 >= AppConfig.instance.co2WarningThreshold) {
      recommendations.add('Okamžitě vyvětrejte místnost - vysoká hladina CO₂!');
    } else if (data.co2 >= AppConfig.instance.co2GoodThreshold) {
      recommendations.add('Doporučujeme vyvětrat místnost');
    }

    // Vyhodnocení teploty
    if (data.temperature > AppConfig.instance.tempMaxWarning) {
      recommendations.add(
        'Příliš vysoká teplota - snižte vytápění nebo zapněte klimatizaci',
      );
    } else if (data.temperature < AppConfig.instance.tempMinWarning) {
      recommendations.add('Příliš nízká teplota - zvyšte vytápění');
    }

    // Vyhodnocení vlhkosti
    if (data.humidity > AppConfig.instance.humidityMaxWarning) {
      recommendations.add(
        'Vysoká vlhkost - zapněte odvlhčovač nebo vyvětrejte',
      );
    } else if (data.humidity < AppConfig.instance.humidityMinWarning) {
      recommendations.add('Nízká vlhkost - zvažte použití zvlhčovače vzduchu');
    }

    return {
      'overall': data.overallQuality.name,
      'message': _getQualityMessage(data.overallQuality),
      'recommendations': recommendations,
    };
  }

  String _getQualityMessage(SensorQuality quality) {
    switch (quality) {
      case SensorQuality.good:
        return 'Kvalita vzduchu je výborná!';
      case SensorQuality.warning:
        return 'Kvalita vzduchu vyžaduje pozornost';
      case SensorQuality.critical:
        return 'Kritická kvalita vzduchu - jednejte!';
    }
  }

  // Získání dat pro konkrétní časový interval (pro vyhodnocení spánku)
  Future<List<SensorData>> getDataForTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    // V reálné implementaci by to mohlo volat API pro historická data
    // Prozatím vrátíme aktuální data jako aproximaci
    if (_currentData != null) {
      return [_currentData!];
    }
    return [];
  }

  // Výpočet průměrných hodnot z dat
  Map<String, double> calculateAverages(List<SensorData> dataList) {
    if (dataList.isEmpty) {
      return {'co2': 0, 'temperature': 0, 'humidity': 0, 'pressure': 0};
    }

    double sumCo2 = 0;
    double sumTemp = 0;
    double sumHumidity = 0;
    double sumPressure = 0;

    for (var data in dataList) {
      sumCo2 += data.co2;
      sumTemp += data.temperature;
      sumHumidity += data.humidity;
      sumPressure += data.pressure;
    }

    final count = dataList.length;

    return {
      'co2': sumCo2 / count,
      'temperature': sumTemp / count,
      'humidity': sumHumidity / count,
      'pressure': sumPressure / count,
    };
  }

  // Dispose
  void dispose() {
    _refreshTimer?.cancel();
    _dataController.close();
    _statsController.close();
    _connectionController.close();
  }
}
