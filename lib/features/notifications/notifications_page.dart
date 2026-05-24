import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/user_profile_sheet.dart';
import '../../data/models/friend.dart';
import '../../data/models/friend_request.dart';
import '../../data/models/mention_record.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/dm_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/mention_service.dart';
import '../../data/services/server_service.dart';
import '../../data/services/user_service.dart';
import '../chat/dm_chat_page.dart';
import '../servers/channel_chat_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _friendService = FriendService();
  final _dmService = DMService();
  final _userService = UserService();
  final _mentionService = MentionService();
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = AuthService().currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.channelSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Thông báo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Divider(color: AppColors.divider, height: 1),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<List<FriendRequest>>(
      stream: _friendService.streamIncomingRequests(_uid),
      builder: (context, reqSnap) {
        final requests = (reqSnap.data ?? [])
            .where((r) => r.status == 'pending')
            .toList();

        return StreamBuilder<List<MentionRecord>>(
          stream: _mentionService.streamMentions(_uid),
          builder: (context, menSnap) {
            final mentions = menSnap.data ?? [];

            return StreamBuilder<List<Friend>>(
              stream: _friendService.streamFriends(_uid),
              builder: (context, friendSnap) {
                final friends = friendSnap.data ?? [];

                if (requests.isEmpty &&
                    friends.isEmpty &&
                    mentions.isEmpty) {
                  return _buildEmpty();
                }

                return ListView(
                  children: [
                    if (requests.isNotEmpty) ...[
                      _SectionHeader(title: 'Lời mời kết bạn'),
                      ...requests.map((req) => _FriendRequestTile(
                            request: req,
                            userService: _userService,
                            onAccept: () => _friendService.acceptRequest(req),
                            onReject: () => _friendService.rejectRequest(req),
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (mentions.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                              child:
                                  _SectionHeader(title: 'Bạn được nhắc tới')),
                          if (mentions.any((m) => !m.read))
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: TextButton(
                                onPressed: () =>
                                    _mentionService.markAllAsRead(_uid),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 0),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('Đánh dấu đã đọc',
                                    style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                      ...mentions.map((m) => _MentionTile(
                            mention: m,
                            currentUid: _uid,
                            mentionService: _mentionService,
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (friends.isNotEmpty)
                      _UnreadDmSection(
                        uid: _uid,
                        friends: friends,
                        dmService: _dmService,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              color: AppColors.textMuted, size: 48),
          SizedBox(height: 8),
          Text('Không có thông báo nào',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Friend Request Tile ──────────────────────────────────────────────────────

class _FriendRequestTile extends StatelessWidget {
  final FriendRequest request;
  final UserService userService;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FriendRequestTile({
    required this.request,
    required this.userService,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: userService.getUserById(request.fromUid),
      builder: (context, snapshot) {
        final displayName = snapshot.data?.displayName ?? request.fromUid;
        final nickname = snapshot.data?.nickname ?? '';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () => showUserProfile(
            context,
            userId: request.fromUid,
            userName: displayName,
          ),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            displayName,
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: nickname.isNotEmpty
              ? Text('@$nickname',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon: Icons.check,
                color: const Color(0xFF23A559),
                onTap: onAccept,
                tooltip: 'Chấp nhận',
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.close,
                color: AppColors.danger,
                onTap: onReject,
                tooltip: 'Từ chối',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ─── Unread DM Section ────────────────────────────────────────────────────────

class _UnreadDmSection extends StatefulWidget {
  final String uid;
  final List<Friend> friends;
  final DMService dmService;

  const _UnreadDmSection({
    required this.uid,
    required this.friends,
    required this.dmService,
  });

  @override
  State<_UnreadDmSection> createState() => _UnreadDmSectionState();
}

class _UnreadDmSectionState extends State<_UnreadDmSection> {
  final Map<String, StreamSubscription<ChatPreview>> _subs = {};
  final Map<String, ChatPreview> _previews = {};

  @override
  void initState() {
    super.initState();
    _subscribeAll(widget.friends);
  }

  @override
  void didUpdateWidget(_UnreadDmSection old) {
    super.didUpdateWidget(old);
    if (old.friends != widget.friends) {
      _subscribeAll(widget.friends);
    }
  }

  void _subscribeAll(List<Friend> friends) {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();

    for (final friend in friends) {
      _subs[friend.uid] = widget.dmService
          .streamChatPreview(widget.uid, friend.uid)
          .listen((preview) {
        if (mounted) setState(() => _previews[friend.uid] = preview);
      });
    }
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.friends
        .where((f) => _previews[f.uid]?.isUnread == true)
        .toList();

    if (unread.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Tin nhắn chưa đọc'),
        ...unread.map((friend) => _DmNotificationTile(
              friend: friend,
              preview: _previews[friend.uid]!,
            )),
      ],
    );
  }
}

class _DmNotificationTile extends StatelessWidget {
  final Friend friend;
  final ChatPreview preview;

  const _DmNotificationTile({
    required this.friend,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () => showUserProfile(
          context,
          userId: friend.uid,
          userName: friend.displayName,
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.accent,
          child: Text(
            friend.displayName.isNotEmpty
                ? friend.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      title: Text(
        friend.displayName,
        style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        preview.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      trailing: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DMChatPage(
            otherUserId: friend.uid,
            otherUserName: friend.displayName,
          ),
        ),
      ),
    );
  }
}

// ─── Mention Tile ─────────────────────────────────────────────────────────────

class _MentionTile extends StatelessWidget {
  final MentionRecord mention;
  final String currentUid;
  final MentionService mentionService;

  const _MentionTile({
    required this.mention,
    required this.currentUid,
    required this.mentionService,
  });

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}p';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}t';
  }

  String get _contextLabel {
    if (mention.isChannel) {
      return '#${mention.channelName ?? ''} · ${mention.serverName ?? ''}';
    }
    return 'Tin nhắn riêng';
  }

  Future<void> _onTap(BuildContext context) async {
    await mentionService.markAsRead(currentUid, mention.id);
    if (!context.mounted) return;
    if (mention.isDm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DMChatPage(
            otherUserId: mention.fromUserId,
            otherUserName: mention.fromUserName,
          ),
        ),
      );
    } else if (mention.isChannel) {
      final service = ServerService();
      final server = await service.getServer(mention.serverId!);
      final channel =
          await service.getChannel(mention.serverId!, mention.channelId!);
      if (server == null || channel == null) return;
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChannelChatPage(server: server, channel: channel),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _onTap(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: mention.read
            ? Colors.transparent
            : AppColors.accent.withValues(alpha: 0.06),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text('@',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            children: [
                              TextSpan(
                                text: mention.fromUserName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: ' nhắc tới bạn'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _relativeTime(mention.timestamp),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _contextLabel,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mention.messagePreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!mention.read) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
