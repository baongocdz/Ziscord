import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryPost {
  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final DateTime timestamp;
  final int commentCount;

  LibraryPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.commentCount,
  });

  factory LibraryPost.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['timestamp'];
    return LibraryPost(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: raw is Timestamp ? raw.toDate() : DateTime.now(),
      commentCount: (map['commentCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'title': title,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'commentCount': commentCount,
      };
}
