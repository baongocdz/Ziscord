import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool _isMuted = false;
  final Set<int> _remoteAgoraUids = {};

  bool get isMuted => _isMuted;

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

  /// Asks for mic permission, initializes the Agora engine, joins the channel,
  /// and writes the current user to the voice_members subcollection.
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
    // On web, permission_handler is a no-op for microphone — Agora's
    // enableAudio() will trigger the browser's native getUserMedia() prompt
    // instead. Only native platforms need the explicit pre-flight check.
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Cần cấp quyền micro để vào kênh thoại');
      }
    }

    _currentServerId = serverId;
    _currentChannelId = channelId;
    _currentUid = uid;

    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(const RtcEngineContext(appId: AgoraConfig.appId));
    await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
    await engine.enableAudio();
    await engine.disableVideo();

    engine.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (conn, remoteUid, elapsed) {
        _remoteAgoraUids.add(remoteUid);
        onRemoteJoined?.call(remoteUid);
      },
      onUserOffline: (conn, remoteUid, reason) {
        _remoteAgoraUids.remove(remoteUid);
        onRemoteLeft?.call(remoteUid);
      },
      onError: (err, msg) {
        onError?.call('Agora ${err.name}: $msg');
      },
      onConnectionStateChanged: (conn, state, reason) {
        onConnectionState?.call(state);
      },
    ));

    // Use a deterministic numeric UID derived from the Firebase uid.
    final agoraUid = uid.hashCode & 0x7FFFFFFF;
    await engine.joinChannel(
      token: '',
      channelId: AgoraConfig.channelName(serverId, channelId),
      uid: agoraUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    await _voiceMembers(serverId, channelId).doc(uid).set({
      'displayName': displayName,
      'photoURL': photoURL,
      'isMuted': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
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
    _isMuted = false;
    _remoteAgoraUids.clear();

    if (sid != null && cid != null && uid != null) {
      await _voiceMembers(sid, cid).doc(uid).delete().catchError((_) {});
    }
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
    }
  }
}
