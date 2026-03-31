import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class DiscoveryProvider extends ChangeNotifier {
  final ApiService _api;

  List<UserModel> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  UserModel? _matchedUser;

  DiscoveryProvider(this._api);

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  UserModel? get matchedUser => _matchedUser;

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

  Future<bool> swipeRight(String targetId) async {
    try {
      final result = await _api.swipe(targetId: targetId, direction: 'like');
      _removeUser(targetId);
      if (result['match'] != null) {
        _matchedUser = UserModel.fromJson(result['match']['users']
            .firstWhere((u) => u['_id'] == targetId, orElse: () => result['match']['users'][0]));
        notifyListeners();
        return true; // it's a match!
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

  void clearMatch() {
    _matchedUser = null;
    notifyListeners();
  }

  void _removeUser(String userId) {
    _users.removeWhere((u) => u.id == userId);
  }

  void reset() {
    _users = [];
    _page = 1;
    _hasMore = true;
    _error = null;
    _matchedUser = null;
    notifyListeners();
  }
}
