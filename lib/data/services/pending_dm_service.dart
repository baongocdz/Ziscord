import 'package:cloud_firestore/cloud_firestore.dart';

/// Tin nhắn từ người chưa phải bạn bè được lưu vào pending_dms/{toUid}/messages
class PendingDmService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _inbox(String uid) =>
      _db.collection('pending_dms').doc(uid).collection('messages');

  Future<void> sendPendingMessage({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String text,
  }) async {
    await _inbox(toUid).add({
      'fromUid': fromUid,
      'fromName': fromName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Stream<List<PendingMessage>> streamInbox(String uid) {
    return _inbox(uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                PendingMessage.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> markRead(String uid, String messageId) async {
    await _inbox(uid).doc(messageId).update({'read': true});
  }

  Future<void> deleteMessage(String uid, String messageId) async {
    await _inbox(uid).doc(messageId).delete();
  }

  Stream<int> streamUnreadCount(String uid) {
    return _inbox(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}

class PendingMessage {
  final String id;
  final String fromUid;
  final String fromName;
  final String text;
  final DateTime timestamp;
  final bool read;

  PendingMessage({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.text,
    required this.timestamp,
    required this.read,
  });

  factory PendingMessage.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['timestamp'];
    return PendingMessage(
      id: id,
      fromUid: map['fromUid'] ?? '',
      fromName: map['fromName'] ?? '',
      text: map['text'] ?? '',
      timestamp: raw is Timestamp ? raw.toDate() : DateTime.now(),
      read: map['read'] == true,
    );
  }
}
