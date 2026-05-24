import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/user_service.dart';
import '../../features/chat/dm_chat_page.dart';
import '../constants/app_colors.dart';
import 'image_viewer_page.dart';

/// Shows a bottom sheet with a user's full profile (avatar, banner, status,
/// quick actions). Pass [userId] and [userName]. Does nothing for the current
/// user.
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
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UserProfileSheet(
      userId: userId,
      fallbackName: userName,
      currentUid: currentUid,
    ),
  );
}

class _UserProfileSheet extends StatefulWidget {
  final String userId;
  final String fallbackName;
  final String currentUid;

  const _UserProfileSheet({
    required this.userId,
    required this.fallbackName,
    required this.currentUid,
  });

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  final _friendService = FriendService();
  final _userService = UserService();
  AppUser? _user;
  bool? _isFriend;
  bool _requesting = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _userService.getUserById(widget.userId),
      _friendService.isFriend(widget.currentUid, widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      _user = results[0] as AppUser?;
      _isFriend = results[1] as bool;
      _loading = false;
    });
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
    if (msg == 'Đã gửi lời mời kết bạn') {
      final friend = await _friendService.isFriend(
          widget.currentUid, widget.userId);
      if (mounted) setState(() => _isFriend = friend);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.displayName.isNotEmpty == true
        ? _user!.displayName
        : widget.fallbackName;
    final statusMessage = _user?.statusMessage ?? '';
    final bannerUrl = _user?.bannerURL;
    final photoUrl = _user?.photoURL;
    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            GestureDetector(
              onTap: hasBanner
                  ? () => ImageViewerPage.open(context, imageUrl: bannerUrl)
                  : null,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  image: hasBanner
                      ? DecorationImage(
                          image: NetworkImage(bannerUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
              ),
            ),

            // Avatar overlapping banner + content below
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: GestureDetector(
                      onTap: hasPhoto
                          ? () => ImageViewerPage.open(context,
                              imageUrl: photoUrl)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.channelSidebar, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.accent,
                          backgroundImage:
                              hasPhoto ? NetworkImage(photoUrl) : null,
                          child: !hasPhoto
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Slide content up to compensate for the avatar translation
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LỜI NHẮN',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                statusMessage.isNotEmpty
                                    ? statusMessage
                                    : 'Chưa có lời nhắn',
                                style: TextStyle(
                                  color: statusMessage.isNotEmpty
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontSize: 14,
                                  fontStyle: statusMessage.isNotEmpty
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(color: AppColors.divider),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.message_rounded,
                                    size: 18),
                                label: const Text('Nhắn tin'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DMChatPage(
                                        otherUserId: widget.userId,
                                        otherUserName: displayName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _loading || _isFriend == null
                                  ? Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: AppColors.accent,
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : _isFriend!
                                      ? OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.textMuted,
                                            side: BorderSide(
                                                color: AppColors.divider),
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8)),
                                          ),
                                          icon: const Icon(
                                              Icons.people_rounded,
                                              size: 18),
                                          label: const Text('Đã là bạn'),
                                          onPressed: null,
                                        )
                                      : ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.accent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8)),
                                          ),
                                          icon: _requesting
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Colors
                                                              .white,
                                                          strokeWidth: 2))
                                              : const Icon(
                                                  Icons.person_add_rounded,
                                                  size: 18),
                                          label: const Text('Kết bạn'),
                                          onPressed: _requesting
                                              ? null
                                              : _addFriend,
                                        ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
