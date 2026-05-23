import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/user_service.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _displayNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _userService = UserService();
  final _authService = AuthService();
  final _cloudinary = CloudinaryService();

  String? _avatarUrl;
  String? _bannerUrl;
  bool _isLoading = false;
  bool _isBannerUploading = false;
  bool _isUserLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    await _authService.loadCurrentUser();
    final user = _authService.currentUserData;
    if (!mounted) return;
    setState(() {
      _displayNameController.text = user?.displayName ?? '';
      _nicknameController.text = user?.nickname ?? '';
      _avatarUrl = user?.photoURL;
      _bannerUrl = user?.bannerURL;
      _isUserLoaded = true;
    });
  }

  Future<void> _pickAvatar() async {
    setState(() => _isLoading = true);
    try {
      final (url, error) = await _cloudinary.pickAndUpload();
      if (error != null) {
        _showSnack('Lỗi upload: $error', isError: true);
        return;
      }
      if (url == null) return; // user cancelled
      await _userService.updateAvatar(url);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _showSnack('Cập nhật avatar thành công');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBanner() async {
    setState(() => _isBannerUploading = true);
    try {
      final (url, error) = await _cloudinary.pickAndUpload();
      if (error != null) {
        _showSnack('Lỗi upload: $error', isError: true);
        return;
      }
      if (url == null) return;
      await _userService.updateBanner(url);
      if (!mounted) return;
      setState(() => _bannerUrl = url);
      _showSnack('Cập nhật ảnh nền thành công');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBannerUploading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      await _userService.updateProfile(
        displayName: _displayNameController.text.trim(),
        nickname: _nicknameController.text.trim(),
      );
      await _authService.loadCurrentUser();
      if (!mounted) return;
      _showSnack('Cập nhật thành công');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.accent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUserLoaded) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    final email = _authService.currentUser?.email ?? '';

    return Container(
      color: AppColors.channelSidebar,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            _BannerArea(
              bannerUrl: _bannerUrl,
              isLoading: _isBannerUploading,
              onTap: _isBannerUploading ? null : _pickBanner,
            ),

            // Avatar overlapping banner
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AvatarPicker(
                      avatarUrl: _avatarUrl,
                      displayName: _displayNameController.text,
                      isLoading: _isLoading,
                      onTap: _pickAvatar,
                    ),
                    const Spacer(),
                    _OutlineButton(
                      label: 'Đổi ảnh nền',
                      onTap: _isBannerUploading ? null : _pickBanner,
                    ),
                  ],
                ),
              ),
            ),

            // Name + email
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Transform.translate(
                offset: const Offset(0, -28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayNameController.text.isNotEmpty
                          ? _displayNameController.text
                          : 'Người dùng',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // Edit form
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THÔNG TIN CÁ NHÂN',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormRow(
                    label: 'TÊN HIỂN THỊ',
                    child: TextField(
                      controller: _displayNameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'Tên của bạn'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormRow(
                    label: 'NICKNAME',
                    child: TextField(
                      controller: _nicknameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'nickname123'),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      onPressed: _isLoading ? null : _updateProfile,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Lưu thay đổi',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _isLoading ? null : _logout,
                  child: const Text('Đăng xuất',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final bool isLoading;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.avatarUrl,
    required this.displayName,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.channelSidebar, width: 4),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.accent,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.selectedBg,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.channelSidebar, width: 2),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                          color: AppColors.textPrimary, strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt,
                      color: AppColors.textPrimary, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: disabled
                  ? AppColors.divider.withValues(alpha: 0.5)
                  : AppColors.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: disabled
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BannerArea extends StatelessWidget {
  final String? bannerUrl;
  final bool isLoading;
  final VoidCallback? onTap;

  const _BannerArea({
    required this.bannerUrl,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accent,
              image: bannerUrl != null && bannerUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(bannerUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
