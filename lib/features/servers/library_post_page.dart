import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/library_comment.dart';
import '../../data/models/library_post.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/server_service.dart';
import 'create_post_page.dart';

class LibraryPostPage extends StatefulWidget {
  final Server server;
  final ServerChannel channel;
  final LibraryPost post;

  const LibraryPostPage({
    super.key,
    required this.server,
    required this.channel,
    required this.post,
  });

  @override
  State<LibraryPostPage> createState() => _LibraryPostPageState();
}

class _LibraryPostPageState extends State<LibraryPostPage> {
  final _commentController = TextEditingController();
  bool _sending = false;
  late final String _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = AuthService().currentUser!.uid;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ServerService().addComment(
        serverId: widget.server.id,
        channelId: widget.channel.id,
        postId: widget.post.id,
        text: text,
      );
      _commentController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        title: Text(
          widget.channel.name,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.post.authorId == _currentUid)
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: AppColors.textMuted, size: 20),
              tooltip: 'Sửa bài đăng',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostPage(
                    serverId: widget.server.id,
                    channelId: widget.channel.id,
                    channelName: widget.channel.name,
                    editPostId: widget.post.id,
                    initialTitle: widget.post.title,
                    initialContent: widget.post.content,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<LibraryComment>>(
              stream: ServerService().streamComments(
                widget.server.id,
                widget.channel.id,
                widget.post.id,
              ),
              builder: (context, snapshot) {
                final comments = snapshot.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 1 + comments.length,
                  itemBuilder: (context, i) {
                    if (i == 0) return _PostBody(post: widget.post);
                    return _CommentTile(comment: comments[i - 1]);
                  },
                );
              },
            ),
          ),
          _CommentInput(
            controller: _commentController,
            sending: _sending,
            onSend: _sendComment,
          ),
        ],
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final LibraryPost post;

  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.person_outline,
                color: AppColors.textMuted, size: 13),
            const SizedBox(width: 4),
            Text(post.authorName,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 12),
            Text(
              _formatDate(post.timestamp),
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          post.content,
          style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),
        Divider(color: AppColors.divider),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Bình luận',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
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

class _CommentTile extends StatelessWidget {
  final LibraryComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.inputBg,
            child: Text(
              comment.authorName.isNotEmpty
                  ? comment.authorName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(comment.timestamp),
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
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

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.channelSidebar,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Viết bình luận...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
