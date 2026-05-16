import 'package:cloud_firestore/cloud_firestore.dart';

class ServerMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isEdited;
  final String? imageUrl;
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToText;
  final Map<String, List<String>> reactions;
  final bool isPinned;
  final List<String> mentions;

  ServerMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.imageUrl,
    this.replyToId,
    this.replyToSenderName,
    this.replyToText,
    this.reactions = const {},
    this.isPinned = false,
    this.mentions = const [],
  });

  factory ServerMessage.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['timestamp'];
    return ServerMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      timestamp: raw is Timestamp ? raw.toDate() : DateTime.now(),
      isEdited: map['isEdited'] == true,
      imageUrl: map['imageUrl'] as String?,
      replyToId: map['replyToId'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
      replyToText: map['replyToText'] as String?,
      reactions: (map['reactions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          ) ??
          {},
      isPinned: map['isPinned'] == true,
      mentions: (map['mentions'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      };
}
