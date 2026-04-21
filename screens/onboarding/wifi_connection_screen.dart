import 'package:air_quality_app/services/background/onboarding_storage_service.dart';
import 'package:air_quality_app/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/api/wifi_config_service.dart';
import '../dashboard_screen.dart';
import '../../config/app_config.dart';

class WifiConnectionScreen extends StatefulWidget {
  final String wifiSsid;
  final String wifiPassword;

  const WifiConnectionScreen({
    super.key,
    required this.wifiSsid,
    required this.wifiPassword,
  });

  @override
  State<WifiConnectionScreen> createState() => _WifiConnectionScreenState();
}

class _WifiConnectionScreenState extends State<WifiConnectionScreen>
    with SingleTickerProviderStateMixin {
  late final WifiConfigService _wifiService;
  ConfigurationStep _currentStep = ConfigurationStep.waiting;
  String _statusMessage = 'Příprava...';
  String? _espIpAddress;
  String? _errorMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    final appState = context.read<AppState>();
    _wifiService = WifiConfigService(appSettings: appState.settings);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _startConfiguration();
  }

  Future<void> _startConfiguration() async {
    _wifiService.statusStream.listen((status) {
      setState(() {
        _currentStep = status.step;
        _statusMessage = status.message;
        _errorMessage = status.errorMessage;
        if (status.ipAddress != null) {
          _espIpAddress = status.ipAddress;
        }
      });

      if (status.step == ConfigurationStep.completed) {
        _animationController.stop();
        Future.delayed(const Duration(seconds: 2), _completeOnboarding);
      } else if (status.step == ConfigurationStep.failed) {
        _animationController.stop();
      }
    });

    await _wifiService.startConfiguration(
      widget.wifiSsid,
      widget.wifiPassword,
    );
  }

  void _completeOnboarding() async {
    if (_espIpAddress != null) {
      final appState = context.read<AppState>();
      await appState.updateEspIp(_espIpAddress!);

      await OnboardingStorage.saveSetupComplete(
        username: AppConfig.instance.userName,
        gender: AppConfig.instance.gender.toString(),
        esp_ip: _espIpAddress!,
        esp_port: WifiConfigService.SERVER_PORT,
      );

      await context.read<UserService>().completeOnboarding();
    }

    // Navigate regardless — if IP is null we still go to dashboard
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Připojení k ${AppConfig.instance.espName}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildStepProgress(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      _buildStatusAnimation(),
                      const SizedBox(height: 24),
                      Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildInstructions(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (_currentStep == ConfigurationStep.connectingToAP)
                ElevatedButton(
                  onPressed: () {
                    _wifiService
                        .userPressedContinue(); // ← Triggers the completer
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Pokračovat',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              else if (_currentStep == ConfigurationStep.completed)
                ElevatedButton(
                  onPressed: _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Dokončit nastavení',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              else if (_currentStep == ConfigurationStep.failed)
                OutlinedButton(
                  onPressed: () => _startConfiguration(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Zkusit znovu',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    final steps = [
      ConfigurationStep.connectingToAP,
      ConfigurationStep.sendingWifiConfig,
      ConfigurationStep.verifyingConnection,
      ConfigurationStep.completed,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isActive = _currentStep.index >= step.index;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (index < steps.length - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusAnimation() {
    if (_currentStep == ConfigurationStep.completed) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
          );
        },
      );
    }

    if (_currentStep == ConfigurationStep.failed) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline,
          size: 80,
          color: Colors.red,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _animationController.value * 2 * 3.14159,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    width: 4,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7 + (_animationController.value * 0.3),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStepIcon(),
                  size: 40,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getStepIcon() {
    switch (_currentStep) {
      case ConfigurationStep.connectingToAP:
        return Icons.wifi_find;
      case ConfigurationStep.apConnected:
        return Icons.wifi;
      case ConfigurationStep.sendingWifiConfig:
        return Icons.send;
      case ConfigurationStep.waitingForConnection:
        return Icons.hourglass_empty;
      case ConfigurationStep.verifyingConnection:
        return Icons.verified;
      default:
        return Icons.wifi;
    }
  }

  Widget _buildInstructions() {
    String instructions = '';
    Color bgColor = Theme.of(context).primaryColor.withValues(alpha: 0.1);

    switch (_currentStep) {
      case ConfigurationStep.waiting:
        instructions = 'Připravuji konfiguraci...';
        break;
      case ConfigurationStep.connectingToAP:
        instructions =
            '⚙ Přejděte do nastavení WiFi\nᯤ Připojte se k síti "${WifiConfigService.AP_SSID}"\n↩ Poté se vraťte zpět do aplikace.';
        bgColor = Colors.blue.withValues(alpha: 0.1);
        break;
      case ConfigurationStep.apConnected:
        instructions = '✓ Připojeno k ${AppConfig.instance.espName}.';
        bgColor = Colors.green.withValues(alpha: 0.1);
        break;
      case ConfigurationStep.sendingWifiConfig:
        instructions = 'komunikace s ${AppConfig.instance.espName}.';
        break;
      case ConfigurationStep.waitingForConnection:
        instructions =
            '${AppConfig.instance.espName} se připojuje k vaší WiFi,\nto může chvíli trvat...';
        bgColor = Colors.orange.withValues(alpha: 0.1);
        break;
      case ConfigurationStep.verifyingConnection:
        instructions = 'konfigurace ${AppConfig.instance.espName}.';
        break;
      case ConfigurationStep.completed:
        instructions =
            'Výborně! ${AppConfig.instance.espName} je připraven k použití.';
        bgColor = Colors.green.withValues(alpha: 0.1);
        break;
      case ConfigurationStep.failed:
        instructions = 'Něco se pokazilo\nZkuste to prosím znovu.';
        bgColor = Colors.red.withValues(alpha: 0.1);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Text(
        instructions,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _wifiService.dispose();
    super.dispose();
  }
}
