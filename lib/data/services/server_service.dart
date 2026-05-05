import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/server.dart';
import '../models/channel.dart';

class ServerService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> createServer(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final serverRef = _db.collection('servers').doc();

    await serverRef.set({
      'name': name,
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await serverRef.collection('members').doc(user.uid).set({
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await serverRef.collection('channels').doc('general').set({
      'name': 'general',
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await serverRef.collection('channels').doc('voice-1').set({
      'name': 'Voice 1',
      'type': 'voice',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> createChannel({
    required String serverId,
    required String name,
    required String type,
  }) async {
    final cleanName = name.trim().toLowerCase().replaceAll(' ', '-');

    if (cleanName.isEmpty) return;

    await _db
        .collection('servers')
        .doc(serverId)
        .collection('channels')
        .add({
      'name': cleanName,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<String?> getUserRole(String serverId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db
        .collection('servers')
        .doc(serverId)
        .collection('members')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;

    return doc.data()?['role'];
  }

  Stream<List<Server>> getMyServers() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _db.collection('servers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Server(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Server',
          ownerId: data['ownerId'] ?? '',
          createdAt: data['createdAt'] == null
              ? DateTime.now()
              : (data['createdAt'] as Timestamp).toDate(),
        );
      }).toList();
    });
  }

  Stream<List<ServerChannel>> getChannels(String serverId) {
    return _db
        .collection('servers')
        .doc(serverId)
        .collection('channels')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return ServerChannel(
          id: doc.id,
          name: data['name'] ?? 'unnamed',
          type: data['type'] ?? 'text',
        );
      }).toList();
    });
  }
}