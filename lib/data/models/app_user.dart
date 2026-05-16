class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String nickname;
  final String? photoURL;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.nickname,
    this.photoURL,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      nickname: map['nickname'] ?? '',
      photoURL: map['photoURL'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'nickname': nickname,
      'photoURL': photoURL,
    };
  }
}