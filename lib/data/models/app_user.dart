class AppUser {
  final String uid;
  final String email;
  final String realName;
  final String nickname;
  final DateTime joinedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.realName,
    required this.nickname,
    required this.joinedAt,
  });
}