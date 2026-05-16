import 'package:flutter/material.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/friend_service.dart';
import '../../features/chat/dm_chat_page.dart';
import '../constants/app_colors.dart';

/// Shows a bottom sheet with a user's profile.
/// Pass [userId] and [userName]. Does not show for the current user.
Future<void> showUserProfile(
  BuildContext context, {
  required String userId,
  required String userName,
}) async {
  final currentUid = AuthService().currentUser?.uid;
  if (currentUid == null || userId == currentUid) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.channelSidebar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UserProfileSheet(
      userId: userId,
      userName: userName,
      currentUid: currentUid,
    ),
  );
}

class _UserProfileSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final String currentUid;

  const _UserProfileSheet({
    required this.userId,
    required this.userName,
    required this.currentUid,
  });

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  final _friendService = FriendService();
  bool? _isFriend;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _checkFriendship();
  }

  Future<void> _checkFriendship() async {
    final result = await _friendService.isFriend(widget.currentUid, widget.userId);
    if (mounted) setState(() => _isFriend = result);
  }

  Future<void> _addFriend() async {
    setState(() => _requesting = true);
    final msg = await _friendService.sendFriendRequestByUid(
        widget.currentUid, widget.userId);
    if (!mounted) return;
    setState(() => _requesting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.accent),
    );
    if (msg == 'Đã gửi lời mời kết bạn') await _checkFriendship();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.accent,
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.userName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.message_rounded, size: 18),
                    label: const Text('Nhắn tin'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DMChatPage(
                            otherUserId: widget.userId,
                            otherUserName: widget.userName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isFriend == null
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.accent, strokeWidth: 2),
                          ),
                        )
                      : _isFriend!
                          ? OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textMuted,
                                side: const BorderSide(
                                    color: AppColors.divider),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.people_rounded, size: 18),
                              label: const Text('Đã là bạn'),
                              onPressed: null,
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _requesting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.person_add_rounded,
                                      size: 18),
                              label: const Text('Kết bạn'),
                              onPressed: _requesting ? null : _addFriend,
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
