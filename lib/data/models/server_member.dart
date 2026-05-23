import 'package:cloud_firestore/cloud_firestore.dart';

class ServerMemberInfo {
  final String uid;
  final String displayName;
  final String nickname;
  final String role;
  final String? serverNickname;
  final bool canCreateChannel;

  ServerMemberInfo({
    required this.uid,
    required this.displayName,
    required this.nickname,
    required this.role,
    this.serverNickname,
    this.canCreateChannel = false,
  });

  String get effectiveName =>
      (serverNickname != null && serverNickname!.isNotEmpty)
          ? serverNickname!
          : displayName;

  bool get isAdmin => role == 'admin';

  bool get canManageChannels => isAdmin || canCreateChannel;
}

class ServerMember {
  final String userId;
  final String role; // 'admin' | 'member'
  final String? serverNickname; // null = dùng displayName toàn cục
  final bool canCreateChannel;
  final DateTime joinedAt;
  final Map<String, int> channelReads; // channelId -> messageCount đã đọc

  ServerMember({
    required this.userId,
    required this.role,
    this.serverNickname,
    this.canCreateChannel = false,
    required this.joinedAt,
    this.channelReads = const {},
  });

  bool get isAdmin => role == 'admin';

  bool get canManageChannels => isAdmin || canCreateChannel;

  factory ServerMember.fromMap(Map<String, dynamic> map, String userId) {
    final raw = map['joinedAt'];
    final readsRaw = map['channelReads'] as Map<String, dynamic>?;
    final reads = <String, int>{};
    if (readsRaw != null) {
      readsRaw.forEach((k, v) {
        if (v is num) reads[k] = v.toInt();
      });
    }
    return ServerMember(
      userId: userId,
      role: map['role'] ?? 'member',
      serverNickname: map['serverNickname'] as String?,
      canCreateChannel: map['canCreateChannel'] ?? false,
      joinedAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
      channelReads: reads,
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'serverNickname': serverNickname,
        'canCreateChannel': canCreateChannel,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'channelReads': channelReads,
      };
}
