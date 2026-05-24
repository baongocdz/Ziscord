import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/agora_config.dart';
import '../models/voice_member.dart';
import '../models/voice_session.dart';

/// App-wide singleton that owns the Agora engine and Firestore voice presence.
///
/// Singleton because voice persists across navigation: the user can leave the
/// VoiceChannelPage (back arrow) but stay connected. Only an explicit [leave]
/// (red phone button or mini-bar disconnect) tears down the session.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final _db = FirebaseFirestore.instance;

  RtcEngine? _engine;
  String? _currentServerId;
  String? _currentChannelId;
  String? _currentUid;
  int? _localAgoraUid;
  bool _isMuted = false;
  bool _listenOnly = false;
  final Set<int> _remoteAgoraUids = {};

  /// Current voice session (null = not in any voice channel). UI watches this
  /// to show/hide the mini bar and to detect "already connected" on page open.
  final ValueNotifier<VoiceSession?> currentSession =
      ValueNotifier<VoiceSession?>(null);

  /// Whether the local mic is muted. Exposed as a notifier so the mini bar
  /// can stay in sync without polling.
  final ValueNotifier<bool> mutedNotifier = ValueNotifier<bool>(false);

  /// Set of Agora UIDs currently above the speaking volume threshold. Local
  /// user is mapped to [_localAgoraUid] (Agora reports local as uid=0).
  final ValueNotifier<Set<int>> speakingAgoraUids =
      ValueNotifier<Set<int>>(const <int>{});

  bool get isMuted => _isMuted;
  bool get isListenOnly => _listenOnly;
  bool get isInSession => currentSession.value != null;

  CollectionReference _voiceMembers(String sid, String cid) => _db
      .collection('servers')
      .doc(sid)
      .collection('channels')
      .doc(cid)
      .collection('voice_members');

  Stream<List<VoiceMember>> streamMembers(String serverId, String channelId) {
    return _voiceMembers(serverId, channelId)
        .orderBy('joinedAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                VoiceMember.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<int> streamMemberCount(String serverId, String channelId) {
    return _voiceMembers(serverId, channelId)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Maps a Firebase uid to the deterministic Agora numeric uid used in join.
  static int agoraUidFor(String firebaseUid) =>
      firebaseUid.hashCode & 0x7FFFFFFF;

  /// Whether the given channel is the one this service is currently in.
  bool isCurrentChannel(String serverId, String channelId) {
    final s = currentSession.value;
    return s != null && s.serverId == serverId && s.channelId == channelId;
  }

  /// Initializes the Agora engine, joins the channel, and writes the current
  /// user to the voice_members subcollection. If already in another channel,
  /// leaves it first. If the device has no mic or the permission is denied,
  /// falls back silently to listen-only.
  Future<void> join({
    required String serverId,
    required String channelId,
    required String serverName,
    required String channelName,
    String? channelIcon,
    required String uid,
    required String displayName,
    String? photoURL,
    void Function(int agoraUid)? onRemoteJoined,
    void Function(int agoraUid)? onRemoteLeft,
    void Function(String message)? onError,
    void Function(ConnectionStateType state)? onConnectionState,
  }) async {
    debugPrint('[voice] join() called sid=$serverId cid=$channelId');
    // If we're already in this exact channel, no-op — caller can just attach
    // listeners to the existing session.
    if (isCurrentChannel(serverId, channelId)) {
      debugPrint('[voice] already in this channel, returning early');
      return;
    }

    // Otherwise tear down any existing session first.
    if (_engine != null) {
      debugPrint('[voice] previous engine exists, leaving first');
      await leave();
    }

    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _listenOnly = true;
      }
    }

    _currentServerId = serverId;
    _currentChannelId = channelId;
    _currentUid = uid;
    _localAgoraUid = agoraUidFor(uid);
    speakingAgoraUids.value = const <int>{};
    _isMuted = false;
    mutedNotifier.value = false;

    debugPrint('[voice] creating engine with appId=${AgoraConfig.appId}');
    final engine = createAgoraRtcEngine();
    _engine = engine;
    try {
      await engine.initialize(
          const RtcEngineContext(appId: AgoraConfig.appId));
      debugPrint('[voice] engine.initialize OK');
    } catch (e) {
      debugPrint('[voice] engine.initialize FAILED: $e');
      rethrow;
    }
    await engine
        .setChannelProfile(ChannelProfileType.channelProfileCommunication);

    try {
      await engine.enableAudio();
    } catch (_) {
      _listenOnly = true;
      try {
        await engine.enableLocalAudio(false);
        await engine.enableAudio();
      } catch (_) {}
    }

    if (_listenOnly) {
      try {
        await engine.enableLocalAudio(false);
      } catch (_) {}
    }

    try {
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
    } catch (_) {}

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await engine.setDefaultAudioRouteToSpeakerphone(true);
      } catch (_) {}
    }

    try {
      await engine.disableVideo();
    } catch (_) {}

    engine.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (conn, remoteUid, elapsed) {
        _remoteAgoraUids.add(remoteUid);
        onRemoteJoined?.call(remoteUid);
      },
      onUserOffline: (conn, remoteUid, reason) {
        _remoteAgoraUids.remove(remoteUid);
        final next = Set<int>.from(speakingAgoraUids.value)..remove(remoteUid);
        if (next.length != speakingAgoraUids.value.length) {
          speakingAgoraUids.value = next;
        }
        onRemoteLeft?.call(remoteUid);
      },
      onError: (err, msg) {
        final lower = msg.toLowerCase();
        if (lower.contains('device') ||
            lower.contains('microphone') ||
            lower.contains('mic ') ||
            lower.contains('record') ||
            lower.contains('playout') ||
            lower.contains('audio')) {
          return;
        }
        onError?.call('Agora ${err.name}: $msg');
      },
      onConnectionStateChanged: (conn, state, reason) {
        debugPrint(
            '[voice] connectionStateChanged state=${state.name} reason=${reason.name}');
        onConnectionState?.call(state);
      },
      onAudioVolumeIndication: (conn, speakers, speakerNumber, totalVolume) {
        // print() reaches the browser console on web (debugPrint may not).
        // ignore: avoid_print
        print(
            '[voice] volumeEvent total=$totalVolume count=$speakerNumber raw=${speakers.map((s) => "${s.uid}:${s.volume}").toList()}');
        const threshold = 1;
        final next = <int>{};
        for (final s in speakers) {
          final v = s.volume ?? 0;
          if (v < threshold) continue;
          final aUid = (s.uid == null || s.uid == 0) ? _localAgoraUid : s.uid;
          if (aUid != null) next.add(aUid);
        }
        final cur = speakingAgoraUids.value;
        if (next.length != cur.length || !next.containsAll(cur)) {
          // ignore: avoid_print
          print('[voice] speaking set → $next');
          speakingAgoraUids.value = next;
        }
      },
    ));

    final agoraChannelName = AgoraConfig.channelName(serverId, channelId);
    debugPrint(
        '[voice] joining channel="$agoraChannelName" uid=$_localAgoraUid listenOnly=$_listenOnly');

    Future<void> doJoin(bool listenOnly) {
      return engine.joinChannel(
        token: '',
        channelId: agoraChannelName,
        uid: _localAgoraUid!,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: !listenOnly,
          autoSubscribeAudio: true,
        ),
      );
    }

    try {
      await doJoin(_listenOnly);
      debugPrint('[voice] joinChannel OK');
    } catch (e) {
      // Agora Web SDK only tries to create the mic track inside joinChannel
      // (not enableAudio), so a missing/blocked mic surfaces here. Retry in
      // listen-only mode so the user can still hear others.
      final msg = e.toString().toLowerCase();
      final isMicError = msg.contains('notfounderror') ||
          msg.contains('device not found') ||
          msg.contains('notallowederror') ||
          msg.contains('permission') ||
          msg.contains('microphone') ||
          msg.contains('createmicrophoneaudiotrack') ||
          msg.contains('notreadableerror');
      if (!isMicError) {
        debugPrint('[voice] joinChannel FAILED (non-mic): $e');
        rethrow;
      }
      debugPrint('[voice] mic unavailable, retrying in listen-only mode');
      _listenOnly = true;
      try {
        await engine.enableLocalAudio(false);
      } catch (_) {}
      // After a failed join, Agora may have partially entered the channel —
      // leave first to reset state before re-joining.
      try {
        await engine.leaveChannel();
      } catch (_) {}
      try {
        await doJoin(true);
        debugPrint('[voice] joinChannel OK (listen-only fallback)');
      } catch (e2) {
        debugPrint('[voice] joinChannel FAILED even in listen-only: $e2');
        rethrow;
      }
    }

    // Volume indication must be enabled AFTER joinChannel on Agora Web SDK
    // (it operates on the active client/connection).
    try {
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: false,
      );
      // ignore: avoid_print
      print('[voice] enableAudioVolumeIndication OK');
    } catch (e) {
      // ignore: avoid_print
      print('[voice] enableAudioVolumeIndication FAILED: $e');
    }

    await _voiceMembers(serverId, channelId).doc(uid).set({
      'displayName': displayName,
      'photoURL': photoURL,
      'isMuted': _listenOnly,
      'isListenOnly': _listenOnly,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    currentSession.value = VoiceSession(
      serverId: serverId,
      channelId: channelId,
      serverName: serverName,
      channelName: channelName,
      channelIcon: channelIcon,
    );
  }

  Future<void> toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
    if (_listenOnly) return;
    _isMuted = !_isMuted;
    mutedNotifier.value = _isMuted;
    await engine.muteLocalAudioStream(_isMuted);
    final sid = _currentServerId;
    final cid = _currentChannelId;
    final uid = _currentUid;
    if (sid != null && cid != null && uid != null) {
      await _voiceMembers(sid, cid).doc(uid).update({'isMuted': _isMuted});
    }
  }

  /// Leaves the channel, removes Firestore presence, and releases the engine.
  /// Safe to call multiple times.
  Future<void> leave() async {
    final engine = _engine;
    final sid = _currentServerId;
    final cid = _currentChannelId;
    final uid = _currentUid;

    _engine = null;
    _currentServerId = null;
    _currentChannelId = null;
    _currentUid = null;
    _localAgoraUid = null;
    _isMuted = false;
    _listenOnly = false;
    _remoteAgoraUids.clear();
    speakingAgoraUids.value = const <int>{};
    mutedNotifier.value = false;
    currentSession.value = null;

    if (sid != null && cid != null && uid != null) {
      await _voiceMembers(sid, cid).doc(uid).delete().catchError((_) {});
    }
    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (_) {}
      try {
        await engine.release();
      } catch (_) {}
    }
  }
}
