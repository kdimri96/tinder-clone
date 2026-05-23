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

  // Badge count for the Matches tab — incremented by socket events, cleared
  // when the user opens the Matches tab.
  int _newNotificationsCount = 0;

  // The most recent match that arrived via socket (used by HomeScreen to show
  // the "You matched!" snackbar). Compared by ID so reference changes don't
  // produce duplicate snackbars after an API reload.
  MatchModel? _lastNewMatch;

  MatchProvider(this._api, this._socket) {
    _socket.onMatch(_onNewMatch);
    _socket.onMessage(_onNewMessage);
    _socket.onChatNotification(_onChatNotification);
  }

  List<MatchModel> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get newNotificationsCount => _newNotificationsCount;
  MatchModel? get lastNewMatch => _lastNewMatch;

  void clearNewNotifications() {
    if (_newNotificationsCount == 0 && _lastNewMatch == null) return;
    _newNotificationsCount = 0;
    // Keep _lastNewMatch so the snackbar identity check in HomeScreen works;
    // HomeScreen resets _lastShownMatchId on its own.
    notifyListeners();
  }

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

  // Called when a `match` socket event arrives.
  // The socket payload only contains `users[]` but no `otherUser`, so we
  // reload from the REST API to get the fully-populated data instead of
  // trying to render the socket model directly.
  void _onNewMatch(MatchModel socketMatch) async {
    _newNotificationsCount++;
    // Join the new room immediately so messages are received in real-time
    _socket.joinMatchRoom(socketMatch.id);
    notifyListeners(); // update badge right away

    try {
      final fresh = await _api.getMatches();
      _matches = fresh;
      // After reload, the newest match is first (sorted by lastMessageAt/createdAt desc)
      if (_matches.isNotEmpty) {
        _lastNewMatch = _matches.first;
      }
    } catch (_) {
      // Fallback: insert raw socket match (otherUser may be null — tile won't render
      // but the count/snackbar still works once the user refreshes)
      if (!_matches.any((m) => m.id == socketMatch.id)) {
        _matches.insert(0, socketMatch);
      }
      _lastNewMatch = socketMatch;
    }
    notifyListeners();
  }

  // Called when a `chat:message` socket event arrives.
  // Updates the preview text and bubbles that conversation to the top.
  // Badge is NOT incremented here — only chat:notification increments it,
  // which is only sent to the receiver (not the sender).
  void _onNewMessage(MessageModel message) {
    final idx = _matches.indexWhere((m) => m.id == message.matchId);
    if (idx >= 0) {
      final match = _matches.removeAt(idx);
      final updated = match.copyWith(
        lastMessage: message,
        lastMessageAt: message.createdAt,
      );
      _matches.insert(0, updated);
      notifyListeners();
    }
  }

  // Called when a `chat:notification` socket event arrives.
  // Only the message receiver gets this event, so incrementing badge here is safe.
  void _onChatNotification(String matchId, String senderName, String text) {
    _newNotificationsCount++;
    notifyListeners();
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
    _socket.removeChatNotificationListener(_onChatNotification);
    super.dispose();
  }
}
