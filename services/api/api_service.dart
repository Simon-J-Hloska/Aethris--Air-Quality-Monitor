import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../models/sensor_data.dart';
import '../../config/app_config.dart';

class ApiService {
  final AppSettings appSettings;
  final Duration timeout = AppConfig.instance.connectionTimeout;

  ApiService({required this.appSettings});

  String get baseUrl =>
      'http://${appSettings.espIpAddress}:${appSettings.espPort}';

  // Test připojení k ESP
  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ping'));
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Získání aktuálních dat ze senzorů
  Future<SensorData> getSensorData() async {
    try {
      final now = DateTime.now();
      final timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final response = await http
          .post(
            Uri.parse('$baseUrl/sensors'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'time': timeString}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return SensorData.fromJson(jsonData);
      } else {
        throw ApiException(
          'Failed to load sensor data: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw ApiException('Connection timeout', 408);
    } catch (e) {
      throw ApiException('Network error: $e', 500);
    }
  }

  // Získání min/max hodnot z ESP
  Future<Map<String, dynamic>?> getMinMaxData() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/stats/minmax')).timeout(timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {"error": "Failed to get min/max data"};
    } catch (e) {
      print('Failed to get min/max data: $e');
      return null;
    }
  }

  // Reset min/max hodnot na ESP
  Future<bool> resetMinMax() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stats/minmax'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to reset min/max: $e');
      return false;
    }
  }

  // Zjištění verze health ESP
  Future<String?> getFirmwareVersion() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/health')).timeout(timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['version'] as String?;
      }
      return null;
    } catch (e) {
      print('Failed to get firmware version: $e');
      return null;
    }
  }

  // Zaslání wifi informací na ESP a získání nové IP
  Future<Map<String, dynamic>?> sendWifiConfig(
      String ssid, String password) async {
    try {
      final body = json.encode({'ssid': ssid, 'password': password});
      print('[DEBUG] Sending body: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/wifi'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('WiFi config response: $data');
        return {
          'status': data['status'],
          'message': data['message'],
        };
      }

      print('WiFi config failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Failed to send WiFi config: $e');
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  // zjištění zda je ESP připojeno k WiFi
  Future<bool> isWifiConnected() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/wifi/status')).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body)['connected'] as bool;
      } else {
        return false;
      }
    } catch (e) {
      print('Failed to get WiFi status: $e');
      return false;
    }
  }
}

// Custom exception pro API chyby
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
