import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/api_error.dart';

const int _dailyLikeLimit = 1000;
const int _dailySuperLikeLimit = 10;
const String _prefLikeCount = 'daily_like_count';
const String _prefLikeDate = 'daily_like_date';
const String _prefSuperLikeCount = 'daily_super_like_count';
const String _prefSuperLikeDate = 'daily_super_like_date';
const String _prefRewindDate = 'last_rewind_date';

class DiscoveryProvider extends ChangeNotifier {
  final ApiService _api;

  List<UserModel> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  UserModel? _matchedUser;
  String? _matchId;
  int _dailyLikesUsed = 0;
  int _dailySuperLikesUsed = 0;
  bool _expandedSearch = false;

  DiscoveryProvider(this._api) {
    _loadDailyLikeCount();
    _loadDailySuperLikeCount();
  }

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  UserModel? get matchedUser => _matchedUser;
  String? get matchId => _matchId;
  int get dailyLikesUsed => _dailyLikesUsed;
  int get dailyLikesRemaining => (_dailyLikeLimit - _dailyLikesUsed).clamp(0, _dailyLikeLimit);
  bool get hasLikesLeft => _dailyLikesUsed < _dailyLikeLimit;
  int get superLikesRemaining => (_dailySuperLikeLimit - _dailySuperLikesUsed).clamp(0, _dailySuperLikeLimit);
  bool get hasSuperLikesLeft => _dailySuperLikesUsed < _dailySuperLikeLimit;
  bool get expandedSearch => _expandedSearch;

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

  Future<void> _loadDailySuperLikeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_prefSuperLikeDate) ?? '';
    if (savedDate != today) {
      await prefs.setInt(_prefSuperLikeCount, 0);
      await prefs.setString(_prefSuperLikeDate, today);
      _dailySuperLikesUsed = 0;
    } else {
      _dailySuperLikesUsed = prefs.getInt(_prefSuperLikeCount) ?? 0;
    }
    notifyListeners();
  }

  Future<void> _incrementSuperLikeCount() async {
    _dailySuperLikesUsed++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSuperLikeCount, _dailySuperLikesUsed);
    await prefs.setString(_prefSuperLikeDate, _todayString());
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
      final result = await _api.getNearby(
        latitude: latitude,
        longitude: longitude,
        page: _page,
        limit: 10,
      );
      final newUsers = result['users'] as List<UserModel>;
      _expandedSearch = result['expandedSearch'] as bool;
      _users.addAll(newUsers);
      _hasMore = newUsers.length == 10;
      _page++;
    } catch (e) {
      _error = extractApiError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> swipeRight(String targetId, {bool bypassLimit = false, String? comment}) async {
    if (!bypassLimit && !hasLikesLeft) {
      _error = 'You have used all $_dailyLikeLimit likes for today. Come back tomorrow!';
      notifyListeners();
      return false;
    }
    try {
      final result = await _api.swipe(targetId: targetId, direction: 'like', comment: comment);
      await _incrementLikeCount();
      // Don't remove the user from the list here — CardSwiper manages its own
      // index. Removing while a swipe is in progress shifts indices and makes
      // subsequent cards point to the wrong user or appear empty.
      if (result['match'] != null) {
        _matchId = result['match']['_id']?.toString();
        _matchedUser = UserModel.fromJson(result['match']['users']
            .firstWhere((u) => u['_id'] == targetId, orElse: () => result['match']['users'][0]));
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = extractApiError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> swipeLeft(String targetId) async {
    try {
      await _api.swipe(targetId: targetId, direction: 'dislike');
      // Don't remove from list — CardSwiper advances its index on its own.
      notifyListeners();
    } catch (e) {
      _error = extractApiError(e);
    }
  }

  Future<bool> superLike(String targetId, {String? comment}) async {
    if (!hasSuperLikesLeft) {
      _error = 'No Super Likes left today. Come back tomorrow!';
      notifyListeners();
      return false;
    }
    try {
      final result = await _api.swipe(targetId: targetId, direction: 'superlike', comment: comment);
      await _incrementSuperLikeCount();
      // Superlike always creates an instant match on the backend
      if (result['match'] != null) {
        _matchId = result['match']['_id']?.toString();
        _matchedUser = UserModel.fromJson(result['match']['users']
            .firstWhere((u) => u['_id'] == targetId, orElse: () => result['match']['users'][0]));
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = extractApiError(e);
      notifyListeners();
      return false;
    }
  }

  // Rewind just undoes the API swipe record. The visual "go back one card"
  // is handled by calling _controller.undo() in DiscoveryScreen.
  Future<bool> rewind() async {
    try {
      final data = await _api.rewindSwipe();
      return data['user'] != null;
    } catch (e) {
      _error = extractApiError(e);
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
    _matchId = null;
    notifyListeners();
  }

  void _removeUser(String userId) {
    _users.removeWhere((u) => u.id == userId);
  }

  Future<void> reset() async {
    _users = [];
    _page = 1;
    _hasMore = true;
    _isLoading = false;
    _error = null;
    _matchedUser = null;
    _matchId = null;
    _expandedSearch = false;
    await _loadDailyLikeCount();
    await _loadDailySuperLikeCount();
    notifyListeners();
  }
}
