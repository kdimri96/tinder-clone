import 'user_model.dart';
import 'message_model.dart';

class MatchModel {
  final String id;
  final List<UserModel> users;
  final UserModel? otherUser;
  final MessageModel? lastMessage;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final bool isSuperLike;
  final String? superLikeBy;

  MatchModel({
    required this.id,
    required this.users,
    this.otherUser,
    this.lastMessage,
    required this.createdAt,
    this.lastMessageAt,
    this.isSuperLike = false,
    this.superLikeBy,
  });

  MatchModel copyWith({MessageModel? lastMessage, DateTime? lastMessageAt}) {
    return MatchModel(
      id: id,
      users: users,
      otherUser: otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isSuperLike: isSuperLike,
      superLikeBy: superLikeBy,
    );
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final usersList = (json['users'] as List?)
        ?.map((u) => UserModel.fromJson(u))
        .toList() ?? [];

    UserModel? other;
    if (json['otherUser'] != null) {
      other = UserModel.fromJson(json['otherUser']);
    }

    return MatchModel(
      id: json['_id'] ?? json['id'] ?? '',
      users: usersList,
      otherUser: other,
      lastMessage: json['lastMessage'] != null && json['lastMessage'] is Map
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'])
          : null,
      isSuperLike: json['isSuperLike'] == true,
      superLikeBy: json['superLikeBy']?.toString(),
    );
  }
}
