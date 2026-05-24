import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/friend.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/dm_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/pending_dm_service.dart';
import '../ai/ai_chat_page.dart';
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
      return Center(
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
          Divider(color: AppColors.divider, height: 1, thickness: 1),
          StreamBuilder<List<Friend>>(
            stream: _friendService.streamFriends(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Expanded(
                  child: Center(
                    child: Text('Lỗi: ${snapshot.error}',
                        style: TextStyle(color: AppColors.danger)),
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
          Text(
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
                    icon: Icon(Icons.mark_email_unread_outlined,
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
                        decoration: BoxDecoration(
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
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tin nhắn...',
          prefixIcon:
              Icon(Icons.search, color: AppColors.textMuted, size: 18),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close,
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
    return Expanded(
      child: ListView.builder(
        itemCount: friends.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _AiAssistantTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiChatPage()),
              ),
            );
          }
          final friend = friends[index - 1];
          return StreamBuilder<ChatPreview>(
            stream: _dmService.streamChatPreview(currentUserId, friend.uid),
            builder: (context, snapshot) {
              final preview = snapshot.data;
              return _ConversationTile(
                friend: friend,
                lastMessage: preview?.lastMessage ?? '',
                timeText: _formatTime(preview?.updatedAt),
                isUnread: preview?.isUnread ?? false,
                unreadCount: preview?.unreadCount ?? 0,
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
            return Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Text('Không tìm thấy tin nhắn nào',
                  style: TextStyle(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final r = results[index];
              final original = friends.firstWhere(
                (f) => f.uid == r.friendUid,
                orElse: () => Friend(
                    uid: r.friendUid,
                    displayName: r.friendName,
                    nickname: r.friendName),
              );
              return _ConversationTile(
                friend: original,
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
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.friend,
    required this.lastMessage,
    required this.timeText,
    required this.onTap,
    this.isUnread = false,
    this.unreadCount = 0,
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
              UserAvatar(
                name: widget.friend.displayName,
                photoURL: widget.friend.photoURL,
                radius: 20,
              ),
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
                        if (widget.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            constraints:
                                const BoxConstraints(minWidth: 18),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.unreadCount > 99
                                  ? '99+'
                                  : '${widget.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          )
                        else if (widget.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
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

// ─── AI Assistant Tile ────────────────────────────────────────────────────────

class _AiAssistantTile extends StatefulWidget {
  final VoidCallback onTap;
  const _AiAssistantTile({required this.onTap});

  @override
  State<_AiAssistantTile> createState() => _AiAssistantTileState();
}

class _AiAssistantTileState extends State<_AiAssistantTile> {
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
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI Assistant',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BOT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Hỏi đáp với Groq',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
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

