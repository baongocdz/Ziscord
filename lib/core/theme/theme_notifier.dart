import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeNotifier extends ValueNotifier<AppThemeOption> {
  static const String _prefKey = 'selected_theme';
  static final ThemeNotifier _instance =
      ThemeNotifier._(AppThemeOption.discord);

  ThemeNotifier._(AppThemeOption initialTheme) : super(initialTheme);

  static ThemeNotifier get instance => _instance;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_prefKey);
    if (themeName != null) {
      try {
        final theme =
            AppThemeOption.values.firstWhere((t) => t.name == themeName);
        value = theme;
      } catch (e) {
        // theme not found, keep default
      }
    }
  }

  Future<void> setTheme(AppThemeOption theme) async {
    value = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, theme.name);
  }
}
