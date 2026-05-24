import 'package:flutter/material.dart';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/channel_icon_picker.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/models/voice_member.dart';
import '../../data/models/voice_session.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/server_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/voice_service.dart';
import 'channel_chat_page.dart';

const Color _speakingGreen = Color(0xFF23A559);

class VoiceChannelPage extends StatefulWidget {
  final Server server;
  final ServerChannel channel;

  const VoiceChannelPage({
    super.key,
    required this.server,
    required this.channel,
  });

  @override
  State<VoiceChannelPage> createState() => _VoiceChannelPageState();
}

class _VoiceChannelPageState extends State<VoiceChannelPage> {
  final _voiceService = VoiceService();
  final _userService = UserService();
  final _serverService = ServerService();

  bool _joining = false;
  ConnectionStateType? _agoraState;

  Future<void> _join() async {
    debugPrint('[voice-page] _join() tap');
    setState(() {
      _joining = true;
    });
    try {
      final uid = AuthService().currentUser!.uid;
      final user = await _userService.getUserById(uid);
      final nickname =
          await _serverService.getServerNickname(widget.server.id, uid);
      final displayName = nickname?.trim().isNotEmpty == true
          ? nickname!.trim()
          : user?.displayName ?? 'User';

      await _voiceService.join(
        serverId: widget.server.id,
        channelId: widget.channel.id,
        serverName: widget.server.name,
        channelName: widget.channel.name,
        channelIcon: widget.channel.icon,
        uid: uid,
        displayName: displayName,
        photoURL: user?.photoURL,
        onConnectionState: (state) {
          if (!mounted) return;
          setState(() => _agoraState = state);
        },
      );

      if (!mounted) return;
      setState(() {
        _joining = false;
      });
    } catch (e, st) {
      debugPrint('[voice-page] _join() FAILED: $e\n$st');
      if (!mounted) return;
      setState(() {
        _joining = false;
      });
    }
  }

  Future<void> _toggleMute() async {
    await _voiceService.toggleMute();
    if (!mounted) return;
    setState(() {});
  }

  /// Leave voice AND pop the page. Bound to the red phone button.
  Future<void> _leaveAndPop() async {
    final navigator = Navigator.of(context);
    await _voiceService.leave();
    if (!mounted) return;
    navigator.pop();
  }

  /// Just pop the page. Voice continues in background. Bound to back arrow.
  void _popOnly() {
    Navigator.of(context).pop();
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChannelChatPage(server: widget.server, channel: widget.channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: _popOnly,
          tooltip: 'Quay lại (vẫn ở trong kênh thoại)',
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ChannelIcon(
              customIcon: widget.channel.icon,
              fallbackIcon: Icons.volume_up_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(widget.channel.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                color: AppColors.textMuted, size: 20),
            tooltip: 'Mở chat của kênh',
            onPressed: _openChat,
          ),
        ],
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.divider, height: 1),
        ),
      ),
      body: ValueListenableBuilder<VoiceSession?>(
        valueListenable: _voiceService.currentSession,
        builder: (context, session, _) {
          final inThis = session != null &&
              session.serverId == widget.server.id &&
              session.channelId == widget.channel.id;
          final inOther = session != null && !inThis;
          return Column(
            children: [
              if (inThis) _buildStatusBanner(),
              if (inOther) _buildOtherChannelBanner(session),
              Expanded(child: _buildBody(inThis)),
              _buildControlBar(inThis, inOther),
            ],
          );
        },
      ),
    );
  }

  String _stateLabel(ConnectionStateType? state) {
    switch (state) {
      case ConnectionStateType.connectionStateConnecting:
        return 'Đang kết nối...';
      case ConnectionStateType.connectionStateConnected:
        return 'Đã kết nối';
      case ConnectionStateType.connectionStateReconnecting:
        return 'Đang kết nối lại...';
      case ConnectionStateType.connectionStateFailed:
        return 'Mất kết nối, đang thử lại...';
      case ConnectionStateType.connectionStateDisconnected:
        return 'Đang kết nối lại...';
      default:
        return 'Đang khởi tạo...';
    }
  }

  Widget _buildStatusBanner() {
    final isHealthy =
        _agoraState == ConnectionStateType.connectionStateConnected;
    if (isHealthy) return const SizedBox.shrink();
    final color = AppColors.textMuted;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _stateLabel(_agoraState),
              style: TextStyle(color: color, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherChannelBanner(VoiceSession s) {
    return Container(
      width: double.infinity,
      color: AppColors.accent.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang ở kênh "${s.channelName}". Bấm "Chuyển sang kênh này" để rời và join.',
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool inThis) {
    return StreamBuilder<List<VoiceMember>>(
      stream: _voiceService.streamMembers(widget.server.id, widget.channel.id),
      builder: (context, snap) {
        final members = snap.data ?? const <VoiceMember>[];
        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headset_off,
                    size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(
                  inThis
                      ? 'Chưa có ai khác trong kênh thoại'
                      : 'Chưa có ai trong kênh thoại',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }
        return ValueListenableBuilder<Set<int>>(
          valueListenable: _voiceService.speakingAgoraUids,
          builder: (context, speakingSet, _) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                final agoraUid = VoiceService.agoraUidFor(m.uid);
                final isSpeaking =
                    inThis && speakingSet.contains(agoraUid) && !m.isMuted;
                return _VoiceTile(member: m, isSpeaking: isSpeaking);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildControlBar(bool inThis, bool inOther) {
    if (inOther) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.channelSidebar,
        child: _bigButton(
          label: _joining ? 'Đang chuyển...' : 'Chuyển sang kênh này',
          icon: Icons.swap_horiz,
          color: AppColors.accent,
          onTap: _joining ? null : _join,
        ),
      );
    }
    if (!inThis) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.channelSidebar,
        child: _bigButton(
          label: _joining ? 'Đang vào...' : 'Vào kênh thoại',
          icon: Icons.call,
          color: _speakingGreen,
          onTap: _joining ? null : _join,
        ),
      );
    }

    final listenOnly = _voiceService.isListenOnly;
    final muted = _voiceService.isMuted;
    final micOff = listenOnly || muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.channelSidebar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _circleBtn(
            icon: micOff ? Icons.mic_off : Icons.mic,
            color: micOff ? AppColors.danger : AppColors.textPrimary,
            bg: AppColors.background,
            onTap: listenOnly ? null : _toggleMute,
            tooltip: listenOnly
                ? 'Không có micro — chế độ chỉ nghe'
                : (muted ? 'Bật micro' : 'Tắt micro'),
          ),
          const SizedBox(width: 24),
          _circleBtn(
            icon: Icons.call_end,
            color: Colors.white,
            bg: AppColors.danger,
            onTap: _leaveAndPop,
            tooltip: 'Rời kênh',
          ),
        ],
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: onTap == null ? color.withValues(alpha: 0.5) : color,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final VoiceMember member;
  final bool isSpeaking;
  const _VoiceTile({required this.member, required this.isSpeaking});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.channelSidebar,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSpeaking ? _speakingGreen : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSpeaking
                      ? [
                          BoxShadow(
                            color: _speakingGreen.withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: UserAvatar(
                    name: member.displayName,
                    photoURL: member.photoURL,
                    radius: 36),
              ),
              if (member.isMuted)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.channelSidebar, width: 2),
                    ),
                    child: const Icon(Icons.mic_off,
                        color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}
