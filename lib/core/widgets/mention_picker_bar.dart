import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'user_avatar.dart';

class MentionCandidate {
  final String uid;
  final String displayName;
  final String? photoURL;

  const MentionCandidate({
    required this.uid,
    required this.displayName,
    this.photoURL,
  });
}

/// Detects an active `@query` token at the cursor and returns it via [onQueryChanged].
///
/// Returns null when there's no active mention being typed.
class MentionDetector {
  /// If the user is currently typing a mention, returns the partial query (after the @).
  /// Otherwise returns null.
  static String? activeQuery(TextEditingValue value) {
    if (!value.selection.isValid) return null;
    final cursor = value.selection.baseOffset;
    if (cursor < 0) return null;
    final before = value.text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) return null;
    // Make sure @ is at start or after whitespace
    if (atIndex > 0) {
      final prev = before[atIndex - 1];
      if (!RegExp(r'\s').hasMatch(prev)) return null;
    }
    final query = before.substring(atIndex + 1);
    // Cancel if query contains whitespace (mention closed)
    if (query.contains(RegExp(r'\s'))) return null;
    return query;
  }

  /// Replaces the active `@query` with `@displayName ` and returns the new value.
  static TextEditingValue insertMention(
      TextEditingValue value, String displayName) {
    final cursor = value.selection.baseOffset;
    final before = value.text.substring(0, cursor);
    final after = value.text.substring(cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) return value;
    final newBefore = '${before.substring(0, atIndex)}@$displayName ';
    final newText = newBefore + after;
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
  }
}

class MentionPickerBar extends StatelessWidget {
  final List<MentionCandidate> candidates;
  final String query;
  final ValueChanged<MentionCandidate> onPick;

  const MentionPickerBar({
    super.key,
    required this.candidates,
    required this.query,
    required this.onPick,
  });

  List<MentionCandidate> _filtered() {
    if (query.isEmpty) return candidates.take(8).toList();
    final q = query.toLowerCase();
    return candidates
        .where((c) => c.displayName.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.channelSidebar,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              query.isEmpty
                  ? 'THÀNH VIÊN'
                  : 'THÀNH VIÊN — KHỚP "@$query"',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final user = filtered[i];
                return InkWell(
                  onTap: () => onPick(user),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: user.displayName,
                          photoURL: user.photoURL,
                          radius: 14,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            user.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                          ),
                        ),
                        Text(
                          '@',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
