import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class StorageService {
  static const String _keyToken = 'jwt_token';
  static const String _keyUser = 'cached_user';
  static const String _keyDeepgramKey = 'custom_deepgram_key';
  static const String _keyPerformanceMode = 'performance_mode';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyUser);
    if (str != null && str.isNotEmpty) {
      try {
        return UserModel.fromJson(jsonDecode(str));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  static Future<void> saveDeepgramKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeepgramKey, key);
  }

  static Future<String?> getDeepgramKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeepgramKey);
  }

  static const String _keyServerUrl = 'custom_server_url';
  static const String _keyLanguage = 'app_language';

  static Future<bool> getPerformanceMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPerformanceMode) ?? false;
  }

  static Future<void> setPerformanceMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPerformanceMode, enabled);
  }

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url.trim().isEmpty) {
      await prefs.remove(_keyServerUrl);
    } else {
      await prefs.setString(_keyServerUrl, url.trim());
    }
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'ru';
  }

  static Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, langCode);
  }
}
