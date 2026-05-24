import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/server.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/server_service.dart';

class BrowseServersPage extends StatefulWidget {
  const BrowseServersPage({super.key});

  @override
  State<BrowseServersPage> createState() => _BrowseServersPageState();
}

class _BrowseServersPageState extends State<BrowseServersPage> {
  final _service = ServerService();
  final _searchCtrl = TextEditingController();

  List<Server> _allPublic = [];
  Set<String> _joinedIds = {};
  Set<String> _pendingIds = {};
  bool _loading = true;
  String? _error;
  String _query = '';
  final Set<String> _joining = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = AuthService().currentUser!.uid;
      final public = await _service.searchPublicServers('');
      final joined = await _service.streamUserServers(uid).first;
      final pending = <String>{};
      for (final s in public) {
        final hasPending =
            await _service.streamHasPendingRequest(s.id, uid).first;
        if (hasPending) pending.add(s.id);
      }
      if (!mounted) return;
      setState(() {
        _allPublic = public;
        _joinedIds = joined.map((s) => s.id).toSet();
        _pendingIds = pending;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Server> get _filtered {
    if (_query.isEmpty) return _allPublic;
    final q = _query.toLowerCase();
    return _allPublic.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _join(Server server) async {
    setState(() => _joining.add(server.id));
    final result = await _service.joinServerById(server.id);
    if (!mounted) return;
    setState(() {
      _joining.remove(server.id);
      if (result.outcome == JoinOutcome.joined) {
        _joinedIds.add(server.id);
      } else if (result.outcome == JoinOutcome.pending) {
        _pendingIds.add(server.id);
      }
    });
    final ok = result.outcome == JoinOutcome.joined ||
        result.outcome == JoinOutcome.pending;
    final msg = result.message ??
        (result.outcome == JoinOutcome.joined
            ? 'Đã tham gia ${server.name}!'
            : 'Có lỗi xảy ra');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.accent : AppColors.danger,
    ));
  }

  Future<void> _cancelRequest(Server server) async {
    await _service.cancelMyJoinRequest(server.id);
    if (!mounted) return;
    setState(() => _pendingIds.remove(server.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã huỷ yêu cầu'),
      backgroundColor: AppColors.accent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.channelSidebar,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Khám phá Server',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Divider(color: AppColors.divider, height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.channelSidebar,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm server...',
          prefixIcon:
              Icon(Icons.search, color: AppColors.textMuted, size: 18),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close,
                      color: AppColors.textMuted, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Text('Không tải được danh sách server',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white),
                onPressed: _load,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final servers = _filtered;

    if (servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 8),
            Text(
              _query.isEmpty
                  ? 'Chưa có server công khai nào'
                  : 'Không tìm thấy server nào',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.channelSidebar,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: servers.length,
        separatorBuilder: (_, _) =>
            Divider(color: AppColors.divider, height: 1, indent: 72),
        itemBuilder: (context, i) => _ServerTile(
          server: servers[i],
          isJoined: _joinedIds.contains(servers[i].id),
          isPending: _pendingIds.contains(servers[i].id),
          isJoining: _joining.contains(servers[i].id),
          onJoin: () => _join(servers[i]),
          onCancelRequest: () => _cancelRequest(servers[i]),
        ),
      ),
    );
  }
}

// ─── Server Tile ──────────────────────────────────────────────────────────────

class _ServerTile extends StatelessWidget {
  final Server server;
  final bool isJoined;
  final bool isPending;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onCancelRequest;

  const _ServerTile({
    required this.server,
    required this.isJoined,
    required this.isPending,
    required this.isJoining,
    required this.onJoin,
    required this.onCancelRequest,
  });

  Widget _buildTrailing() {
    if (isJoined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('Đã tham gia',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
    }
    if (isJoining) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            color: AppColors.accent, strokeWidth: 2),
      );
    }
    if (isPending) {
      return OutlinedButton(
        onPressed: onCancelRequest,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          side: BorderSide(color: AppColors.divider),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: const Text('Chờ duyệt'),
      );
    }
    return ElevatedButton(
      onPressed: onJoin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
        textStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(server.requiresApproval ? 'Yêu cầu tham gia' : 'Tham gia'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _ServerIcon(server: server),
      title: Text(
        server.name,
        style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        server.isPublic ? 'Server công khai' : 'Server riêng tư',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: _buildTrailing(),
    );
  }
}

class _ServerIcon extends StatelessWidget {
  final Server server;
  const _ServerIcon({required this.server});

  @override
  Widget build(BuildContext context) {
    if (server.iconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(server.iconUrl!,
            width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        server.name.isNotEmpty ? server.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20),
      ),
    );
  }
}
