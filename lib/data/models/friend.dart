class Friend {
  final String uid;
  final String displayName;
  final String nickname;
  final String? photoURL;

  Friend({
    required this.uid,
    required this.displayName,
    required this.nickname,
    this.photoURL,
  });

  factory Friend.fromMap(String uid, Map<String, dynamic> map) {
    return Friend(
      uid: uid,
      displayName: map['displayName'] ?? '',
      nickname: map['nickname'] ?? '',
      photoURL: map['photoURL'] as String?,
    );
  }
}
