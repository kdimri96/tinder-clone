import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message_model.dart';
import '../models/match_model.dart';

typedef MessageCallback = void Function(MessageModel message);
typedef MatchCallback = void Function(MatchModel match);
typedef TypingCallback = void Function(String userId, bool isTyping);
typedef PresenceCallback = void Function(String userId, bool isOnline);

class SocketService {
  static const String _baseUrl = 'http://10.0.2.2:3000';
  IO.Socket? _socket;

  final List<MessageCallback> _messageListeners = [];
  final List<MatchCallback> _matchListeners = [];
  final List<TypingCallback> _typingListeners = [];
  final List<PresenceCallback> _presenceListeners = [];

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    _socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
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
      for (final listener in _typingListeners) {
        listener(data['userId'], true);
      }
    });

    _socket!.on('typing:stop', (data) {
      for (final listener in _typingListeners) {
        listener(data['userId'], false);
      }
    });

    _socket!.on('presence:online', (data) {
      for (final listener in _presenceListeners) {
        listener(data['userId'], true);
      }
    });

    _socket!.on('presence:offline', (data) {
      for (final listener in _presenceListeners) {
        listener(data['userId'], false);
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void sendMessage(String matchId, String text, {Function(dynamic)? onSuccess, Function(dynamic)? onError}) {
    _socket?.emitWithAck('chat:send', {'matchId': matchId, 'text': text}, ack: (response) {
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

  void removeMessageListener(MessageCallback callback) => _messageListeners.remove(callback);
  void removeMatchListener(MatchCallback callback) => _matchListeners.remove(callback);
  void removeTypingListener(TypingCallback callback) => _typingListeners.remove(callback);
  void removePresenceListener(PresenceCallback callback) => _presenceListeners.remove(callback);
}
