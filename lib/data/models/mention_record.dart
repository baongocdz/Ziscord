import 'package:cloud_firestore/cloud_firestore.dart';

/// A mention notification record stored in `users/{uid}/mention_inbox`.
class MentionRecord {
  final String id;
  final String context; // 'dm' | 'channel'
  final String fromUserId;
  final String fromUserName;
  final String messageId;
  final String messagePreview;
  final DateTime timestamp;
  final bool read;

  // Channel context
  final String? serverId;
  final String? channelId;
  final String? serverName;
  final String? channelName;

  MentionRecord({
    required this.id,
    required this.context,
    required this.fromUserId,
    required this.fromUserName,
    required this.messageId,
    required this.messagePreview,
    required this.timestamp,
    required this.read,
    this.serverId,
    this.channelId,
    this.serverName,
    this.channelName,
  });

  bool get isChannel => context == 'channel';
  bool get isDm => context == 'dm';

  factory MentionRecord.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['timestamp'];
    return MentionRecord(
      id: id,
      context: map['context'] ?? 'dm',
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? '',
      messageId: map['messageId'] ?? '',
      messagePreview: map['messagePreview'] ?? '',
      timestamp: raw is Timestamp ? raw.toDate() : DateTime.now(),
      read: map['read'] == true,
      serverId: map['serverId'] as String?,
      channelId: map['channelId'] as String?,
      serverName: map['serverName'] as String?,
      channelName: map['channelName'] as String?,
    );
  }
}
