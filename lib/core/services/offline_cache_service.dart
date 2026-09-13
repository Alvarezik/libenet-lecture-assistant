import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/lecture_model.dart';

class OfflineCacheService {
  static const String _keyLecturesList = 'cached_offline_lectures_';
  static const String _prefixDetail = 'cached_lecture_detail_';

  static Future<void> saveLecturesList(int userId, List<LectureModel> lectures) async {
    if (userId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = lectures.map((l) => l.toJson()).toList();
      await prefs.setString('$_keyLecturesList$userId', jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<LectureModel>> getCachedLecturesList(int userId) async {
    if (userId <= 0) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_keyLecturesList$userId');
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => LectureModel.fromJson(e, fromCache: true)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveLectureDetail(int userId, LectureModel lecture) async {
    if (userId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefixDetail${userId}_${lecture.id}', jsonEncode(lecture.toJson()));
    } catch (_) {}
  }

  static Future<LectureModel?> getCachedLectureDetail(int userId, int lectureId) async {
    if (userId <= 0) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_prefixDetail${userId}_$lectureId');
      if (str != null && str.isNotEmpty) {
        return LectureModel.fromJson(jsonDecode(str), fromCache: true);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearUserCache(int userId) async {
    if (userId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyLecturesList$userId');
      final keys = prefs.getKeys().where((k) => k.startsWith('$_prefixDetail${userId}_'));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
