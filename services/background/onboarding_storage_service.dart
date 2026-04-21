import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStorage {
  static const String _keySetupComplete = 'setup_complete';
  static const String _keyUserName = 'username';
  static const String _keyUserGender = 'gender';
  static const String _keyEspIp = 'esp_ip';
  static const String _keyEspPort = 'esp_port';

  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySetupComplete) ?? false;
  }

  static Future<void> saveSetupComplete({
    required String username,
    required String gender,
    required String esp_ip,
    required int esp_port,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySetupComplete, true);
    await prefs.setString(_keyUserName, username);
    await prefs.setString(_keyUserGender, gender);
    await prefs.setString(_keyEspIp, esp_ip);
    await prefs.setInt(_keyEspPort, esp_port);
  }

  static Future<Map<String, dynamic>?> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keySetupComplete) ?? false)) return null;

    return {
      'username': prefs.getString(_keyUserName),
      'gender': prefs.getString(_keyUserGender),
      'esp_ip': prefs.getString(_keyEspIp),
      'esp_port': prefs.getInt(_keyEspPort) ?? 80,
      'refresh_interval': prefs.getInt('refresh_interval') ?? 40,
      'chatbot_enabled': prefs.getBool('chatbot_enabled') ?? true,
      'notifications_enabled': prefs.getBool('notifications_enabled') ?? false,
    };
  }

  static Future<void> clearSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
