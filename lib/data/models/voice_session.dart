/// Snapshot of the active voice session, exposed by VoiceService so the UI
/// (mini bar, voice page) can react to join/leave without holding refs.
class VoiceSession {
  final String serverId;
  final String channelId;
  final String serverName;
  final String channelName;
  final String? channelIcon;

  const VoiceSession({
    required this.serverId,
    required this.channelId,
    required this.serverName,
    required this.channelName,
    this.channelIcon,
  });
}
