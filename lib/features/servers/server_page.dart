import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/channel_icon_picker.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/models/server_member.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/server_service.dart';
import '../../data/services/voice_service.dart';
import 'channel_chat_page.dart';
import 'library_channel_page.dart';
import 'server_member_list_page.dart';
import 'server_search_page.dart';
import 'server_settings_page.dart';
import 'voice_channel_page.dart';

class ServerPage extends StatelessWidget {
  final String serverId;

  const ServerPage({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    final service = ServerService();

    return FutureBuilder<Server?>(
      future: service.getServer(serverId),
      builder: (context, snap) {
        final server = snap.data;
        if (server == null && snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (server == null) {
          return const Center(
              child: Text('Server không tồn tại',
                  style: TextStyle(color: AppColors.textMuted)));
        }
        return _ServerContent(server: server, service: service);
      },
    );
  }
}

class _ServerContent extends StatelessWidget {
  final Server server;
  final ServerService service;

  const _ServerContent({required this.server, required this.service});

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService().currentUser!.uid;
    return StreamBuilder<ServerMember?>(
      stream: service.streamMember(server.id, currentUid),
      builder: (context, memberSnap) {
        final member = memberSnap.data;
        final isAdmin = member?.isAdmin ?? false;
        final canManageChannels = member?.canManageChannels ?? false;
        final channelReads = member?.channelReads ?? const <String, int>{};
        return _buildContent(
            context, isAdmin, canManageChannels, channelReads);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isAdmin,
      bool canManageChannels, Map<String, int> channelReads) {
    return Container(
      color: AppColors.channelSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server header
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1)),
            ),
            padding:
                const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          StreamBuilder<int>(
                            stream: service.streamMemberCount(server.id),
                            builder: (context, snap) {
                              final count = snap.data ?? 0;
                              return Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF23A559),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$count thành viên',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.people_outline,
                          color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServerMemberListPage(
                            server: server,
                            isAdmin: isAdmin,
                          ),
                        ),
                      ),
                      tooltip: 'Thành viên',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings,
                          color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ServerSettingsPage(server: server),
                        ),
                      ),
                      tooltip: 'Cài đặt server',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SearchBar(server: server),
              ],
            ),
          ),

          // Channel list
          Expanded(
            child: StreamBuilder<List<ServerChannel>>(
              stream: service.streamChannels(server.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent));
                }

                final channels = snapshot.data ?? [];

                if (channels.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa có kênh nào\nNhấn + để tạo kênh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  );
                }

                return _ChannelList(
                  server: server,
                  channels: channels,
                  channelReads: channelReads,
                  canManageChannels: canManageChannels,
                  isAdmin: isAdmin,
                  onAddText: canManageChannels
                      ? () => _showAddChannelDialog(
                          context, server.id, 'text')
                      : null,
                  onAddVoice: canManageChannels
                      ? () => _showAddChannelDialog(
                          context, server.id, 'voice')
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChannelDialog(
      BuildContext context, String serverId, String type) {
    final controller = TextEditingController();
    String subtype = 'chat';
    String? pickedIcon;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.channelSidebar,
          title: Text(
            type == 'text' ? 'Tạo kênh văn bản' : 'Tạo kênh thoại',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ICON',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _IconButton(
                  icon: pickedIcon,
                  fallback: type == 'voice'
                      ? Icons.volume_up_rounded
                      : (subtype == 'library'
                          ? Icons.menu_book_rounded
                          : Icons.tag),
                  onTap: () async {
                    final result = await showChannelIconPicker(
                      ctx,
                      currentIcon: pickedIcon,
                    );
                    if (result == null) return;
                    setDialogState(() {
                      pickedIcon = result.isEmpty ? null : result;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('TÊN KÊNH',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(hintText: 'tên-kênh'),
                ),
                if (type == 'text') ...[
                  const SizedBox(height: 16),
                  const Text('LOẠI KÊNH',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _RadioOption(
                    label: 'Chat',
                    subtitle: 'Chat tự do không có chủ đề',
                    value: 'chat',
                    groupValue: subtype,
                    onChanged: (v) =>
                        setDialogState(() => subtype = v),
                  ),
                  _RadioOption(
                    label: 'Library',
                    subtitle: 'Bài đăng theo chủ đề (forum)',
                    value: 'library',
                    groupValue: subtype,
                    onChanged: (v) =>
                        setDialogState(() => subtype = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await ServerService().createChannel(
                  serverId: serverId,
                  name: name,
                  type: type,
                  subtype: type == 'text' ? subtype : 'chat',
                  icon: pickedIcon,
                );
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final Server server;
  const _SearchBar({required this.server});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServerSearchPage(server: server),
        ),
      ),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search,
                color: AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tìm kiếm trong ${server.name}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Channel List ─────────────────────────────────────────────────────────────

class _ChannelList extends StatelessWidget {
  final Server server;
  final List<ServerChannel> channels;
  final Map<String, int> channelReads;
  final bool canManageChannels;
  final bool isAdmin;
  final VoidCallback? onAddText;
  final VoidCallback? onAddVoice;

  const _ChannelList({
    required this.server,
    required this.channels,
    required this.channelReads,
    required this.canManageChannels,
    required this.isAdmin,
    this.onAddText,
    this.onAddVoice,
  });

  int _unreadFor(ServerChannel channel) {
    final read = channelReads[channel.id];
    if (read == null) return 0; // chưa có dữ liệu đọc → không hiển thị badge
    final diff = channel.messageCount - read;
    return diff <= 0 ? 0 : diff;
  }

  void _openChannel(BuildContext context, ServerChannel ch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (ch.isVoice) return VoiceChannelPage(server: server, channel: ch);
          if (ch.isLibrary) return LibraryChannelPage(server: server, channel: ch);
          return ChannelChatPage(server: server, channel: ch);
        },
      ),
    );
  }

  Future<void> _handleReorder(
      List<ServerChannel> section, bool isText, int oldIdx, int newIdx) async {
    if (newIdx > oldIdx) newIdx -= 1;
    final reordered = [...section];
    final item = reordered.removeAt(oldIdx);
    reordered.insert(newIdx, item);

    final text = isText
        ? reordered
        : channels.where((c) => c.isText).toList();
    final voice = !isText
        ? reordered
        : channels.where((c) => c.isVoice).toList();

    final orderedIds = [
      ...text.map((c) => c.id),
      ...voice.map((c) => c.id),
    ];
    await ServerService().reorderChannels(server.id, orderedIds);
  }

  Future<void> _editChannel(
      BuildContext context, ServerChannel ch) async {
    final controller = TextEditingController(text: ch.name);
    String? pickedIcon = ch.icon;

    final result = await showDialog<_EditChannelResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.channelSidebar,
          title: const Text('Sửa kênh',
              style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ICON',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _IconButton(
                  icon: pickedIcon,
                  fallback: ch.isVoice
                      ? Icons.volume_up_rounded
                      : (ch.isLibrary
                          ? Icons.menu_book_rounded
                          : Icons.tag),
                  onTap: () async {
                    final picked = await showChannelIconPicker(
                      ctx,
                      currentIcon: pickedIcon,
                    );
                    if (picked == null) return;
                    setDialogState(() {
                      pickedIcon = picked.isEmpty ? null : picked;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('TÊN KÊNH',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Tên kênh'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(
                ctx,
                _EditChannelResult(
                  name: controller.text.trim(),
                  icon: pickedIcon,
                ),
              ),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final newName = result.name;
    if (newName.isNotEmpty && newName != ch.name) {
      await ServerService().renameChannel(server.id, ch.id, newName);
    }
    if (result.icon != ch.icon) {
      await ServerService().setChannelIcon(server.id, ch.id, result.icon);
    }
  }

  Future<void> _deleteChannel(
      BuildContext context, ServerChannel ch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title: Text('Xóa kênh #${ch.name}?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text('Hành động này không thể hoàn tác.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ServerService().deleteChannel(server.id, ch.id);
  }

  Widget _buildSection(
      BuildContext context, List<ServerChannel> section, bool isText) {
    if (canManageChannels) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: section.length,
        onReorder: (oldIdx, newIdx) =>
            _handleReorder(section, isText, oldIdx, newIdx),
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        itemBuilder: (context, i) {
          final ch = section[i];
          return _ManageableChannelTile(
            key: ValueKey(ch.id),
            serverId: server.id,
            channel: ch,
            index: i,
            isAdmin: isAdmin,
            unreadCount: _unreadFor(ch),
            onTap: () => _openChannel(context, ch),
            onEdit: () => _editChannel(context, ch),
            onDelete: () => _deleteChannel(context, ch),
          );
        },
      );
    }
    return Column(
      children: section
          .map((ch) => _ChannelTile(
                serverId: server.id,
                channel: ch,
                unreadCount: _unreadFor(ch),
                onTap: () => _openChannel(context, ch),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textChannels = channels.where((c) => c.isText).toList();
    final voiceChannels = channels.where((c) => c.isVoice).toList();
    final showTextHeader = textChannels.isNotEmpty || canManageChannels;
    final showVoiceHeader = voiceChannels.isNotEmpty || canManageChannels;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (showTextHeader) ...[
          _ChannelGroupHeader(label: 'KÊNH VĂN BẢN', onAdd: onAddText),
          if (textChannels.isNotEmpty)
            _buildSection(context, textChannels, true),
        ],
        if (showVoiceHeader) ...[
          _ChannelGroupHeader(label: 'KÊNH THOẠI', onAdd: onAddVoice),
          if (voiceChannels.isNotEmpty)
            _buildSection(context, voiceChannels, false),
        ],
      ],
    );
  }
}

class _EditChannelResult {
  final String name;
  final String? icon;
  const _EditChannelResult({required this.name, required this.icon});
}

class _ManageableChannelTile extends StatelessWidget {
  final String serverId;
  final ServerChannel channel;
  final int index;
  final bool isAdmin;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ManageableChannelTile({
    super.key,
    required this.serverId,
    required this.channel,
    required this.index,
    required this.isAdmin,
    required this.unreadCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  IconData get _fallbackIcon {
    if (channel.isVoice) return Icons.volume_up_rounded;
    if (channel.isLibrary) return Icons.menu_book_rounded;
    return Icons.tag;
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.drag_indicator,
                        color: AppColors.textMuted, size: 16),
                  ),
                ),
                const SizedBox(width: 2),
                ChannelIcon(
                  customIcon: channel.icon,
                  fallbackIcon: _fallbackIcon,
                  color: hasUnread
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    channel.name,
                    style: TextStyle(
                        color: hasUnread
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (channel.isVoice) ...[
                  _VoiceCountChip(serverId: serverId, channelId: channel.id),
                  const SizedBox(width: 4),
                ],
                if (hasUnread) ...[
                  _UnreadBadge(count: unreadCount),
                  const SizedBox(width: 4),
                ],
                if (isAdmin)
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz,
                          color: AppColors.textMuted, size: 16),
                      padding: EdgeInsets.zero,
                      color: AppColors.channelSidebar,
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit,
                                  color: AppColors.textPrimary, size: 16),
                              SizedBox(width: 8),
                              Text('Sửa kênh',
                                  style: TextStyle(
                                      color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  color: AppColors.danger, size: 16),
                              SizedBox(width: 8),
                              Text('Xóa kênh',
                                  style:
                                      TextStyle(color: AppColors.danger)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Channel Group Header ─────────────────────────────────────────────────────

class _ChannelGroupHeader extends StatelessWidget {
  final String label;
  final VoidCallback? onAdd;

  const _ChannelGroupHeader({required this.label, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.chevron_right,
              color: AppColors.textMuted, size: 14),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: const Icon(Icons.add,
                  color: AppColors.textMuted, size: 18),
            ),
        ],
      ),
    );
  }
}

// ─── Channel Tile ─────────────────────────────────────────────────────────────

class _ChannelTile extends StatefulWidget {
  final String serverId;
  final ServerChannel channel;
  final int unreadCount;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.serverId,
    required this.channel,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  bool _hovered = false;

  IconData get _fallbackIcon {
    if (widget.channel.isVoice) return Icons.volume_up_rounded;
    if (widget.channel.isLibrary) return Icons.menu_book_rounded;
    return Icons.tag;
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ChannelIcon(
                customIcon: widget.channel.icon,
                fallbackIcon: _fallbackIcon,
                color: hasUnread
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.channel.name,
                  style: TextStyle(
                    color: hasUnread
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.channel.isVoice)
                _VoiceCountChip(
                    serverId: widget.serverId,
                    channelId: widget.channel.id),
              if (hasUnread) _UnreadBadge(count: widget.unreadCount),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Voice Count Chip ─────────────────────────────────────────────────────────

class _VoiceCountChip extends StatelessWidget {
  final String serverId;
  final String channelId;

  const _VoiceCountChip({required this.serverId, required this.channelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: VoiceService().streamMemberCount(serverId, channelId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.headset,
                  color: AppColors.textMuted, size: 12),
              const SizedBox(width: 3),
              Text('$count',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Unread Badge ────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─── Icon picker button (used in create/edit dialogs) ────────────────────────

class _IconButton extends StatelessWidget {
  final String? icon;
  final IconData fallback;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.fallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        alignment: Alignment.center,
        child: icon != null && icon!.isNotEmpty
            ? Text(icon!, style: const TextStyle(fontSize: 26))
            : Icon(fallback, color: AppColors.textMuted, size: 24),
      ),
    );
  }
}

// ─── Radio Option ─────────────────────────────────────────────────────────────

class _RadioOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _RadioOption({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
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
