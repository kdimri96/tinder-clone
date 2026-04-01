import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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
    try {
      _error = null;
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return false;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Failed to get Google credentials');

      final data = await _api.socialLogin(
        provider: 'google',
        token: idToken,
        name: account.displayName,
        email: account.email,
      );
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

  Future<bool> loginWithFacebook() async {
    try {
      _error = null;
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success) {
        if (result.status == LoginStatus.cancelled) return false;
        throw Exception(result.message ?? 'Facebook login failed');
      }

      final tokenString = result.accessToken?.tokenString;
      if (tokenString == null) throw Exception('Failed to get Facebook token');

      final userData = await FacebookAuth.instance.getUserData(
        fields: 'name,email',
      );

      final data = await _api.socialLogin(
        provider: 'facebook',
        token: tokenString,
        name: userData['name'] as String?,
        email: userData['email'] as String?,
      );
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

  Future<bool> loginWithApple() async {
    try {
      _error = null;
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) throw Exception('Failed to get Apple credentials');

      final nameParts = [credential.givenName, credential.familyName]
          .where((e) => e != null && e.isNotEmpty)
          .join(' ');

      final data = await _api.socialLogin(
        provider: 'apple',
        token: identityToken,
        name: nameParts.isNotEmpty ? nameParts : null,
        email: credential.email,
      );
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
