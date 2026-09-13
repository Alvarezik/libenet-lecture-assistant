import 'package:flutter/foundation.dart';
import 'offline_cache_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import '../constants/app_config.dart';
import 'storage_service.dart';
import '../../models/user_model.dart';
import '../../models/lecture_model.dart';
import '../../models/log_model.dart';
import '../../models/stats_model.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _longTimeout = Duration(minutes: 15);
  static VoidCallback? onUnauthorized;

  static void _checkAuthStatus(int statusCode) {
    if (statusCode == 401) {
      onUnauthorized?.call();
    }
  }

  static String _localizeError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('failed host lookup') || str.contains('network is unreachable')) {
      return 'Нет подключения к интернету. Проверьте соединение.';
    }
    if (str.contains('timeoutexception') || str.contains('timed out')) {
      return 'Время ожидания ответа сервера истекло. Попробуйте еще раз.';
    }
    if (str.contains('connection refused')) {
      return 'Сервер временно недоступен. Ведутся технические работы.';
    }
    if (str.contains('401') || str.contains('недействительный токен') || str.contains('токен истек')) {
      return 'Сессия истекла. Пожалуйста, выполните вход заново.';
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  static Map<String, String> _headers(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static bool? _cachedRegistrationEnabled;
  static bool? get cachedRegistrationEnabled => _cachedRegistrationEnabled;

  // Public Settings
  static Future<bool> isRegistrationEnabled() async {
    if (_cachedRegistrationEnabled != null) {
      _refreshRegistrationSettingInBackground();
      return _cachedRegistrationEnabled!;
    }
    try {
      final res = await http.get(Uri.parse(ApiConstants.publicSettings)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        _cachedRegistrationEnabled = data['registration_enabled'] ?? true;
        return _cachedRegistrationEnabled!;
      }
    } catch (_) {}
    return true;
  }

  static void _refreshRegistrationSettingInBackground() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.publicSettings)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        _cachedRegistrationEnabled = data['registration_enabled'] ?? true;
      }
    } catch (_) {}
  }

  // Auth
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.login),
        headers: _headers(null),
        body: jsonEncode({'username': username.trim(), 'password': password}),
      ).timeout(_timeout);
      
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        final token = data['token'];
        final user = UserModel.fromJson(data['user']);
        await StorageService.saveToken(token);
        await StorageService.saveUser(user);
        return {'success': true, 'user': user, 'token': token};
      } else {
        throw Exception(data['detail'] ?? 'Неверный логин или пароль');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password, String fullName) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.register),
        headers: _headers(null),
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
        }),
      ).timeout(_timeout);
      
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        final token = data['token'];
        final user = UserModel.fromJson(data['user']);
        await StorageService.saveToken(token);
        await StorageService.saveUser(user);
        return {'success': true, 'user': user, 'token': token};
      } else {
        throw Exception(data['detail'] ?? 'Ошибка регистрации нового аккаунта');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<UserModel?> getMe() async {
    final token = await StorageService.getToken();
    if (token == null) return null;
    try {
      final res = await http.get(Uri.parse(ApiConstants.me), headers: _headers(token)).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['user'] != null) {
          final user = UserModel.fromJson(data['user']);
          await StorageService.saveUser(user);
          return user;
        }
      }
    } catch (_) {}
    return null;
  }

  // Lectures (with automatic offline cache scoped to userId)
  static Future<List<LectureModel>> getLectures() async {
    final user = await StorageService.getUser();
    final userId = user?.id ?? 0;
    try {
      final token = await StorageService.getToken();
      final res = await http.get(Uri.parse(ApiConstants.lectures), headers: _headers(token)).timeout(_timeout);
      _checkAuthStatus(res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['lectures'] is List) {
          final list = (data['lectures'] as List)
              .map((e) => LectureModel.fromJson(e))
              .toList();
          if (userId > 0) {
            await OfflineCacheService.saveLecturesList(userId, list);
          }
          return list;
        }
      }
    } catch (_) {
      // Fallback to offline cache if no internet
      if (userId > 0) {
        final cached = await OfflineCacheService.getCachedLecturesList(userId);
        if (cached.isNotEmpty) {
          return cached;
        }
      }
    }
    if (userId > 0) {
      return await OfflineCacheService.getCachedLecturesList(userId);
    }
    return [];
  }

  static Future<int> createLecture({
    required String title,
    String subject = '',
    String teacherName = '',
    int durationSeconds = 0,
  }) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.lectures),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'subject': subject,
          'teacher_name': teacherName,
          'duration_seconds': durationSeconds,
        }),
      ).timeout(_timeout);
      _checkAuthStatus(res.statusCode);
      
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return data['lecture_id'];
      } else {
        throw Exception(data['detail'] ?? 'Не удалось создать запись лекции');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<LectureModel> getLectureDetail(int lectureId) async {
    final user = await StorageService.getUser();
    final userId = user?.id ?? 0;
    try {
      final token = await StorageService.getToken();
      final res = await http.get(Uri.parse(ApiConstants.lectureDetail(lectureId)), headers: _headers(token)).timeout(_timeout);
      _checkAuthStatus(res.statusCode);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        final model = LectureModel.fromJson(data['lecture']);
        if (userId > 0) {
          await OfflineCacheService.saveLectureDetail(userId, model);
        }
        return model;
      }
    } catch (_) {
      // Offline fallback
      if (userId > 0) {
        final cached = await OfflineCacheService.getCachedLectureDetail(userId, lectureId);
        if (cached != null) {
          return LectureModel.fromJson(cached.toJson(), fromCache: true);
        }
      }
    }
    if (userId > 0) {
      final cached = await OfflineCacheService.getCachedLectureDetail(userId, lectureId);
      if (cached != null) {
        return LectureModel.fromJson(cached.toJson(), fromCache: true);
      }
    }
    throw Exception('Нет подключения к интернету и лекция отсутствует в офлайн-памяти.');
  }

  static Future<void> deleteLecture(int lectureId) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.delete(Uri.parse(ApiConstants.lectureDetail(lectureId)), headers: _headers(token)).timeout(_timeout);
      _checkAuthStatus(res.statusCode);
      if (res.statusCode != 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(data['detail'] ?? 'Ошибка удаления лекции');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<String> uploadAudioFile(int lectureId, String filePath, int durationSeconds) async {
    try {
      final token = await StorageService.getToken();
      final uri = Uri.parse(ApiConstants.uploadAudio(lectureId));
      final request = http.MultipartRequest('POST', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.fields['duration_seconds'] = durationSeconds.toString();

      final ext = filePath.split('.').last.toLowerCase();
      String subType = 'm4a';
      if (ext == 'mp3') {
        subType = 'mpeg';
      } else if (ext == 'wav') {
        subType = 'wav';
      } else if (ext == 'ogg') {
        subType = 'ogg';
      } else if (ext == 'aac') {
        subType = 'aac';
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('audio', subType),
      ));

      final streamedRes = await request.send().timeout(_longTimeout);
      final res = await http.Response.fromStream(streamedRes);
      _checkAuthStatus(res.statusCode);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      
      if (res.statusCode == 200 && data['success'] == true) {
        return data['filename'];
      } else {
        throw Exception(data['detail'] ?? 'Ошибка передачи аудиозаписи на сервер');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<Map<String, dynamic>> transcribeLecture(
    int lectureId, {
    String language = 'ru',
    String engine = 'auto',
    String? localFilePath,
  }) async {
    // 1. Try server endpoint with multi-engine backend (180s timeout)
    try {
      final token = await StorageService.getToken();
      final url = '${ApiConstants.transcribe(lectureId)}?language=$language&engine=$engine';
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 180));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true) {
          return data;
        }
      } else {
        sendClientLog('SERVER_TRANSCRIBE_STATUS', 'WARN', 'Server status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      sendClientLog('TRANSCRIBE_SERVER_FAIL', 'WARN', 'Server transcribe failed: $e');
    }

    // 2. Direct client fallback if local file is present on device
    if (localFilePath != null && File(localFilePath).existsSync()) {
      sendClientLog('DIRECT_FALLBACK_START', 'INFO', 'Using direct fallback for lecture #$lectureId with engine $engine');
      if ((engine == 'gladia' || engine == 'auto') && AppConfig.hasDirectGladia) {
        try {
          return await _transcribeDirectGladia(lectureId, localFilePath, language: language);
        } catch (e) {
          sendClientLog('DIRECT_GLADIA_FAIL', 'WARN', 'Gladia fallback failed: $e');
        }
      }
      if (AppConfig.hasDirectDeepgram) {
        try {
          return await _transcribeDirectDeepgram(lectureId, localFilePath, language: language);
        } catch (e) {
          sendClientLog('DIRECT_DG_FAIL', 'WARN', 'Deepgram fallback failed: $e');
        }
      }
    }

    throw Exception('Не удалось выполнить распознавание речи. Попробуйте другой сервис в меню или повторите попытку.');
  }

  static Future<Map<String, dynamic>> _transcribeDirectGladia(
    int lectureId,
    String localFilePath, {
    String language = 'ru',
  }) async {
    final gladiaKey = AppConfig.gladiaApiKey;
    if (gladiaKey.isEmpty) {
      throw Exception('Прямой клиентский шлюз Gladia не настроен.');
    }
    final file = File(localFilePath);
    final audioBytes = await file.readAsBytes();

    // 1. Upload
    final upUri = Uri.parse('https://api.gladia.io/v2/upload');
    final request = http.MultipartRequest('POST', upUri)
      ..headers['x-gladia-key'] = gladiaKey
      ..files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'audio.m4a'));
    final streamedResponse = await request.send().timeout(const Duration(seconds: 90));
    final upRes = await http.Response.fromStream(streamedResponse);
    if (upRes.statusCode != 200) {
      throw Exception('Gladia upload error: ${upRes.statusCode}');
    }
    final audioUrl = jsonDecode(upRes.body)['audio_url'];

    // 2. Submit
    final subRes = await http.post(
      Uri.parse('https://api.gladia.io/v2/pre-recorded'),
      headers: {'x-gladia-key': gladiaKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'audio_url': audioUrl, 'audio_enhancer': true}),
    ).timeout(const Duration(seconds: 60));
    final resultUrl = jsonDecode(subRes.body)['result_url'];

    // 3. Poll
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final pollRes = await http.get(Uri.parse(resultUrl), headers: {'x-gladia-key': gladiaKey});
      final pData = jsonDecode(pollRes.body);
      final status = pData['status'];
      if (status == 'done') {
        final transcription = pData['result']?['transcription'] ?? {};
        final fullText = (transcription['full_transcript'] ?? '').toString().trim();
        final utterances = transcription['utterances'] as List? ?? [];
        final timed = <Map<String, dynamic>>[];
        for (final u in utterances) {
          final uStart = (u['start'] as num? ?? 0.0).toDouble();
          final m = (uStart ~/ 60).toString().padLeft(2, '0');
          final s = (uStart.toInt() % 60).toString().padLeft(2, '0');
          final text = (u['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            timed.add({'start': uStart, 'time': '$m:$s', 'text': text});
          }
        }
        await saveLectureTranscript(lectureId: lectureId, rawTranscript: fullText, timedTranscript: timed, language: language);
        return {'success': true, 'transcript': fullText, 'timed_transcript': timed, 'status': 'transcribed'};
      } else if (status == 'error') {
        throw Exception('Gladia returned error status');
      }
    }
    throw Exception('Gladia transcription timed out');
  }

  static Future<Map<String, dynamic>> _transcribeDirectDeepgram(
    int lectureId,
    String localFilePath, {
    String language = 'ru',
  }) async {
    final dgKey = AppConfig.deepgramApiKey;
    if (dgKey.isEmpty) {
      throw Exception('Прямой клиентский шлюз Deepgram не настроен.');
    }
    final file = File(localFilePath);
    final audioBytes = await file.readAsBytes();

    final url = 'https://api.deepgram.com/v1/listen?model=nova-2&language=$language&smart_format=true&punctuate=true&paragraphs=true&utterances=true';
    final res = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Token $dgKey',
        'Content-Type': 'audio/m4a',
      },
      body: audioBytes,
    ).timeout(const Duration(seconds: 300));

    if (res.statusCode != 200) {
      sendClientLog('DIRECT_DG_ERROR', 'ERROR', 'Deepgram returned ${res.statusCode}: ${res.body}');
      throw Exception('Ошибка Deepgram API (код ${res.statusCode})');
    }

    final dgJson = jsonDecode(utf8.decode(res.bodyBytes));
    final results = dgJson['results'] as Map<String, dynamic>? ?? {};
    final channels = results['channels'] as List? ?? [];

    String transcriptText = '';
    final timedSegments = <Map<String, dynamic>>[];

    if (channels.isNotEmpty) {
      final alt = (channels[0]['alternatives'] as List? ?? [{}])[0];
      final paragraphsData = alt['paragraphs']?['paragraphs'] as List? ?? [];
      final paras = <String>[];
      for (final p in paragraphsData) {
        final pStart = (p['start'] as num? ?? 0.0).toDouble();
        final m = (pStart ~/ 60).toString().padLeft(2, '0');
        final s = (pStart.toInt() % 60).toString().padLeft(2, '0');
        final timeStr = '$m:$s';
        final sentences = p['sentences'] as List? ?? [];
        final pText = sentences.map((sItem) => (sItem['text'] ?? '').toString().trim()).where((t) => t.isNotEmpty).join(' ');
        if (pText.isNotEmpty) {
          paras.add(pText);
          timedSegments.add({'start': pStart, 'time': timeStr, 'text': pText});
        }
      }
      if (paras.isNotEmpty) {
        transcriptText = paras.join('\n\n');
      }
      if (transcriptText.isEmpty) {
        transcriptText = alt['transcript'] ?? '';
      }
    }

    if (transcriptText.isEmpty) {
      transcriptText = 'В аудиозаписи не удалось обнаружить разборчивую речь.';
    }

    // Save to server database
    await saveLectureTranscript(
      lectureId: lectureId,
      rawTranscript: transcriptText,
      timedTranscript: timedSegments,
      language: language,
    );

    return {
      'success': true,
      'transcript': transcriptText,
      'timed_transcript': timedSegments,
      'status': 'transcribed',
    };
  }

  static Future<void> saveLectureTranscript({
    required int lectureId,
    required String rawTranscript,
    List<Map<String, dynamic>> timedTranscript = const [],
    String language = 'ru',
  }) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.saveTranscript(lectureId)),
        headers: _headers(token),
        body: jsonEncode({
          'raw_transcript': rawTranscript,
          'timed_transcript': timedTranscript,
          'detected_language': language,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        sendClientLog('SAVE_TRANSCRIPT_ERROR', 'WARN', 'Status: ${res.statusCode}');
      }
    } catch (e) {
      sendClientLog('SAVE_TRANSCRIPT_EXCEPTION', 'WARN', 'Exception: $e');
    }
  }

  static Future<Map<String, dynamic>> summarizeLecture(int lectureId) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.summarize(lectureId)),
        headers: _headers(token),
      ).timeout(_longTimeout);
      
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['detail'] ?? 'Ошибка генерации конспекта без воды');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  // Admin
  static Future<AdminStatsModel> getAdminStats() async {
    try {
      final token = await StorageService.getToken();
      final res = await http.get(Uri.parse(ApiConstants.adminStats), headers: _headers(token)).timeout(_timeout);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return AdminStatsModel.fromJson(data['stats']);
      } else {
        throw Exception(data['detail'] ?? 'Ошибка загрузки статистики');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<List<UserModel>> getAdminUsers({String? search}) async {
    try {
      final token = await StorageService.getToken();
      var url = ApiConstants.adminUsers;
      if (search != null && search.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(search)}';
      }
      final res = await http.get(Uri.parse(url), headers: _headers(token)).timeout(_timeout);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return (data['users'] as List).map((e) => UserModel.fromJson(e)).toList();
      } else {
        throw Exception(data['detail'] ?? 'Ошибка получения списка пользователей');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> adminCreateUser({
    required String username,
    required String email,
    required String password,
    String fullName = '',
    String role = 'user',
  }) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.adminUsers),
        headers: _headers(token),
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'role': role,
        }),
      ).timeout(_timeout);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode != 200 || data['success'] != true) {
        throw Exception(data['detail'] ?? 'Ошибка создания пользователя');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> updateAdminUser(
    int userId, {
    String? username,
    String? email,
    String? fullName,
    String? role,
    bool? isActive,
    String? password,
    bool? canTranscribe,
    bool? canSummarize,
    bool? canChatGeneral,
    bool? canChatLecture,
  }) async {
    try {
      final token = await StorageService.getToken();
      final Map<String, dynamic> body = {};
      if (username != null && username.isNotEmpty) body['username'] = username.trim();
      if (email != null && email.isNotEmpty) body['email'] = email.trim();
      if (fullName != null) body['full_name'] = fullName.trim();
      if (role != null) body['role'] = role;
      if (isActive != null) body['is_active'] = isActive;
      if (password != null && password.isNotEmpty) body['password'] = password;
      if (canTranscribe != null) body['can_transcribe'] = canTranscribe;
      if (canSummarize != null) body['can_summarize'] = canSummarize;
      if (canChatGeneral != null) body['can_chat_general'] = canChatGeneral;
      if (canChatLecture != null) body['can_chat_lecture'] = canChatLecture;

      final res = await http.put(
        Uri.parse(ApiConstants.adminUserDetail(userId)),
        headers: _headers(token),
        body: jsonEncode(body),
      ).timeout(_timeout);
      
      if (res.statusCode != 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(data['detail'] ?? 'Ошибка обновления данных пользователя');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> deleteAdminUser(int userId) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.delete(Uri.parse(ApiConstants.adminUserDetail(userId)), headers: _headers(token)).timeout(_timeout);
      if (res.statusCode != 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(data['detail'] ?? 'Ошибка удаления аккаунта');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<List<LogModel>> getAdminLogs({String? level, String? category, String? search, int limit = 150}) async {
    try {
      final token = await StorageService.getToken();
      final queryParams = <String, String>{'limit': limit.toString()};
      if (level != null && level != 'ALL') queryParams['level'] = level;
      if (category != null && category != 'all') queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse(ApiConstants.adminLogs).replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers(token)).timeout(_timeout);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return (data['logs'] as List).map((e) => LogModel.fromJson(e)).toList();
      } else {
        throw Exception(data['detail'] ?? 'Ошибка загрузки журнала логов');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> clearAdminLogs() async {
    try {
      final token = await StorageService.getToken();
      final res = await http.delete(Uri.parse(ApiConstants.adminClearLogs), headers: _headers(token)).timeout(_timeout);
      if (res.statusCode != 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(data['detail'] ?? 'Ошибка очистки логов');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<Map<String, String>> getAdminSettings() async {
    try {
      final token = await StorageService.getToken();
      final res = await http.get(Uri.parse(ApiConstants.adminSettings), headers: _headers(token)).timeout(_timeout);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['settings'] is Map) {
        return Map<String, String>.from(data['settings']);
      }
    } catch (_) {}
    return {};
  }

  static Future<void> updateRegistrationEnabled(bool enabled) async {
    try {
      final token = await StorageService.getToken();
      await http.post(
        Uri.parse(ApiConstants.adminSettings),
        headers: _headers(token),
        body: jsonEncode({'registration_enabled': enabled}),
      ).timeout(_timeout);
      _cachedRegistrationEnabled = enabled;
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> updateAdminSettings(Map<String, dynamic> settings) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.adminSettings),
        headers: _headers(token),
        body: jsonEncode(settings),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(data['detail'] ?? 'Ошибка сохранения настроек');
      }
      if (settings.containsKey('registration_enabled')) {
        _cachedRegistrationEnabled = settings['registration_enabled'] == true || settings['registration_enabled'] == 1;
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> sendClientLog(String action, String level, String details) async {
    try {
      await http.post(
        Uri.parse(ApiConstants.clientLog),
        headers: _headers(null),
        body: jsonEncode({
          'action': action,
          'level': level,
          'details': details,
          'category': 'mobile_client',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // System Health Diagnostics
  static Future<Map<String, dynamic>> getSystemHealthDetails() async {
    try {
      final token = await StorageService.getToken();
      final res = await http.get(
        Uri.parse(ApiConstants.systemHealthDetails),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return data;
      }
    } catch (_) {}
    return {};
  }

  // Admin Lectures Management
  static Future<List<LectureModel>> getAdminLectures({String? search}) async {
    try {
      final token = await StorageService.getToken();
      var url = ApiConstants.adminLectures;
      if (search != null && search.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(search)}';
      }
      final res = await http.get(Uri.parse(url), headers: _headers(token)).timeout(_timeout);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && data['success'] == true) {
        return (data['lectures'] as List).map((e) => LectureModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  static Future<void> adminDeleteLecture(int lectureId) async {
    try {
      final token = await StorageService.getToken();
      final res = await http.delete(
        Uri.parse(ApiConstants.adminLectureDetail(lectureId)),
        headers: _headers(token),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(data['detail'] ?? 'Ошибка удаления лекции администратором');
      }
    } catch (e) {
      throw Exception(_localizeError(e));
    }
  }

  // Academic AI Lecture Chat (LibeNet AI)
  static Future<String> askLectureChat({
    required int lectureId,
    required String question,
    List<Map<String, String>> history = const [],
    String? lectureTitle,
    String? lectureSummary,
    String? lectureTranscript,
  }) async {
    final cleanQuestion = question.trim();
    final filteredHistory = history.where((m) => m['content']?.trim() != cleanQuestion).toList();
    final recentHistory = filteredHistory.length > 6
        ? filteredHistory.sublist(filteredHistory.length - 6)
        : filteredHistory;

    // 1. Try server endpoint first
    try {
      final token = await StorageService.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.lectureChat(lectureId)),
        headers: _headers(token),
        body: jsonEncode({
          'question': cleanQuestion,
          'history': recentHistory,
        }),
      ).timeout(const Duration(seconds: 40));
      _checkAuthStatus(res.statusCode);

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['answer'] != null) {
          return data['answer'];
        }
      }
    } catch (e) {
      sendClientLog('CHAT_FALLBACK', 'WARN', 'Server endpoint fallback triggered: $e');
    }

    // 2. Direct LibeNet AI via OrcaRouter fallback if configured
    if (AppConfig.hasDirectOrca) {
      try {
        return await _askAiDirect(
          question: cleanQuestion,
          history: recentHistory,
          lectureTitle: lectureTitle ?? 'Лекция #$lectureId',
          lectureSummary: lectureSummary ?? '',
          lectureTranscript: lectureTranscript ?? '',
        );
      } catch (e) {
        sendClientLog('DIRECT_AI_FAIL', 'WARN', 'Direct AI fallback failed: $e');
      }
    }

    throw Exception('Сервис AI временно недоступен. Пожалуйста, повторите попытку.');
  }

  static Future<String> _askAiDirect({
    required String question,
    List<Map<String, String>> history = const [],
    required String lectureTitle,
    required String lectureSummary,
    required String lectureTranscript,
  }) async {
    final orcaKey = AppConfig.orcaApiKey;
    if (orcaKey.isEmpty) {
      throw Exception('Прямой клиентский AI-шлюз не настроен.');
    }
    const model = 'deepseek/deepseek-v4-flash-free';

    String contextText = '';
    if (lectureSummary.isNotEmpty) {
      contextText += 'КОНСПЕКТ ЛЕКЦИИ:\n$lectureSummary\n\n';
    }
    if (lectureTranscript.isNotEmpty) {
      final truncated = lectureTranscript.length > 25000
          ? lectureTranscript.substring(0, 25000)
          : lectureTranscript;
      contextText += 'ПОЛНЫЙ ТЕКСТ РЕЧИ ЛЕКТОРА:\n$truncated';
    }

    final systemPrompt = 'Ты — академический AI-консультант и тьютор студента по лекции «$lectureTitle».\n'
        'Твоя задача — точно, понятно и профессионально отвечать на любые вопросы студента, опираясь на материалы лекции.\n\n'
        'МАТЕРИАЛЫ ЛЕКЦИИ:\n$contextText\n\n'
        'ПРАВИЛА ОТВЕТА:\n'
        '1. Отвечай строго по существу вопроса на русском языке.\n'
        '2. Опирайся на приведенные материалы лекции.\n'
        '3. Если студент просит объяснить простыми словами — объясни доступно на понятных примерах и аналогиях.\n'
        '4. Оформляй ответ в красивом Markdown: выделяй термины **жирным шрифтом**, используй списки при необходимости.\n'
        '5. НЕ используй смайлики и эмодзи.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    final filtered = history.where((m) => m['content']?.trim() != question.trim()).toList();
    final recent = filtered.length > 6 ? filtered.sublist(filtered.length - 6) : filtered;
    for (final h in recent) {
      if (h.containsKey('role') && h.containsKey('content')) {
        messages.add({'role': h['role']!, 'content': h['content']!});
      }
    }
    messages.add({'role': 'user', 'content': question.trim()});

    try {
      final res = await http.post(
        Uri.parse('https://api.orcarouter.ai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $orcaKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 0.3,
          'max_tokens': 1200,
        }),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'] ?? '';
        }
      }

      sendClientLog('ORCAROUTER_API_ERROR', 'ERROR', 'LibeNet AI returned status ${res.statusCode}: ${res.body}');
      throw Exception('Ошибка LibeNet AI (код ${res.statusCode}): ${res.body}');
    } catch (e) {
      sendClientLog('ORCAROUTER_EXCEPTION', 'ERROR', 'Failed to reach LibeNet AI: $e');
      rethrow;
    }
  }
}

