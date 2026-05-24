import 'package:flutter/material.dart';

enum AppThemeOption {
  discord,
  light,
  midnight,
  ocean,
}

class ThemePalette {
  final Color serverSidebar;
  final Color channelSidebar;
  final Color background;
  final Color inputBg;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final Color danger;
  final Color divider;
  final Color selectedBg;
  final Color hoverBg;
  final Color messageSelf;
  final Color messageOther;
  final Brightness brightness;

  const ThemePalette({
    required this.serverSidebar,
    required this.channelSidebar,
    required this.background,
    required this.inputBg,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.danger,
    required this.divider,
    required this.selectedBg,
    required this.hoverBg,
    required this.messageSelf,
    required this.messageOther,
    required this.brightness,
  });
}

const _discordPalette = ThemePalette(
  serverSidebar: Color(0xFF1E1F22),
  channelSidebar: Color(0xFF2B2D31),
  background: Color(0xFF313338),
  inputBg: Color(0xFF383A40),
  textPrimary: Color(0xFFDBDEE1),
  textMuted: Color(0xFF949BA4),
  accent: Color(0xFF5865F2),
  danger: Color(0xFFED4245),
  divider: Color(0xFF3F4147),
  selectedBg: Color(0xFF404249),
  hoverBg: Color(0xFF35373C),
  messageSelf: Color(0xFF5865F2),
  messageOther: Color(0xFF404249),
  brightness: Brightness.dark,
);

const _lightPalette = ThemePalette(
  serverSidebar: Color(0xFFE3E5E8),
  channelSidebar: Color(0xFFF2F3F5),
  background: Color(0xFFFFFFFF),
  inputBg: Color(0xFFEBEDEF),
  textPrimary: Color(0xFF060607),
  textMuted: Color(0xFF4E5058),
  accent: Color(0xFF5865F2),
  danger: Color(0xFFD83C3E),
  divider: Color(0xFFD4D7DC),
  selectedBg: Color(0xFFD7D9DC),
  hoverBg: Color(0xFFEBEDEF),
  messageSelf: Color(0xFF5865F2),
  messageOther: Color(0xFFEBEDEF),
  brightness: Brightness.light,
);

const _midnightPalette = ThemePalette(
  serverSidebar: Color(0xFF050816),
  channelSidebar: Color(0xFF0A0E27),
  background: Color(0xFF1A1F3A),
  inputBg: Color(0xFF252B4A),
  textPrimary: Color(0xFFDBDEE1),
  textMuted: Color(0xFF949BA4),
  accent: Color(0xFF4752F4),
  danger: Color(0xFFED4245),
  divider: Color(0xFF2A2F4A),
  selectedBg: Color(0xFF2F345A),
  hoverBg: Color(0xFF252B4A),
  messageSelf: Color(0xFF4752F4),
  messageOther: Color(0xFF252B4A),
  brightness: Brightness.dark,
);

const _oceanPalette = ThemePalette(
  serverSidebar: Color(0xFF0A1419),
  channelSidebar: Color(0xFF0F1F2A),
  background: Color(0xFF1A2A3A),
  inputBg: Color(0xFF22384A),
  textPrimary: Color(0xFFDBDEE1),
  textMuted: Color(0xFF8DA5B5),
  accent: Color(0xFF00D4FF),
  danger: Color(0xFFFF5C5C),
  divider: Color(0xFF2A3A4A),
  selectedBg: Color(0xFF2D4358),
  hoverBg: Color(0xFF22384A),
  messageSelf: Color(0xFF008FB3),
  messageOther: Color(0xFF22384A),
  brightness: Brightness.dark,
);

extension AppThemeExt on AppThemeOption {
  String get label {
    return switch (this) {
      AppThemeOption.discord => 'Discord Dark',
      AppThemeOption.light => 'Sáng',
      AppThemeOption.midnight => 'Midnight',
      AppThemeOption.ocean => 'Ocean',
    };
  }

  IconData get icon {
    return switch (this) {
      AppThemeOption.discord => Icons.dark_mode,
      AppThemeOption.light => Icons.light_mode,
      AppThemeOption.midnight => Icons.nights_stay,
      AppThemeOption.ocean => Icons.waves,
    };
  }

  ThemePalette get palette {
    return switch (this) {
      AppThemeOption.discord => _discordPalette,
      AppThemeOption.light => _lightPalette,
      AppThemeOption.midnight => _midnightPalette,
      AppThemeOption.ocean => _oceanPalette,
    };
  }

  Color get previewColor => palette.background;

  ThemeData get themeData => _buildThemeData(palette);
}

ThemeData _buildThemeData(ThemePalette p) {
  return ThemeData(
    brightness: p.brightness,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.channelSidebar,
    cardColor: p.channelSidebar,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: Colors.white,
      secondary: p.accent,
      onSecondary: Colors.white,
      error: p.danger,
      onError: Colors.white,
      surface: p.channelSidebar,
      onSurface: p.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.channelSidebar,
      foregroundColor: p.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: p.textMuted),
    ),
    dividerColor: p.divider,
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: p.textPrimary),
      bodyMedium: TextStyle(color: p.textPrimary),
      bodySmall: TextStyle(color: p.textMuted),
      titleLarge: TextStyle(color: p.textPrimary),
      titleMedium: TextStyle(color: p.textPrimary),
      titleSmall: TextStyle(color: p.textPrimary),
      labelLarge: TextStyle(color: p.textPrimary),
      labelMedium: TextStyle(color: p.textPrimary),
      labelSmall: TextStyle(color: p.textMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inputBg,
      hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
    iconTheme: IconThemeData(color: p.textMuted),
    listTileTheme: ListTileThemeData(
      textColor: p.textPrimary,
      iconColor: p.textMuted,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.channelSidebar,
      surfaceTintColor: p.channelSidebar,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.channelSidebar,
      surfaceTintColor: p.channelSidebar,
      titleTextStyle: TextStyle(
        color: p.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
        color: p.textPrimary,
        fontSize: 14,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.selectedBg,
      contentTextStyle: TextStyle(color: p.textPrimary),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.channelSidebar,
      textStyle: TextStyle(color: p.textPrimary),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.textPrimary,
      unselectedLabelColor: p.textMuted,
      indicatorColor: p.accent,
    ),
  );
}

class AppTheme {
  static ThemeData get dark => AppThemeOption.discord.themeData;
}
