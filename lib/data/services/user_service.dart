import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

  Future<AppUser?> getUserInfo(String uid, String serverId) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final serverDoc =
        await _db.collection('servers').doc(serverId).collection('members').doc(uid).get();

    final serverData = serverDoc.data();
    final nickname = (serverData != null && serverDoc.exists)
        ? serverData['nickname'] ?? ''
        : '';

    return AppUser(
      uid: uid,
      email: doc.data()?['email'] ?? 'unknown',
      realName: doc.data()?['realName'] ?? 'unknown',
      nickname: nickname,
      joinedAt: (serverData != null && serverDoc.exists && serverData['joinedAt'] != null)
          ? (serverData['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}