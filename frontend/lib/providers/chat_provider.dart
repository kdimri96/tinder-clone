import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final SocketService _socket;

  final Map<String, List<MessageModel>> _messages = {};
  final Map<String, bool> _typingStatus = {};
  final Map<String, Timer> _typingTimers = {};
  bool _isLoading = false;
  String? _error;

  // Tracks which chat the user currently has open so HomeScreen can suppress
  // duplicate notifications for the same conversation.
  String? _activeChatMatchId;
  String? get activeChatMatchId => _activeChatMatchId;
  void setActiveChat(String? matchId) => _activeChatMatchId = matchId;

  ChatProvider(this._api, this._socket) {
    _socket.onMessage(_onMessage);
    _socket.onTyping(_onTyping);
  }

  List<MessageModel> getMessages(String matchId) => _messages[matchId] ?? [];
  bool isTyping(String matchId) => _typingStatus[matchId] ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMessages(String matchId) async {
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
      final msgs = _messages[matchId]!;
      final idx = msgs.indexWhere((m) => m.id == tempId);
      if (idx >= 0) msgs[idx] = sent;
      notifyListeners();
    } catch (e) {
      _messages[matchId]!.removeWhere((m) => m.id == tempId);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendPhoto(String matchId, XFile file) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      matchId: matchId,
      senderId: 'me',
      text: '📷 Photo',
      createdAt: DateTime.now(),
      readBy: ['me'],
    );

    _messages[matchId] ??= [];
    _messages[matchId]!.add(optimistic);
    notifyListeners();

    try {
      final sent = await _api.sendPhotoMessage(matchId, file);
      final msgs = _messages[matchId]!;
      final idx = msgs.indexWhere((m) => m.id == tempId);
      if (idx >= 0) msgs[idx] = sent;
      notifyListeners();
    } catch (e) {
      _messages[matchId]!.removeWhere((m) => m.id == tempId);
      _error = e.toString();
      notifyListeners();
    }
  }

  void startTyping(String matchId) => _socket.startTyping(matchId);
  void stopTyping(String matchId) => _socket.stopTyping(matchId);

  void _onMessage(MessageModel message) {
    _messages[message.matchId] ??= [];
    if (!_messages[message.matchId]!.any((m) => m.id == message.id)) {
      _messages[message.matchId]!.add(message);
      _socket.markRead(message.matchId);
      notifyListeners();
    }
  }

  void _onTyping(String matchId, String userId, bool typing) {
    // Cancel any previous auto-clear for this conversation
    _typingTimers[matchId]?.cancel();

    if (typing) {
      _typingStatus[matchId] = true;
      // Auto-clear after 4 s in case stop event is missed
      _typingTimers[matchId] = Timer(const Duration(seconds: 4), () {
        _typingStatus[matchId] = false;
        notifyListeners();
      });
    } else {
      _typingStatus[matchId] = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _socket.removeMessageListener(_onMessage);
    _socket.removeTypingListener(_onTyping);
    super.dispose();
  }
}
