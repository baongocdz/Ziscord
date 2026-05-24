import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/agora_config.dart';
import '../models/voice_member.dart';

/// Manages a single voice-channel session: Agora engine + Firestore presence.
///
/// Lifetime: one instance per `VoiceChannelPage`. Always call [leave] before
/// disposing; the engine is expensive and must be released.
class VoiceService {
  final _db = FirebaseFirestore.instance;

  RtcEngine? _engine;
  String? _currentServerId;
  String? _currentChannelId;
  String? _currentUid;
  int? _localAgoraUid;
  bool _isMuted = false;
  bool _listenOnly = false;
  final Set<int> _remoteAgoraUids = {};

  /// Set of Agora UIDs currently above the speaking volume threshold. Local
  /// user is mapped to [_localAgoraUid] (Agora reports local as uid=0).
  final ValueNotifier<Set<int>> speakingAgoraUids =
      ValueNotifier<Set<int>>(const <int>{});

  bool get isMuted => _isMuted;
  bool get isListenOnly => _listenOnly;

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

  /// Initializes the Agora engine, joins the channel, and writes the current
  /// user to the voice_members subcollection. If the device has no mic or the
  /// permission is denied, falls back silently to listen-only mode (the user
  /// still hears others and is shown as muted to everyone).
  Future<void> join({
    required String serverId,
    required String channelId,
    required String uid,
    required String displayName,
    String? photoURL,
    void Function(int agoraUid)? onRemoteJoined,
    void Function(int agoraUid)? onRemoteLeft,
    void Function(String message)? onError,
    void Function(ConnectionStateType state)? onConnectionState,
  }) async {
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

    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(const RtcEngineContext(appId: AgoraConfig.appId));
    await engine
        .setChannelProfile(ChannelProfileType.channelProfileCommunication);

    // enableAudio() turns on BOTH mic capture and remote-audio playback. If it
    // throws (no mic / mic blocked), retry with local-audio disabled so that
    // playback still works — that lets the user listen even without a mic.
    try {
      await engine.enableAudio();
    } catch (_) {
      _listenOnly = true;
      try {
        await engine.enableLocalAudio(false);
        await engine.enableAudio();
      } catch (_) {
        // Last-ditch — keep going so we at least join the channel.
      }
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

    // Periodic volume reports power the "who is speaking" ring.
    try {
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: false,
      );
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
        // Audio-device errors are already handled by listen-only fallback —
        // surfacing them as a red banner would be noise.
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
        onConnectionState?.call(state);
      },
      onAudioVolumeIndication: (conn, speakers, speakerNumber, totalVolume) {
        const threshold = 25; // 0-255; below this is ambient noise
        final next = <int>{};
        for (final s in speakers) {
          final v = s.volume ?? 0;
          if (v < threshold) continue;
          final aUid = (s.uid == null || s.uid == 0)
              ? _localAgoraUid
              : s.uid;
          if (aUid != null) next.add(aUid);
        }
        final cur = speakingAgoraUids.value;
        if (next.length != cur.length || !next.containsAll(cur)) {
          speakingAgoraUids.value = next;
        }
      },
    ));

    await engine.joinChannel(
      token: '',
      channelId: AgoraConfig.channelName(serverId, channelId),
      uid: _localAgoraUid!,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: !_listenOnly,
        autoSubscribeAudio: true,
      ),
    );

    await _voiceMembers(serverId, channelId).doc(uid).set({
      'displayName': displayName,
      'photoURL': photoURL,
      'isMuted': _listenOnly,
      'isListenOnly': _listenOnly,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
    if (_listenOnly) return;
    _isMuted = !_isMuted;
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
