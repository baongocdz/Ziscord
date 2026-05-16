import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

const kQuickEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡', '🔥', '🎉', '👀', '✅', '💯', '🙏'];

Future<String?> showEmojiPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.channelSidebar,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reaction',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kQuickEmojis
                  .map((e) => GestureDetector(
                        onTap: () => Navigator.pop(sheetCtx, e),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
