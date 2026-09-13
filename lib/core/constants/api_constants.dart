class ApiConstants {
  static const String defaultBaseUrl = 'https://silenceteam.alwaysdata.net';
  static String _currentBaseUrl = defaultBaseUrl;

  static String get baseUrl => _currentBaseUrl;

  static void setBaseUrl(String url) {
    var clean = url.trim();
    if (clean.isEmpty) {
      _currentBaseUrl = defaultBaseUrl;
      return;
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    _currentBaseUrl = clean;
  }

  // Public
  static String get publicSettings => '$baseUrl/api/settings/public';

  // Auth
  static String get register => '$baseUrl/api/auth/register';
  static String get login => '$baseUrl/api/auth/login';
  static String get me => '$baseUrl/api/auth/me';

  // Lectures
  static String get lectures => '$baseUrl/api/lectures';
  static String lectureDetail(int id) => '$baseUrl/api/lectures/$id';
  static String uploadAudio(int id) => '$baseUrl/api/lectures/$id/upload-audio';
  static String transcribe(int id) => '$baseUrl/api/lectures/$id/transcribe';
  static String summarize(int id) => '$baseUrl/api/lectures/$id/summarize';
  static String audioStream(String filename) => '$baseUrl/api/audio/$filename';
  static String lectureChat(int id) => '$baseUrl/api/lectures/$id/chat';
  static String saveTranscript(int id) => '$baseUrl/api/lectures/$id/save-transcript';

  // Admin
  static String get adminStats => '$baseUrl/api/admin/stats';
  static String get adminUsers => '$baseUrl/api/admin/users';
  static String adminUserDetail(int id) => '$baseUrl/api/admin/users/$id';
  static String get adminLectures => '$baseUrl/api/admin/lectures';
  static String adminLectureDetail(int id) => '$baseUrl/api/admin/lectures/$id';
  static String get adminLogs => '$baseUrl/api/admin/logs';
  static String get adminClearLogs => '$baseUrl/api/admin/logs/clear';
  static String get adminSettings => '$baseUrl/api/admin/settings';

  // System Health & Diagnostics
  static String get systemHealthDetails => '$baseUrl/api/system/health-details';
  static String get clientLog => '$baseUrl/api/logs/client';
  static String get health => '$baseUrl/api/health';
}
