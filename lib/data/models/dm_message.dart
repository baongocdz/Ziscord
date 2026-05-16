import 'package:cloud_firestore/cloud_firestore.dart';

class DMMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isEdited;
  final String? imageUrl;
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToText;
  final Map<String, List<String>> reactions;
  final List<String> mentions;

  DMMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.imageUrl,
    this.replyToId,
    this.replyToSenderName,
    this.replyToText,
    this.reactions = const {},
    this.mentions = const [],
  });

  factory DMMessage.fromMap(Map<String, dynamic> map, String id) {
    final rawTimestamp = map['timestamp'];

    return DMMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : DateTime.now(),
      isEdited: map['isEdited'] == true,
      imageUrl: map['imageUrl'] as String?,
      replyToId: map['replyToId'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
      replyToText: map['replyToText'] as String?,
      reactions: (map['reactions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          ) ??
          {},
      mentions: (map['mentions'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}