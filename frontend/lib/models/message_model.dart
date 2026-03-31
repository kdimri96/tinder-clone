import 'user_model.dart';

class MessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final UserModel? sender;
  final String text;
  final String? mediaUrl;
  final List<String> readBy;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    this.sender,
    required this.text,
    this.mediaUrl,
    this.readBy = const [],
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    UserModel? sender;
    if (json['senderId'] is Map) {
      sender = UserModel.fromJson(json['senderId']);
    }

    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      senderId: sender?.id ?? (json['senderId'] is String ? json['senderId'] : ''),
      sender: sender,
      text: json['text'] ?? '',
      mediaUrl: json['mediaUrl'],
      readBy: List<String>.from(json['readBy'] ?? []),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool isReadBy(String userId) => readBy.contains(userId);
}
