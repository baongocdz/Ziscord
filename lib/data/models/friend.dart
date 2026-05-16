class Friend {
  final String uid;
  final String displayName;
  final String nickname;

  Friend({
    required this.uid,
    required this.displayName,
    required this.nickname,
  });

  factory Friend.fromMap(String uid, Map<String, dynamic> map) {
    return Friend(
      uid: uid,
      displayName: map['displayName'] ?? '',
      nickname: map['nickname'] ?? '',
    );
  }
}