import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/user_profile_sheet.dart';
import '../../data/models/app_user.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/models/server_member.dart';
import '../../data/services/server_service.dart';
import '../../data/services/user_service.dart';
import 'channel_chat_page.dart';
import 'library_channel_page.dart';
import 'voice_channel_page.dart';

class ServerSearchPage extends StatefulWidget {
  final Server server;
  const ServerSearchPage({super.key, required this.server});

  @override
  State<ServerSearchPage> createState() => _ServerSearchPageState();
}

class _ServerSearchPageState extends State<ServerSearchPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = ServerService();
  final _userService = UserService();
  final _searchController = TextEditingController();

  String _query = '';

  List<ServerChannel> _channels = const [];
  List<ServerMemberInfo> _members = const [];
  List<ServerMediaItem> _media = const [];
  final Map<String, AppUser?> _userCache = {};

  bool _loadingMedia = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      final v = _searchController.text.trim().toLowerCase();
      if (v != _query) setState(() => _query = v);
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final channels = await _service.streamChannels(widget.server.id).first;
    final members =
        await _service.streamMembersWithNames(widget.server.id).first;
    if (!mounted) return;
    setState(() {
      _channels = channels;
      _members = members;
    });
    final media = await _service.getServerMedia(widget.server.id);
    if (!mounted) return;
    final senderIds = media.map((m) => m.senderId).toSet();
    setState(() {
      _media = media;
      _loadingMedia = false;
    });
    _ensureUsersLoaded(senderIds);
  }

  void _ensureUsersLoaded(Iterable<String> uids) {
    final missing =
        uids.toSet().where((u) => !_userCache.containsKey(u)).toList();
    if (missing.isEmpty) return;
    for (final uid in missing) {
      _userCache[uid] = null;
    }
    for (final uid in missing) {
      _userService.getUserById(uid).then((u) {
        if (!mounted) return;
        setState(() => _userCache[uid] = u);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openChannel(ServerChannel ch) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (ch.isVoice) {
            return VoiceChannelPage(server: widget.server, channel: ch);
          }
          if (ch.isLibrary) {
            return LibraryChannelPage(server: widget.server, channel: ch);
          }
          return ChannelChatPage(server: widget.server, channel: ch);
        },
      ),
    );
  }

  List<ServerChannel> get _filteredChannels {
    if (_query.isEmpty) return _channels;
    return _channels
        .where((c) => c.name.toLowerCase().contains(_query))
        .toList();
  }

  List<ServerMemberInfo> get _filteredMembers {
    if (_query.isEmpty) return _members;
    return _members
        .where((m) =>
            m.effectiveName.toLowerCase().contains(_query) ||
            m.displayName.toLowerCase().contains(_query) ||
            m.nickname.toLowerCase().contains(_query))
        .toList();
  }

  List<ServerMediaItem> get _filteredMedia {
    if (_query.isEmpty) return _media;
    return _media
        .where((m) =>
            m.senderName.toLowerCase().contains(_query) ||
            m.channelName.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: _buildSearchField(),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.textMuted),
            onPressed: () {},
            tooltip: 'Bộ lọc',
          ),
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.channelSidebar,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Gần đây'),
                Tab(text: 'Thành viên'),
                Tab(text: 'Kênh'),
                Tab(text: 'Đa phương tiện'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentTab(),
          _buildMembersTab(),
          _buildChannelsTab(),
          _buildMediaTab(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          prefixIcon: const Icon(Icons.search,
              color: AppColors.textMuted, size: 18),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 18),
                  onPressed: () => _searchController.clear(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          hintText: 'Tìm kiếm trong ${widget.server.name}',
          hintStyle:
              const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ),
    );
  }

  // ─── Tab: Gần đây ───────────────────────────────────────────────────────────

  Widget _buildRecentTab() {
    final channels = _filteredChannels;
    final members = _filteredMembers;
    final hasQuery = _query.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (!hasQuery) ...[
          _sectionHeader('Tìm trong mục Lịch', trailing: 'Xóa tất cả'),
          ...channels.take(2).map((c) => _RecentChannelTile(
                channel: c,
                onTap: () => _openChannel(c),
                onClose: () {},
              )),
          const SizedBox(height: 8),
          _sectionHeader('Kênh đề xuất'),
          ...channels.take(6).map((c) => _RecentChannelTile(
                channel: c,
                onTap: () => _openChannel(c),
              )),
        ] else ...[
          if (channels.isNotEmpty) ...[
            _sectionHeader('Kênh — ${channels.length}'),
            ...channels.take(4).map((c) => _RecentChannelTile(
                  channel: c,
                  onTap: () => _openChannel(c),
                )),
          ],
          if (members.isNotEmpty) ...[
            _sectionHeader('Thành viên — ${members.length}'),
            ...members.take(4).map((m) => _MemberTile(
                  member: m,
                  photoURL: _userCache[m.uid]?.photoURL,
                  onTap: () => _openMember(m),
                )),
          ],
          if (channels.isEmpty && members.isEmpty) _emptyState(),
        ],
      ],
    );
  }

  // ─── Tab: Thành viên ────────────────────────────────────────────────────────

  Widget _buildMembersTab() {
    final members = _filteredMembers;
    _ensureUsersLoaded(members.map((m) => m.uid));
    if (members.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        return _MemberTile(
          member: m,
          photoURL: _userCache[m.uid]?.photoURL,
          onTap: () => _openMember(m),
        );
      },
    );
  }

  void _openMember(ServerMemberInfo m) {
    showUserProfile(
      context,
      userId: m.uid,
      userName: m.effectiveName,
    );
  }

  // ─── Tab: Kênh ──────────────────────────────────────────────────────────────

  Widget _buildChannelsTab() {
    final channels = _filteredChannels;
    if (channels.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final c = channels[i];
        return _RecentChannelTile(
          channel: c,
          onTap: () => _openChannel(c),
        );
      },
    );
  }

  // ─── Tab: Đa phương tiện ────────────────────────────────────────────────────

  Widget _buildMediaTab() {
    if (_loadingMedia) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    final media = _filteredMedia;
    if (media.isEmpty) {
      return _emptyState(
          icon: Icons.image_outlined, label: 'Chưa có ảnh nào');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: media.length,
      itemBuilder: (_, i) {
        final item = media[i];
        return _MediaTile(
          item: item,
          senderPhotoURL: _userCache[item.senderId]?.photoURL,
          onTap: () => _showMediaPreview(item),
        );
      },
    );
  }

  void _showMediaPreview(ServerMediaItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(item.imageUrl),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: item.senderName,
                      photoURL: _userCache[item.senderId]?.photoURL,
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.senderName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '#${item.channelName} • '
                            '${DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String label, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({IconData icon = Icons.search_off, String? label}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 8),
          Text(
            label ?? 'Không có kết quả',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Channel tile (search result style, with "active X ago") ─────────────────

class _RecentChannelTile extends StatelessWidget {
  final ServerChannel channel;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _RecentChannelTile({
    required this.channel,
    required this.onTap,
    this.onClose,
  });

  IconData get _icon {
    if (channel.isVoice) return Icons.volume_up_rounded;
    if (channel.isLibrary) return Icons.menu_book_rounded;
    return Icons.tag;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(_icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_outline,
                          color: AppColors.textMuted, size: 12),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Kênh trong server',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 18),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Member tile ────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final ServerMemberInfo member;
  final String? photoURL;
  final VoidCallback onTap;

  const _MemberTile({
    required this.member,
    required this.photoURL,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            UserAvatar(
              name: member.effectiveName,
              photoURL: photoURL,
              radius: 18,
              backgroundColor: member.isAdmin
                  ? AppColors.accent
                  : const Color(0xFF5B6170),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.effectiveName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (member.isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (member.displayName != member.effectiveName &&
                      member.displayName.isNotEmpty)
                    Text(
                      member.displayName,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
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

// ─── Media tile (image with sender avatar overlay) ──────────────────────────

class _MediaTile extends StatelessWidget {
  final ServerMediaItem item;
  final String? senderPhotoURL;
  final VoidCallback onTap;

  const _MediaTile({
    required this.item,
    required this.senderPhotoURL,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.channelSidebar),
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    ),
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image,
                    color: AppColors.textMuted, size: 28),
              ),
            ),
            // Sender avatar in bottom-left corner
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(
                  name: item.senderName,
                  photoURL: senderPhotoURL,
                  radius: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
