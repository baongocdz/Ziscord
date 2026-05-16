import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/pending_dm_service.dart';
import 'dm_chat_page.dart';

class PendingInboxPage extends StatelessWidget {
  const PendingInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser!.uid;
    final service = PendingDmService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tin nhắn chờ',
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
      body: StreamBuilder<List<PendingMessage>>(
        stream: service.streamInbox(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.textMuted, size: 48),
                  SizedBox(height: 8),
                  Text('Không có tin nhắn chờ',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final msg = messages[i];
              return _PendingTile(
                msg: msg,
                currentUid: uid,
                onAccept: () async {
                  await service.deleteMessage(uid, msg.id);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DMChatPage(
                        otherUserId: msg.fromUid,
                        otherUserName: msg.fromName,
                      ),
                    ),
                  );
                },
                onDecline: () => service.deleteMessage(uid, msg.id),
                onAddFriend: () async {
                  final result = await FriendService()
                      .sendFriendRequestByUid(uid, msg.fromUid);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result),
                    backgroundColor: AppColors.accent,
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final PendingMessage msg;
  final String currentUid;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onAddFriend;

  const _PendingTile({
    required this.msg,
    required this.currentUid,
    required this.onAccept,
    required this.onDecline,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.channelSidebar,
        borderRadius: BorderRadius.circular(8),
        border: msg.read
            ? null
            : Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent,
                child: Text(
                  msg.fromName.isNotEmpty
                      ? msg.fromName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.fromName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    Text(
                      DateFormat('dd/MM HH:mm').format(msg.timestamp),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!msg.read)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.text,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onAddFriend,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Kết bạn'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Nhắn tin'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
