import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/join_request.dart';
import '../models/library_comment.dart';
import '../models/library_post.dart';
import '../models/server.dart';
import '../models/server_channel.dart';
import '../models/server_member.dart';
import '../models/server_message.dart';
import 'mention_service.dart';

/// Result of attempting to join a server.
enum JoinOutcome { joined, pending, alreadyMember, alreadyPending, notFound, error }

class JoinResult {
  final JoinOutcome outcome;
  final String? message;
  const JoinResult(this.outcome, [this.message]);
}

class ServerService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _mentionService = MentionService();

  // ─── Refs ────────────────────────────────────────────────────────────────────

  CollectionReference get _servers => _db.collection('servers');

  CollectionReference _members(String sid) =>
      _servers.doc(sid).collection('members');

  CollectionReference _channels(String sid) =>
      _servers.doc(sid).collection('channels');

  CollectionReference _messages(String sid, String cid) =>
      _channels(sid).doc(cid).collection('messages');

  CollectionReference _userServers(String uid) =>
      _db.collection('user_servers').doc(uid).collection('joined');

  CollectionReference _joinRequests(String sid) =>
      _servers.doc(sid).collection('join_requests');

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String get _currentUid => _auth.currentUser!.uid;

  // ─── Server CRUD ──────────────────────────────────────────────────────────────

  Future<Server> createServer({
    required String name,
    required bool isPublic,
  }) async {
    final uid = _currentUid;
    final inviteCode = _generateInviteCode();
    final now = Timestamp.now();
    final ref = _servers.doc();

    final server = Server(
      id: ref.id,
      name: name,
      ownerId: uid,
      isPublic: isPublic,
      requiresApproval: false,
      inviteCode: inviteCode,
      createdAt: now.toDate(),
    );

    final batch = _db.batch();
    batch.set(ref, server.toMap());
    batch.set(_members(ref.id).doc(uid), {
      'role': 'admin',
      'serverNickname': null,
      'joinedAt': now,
    });
    batch.set(_userServers(uid).doc(ref.id), {
      'serverName': name,
      'joinedAt': now,
      'role': 'admin',
    });
    await batch.commit();

    // Default channel
    await createChannel(
      serverId: ref.id,
      name: 'general',
      type: 'text',
      subtype: 'chat',
    );

    return server;
  }

  Stream<List<Server>> streamUserServers(String userId) {
    return _userServers(userId).snapshots().asyncMap((snap) async {
      final result = <Server>[];
      for (final doc in snap.docs) {
        final serverDoc = await _servers.doc(doc.id).get();
        if (serverDoc.exists) {
          result.add(Server.fromMap(
              serverDoc.data() as Map<String, dynamic>, serverDoc.id));
        }
      }
      return result;
    });
  }

  Future<Server?> getServer(String serverId) async {
    final doc = await _servers.doc(serverId).get();
    if (!doc.exists) return null;
    return Server.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<Server?> streamServer(String serverId) {
    return _servers.doc(serverId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Server.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Future<void> renameServer(String serverId, String newName) async {
    await _servers.doc(serverId).update({'name': newName});
  }

  Future<void> setServerIcon(String serverId, String? iconUrl) async {
    await _servers.doc(serverId).update({'iconUrl': iconUrl});
  }

  Future<void> setServerPublic(String serverId, bool isPublic) async {
    await _servers.doc(serverId).update({'isPublic': isPublic});
  }

  Future<void> setRequiresApproval(String serverId, bool value) async {
    await _servers.doc(serverId).update({'requiresApproval': value});
  }

  Future<String> regenerateInviteCode(String serverId) async {
    final code = _generateInviteCode();
    await _servers.doc(serverId).update({'inviteCode': code});
    return code;
  }

  Future<void> leaveServer(String serverId) async {
    final uid = _currentUid;
    final batch = _db.batch();
    batch.delete(_members(serverId).doc(uid));
    batch.delete(_userServers(uid).doc(serverId));
    await batch.commit();
  }

  Future<void> deleteServer(String serverId) async {
    // Xóa members + user_servers references + server doc.
    // Channels và messages để Firestore tự dọn theo TTL hoặc bỏ qua (orphan).
    final membersSnap = await _members(serverId).get();
    final batch = _db.batch();
    for (final m in membersSnap.docs) {
      batch.delete(m.reference);
      batch.delete(_userServers(m.id).doc(serverId));
    }
    batch.delete(_servers.doc(serverId));
    await batch.commit();
  }

  // ─── Public Server Browse ─────────────────────────────────────────────────────

  Future<List<Server>> searchPublicServers(String query) async {
    final snap = await _servers.where('isPublic', isEqualTo: true).get();
    final servers = snap.docs
        .map((d) => Server.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
    if (query.isEmpty) return servers;
    final q = query.toLowerCase();
    return servers.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Future<JoinResult> joinServerById(String serverId) async {
    final uid = _currentUid;
    final serverDoc = await _servers.doc(serverId).get();
    if (!serverDoc.exists) {
      return const JoinResult(JoinOutcome.notFound, 'Server không tồn tại');
    }
    return _enterServer(serverDoc, uid);
  }

  // ─── Join ─────────────────────────────────────────────────────────────────────

  Future<JoinResult> joinServerByCode(String code) async {
    final uid = _currentUid;
    final snap = await _servers
        .where('inviteCode', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return const JoinResult(JoinOutcome.notFound, 'Mã mời không tồn tại');
    }
    return _enterServer(snap.docs.first, uid);
  }

  /// Shared join logic — routes to instant join or pending request based on
  /// the server's `requiresApproval` flag.
  Future<JoinResult> _enterServer(
      DocumentSnapshot serverDoc, String uid) async {
    final serverId = serverDoc.id;
    final data = serverDoc.data() as Map<String, dynamic>;
    final requiresApproval = data['requiresApproval'] == true;
    final serverName = data['name'] as String? ?? '';

    final existing = await _members(serverId).doc(uid).get();
    if (existing.exists) {
      return const JoinResult(
          JoinOutcome.alreadyMember, 'Bạn đã tham gia server này rồi');
    }

    if (requiresApproval) {
      final pending = await _joinRequests(serverId).doc(uid).get();
      if (pending.exists) {
        return const JoinResult(
            JoinOutcome.alreadyPending, 'Bạn đã gửi yêu cầu, đang chờ duyệt');
      }
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      await _joinRequests(serverId).doc(uid).set({
        'displayName': userData['displayName'] ?? uid,
        'photoURL': userData['photoURL'],
        'requestedAt': FieldValue.serverTimestamp(),
      });
      return const JoinResult(
          JoinOutcome.pending, 'Đã gửi yêu cầu tham gia, chờ admin duyệt');
    }

    final now = Timestamp.now();
    final batch = _db.batch();
    batch.set(_members(serverId).doc(uid), {
      'role': 'member',
      'serverNickname': null,
      'joinedAt': now,
    });
    batch.set(_userServers(uid).doc(serverId), {
      'serverName': serverName,
      'joinedAt': now,
      'role': 'member',
    });
    await batch.commit();
    return const JoinResult(JoinOutcome.joined);
  }

  // ─── Join Requests (admin) ────────────────────────────────────────────────────

  Stream<List<JoinRequest>> streamJoinRequests(String serverId) {
    return _joinRequests(serverId)
        .orderBy('requestedAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                JoinRequest.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<int> streamJoinRequestCount(String serverId) {
    return _joinRequests(serverId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<bool> streamHasPendingRequest(String serverId, String uid) {
    return _joinRequests(serverId).doc(uid).snapshots().map((d) => d.exists);
  }

  Future<void> approveJoinRequest(String serverId, String uid) async {
    final serverDoc = await _servers.doc(serverId).get();
    if (!serverDoc.exists) return;
    final serverName =
        (serverDoc.data() as Map<String, dynamic>)['name'] as String? ?? '';
    final now = Timestamp.now();
    final batch = _db.batch();
    batch.set(_members(serverId).doc(uid), {
      'role': 'member',
      'serverNickname': null,
      'joinedAt': now,
    });
    batch.set(_userServers(uid).doc(serverId), {
      'serverName': serverName,
      'joinedAt': now,
      'role': 'member',
    });
    batch.delete(_joinRequests(serverId).doc(uid));
    await batch.commit();
  }

  Future<void> rejectJoinRequest(String serverId, String uid) async {
    await _joinRequests(serverId).doc(uid).delete();
  }

  Future<void> cancelMyJoinRequest(String serverId) async {
    await _joinRequests(serverId).doc(_currentUid).delete();
  }

  // ─── Channels ─────────────────────────────────────────────────────────────────

  Future<void> createChannel({
    required String serverId,
    required String name,
    String type = 'text',
    String subtype = 'chat',
    int? position,
  }) async {
    await _channels(serverId).add({
      'name': name,
      'type': type,
      'subtype': subtype,
      'position': position ?? DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reorderChannels(
      String serverId, List<String> orderedIds) async {
    final batch = _db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(_channels(serverId).doc(orderedIds[i]), {'position': i});
    }
    await batch.commit();
  }

  Future<void> deleteChannel(String serverId, String channelId) async {
    await _channels(serverId).doc(channelId).delete();
  }

  Future<void> renameChannel(
      String serverId, String channelId, String newName) async {
    await _channels(serverId).doc(channelId).update({'name': newName});
  }

  Future<ServerChannel?> getChannel(String serverId, String channelId) async {
    final doc = await _channels(serverId).doc(channelId).get();
    if (!doc.exists) return null;
    return ServerChannel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<List<ServerChannel>> streamChannels(String serverId) {
    return _channels(serverId)
        .orderBy('position')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ServerChannel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ─── Messages ─────────────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String serverId,
    required String channelId,
    required String text,
    String? imageUrl,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
    List<String> mentions = const [],
  }) async {
    final uid = _currentUid;
    final senderName = await _resolveSenderName(serverId, uid);

    final msg = <String, dynamic>{
      'senderId': uid,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (imageUrl != null) msg['imageUrl'] = imageUrl;
    if (replyToId != null) {
      msg['replyToId'] = replyToId;
      msg['replyToSenderName'] = replyToSenderName;
      msg['replyToText'] = replyToText;
    }
    if (mentions.isNotEmpty) msg['mentions'] = mentions;
    final msgRef = await _messages(serverId, channelId).add(msg);

    if (mentions.isNotEmpty) {
      final serverDoc = await _servers.doc(serverId).get();
      final channelDoc = await _channels(serverId).doc(channelId).get();
      final serverName =
          (serverDoc.data() as Map<String, dynamic>?)?['name'] as String? ?? '';
      final channelName =
          (channelDoc.data() as Map<String, dynamic>?)?['name'] as String? ?? '';
      await _mentionService.recordChannelMentions(
        mentionedUids: mentions,
        senderId: uid,
        senderName: senderName,
        messageId: msgRef.id,
        messageText: text,
        serverId: serverId,
        channelId: channelId,
        serverName: serverName,
        channelName: channelName,
      );
    }
  }

  Future<void> editMessage({
    required String serverId,
    required String channelId,
    required String messageId,
    required String newText,
  }) async {
    await _messages(serverId, channelId).doc(messageId).update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> deleteMessage({
    required String serverId,
    required String channelId,
    required String messageId,
  }) async {
    await _messages(serverId, channelId).doc(messageId).delete();
  }

  Future<void> toggleReaction({
    required String serverId,
    required String channelId,
    required String messageId,
    required String emoji,
    required String uid,
    required bool hasReacted,
  }) async {
    final ref = _messages(serverId, channelId).doc(messageId);
    if (hasReacted) {
      await ref.update({'reactions.$emoji': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'reactions.$emoji': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> pinMessage({
    required String serverId,
    required String channelId,
    required String messageId,
    required bool pin,
  }) async {
    await _messages(serverId, channelId)
        .doc(messageId)
        .update({'isPinned': pin});
  }

  Stream<List<ServerMessage>> streamPinnedMessages(
      String serverId, String channelId) {
    return _messages(serverId, channelId)
        .where('isPinned', isEqualTo: true)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ServerMessage.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<ServerMessage>> streamMessages(
      String serverId, String channelId) {
    return _messages(serverId, channelId)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ServerMessage.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ─── Server Nickname ──────────────────────────────────────────────────────────

  Future<void> setServerNickname(String serverId, String nickname) async {
    final uid = _currentUid;
    await _members(serverId).doc(uid).update({
      'serverNickname': nickname.trim().isEmpty ? null : nickname.trim(),
    });
  }

  Future<String?> getServerNickname(String serverId, String userId) async {
    final doc = await _members(serverId).doc(userId).get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>)['serverNickname'] as String?;
  }

  Stream<ServerMember?> streamMember(String serverId, String userId) {
    return _members(serverId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ServerMember.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  // ─── Library (Forum) ──────────────────────────────────────────────────────────

  CollectionReference _posts(String sid, String cid) =>
      _channels(sid).doc(cid).collection('posts');

  CollectionReference _comments(String sid, String cid, String pid) =>
      _posts(sid, cid).doc(pid).collection('comments');

  Future<void> createPost({
    required String serverId,
    required String channelId,
    required String title,
    required String content,
  }) async {
    final uid = _currentUid;
    final authorName = await _resolveSenderName(serverId, uid);
    await _posts(serverId, channelId).add({
      'authorId': uid,
      'authorName': authorName,
      'title': title,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'commentCount': 0,
    });
  }

  Future<void> updatePost({
    required String serverId,
    required String channelId,
    required String postId,
    required String title,
    required String content,
  }) async {
    await _posts(serverId, channelId).doc(postId).update({
      'title': title,
      'content': content,
    });
  }

  Stream<List<LibraryPost>> streamPosts(String serverId, String channelId) {
    return _posts(serverId, channelId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                LibraryPost.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addComment({
    required String serverId,
    required String channelId,
    required String postId,
    required String text,
  }) async {
    final uid = _currentUid;
    final authorName = await _resolveSenderName(serverId, uid);
    final batch = _db.batch();
    final commentRef = _comments(serverId, channelId, postId).doc();
    batch.set(commentRef, {
      'authorId': uid,
      'authorName': authorName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(_posts(serverId, channelId).doc(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Stream<List<LibraryComment>> streamComments(
      String serverId, String channelId, String postId) {
    return _comments(serverId, channelId, postId)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LibraryComment.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ─── Members ──────────────────────────────────────────────────────────────────

  Stream<List<ServerMemberInfo>> streamMembersWithNames(String serverId) {
    return _members(serverId).snapshots().asyncMap((snap) async {
      final result = <ServerMemberInfo>[];
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userDoc = await _db.collection('users').doc(doc.id).get();
        String displayName = doc.id;
        String nickname = '';
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          displayName = userData['displayName'] ?? doc.id;
          nickname = userData['nickname'] ?? '';
        }
        result.add(ServerMemberInfo(
          uid: doc.id,
          displayName: displayName,
          nickname: nickname,
          role: data['role'] ?? 'member',
          serverNickname: data['serverNickname'] as String?,
          canCreateChannel: data['canCreateChannel'] ?? false,
        ));
      }
      result.sort((a, b) {
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return a.effectiveName.compareTo(b.effectiveName);
      });
      return result;
    });
  }

  Future<void> setMemberCanCreateChannel(
      String serverId, String userId, bool value) async {
    await _members(serverId).doc(userId).update({'canCreateChannel': value});
  }

  Future<void> kickMember(String serverId, String userId) async {
    final batch = _db.batch();
    batch.delete(_members(serverId).doc(userId));
    batch.delete(_userServers(userId).doc(serverId));
    await batch.commit();
  }

  // ─── Private ──────────────────────────────────────────────────────────────────

  Future<String> _resolveSenderName(String serverId, String uid) async {
    final memberDoc = await _members(serverId).doc(uid).get();
    if (memberDoc.exists) {
      final nickname = (memberDoc.data()
          as Map<String, dynamic>)['serverNickname'] as String?;
      if (nickname != null && nickname.isNotEmpty) return nickname;
    }
    // Fallback to global displayName
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return (userDoc.data() as Map<String, dynamic>)['displayName'] ?? uid;
    }
    return uid;
  }
}
