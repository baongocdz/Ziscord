import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  final String uid;
  final String displayName;
  final String? photoURL;
  final DateTime requestedAt;

  JoinRequest({
    required this.uid,
    required this.displayName,
    this.photoURL,
    required this.requestedAt,
  });

  factory JoinRequest.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['requestedAt'];
    return JoinRequest(
      uid: id,
      displayName: map['displayName'] ?? id,
      photoURL: map['photoURL'] as String?,
      requestedAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}
