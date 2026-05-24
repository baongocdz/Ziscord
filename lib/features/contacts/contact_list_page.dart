import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/user_profile_sheet.dart';
import '../../data/models/friend.dart';
import '../../data/models/friend_request.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/user_service.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _friendService = FriendService();
  final _userService = UserService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    final uid = AuthService().currentUser!.uid;
    final result = await _friendService.sendFriendRequest(uid, email);
    if (!mounted) return;
    _emailController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result),
      backgroundColor:
          result.startsWith('Đã gửi') ? AppColors.accent : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser!.uid;

    return Container(
      color: AppColors.channelSidebar,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(Icons.people, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Contacts',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.person_add_outlined,
                      color: AppColors.textMuted, size: 20),
                  tooltip: 'Thêm bạn',
                  onPressed: () => _showAddFriendSheet(context),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Bạn bè'),
              Tab(text: 'Lời mời'),
            ],
          ),
          Divider(color: AppColors.divider, height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FriendsList(uid: uid, friendService: _friendService),
                _RequestsList(
                  uid: uid,
                  friendService: _friendService,
                  userService: _userService,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFriendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thêm bạn bè',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Nhập email để gửi lời mời kết bạn',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'email@example.com',
                prefixIcon:
                    Icon(Icons.email_outlined, color: AppColors.textMuted),
              ),
              onSubmitted: (_) {
                Navigator.pop(ctx);
                _sendRequest();
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendRequest();
                },
                child: const Text('Gửi lời mời',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Friends List ─────────────────────────────────────────────────────────────

class _FriendsList extends StatelessWidget {
  final String uid;
  final FriendService friendService;

  const _FriendsList({required this.uid, required this.friendService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Friend>>(
      stream: friendService.streamFriends(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, color: AppColors.textMuted, size: 48),
                SizedBox(height: 8),
                Text('Chưa có bạn bè nào',
                    style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, i) {
            final f = friends[i];
            return _FriendTile(
              friend: f,
              currentUid: uid,
              friendService: friendService,
            );
          },
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final String currentUid;
  final FriendService friendService;
  const _FriendTile({
    required this.friend,
    required this.currentUid,
    required this.friendService,
  });

  Future<void> _confirmRemove(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title: Text('Xóa kết bạn?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Bạn có chắc muốn xóa ${friend.displayName} khỏi danh sách bạn bè?',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Huỷ',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await friendService.removeFriend(currentUid, friend.uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã xóa ${friend.displayName} khỏi bạn bè'),
      backgroundColor: AppColors.accent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => showUserProfile(
        context,
        userId: friend.uid,
        userName: friend.displayName,
      ),
      leading: CircleAvatar(
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
      title: Text(friend.displayName,
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: friend.nickname.isNotEmpty
          ? Text('@${friend.nickname}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          : null,
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz, color: AppColors.textMuted),
        color: AppColors.channelSidebar,
        onSelected: (v) {
          if (v == 'remove') _confirmRemove(context);
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, color: AppColors.danger, size: 18),
                SizedBox(width: 8),
                Text('Xóa kết bạn',
                    style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Requests List ────────────────────────────────────────────────────────────

class _RequestsList extends StatelessWidget {
  final String uid;
  final FriendService friendService;
  final UserService userService;

  const _RequestsList({
    required this.uid,
    required this.friendService,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: friendService.streamIncomingRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }
        final requests =
            (snapshot.data ?? []).where((r) => r.status == 'pending').toList();
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 48),
                SizedBox(height: 8),
                Text('Không có lời mời nào',
                    style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, i) {
            final req = requests[i];
            return _RequestTile(
              request: req,
              userService: userService,
              onAccept: () => friendService.acceptRequest(req),
              onReject: () => friendService.rejectRequest(req),
            );
          },
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final FriendRequest request;
  final UserService userService;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
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
        final displayName =
            snapshot.data?.displayName ?? request.fromUid;
        final nickname = snapshot.data?.nickname ?? '';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.check,
                color: const Color(0xFF23A559),
                onTap: onAccept,
                tooltip: 'Chấp nhận',
              ),
              const SizedBox(width: 8),
              _ActionButton(
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({
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
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
