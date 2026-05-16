import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/emoji_picker_sheet.dart';
import '../../core/widgets/formatted_text.dart';
import '../../core/widgets/image_preview_strip.dart';
import '../../core/widgets/mention_picker_bar.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/app_user.dart';
import '../../data/models/dm_message.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/dm_service.dart';
import '../../data/services/user_service.dart';

class DMChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const DMChatPage({
    super.key,
    required this.otherUserId,
    this.otherUserName = 'Chat',
    this.otherUserAvatar = '',
  });

  @override
  State<DMChatPage> createState() => _DMChatPageState();
}

class _DMChatPageState extends State<DMChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DMService _dmService = DMService();
  late final String _currentUserId;
  AppUser? _myUser;
  AppUser? _otherUser;
  List<XFile> _stagedImages = [];
  bool _isUploading = false;
  DMMessage? _replyingTo;
  final Set<String> _mentionedUids = {};
  String? _mentionQuery;

  @override
  void initState() {
    super.initState();
    _currentUserId = AuthService().currentUser!.uid;
    _messageController.addListener(_onTextChanged);
    _loadUsers();
    DMService().markAsRead(_currentUserId, widget.otherUserId);
  }

  void _onTextChanged() {
    final query = MentionDetector.activeQuery(_messageController.value);
    if (query != _mentionQuery) {
      setState(() => _mentionQuery = query);
    }
  }

  List<MentionCandidate> get _mentionCandidates {
    if (_otherUser == null) return const [];
    return [
      MentionCandidate(
        uid: _otherUser!.uid,
        displayName: _otherUser!.displayName,
        photoURL: _otherUser!.photoURL,
      ),
    ];
  }

  void _pickMention(MentionCandidate user) {
    final newValue =
        MentionDetector.insertMention(_messageController.value, user.displayName);
    _messageController.value = newValue;
    setState(() {
      _mentionedUids.add(user.uid);
      _mentionQuery = null;
    });
  }

  Future<void> _loadUsers() async {
    final service = UserService();
    final mine = await service.getUserById(_currentUserId);
    final other = await service.getUserById(widget.otherUserId);
    if (!mounted) return;
    setState(() {
      _myUser = mine;
      _otherUser = other;
    });
  }

  String get _myName => _myUser?.displayName ?? 'Bạn';
  String get _otherName => _otherUser?.displayName ?? widget.otherUserName;

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessageActions(BuildContext context, DMMessage msg) {
    final isOwn = msg.senderId == _currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.channelSidebar,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined, color: AppColors.textPrimary),
              title: const Text('React', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                final emoji = await showEmojiPicker(context);
                if (emoji == null) return;
                final hasReacted = (msg.reactions[emoji] ?? []).contains(_currentUserId);
                await _dmService.toggleReaction(
                  senderId: _currentUserId,
                  receiverId: widget.otherUserId,
                  messageId: msg.id,
                  emoji: emoji,
                  uid: _currentUserId,
                  hasReacted: hasReacted,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_outlined, color: AppColors.textPrimary),
              title: const Text('Trả lời', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
            ),
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: AppColors.textPrimary),
                title: const Text('Sửa tin nhắn',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.danger),
                title: const Text('Xóa tin nhắn',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirm(context, msg);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, DMMessage msg) {
    final controller = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title: const Text('Sửa tin nhắn',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Nội dung tin nhắn'),
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
              final newText = controller.text.trim();
              Navigator.pop(ctx);
              if (newText.isEmpty || newText == msg.text) return;
              await _dmService.editMessage(
                senderId: _currentUserId,
                receiverId: widget.otherUserId,
                messageId: msg.id,
                newText: newText,
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, DMMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title: const Text('Xóa tin nhắn?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Tin nhắn này sẽ bị xóa vĩnh viễn.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _dmService.deleteMessage(
                senderId: _currentUserId,
                receiverId: widget.otherUserId,
                messageId: msg.id,
              );
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final images = await CloudinaryService().pickImages();
    if (images.isEmpty) return;
    setState(() => _stagedImages = [..._stagedImages, ...images]);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final images = List<XFile>.from(_stagedImages);
    if (text.isEmpty && images.isEmpty) return;

    final reply = _replyingTo;
    // Only include mention uids whose @name is still in the final text
    final mentions = _mentionedUids
        .where((uid) {
          if (uid == _otherUser?.uid && _otherUser != null) {
            return text.contains('@${_otherUser!.displayName}');
          }
          return false;
        })
        .toList();
    _messageController.clear();
    setState(() {
      _stagedImages = [];
      _replyingTo = null;
      _mentionedUids.clear();
      _mentionQuery = null;
      _isUploading = images.isNotEmpty;
    });

    try {
      for (final img in images) {
        final url = await CloudinaryService().uploadImage(img);
        await _dmService.sendMessage(
          senderId: _currentUserId,
          receiverId: widget.otherUserId,
          text: '',
          imageUrl: url,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderId == _currentUserId ? 'Bạn' : widget.otherUserName,
          replyToText: reply?.text,
        );
      }
      if (text.isNotEmpty) {
        await _dmService.sendMessage(
          senderId: _currentUserId,
          receiverId: widget.otherUserId,
          text: text,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderId == _currentUserId ? 'Bạn' : widget.otherUserName,
          replyToText: reply?.text,
          mentions: mentions,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi upload ảnh: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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
        title: Row(
          children: [
            UserAvatar(
              name: _otherName,
              photoURL: _otherUser?.photoURL,
              radius: 16,
            ),
            const SizedBox(width: 10),
            Text(
              _otherName,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
          ],
        ),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DMMessage>>(
              stream:
                  _dmService.streamMessages(_currentUserId, widget.otherUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Lỗi: ${snapshot.error}',
                          style:
                              const TextStyle(color: AppColors.danger)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }

                final messages = snapshot.data ?? [];
                _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          name: _otherName,
                          photoURL: _otherUser?.photoURL,
                          radius: 36,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _otherName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đây là lúc bắt đầu cuộc trò chuyện với $_otherName',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                DateTime? lastDate;
                String? lastSenderId;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUserId;

                    Widget? dateSeparator;
                    if (lastDate == null ||
                        msg.timestamp.day != lastDate!.day ||
                        msg.timestamp.month != lastDate!.month ||
                        msg.timestamp.year != lastDate!.year) {
                      dateSeparator =
                          _DateSeparator(date: msg.timestamp);
                    }
                    final showHeader =
                        dateSeparator != null || lastSenderId != msg.senderId;

                    lastDate = msg.timestamp;
                    lastSenderId = msg.senderId;

                    return Column(
                      children: [
                        ?dateSeparator,
                        _DMMessageItem(
                          msg: msg,
                          isMe: isMe,
                          showHeader: showHeader,
                          senderName: isMe ? _myName : _otherName,
                          senderPhotoURL: isMe
                              ? _myUser?.photoURL
                              : _otherUser?.photoURL,
                          currentUid: _currentUserId,
                          onLongPress: () =>
                              _showMessageActions(context, msg),
                          onReact: (emoji) async {
                            final hasReacted =
                                (msg.reactions[emoji] ?? [])
                                    .contains(_currentUserId);
                            await _dmService.toggleReaction(
                              senderId: _currentUserId,
                              receiverId: widget.otherUserId,
                              messageId: msg.id,
                              emoji: emoji,
                              uid: _currentUserId,
                              hasReacted: hasReacted,
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_mentionQuery != null && _mentionCandidates.isNotEmpty)
            MentionPickerBar(
              candidates: _mentionCandidates,
              query: _mentionQuery!,
              onPick: _pickMention,
            ),
          if (_replyingTo != null)
            _ReplyBar(
              senderName: _replyingTo!.senderId == _currentUserId
                  ? 'Bạn'
                  : widget.otherUserName,
              text: _replyingTo!.text,
              onCancel: () => setState(() => _replyingTo = null),
            ),
          if (_stagedImages.isNotEmpty)
            ImagePreviewStrip(
              images: _stagedImages,
              onRemove: (i) => setState(
                  () => _stagedImages = List.from(_stagedImages)..removeAt(i)),
            ),
          _MessageInput(
            controller: _messageController,
            onSend: _isUploading ? () {} : _sendMessage,
            onPickImage: _pickImages,
            recipientName: widget.otherUserName,
          ),
        ],
      ),
    );
  }
}

// ─── DM Message Item (Discord-flat layout) ────────────────────────────────────

class _DMMessageItem extends StatefulWidget {
  final DMMessage msg;
  final bool isMe;
  final bool showHeader;
  final String senderName;
  final String? senderPhotoURL;
  final String currentUid;
  final VoidCallback? onLongPress;
  final void Function(String emoji) onReact;

  const _DMMessageItem({
    required this.msg,
    required this.isMe,
    required this.showHeader,
    required this.senderName,
    required this.senderPhotoURL,
    required this.currentUid,
    required this.onReact,
    this.onLongPress,
  });

  @override
  State<_DMMessageItem> createState() => _DMMessageItemState();
}

class _DMMessageItemState extends State<_DMMessageItem> {
  bool _hovered = false;

  String _formatTime(DateTime ts) {
    final now = DateTime.now();
    if (ts.year == now.year && ts.month == now.month && ts.day == now.day) {
      return 'Hôm nay lúc ${DateFormat('HH:mm').format(ts)}';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(ts);
  }

  String _formatInlineTime(DateTime ts) => DateFormat('HH:mm').format(ts);

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hovered ? AppColors.hoverBg : Colors.transparent,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: widget.showHeader ? 12 : 1,
            bottom: 1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: widget.showHeader
                    ? UserAvatar(
                        name: widget.senderName,
                        photoURL: widget.senderPhotoURL,
                        radius: 16,
                      )
                    : (_hovered
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatInlineTime(msg.timestamp),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showHeader)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            widget.senderName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(msg.timestamp),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    if (msg.replyToText != null)
                      _ReplyQuote(
                        senderName: msg.replyToSenderName ?? '',
                        text: msg.replyToText!,
                      ),
                    if (msg.imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            msg.imageUrl!,
                            width: 260,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                        width: 260,
                                        height: 160,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                              color: AppColors.accent,
                                              strokeWidth: 2),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    if (msg.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: FormattedText(text: msg.text),
                            ),
                            if (msg.isEdited)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(' (đã sửa)',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                              ),
                          ],
                        ),
                      ),
                    if (msg.reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: msg.reactions.entries
                              .where((e) => e.value.isNotEmpty)
                              .map((e) {
                            final reacted = e.value.contains(widget.currentUid);
                            return GestureDetector(
                              onTap: () => widget.onReact(e.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: reacted
                                      ? AppColors.accent.withValues(alpha: 0.25)
                                      : AppColors.channelSidebar,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: reacted
                                        ? AppColors.accent
                                        : AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${e.key} ${e.value.length}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Date Separator ───────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ─── Reply Bar ────────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  final String senderName;
  final String text;
  final VoidCallback onCancel;

  const _ReplyBar({
    required this.senderName,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.channelSidebar,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            color: AppColors.accent,
            margin: const EdgeInsets.only(right: 10),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trả lời $senderName',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  text.isEmpty ? '📷 Ảnh' : text,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Reply Quote ──────────────────────────────────────────────────────────────

class _ReplyQuote extends StatelessWidget {
  final String senderName;
  final String text;

  const _ReplyQuote({required this.senderName, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            text.isEmpty ? '📷 Ảnh' : text,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Message Input ────────────────────────────────────────────────────────────

class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final String recipientName;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.recipientName,
  });

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateText);
    super.dispose();
  }

  void _updateText() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle,
                  color: AppColors.textMuted, size: 24),
              onPressed: widget.onPickImage,
              tooltip: 'Gửi ảnh',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: widget.controller,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    hintText: 'Nhắn tin cho ${widget.recipientName}',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 15),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _hasText
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.accent, size: 22),
                      onPressed: widget.onSend,
                      tooltip: 'Gửi',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    )
                  : const SizedBox(
                      key: ValueKey('empty'),
                      width: 40,
                      height: 40,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
