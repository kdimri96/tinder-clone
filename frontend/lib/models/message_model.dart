import 'user_model.dart';

enum MediaType { image, audio, snap }

class MessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final UserModel? sender;
  final String text;
  final String? mediaUrl;
  final MediaType? mediaType;
  final int? audioDuration;   // seconds
  final bool isSnap;
  final List<String> snapViewedBy;
  final List<String> readBy;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    this.sender,
    required this.text,
    this.mediaUrl,
    this.mediaType,
    this.audioDuration,
    this.isSnap = false,
    this.snapViewedBy = const [],
    this.readBy = const [],
    required this.createdAt,
  });

  bool get isAudio => mediaType == MediaType.audio;
  bool get isSnapMessage => isSnap || mediaType == MediaType.snap;
  bool get isPhoto => mediaType == MediaType.image ||
      (mediaUrl != null && mediaUrl!.isNotEmpty && !isAudio && !isSnapMessage);

  bool isReadBy(String userId) => readBy.contains(userId);
  bool isSnapViewedBy(String userId) => snapViewedBy.contains(userId);

  MessageModel copyWith({List<String>? snapViewedBy, List<String>? readBy, String? mediaUrl}) {
    return MessageModel(
      id: id,
      matchId: matchId,
      senderId: senderId,
      sender: sender,
      text: text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType,
      audioDuration: audioDuration,
      isSnap: isSnap,
      snapViewedBy: snapViewedBy ?? this.snapViewedBy,
      readBy: readBy ?? this.readBy,
      createdAt: createdAt,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    UserModel? sender;
    if (json['senderId'] is Map) {
      sender = UserModel.fromJson(json['senderId']);
    }

    MediaType? mediaType;
    final mt = json['mediaType'];
    if (mt == 'audio') mediaType = MediaType.audio;
    else if (mt == 'snap') mediaType = MediaType.snap;
    else if (mt == 'image') mediaType = MediaType.image;
    else if (json['mediaUrl'] != null && json['isSnap'] != true && mt == null) {
      mediaType = MediaType.image;
    }

    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      senderId: sender?.id ?? (json['senderId'] is String ? json['senderId'] : ''),
      sender: sender,
      text: json['text'] ?? '',
      mediaUrl: json['mediaUrl'],
      mediaType: mediaType,
      audioDuration: json['audioDuration'] != null
          ? (json['audioDuration'] as num).toInt()
          : null,
      isSnap: json['isSnap'] == true,
      snapViewedBy: List<String>.from(
          (json['snapViewedBy'] as List? ?? []).map((e) => e.toString())),
      readBy: List<String>.from(json['readBy'] ?? []),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
