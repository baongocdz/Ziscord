import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dm_message.dart';
import '../models/friend.dart';
import 'mention_service.dart';

class DMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MentionService _mentionService = MentionService();

  String getChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<DMMessage>> streamMessages(String currentUserId, String otherUserId) {
    final chatId = getChatId(currentUserId, otherUserId);

    return _firestore
        .collection('dm_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DMMessage.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
  Stream<ChatPreview> streamChatPreview(String currentUserId, String otherUserId) {
    final chatId = getChatId(currentUserId, otherUserId);

    return _firestore.collection('dm_chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) {
        return ChatPreview(lastMessage: 'Chưa có tin nhắn', updatedAt: null);
      }

      final data = doc.data() ?? {};
      final rawUpdatedAt = data['updatedAt'];
      final updatedAt = rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null;

      final messageCount = (data['messageCount'] as num?)?.toInt() ?? 0;
      final lastReadCount = ((data['lastReadCount']
              as Map<String, dynamic>?)?[currentUserId] as num?)
              ?.toInt() ??
          0;
      final unread = (messageCount - lastReadCount).clamp(0, 999999);

      return ChatPreview(
        lastMessage: data['lastMessage'] ?? 'Chưa có tin nhắn',
        updatedAt: updatedAt,
        isUnread: unread > 0,
        unreadCount: unread,
      );
    });
  }

  /// Total unread DM messages across all chats this user participates in.
  Stream<int> streamTotalUnread(String currentUserId) {
    return _firestore
        .collection('dm_chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final messageCount = (data['messageCount'] as num?)?.toInt() ?? 0;
        final lastReadCount = ((data['lastReadCount']
                as Map<String, dynamic>?)?[currentUserId] as num?)
                ?.toInt() ??
            0;
        final unread = messageCount - lastReadCount;
        if (unread > 0) total += unread;
      }
      return total;
    });
  }

  Future<void> markAsRead(String currentUserId, String otherUserId) async {
    final chatId = getChatId(currentUserId, otherUserId);
    final ref = _firestore.collection('dm_chats').doc(chatId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final messageCount =
        ((doc.data() ?? {})['messageCount'] as num?)?.toInt() ?? 0;
    await ref.update({
      'lastRead.$currentUserId': FieldValue.serverTimestamp(),
      'lastReadCount.$currentUserId': messageCount,
    });
  }

  Future<List<MessageSearchResult>> searchMessages({
    required String currentUserId,
    required List<Friend> friends,
    required String query,
  }) async {
    final keyword = query.trim().toLowerCase();

    if (keyword.isEmpty) return [];

    final List<MessageSearchResult> results = [];

    for (final friend in friends) {
      final chatId = getChatId(currentUserId, friend.uid);

      final snapshot = await _firestore
          .collection('dm_chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(80)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final text = (data['text'] ?? '').toString();

        if (text.toLowerCase().contains(keyword)) {
          final rawTimestamp = data['timestamp'];

          results.add(
            MessageSearchResult(
              friendUid: friend.uid,
              friendName: friend.displayName,
              messageText: text,
              timestamp: rawTimestamp is Timestamp
                  ? rawTimestamp.toDate()
                  : DateTime.now(),
            ),
          );
        }
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  Future<void> editMessage({
    required String senderId,
    required String receiverId,
    required String messageId,
    required String newText,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    await _firestore
        .collection('dm_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true});
  }

  Future<void> deleteMessage({
    required String senderId,
    required String receiverId,
    required String messageId,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    await _firestore
        .collection('dm_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> toggleReaction({
    required String senderId,
    required String receiverId,
    required String messageId,
    required String emoji,
    required String uid,
    required bool hasReacted,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final ref = _firestore
        .collection('dm_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    if (hasReacted) {
      await ref.update({'reactions.$emoji': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'reactions.$emoji': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
    List<String> mentions = const [],
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final chatRef = _firestore.collection('dm_chats').doc(chatId);

    await chatRef.set({
      'participants': [senderId, receiverId],
      'lastMessage': imageUrl != null && text.isEmpty ? '📷 Ảnh' : text,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRead': {senderId: FieldValue.serverTimestamp()},
      'messageCount': FieldValue.increment(1),
      'lastReadCount': {senderId: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    final msg = <String, dynamic>{
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (imageUrl != null) msg['imageUrl'] = imageUrl;
    if (replyToId != null) {
      msg['replyToId'] = replyToId;
      msg['replyToSenderName'] = replyToSenderName;
      msg['replyToText'] = replyToText;
    }
    if (mentions.isNotEmpty) msg['mentions'] = mentions;
    final msgRef = await chatRef.collection('messages').add(msg);

    if (mentions.isNotEmpty) {
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final senderName =
          (senderDoc.data())?['displayName'] as String? ?? 'Người dùng';
      await _mentionService.recordDmMentions(
        mentionedUids: mentions,
        senderId: senderId,
        senderName: senderName,
        messageId: msgRef.id,
        messageText: text,
      );
    }
  }
}
class ChatPreview {
  final String lastMessage;
  final DateTime? updatedAt;
  final bool isUnread;
  final int unreadCount;

  ChatPreview({
    required this.lastMessage,
    required this.updatedAt,
    this.isUnread = false,
    this.unreadCount = 0,
  });
}

class MessageSearchResult {
  final String friendUid;
  final String friendName;
  final String messageText;
  final DateTime timestamp;

  MessageSearchResult({
    required this.friendUid,
    required this.friendName,
    required this.messageText,
    required this.timestamp,
  });
}