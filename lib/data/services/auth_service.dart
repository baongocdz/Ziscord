import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  AppUser? currentUserData;

  User? get currentUser => _auth.currentUser;

  Future<AppUser?> register({
    required String email,
    required String password,
    required String displayName,
    required String nickname,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = cred.user;
    if (firebaseUser == null) return null;

    final user = AppUser(
      uid: firebaseUser.uid,
      email: email,
      displayName: displayName,
      nickname: nickname,
      photoURL: null,
    );

    await _userService.createUser(user);
    currentUserData = user;

    return user;
  }

  Future<AppUser?> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = cred.user;
    if (firebaseUser == null) return null;

    currentUserData = await _userService.getUserById(firebaseUser.uid);
    return currentUserData;
  }

  Future<void> loadCurrentUser() async {
    final firebaseUser = currentUser;

    if (firebaseUser == null) {
      currentUserData = null;
      return;
    }

    currentUserData = await _userService.getUserById(firebaseUser.uid);
  }

  Future<void> logout() async {
    currentUserData = null;
    await _auth.signOut();
  }
}