import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

const int _dailyLikeLimit = 10;
const String _prefLikeCount = 'daily_like_count';
const String _prefLikeDate = 'daily_like_date';
const String _prefRewindDate = 'last_rewind_date';

class DiscoveryProvider extends ChangeNotifier {
  final ApiService _api;

  List<UserModel> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  UserModel? _matchedUser;
  int _dailyLikesUsed = 0;
  UserModel? _lastRewoundUser;

  DiscoveryProvider(this._api) {
    _loadDailyLikeCount();
  }

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  UserModel? get matchedUser => _matchedUser;
  int get dailyLikesUsed => _dailyLikesUsed;
  int get dailyLikesRemaining => (_dailyLikeLimit - _dailyLikesUsed).clamp(0, _dailyLikeLimit);
  bool get hasLikesLeft => _dailyLikesUsed < _dailyLikeLimit;

  Future<void> _loadDailyLikeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_prefLikeDate) ?? '';
    if (savedDate != today) {
      // New day — reset count
      await prefs.setInt(_prefLikeCount, 0);
      await prefs.setString(_prefLikeDate, today);
      _dailyLikesUsed = 0;
    } else {
      _dailyLikesUsed = prefs.getInt(_prefLikeCount) ?? 0;
    }
    notifyListeners();
  }

  Future<void> _incrementLikeCount() async {
    _dailyLikesUsed++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLikeCount, _dailyLikesUsed);
    await prefs.setString(_prefLikeDate, _todayString());
    notifyListeners();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<bool> hasUsedRewindToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRewindDate = prefs.getString(_prefRewindDate) ?? '';
    return lastRewindDate == _todayString();
  }

  Future<void> markRewindUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRewindDate, _todayString());
  }

  Future<void> loadUsers({double? latitude, double? longitude}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newUsers = await _api.getNearby(
        latitude: latitude,
        longitude: longitude,
        page: _page,
        limit: 10,
      );
      _users.addAll(newUsers);
      _hasMore = newUsers.length == 10;
      _page++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> swipeRight(String targetId, {bool bypassLimit = false}) async {
    if (!bypassLimit && !hasLikesLeft) {
      _error = 'You have used all $_dailyLikeLimit likes for today. Come back tomorrow!';
      notifyListeners();
      return false;
    }
    try {
      final result = await _api.swipe(targetId: targetId, direction: 'like');
      await _incrementLikeCount();
      _removeUser(targetId);
      if (result['match'] != null) {
        _matchedUser = UserModel.fromJson(result['match']['users']
            .firstWhere((u) => u['_id'] == targetId, orElse: () => result['match']['users'][0]));
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> swipeLeft(String targetId) async {
    try {
      await _api.swipe(targetId: targetId, direction: 'dislike');
      _removeUser(targetId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<bool> superLike(String targetId) async {
    try {
      final result = await _api.swipe(targetId: targetId, direction: 'superlike');
      _removeUser(targetId);
      if (result['match'] != null) {
        _matchedUser = UserModel.fromJson(result['match']['users']
            .firstWhere((u) => u['_id'] == targetId, orElse: () => result['match']['users'][0]));
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rewind() async {
    try {
      final data = await _api.rewindSwipe();
      if (data['user'] != null) {
        final user = UserModel.fromJson(data['user']);
        _users.insert(0, user);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void removeUserById(String userId) {
    _removeUser(userId);
    notifyListeners();
  }

  void clearMatch() {
    _matchedUser = null;
    notifyListeners();
  }

  void _removeUser(String userId) {
    _users.removeWhere((u) => u.id == userId);
  }

  Future<void> reset() async {
    _users = [];
    _page = 1;
    _hasMore = true;
    _error = null;
    _matchedUser = null;
    await _loadDailyLikeCount();
    notifyListeners();
  }
}
