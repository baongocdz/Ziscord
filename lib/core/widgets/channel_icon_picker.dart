import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Curated emoji icons users can attach to a channel name to give it a bit of
/// color. The first entry (`null`) means "no custom icon" — fall back to the
/// default # / 🔊 / 📚 indicator per channel type.
class ChannelIcons {
  static const List<String> options = [
    '📢', '📌', '📝', '📋', '📅', '💬',
    '📚', '📖', '📕', '💡', '❓', '🧠',
    '🔊', '🎵', '🎤', '🎧', '🎬', '🎮',
    '🏆', '🎯', '🎲', '🕹️', '🎉', '✨',
    '🌟', '🔥', '⚡', '💎', '🚀', '🌈',
    '🎨', '📷', '🍕', '☕', '🐶', '🐱',
    '🌸', '🍀', '🌍', '⚙️', '🔧', '💻',
  ];
}

/// Opens a bottom sheet letting the user pick (or clear) a channel emoji icon.
/// Returns the chosen emoji string, an empty string to clear the icon, or
/// `null` if the user dismissed the picker without changing anything.
Future<String?> showChannelIconPicker(
  BuildContext context, {
  String? currentIcon,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.channelSidebar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final screenH = MediaQuery.of(ctx).size.height;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenH * 0.7),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn icon cho kênh',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: ChannelIcons.options.length,
                    itemBuilder: (_, i) {
                      final icon = ChannelIcons.options[i];
                      final selected = icon == currentIcon;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, icon),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent.withValues(alpha: 0.25)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child:
                              Text(icon, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(ctx, ''),
                      icon: const Icon(Icons.do_not_disturb_alt,
                          color: AppColors.textMuted, size: 16),
                      label: const Text('Không dùng icon',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Huỷ',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Displays the right icon for a channel — uses the custom emoji if set,
/// otherwise falls back to a Material icon based on channel type.
class ChannelIcon extends StatelessWidget {
  final String? customIcon;
  final IconData fallbackIcon;
  final double size;
  final Color color;

  const ChannelIcon({
    super.key,
    required this.customIcon,
    required this.fallbackIcon,
    required this.color,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (customIcon != null && customIcon!.isNotEmpty) {
      return SizedBox(
        width: size + 4,
        height: size + 4,
        child: Center(
          child: Text(customIcon!, style: TextStyle(fontSize: size)),
        ),
      );
    }
    return Icon(fallbackIcon, color: color, size: size);
  }
}
