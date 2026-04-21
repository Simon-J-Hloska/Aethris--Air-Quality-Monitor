import 'dart:math';
import 'package:air_quality_app/config/app_config.dart';

class SensorData {
  final int co2;
  final double temperature;
  final double humidity;
  final double pressure;
  final int gas;
  final DateTime timestamp;

  SensorData({
    required this.co2,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.gas,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.0,
      co2: (json['co2'] as num?)?.toInt() ?? 0,
      gas: (json['gas_resistance'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] as num).toInt() * 1000,
              isUtc: false)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'humidity': humidity,
        'pressure': pressure,
        'co2': co2,
        'gas': gas,
        'timestamp': timestamp.toIso8601String(),
        'iaq': iaq,
      };

  // IAQ score 0–100 (higher = better)
  // gas resistance weighted 75%, humidity deviation weighted 25%
  int get iaq {
    const referenceGas = 75000.0;
    final gasScore = min(gas / referenceGas, 1.0) * 75;
    final humScore =
        (1.0 - (humidity - 40.0).abs() / 60.0).clamp(0.0, 1.0) * 25;
    final calcIaq = (gasScore + humScore).clamp(0.0, 100.0).toInt();
    return calcIaq;
  }

  SensorQuality iaqQuality({int? iaq_new}) {
    int currentIaq = iaq;
    if (iaq_new != null) currentIaq = iaq_new;

    final t = ThresholdProvider(WorkflowManager()).thresholds;
    if (currentIaq >= t['iaq_good_higher']!) return SensorQuality.good;
    if (currentIaq >= t['iaq_min_warning']!) return SensorQuality.warning;
    return SensorQuality.critical;
  }

  SensorQuality co2Quality({int? co2_new}) {
    int currentCo2 = co2;
    if (co2_new != null) currentCo2 = co2_new;

    final t = ThresholdProvider(WorkflowManager()).thresholds;
    if (currentCo2 <= t['co2_max_good']!) return SensorQuality.good;
    if (currentCo2 <= t['co2_max_warning']!) return SensorQuality.warning;
    return SensorQuality.critical;
  }

  SensorQuality temperatureQuality({double? temp_new}) {
    double currentTemp = temperature;
    if (temp_new != null) currentTemp = temp_new;

    final t = ThresholdProvider(WorkflowManager()).thresholds;
    if (currentTemp >= t['temp_min_good']! &&
        currentTemp <= t['temp_max_good']!) {
      return SensorQuality.good;
    }
    if ((currentTemp >= t['temp_min_warning_low']! &&
            currentTemp <= t['temp_max_warning_low']!) ||
        (currentTemp >= t['temp_min_warning_high']! &&
            currentTemp <= t['temp_max_warning_high']!)) {
      return SensorQuality.warning;
    }
    return SensorQuality.critical;
  }

  SensorQuality humidityQuality({double? humidity_new}) {
    double currentHumidity = humidity;
    if (humidity_new != null) currentHumidity = humidity_new;

    final t = ThresholdProvider(WorkflowManager()).thresholds;
    if (currentHumidity >= t['humidity_min_good']! &&
        currentHumidity <= t['humidity_max_good']!) {
      return SensorQuality.good;
    }
    if ((currentHumidity >= t['humidity_min_warning_low']! &&
            currentHumidity <= t['humidity_max_warning_low']!) ||
        (currentHumidity >= t['humidity_min_warning_high']! &&
            currentHumidity <= t['humidity_max_warning_high']!)) {
      return SensorQuality.warning;
    }
    return SensorQuality.critical;
  }

  // Worst of all four sensors wins
  SensorQuality get overallQuality {
    final qualities = [
      co2Quality,
      temperatureQuality,
      humidityQuality,
      iaqQuality
    ];
    if (qualities.any((q) => q == SensorQuality.critical)) {
      return SensorQuality.critical;
    }
    if (qualities.any((q) => q == SensorQuality.warning)) {
      return SensorQuality.warning;
    }
    return SensorQuality.good;
  }

  @override
  String toString() =>
      'SensorData(co2: $co2, temp: $temperature°C, humidity: $humidity%, '
      'pressure: $pressure hPa, gas: $gas, iaq: ${iaq.toStringAsFixed(1)})';
}

// ── SensorQuality ─────────────────────────────────────────────────────────────

enum SensorQuality {
  good,
  warning,
  critical;

  String get displayName => switch (this) {
        SensorQuality.good => 'Výborné',
        SensorQuality.warning => 'Pozor',
        SensorQuality.critical => 'Kritické',
      };
}

// ── SensorStats ───────────────────────────────────────────────────────────────

class SensorStats {
  final int minCo2;
  final int maxCo2;
  final double minTemperature;
  final double maxTemperature;
  final double minHumidity;
  final double maxHumidity;
  final double minPressure;
  final double maxPressure;
  final int miniaq;
  final int maxiaq;
  final DateTime? lastUpdated;

  SensorStats({
    required this.minCo2,
    required this.maxCo2,
    required this.minTemperature,
    required this.maxTemperature,
    required this.minHumidity,
    required this.maxHumidity,
    required this.minPressure,
    required this.maxPressure,
    required this.miniaq,
    required this.maxiaq,
    this.lastUpdated,
  });

  factory SensorStats.empty() => SensorStats(
        minCo2: 0,
        maxCo2: 0,
        minTemperature: 0,
        maxTemperature: 0,
        minHumidity: 0,
        maxHumidity: 0,
        minPressure: 0,
        maxPressure: 0,
        miniaq: 0,
        maxiaq: 0,
      );

  SensorStats updateWith(SensorData data) => SensorStats(
        minCo2: minCo2 == 0 ? data.co2 : min(minCo2, data.co2),
        maxCo2: max(maxCo2, data.co2),
        minTemperature: minTemperature == 0
            ? data.temperature
            : min(minTemperature, data.temperature),
        maxTemperature: max(maxTemperature, data.temperature),
        minHumidity:
            minHumidity == 0 ? data.humidity : min(minHumidity, data.humidity),
        maxHumidity: max(maxHumidity, data.humidity),
        minPressure:
            minPressure == 0 ? data.pressure : min(minPressure, data.pressure),
        maxPressure: max(maxPressure, data.pressure),
        miniaq: miniaq == 0 ? data.iaq : min(miniaq, data.iaq.toInt()),
        maxiaq: max(maxiaq, data.iaq.toInt()),
        lastUpdated: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'minCo2': minCo2,
        'maxCo2': maxCo2,
        'minTemperature': minTemperature,
        'maxTemperature': maxTemperature,
        'minHumidity': minHumidity,
        'maxHumidity': maxHumidity,
        'minPressure': minPressure,
        'maxPressure': maxPressure,
        'miniaq': miniaq,
        'maxiaq': maxiaq,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory SensorStats.fromJson(Map<String, dynamic> json) => SensorStats(
        minCo2: (json['minCo2'] as num?)?.toInt() ?? 0,
        maxCo2: (json['maxCo2'] as num?)?.toInt() ?? 0,
        minTemperature: (json['minTemperature'] as num?)?.toDouble() ?? 0.0,
        maxTemperature: (json['maxTemperature'] as num?)?.toDouble() ?? 0.0,
        minHumidity: (json['minHumidity'] as num?)?.toDouble() ?? 0.0,
        maxHumidity: (json['maxHumidity'] as num?)?.toDouble() ?? 0.0,
        minPressure: (json['minPressure'] as num?)?.toDouble() ?? 0.0,
        maxPressure: (json['maxPressure'] as num?)?.toDouble() ?? 0.0,
        miniaq: (json['miniaq'] as num?)?.toInt() ?? 0,
        maxiaq: (json['maxiaq'] as num?)?.toInt() ?? 0,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'])
            : null,
      );
}

// ── ThresholdProvider ─────────────────────────────────────────────────────────

class ThresholdProvider {
  final WorkflowManager workflowManager;
  ThresholdProvider(this.workflowManager);

  Map<String, double> get thresholds =>
      switch (workflowManager.getCurrentWorkflow()) {
        WorkflowMode.work => _workThresholds,
        WorkflowMode.sleep => _sleepThresholds,
        WorkflowMode.relax => _relaxThresholds,
      };

  final _relaxThresholds = const <String, double>{
    'temp_min_good': 20.0,
    'temp_max_good': 24.5,
    'temp_min_warning_low': 18.0,
    'temp_max_warning_low': 19.9,
    'temp_min_warning_high': 24.6,
    'temp_max_warning_high': 27.0,
    'humidity_min_good': 35.0,
    'humidity_max_good': 65.0,
    'humidity_min_warning_low': 25.0,
    'humidity_max_warning_low': 34.0,
    'humidity_min_warning_high': 66.0,
    'humidity_max_warning_high': 75.0,
    'co2_max_good': 1000.0,
    'co2_max_warning': 1600.0,
    'iaq_good_higher': 65.0,
    'iaq_min_warning': 40.0,
  };

  final _workThresholds = const <String, double>{
    'temp_min_good': 21.0,
    'temp_max_good': 23.5,
    'temp_min_warning_low': 19.0,
    'temp_max_warning_low': 20.9,
    'temp_min_warning_high': 23.6,
    'temp_max_warning_high': 26.0,
    'humidity_min_good': 40.0,
    'humidity_max_good': 55.0,
    'humidity_min_warning_low': 30.0,
    'humidity_max_warning_low': 39.0,
    'humidity_min_warning_high': 56.0,
    'humidity_max_warning_high': 65.0,
    'co2_max_good': 800.0,
    'co2_max_warning': 1400.0,
    'iaq_good_higher': 75.0,
    'iaq_min_warning': 50.0,
  };

  final _sleepThresholds = const <String, double>{
    'temp_min_good': 17.0,
    'temp_max_good': 19.5,
    'temp_min_warning_low': 15.0,
    'temp_max_warning_low': 16.9,
    'temp_min_warning_high': 19.6,
    'temp_max_warning_high': 24.0,
    'humidity_min_good': 40.0,
    'humidity_max_good': 60.0,
    'humidity_min_warning_low': 30.0,
    'humidity_max_warning_low': 39.0,
    'humidity_min_warning_high': 61.0,
    'humidity_max_warning_high': 70.0,
    'co2_max_good': 700.0,
    'co2_max_warning': 1200.0,
    'iaq_good_higher': 80.0,
    'iaq_min_warning': 60.0,
  };
}
