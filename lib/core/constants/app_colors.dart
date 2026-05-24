import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';

/// Theme-aware color accessors. Values change based on the active theme in
/// [ThemeNotifier]. Widgets that read these are rebuilt automatically because
/// the root `MaterialApp` is wrapped in a `ValueListenableBuilder` over the
/// notifier, so the whole tree rebuilds on theme change.
class AppColors {
  static ThemePalette get _p => ThemeNotifier.instance.value.palette;

  static Color get serverSidebar => _p.serverSidebar;
  static Color get channelSidebar => _p.channelSidebar;
  static Color get background => _p.background;
  static Color get inputBg => _p.inputBg;

  static Color get textPrimary => _p.textPrimary;
  static Color get textMuted => _p.textMuted;

  static Color get accent => _p.accent;
  static Color get danger => _p.danger;

  static Color get divider => _p.divider;
  static Color get selectedBg => _p.selectedBg;
  static Color get hoverBg => _p.hoverBg;

  static Color get messageSelf => _p.messageSelf;
  static Color get messageOther => _p.messageOther;
}
