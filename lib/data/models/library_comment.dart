import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryComment {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime timestamp;

  LibraryComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.timestamp,
  });

  factory LibraryComment.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['timestamp'];
    return LibraryComment(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      text: map['text'] ?? '',
      timestamp: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}
