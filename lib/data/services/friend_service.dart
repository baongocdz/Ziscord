import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request.dart';
import '../models/friend.dart';


class FriendService {
  final CollectionReference friends = FirebaseFirestore.instance.collection('friends');
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final CollectionReference friendRequests = FirebaseFirestore.instance.collection('friend_requests');

  // Gửi request bằng email
  Future<String> sendFriendRequest(String fromUid, String toEmail) async {
    final query = await users.where('email', isEqualTo: toEmail).get();
    if (query.docs.isEmpty) return 'Người dùng không tồn tại';

    final toUid = query.docs.first.id;

    // ⚡ Không cho gửi request cho chính mình
    if (fromUid == toUid) return 'Không thể gửi request cho chính mình';

    if (await isFriend(fromUid, toUid)) return 'Đã là bạn bè';

    // Cho phép gửi lại nếu request cũ đã bị reject; chặn nếu còn pending/accepted
    final existing = await friendRequests
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .get();
    for (final doc in existing.docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'];
      if (status == 'rejected') {
        await doc.reference.delete();
      } else {
        return 'Đã gửi request trước đó';
      }
    }

    await friendRequests.add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'timestamp': DateTime.now(),
    });

    return 'Đã gửi request';
  }

  // Stream request tới user hiện tại
  Stream<List<FriendRequest>> streamIncomingRequests(String uid) {
    return friendRequests.where('to', isEqualTo: uid).snapshots().map((snap) {
      return snap.docs.map((doc) => FriendRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  Stream<int> streamPendingCount(String uid) {
    return friendRequests
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Stream danh sách bạn bè
  Stream<List<Friend>> streamFriends(String uid) {
    return friends.doc(uid).collection('my_friends').snapshots().asyncMap((snap) async {
      final result = <Friend>[];

      for (final doc in snap.docs) {
        final userDoc = await users.doc(doc.id).get();
        if (userDoc.exists) {
          result.add(Friend.fromMap(userDoc.id, userDoc.data() as Map<String, dynamic>));
        }
      }

      return result;
    });
  }

  Future<bool> isFriend(String uid, String otherUid) async {
    final doc = await friends.doc(uid).collection('my_friends').doc(otherUid).get();
    return doc.exists;
  }

  Future<String> sendFriendRequestByUid(String fromUid, String toUid) async {
    if (fromUid == toUid) return 'Không thể gửi request cho chính mình';
    final alreadyFriend = await isFriend(fromUid, toUid);
    if (alreadyFriend) return 'Đã là bạn bè';
    final existing = await friendRequests
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .get();
    for (final doc in existing.docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'];
      if (status == 'rejected') {
        await doc.reference.delete();
      } else {
        return 'Đã gửi request trước đó';
      }
    }
    await friendRequests.add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'timestamp': DateTime.now(),
    });
    return 'Đã gửi lời mời kết bạn';
  }

  Future<void> rejectRequest(FriendRequest req) async {
    await friendRequests.doc(req.id).delete();
  }

  Future<void> removeFriend(String uid, String otherUid) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(friends.doc(uid).collection('my_friends').doc(otherUid));
    batch.delete(friends.doc(otherUid).collection('my_friends').doc(uid));

    final q1 = await friendRequests
        .where('from', isEqualTo: uid)
        .where('to', isEqualTo: otherUid)
        .get();
    final q2 = await friendRequests
        .where('from', isEqualTo: otherUid)
        .where('to', isEqualTo: uid)
        .get();
    for (final doc in [...q1.docs, ...q2.docs]) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Accept request
  Future<void> acceptRequest(FriendRequest req) async {
    await friendRequests.doc(req.id).update({'status': 'accepted'});

    // Tạo record friend cho cả 2
    await friends.doc(req.fromUid).collection('my_friends').doc(req.toUid).set({'since': DateTime.now()});
    await friends.doc(req.toUid).collection('my_friends').doc(req.fromUid).set({'since': DateTime.now()});
  }
}