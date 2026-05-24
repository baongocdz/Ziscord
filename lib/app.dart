import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/auth/login_page.dart';
import 'features/main/main_scaffold.dart';

class MyApp extends StatelessWidget {
  final User? initialUser;
  const MyApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, theme, _) {
        // KeyedSubtree with a key tied to the theme forces the home page
        // (and its descendants) to remount when the theme changes. This is
        // needed because `AppColors.*` is a runtime getter rather than a
        // context lookup — without the key, the Navigator-cached route keeps
        // stale color values on screen.
        return MaterialApp(
          title: 'Ziscord',
          theme: theme.themeData,
          home: KeyedSubtree(
            key: ValueKey(theme),
            child: initialUser != null
                ? const MainScaffold()
                : const LoginPage(),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
