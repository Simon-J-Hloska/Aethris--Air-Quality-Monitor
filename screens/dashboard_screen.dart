import 'package:air_quality_app/config/app_themes.dart';
import 'package:air_quality_app/widgets/WindSwayWrapper.dart';
import 'package:air_quality_app/widgets/type_writer_text.dart';
import 'package:air_quality_app/widgets/workflow_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/sensor_data.dart';
import '../config/app_config.dart';
import 'sensor_detail_screen.dart';
import 'chatbot_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final WindController _wind = WindController();
  late AnimationController _leavesController;

  @override
  void initState() {
    super.initState();
    _leavesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _wind.leavesController = _leavesController;
    _wind.start();
  }

  @override
  void dispose() {
    _wind.dispose();
    _leavesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aethris měřič vzduchu'),
        automaticallyImplyLeading: false, // ← Removes back arrow
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AppState>().refreshData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading && appState.currentSensorData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!appState.isOnline) {
            return _buildOfflineView(context, appState);
          }

          if (appState.currentSensorData == null) {
            return _buildNoDataView(context);
          }

          return RefreshIndicator(
            onRefresh: () => appState.refreshData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppConfig.instance.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionStatus(appState, context),
                  const SizedBox(height: 50),
                  _buildOverallQualityCard(
                      context, appState.currentSensorData!),
                  const SizedBox(height: 30),
                  _buildSensorGrid(context, appState.currentSensorData!),
                  const SizedBox(height: 30),
                  const WorkflowCard(),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AppSettings>(
        builder: (context, settings, _) => settings.isChatbotEnabled
            ? FloatingActionButton(
                backgroundColor: const Color(0xFF1B5E20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                ),
                child: CustomPaint(
                  painter: WoodChopPainter(),
                  child: const SizedBox(width: 64, height: 64),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildConnectionStatus(AppState appState, BuildContext context) {
    final bgColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).scaffoldBackgroundColor;

    return Container(
      // <-- adds empty space below
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: appState.isOnline ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              appState.isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: appState.isOnline ? Colors.green : Colors.red,
              size: 30,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            appState.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: appState.isOnline ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallQualityCard(BuildContext context, SensorData data) {
    final username = AppConfig.instance.userVocative;
    return TypewriterText(
      text: "Ahoj $username",
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }

  Widget _buildSensorGrid(BuildContext context, SensorData data) {
    final cards = [
      (
        title: 'IAQ',
        value: data.iaq.toStringAsFixed(0),
        unit: '/ 100',
        icon: Icons.waves,
        quality: data.iaqQuality(),
        type: 'iaq'
      ),
      (
        title: 'Teplota',
        value: data.temperature.toStringAsFixed(1),
        unit: '°C',
        icon: Icons.thermostat,
        quality: data.temperatureQuality(),
        type: 'temperature'
      ),
      (
        title: 'CO₂',
        value: '${data.co2}',
        unit: 'ppm',
        icon: Icons.air,
        quality: data.co2Quality(),
        type: 'co2'
      ),
      (
        title: 'Vlhkost',
        value: data.humidity.toStringAsFixed(0),
        unit: '%',
        icon: Icons.water_drop,
        quality: data.humidityQuality(),
        type: 'humidity'
      ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: cards.indexed.map((entry) {
            final (i, card) = entry;
            return WindSwayCard(
              index: i,
              windStream: _wind.stream,
              child: _buildSensorCard(
                context,
                title: card.title,
                value: card.value,
                unit: card.unit,
                icon: card.icon,
                quality: card.quality,
                sensorType: card.type,
              ),
            );
          }).toList(),
        ),
        // Leaves overlay on top of the grid
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _leavesController,
              builder: (_, __) => CustomPaint(
                painter: LeavesPainter(progress: _leavesController.value),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSensorCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required SensorQuality quality,
    required String sensorType,
  }) {
    final color = _getQualityColor(quality);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SensorDetailScreen(sensorType: sensorType),
          ),
        );
      },
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppConfig.instance.cardBorderRadius),
          side: BorderSide(color: color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quality.displayName,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppThemes.getTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppThemes.getTextColor(context),
                          ),
                        ),
                        TextSpan(
                          text: ' $unit',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppThemes.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineView(BuildContext context, AppState appState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: AppThemes.getTextColor(context),
            ),
            const SizedBox(height: 24),
            Text('Offline', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Nepodařilo se připojit k ESP zařízení',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppThemes.getTextColor(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => appState.refreshData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Zkusit znovu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline,
              size: 64, color: AppThemes.getTextColor(context)),
          const SizedBox(height: 16),
          Text(
            'Žádná data k dispozici',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(SensorQuality quality) {
    switch (quality) {
      case SensorQuality.good:
        return Color(AppConfig.instance.qualityColors['good']!);
      case SensorQuality.warning:
        return Color(AppConfig.instance.qualityColors['warning']!);
      case SensorQuality.critical:
        return Color(AppConfig.instance.qualityColors['critical']!);
    }
  }
}

class WoodChopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Updated to the 'Creamy Wood Core' color
    final paint = Paint()
      ..color = const Color(0xFFF5ECD7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 2), width: 28, height: 22),
        const Radius.circular(6),
      ))
      ..moveTo(cx - 6, cy + 9)
      ..lineTo(cx - 12, cy + 17)
      ..lineTo(cx, cy + 9)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
