import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/channel_icon_picker.dart';
import '../../data/models/library_post.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/services/server_service.dart';
import 'create_post_page.dart';
import 'library_post_page.dart';

class LibraryChannelPage extends StatelessWidget {
  final Server server;
  final ServerChannel channel;

  const LibraryChannelPage(
      {super.key, required this.server, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        title: Row(
          children: [
            ChannelIcon(
              customIcon: channel.icon,
              fallbackIcon: Icons.menu_book_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(channel.name,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<LibraryPost>>(
        stream:
            ServerService().streamPosts(server.id, channel.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.accent));
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.article_outlined,
                      color: AppColors.textMuted, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có bài đăng nào',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nhấn + để tạo bài đăng đầu tiên',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _PostCard(post: posts[i], server: server, channel: channel),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostPage(
              serverId: server.id,
              channelId: channel.id,
              channelName: channel.name,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final LibraryPost post;
  final Server server;
  final ServerChannel channel;

  const _PostCard(
      {required this.post, required this.server, required this.channel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LibraryPostPage(
            server: server,
            channel: channel,
            post: post,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.channelSidebar,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              post.content,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppColors.textMuted, size: 14),
                const SizedBox(width: 4),
                Text(post.authorName,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.chat_bubble_outline,
                    color: AppColors.textMuted, size: 14),
                const SizedBox(width: 4),
                Text('${post.commentCount}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 12),
                Text(
                  _formatDate(post.timestamp),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
