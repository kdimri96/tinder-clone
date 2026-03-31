import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final SocketService _socket;

  final Map<String, List<MessageModel>> _messages = {};
  final Map<String, bool> _typingStatus = {};
  bool _isLoading = false;
  String? _error;

  ChatProvider(this._api, this._socket) {
    _socket.onMessage(_onMessage);
    _socket.onTyping(_onTyping);
  }

  List<MessageModel> getMessages(String matchId) => _messages[matchId] ?? [];
  bool isTyping(String matchId) => _typingStatus[matchId] ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMessages(String matchId) async {
    if (_messages.containsKey(matchId) && _messages[matchId]!.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final messages = await _api.getMessages(matchId);
      _messages[matchId] = messages;
      _socket.joinMatchRoom(matchId);
      _socket.markRead(matchId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(String matchId) async {
    final existing = _messages[matchId];
    if (existing == null || existing.isEmpty) return;

    try {
      final older = await _api.getMessages(matchId, before: existing.first.id);
      _messages[matchId] = [...older, ...existing];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> sendMessage(String matchId, String text) async {
    // Optimistic update
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      matchId: matchId,
      senderId: 'me',
      text: text,
      createdAt: DateTime.now(),
      readBy: ['me'],
    );

    _messages[matchId] ??= [];
    _messages[matchId]!.add(optimistic);
    notifyListeners();

    try {
      final sent = await _api.sendMessage(matchId, text);
      // Replace optimistic message with real one
      final msgs = _messages[matchId]!;
      final idx = msgs.indexWhere((m) => m.id == tempId);
      if (idx >= 0) msgs[idx] = sent;
      notifyListeners();
    } catch (e) {
      // Remove optimistic on failure
      _messages[matchId]!.removeWhere((m) => m.id == tempId);
      _error = e.toString();
      notifyListeners();
    }
  }

  void startTyping(String matchId) => _socket.startTyping(matchId);
  void stopTyping(String matchId) => _socket.stopTyping(matchId);

  void _onMessage(MessageModel message) {
    _messages[message.matchId] ??= [];
    // Avoid duplicate from socket if REST already added it
    if (!_messages[message.matchId]!.any((m) => m.id == message.id)) {
      _messages[message.matchId]!.add(message);
      _socket.markRead(message.matchId);
      notifyListeners();
    }
  }

  void _onTyping(String userId, bool isTyping) {
    // This is a simplified version; in production you'd key by matchId+userId
    notifyListeners();
  }

  @override
  void dispose() {
    _socket.removeMessageListener(_onMessage);
    _socket.removeTypingListener(_onTyping);
    super.dispose();
  }
}
