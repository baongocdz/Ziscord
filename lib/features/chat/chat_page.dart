import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/friend.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/dm_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/pending_dm_service.dart';
import 'dm_chat_page.dart';
import 'pending_inbox_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  final DMService _dmService = DMService();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final isToday =
        now.year == time.year && now.month == time.month && now.day == time.day;
    return isToday
        ? DateFormat('HH:mm').format(time)
        : DateFormat('dd/MM').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('Bạn chưa đăng nhập',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return Container(
      color: AppColors.channelSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchBox(),
          const Divider(color: AppColors.divider, height: 1, thickness: 1),
          StreamBuilder<List<Friend>>(
            stream: _friendService.streamFriends(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Expanded(
                  child: Center(
                    child: Text('Lỗi: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                );
              }

              final friends = snapshot.data ?? [];

              if (_searchText.isNotEmpty) {
                return _buildSearchResults(currentUser.uid, friends);
              }
              return _buildConversationList(currentUser.uid, friends);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final uid = AuthService().currentUser!.uid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
      child: Row(
        children: [
          const Text(
            'Direct Messages',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          StreamBuilder<int>(
            stream: PendingDmService().streamUnreadCount(uid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mark_email_unread_outlined,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PendingInboxPage()),
                    ),
                    tooltip: 'Tin nhắn chờ',
                  ),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchText = v.trim()),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tin nhắn...',
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textMuted, size: 18),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildConversationList(String currentUserId, List<Friend> friends) {
    if (friends.isEmpty) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, color: AppColors.textMuted, size: 48),
              SizedBox(height: 8),
              Text(
                'Chưa có bạn bè nào\nthêm bạn trong tab Contacts',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return StreamBuilder<ChatPreview>(
            stream: _dmService.streamChatPreview(currentUserId, friend.uid),
            builder: (context, snapshot) {
              final preview = snapshot.data;
              return _ConversationTile(
                friend: friend,
                lastMessage: preview?.lastMessage ?? '',
                timeText: _formatTime(preview?.updatedAt),
                isUnread: preview?.isUnread ?? false,
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
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(String currentUserId, List<Friend> friends) {
    return Expanded(
      child: FutureBuilder<List<MessageSearchResult>>(
        future: _dmService.searchMessages(
          currentUserId: currentUserId,
          friends: friends,
          query: _searchText,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return const Center(
              child: Text('Không tìm thấy tin nhắn nào',
                  style: TextStyle(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final r = results[index];
              return _ConversationTile(
                friend: Friend(
                    uid: r.friendUid,
                    displayName: r.friendName,
                    nickname: r.friendName),
                lastMessage: r.messageText,
                timeText: _formatTime(r.timestamp),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DMChatPage(
                        otherUserId: r.friendUid, otherUserName: r.friendName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatefulWidget {
  final Friend friend;
  final String lastMessage;
  final String timeText;
  final bool isUnread;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.friend,
    required this.lastMessage,
    required this.timeText,
    required this.onTap,
    this.isUnread = false,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              _Avatar(name: widget.friend.displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.friend.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: widget.isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (widget.timeText.isNotEmpty)
                          Text(
                            widget.timeText,
                            style: TextStyle(
                              color: widget.isUnread
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: widget.isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: widget.lastMessage.isNotEmpty
                              ? Text(
                                  widget.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.isUnread
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                    fontSize: 13,
                                    fontWeight: widget.isUnread
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (widget.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
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
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.accent,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}
