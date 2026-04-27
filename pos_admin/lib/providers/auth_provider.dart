import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  bool _isLoading = false;
  String? _error;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final data = await api.login(username, password);
      api.setToken(data['token'] as String);

      _isLoggedIn = true;
      _username = data['username'] as String?;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    ApiService().clearToken();
    _isLoggedIn = false;
    _username = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
