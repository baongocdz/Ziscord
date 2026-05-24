import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/channel_icon_picker.dart';
import '../../data/models/voice_session.dart';
import '../../data/services/server_service.dart';
import '../../data/services/voice_service.dart';
import 'voice_channel_page.dart';

/// Sticky bar above the bottom nav that surfaces the active voice session.
/// Tap to reopen the voice page; mic / leave buttons act on the service.
class MiniVoiceBar extends StatelessWidget {
  const MiniVoiceBar({super.key});

  Future<void> _openVoicePage(BuildContext context, VoiceSession s) async {
    final service = ServerService();
    final server = await service.getServer(s.serverId);
    final channels = await service.streamChannels(s.serverId).first;
    final channel = channels.where((c) => c.id == s.channelId).firstOrNull;
    if (!context.mounted || server == null || channel == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceChannelPage(server: server, channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = VoiceService();
    return ValueListenableBuilder<VoiceSession?>(
      valueListenable: voice.currentSession,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: voice.mutedNotifier,
          builder: (context, muted, _) {
            final listenOnly = voice.isListenOnly;
            final micOff = listenOnly || muted;
            return Material(
              color: const Color(0xFF1A4D2E),
              child: InkWell(
                onTap: () => _openVoicePage(context, session),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_rounded,
                          color: Color(0xFF23A559), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                ChannelIcon(
                                  customIcon: session.channelIcon,
                                  fallbackIcon: Icons.volume_up_rounded,
                                  color: AppColors.textPrimary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    session.channelName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Trong ${session.serverName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      _MiniBtn(
                        icon: micOff ? Icons.mic_off : Icons.mic,
                        color: micOff
                            ? AppColors.danger
                            : AppColors.textPrimary,
                        onTap: listenOnly ? null : voice.toggleMute,
                        tooltip: listenOnly
                            ? 'Chỉ nghe'
                            : (muted ? 'Bật mic' : 'Tắt mic'),
                      ),
                      const SizedBox(width: 4),
                      _MiniBtn(
                        icon: Icons.call_end,
                        color: Colors.white,
                        bg: AppColors.danger,
                        onTap: () => voice.leave(),
                        tooltip: 'Rời kênh',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? bg;
  final VoidCallback? onTap;
  final String tooltip;

  const _MiniBtn({
    required this.icon,
    required this.color,
    this.bg,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? color.withValues(alpha: 0.5) : color,
          ),
        ),
      ),
    );
  }
}
