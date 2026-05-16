
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String status; // pending / accepted / rejected
  final DateTime timestamp;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.timestamp,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> map, String id) {
    return FriendRequest(
      id: id,
      fromUid: map['from'],
      toUid: map['to'],
      status: map['status'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from': fromUid,
      'to': toUid,
      'status': status,
      'timestamp': timestamp,
    };
  }
}