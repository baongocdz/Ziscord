import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dm_message.dart';

class DMService {
  final _db = FirebaseFirestore.instance;

  // Tạo chatId duy nhất giữa 2 user
  String _chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<DMMessage>> getMessages(String uid1, String uid2) {
    final chatId = _chatId(uid1, uid2);
    return _db
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages')
        .orderBy('time')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DMMessage(
          senderId: data['senderId'] ?? '',
          senderEmail: data['senderEmail'] ?? 'Unknown',
          content: data['content'] ?? '',
          time: (data['time'] as Timestamp).toDate(),
        );
      }).toList();
    });
  }

  Future<void> sendMessage(String uid1, String uid2, DMMessage message) async {
    final chatId = _chatId(uid1, uid2);
    await _db
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': message.senderId,
      'senderEmail': message.senderEmail,
      'content': message.content,
      'time': Timestamp.fromDate(message.time),
    });
  }
}