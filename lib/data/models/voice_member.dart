import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceMember {
  final String uid;
  final String displayName;
  final String? photoURL;
  final bool isMuted;
  final bool isListenOnly;
  final DateTime joinedAt;

  VoiceMember({
    required this.uid,
    required this.displayName,
    this.photoURL,
    required this.isMuted,
    this.isListenOnly = false,
    required this.joinedAt,
  });

  factory VoiceMember.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['joinedAt'];
    return VoiceMember(
      uid: id,
      displayName: map['displayName'] ?? id,
      photoURL: map['photoURL'] as String?,
      isMuted: map['isMuted'] == true,
      isListenOnly: map['isListenOnly'] == true,
      joinedAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}
