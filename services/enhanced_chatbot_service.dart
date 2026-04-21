import 'dart:math';
import '../models/sensor_data.dart';
import '../models/connection_status.dart';
import '../config/app_config.dart';
import 'api/sensor_service.dart';

class EnhancedChatbotService {
  final SensorService sensorService;
  final String userName;
  final String userVocative;

  // Varianty odpovědí pro rozmanitost
  final _random = Random();

  EnhancedChatbotService({
    required this.sensorService,
    required this.userName,
    required this.userVocative,
  });

  // Zpracování zprávy s kontextem
  Future<ChatbotResponse> processMessage(String message) async {
    final lowerMessage = message.toLowerCase().trim();
    final intent = _detectIntent(lowerMessage);

    // Kontextové informace
    final context = ChatContext(
      currentSensorData: sensorService.currentData,
      sensorStats: sensorService.stats,
      connectionStatus: sensorService.isOnline
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected,
      userName: userName,
      userVocative: userVocative,
    );

    return await _generateResponse(intent, context, lowerMessage);
  }

  ChatIntent _detectIntent(String message) {
    // ESP stav
    if (_containsAny(message, [
      'připojeno',
      'připojen',
      'online',
      'offline',
      'funguje',
      'nefunguje',
      'zařízení'
    ])) {
      return ChatIntent.deviceStatus;
    }

    // Aktuální stav
    if (_containsAny(message, [
      'jak',
      'jaká',
      'jaký',
      'kvalita',
      'stav',
      'teď',
      'nyní',
      'aktuální'
    ])) {
      return ChatIntent.airQualityStatus;
    }

    // Větrání
    if (_containsAny(message, ['větrat', 'vyvětrat', 'okno', 'otevřít'])) {
      return ChatIntent.shouldVentilate;
    }

    // Spánek
    if (_containsAny(
        message, ['spánek', 'spal', 'spala', 'v noci', 'během noci'])) {
      return ChatIntent.sleepImpact;
    }

    // Notifikace
    if (_containsAny(message, ['notifikace', 'upozornění', 'přišla', 'proč'])) {
      return ChatIntent.notificationExplanation;
    }

    // Doporučení
    if (_containsAny(message, ['zlepšit', 'co', 'můžu', 'udělat', 'poraď'])) {
      return ChatIntent.improvement;
    }

    // Info o parametrech
    if (_containsAny(
        message, ['co2', 'teplota', 'vlhkost', 'tlak', 'znamená', 'co je'])) {
      return ChatIntent.sensorInfo;
    }

    // Min/Max hodnoty
    if (_containsAny(message,
        ['minimum', 'maximum', 'nejnižší', 'nejvyšší', 'statistiky'])) {
      return ChatIntent.statistics;
    }

    // Pozdrav
    if (_containsAny(
        message, ['ahoj', 'nazdar', 'čau', 'dobrý den', 'zdravím', 'jak se'])) {
      return ChatIntent.greeting;
    }

    return ChatIntent.unknown;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  Future<ChatbotResponse> _generateResponse(
    ChatIntent intent,
    ChatContext context,
    String originalMessage,
  ) async {
    switch (intent) {
      case ChatIntent.deviceStatus:
        return _handleDeviceStatus(context);

      case ChatIntent.airQualityStatus:
        return _handleAirQualityStatus(context);

      case ChatIntent.shouldVentilate:
        return _handleShouldVentilate(context);

      case ChatIntent.sleepImpact:
        return await _handleSleepImpact(context);

      case ChatIntent.notificationExplanation:
        return _handleNotificationExplanation(context);

      case ChatIntent.improvement:
        return _handleImprovement(context);

      case ChatIntent.sensorInfo:
        return _handleSensorInfo(context, originalMessage);

      case ChatIntent.statistics:
        return _handleStatistics(context);

      case ChatIntent.greeting:
        return _handleGreeting(context);

      case ChatIntent.unknown:
        return _handleUnknown(context);
    }
  }

  // Handler: Stav zařízení
  ChatbotResponse _handleDeviceStatus(ChatContext context) {
    if (context.connectionStatus == ConnectionStatus.connected) {
      final responses = [
        'Zařízení je připojené a funguje správně!',
        'ESP je online a sbírá data. Vše běží bez problémů!',
        'Super, ${context.userVocative}! Zařízení je připravené a měří.',
      ];

      return ChatbotResponse(
        message: _pickRandom(responses),
        suggestions: ['Jaká je kvalita vzduchu?', 'Min/max hodnoty'],
      );
    } else {
      return ChatbotResponse(
        message: 'Bohužel zařízení není připojeno. Zkontroluj prosím '
            'připojení ESP k WiFi a ujisti se, že je zapnuté.',
        suggestions: ['Jak to vyřešit?', 'Nastavení'],
      );
    }
  }

  // Handler: Aktuální kvalita (s personalizací)
  ChatbotResponse _handleAirQualityStatus(ChatContext context) {
    final data = context.currentSensorData;

    if (data == null) {
      return ChatbotResponse(
        message:
            'Momentálně nemám k dispozici data ze senzorů, ${context.userVocative}.',
        suggestions: ['Je zařízení připojeno?', 'Zkusit znovu'],
      );
    }

    final quality = data.overallQuality;
    String response = '';

    switch (quality) {
      case SensorQuality.good:
        final greetings = [
          'Skvělé zprávy, ${context.userVocative}! ',
          'Výborně, ${context.userVocative}! ',
          'Super, ${context.userVocative}! ',
        ];
        response = _pickRandom(greetings);
        response += 'Kvalita vzduchu je ideální. ';
        response +=
            'CO₂: ${data.co2} ppm, Teplota: ${data.temperature.toStringAsFixed(1)}°C, ';
        response += 'Vlhkost: ${data.humidity.toStringAsFixed(0)}%.';
        break;

      case SensorQuality.warning:
        response =
            'Kvalita vzduchu vyžaduje pozornost, ${context.userVocative}. ';
        if (data.co2 >= AppConfig.instance.co2GoodThreshold) {
          response += 'CO₂ je trochu zvýšené (${data.co2} ppm). ';
        }
        response += 'Doporučuji provést úpravy.';
        break;

      case SensorQuality.critical:
        response = '⚠️ ${context.userName}, kvalita vzduchu je kritická! ';
        if (data.co2 >= AppConfig.instance.co2WarningThreshold) {
          response += 'CO₂ je příliš vysoké (${data.co2} ppm). ';
        }
        response += 'Jednej prosím co nejdříve!';
        break;
    }

    return ChatbotResponse(
      message: response,
      suggestions: ['Měl bych větrat?', 'Co můžu zlepšit?'],
    );
  }

  // Handler: Měl bych větrat? (více variant)
  ChatbotResponse _handleShouldVentilate(ChatContext context) {
    final data = context.currentSensorData;

    if (data == null) {
      return ChatbotResponse(
        message: 'Nemám aktuální data, ${context.userVocative}.',
        suggestions: [],
      );
    }

    if (data.co2 >= AppConfig.instance.co2WarningThreshold) {
      final urgentResponses = [
        'Ano, rozhodně! CO₂ je velmi vysoké (${data.co2} ppm). Otevři okna a vyvětrej alespoň 10 minut!',
        '${context.userName}, okamžitě vyvětrej! CO₂ dosáhlo ${data.co2} ppm, což je hodně.',
        'Určitě ano! Vzduch je teď opravdu špatný (CO₂: ${data.co2} ppm). Větrání by mělo být priorita!',
      ];

      return ChatbotResponse(
        message: _pickRandom(urgentResponses),
        suggestions: ['Připomenout za 10 minut', 'Jaká je kvalita pak?'],
      );
    } else if (data.co2 >= AppConfig.instance.co2GoodThreshold) {
      return ChatbotResponse(
        message: 'Doporučuji to, ${context.userVocative}. CO₂ je mírně zvýšené '
            '(${data.co2} ppm). Stačí 5-10 minut.',
        suggestions: ['Jaká je kvalita vzduchu?', 'Co můžu zlepšit?'],
      );
    } else {
      final goodResponses = [
        'Momentálně to není nutné. CO₂ je na dobré úrovni (${data.co2} ppm).',
        'Ne, zatím ne. Vzduch je v pohodě! CO₂: ${data.co2} ppm.',
        'Nemusíš, ${context.userVocative}. Hodnoty jsou dobré.',
      ];

      return ChatbotResponse(
        message: _pickRandom(goodResponses),
        suggestions: ['Kdy bych měl větrat?', 'Vliv na spánek'],
      );
    }
  }

  // Handler: Statistiky
  ChatbotResponse _handleStatistics(ChatContext context) {
    final stats = context.sensorStats;

    if (stats.maxCo2 == 0) {
      return ChatbotResponse(
        message:
            'Zatím nemám dostatek dat pro statistiky, ${context.userVocative}.',
        suggestions: [],
      );
    }

    final response = 'Zde jsou naměřené extrémy:\n\n'
        '📊 CO₂: ${stats.minCo2} - ${stats.maxCo2} ppm\n'
        '🌡️ Teplota: ${stats.minTemperature.toStringAsFixed(1)} - ${stats.maxTemperature.toStringAsFixed(1)}°C\n'
        '💧 Vlhkost: ${stats.minHumidity.toStringAsFixed(0)} - ${stats.maxHumidity.toStringAsFixed(0)}%';

    return ChatbotResponse(
      message: response,
      suggestions: ['Resetovat statistiky', 'Jaká je kvalita teď?'],
    );
  }

  // Handler: Vysvětlení notifikace
  ChatbotResponse _handleNotificationExplanation(ChatContext context) {
    final data = context.currentSensorData;

    if (data == null) {
      return ChatbotResponse(
        message: 'Momentálně nemám data, abych vysvětlil upozornění.',
        suggestions: [],
      );
    }

    String explanation = 'Upozornění přišlo, protože ';

    if (data.co2 >= AppConfig.instance.co2WarningThreshold) {
      explanation += 'CO₂ překročilo kritickou hodnotu (${data.co2} ppm). '
          'To může způsobit únavu a horší soustředění.';
    } else if (data.humidity > AppConfig.instance.humidityMaxWarning) {
      explanation +=
          'vlhkost je příliš vysoká (${data.humidity.toStringAsFixed(0)}%). '
          'To podporuje růst plísní.';
    } else if (data.humidity < AppConfig.instance.humidityMinWarning) {
      explanation +=
          'vlhkost je příliš nízká (${data.humidity.toStringAsFixed(0)}%). '
          'To vysušuje sliznice.';
    } else {
      explanation =
          'Upozornění bylo spuštěno na základě vyhodnocení celkové kvality vzduchu.';
    }

    return ChatbotResponse(
      message: explanation,
      suggestions: ['Co mám udělat?', 'Měl bych větrat?'],
    );
  }

  // Handler: Vylepšené pozdravy podle času
  ChatbotResponse _handleGreeting(ChatContext context) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 10) {
      greeting = 'Dobré ráno, ${context.userVocative}! ☀️';
    } else if (hour < 18) {
      greeting = 'Ahoj, ${context.userVocative}! 👋';
    } else {
      greeting = 'Dobrý večer, ${context.userVocative}! 🌙';
    }

    final responses = [
      '$greeting Jak ti můžu pomoct s kvalitou vzduchu?',
      '$greeting Rád ti poradím ohledně prostředí!',
      '$greeting Jsem tu, abych ti pomohl s kvalitou vzduchu.',
    ];

    return ChatbotResponse(
      message: _pickRandom(responses),
      suggestions: [
        'Jaká je kvalita vzduchu?',
        'Měl bych větrat?',
        'Vliv na spánek',
      ],
    );
  }

  // Ostatní handlery... (převzaté z předchozího chatbot_service.dart)
  // Pro stručnost vynechány - použij existující implementace

  ChatbotResponse _handleSensorInfo(ChatContext context, String message) {
    // Implementace stejná jako v původním chatbot_service.dart
    return ChatbotResponse(message: 'Info o senzorech...', suggestions: []);
  }

  Future<ChatbotResponse> _handleSleepImpact(ChatContext context) async {
    // Implementace stejná jako v původním chatbot_service.dart
    return ChatbotResponse(message: 'Sleep impact...', suggestions: []);
  }

  ChatbotResponse _handleImprovement(ChatContext context) {
    // Implementace stejná jako v původním chatbot_service.dart
    return ChatbotResponse(message: 'Recommendations...', suggestions: []);
  }

  ChatbotResponse _handleUnknown(ChatContext context) {
    final responses = [
      'Omlouvám se, ${context.userVocative}, této otázce nerozumím.',
      'Hmm, nejsem si jistý, co myslíš. Můžeš se zeptat jinak?',
      'To bohužel nevím. Zkus se zeptat například na kvalitu vzduchu.',
    ];

    return ChatbotResponse(
      message: _pickRandom(responses),
      suggestions: [
        'Jaká je kvalita vzduchu?',
        'Měl bych větrat?',
        'Co můžu zlepšit?',
      ],
    );
  }

  String _pickRandom(List<String> options) {
    return options[_random.nextInt(options.length)];
  }
}

// Rozšířené intenty
enum ChatIntent {
  airQualityStatus,
  shouldVentilate,
  sleepImpact,
  improvement,
  sensorInfo,
  statistics,
  deviceStatus,
  notificationExplanation,
  greeting,
  unknown,
}

// Kontextový model
class ChatContext {
  final SensorData? currentSensorData;
  final SensorStats sensorStats;
  final ConnectionStatus connectionStatus;
  final String userName;
  final String userVocative;

  ChatContext({
    required this.currentSensorData,
    required this.sensorStats,
    required this.connectionStatus,
    required this.userName,
    required this.userVocative,
  });
}

// Response model (stejný jako předtím)
class ChatbotResponse {
  final String message;
  final List<String> suggestions;

  ChatbotResponse({
    required this.message,
    this.suggestions = const [],
  });
}
