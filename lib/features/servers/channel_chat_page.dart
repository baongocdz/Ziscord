import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/channel_icon_picker.dart';
import '../../core/widgets/emoji_picker_sheet.dart';
import '../../core/widgets/formatted_text.dart';
import '../../core/widgets/image_preview_strip.dart';
import '../../core/widgets/mention_picker_bar.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/user_profile_sheet.dart';
import '../../data/models/app_user.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/models/server_member.dart';
import '../../data/models/server_message.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/mention_service.dart';
import '../../data/services/server_service.dart';
import '../../data/services/user_service.dart';

class ChannelChatPage extends StatefulWidget {
  final Server server;
  final ServerChannel channel;

  const ChannelChatPage({
    super.key,
    required this.server,
    required this.channel,
  });

  @override
  State<ChannelChatPage> createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _serverService = ServerService();
  final _userService = UserService();
  final _mentionService = MentionService();
  final Map<String, AppUser?> _userCache = {};
  late final String _currentUid;
  List<XFile> _stagedImages = [];
  bool _isUploading = false;
  ServerMessage? _replyingTo;
  List<ServerMemberInfo> _members = [];
  final Set<String> _mentionedUids = {};
  String? _mentionQuery;
  String? _lastSeenMessageId;

  @override
  void initState() {
    super.initState();
    _currentUid = AuthService().currentUser!.uid;
    _messageController.addListener(_onTextChanged);
    _loadMembers();
    _markMentionsRead();
  }

  Future<void> _markMentionsRead() async {
    await _mentionService.markChannelMentionsAsRead(
        _currentUid, widget.server.id, widget.channel.id);
    await _serverService.markChannelAsRead(
        widget.server.id, widget.channel.id);
  }

  Future<void> _loadMembers() async {
    final members =
        await _serverService.streamMembersWithNames(widget.server.id).first;
    if (!mounted) return;
    setState(() => _members = members);
    // Pre-fetch user photos so the mention picker shows avatars immediately
    // instead of fallback initials (the picker reads `_userCache`).
    _ensureUsersLoaded(members.map((m) => m.uid));
  }

  void _onTextChanged() {
    final query = MentionDetector.activeQuery(_messageController.value);
    if (query != _mentionQuery) {
      setState(() => _mentionQuery = query);
    }
  }

  List<MentionCandidate> get _mentionCandidates {
    return _members
        .where((m) => m.uid != _currentUid)
        .map((m) => MentionCandidate(
              uid: m.uid,
              displayName: m.effectiveName,
              photoURL: _userCache[m.uid]?.photoURL,
            ))
        .toList();
  }

  void _pickMention(MentionCandidate user) {
    final newValue = MentionDetector.insertMention(
        _messageController.value, user.displayName);
    _messageController.value = newValue;
    setState(() {
      _mentionedUids.add(user.uid);
      _mentionQuery = null;
    });
  }

  void _ensureUsersLoaded(Iterable<String> uids) {
    final missing =
        uids.toSet().where((u) => !_userCache.containsKey(u)).toList();
    if (missing.isEmpty) return;
    // Mark as loading to avoid duplicate fetches
    for (final uid in missing) {
      _userCache[uid] = null;
    }
    for (final uid in missing) {
      _userService.getUserById(uid).then((user) {
        if (!mounted) return;
        setState(() => _userCache[uid] = user);
      });
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessageActions(BuildContext context, ServerMessage msg) {
    final isOwn = msg.senderId == _currentUid;
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
                final hasReacted = (msg.reactions[emoji] ?? []).contains(_currentUid);
                await _serverService.toggleReaction(
                  serverId: widget.server.id,
                  channelId: widget.channel.id,
                  messageId: msg.id,
                  emoji: emoji,
                  uid: _currentUid,
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
            ListTile(
              leading: Icon(
                msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text(
                msg.isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _serverService.pinMessage(
                  serverId: widget.server.id,
                  channelId: widget.channel.id,
                  messageId: msg.id,
                  pin: !msg.isPinned,
                );
              },
            ),
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                title: const Text('Sửa tin nhắn',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
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

  void _showEditDialog(BuildContext context, ServerMessage msg) {
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
              await _serverService.editMessage(
                serverId: widget.server.id,
                channelId: widget.channel.id,
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

  void _showDeleteConfirm(BuildContext context, ServerMessage msg) {
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
              await _serverService.deleteMessage(
                serverId: widget.server.id,
                channelId: widget.channel.id,
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
    // Auto-detect mentions: any member whose @effectiveName appears in text
    final mentions = _members
        .where((m) =>
            m.uid != _currentUid && text.contains('@${m.effectiveName}'))
        .map((m) => m.uid)
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
        await _serverService.sendMessage(
          serverId: widget.server.id,
          channelId: widget.channel.id,
          text: '',
          imageUrl: url,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderName,
          replyToText: reply?.text,
        );
      }
      if (text.isNotEmpty) {
        await _serverService.sendMessage(
          serverId: widget.server.id,
          channelId: widget.channel.id,
          text: text,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderName,
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
            ChannelIcon(
              customIcon: widget.channel.icon,
              fallbackIcon: widget.channel.isLibrary
                  ? Icons.menu_book_rounded
                  : Icons.tag,
              color: AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              widget.channel.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
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
            child: StreamBuilder<List<ServerMessage>>(
              stream: _serverService.streamMessages(
                  widget.server.id, widget.channel.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}',
                        style:
                            const TextStyle(color: AppColors.danger)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent));
                }

                final messages = snapshot.data ?? [];
                _scrollToBottom();

                if (messages.isNotEmpty) {
                  final latestId = messages.last.id;
                  if (latestId != _lastSeenMessageId) {
                    _lastSeenMessageId = latestId;
                    _markMentionsRead();
                  }
                }

                if (messages.isEmpty) {
                  return _EmptyChannelView(channel: widget.channel);
                }

                _ensureUsersLoaded(messages.map((m) => m.senderId));

                DateTime? lastDate;
                String? lastSenderId;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUid;

                    Widget? separator;
                    if (lastDate == null ||
                        msg.timestamp.day != lastDate!.day ||
                        msg.timestamp.month != lastDate!.month ||
                        msg.timestamp.year != lastDate!.year) {
                      separator = _DateSeparator(date: msg.timestamp);
                    }

                    final isGrouped = lastSenderId == msg.senderId &&
                        separator == null;

                    lastDate = msg.timestamp;
                    lastSenderId = msg.senderId;

                    return Column(
                      children: [
                        ?separator,
                        _ServerMessageBubble(
                          msg: msg,
                          showHeader: !isGrouped,
                          currentUid: _currentUid,
                          senderPhotoURL: _userCache[msg.senderId]?.photoURL,
                          onLongPress: () => _showMessageActions(context, msg),
                          onTapAuthor: isMe
                              ? null
                              : () => showUserProfile(
                                    context,
                                    userId: msg.senderId,
                                    userName: msg.senderName,
                                  ),
                          onReact: (emoji) async {
                            final hasReacted = (msg.reactions[emoji] ?? [])
                                .contains(_currentUid);
                            await _serverService.toggleReaction(
                              serverId: widget.server.id,
                              channelId: widget.channel.id,
                              messageId: msg.id,
                              emoji: emoji,
                              uid: _currentUid,
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
              senderName: _replyingTo!.senderName,
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
            channelName: widget.channel.name,
            onSend: _isUploading ? () {} : _sendMessage,
            onPickImage: _pickImages,
          ),
        ],
      ),
    );
  }
}

// ─── Empty Channel View ───────────────────────────────────────────────────────

class _EmptyChannelView extends StatelessWidget {
  final ServerChannel channel;
  const _EmptyChannelView({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.channelSidebar,
              shape: BoxShape.circle,
            ),
            child: Icon(
              channel.isLibrary ? Icons.menu_book_rounded : Icons.tag,
              color: AppColors.textMuted,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '#${channel.name}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Đây là lúc bắt đầu kênh này',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _ServerMessageBubble extends StatefulWidget {
  final ServerMessage msg;
  final bool showHeader;
  final VoidCallback? onLongPress;
  final VoidCallback? onTapAuthor;
  final String currentUid;
  final String? senderPhotoURL;
  final void Function(String emoji) onReact;

  const _ServerMessageBubble({
    required this.msg,
    required this.showHeader,
    required this.currentUid,
    required this.onReact,
    this.senderPhotoURL,
    this.onLongPress,
    this.onTapAuthor,
  });

  @override
  State<_ServerMessageBubble> createState() => _ServerMessageBubbleState();
}

class _ServerMessageBubbleState extends State<_ServerMessageBubble> {
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
                    ? GestureDetector(
                        onTap: widget.onTapAuthor,
                        child: UserAvatar(
                          name: msg.senderName,
                          photoURL: widget.senderPhotoURL,
                          radius: 16,
                          backgroundColor: const Color(0xFF5B6170),
                        ),
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
                      GestureDetector(
                        onTap: widget.onTapAuthor,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              msg.senderName,
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
                    if (msg.isPinned)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin,
                                color: AppColors.textMuted, size: 12),
                            SizedBox(width: 4),
                            Text('Đã ghim',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11)),
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
                            final reacted =
                                e.value.contains(widget.currentUid);
                            return GestureDetector(
                              onTap: () => widget.onReact(e.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: reacted
                                      ? AppColors.accent
                                          .withValues(alpha: 0.25)
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
  final String channelName;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _MessageInput({
    required this.controller,
    required this.channelName,
    required this.onSend,
    required this.onPickImage,
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
                    hintText: 'Nhắn tin vào #${widget.channelName}',
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
