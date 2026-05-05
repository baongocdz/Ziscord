import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Message>> getMessages(String serverId, String channelId) {
    return _db
        .collection('servers')
        .doc(serverId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('time')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Message(
          userId: data['userId'] ?? '',
          user: data['user'] ?? 'Unknown',
          content: data['content'] ?? '',
          time: data['time'] == null
              ? DateTime.now()
              : (data['time'] as Timestamp).toDate(),
        );
      }).toList();
    });
  }

  Future<void> sendMessage(
    String serverId,
    String channelId,
    Message message,
  ) async {
    await _db
        .collection('servers')
        .doc(serverId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .add({
      'userId': message.userId,
      'user': message.user,
      'content': message.content,
      'time': Timestamp.fromDate(message.time),
    });
  }
}