import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/theme_notifier.dart';
import 'firebase_options.dart';
import 'app.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await ThemeNotifier.instance.init();

  // Lấy user hiện tại
  final User? currentUser = FirebaseAuth.instance.currentUser;

  runApp(MyApp(initialUser: currentUser));
}