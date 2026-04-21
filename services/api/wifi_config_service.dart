import 'dart:async';
import 'package:air_quality_app/config/app_config.dart';
import 'package:air_quality_app/services/api/Esp_discovery.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

enum ConfigurationStep {
  waiting,
  connectingToAP,
  apConnected,
  sendingWifiConfig,
  waitingForConnection,
  verifyingConnection,
  completed,
  failed,
}

class ConfigurationStatus {
  final ConfigurationStep step;
  final String message;
  final String? ipAddress;
  final String? errorMessage;

  ConfigurationStatus({
    required this.step,
    required this.message,
    this.ipAddress,
    this.errorMessage,
  });

  @override
  String toString() =>
      'ConfigurationStatus(step: $step, message: $message, ip: $ipAddress, error: $errorMessage)';
}

class WifiConfigService {
  static const String AP_SSID = "Aethris_Wifi_Setup";
  static const String AP_IP = "192.168.4.1";
  static const int SERVER_PORT = 80;
  static const Duration AP_CONNECTION_TIMEOUT = Duration(seconds: 45);
  static const Duration WIFI_VERIFICATION_DELAY = Duration(seconds: 2);
  static const int MAX_VERIFICATION_ATTEMPTS = 15;

  final Connectivity _connectivity = Connectivity();
  final AppSettings appSettings;
  late final ApiService _apiService;
  final EspDiscoveryService discovery = EspDiscoveryService();

  StreamController<ConfigurationStatus>? _statusController;
  Completer<void>? _continueCompleter;
  Stream<ConfigurationStatus> get statusStream {
    _statusController ??= StreamController<ConfigurationStatus>.broadcast();
    return _statusController!.stream;
  }

  bool _isDisposed = false;
  bool _isRunning = false;

  WifiConfigService({required this.appSettings}) {
    _apiService = ApiService(appSettings: appSettings);
  }

  String get baseUrl => 'http://$AP_IP:$SERVER_PORT';

  void _updateStatus(
    ConfigurationStep step,
    String message, {
    String? ipAddress,
    String? errorMessage,
  }) {
    if (_isDisposed ||
        _statusController == null ||
        _statusController!.isClosed) {
      print('[WifiConfig] WARNING: Cannot update status, controller disposed');
      return;
    }

    final status = ConfigurationStatus(
      step: step,
      message: message,
      ipAddress: ipAddress,
      errorMessage: errorMessage,
    );
    print('[WifiConfig] Status update: $status');

    try {
      _statusController!.add(status);
    } catch (e) {
      print('[WifiConfig] ERROR: Failed to add status: $e');
    }
  }

  void userPressedContinue() {
    print('[WifiConfig] User pressed continue');
    if (_continueCompleter != null && !_continueCompleter!.isCompleted) {
      _continueCompleter!.complete();
    }
  }

  /// Hlavní metoda pro spuštění konfigurace
  Future<bool> startConfiguration(String wifiSsid, String wifiPassword) async {
    if (_isRunning) {
      print('[WifiConfig] WARNING: Configuration already running');
      return false;
    }

    _isRunning = true;
    print('[WifiConfig] ===== Starting WiFi Configuration =====');
    print('[WifiConfig] Target SSID: $wifiSsid');
    print('[WifiConfig] ESP AP: $AP_SSID');
    print('[WifiConfig] ESP IP: $AP_IP:$SERVER_PORT');

    try {
      // Validace vstupních dat
      if (wifiSsid.trim().isEmpty) {
        _updateStatus(
          ConfigurationStep.failed,
          'Chybné zadání',
          errorMessage: 'SSID nemůže být prázdné',
        );
        print('[WifiConfig] ERROR: Empty SSID provided');
        return false;
      }

      if (wifiPassword.trim().isEmpty) {
        _updateStatus(
          ConfigurationStep.failed,
          'Chybné zadání',
          errorMessage: 'Heslo nemůže být prázdné',
        );
        print('[WifiConfig] ERROR: Empty password provided');
        return false;
      }

      // Krok 1: připojení k AP
      print('[WifiConfig] Step 1: user connecting to AP');
      _updateStatus(
        ConfigurationStep.connectingToAP,
        'Připojte se k wifi síti "$AP_SSID"\n\n'
        'Po připojení stiskněte "Pokračovat"',
      );
      _continueCompleter = Completer<void>();
      await _continueCompleter!.future;
      _continueCompleter = null;

      // Krok 2: Test spojení s ESP
      print('[WifiConfig] Step 2: Testing ESP connection');
      _updateStatus(
        ConfigurationStep.apConnected,
        'Testování připojení k ESP...',
      );

      bool connected = await _testConnection();
      if (!connected) {
        _updateStatus(
          ConfigurationStep.failed,
          'Nepodařilo se připojit k ESP',
          errorMessage: 'ESP neodpovídá na /ping endpoint na adrese $AP_IP.\n\n'
              'Zkontrolujte:\n'
              '1. Že jste připojeni k WiFi "$AP_SSID"\n'
              '2. Že ESP běží a AP je aktivní\n'
              '3. Že můžete otevřít http://$AP_IP v prohlížeči',
        );
        print('[WifiConfig] ERROR: ESP not responding to ping');
        return false;
      }

      print('[WifiConfig] ESP ping successful');

      // Krok 3: Odeslání WiFi konfigurace
      print('[WifiConfig] Step 3: Starting UDP discovery');
      _updateStatus(
        ConfigurationStep.sendingWifiConfig,
        'Odesílám WiFi konfiguraci...',
      );

      await discovery.start();

      final configResult = await _sendWifiConfig(wifiSsid, wifiPassword);
      if (configResult == null) {
        _updateStatus(
          ConfigurationStep.failed,
          'Nepodařilo se odeslat WiFi konfiguraci',
          errorMessage:
              'Chyba při odesílání. ESP nepotvrdilo přijetí konfigurace.',
        );
        discovery.stop();
        print('[WifiConfig] ERROR: Failed to send WiFi config');
        return false;
      }

      late String espIp;
      try {
        espIp = await discovery.ipStream.first.timeout(
          const Duration(seconds: 25),
        );
        if (espIp.isEmpty) {
          throw Exception('Empty IP received');
        }

        print('[WifiConfig] ESP reported IP: $espIp');
        appSettings.espIpAddress = espIp;
      } on TimeoutException {
        discovery.stop();
        _updateStatus(
          ConfigurationStep.failed,
          'Časový limit vypršel',
          errorMessage: 'ESP neodpovědělo do 25 sekund.',
        );
        return false;
      } catch (e) {
        // Handle AP_MODE or other errors
        if (e.toString().contains('AP_MODE') ||
            e.toString().contains('Empty IP')) {
          _updateStatus(
            ConfigurationStep.failed,
            'Připojení k WiFi selhalo',
            errorMessage: 'ESP se nepřipojilo k síti. Zkontrolujte heslo.',
          );
          return false;
        }
        rethrow;
      } finally {
        discovery.stop();
      }

      print('[WifiConfig] ESP connected successfully! IP: $espIp');

      // Krok 4: Čekání na připojení ESP k WiFi
      print('[WifiConfig] Step 4: Waiting for ESP to connect to WiFi');
      _updateStatus(
        ConfigurationStep.waitingForConnection,
        'ESP se připojuje k WiFi "$wifiSsid"...\n\n'
        'Tento proces může trvat až 20 sekund.\n'
        'ESP se restartuje a připojuje k vaší síti.',
      );

      // Krok 5: Ověření připojení
      print('[WifiConfig] Step 5: Verifying WiFi connection');
      _updateStatus(
        ConfigurationStep.verifyingConnection,
        'Ověřuji připojení ESP k WiFi...',
      );

      final check = await _verifyWifiConnection(espIp);
      if (check == null || check.isEmpty) {
        _updateStatus(
          ConfigurationStep.failed,
          'ESP se nepodařilo připojit k WiFi',
          errorMessage:
              'ESP se nepřipojilo k síti "$wifiSsid" ani po $MAX_VERIFICATION_ATTEMPTS pokusech.\n\n'
              'Možné příčiny:\n'
              '1. Nesprávné heslo WiFi\n'
              '2. Síť "$wifiSsid" není v dosahu ESP\n'
              '3. ESP nemůže získat IP adresu z DHCP\n'
              '4. Problém s WiFi modulem ESP',
        );
        print('[WifiConfig] ERROR: ESP failed to connect to WiFi');
        return false;
      }

      print('[WifiConfig] ESP connected successfully! IP: $espIp');
      appSettings.espIpAddress = espIp;

      _updateStatus(
        ConfigurationStep.completed,
        'Konfigurace úspěšně dokončena!\n\n'
        'ESP je připojeno k síti "$wifiSsid"\n'
        'IP adresa: $espIp\n\n'
        'Nyní se můžete připojit zpět k vaší běžné WiFi síti.',
        ipAddress: espIp,
      );

      print('[WifiConfig] ===== Configuration Completed Successfully =====');
      return true;
    } catch (e, stackTrace) {
      print('[WifiConfig] FATAL ERROR: $e');
      print('[WifiConfig] Stack trace: $stackTrace');

      if (!_isDisposed) {
        _updateStatus(
          ConfigurationStep.failed,
          'Neočekávaná chyba',
          errorMessage: 'Došlo k neočekávané chybě: ${e.toString()}',
        );
      }
      return false;
    } finally {
      _isRunning = false;
      print('[WifiConfig] Configuration process finished');
    }
  }

  Future<bool> ensureLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      return true;
    }

    final result = await Permission.locationWhenInUse.request();
    return result.isGranted;
  }

  /// Test připojení k ESP
  Future<bool> _testConnection() async {
    print('[WifiConfig] Testing connection to ESP at $baseUrl/ping');
    try {
      final connected = await _apiService.testConnection();
      print('[WifiConfig] Ping result: $connected');
      return connected;
    } catch (e) {
      print('[WifiConfig] Ping failed with exception: $e');
      return false;
    }
  }

  /// Odeslání WiFi konfigurace
  Future<Map<String, dynamic>?> _sendWifiConfig(
      String ssid, String password) async {
    print('[WifiConfig] Sending WiFi config to ESP');
    print('[WifiConfig] SSID: $ssid');

    try {
      final result = await _apiService.sendWifiConfig(ssid, password);

      print('[WifiConfig] WiFi config result: $result');
      return result;
    } catch (e) {
      print('[WifiConfig] Failed to send WiFi config: $e');
      return null;
    }
  }

  /// Ověření WiFi připojení a získání IP adresy
  Future<String?> _verifyWifiConnection(espIp) async {
    print('[WifiConfig] Verifying ESP WiFi connection');

    appSettings.espIpAddress = espIp;
    const int maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        if (connectivityResult == ConnectivityResult.wifi) {
          print('[WifiConfig] Attempt $attempt: device IP = $espIp');

          final connected = await _apiService.testConnection();
          if (connected) {
            print('[WifiConfig] ESP reachable at $espIp');
            return espIp;
          }
        }
      } catch (e) {
        print('[WifiConfig] Verification attempt $attempt error: $e');
      }

      await Future.delayed(WIFI_VERIFICATION_DELAY);
    }

    print('[WifiConfig] Verification failed after $maxAttempts attempts');
    return null;
  }

  /// Ukončení streamu - volat pouze když už nebude service použit
  void dispose() {
    if (_isDisposed) {
      print('[WifiConfig] WARNING: Already disposed');
      return;
    }

    print('[WifiConfig] Disposing WifiConfigService');
    _isDisposed = true;

    // Počkáme malou chvíli, aby se dokončily případné poslední zprávy
    Future.delayed(const Duration(milliseconds: 100), () {
      _statusController?.close();
      _statusController = null;
    });
  }
}
