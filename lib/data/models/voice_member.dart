import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceMember {
  final String uid;
  final String displayName;
  final String? photoURL;
  final bool isMuted;
  final bool isListenOnly;
  final bool cameraOn;
  final DateTime joinedAt;

  VoiceMember({
    required this.uid,
    required this.displayName,
    this.photoURL,
    required this.isMuted,
    this.isListenOnly = false,
    this.cameraOn = false,
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
      cameraOn: map['cameraOn'] == true,
      joinedAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}
