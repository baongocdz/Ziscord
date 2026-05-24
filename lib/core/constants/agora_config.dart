/// Agora project config.
///
/// App ID is safe to ship in client code (it's an identifier, not a secret).
/// Token mode:
///   - Project on Testing Mode → leave `kAgoraToken` null; join with `token: null`.
///   - Project on Secure Mode  → need a Cloud Function to mint per-channel tokens.
///     The temp token from the console only works for the single channel name
///     you typed when generating it, so it's not a general fallback.
class AgoraConfig {
  static const String appId = '7d38b1bef5d643cfa0c3a5035e7a32c4';

  /// Channel name strategy: use `<serverId>_<channelId>` so the same Ziscord
  /// channel ID across servers can't collide.
  static String channelName(String serverId, String channelId) =>
      '${serverId}_$channelId';
}
