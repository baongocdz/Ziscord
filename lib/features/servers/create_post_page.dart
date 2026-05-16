import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/server_service.dart';

class CreatePostPage extends StatefulWidget {
  final String serverId;
  final String channelId;
  final String channelName;
  final String? editPostId;
  final String? initialTitle;
  final String? initialContent;

  const CreatePostPage({
    super.key,
    required this.serverId,
    required this.channelId,
    required this.channelName,
    this.editPostId,
    this.initialTitle,
    this.initialContent,
  });

  bool get isEditing => editPostId != null;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
  }

  bool get _canSend =>
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      if (widget.isEditing) {
        await ServerService().updatePost(
          serverId: widget.serverId,
          channelId: widget.channelId,
          postId: widget.editPostId!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        );
      } else {
        await ServerService().createPost(
          serverId: widget.serverId,
          channelId: widget.channelId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
      );
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        title: Text(
          widget.isEditing ? 'Sửa bài đăng' : widget.channelName,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _canSend ? _submit : null,
                    child: Text(
                      widget.isEditing ? 'Lưu' : 'Đăng',
                      style: TextStyle(
                        color: _canSend
                            ? AppColors.accent
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.channelSidebar,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Tiêu đề bài đăng',
                hintStyle:
                    TextStyle(color: AppColors.textMuted, fontSize: 18),
                border: InputBorder.none,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: Container(
              color: AppColors.channelSidebar,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _contentController,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Nội dung bài đăng...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
