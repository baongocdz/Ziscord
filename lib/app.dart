import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/main/main_scaffold.dart';

class MyApp extends StatelessWidget {
  final User? initialUser;
  const MyApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ziscord',
      theme: AppTheme.dark,
      home: initialUser != null ? const MainScaffold() : const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
