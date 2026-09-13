import '../models/lecture_model.dart';
import 'package:flutter/foundation.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';
import '../models/log_model.dart';
import '../models/stats_model.dart';

class AdminProvider with ChangeNotifier {
  AdminStatsModel? _stats;
  List<UserModel> _users = [];
  List<LogModel> _allLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _registrationEnabled = true;
  String _selectedLogLevel = 'ALL';
  String _logSearchQuery = '';

  AdminStatsModel? get stats => _stats;
  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get registrationEnabled => _registrationEnabled;
  String get selectedLogLevel => _selectedLogLevel;

  List<LogModel> get filteredLogs {
    var list = _allLogs;
    if (_selectedLogLevel != 'ALL') {
      list = list.where((l) => l.level.toUpperCase() == _selectedLogLevel).toList();
    }
    if (_logSearchQuery.isNotEmpty) {
      final q = _logSearchQuery.toLowerCase();
      list = list.where((l) =>
        l.action.toLowerCase().contains(q) ||
        l.details.toLowerCase().contains(q) ||
        l.username.toLowerCase().contains(q) ||
        l.ipAddress.toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final statsFuture = ApiService.getAdminStats();
      final usersFuture = ApiService.getAdminUsers();
      final logsFuture = ApiService.getAdminLogs(limit: 200);
      final settingsFuture = ApiService.getAdminSettings();

      final results = await Future.wait([statsFuture, usersFuture, logsFuture, settingsFuture]);
      _stats = results[0] as AdminStatsModel;
      _users = results[1] as List<UserModel>;
      _allLogs = results[2] as List<LogModel>;
      
      final settings = results[3] as Map<String, String>;
      if (settings.containsKey('registration_enabled')) {
        _registrationEnabled = settings['registration_enabled']?.toLowerCase() == 'true';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLogLevelFilter(String level) {
    _selectedLogLevel = level;
    notifyListeners();
  }

  void searchLogs(String query) {
    _logSearchQuery = query;
    notifyListeners();
  }

  Future<void> toggleRegistration() async {
    final next = !_registrationEnabled;
    try {
      await ApiService.updateRegistrationEnabled(next);
      _registrationEnabled = next;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createUser({
    required String username,
    required String email,
    required String password,
    String fullName = '',
    String role = 'user',
  }) async {
    try {
      await ApiService.adminCreateUser(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      await fetchDashboardData();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateUser(
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
      await ApiService.updateAdminUser(
        userId,
        username: username,
        email: email,
        fullName: fullName,
        role: role,
        isActive: isActive,
        password: password,
        canTranscribe: canTranscribe,
        canSummarize: canSummarize,
        canChatGeneral: canChatGeneral,
        canChatLecture: canChatLecture,
      );
      await fetchDashboardData();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await ApiService.deleteAdminUser(userId);
      _users.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearLogs() async {
    try {
      await ApiService.clearAdminLogs();
      _allLogs.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  List<LectureModel> _adminLectures = [];
  List<LectureModel> get adminLectures => _adminLectures;

  Future<void> fetchAdminLectures({String? search}) async {
    try {
      _adminLectures = await ApiService.getAdminLectures(search: search);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> deleteAdminLecture(int lectureId) async {
    try {
      await ApiService.adminDeleteLecture(lectureId);
      _adminLectures.removeWhere((l) => l.id == lectureId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _stats = null;
    _users = [];
    _allLogs = [];
    _adminLectures = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      await ApiService.updateAdminSettings(settings);
      if (settings.containsKey('registration_enabled')) {
        _registrationEnabled = settings['registration_enabled'] == true || settings['registration_enabled'] == 1;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

}
