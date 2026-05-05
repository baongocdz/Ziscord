import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/message.dart';
import '../direct_messages/dm_chat_page.dart';
import '../home/user_profile_popup.dart'; // import popup
import '../../data/services/user_service.dart'; // import service

class MessageItem extends StatelessWidget {
  final Message message;
  final bool showHeader;
  final String serverId;

  const MessageItem({
    super.key,
    required this.message,
    this.showHeader = true,
    required this.serverId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = currentUser?.uid == message.userId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thêm avatar cho người khác (click mở DM)
          if (!isMe)
            GestureDetector(
              onTap: () async {
                if (currentUser == null) return;
                if (currentUser.uid == message.userId) return;

                final userService = UserService();

                final userProfile = await userService.getUserInfo(message.userId, serverId);
                if (userProfile == null) return;

                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => UserProfilePopup(user: userProfile),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4),
                child: CircleAvatar(
                  radius: 12,
                  child: Text(
                    message.user[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),

          // Container hiện tại giữ nguyên hoàn toàn
          Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF5865F2) : const Color(0xFF40444B),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.user,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                Text(
                  message.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.time),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}