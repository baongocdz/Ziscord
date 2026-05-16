import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/server.dart';
import '../../data/models/server_member.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/server_service.dart';

class ServerMemberListPage extends StatelessWidget {
  final Server server;
  final bool isAdmin;

  const ServerMemberListPage({
    super.key,
    required this.server,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService().currentUser!.uid;
    final service = ServerService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thành viên',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16),
        ),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.divider, height: 1),
        ),
      ),
      body: StreamBuilder<List<ServerMemberInfo>>(
        stream: service.streamMembersWithNames(server.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return const Center(
              child: Text('Không có thành viên',
                  style: TextStyle(color: AppColors.textMuted)),
            );
          }

          final admins = members.where((m) => m.isAdmin).toList();
          final regulars = members.where((m) => !m.isAdmin).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (admins.isNotEmpty) ...[
                _SectionHeader(
                    label: 'ADMIN — ${admins.length}'),
                ...admins.map((m) => _MemberTile(
                      member: m,
                      isCurrentUser: m.uid == currentUid,
                      canKick: isAdmin && m.uid != currentUid && !m.isAdmin,
                      onKick: () => _confirmKick(context, service, m),
                    )),
              ],
              if (regulars.isNotEmpty) ...[
                _SectionHeader(
                    label: 'THÀNH VIÊN — ${regulars.length}'),
                ...regulars.map((m) => _MemberTile(
                      member: m,
                      isCurrentUser: m.uid == currentUid,
                      canKick: isAdmin && m.uid != currentUid,
                      canTogglePerm: isAdmin && m.uid != currentUid,
                      onKick: () => _confirmKick(context, service, m),
                      onTogglePerm: () => service.setMemberCanCreateChannel(
                          server.id, m.uid, !m.canCreateChannel),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  void _confirmKick(
      BuildContext context, ServerService service, ServerMemberInfo member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title: Text('Kick ${member.effectiveName}?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '${member.effectiveName} sẽ bị xoá khỏi server này.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Huỷ', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await service.kickMember(server.id, member.uid);
            },
            child: const Text('Kick'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ServerMemberInfo member;
  final bool isCurrentUser;
  final bool canKick;
  final bool canTogglePerm;
  final VoidCallback onKick;
  final VoidCallback onTogglePerm;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.canKick,
    this.canTogglePerm = false,
    required this.onKick,
    this.onTogglePerm = _noop,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final name = member.effectiveName;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            member.isAdmin ? AppColors.accent : const Color(0xFF5B6170),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrentUser
                    ? AppColors.accent
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Bạn',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (!member.isAdmin && member.canCreateChannel) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Có quyền tạo kênh',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF23A559).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Tạo kênh',
                  style: TextStyle(
                      color: Color(0xFF23A559),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: member.nickname.isNotEmpty
          ? Text('@${member.nickname}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12))
          : null,
      trailing: (canKick || canTogglePerm)
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
              color: AppColors.channelSidebar,
              onSelected: (v) {
                if (v == 'kick') onKick();
                if (v == 'perm') onTogglePerm();
              },
              itemBuilder: (_) => [
                if (canTogglePerm)
                  PopupMenuItem(
                    value: 'perm',
                    child: Row(
                      children: [
                        Icon(
                          member.canCreateChannel
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          member.canCreateChannel
                              ? 'Thu hồi quyền tạo kênh'
                              : 'Cấp quyền tạo kênh',
                          style:
                              const TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                if (canKick)
                  const PopupMenuItem(
                    value: 'kick',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove,
                            color: AppColors.danger, size: 18),
                        SizedBox(width: 8),
                        Text('Kick',
                            style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}
