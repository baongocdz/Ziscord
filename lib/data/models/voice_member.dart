import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceMember {
  final String uid;
  final String displayName;
  final String? photoURL;
  final bool isMuted;
  final DateTime joinedAt;

  VoiceMember({
    required this.uid,
    required this.displayName,
    this.photoURL,
    required this.isMuted,
    required this.joinedAt,
  });

  factory VoiceMember.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['joinedAt'];
    return VoiceMember(
      uid: id,
      displayName: map['displayName'] ?? id,
      photoURL: map['photoURL'] as String?,
      isMuted: map['isMuted'] == true,
      joinedAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}
