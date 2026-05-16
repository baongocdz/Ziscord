import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class UserService {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  Future<void> createUser(AppUser user) async {
    await users.doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUserById(String uid) async {
    final doc = await users.doc(uid).get();

    if (!doc.exists) return null;

    return AppUser.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> updateProfile({
    required String displayName,
    required String nickname,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await users.doc(currentUser.uid).update({
      'displayName': displayName,
      'nickname': nickname,
    });
  }

  Future<void> updateAvatar(String url) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await users.doc(currentUser.uid).update({
      'photoURL': url,
    });
  }
}