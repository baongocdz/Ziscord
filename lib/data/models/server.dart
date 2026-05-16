import 'package:cloud_firestore/cloud_firestore.dart';

class Server {
  final String id;
  final String name;
  final String ownerId;
  final String? iconUrl;
  final bool isPublic;
  final String inviteCode;
  final DateTime createdAt;

  Server({
    required this.id,
    required this.name,
    required this.ownerId,
    this.iconUrl,
    required this.isPublic,
    required this.inviteCode,
    required this.createdAt,
  });

  factory Server.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['createdAt'];
    return Server(
      id: id,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      iconUrl: map['iconUrl'],
      isPublic: map['isPublic'] ?? false,
      inviteCode: map['inviteCode'] ?? '',
      createdAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerId': ownerId,
        'iconUrl': iconUrl,
        'isPublic': isPublic,
        'inviteCode': inviteCode,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
