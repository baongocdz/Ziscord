import 'package:flutter/material.dart';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/channel_icon_picker.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/server.dart';
import '../../data/models/server_channel.dart';
import '../../data/models/voice_member.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/server_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/voice_service.dart';

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
  bool _connected = false;
  bool _muted = false;
  bool _listenOnly = false;
  String? _errorMessage;
  ConnectionStateType? _agoraState;

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _errorMessage = null;
    });
    try {
      final uid = AuthService().currentUser!.uid;
      final user = await _userService.getUserById(uid);
      final nickname = await _serverService.getServerNickname(
          widget.server.id, uid);
      final displayName = nickname?.trim().isNotEmpty == true
          ? nickname!.trim()
          : user?.displayName ?? 'User';

      await _voiceService.join(
        serverId: widget.server.id,
        channelId: widget.channel.id,
        uid: uid,
        displayName: displayName,
        photoURL: user?.photoURL,
        onError: (msg) {
          if (!mounted) return;
          setState(() => _errorMessage = msg);
        },
        onConnectionState: (state) {
          if (!mounted) return;
          setState(() => _agoraState = state);
        },
      );

      if (!mounted) return;
      setState(() {
        _joining = false;
        _connected = true;
        _listenOnly = _voiceService.isListenOnly;
        _muted = _voiceService.isMuted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _errorMessage = _translateError(e);
      });
    }
  }

  String _translateError(Object e) {
    final s = e.toString();
    if (s.contains('NotFoundError') ||
        s.contains('Requested device not found')) {
      return 'Không tìm thấy microphone. Cắm hoặc bật micro trong cài đặt hệ thống, sau đó thử lại.';
    }
    if (s.contains('NotAllowedError') || s.contains('Permission')) {
      return 'Bạn đã chặn quyền microphone. Cho phép quyền trong cài đặt trình duyệt rồi thử lại.';
    }
    if (s.contains('NotReadableError')) {
      return 'Microphone đang được app khác sử dụng. Tắt app đó (Zoom, OBS, Discord…) rồi thử lại.';
    }
    return 'Lỗi vào kênh: $e';
  }

  Future<void> _toggleMute() async {
    await _voiceService.toggleMute();
    if (!mounted) return;
    setState(() => _muted = _voiceService.isMuted);
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    await _voiceService.leave();
    if (!mounted) return;
    navigator.pop();
  }

  @override
  void dispose() {
    _voiceService.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_connected,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _voiceService.leave();
        if (!mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.channelSidebar,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
            onPressed: _leave,
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
              Text(widget.channel.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
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
            if (_connected) _buildStatusBanner(),
            if (_connected && _listenOnly) _buildListenOnlyBanner(),
            Expanded(child: _buildBody()),
            _buildControlBar(),
          ],
        ),
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
        return 'Kết nối Agora thất bại';
      case ConnectionStateType.connectionStateDisconnected:
        return 'Mất kết nối';
      default:
        return 'Đang khởi tạo...';
    }
  }

  Widget _buildListenOnlyBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.accent.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.hearing, color: AppColors.accent, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chế độ chỉ nghe — máy không có micro hoặc bị chặn quyền. Bạn vẫn nghe được người khác nói.',
              style: TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final hasError = _errorMessage != null;
    final stateLabel = _stateLabel(_agoraState);
    final isHealthy = _agoraState == ConnectionStateType.connectionStateConnected;
    final color = hasError || _agoraState == ConnectionStateType.connectionStateFailed
        ? AppColors.danger
        : (isHealthy ? const Color(0xFF23A559) : AppColors.textMuted);
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
              hasError ? _errorMessage! : stateLabel,
              style: TextStyle(color: color, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<List<VoiceMember>>(
      stream:
          _voiceService.streamMembers(widget.server.id, widget.channel.id),
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
                  _connected
                      ? 'Chưa có ai khác trong kênh thoại'
                      : 'Chưa có ai trong kênh thoại',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: members.length,
          itemBuilder: (_, i) => _VoiceTile(member: members[i]),
        );
      },
    );
  }

  Widget _buildControlBar() {
    if (_errorMessage != null && !_connected) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.channelSidebar,
        child: Column(
          children: [
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            _bigButton(
                label: 'Thử lại',
                color: AppColors.accent,
                icon: Icons.refresh,
                onTap: _join),
          ],
        ),
      );
    }
    if (!_connected) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.channelSidebar,
        child: _bigButton(
          label: _joining ? 'Đang vào...' : 'Vào kênh thoại',
          icon: Icons.call,
          color: const Color(0xFF23A559),
          onTap: _joining ? null : _join,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.channelSidebar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _circleBtn(
            icon: _listenOnly
                ? Icons.mic_off
                : (_muted ? Icons.mic_off : Icons.mic),
            color: (_listenOnly || _muted)
                ? AppColors.danger
                : AppColors.textPrimary,
            bg: AppColors.background,
            onTap: _listenOnly ? null : _toggleMute,
            tooltip: _listenOnly
                ? 'Không có micro'
                : (_muted ? 'Bật micro' : 'Tắt micro'),
          ),
          const SizedBox(width: 24),
          _circleBtn(
            icon: Icons.call_end,
            color: Colors.white,
            bg: AppColors.danger,
            onTap: _leave,
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
  const _VoiceTile({required this.member});

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
              UserAvatar(
                  name: member.displayName,
                  photoURL: member.photoURL,
                  radius: 36),
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

