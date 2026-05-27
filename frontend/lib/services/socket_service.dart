import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../utils/app_config.dart';

typedef MessageCallback = void Function(MessageModel message);
typedef MatchCallback = void Function(MatchModel match);
// matchId included so ChatProvider can key typing status per-conversation
typedef TypingCallback = void Function(String matchId, String userId, bool isTyping);
typedef PresenceCallback = void Function(String userId, bool isOnline);
typedef LikedYouCallback = void Function();
typedef ChatNotificationCallback = void Function(String matchId, String senderName, String text);
typedef SnapViewedCallback = void Function(String messageId, String viewedBy);

class SocketService {
  static String get _baseUrl => AppConfig.socketBaseUrl;

  IO.Socket? _socket;

  final List<MessageCallback> _messageListeners = [];
  final List<MatchCallback> _matchListeners = [];
  final List<TypingCallback> _typingListeners = [];
  final List<PresenceCallback> _presenceListeners = [];
  final List<LikedYouCallback> _likedYouListeners = [];
  final List<ChatNotificationCallback> _chatNotificationListeners = [];
  final List<SnapViewedCallback> _snapViewedListeners = [];
  final List<VoidCallback> _reconnectListeners = [];

  // Live online-status map so any widget can call isUserOnline() synchronously
  final Map<String, bool> _onlineStatus = {};

  bool get isConnected => _socket?.connected ?? false;
  bool isUserOnline(String userId) => _onlineStatus[userId] ?? false;

  void connect(String token) {
    _socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .build(),
    );

    bool _firstConnect = true;
    _socket!.onConnect((_) {
      print('Socket connected');
      if (!_firstConnect) {
        // Reconnect after a drop — notify listeners so they can refresh data
        for (final cb in _reconnectListeners) {
          cb();
        }
      }
      _firstConnect = false;
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onConnectError((data) {
      print('Socket connection error: $data');
    });

    _socket!.on('chat:message', (data) {
      try {
        final message = MessageModel.fromJson(data['message']);
        for (final listener in _messageListeners) {
          listener(message);
        }
      } catch (e) {
        print('Error parsing message: $e');
      }
    });

    _socket!.on('match', (data) {
      try {
        final match = MatchModel.fromJson(data['match']);
        for (final listener in _matchListeners) {
          listener(match);
        }
      } catch (e) {
        print('Error parsing match: $e');
      }
    });

    _socket!.on('typing:start', (data) {
      final matchId = (data['matchId'] ?? '').toString();
      final userId = (data['userId'] ?? '').toString();
      for (final listener in _typingListeners) {
        listener(matchId, userId, true);
      }
    });

    _socket!.on('typing:stop', (data) {
      final matchId = (data['matchId'] ?? '').toString();
      final userId = (data['userId'] ?? '').toString();
      for (final listener in _typingListeners) {
        listener(matchId, userId, false);
      }
    });

    _socket!.on('presence:online', (data) {
      final userId = (data['userId'] ?? '').toString();
      _onlineStatus[userId] = true;
      for (final listener in _presenceListeners) {
        listener(userId, true);
      }
    });

    _socket!.on('presence:offline', (data) {
      final userId = (data['userId'] ?? '').toString();
      _onlineStatus[userId] = false;
      for (final listener in _presenceListeners) {
        listener(userId, false);
      }
    });

    _socket!.on('liked:you', (_) {
      for (final listener in _likedYouListeners) {
        listener();
      }
    });

    _socket!.on('chat:notification', (data) {
      for (final listener in _chatNotificationListeners) {
        listener(
          (data['matchId'] ?? '').toString(),
          (data['senderName'] ?? 'Someone').toString(),
          (data['text'] ?? 'New message').toString(),
        );
      }
    });

    _socket!.on('snap:viewed', (data) {
      final messageId = (data['messageId'] ?? '').toString();
      final viewedBy = (data['viewedBy'] ?? '').toString();
      for (final listener in _snapViewedListeners) {
        listener(messageId, viewedBy);
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _onlineStatus.clear();
  }

  void sendMessage(String matchId, String text,
      {Function(dynamic)? onSuccess, Function(dynamic)? onError}) {
    _socket?.emitWithAck('chat:send', {'matchId': matchId, 'text': text},
        ack: (response) {
      if (response['success'] == true) {
        onSuccess?.call(response);
      } else {
        onError?.call(response['error']);
      }
    });
  }

  void markRead(String matchId) {
    _socket?.emit('chat:read', {'matchId': matchId});
  }

  void startTyping(String matchId) {
    _socket?.emit('typing:start', {'matchId': matchId});
  }

  void stopTyping(String matchId) {
    _socket?.emit('typing:stop', {'matchId': matchId});
  }

  void joinMatchRoom(String matchId) {
    _socket?.emit('match:join', {'matchId': matchId});
  }

  void onMessage(MessageCallback callback) => _messageListeners.add(callback);
  void onMatch(MatchCallback callback) => _matchListeners.add(callback);
  void onTyping(TypingCallback callback) => _typingListeners.add(callback);
  void onPresence(PresenceCallback callback) => _presenceListeners.add(callback);
  void onLikedYou(LikedYouCallback callback) => _likedYouListeners.add(callback);
  void onChatNotification(ChatNotificationCallback callback) =>
      _chatNotificationListeners.add(callback);
  void onSnapViewed(SnapViewedCallback callback) =>
      _snapViewedListeners.add(callback);
  void onReconnect(VoidCallback callback) => _reconnectListeners.add(callback);

  void removeMessageListener(MessageCallback callback) =>
      _messageListeners.remove(callback);
  void removeMatchListener(MatchCallback callback) =>
      _matchListeners.remove(callback);
  void removeTypingListener(TypingCallback callback) =>
      _typingListeners.remove(callback);
  void removePresenceListener(PresenceCallback callback) =>
      _presenceListeners.remove(callback);
  void removeLikedYouListener(LikedYouCallback callback) =>
      _likedYouListeners.remove(callback);
  void removeChatNotificationListener(ChatNotificationCallback callback) =>
      _chatNotificationListeners.remove(callback);
  void removeSnapViewedListener(SnapViewedCallback callback) =>
      _snapViewedListeners.remove(callback);
  void removeReconnectListener(VoidCallback callback) =>
      _reconnectListeners.remove(callback);
}
