import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final SocketService _socket;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;

  AuthProvider(this._api, this._socket);

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isProfileComplete => _user?.isProfileComplete ?? false;

  Future<void> checkAuthStatus() async {
    try {
      final token = await _api.getStoredToken();
      if (token == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      _user = await _api.getMe();
      _status = AuthStatus.authenticated;
      _socket.connect(token);
      notifyListeners();
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _error = null;
      final data = await _api.register(name: name, email: email, password: password);
      _user = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      final token = await _api.getStoredToken();
      if (token != null) _socket.connect(token);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      _error = null;
      final data = await _api.login(email: email, password: password);
      _user = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      final token = await _api.getStoredToken();
      if (token != null) _socket.connect(token);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _error = 'Google Sign-In coming soon';
    notifyListeners();
    return false;
  }

  Future<bool> loginWithFacebook() async {
    _error = 'Facebook Sign-In coming soon';
    notifyListeners();
    return false;
  }

  Future<bool> loginWithApple() async {
    _error = 'Apple Sign-In coming soon';
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _socket.disconnect();
    await _api.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('message')) {
        final match = RegExp(r'"message":"([^"]+)"').firstMatch(msg);
        return match?.group(1) ?? 'Something went wrong';
      }
      return msg.replaceAll('Exception:', '').trim();
    }
    return 'Something went wrong';
  }
}
