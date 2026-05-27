import 'dart:async';
import 'dart:typed_data';
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
    _socket.onSnapViewed(_onSnapViewed);
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
    _error = null;
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
      // Remove any socket-delivered copy that arrived before the API response
      // (race condition: socket fires → _onMessage adds real ID → API returns
      // and replaces temp → two entries with the same real ID).
      msgs.removeWhere((m) => m.id == sent.id);
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
    _error = null;
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
      msgs.removeWhere((m) => m.id == sent.id);
      final idx = msgs.indexWhere((m) => m.id == tempId);
      if (idx >= 0) msgs[idx] = sent;
      notifyListeners();
    } catch (e) {
      _messages[matchId]!.removeWhere((m) => m.id == tempId);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendAudio(String matchId, Uint8List bytes, int durationSeconds, String filename) async {
    _error = null;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      matchId: matchId,
      senderId: 'me',
      text: '🎵 Voice message',
      mediaType: MediaType.audio,
      audioDuration: durationSeconds,
      createdAt: DateTime.now(),
      readBy: ['me'],
    );
    _messages[matchId] ??= [];
    _messages[matchId]!.add(optimistic);
    notifyListeners();

    try {
      final sent = await _api.sendAudioMessage(matchId, bytes, durationSeconds, filename);
      final msgs = _messages[matchId]!;
      msgs.removeWhere((m) => m.id == sent.id);
      final idx = msgs.indexWhere((m) => m.id == tempId);
      if (idx >= 0) msgs[idx] = sent;
      notifyListeners();
    } catch (e) {
      _messages[matchId]!.removeWhere((m) => m.id == tempId);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendSnap(String matchId, XFile file) async {
    _error = null;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      matchId: matchId,
      senderId: 'me',
      text: '📸 Snap',
      mediaType: MediaType.snap,
      isSnap: true,
      createdAt: DateTime.now(),
      readBy: ['me'],
    );
    _messages[matchId] ??= [];
    _messages[matchId]!.add(optimistic);
    notifyListeners();

    try {
      final sent = await _api.sendSnapMessage(matchId, file);
      final msgs = _messages[matchId]!;
      msgs.removeWhere((m) => m.id == sent.id);
      final idx = msgs.indexWhere((m) => m.id == tempId);
      if (idx >= 0) msgs[idx] = sent;
      notifyListeners();
    } catch (e) {
      _messages[matchId]!.removeWhere((m) => m.id == tempId);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> viewSnap(String matchId, String messageId) async {
    try {
      final updated = await _api.viewSnap(messageId);
      _updateMessage(matchId, updated);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _updateMessage(String matchId, MessageModel updated) {
    final msgs = _messages[matchId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == updated.id);
    if (idx >= 0) {
      msgs[idx] = updated;
      notifyListeners();
    }
  }

  void _onSnapViewed(String messageId, String viewedBy) {
    for (final msgs in _messages.values) {
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        final m = msgs[idx];
        if (!m.snapViewedBy.contains(viewedBy)) {
          msgs[idx] = m.copyWith(snapViewedBy: [...m.snapViewedBy, viewedBy]);
          notifyListeners();
        }
        break;
      }
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
    _socket.removeSnapViewedListener(_onSnapViewed);
    super.dispose();
  }
}
