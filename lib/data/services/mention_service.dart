import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mention_record.dart';

class MentionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('mention_inbox');

  Stream<List<MentionRecord>> streamMentions(String uid) {
    return _inbox(uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                MentionRecord.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<int> streamUnreadCount(String uid) {
    return _inbox(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Unread mention counts per channel in a single server. Keyed by channelId.
  Stream<Map<String, int>> streamServerChannelMentionCounts(
      String uid, String serverId) {
    return _inbox(uid)
        .where('read', isEqualTo: false)
        .where('context', isEqualTo: 'channel')
        .where('serverId', isEqualTo: serverId)
        .snapshots()
        .map((snap) {
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final cid = data['channelId'] as String?;
        if (cid == null) continue;
        counts[cid] = (counts[cid] ?? 0) + 1;
      }
      return counts;
    });
  }

  Future<void> markAsRead(String uid, String mentionId) {
    return _inbox(uid).doc(mentionId).update({'read': true});
  }

  Future<void> markAllAsRead(String uid) async {
    final snap = await _inbox(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Marks every unread channel-mention in a given channel as read.
  Future<void> markChannelMentionsAsRead(
      String uid, String serverId, String channelId) async {
    final snap = await _inbox(uid)
        .where('read', isEqualTo: false)
        .where('context', isEqualTo: 'channel')
        .where('serverId', isEqualTo: serverId)
        .where('channelId', isEqualTo: channelId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String uid, String mentionId) {
    return _inbox(uid).doc(mentionId).delete();
  }

  /// Writes mention inbox records for a DM message.
  Future<void> recordDmMentions({
    required List<String> mentionedUids,
    required String senderId,
    required String senderName,
    required String messageId,
    required String messageText,
  }) async {
    if (mentionedUids.isEmpty) return;
    final batch = _db.batch();
    final preview = _preview(messageText);
    for (final uid in mentionedUids) {
      if (uid == senderId) continue; // never notify self
      final ref = _inbox(uid).doc();
      batch.set(ref, {
        'context': 'dm',
        'fromUserId': senderId,
        'fromUserName': senderName,
        'messageId': messageId,
        'messagePreview': preview,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
    await batch.commit();
  }

  /// Writes mention inbox records for a channel message.
  Future<void> recordChannelMentions({
    required List<String> mentionedUids,
    required String senderId,
    required String senderName,
    required String messageId,
    required String messageText,
    required String serverId,
    required String channelId,
    required String serverName,
    required String channelName,
  }) async {
    if (mentionedUids.isEmpty) return;
    final batch = _db.batch();
    final preview = _preview(messageText);
    for (final uid in mentionedUids) {
      if (uid == senderId) continue;
      final ref = _inbox(uid).doc();
      batch.set(ref, {
        'context': 'channel',
        'fromUserId': senderId,
        'fromUserName': senderName,
        'messageId': messageId,
        'messagePreview': preview,
        'serverId': serverId,
        'channelId': channelId,
        'serverName': serverName,
        'channelName': channelName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
    await batch.commit();
  }

  String _preview(String text) {
    if (text.isEmpty) return '📷 Ảnh';
    return text.length > 100 ? '${text.substring(0, 100)}…' : text;
  }
}
