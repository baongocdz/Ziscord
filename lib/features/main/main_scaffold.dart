import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/server.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/mention_service.dart';
import '../../data/services/server_service.dart';
import '../chat/chat_page.dart';
import '../contacts/contact_list_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../servers/browse_servers_page.dart';
import '../servers/create_server_page.dart';
import '../servers/server_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _tab = 0;
  String? _selectedServerId;

  late final String _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = AuthService().currentUser!.uid;
  }

  Widget _buildHomeContent() {
    return Row(
      children: [
        _ServerSidebar(
          userId: _currentUid,
          selectedServerId: _selectedServerId,
          onDMSelected: () => setState(() => _selectedServerId = null),
          onServerSelected: (id) => setState(() => _selectedServerId = id),
        ),
        Expanded(
          child: _selectedServerId == null
              ? const _DMSection()
              : ServerPage(key: ValueKey(_selectedServerId), serverId: _selectedServerId!),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 1:
        return const NotificationsPage();
      case 2:
        return const ProfilePage();
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: StreamBuilder<int>(
        stream: FriendService().streamPendingCount(_currentUid),
        builder: (context, friendSnap) {
          return StreamBuilder<int>(
            stream: MentionService().streamUnreadCount(_currentUid),
            builder: (context, mentionSnap) {
              final total =
                  (friendSnap.data ?? 0) + (mentionSnap.data ?? 0);
              return _BottomNav(
                currentIndex: _tab,
                notificationBadge: total,
                onTap: (i) => setState(() => _tab = i),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int notificationBadge;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.notificationBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.serverSidebar,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
                selectedIcon: Icons.notifications,
                label: 'Thông báo',
                selected: currentIndex == 1,
                badgeCount: notificationBadge,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 24),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Server Sidebar ───────────────────────────────────────────────────────────

class _ServerSidebar extends StatelessWidget {
  final String userId;
  final String? selectedServerId;
  final VoidCallback onDMSelected;
  final ValueChanged<String> onServerSelected;

  const _ServerSidebar({
    required this.userId,
    required this.selectedServerId,
    required this.onDMSelected,
    required this.onServerSelected,
  });

  void _showServerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ServerOptionsSheet(
        onCreateServer: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateServerPage()),
          );
        },
        onJoinServer: () {
          Navigator.pop(context);
          _showJoinDialog(context);
        },
        onBrowse: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BrowseServersPage()),
          );
        },
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title: const Text('Tham gia Server',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nhập mã mời (8 ký tự)',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Huỷ', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white),
            onPressed: () async {
              final code = controller.text.trim();
              Navigator.pop(ctx);
              final result =
                  await ServerService().joinServerByCode(code);
              if (!context.mounted) return;
              final ok = result.outcome == JoinOutcome.joined ||
                  result.outcome == JoinOutcome.pending;
              final msg = result.message ??
                  (result.outcome == JoinOutcome.joined
                      ? 'Tham gia server thành công!'
                      : 'Có lỗi xảy ra');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(msg),
                backgroundColor: ok ? AppColors.accent : AppColors.danger,
              ));
            },
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: AppColors.serverSidebar,
      child: Column(
        children: [
          const SizedBox(height: 12),

          // DM icon
          _SidebarIcon(
            isSelected: selectedServerId == null,
            onTap: onDMSelected,
            tooltip: 'Direct Messages',
            child: const Icon(Icons.message_rounded,
                color: Colors.white, size: 22),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 1.5, color: AppColors.divider),
          ),
          const SizedBox(height: 8),

          // Server list from Firestore
          Expanded(
            child: StreamBuilder<List<Server>>(
              stream: ServerService().streamUserServers(userId),
              builder: (context, snapshot) {
                final servers = snapshot.data ?? [];
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: servers.length,
                  itemBuilder: (context, i) {
                    final server = servers[i];
                    return _SidebarIcon(
                      isSelected: selectedServerId == server.id,
                      onTap: () => onServerSelected(server.id),
                      tooltip: server.name,
                      child: server.iconUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  selectedServerId == server.id ? 16 : 24),
                              child: Image.network(server.iconUrl!,
                                  width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : Text(
                              server.name.isNotEmpty
                                  ? server.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),

          // Add server button
          _SidebarIcon(
            isSelected: false,
            onTap: () => _showServerOptions(context),
            tooltip: 'Tạo / Tham gia Server',
            squarish: true,
            child:
                const Icon(Icons.add, color: AppColors.accent, size: 22),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Server Options Sheet ─────────────────────────────────────────────────────

class _ServerOptionsSheet extends StatelessWidget {
  final VoidCallback onCreateServer;
  final VoidCallback onJoinServer;
  final VoidCallback onBrowse;

  const _ServerOptionsSheet({
    required this.onCreateServer,
    required this.onJoinServer,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thêm Server',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _OptionTile(
            icon: Icons.add_circle_outline,
            title: 'Tạo server mới',
            subtitle: 'Tạo server của riêng bạn',
            onTap: onCreateServer,
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.login_rounded,
            title: 'Tham gia server',
            subtitle: 'Nhập mã mời để tham gia',
            onTap: onJoinServer,
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.explore_rounded,
            title: 'Khám phá server',
            subtitle: 'Tìm kiếm server công khai',
            onTap: onBrowse,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.channelSidebar,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sidebar Icon ─────────────────────────────────────────────────────────────

class _SidebarIcon extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;
  final bool squarish;

  const _SidebarIcon({
    required this.child,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
    this.squarish = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 4,
              height: isSelected ? 40 : 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
          Tooltip(
            message: tooltip,
            preferBelow: false,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.channelSidebar,
                  borderRadius: BorderRadius.circular(
                    isSelected || squarish ? 16 : 24,
                  ),
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DM Section ───────────────────────────────────────────────────────────────

class _DMSection extends StatefulWidget {
  const _DMSection();

  @override
  State<_DMSection> createState() => _DMSectionState();
}

class _DMSectionState extends State<_DMSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser!.uid;
    return Column(
      children: [
        Container(
          color: AppColors.channelSidebar,
          child: StreamBuilder<int>(
            stream: FriendService().streamPendingCount(uid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  const Tab(text: 'Messages'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Friends',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        if (count > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [ChatPage(), ContactListPage()],
          ),
        ),
      ],
    );
  }
}

