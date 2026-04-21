import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/sensor_data.dart';
import '../config/app_config.dart';

class SensorDetailScreen extends StatefulWidget {
  final String sensorType;
  const SensorDetailScreen({super.key, required this.sensorType});

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: _iconDuration(widget.sensorType),
    )..repeat(reverse: _iconReverses(widget.sensorType));
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  Duration _iconDuration(String type) => switch (type) {
        'co2' => const Duration(seconds: 3),
        'temperature' => const Duration(seconds: 4),
        'humidity' => const Duration(seconds: 2),
        'iaq' => const Duration(seconds: 5),
        _ => const Duration(seconds: 3),
      };

  bool _iconReverses(String type) => switch (type) {
        'temperature' => true,
        'humidity' => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getSensorTitle()),
        leading: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back),
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final data = appState.currentSensorData;
          final stats = appState.sensorStats;

          if (data == null) {
            return const Center(child: Text('Žádná data k dispozici'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(AppConfig.instance.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentValueCard(context, data),
                const SizedBox(height: 20),
                _buildMinMaxCard(context, stats),
                const SizedBox(height: 20),
                _buildDescriptionCard(context),
                const SizedBox(height: 20),
                _buildRecommendationsCard(context, data),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Current value ─────────────────────────────────────────────────────────

  Widget _buildCurrentValueCard(BuildContext context, SensorData data) {
    final value = _getCurrentValue(data);
    final unit = _getUnit();
    final quality = _getQuality(data);
    final color = _qualityColor(quality);
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(AppConfig.instance.cardBorderRadius),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _AnimatedSensorIcon(
              sensorType: widget.sensorType,
              color: color,
              animation: _iconController,
            ),
            const SizedBox(height: 20),
            Text(
              'Aktuální hodnota',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 22,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                quality.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Naposledy aktualizováno: ${_formatTime(DateTime.now())}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Min / Max ─────────────────────────────────────────────────────────────

  Widget _buildMinMaxCard(BuildContext context, SensorStats stats) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(AppConfig.instance.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Minima / Maxima',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _showResetDialog(context),
                  tooltip: 'Resetovat',
                ),
              ],
            ),
            Divider(height: 24, color: theme.dividerColor),
            Row(
              children: [
                Expanded(
                  child: _buildMinMaxItem(
                    context,
                    label: 'Minimum',
                    value: _getMinValue(stats),
                    unit: _getUnit(),
                    icon: Icons.arrow_downward,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMinMaxItem(
                    context,
                    label: 'Maximum',
                    value: _getMaxValue(stats),
                    unit: _getUnit(),
                    icon: Icons.arrow_upward,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinMaxItem(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────

  Widget _buildDescriptionCard(BuildContext context) {
    final theme = Theme.of(context);
    final description =
        AppConfig.instance.sensorDescriptions[widget.sensorType] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(AppConfig.instance.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'O tomto parametru',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: theme.dividerColor),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recommendations ───────────────────────────────────────────────────────

  Widget _buildRecommendationsCard(BuildContext context, SensorData data) {
    final recs = _getRecommendations(data);
    if (recs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(0xFFFFF8E1);
    final iconColor = isDark ? Colors.amber[300]! : Colors.orange[700]!;
    final titleColor = isDark ? Colors.amber[200]! : Colors.orange[900]!;
    final borderColor = isDark ? Colors.amber[700]! : Colors.orange[200]!;

    return Card(
      elevation: 2,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(AppConfig.instance.cardBorderRadius),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  'Doporučení',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: borderColor),
            ...recs.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20, color: iconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rec,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reset dialog ──────────────────────────────────────────────────────────

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetovat statistiky'),
        content: const Text(
          'Opravdu chcete resetovat minimální a maximální hodnoty?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().resetStatistics();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Statistiky resetovány')),
              );
            },
            child: const Text('Resetovat'),
          ),
        ],
      ),
    );
  }

  // ── Value helpers ─────────────────────────────────────────────────────────

  String _getSensorTitle() => switch (widget.sensorType) {
        'co2' => 'CO₂',
        'temperature' => 'Teplota',
        'humidity' => 'Vlhkost',
        'pressure' => 'Tlak',
        'iaq' => 'Index kvality vzduchu',
        _ => 'Detail senzoru',
      };

  String _getCurrentValue(SensorData data) => switch (widget.sensorType) {
        'co2' => data.co2.toString(),
        'temperature' => data.temperature.toStringAsFixed(1),
        'humidity' => data.humidity.toStringAsFixed(0),
        'pressure' => data.pressure.toStringAsFixed(0),
        'iaq' => data.iaq.toStringAsFixed(0),
        _ => '—',
      };

  String _getUnit() => switch (widget.sensorType) {
        'co2' => 'ppm',
        'temperature' => '°C',
        'humidity' => '%',
        'pressure' => 'hPa',
        'iaq' => '/ 100',
        _ => '',
      };

  SensorQuality _getQuality(SensorData data) => switch (widget.sensorType) {
        'co2' => data.co2Quality(),
        'temperature' => data.temperatureQuality(),
        'humidity' => data.humidityQuality(),
        'iaq' => data.iaqQuality(),
        _ => SensorQuality.good,
      };

  String _getMinValue(SensorStats stats) => switch (widget.sensorType) {
        'co2' => stats.minCo2.toString(),
        'temperature' => stats.minTemperature.toStringAsFixed(1),
        'humidity' => stats.minHumidity.toStringAsFixed(0),
        'pressure' => stats.minPressure.toStringAsFixed(0),
        'iaq' => stats.miniaq.toStringAsFixed(0),
        _ => '—',
      };

  String _getMaxValue(SensorStats stats) => switch (widget.sensorType) {
        'co2' => stats.maxCo2.toString(),
        'temperature' => stats.maxTemperature.toStringAsFixed(1),
        'humidity' => stats.maxHumidity.toStringAsFixed(0),
        'pressure' => stats.maxPressure.toStringAsFixed(0),
        'iaq' => stats.maxiaq.toStringAsFixed(0),
        _ => '—',
      };

  Color _qualityColor(SensorQuality quality) => switch (quality) {
        SensorQuality.good => Color(AppConfig.instance.qualityColors['good']!),
        SensorQuality.warning =>
          Color(AppConfig.instance.qualityColors['warning']!),
        SensorQuality.critical =>
          Color(AppConfig.instance.qualityColors['critical']!),
      };

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Recommendations (threshold-aware, Czech) ──────────────────────────────

  List<String> _getRecommendations(SensorData data) {
    final t = ThresholdProvider(WorkflowManager()).thresholds;
    return switch (widget.sensorType) {
      'co2' => _co2Recs(data.co2, t),
      'temperature' => _tempRecs(data.temperature, t),
      'humidity' => _humidityRecs(data.humidity, t),
      'iaq' => _iaqRecs(data.iaq, t),
      _ => [],
    };
  }

  List<String> _co2Recs(int co2, Map<String, double> t) {
    if (co2 <= t['co2_max_good']!) return [];
    if (co2 <= t['co2_max_warning']!) {
      return [
        'Otevřete okno alespoň na 10–15 minut — svěží vzduch rychle sníží hodnotu CO₂.',
        'Nechte dveře otevřené, aby vzduch mohl proudit celým bytem.',
        'Přidejte pokojové rostliny jako pothos nebo sansevérii — přirozeně čistí vzduch.',
      ];
    }
    return [
      'Okamžitě vyvětrejte — otevřete okna dokořán a vytvořte průvan.',
      'Omezte otevřený oheň v místnosti (svíčky, krb) — spalování zvyšuje CO₂.',
      'Při vaření používejte digestoř a otevřete okno — vaření na plynu trojnásobí CO₂.',
      'Zvažte instalaci rekuperační jednotky (HRV/ERV) pro trvalé větrání bez tepelných ztrát.',
      'Vyjděte ven na čerstvý vzduch, pokud pociťujete únavu nebo bolest hlavy.',
    ];
  }

  List<String> _tempRecs(double temp, Map<String, double> t) {
    if (temp >= t['temp_min_good']! && temp <= t['temp_max_good']!) return [];
    if (temp < t['temp_min_warning_low']!) {
      return [
        'Zvyšte vytápění nebo přidejte přenosný tepelný zářič.',
        'Zkontrolujte těsnost oken a dveří — průvanem může unikat velké množství tepla.',
        'Pro spánek přidejte deky — lepší než přetápět celou místnost.',
      ];
    }
    if (temp < t['temp_min_good']!) {
      return [
        'Trochu přitopte nebo přidejte vrstvu oblečení.',
        'Uzavřete žaluzie nebo záclony v noci — sklo je největší zdroj tepelných ztrát.',
      ];
    }
    if (temp > t['temp_max_warning_high']!) {
      return [
        'Zapněte klimatizaci nebo větrák — vysoká teplota narušuje spánek i koncentraci.',
        'Zavřete žaluzie a záclony přes den, aby sluneční záření neohřívalo místnost.',
        'Vyvětrejte brzy ráno nebo pozdě večer, kdy je venku chladněji.',
        'Na lůžko použijte lehčí, prodyšné povlečení z bavlny nebo lnu.',
      ];
    }
    return [
      'Mírně snižte vytápění nebo otevřete okno.',
      'Zapněte stropní ventilátor — pohyb vzduchu ochlazuje bez snížení teploty.',
    ];
  }

  List<String> _humidityRecs(double humidity, Map<String, double> t) {
    if (humidity >= t['humidity_min_good']! &&
        humidity <= t['humidity_max_good']!) {
      return [];
    }
    if (humidity < t['humidity_min_warning_low']!) {
      return [
        'Pořiďte zvlhčovač vzduchu — nejrychlejší a nejúčinnější řešení sucha.',
        'Rozložte mokrý ručník nebo prádlo na sušák — odpaří se a zvlhčí vzduch.',
        'Umístěte misky s vodou na radiátor — teplo způsobí odpařování.',
        'Přidejte pokojové rostliny s velkými listy (palmy, fíkus) — přirozeně vypařují vodu.',
        'Při sprchování nechte dveře pootevřené — vlhkost se rozptýlí do dalších místností.',
      ];
    }
    if (humidity < t['humidity_min_good']!) {
      return [
        'Nechte přirozeně vyschnout prádlo v místnosti místo v sušičce.',
        'Přidejte rostliny nebo misku s vodou na radiátor.',
      ];
    }
    if (humidity > t['humidity_max_warning_high']!) {
      return [
        'Zapněte odvlhčovač vzduchu nebo klimatizaci — nadměrná vlhkost podporuje plísně.',
        'Vyvětrejte, pokud je venku méně vlhko než uvnitř.',
        'Při vaření a sprchování vždy zapněte digestoř a ventilátor.',
        'Zkraťte sprchy a snižte jejich teplotu — horká pára výrazně zvyšuje vlhkost.',
        'Přesuňte část pokojových rostlin jinam — také přispívají k vlhkosti.',
        'Zkontrolujte, zda někde nekapou trubky nebo nevnikla voda do zdí.',
      ];
    }
    return [
      'Vyvětrejte alespoň 10 minut — pohyb vzduchu odvede nadbytečnou vlhkost.',
      'Zapněte ventilátor v koupelně nebo kuchyni.',
    ];
  }

  List<String> _iaqRecs(int iaq, Map<String, double> t) {
    if (iaq >= t['iaq_good_higher']!) return [];
    if (iaq >= t['iaq_min_warning']!) {
      return [
        'Přepněte na přírodní čisticí prostředky (ocet, jedlá soda) — syntetické chemikálie jsou hlavní zdroj VOC.',
        'Vyvětrejte místnost — čerstvý vzduch ředí chemické látky ve vzduchu.',
        'Svíčky a vonné tyčinky vypouštějí VOC — omezte jejich používání nebo otevřete okno.',
        'Nové předměty (nábytek, koberce) nechte nejprve odvětrat venku nebo v garáži.',
      ];
    }
    return [
      'Okamžitě vyvětrejte — hodnoty ukazují na výrazné znečištění vzduchu.',
      'Najděte zdroj: čerstvě natřená stěna, nový nábytek, čisticí přípravky nebo osvěžovač vzduchu.',
      'Pořiďte čističku vzduchu s aktivním uhlím — jedině ta zachytí VOC a plyny (HEPA nestačí).',
      'Nekuřte v místnosti — cigaretový kouř obsahuje stovky škodlivých látek.',
      'Nepoužívejte aerosolové spreje v uzavřené místnosti.',
      'Nechte místnost vyvětrat přes noc s otevřeným oknem, pokud to teplota dovolí.',
    ];
  }
}

// ── Animated sensor icon ──────────────────────────────────────────────────────

class _AnimatedSensorIcon extends StatelessWidget {
  const _AnimatedSensorIcon({
    required this.sensorType,
    required this.color,
    required this.animation,
  });

  final String sensorType;
  final Color color;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => switch (sensorType) {
        'co2' => _co2Icon(),
        'temperature' => _tempIcon(),
        'humidity' => _humidityIcon(),
        'iaq' => _iaqIcon(),
        _ => Icon(Icons.sensors, size: 72, color: color),
      },
    );
  }

  // Pulses like breathing — sine wave scale
  Widget _co2Icon() {
    final scale = 0.9 + 0.1 * sin(animation.value * 2 * pi);
    return Transform.scale(
      scale: scale,
      child: Icon(Icons.air, size: 72, color: color),
    );
  }

  // Color shifts between cool blue and warm red
  Widget _tempIcon() {
    final t = animation.value;
    final shiftedColor = Color.lerp(Colors.blue[300], Colors.red[400], t)!;
    return Icon(Icons.thermostat, size: 72, color: shiftedColor);
  }

  // Bobs up and down like a water drop falling
  Widget _humidityIcon() {
    final offset = -4.0 + 8.0 * sin(animation.value * pi);
    return Transform.translate(
      offset: Offset(0, offset),
      child: Icon(Icons.water_drop, size: 72, color: color),
    );
  }

  // Slow full rotation like a radar sweep
  Widget _iaqIcon() {
    return Transform.rotate(
      angle: animation.value * 2 * pi,
      child: Icon(Icons.radar, size: 72, color: color),
    );
  }
}
