import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';

class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // For iOS simulator use: http://localhost:3000/api
  // For physical device use your machine's IP: http://192.168.x.x:3000/api

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
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
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '$_baseUrl/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      await _storage.write(key: 'access_token', value: response.data['token']);
      await _storage.write(key: 'refresh_token', value: response.data['refreshToken']);
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

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data);
    return response.data;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get('/auth/me');
    return UserModel.fromJson(response.data['user']);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    if (data['token'] != null) {
      await _storage.write(key: 'access_token', value: data['token']);
    }
    if (data['refreshToken'] != null) {
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);
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

  Future<UserModel> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/profile/photo', data: formData);
    return UserModel.fromJson(response.data['user']);
  }

  Future<UserModel> deletePhoto(String photoUrl) async {
    final response = await _dio.delete('/profile/photo', data: {'photoUrl': photoUrl});
    return UserModel.fromJson(response.data['user']);
  }

  // DISCOVERY
  Future<List<UserModel>> getNearby({
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (latitude != null) queryParams['latitude'] = latitude;
    if (longitude != null) queryParams['longitude'] = longitude;

    final response = await _dio.get('/discovery/nearby', queryParameters: queryParams);
    final users = response.data['users'] as List;
    return users.map((u) => UserModel.fromJson(u)).toList();
  }

  // SWIPE
  Future<Map<String, dynamic>> swipe({
    required String targetId,
    required String direction, // 'like', 'dislike', 'superlike'
  }) async {
    final response = await _dio.post('/swipe', data: {
      'targetId': targetId,
      'direction': direction,
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

  Future<String?> getStoredToken() async {
    return _storage.read(key: 'access_token');
  }
}
