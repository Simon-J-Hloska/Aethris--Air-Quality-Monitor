import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserService extends ChangeNotifier {
  static const String _userProfileKey = 'user_profile';
  static const String _keyIsOnboarded = 'is_onboarded_complete';

  UserProfile? _profile;
  bool _isOnboarded = false;
  bool _isInitialized = false;

  UserProfile? get profile => _profile;
  bool get isOnboarded => _isOnboarded;
  bool get hasProfile => _profile != null;
  bool get isInitialized => _isInitialized;

  // Inicializace - načte profil
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = prefs.getBool(_keyIsOnboarded) ?? false;
    final profileJson = prefs.getString(_userProfileKey);

    final savedIp =
        prefs.getString('esp_ip'); // Použij klíč, pod kterým ukládáš IP
    if (savedIp != null &&
        savedIp.isNotEmpty &&
        savedIp != '192.168.4.1' &&
        profileJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(profileJson);
        _profile = UserProfile.fromJson(json);
        print('[UserService] Loaded profile: ${_profile?.name}');
        _isOnboarded = true;
      } catch (e) {
        print('Failed to load user profile: $e');
        _isOnboarded = false;
      }
    }
    _isInitialized = true;

    print(
        '[UserService] Initialized: isOnboarded=$_isOnboarded, hasProfile=$hasProfile');
    notifyListeners();
  }

  /// Save profile (called during name/gender screen)
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
    print('[UserService] Profile saved: ${profile.name}');
  }

  /// Complete onboarding (called after WiFi setup succeeds)
  Future<void> completeOnboarding() async {
    _isOnboarded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsOnboarded, true);

    notifyListeners();
    print('[UserService] Onboarding marked complete');
  }

  // Aktualizace profilu
  Future<void> updateProfile(UserProfile profile) async {
    await saveProfile(profile);
  }

  Future<void> clearProfile() async {
    _profile = null;
    _isOnboarded = false;
    _isInitialized = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
    await prefs.remove(_keyIsOnboarded);
    print('[UserService] Profile cleared');
  }

  // Oslovení pro různé části aplikace
  String getGreeting() => _profile?.getGreeting() ?? 'Ahoj';
  String getShortGreeting() => _profile?.shortGreeting ?? 'Ahoj';
  String getVocative() => _profile?.vocative ?? 'uživateli';
}
