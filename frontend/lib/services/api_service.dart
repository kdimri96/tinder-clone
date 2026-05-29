import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/message_model.dart' hide MediaType;
import '../utils/app_config.dart';

class ApiService {
  static String get _baseUrl => AppConfig.apiBaseUrl;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Web-safe token read/write/delete using SharedPreferences on web
  Future<String?> _readKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _storage.read(key: key);
  }

  Future<void> _writeKey(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<void> _deleteKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readKey('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Bypass ngrok browser warning page for API calls
        options.headers['ngrok-skip-browser-warning'] = 'true';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _readKey('access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final retryResponse = await _dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _readKey('refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '$_baseUrl/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      await _writeKey('access_token', response.data['token']);
      await _writeKey('refresh_token', response.data['refreshToken']);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  // AUTH
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data);
    return response.data;
  }

  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
    String? name,
    String? email,
  }) async {
    final response = await _dio.post('/auth/social', data: {
      'provider': provider,
      'token': token,
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    await _saveTokens(response.data);
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    return response.data;
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_email');
  }

  Future<void> logout() async {
    await _deleteKey('access_token');
    await _deleteKey('refresh_token');
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get('/auth/me');
    return UserModel.fromJson(response.data['user']);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    if (data['token'] != null) {
      await _writeKey('access_token', data['token']);
    }
    if (data['refreshToken'] != null) {
      await _writeKey('refresh_token', data['refreshToken']);
    }
  }

  // PROFILE
  Future<UserModel> getProfile() async {
    final response = await _dio.get('/profile');
    return UserModel.fromJson(response.data['user']);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> updates) async {
    final response = await _dio.patch('/profile', data: updates);
    return UserModel.fromJson(response.data['user']);
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    await _dio.patch('/profile', data: {'latitude': latitude, 'longitude': longitude});
  }

  // Accepts XFile (works on all platforms including web)
  Future<UserModel> uploadPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: _safeFilename(file.name, 'photo.jpg'),
        contentType: MediaType.parse(_mimeType(file)),
      ),
    });
    final response = await _dio.post('/profile/photo', data: formData);
    return UserModel.fromJson(response.data['user']);
  }

  Future<UserModel> deletePhoto(String photoUrl) async {
    final response = await _dio.delete('/profile/photo', data: {'photoUrl': photoUrl});
    return UserModel.fromJson(response.data['user']);
  }

  // DISCOVERY
  Future<Map<String, dynamic>> getNearby({
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (latitude != null) queryParams['latitude'] = latitude;
    if (longitude != null) queryParams['longitude'] = longitude;

    final response = await _dio.get('/discovery/nearby', queryParameters: queryParams);
    final users = (response.data['users'] as List).map((u) => UserModel.fromJson(u)).toList();
    return {
      'users': users,
      'expandedSearch': response.data['expandedSearch'] ?? false,
    };
  }

  // SWIPE
  Future<Map<String, dynamic>> swipe({
    required String targetId,
    required String direction,
    String? comment,
  }) async {
    final response = await _dio.post('/swipe', data: {
      'targetId': targetId,
      'direction': direction,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return response.data;
  }

  // MATCHES
  Future<List<MatchModel>> getMatches() async {
    final response = await _dio.get('/matches');
    final matches = response.data['matches'] as List;
    return matches.map((m) => MatchModel.fromJson(m)).toList();
  }

  Future<MatchModel> getMatch(String matchId) async {
    final response = await _dio.get('/matches/$matchId');
    return MatchModel.fromJson(response.data['match']);
  }

  Future<void> unmatch(String matchId) async {
    await _dio.delete('/matches/$matchId');
  }

  // MESSAGES
  Future<List<MessageModel>> getMessages(String matchId, {String? before, int limit = 30}) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (before != null) queryParams['before'] = before;

    final response = await _dio.get('/messages/$matchId', queryParameters: queryParams);
    final messages = response.data['messages'] as List;
    return messages.map((m) => MessageModel.fromJson(m)).toList();
  }

  Future<MessageModel> sendMessage(String matchId, String text) async {
    final response = await _dio.post('/messages/$matchId', data: {'text': text});
    return MessageModel.fromJson(response.data['message']);
  }

  Future<MessageModel> sendPhotoMessage(String matchId, XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: _safeFilename(file.name, 'photo.jpg'),
        contentType: MediaType.parse(_mimeType(file)),
      ),
    });
    final response = await _dio.post('/messages/$matchId/photo', data: formData);
    return MessageModel.fromJson(response.data['message']);
  }

  Future<MessageModel> sendAudioMessage(String matchId, Uint8List bytes, int durationSeconds, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'webm';
    final mimeStr = {
      'm4a': 'audio/mp4', 'aac': 'audio/aac',
      'mp3': 'audio/mpeg', 'ogg': 'audio/ogg',
      'wav': 'audio/wav', 'webm': 'audio/webm',
    }[ext] ?? 'audio/webm';

    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType.parse(mimeStr)),
      'duration': durationSeconds.toString(),
    });
    final response = await _dio.post('/messages/$matchId/audio', data: formData);
    return MessageModel.fromJson(response.data['message']);
  }

  Future<MessageModel> sendSnapMessage(String matchId, XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = _mimeType(file);
    final fallback = mime.startsWith('video/') ? 'snap.mp4' : 'snap.jpg';
    final formData = FormData.fromMap({
      'snap': MultipartFile.fromBytes(
        bytes,
        filename: _safeFilename(file.name, fallback),
        contentType: MediaType.parse(mime),
      ),
    });
    final response = await _dio.post('/messages/$matchId/snap', data: formData);
    return MessageModel.fromJson(response.data['message']);
  }

  Future<MessageModel> viewSnap(String messageId) async {
    final response = await _dio.post('/messages/snap/$messageId/view');
    return MessageModel.fromJson(response.data['message']);
  }

  // Returns the MIME type for an XFile: uses the declared mimeType if available,
  // otherwise guesses from the filename extension.
  String _mimeType(XFile file) {
    if (file.mimeType != null && file.mimeType!.isNotEmpty) return file.mimeType!;
    final ext = file.name.toLowerCase().split('.').last;
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png', 'webp': 'image/webp', 'gif': 'image/gif',
      'mp4': 'video/mp4', 'mov': 'video/quicktime',
      'webm': 'video/webm', 'm4v': 'video/x-m4v', 'avi': 'video/x-msvideo',
    };
    return map[ext] ?? 'image/jpeg';
  }

  // Ensures the filename is non-empty and has a proper extension.
  String _safeFilename(String name, String fallback) {
    if (name.isEmpty || !name.contains('.')) return fallback;
    return name;
  }

  Future<String?> getStoredToken() async {
    return _readKey('access_token');
  }

  // PAYMENTS
  Future<Map<String, dynamic>> getPlans() async {
    final response = await _dio.get('/payments/plans');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> createPaymentOrder(String planId) async {
    final response = await _dio.post('/payments/create-order', data: {'planId': planId});
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String planId,
  }) async {
    final response = await _dio.post('/payments/verify', data: {
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
      'planId': planId,
    });
    return Map<String, dynamic>.from(response.data);
  }

  // PREFERENCES
  Future<UserModel> updatePreferences(Map<String, dynamic> prefs) async {
    final response = await _dio.patch('/profile/preferences', data: prefs);
    return UserModel.fromJson(response.data['user']);
  }

  // REWIND
  Future<Map<String, dynamic>> rewindSwipe() async {
    final response = await _dio.post('/swipe/rewind');
    return Map<String, dynamic>.from(response.data);
  }

  // REPORT & BLOCK
  Future<void> reportUser(String reportedId, String reason, {String details = ''}) async {
    await _dio.post('/users/report', data: {'reportedId': reportedId, 'reason': reason, 'details': details});
  }

  Future<void> blockUser(String blockedId) async {
    await _dio.post('/users/block', data: {'blockedId': blockedId});
  }

  // LIKED YOU
  Future<List<UserModel>> getLikedYou({int page = 1}) async {
    final response = await _dio.get('/discovery/liked-you', queryParameters: {'page': page, 'limit': 20});
    final users = response.data['users'] as List;
    return users.map((u) => UserModel.fromJson(u)).toList();
  }
}
