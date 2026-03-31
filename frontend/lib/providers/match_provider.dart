import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class MatchProvider extends ChangeNotifier {
  final ApiService _api;
  final SocketService _socket;

  List<MatchModel> _matches = [];
  bool _isLoading = false;
  String? _error;

  MatchProvider(this._api, this._socket) {
    _socket.onMatch(_onNewMatch);
    _socket.onMessage(_onNewMessage);
  }

  List<MatchModel> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => 0; // simplified

  Future<void> loadMatches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _matches = await _api.getMatches();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onNewMatch(MatchModel match) {
    _matches.insert(0, match);
    notifyListeners();
  }

  void _onNewMessage(MessageModel message) {
    final idx = _matches.indexWhere((m) => m.id == message.matchId);
    if (idx >= 0) {
      // Move match with new message to top
      final match = _matches.removeAt(idx);
      _matches.insert(0, match);
      notifyListeners();
    }
  }

  Future<void> unmatch(String matchId) async {
    try {
      await _api.unmatch(matchId);
      _matches.removeWhere((m) => m.id == matchId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socket.removeMatchListener(_onNewMatch);
    _socket.removeMessageListener(_onNewMessage);
    super.dispose();
  }
}
