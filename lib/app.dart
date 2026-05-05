import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data/services/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';

class ZiscordApp extends StatelessWidget {
  const ZiscordApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'Ziscord',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomePage();
          }

          return const LoginPage();
        },
      ),
    );
  }
}