import '../models/sensor_data.dart';
import '../config/app_config.dart';
import 'api/sensor_service.dart';

// ── ChatbotService ─────────────────────────────────────────────────────────────

class ChatbotService {
  final SensorService sensorService;

  // Conversation history for context-aware responses
  final List<_ConversationTurn> _history = [];

  // Last intent — enables follow-up detection
  ChatIntent? _lastIntent;

  ChatbotService({required this.sensorService});

  // ── Public entry point ───────────────────────────────────────────────────────

  Future<ChatbotResponse> processMessage(String message) async {
    final trimmed = message.trim();
    final lower = trimmed.toLowerCase();

    // Record user turn
    _history.add(_ConversationTurn(role: 'user', text: trimmed));

    // Resolve intent — options/suggestions are mapped directly
    final intent = _resolveIntent(lower);

    // Generate response
    final response = await _dispatch(intent, lower);

    // Record assistant turn & update context
    _history.add(_ConversationTurn(role: 'assistant', text: response.message));
    _lastIntent = intent;

    return response;
  }

  // ── Intent resolution ────────────────────────────────────────────────────────

  ChatIntent _resolveIntent(String message) {
    // 1. Direct option matches (suggestions the bot itself offered)
    final optionMatch = _matchSuggestion(message);
    if (optionMatch != null) return optionMatch;

    // 2. Follow-up detection using previous context
    final followUp = _detectFollowUp(message);
    if (followUp != null) return followUp;

    // 3. Primary keyword matching
    return _detectPrimaryIntent(message);
  }

  /// Maps suggestion labels → intents (case-insensitive partial match)
  ChatIntent? _matchSuggestion(String message) {
    final suggestionMap = <String, ChatIntent>{
      'jaká je kvalita vzduchu': ChatIntent.airQualityStatus,
      'kvalita vzduchu': ChatIntent.airQualityStatus,
      'měl bych větrat': ChatIntent.shouldVentilate,
      'větrat': ChatIntent.shouldVentilate,
      'co můžu zlepšit': ChatIntent.improvement,
      'zlepšit': ChatIntent.improvement,
      'vliv na spánek': ChatIntent.sleepImpact,
      'spánek': ChatIntent.sleepImpact,
      'info o co₂': ChatIntent.sensorInfo,
      'co₂': ChatIntent.sensorInfoCo2,
      'co2': ChatIntent.sensorInfoCo2,
      'teplota': ChatIntent.sensorInfoTemp,
      'vlhkost': ChatIntent.sensorInfoHumidity,
      'tlak': ChatIntent.sensorInfoPressure,
      'iaq': ChatIntent.sensorInfoIaq,
      'připomenout': ChatIntent.reminder,
      'proč': ChatIntent.whyExplain,
      'co to znamená': ChatIntent.whyExplain,
      'jak to funguje': ChatIntent.howItWorks,
    };

    for (final entry in suggestionMap.entries) {
      if (message.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Detects short follow-ups like "proč?", "a co?", "díky" based on last intent
  ChatIntent? _detectFollowUp(String message) {
    final isShort = message.split(' ').length <= 3;
    if (!isShort || _lastIntent == null) return null;

    if (_containsAny(
        message, ['proč', 'jak to', 'co to', 'vysvětli', 'více'])) {
      return ChatIntent.whyExplain;
    }
    if (_containsAny(
        message, ['díky', 'děkuji', 'ok', 'super', 'jasně', 'rozumím'])) {
      return ChatIntent.acknowledge;
    }
    if (_containsAny(message, ['a co dál', 'co teď', 'co mám dělat'])) {
      return ChatIntent.nextStep;
    }
    return null;
  }

  ChatIntent _detectPrimaryIntent(String message) {
    // Greeting
    if (_containsAny(message, [
      'ahoj',
      'nazdar',
      'čau',
      'zdravím',
      'dobrý den',
      'dobrý ráno',
      'dobré ráno',
      'good morning',
      'hello',
      'hi',
      'hey',
    ])) {
      return ChatIntent.greeting;
    }

    // Ventilation
    if (_containsAny(message, [
      'větrat',
      'vyvětrat',
      'okno',
      'otevřít',
      'průvan',
      'čerstvý vzduch',
      'mám větrat',
      'potřebuji větrat',
    ])) {
      return ChatIntent.shouldVentilate;
    }

    // Sleep impact
    if (_containsAny(message, [
      'spánek',
      'spát',
      'spím',
      'noc',
      'odpočinek',
      'únava',
      'unavený',
      'ráno',
      'procitnutí',
      'vliv na spánek',
    ])) {
      return ChatIntent.sleepImpact;
    }

    // Improvement
    if (_containsAny(message, [
      'zlepšit',
      'zlepšení',
      'co mám',
      'co mohu',
      'co můžu',
      'udělat',
      'doporučení',
      'poraď',
      'pomoc',
      'rady',
      'tipy',
      'jak zlepšit',
    ])) {
      return ChatIntent.improvement;
    }

    // Specific sensor info
    if (message.contains('co2') ||
        message.contains('co₂') ||
        message.contains('oxid uhličitý')) {
      return ChatIntent.sensorInfoCo2;
    }
    if (_containsAny(
        message, ['teplota', 'teplot', 'teplo', 'zima', 'horko', 'stupně'])) {
      return ChatIntent.sensorInfoTemp;
    }
    if (_containsAny(
        message, ['vlhkost', 'vlhko', 'vlhký', 'suchý', 'sucho'])) {
      return ChatIntent.sensorInfoHumidity;
    }
    if (_containsAny(message, ['tlak', 'atmosférický', 'hpa', 'barometr'])) {
      return ChatIntent.sensorInfoPressure;
    }
    if (_containsAny(
        message, ['iaq', 'index kvality', 'znečišt', 'plyn', 'gas'])) {
      return ChatIntent.sensorInfoIaq;
    }

    // General sensor question
    if (_containsAny(
        message, ['senzor', 'měří', 'měřit', 'co sleduje', 'parametr'])) {
      return ChatIntent.sensorInfo;
    }

    // Air quality status
    if (_containsAny(message, [
      'jak',
      'jaká',
      'jaký',
      'kvalita',
      'stav',
      'vzduch',
      'teď',
      'nyní',
      'aktuální',
      'momentálně',
      'situace',
      'je v pořádku',
      'normální',
    ])) {
      return ChatIntent.airQualityStatus;
    }

    return ChatIntent.unknown;
  }

  // ── Dispatch ─────────────────────────────────────────────────────────────────

  Future<ChatbotResponse> _dispatch(ChatIntent intent, String message) async {
    switch (intent) {
      case ChatIntent.airQualityStatus:
        return await _handleAirQualityStatus();
      case ChatIntent.shouldVentilate:
        return await _handleShouldVentilate();
      case ChatIntent.improvement:
        return await _handleImprovement();
      case ChatIntent.sleepImpact:
        return await _handleSleepImpact();
      case ChatIntent.sensorInfo:
        return _handleSensorInfoGeneral();
      case ChatIntent.sensorInfoCo2:
        return _handleSensorDetail('co2');
      case ChatIntent.sensorInfoTemp:
        return _handleSensorDetail('temperature');
      case ChatIntent.sensorInfoHumidity:
        return _handleSensorDetail('humidity');
      case ChatIntent.sensorInfoPressure:
        return _handleSensorDetail('pressure');
      case ChatIntent.sensorInfoIaq:
        return _handleSensorDetail('iaq');
      case ChatIntent.greeting:
        return _handleGreeting();
      case ChatIntent.acknowledge:
        return _handleAcknowledge();
      case ChatIntent.nextStep:
        return await _handleNextStep();
      case ChatIntent.whyExplain:
        return await _handleWhyExplain();
      case ChatIntent.howItWorks:
        return _handleHowItWorks();
      case ChatIntent.reminder:
        return _handleReminder();
      case ChatIntent.unknown:
        return _handleUnknown(message);
    }
  }

  // ── Handlers ─────────────────────────────────────────────────────────────────

  Future<ChatbotResponse> _handleAirQualityStatus() async {
    final data = sensorService.currentData;

    if (data == null) {
      return ChatbotResponse(
        message:
            'Momentálně nemám data ze senzorů. Zkontroluj prosím připojení k zařízení ${AppConfig.instance.espName}.',
        suggestions: ['Zkontrolovat nastavení', 'Jak to funguje?'],
      );
    }

    final quality = data.overallQuality;
    final variants = <SensorQuality, List<String>>{
      SensorQuality.good: [
        'Vzduch je v pořádku! CO₂ na ${data.co2} ppm, teplota ${data.temperature.toStringAsFixed(1)}°C, vlhkost ${data.humidity.toStringAsFixed(0)}%.',
        'Skvělé zprávy — kvalita vzduchu je výborná. CO₂: ${data.co2} ppm, teplota: ${data.temperature.toStringAsFixed(1)}°C.',
        'Všechno vypadá dobře. Vzduch je čerstvý a podmínky jsou příjemné.',
      ],
      SensorQuality.warning: [
        'Vzduch by si zasloužil trochu pozornosti. ${_buildWarningDetail(data)}',
        'Kvalita vzduchu není ideální. ${_buildWarningDetail(data)}',
        'Vidím pár věcí, které by se daly zlepšit. ${_buildWarningDetail(data)}',
      ],
      SensorQuality.critical: [
        '⚠️ Vzduch je ve špatném stavu! ${_buildCriticalDetail(data)} Doporučuji jednat hned.',
        '⚠️ Pozor — kvalita vzduchu je kritická. ${_buildCriticalDetail(data)}',
      ],
    };

    final messages = variants[quality]!;
    final message = messages[DateTime.now().second % messages.length];

    return ChatbotResponse(
      message: message,
      suggestions: quality == SensorQuality.good
          ? ['Měl bych větrat?', 'Vliv na spánek', 'Jak to funguje?']
          : ['Měl bych větrat?', 'Co můžu zlepšit?', 'Proč je to špatně?'],
    );
  }

  String _buildWarningDetail(SensorData data) {
    final issues = <String>[];
    final t = ThresholdProvider(WorkflowManager()).thresholds;
    if (data.co2 > (t['co2_max_good'] ?? 800)) {
      issues.add('CO₂ je trochu vyšší (${data.co2} ppm)');
    }
    if (data.temperature > (t['temp_max_good'] ?? 24)) {
      issues.add('teplota je vyšší (${data.temperature.toStringAsFixed(1)}°C)');
    }
    if (data.temperature < (t['temp_min_good'] ?? 18)) {
      issues.add('teplota je nižší (${data.temperature.toStringAsFixed(1)}°C)');
    }
    if (data.humidity > (t['humidity_max_good'] ?? 65)) {
      issues.add('vlhkost je vyšší (${data.humidity.toStringAsFixed(0)}%)');
    }
    if (data.humidity < (t['humidity_min_good'] ?? 35)) {
      issues.add('vlhkost je nižší (${data.humidity.toStringAsFixed(0)}%)');
    }
    return issues.isEmpty
        ? 'Hodnoty jsou mírně mimo ideál.'
        : '${issues.join(', ').capitalize()}.';
  }

  String _buildCriticalDetail(SensorData data) {
    final issues = <String>[];
    final t = ThresholdProvider(WorkflowManager()).thresholds;
    if (data.co2 > (t['co2_max_warning'] ?? 1400)) {
      issues.add('CO₂ je velmi vysoké (${data.co2} ppm) — okamžitě vyvětrej');
    }
    if (data.temperature > (t['temp_max_warning_high'] ?? 27)) {
      issues.add(
          'teplota je příliš vysoká (${data.temperature.toStringAsFixed(1)}°C)');
    }
    if (data.humidity > (t['humidity_max_warning_high'] ?? 75)) {
      issues.add(
          'vlhkost je příliš vysoká (${data.humidity.toStringAsFixed(0)}%)');
    }
    return issues.isEmpty
        ? 'Více parametrů je mimo bezpečné rozmezí.'
        : '${issues.join('. ').capitalize()}.';
  }

  Future<ChatbotResponse> _handleShouldVentilate() async {
    final data = sensorService.currentData;

    if (data == null) {
      return const ChatbotResponse(
        message:
            'Nemám aktuální data — nedokážu posoudit, jestli větrat. Zkontroluj připojení.',
        suggestions: ['Jaká je kvalita vzduchu?'],
      );
    }

    final t = ThresholdProvider(WorkflowManager()).thresholds;
    final co2Warning = t['co2_max_warning'] ?? 1400;
    final co2Good = t['co2_max_good'] ?? 800;

    if (data.co2 >= co2Warning) {
      return ChatbotResponse(
        message:
            'Ano, určitě větrej! CO₂ je na ${data.co2} ppm — to je hodně. Otevři okno aspoň na 10 minut, ideálně dokořán.',
        suggestions: [
          'Připomenout za 10 minut',
          'Jak ovlivňuje CO₂ zdraví?',
          'Jaká je kvalita vzduchu?'
        ],
      );
    } else if (data.co2 >= co2Good) {
      return ChatbotResponse(
        message:
            'Doporučil bych vyvětrat. CO₂ je na ${data.co2} ppm — mírně zvýšené. Stačí 5–10 minut s otevřeným oknem.',
        suggestions: [
          'Co můžu zlepšit?',
          'Jaká je kvalita vzduchu?',
          'Vliv na spánek'
        ],
      );
    } else {
      return ChatbotResponse(
        message:
            'Teď větrat nemusíš. CO₂ je na přijatelné hodnotě ${data.co2} ppm. Za hodinu nebo dvě se podívám znovu.',
        suggestions: [
          'Jaká je kvalita vzduchu?',
          'Vliv na spánek',
          'Co můžu zlepšit?'
        ],
      );
    }
  }

  Future<ChatbotResponse> _handleImprovement() async {
    final evaluation = sensorService.evaluateAirQuality();
    final recommendations = evaluation['recommendations'] as List<String>;

    if (recommendations.isEmpty) {
      return const ChatbotResponse(
        message:
            'Upřímně — teď není co řešit. Vzduch je v dobré kondici. Jen ho tak nech!',
        suggestions: [
          'Jaká je kvalita vzduchu?',
          'Vliv na spánek',
          'Jak to funguje?'
        ],
      );
    }

    final intro = recommendations.length == 1
        ? 'Mám pro tebe jedno doporučení:'
        : 'Mám pro tebe ${recommendations.length} tipy:';

    final body = recommendations
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return ChatbotResponse(
      message: '$intro\n\n$body',
      suggestions: [
        'Měl bych větrat?',
        'Jaká je kvalita vzduchu?',
        'Proč je to špatně?'
      ],
    );
  }

  Future<ChatbotResponse> _handleSleepImpact() async {
    final data = sensorService.currentData;

    if (data == null) {
      return const ChatbotResponse(
        message:
            'Nemám aktuální data. Pro posouzení vlivu na spánek potřebuji hodnoty ze senzorů.',
        suggestions: ['Jaká je kvalita vzduchu?'],
      );
    }

    final issues = <String>[];
    final tips = <String>[];

    // CO2 sleep check
    if (data.co2 > 800) {
      issues.add(
          'CO₂ (${data.co2} ppm) může způsobovat přerušovaný spánek a ranní únavu');
      tips.add('Vyvětrej před spaním aspoň 10 minut');
    }

    // Temperature sleep check (ideal sleep temp 17–20°C)
    if (data.temperature > 21) {
      issues.add(
          'Teplota ${data.temperature.toStringAsFixed(1)}°C je na spánek trochu vysoká');
      tips.add('Ideální teplota pro spánek je 17–20°C');
    } else if (data.temperature < 16) {
      issues.add(
          'Teplota ${data.temperature.toStringAsFixed(1)}°C může být na spánek příliš chladná');
      tips.add('Zkus vytápět pokoj na aspoň 17°C před spaním');
    }

    // Humidity sleep check
    if (data.humidity < 35) {
      issues.add(
          'Nízká vlhkost (${data.humidity.toStringAsFixed(0)}%) může vysušovat dýchací cesty');
      tips.add('Zvažte použití zvlhčovače vzduchu');
    }

    if (issues.isEmpty) {
      return ChatbotResponse(
        message:
            'Podmínky pro spánek jsou teď příznivé. CO₂ ${data.co2} ppm, teplota ${data.temperature.toStringAsFixed(1)}°C — měl by ses dobře vyspat!',
        suggestions: ['Jaká je kvalita vzduchu?', 'Měl bych větrat?'],
      );
    }

    final message = 'Pár věcí by mohlo narušit spánek:\n\n'
        '${issues.map((i) => '• $i').join('\n')}\n\n'
        'Co s tím:\n${tips.map((t) => '• $t').join('\n')}';

    return ChatbotResponse(
      message: message,
      suggestions: [
        'Měl bych větrat?',
        'Co můžu zlepšit?',
        'Jaká je kvalita vzduchu?'
      ],
    );
  }

  ChatbotResponse _handleSensorInfoGeneral() {
    return const ChatbotResponse(
      message:
          'Sleduji čtyři parametry vzduchu: CO₂ (oxid uhličitý), teplotu, vlhkost a atmosferický tlak. Každý z nich ovlivňuje, jak se cítíš. O kterém chceš vědět víc?',
      suggestions: ['CO₂', 'Teplota', 'Vlhkost', 'Tlak', 'IAQ'],
    );
  }

  ChatbotResponse _handleSensorDetail(String sensor) {
    final desc = AppConfig.instance.sensorDescriptions[sensor];
    if (desc == null) {
      return _handleSensorInfoGeneral();
    }

    final followUps = <String, List<String>>{
      'co2': ['Měl bych větrat?', 'Vliv na spánek', 'Jaká je kvalita vzduchu?'],
      'temperature': [
        'Vliv na spánek',
        'Co můžu zlepšit?',
        'Jaká je kvalita vzduchu?'
      ],
      'humidity': [
        'Vliv na spánek',
        'Co můžu zlepšit?',
        'Jaká je kvalita vzduchu?'
      ],
      'pressure': ['Jaká je kvalita vzduchu?', 'Jak to funguje?'],
      'iaq': ['Jaká je kvalita vzduchu?', 'Co můžu zlepšit?'],
    };

    return ChatbotResponse(
      message: desc,
      suggestions: followUps[sensor] ?? ['Jaká je kvalita vzduchu?'],
    );
  }

  ChatbotResponse _handleGreeting() {
    final greetings = AppConfig.instance.getChatbotGreetings();
    final message = greetings[DateTime.now().millisecond % greetings.length];

    return ChatbotResponse(
      message: message,
      suggestions: [
        'Jaká je kvalita vzduchu?',
        'Měl bych větrat?',
        'Vliv na spánek',
        'Co můžu zlepšit?',
      ],
    );
  }

  ChatbotResponse _handleAcknowledge() {
    final responses = [
      'Rádo se stalo! Kdyby bylo cokoliv, jsem tady.',
      'Super! Dej vědět, když budeš potřebovat.',
      'Dobře! Monitoruji vzduch dál.',
      'V pohodě! Kdykoli se zeptej.',
    ];
    final message = responses[DateTime.now().millisecond % responses.length];

    return ChatbotResponse(
      message: message,
      suggestions: ['Jaká je kvalita vzduchu?', 'Měl bych větrat?'],
    );
  }

  Future<ChatbotResponse> _handleNextStep() async {
    // Suggest the most relevant action based on last intent + current data
    if (_lastIntent == ChatIntent.shouldVentilate ||
        _lastIntent == ChatIntent.airQualityStatus) {
      return await _handleImprovement();
    }
    return const ChatbotResponse(
      message: 'Nejlepší další krok je zkontrolovat aktuální kvalitu vzduchu.',
      suggestions: ['Jaká je kvalita vzduchu?', 'Co můžu zlepšit?'],
    );
  }

  Future<ChatbotResponse> _handleWhyExplain() async {
    switch (_lastIntent) {
      case ChatIntent.shouldVentilate:
        return const ChatbotResponse(
          message:
              'Větrání je důležité, protože vydechujeme CO₂. V uzavřené místnosti se hromadí — to způsobuje únavu, špatnou koncentraci a bolesti hlavy. Čerstvý vzduch pomáhá odvětrat CO₂ ven.',
          suggestions: [
            'Jak CO₂ ovlivňuje zdraví?',
            'Jaká je kvalita vzduchu?'
          ],
        );
      case ChatIntent.airQualityStatus:
        final data = sensorService.currentData;
        if (data != null && data.overallQuality != SensorQuality.good) {
          return await _handleImprovement();
        }
        return const ChatbotResponse(
          message:
              'Kvalita vzduchu závisí na více faktorech — CO₂, teplotě, vlhkosti i chemickém složení. Každý z nich ovlivňuje pohodu a zdraví.',
          suggestions: ['Co můžu zlepšit?', 'Jak to funguje?'],
        );
      default:
        return const ChatbotResponse(
          message:
              'Rád vysvětlím! Na co přesně se ptáš? Mohu popsat vliv CO₂, teploty, vlhkosti nebo celkového indexu kvality vzduchu.',
          suggestions: ['CO₂', 'Teplota', 'Vlhkost', 'IAQ'],
        );
    }
  }

  ChatbotResponse _handleHowItWorks() {
    return ChatbotResponse(
      message:
          'Zařízení ${AppConfig.instance.espName} nepřetržitě měří CO₂, teplotu, vlhkost a tlak. Data posílá do aplikace, kde je vyhodnocuji a dávám ti doporučení v reálném čase.',
      suggestions: ['Jaká je kvalita vzduchu?', 'Co měří CO₂?', 'Co je IAQ?'],
    );
  }

  ChatbotResponse _handleReminder() {
    return const ChatbotResponse(
      message:
          'Připomínky zatím neumím nastavit přímo z chatu — ale zkus mě znovu za chvíli, rád zkontroluju, jak se vzduch mezitím změnil.',
      suggestions: ['Jaká je kvalita vzduchu?', 'Měl bych větrat?'],
    );
  }

  ChatbotResponse _handleUnknown(String message) {
    // Try to guide based on any partial keyword match
    if (message.length > 3) {
      if (_containsAny(message, ['zdraví', 'nemoc', 'bolest', 'hlava'])) {
        return const ChatbotResponse(
          message:
              'Zní to, že tě zajímá vliv vzduchu na zdraví. Mohu ti říct víc o CO₂ nebo o tom, jak vzduch ovlivňuje spánek.',
          suggestions: [
            'Jak CO₂ ovlivňuje zdraví?',
            'Vliv na spánek',
            'Jaká je kvalita vzduchu?'
          ],
        );
      }
    }

    return const ChatbotResponse(
      message:
          'Přesně téhle otázce nerozumím. Zkus to jinak, nebo vyber z nabídky níže — tam najdeš všechno, s čím ti mohu pomoci.',
      suggestions: [
        'Jaká je kvalita vzduchu?',
        'Měl bych větrat?',
        'Co můžu zlepšit?',
        'Vliv na spánek',
      ],
    );
  }

  // ── Utilities ────────────────────────────────────────────────────────────────

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  /// Clear conversation history (e.g. on new session)
  void resetConversation() {
    _history.clear();
    _lastIntent = null;
  }
}

// ── Supporting models ─────────────────────────────────────────────────────────

class ChatbotResponse {
  final String message;
  final List<String> suggestions;

  const ChatbotResponse({
    required this.message,
    this.suggestions = const [],
  });
}

class _ConversationTurn {
  final String role; // 'user' | 'assistant'
  final String text;
  _ConversationTurn({required this.role, required this.text});
}

// ── Intent enum ───────────────────────────────────────────────────────────────

enum ChatIntent {
  airQualityStatus,
  shouldVentilate,
  improvement,
  sleepImpact,
  sensorInfo,
  sensorInfoCo2,
  sensorInfoTemp,
  sensorInfoHumidity,
  sensorInfoPressure,
  sensorInfoIaq,
  greeting,
  acknowledge,
  nextStep,
  whyExplain,
  howItWorks,
  reminder,
  unknown,
}

// ── String extension ──────────────────────────────────────────────────────────

extension _StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
