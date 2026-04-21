import 'dart:convert';

import 'package:air_quality_app/config/app_config.dart';
import 'package:air_quality_app/models/user_profile.dart';
import 'package:air_quality_app/services/background/background_controller.dart';
import 'package:air_quality_app/services/background/onboarding_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'services/theme_service.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'config/app_themes.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> requestPermissions() async {
  await Permission.notification.request();
  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
  }
}

Future<void> syncTimeToEsp(String baseUrl) async {
  try {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await http.post(
      Uri.parse('$baseUrl/time'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'time': timeString, // "20:32"
      }),
    );
  } catch (e) {
    print('[Main] Chyba při synchronizaci času s ESP: $e');
  }
}

Future<Gender> genderFromString(String genderStr) async {
  switch (genderStr.toLowerCase()) {
    case 'male':
      return Gender.male;
    case 'female':
      return Gender.female;
    default:
      return Gender.other;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final savedConfig = await OnboardingStorage.loadSavedConfig();
  if (savedConfig != null) {
    print('[Main] Loaded saved ESP IP: ${savedConfig['esp_ip']}');
    AppSettings().espI = savedConfig['esp_ip'] as String? ?? '192.168.4.1';
    AppSettings().espP = savedConfig['esp_port'] as int? ?? 80;
    AppSettings().user_profile = UserProfile(
        name: savedConfig['username'],
        gender: await genderFromString(savedConfig['gender']));
    AppSettings().refreshInterval =
        Duration(seconds: savedConfig['refresh_interval'] as int? ?? 10);
    AppSettings().chatbotEnabled =
        savedConfig['chatbot_enabled'] as bool? ?? true;
    AppSettings().notificationsEnabled =
        savedConfig['notifications_enabled'] as bool? ?? false;
  }
  await requestPermissions();
  syncTimeToEsp(AppSettings().baseUrl)
      .timeout(const Duration(seconds: 2))
      .catchError((e) => print(e));
  // Inicializace služeb
  final themeService = ThemeService();
  final userService = UserService();
  final notificationService = NotificationService();

  await themeService.initialize();
  await userService.initialize();
  await notificationService.initialize();
  await initializeService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: userService),
        ChangeNotifierProvider.value(value: AppSettings.instance),
        ChangeNotifierProvider(
          create: (_) => AppState()..initialize(),
        ),
      ],
      child: const AirQualityApp(),
    ),
  );
}

class AirQualityApp extends StatelessWidget {
  const AirQualityApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeService>().themeMode;
    final isOnboarded = context.watch<UserService>().isOnboarded;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'Kvalita vzduchu',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        darkTheme: AppThemes.darkTheme,
        themeMode: themeMode,

        // WRAPPER pro všechny screens - vynutí portrait
        builder: (context, child) {
          return PortraitOnlyWrapper(child: child!);
        },

        home: isOnboarded ? const DashboardScreen() : const WelcomeScreen(),
      ),
    );
  }
}

// Wrapper widget který vynutí portrait
class PortraitOnlyWrapper extends StatelessWidget {
  final Widget child;

  const PortraitOnlyWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Vynutíme portrait orientaci při každém buildu
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return child;
  }
}

// Splash screen (volitelný)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Počkat na inicializaci všech services
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      final isOnboarded = context.read<UserService>().isOnboarded;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isOnboarded ? const DashboardScreen() : const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.air,
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Načítání...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
