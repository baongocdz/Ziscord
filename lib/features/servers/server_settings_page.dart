import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/constants/app_colors.dart';
import '../../data/models/server.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/server_service.dart';

class ServerSettingsPage extends StatelessWidget {
  final Server server;

  const ServerSettingsPage({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    final service = ServerService();
    return StreamBuilder<Server?>(
      stream: service.streamServer(server.id),
      initialData: server,
      builder: (context, snap) {
        final live = snap.data;
        if (live == null) {
          // Server bị xóa
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
          return const SizedBox.shrink();
        }
        return _SettingsContent(server: live, service: service);
      },
    );
  }
}

class _SettingsContent extends StatefulWidget {
  final Server server;
  final ServerService service;

  const _SettingsContent({required this.server, required this.service});

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  final _nicknameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _nicknameLoaded = false;
  bool _isAdmin = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.server.name;
    _loadInitial();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final uid = AuthService().currentUser!.uid;
    final nickname =
        await widget.service.getServerNickname(widget.server.id, uid);
    if (!mounted) return;
    setState(() {
      _nicknameCtrl.text = nickname ?? '';
      _isAdmin = widget.server.ownerId == uid;
      _nicknameLoaded = true;
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.accent,
    ));
  }

  Future<void> _runWithBusy(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      _toast('Lỗi: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNickname() async {
    await _runWithBusy(() async {
      await widget.service
          .setServerNickname(widget.server.id, _nicknameCtrl.text);
      _toast('Đã lưu nickname server');
    });
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Tên server không được trống', error: true);
      return;
    }
    if (name == widget.server.name) return;
    await _runWithBusy(() async {
      await widget.service.renameServer(widget.server.id, name);
      _toast('Đã đổi tên server');
    });
  }

  Future<void> _changeIcon() async {
    await _runWithBusy(() async {
      final (url, error) = await CloudinaryService().pickAndUpload();
      if (error != null) {
        _toast('Lỗi upload: $error', error: true);
        return;
      }
      if (url == null) return;
      await widget.service.setServerIcon(widget.server.id, url);
      _toast('Đã đổi icon server');
    });
  }

  Future<void> _removeIcon() async {
    await _runWithBusy(() async {
      await widget.service.setServerIcon(widget.server.id, null);
      _toast('Đã xóa icon');
    });
  }

  Future<void> _togglePublic(bool value) async {
    await _runWithBusy(() async {
      await widget.service.setServerPublic(widget.server.id, value);
      _toast(value ? 'Server đã chuyển sang công khai' : 'Server đã thành riêng tư');
    });
  }

  Future<void> _regenerateCode() async {
    final ok = await _confirm(
      title: 'Tạo mã mời mới?',
      message: 'Mã mời hiện tại sẽ không còn dùng được nữa.',
      confirmLabel: 'Tạo mới',
    );
    if (!ok) return;
    await _runWithBusy(() async {
      await widget.service.regenerateInviteCode(widget.server.id);
      _toast('Đã tạo mã mời mới');
    });
  }

  Future<void> _leaveServer() async {
    final ok = await _confirm(
      title: 'Rời server?',
      message: 'Bạn sẽ không còn thấy server này nữa.',
      confirmLabel: 'Rời',
      danger: true,
    );
    if (!ok) return;
    await widget.service.leaveServer(widget.server.id);
    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  Future<void> _deleteServer() async {
    final ok = await _confirm(
      title: 'Xóa server?',
      message:
          'Hành động này không thể hoàn tác. Tất cả thành viên sẽ bị xóa khỏi server.',
      confirmLabel: 'Xóa server',
      danger: true,
    );
    if (!ok) return;
    await widget.service.deleteServer(widget.server.id);
    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.channelSidebar,
        title:
            Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AppColors.danger : AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_nicknameLoaded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(widget.server.name)),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.server.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isAdmin) ...[
                _buildIconSection(),
                const SizedBox(height: 24),
                _buildNameSection(),
                const SizedBox(height: 24),
                _buildVisibilitySection(),
                const SizedBox(height: 24),
              ],
              _buildInviteSection(),
              const SizedBox(height: 24),
              _buildNicknameSection(),
              const SizedBox(height: 24),
              _buildDangerZone(),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
            ),
        ],
      ),
    );
  }

  // ─── Sections ──────────────────────────────────────────────────────────────

  Widget _buildIconSection() {
    return _Section(
      title: 'ICON SERVER',
      child: Row(
        children: [
          _IconPreview(server: widget.server),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Tải lên ảnh mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _changeIcon,
                ),
                if (widget.server.iconUrl != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _removeIcon,
                    child: const Text('Xóa icon',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return _Section(
      title: 'TÊN SERVER',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Tên server'),
            maxLength: 50,
            buildCounter: (_, {required currentLength,
                    required isFocused,
                    required maxLength}) =>
                null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _busy || _nameCtrl.text.trim() == widget.server.name
                  ? null
                  : _saveName,
              child: const Text('Lưu tên'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySection() {
    return _Section(
      title: 'HIỂN THỊ SERVER',
      description: widget.server.isPublic
          ? 'Mọi người có thể tìm thấy server này.'
          : 'Server chỉ vào được qua mã mời.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.channelSidebar,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.accent,
          title: const Text('Server công khai',
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: const Text('Hiện trong tab Khám phá',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          value: widget.server.isPublic,
          onChanged: _busy ? null : _togglePublic,
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    return _Section(
      title: 'MÃ MỜI SERVER',
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.channelSidebar,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.server.inviteCode,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.server.inviteCode));
                    _toast('Đã copy mã mời');
                  },
                  tooltip: 'Copy mã mời',
                ),
              ],
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.refresh,
                    color: AppColors.textMuted, size: 16),
                label: const Text('Tạo mã mới',
                    style: TextStyle(color: AppColors.textMuted)),
                onPressed: _busy ? null : _regenerateCode,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNicknameSection() {
    return _Section(
      title: 'NICKNAME CỦA TÔI TRONG SERVER NÀY',
      description:
          'Đặt tên hiển thị riêng cho server này. Để trống để dùng tên mặc định.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nicknameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Nickname trong ${widget.server.name}',
            ),
            maxLength: 32,
            buildCounter: (_, {required currentLength,
                    required isFocused,
                    required maxLength}) =>
                null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _busy ? null : _saveNickname,
              child: const Text('Lưu nickname'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return _Section(
      title: 'NGUY HIỂM',
      child: Column(
        children: [
          if (!_isAdmin)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text('Rời server',
                    style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: _busy ? null : _leaveServer,
              ),
            ),
          if (_isAdmin)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Xóa server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy ? null : _deleteServer,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

class _IconPreview extends StatelessWidget {
  final Server server;
  const _IconPreview({required this.server});

  @override
  Widget build(BuildContext context) {
    if (server.iconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(server.iconUrl!,
            width: 64, height: 64, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        server.name.isNotEmpty ? server.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 26),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const _Section({
    required this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
