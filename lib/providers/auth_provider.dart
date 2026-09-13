import 'package:flutter/foundation.dart';
import '../core/services/api_service.dart';
import '../core/services/storage_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = true;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _token != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get errorMessage => _errorMessage;
  Future<void> checkAuth() => initAuth();

  AuthProvider() {
    ApiService.onUnauthorized = () {
      logout();
    };
  }

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      _token = await StorageService.getToken();
      _user = await StorageService.getUser();
      if (_token != null) {
        // Refresh profile in background
        final me = await ApiService.getMe();
        if (me != null) {
          _user = me;
        }
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await ApiService.login(username, password);
      _user = res['user'];
      _token = res['token'];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password, String fullName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await ApiService.register(username, email, password, fullName);
      _user = res['user'];
      _token = res['token'];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.clearAuth();
    _user = null;
    _token = null;
    notifyListeners();
  }
}
