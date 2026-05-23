class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String nickname;
  final String? photoURL;
  final String? bannerURL;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.nickname,
    this.photoURL,
    this.bannerURL,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      nickname: map['nickname'] ?? '',
      photoURL: map['photoURL'],
      bannerURL: map['bannerURL'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'nickname': nickname,
      'photoURL': photoURL,
      'bannerURL': bannerURL,
    };
  }
}
