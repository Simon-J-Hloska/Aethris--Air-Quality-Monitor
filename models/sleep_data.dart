class SleepData {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final double qualityScore; // 0-100
  final SleepQuality quality;
  final List<SleepStage>? stages;

  SleepData({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.qualityScore,
    required this.quality,
    this.stages,
  });

  // Factory konstruktor z JSON (z API hodinek)
  factory SleepData.fromJson(Map<String, dynamic> json) {
    return SleepData(
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      durationMinutes: json['durationMinutes'] as int,
      qualityScore: (json['qualityScore'] as num).toDouble(),
      quality: SleepQuality.fromScore(json['qualityScore'] as num),
      stages: json['stages'] != null
          ? (json['stages'] as List).map((s) => SleepStage.fromJson(s)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'qualityScore': qualityScore,
      'quality': quality.name,
      'stages': stages?.map((s) => s.toJson()).toList(),
    };
  }

  // Formátovaná délka spánku
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  // Je spánek dostatečně dlouhý? (min 6 hodin)
  bool get isSufficientDuration {
    return durationMinutes >= 360;
  }
}

// Enum pro kvalitu spánku
enum SleepQuality {
  excellent,
  good,
  fair,
  poor;

  static SleepQuality fromScore(num score) {
    if (score >= 85) return SleepQuality.excellent;
    if (score >= 70) return SleepQuality.good;
    if (score >= 50) return SleepQuality.fair;
    return SleepQuality.poor;
  }

  String get displayName {
    switch (this) {
      case SleepQuality.excellent:
        return 'Výborný';
      case SleepQuality.good:
        return 'Dobrý';
      case SleepQuality.fair:
        return 'Průměrný';
      case SleepQuality.poor:
        return 'Špatný';
    }
  }
}

// Model pro fáze spánku
class SleepStage {
  final String stage; // 'deep', 'light', 'rem', 'awake'
  final int durationMinutes;

  SleepStage({required this.stage, required this.durationMinutes});

  factory SleepStage.fromJson(Map<String, dynamic> json) {
    return SleepStage(
      stage: json['stage'] as String,
      durationMinutes: json['durationMinutes'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'stage': stage, 'durationMinutes': durationMinutes};
  }
}

// Model pro vyhodnocení vlivu prostředí na spánek
class SleepEnvironmentImpact {
  final SleepData sleepData;
  final double avgCo2;
  final double avgTemperature;
  final double avgHumidity;
  final ImpactLevel co2Impact;
  final ImpactLevel temperatureImpact;
  final ImpactLevel humidityImpact;
  final String positiveFeedback;
  final String problem;
  final String recommendation;

  SleepEnvironmentImpact({
    required this.sleepData,
    required this.avgCo2,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.co2Impact,
    required this.temperatureImpact,
    required this.humidityImpact,
    required this.positiveFeedback,
    required this.problem,
    required this.recommendation,
  });

  // Celkový vliv prostředí
  ImpactLevel get overallImpact {
    final impacts = [co2Impact, temperatureImpact, humidityImpact];
    if (impacts.any((i) => i == ImpactLevel.negative)) {
      return ImpactLevel.negative;
    }
    if (impacts.any((i) => i == ImpactLevel.neutral)) {
      return ImpactLevel.neutral;
    }
    return ImpactLevel.positive;
  }

  String get overallImpactText {
    switch (overallImpact) {
      case ImpactLevel.positive:
        return 'Kvalita vzduchu měla pozitivní vliv na váš spánek';
      case ImpactLevel.neutral:
        return 'Kvalita vzduchu byla neutrální';
      case ImpactLevel.negative:
        return 'Kvalita vzduchu měla negativní vliv na váš spánek';
    }
  }

  // Feedback sandwich formát
  String get feedbackSandwich {
    return '$positiveFeedback\n\n$problem\n\n$recommendation';
  }
}

// Enum pro úroveň vlivu
enum ImpactLevel {
  positive,
  neutral,
  negative;

  String get displayName {
    switch (this) {
      case ImpactLevel.positive:
        return 'Pozitivní';
      case ImpactLevel.neutral:
        return 'Neutrální';
      case ImpactLevel.negative:
        return 'Negativní';
    }
  }
}

// Model pro nastavení spánkového okna
class SleepWindow {
  final TimeOfDay bedTime;
  final TimeOfDay wakeTime;

  SleepWindow({required this.bedTime, required this.wakeTime});

  factory SleepWindow.defaultWindow() {
    return SleepWindow(
      bedTime: const TimeOfDay(hour: 21, minute: 00),
      wakeTime: const TimeOfDay(hour: 8, minute: 00),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bedTime': {'hour': bedTime.hour, 'minute': bedTime.minute},
      'wakeTime': {'hour': wakeTime.hour, 'minute': wakeTime.minute},
    };
  }

  factory SleepWindow.fromJson(Map<String, dynamic> json) {
    return SleepWindow(
      bedTime: TimeOfDay(
        hour: json['bedTime']['hour'] as int,
        minute: json['bedTime']['minute'] as int,
      ),
      wakeTime: TimeOfDay(
        hour: json['wakeTime']['hour'] as int,
        minute: json['wakeTime']['minute'] as int,
      ),
    );
  }

  String get formattedBedTime {
    return '${bedTime.hour.toString().padLeft(2, '0')}:${bedTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedWakeTime {
    return '${wakeTime.hour.toString().padLeft(2, '0')}:${wakeTime.minute.toString().padLeft(2, '0')}';
  }
}

// TimeOfDay helper pro JSON
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});
}
