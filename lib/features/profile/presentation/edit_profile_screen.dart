import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../auth/data/app_auth_repository.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../data/avatar_borders.dart';
import '../data/avatar_storage_repository.dart';
import '../data/banner_storage_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Edit Profile lengkap — 9 section:
/// 1. Banner upload (1500×500)
/// 2. Avatar upload + Avatar border picker
/// 3. Username + Bio
/// 4. Email (editable dengan re-verify)
/// 5. Change password
/// 6. Privacy per-field (4 toggles)
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Controllers
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _avatarUrl;
  String? _bannerUrl;
  AvatarBorderStyle _border = AvatarBorderStyle.none;
  late PrivacyPrefs _privacy;

  Uint8List? _pickedAvatarBytes;
  Uint8List? _pickedBannerBytes;

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appAuthControllerProvider).user;
    _usernameCtrl.text = user?.username ?? '';
    _bioCtrl.text = user?.bio ?? '';
    _emailCtrl.text = user?.email ?? '';
    _avatarUrl = user?.avatarUrl;
    _bannerUrl = user?.bannerUrl;
    _border = AvatarBorderStyle.fromCode(user?.avatarBorder);
    _privacy = user?.privacy ?? const PrivacyPrefs();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _isUsernameValid {
    final u = _usernameCtrl.text.trim();
    return u.length >= 3 && u.length <= 20;
  }

  // ─── Avatar upload ──────────────────────────────────────────────────────

  Future<void> _pickAvatar(ImageSource source) async {
    final user = ref.read(appAuthControllerProvider).user;
    if (user == null) return;
    Haptic.medium();
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      setState(() => _pickedAvatarBytes = bytes);
      final repo = ref.read(avatarStorageRepositoryProvider);
      final ext = file.name.split('.').last.toLowerCase();
      final url = await repo.uploadAvatar(
        userId: user.id,
        bytes: bytes,
        extension: ext == 'png' ? 'png' : 'jpg',
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      AppSnackbar.success(context, 'Avatar ter-upload — tap Simpan');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Upload gagal: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ─── Banner upload ──────────────────────────────────────────────────────

  Future<void> _pickBanner() async {
    final user = ref.read(appAuthControllerProvider).user;
    if (user == null) return;
    Haptic.medium();
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1500,
      maxHeight: 500,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isUploadingBanner = true);
    try {
      final bytes = await file.readAsBytes();
      setState(() => _pickedBannerBytes = bytes);
      final repo = ref.read(bannerStorageRepositoryProvider);
      final ext = file.name.split('.').last.toLowerCase();
      final url = await repo.uploadBanner(
        userId: user.id,
        bytes: bytes,
        extension: ext == 'png' ? 'png' : 'jpg',
      );
      if (!mounted) return;
      setState(() => _bannerUrl = url);
      AppSnackbar.success(context, 'Banner ter-upload — tap Simpan');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Upload gagal: $e');
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  // ─── Save all ───────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    if (!_isUsernameValid) return;
    Haptic.medium();
    setState(() => _isSaving = true);
    try {
      await ref
          .read(appAuthControllerProvider.notifier)
          .updateProfile(
            username: _usernameCtrl.text.trim(),
            avatarUrl: _avatarUrl,
            bannerUrl: _bannerUrl,
            bio: _bioCtrl.text.trim(),
            avatarBorder: _border.code,
            privacy: _privacy,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Profil tersimpan');
      NavHelper.safePop(context);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Save gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Email change ───────────────────────────────────────────────────────

  Future<void> _changeEmail() async {
    final newEmail = _emailCtrl.text.trim();
    final currentEmail = ref.read(appAuthControllerProvider).user?.email;
    if (newEmail == currentEmail) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(newEmail)) {
      AppSnackbar.error(context, 'Format email tidak valid');
      return;
    }
    Haptic.medium();
    try {
      await ref.read(appAuthControllerProvider.notifier).updateEmail(newEmail);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        'Cek inbox $newEmail untuk konfirmasi perubahan email',
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Gagal: $e');
    }
  }

  // ─── Password change ────────────────────────────────────────────────────

  Future<void> _openChangePasswordDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(context.l10n.editPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password lama'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password baru (min 6)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonUpdate),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (newCtrl.text.length < 6) {
      if (mounted) {
        AppSnackbar.error(context, 'Password baru minimal 6 karakter');
      }
      return;
    }
    try {
      await ref
          .read(appAuthControllerProvider.notifier)
          .updatePassword(
            currentPassword: oldCtrl.text,
            newPassword: newCtrl.text,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Password berhasil diubah');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Gagal: $e');
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileEdit),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || _isUploadingAvatar || _isUploadingBanner)
                ? null
                : _saveAll,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.actionSave),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Banner section
          _BannerEditor(
            bannerUrl: _bannerUrl,
            pickedBytes: _pickedBannerBytes,
            isUploading: _isUploadingBanner,
            onTap: _pickBanner,
          ),

          // Avatar section overlap banner
          Transform.translate(
            offset: const Offset(0, -40),
            child: _AvatarEditor(
              avatarUrl: _avatarUrl,
              pickedBytes: _pickedAvatarBytes,
              isUploading: _isUploadingAvatar,
              border: _border,
              onPickGallery: () => _pickAvatar(ImageSource.gallery),
              onPickCamera: () => _pickAvatar(ImageSource.camera),
            ),
          ),

          // Avatar border picker
          _SectionHeader(context.l10n.profileAvatarBorder),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: AvatarBorderStyle.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final style = AvatarBorderStyle.values[i];
                final isActive = style == _border;
                return GestureDetector(
                  onTap: () {
                    Haptic.selection();
                    setState(() => _border = style);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration:
                            style.sweepDecoration ??
                            BoxDecoration(
                              shape: BoxShape.circle,
                              border: style.border,
                            ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface(context),
                              border: isActive
                                  ? Border.all(
                                      color: AppColors.primaryAdaptive(context),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Icon(
                                isActive ? Icons.check : Icons.person,
                                size: 16,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.label,
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          color: isActive
                              ? AppColors.primaryAdaptive(context)
                              : AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Username + Bio
          _SectionHeader(context.l10n.profileUsername),
          _FieldPadding(
            child: TextField(
              controller: _usernameCtrl,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: 'min 3, max 20 karakter',
                counterText: '',
                suffixIcon: _usernameCtrl.text.isEmpty
                    ? null
                    : Icon(
                        _isUsernameValid
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: _isUsernameValid
                            ? AppColors.success
                            : AppColors.warning,
                        size: 18,
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          _SectionHeader(context.l10n.profileBio),
          _FieldPadding(
            child: TextField(
              controller: _bioCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Ceritakan tentang dirimu (200 karakter)',
              ),
            ),
          ),

          // Email
          _SectionHeader(context.l10n.profileEmail),
          _FieldPadding(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'kamu@email.com',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _changeEmail,
                  child: Text(context.l10n.commonChange),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Setelah ubah, cek inbox email baru untuk verify link.',
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: AppColors.textMuted(context),
              ),
            ),
          ),

          // Password
          _SectionHeader('Keamanan'),
          _FieldPadding(
            child: OutlinedButton.icon(
              onPressed: _openChangePasswordDialog,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(context.l10n.editPassword),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

          // Privacy
          _SectionHeader(context.l10n.profilePrivacy),
          _PrivacyToggleRow(
            title: 'Tampilkan statistik',
            subtitle: 'Stat counter (judul, ep, jam) di profile saya',
            value: _privacy.showStats,
            onChanged: (v) =>
                setState(() => _privacy = _privacy.copyWith(showStats: v)),
          ),
          _PrivacyToggleRow(
            title: 'Tampilkan aktivitas',
            subtitle: 'Aktivitas nonton saya muncul di feed teman',
            value: _privacy.showActivity,
            onChanged: (v) =>
                setState(() => _privacy = _privacy.copyWith(showActivity: v)),
          ),
          _PrivacyToggleRow(
            title: 'Tampilkan favorit',
            subtitle: 'Daftar favorit visible untuk teman',
            value: _privacy.showFavorites,
            onChanged: (v) =>
                setState(() => _privacy = _privacy.copyWith(showFavorites: v)),
          ),
          _PrivacyToggleRow(
            title: 'Terima permintaan teman',
            subtitle: 'User lain boleh kirim friend request',
            value: _privacy.allowFriendRequests,
            onChanged: (v) => setState(
              () => _privacy = _privacy.copyWith(allowFriendRequests: v),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textMuted(context),
        ),
      ),
    );
  }
}

class _FieldPadding extends StatelessWidget {
  const _FieldPadding({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
  }
}

class _BannerEditor extends StatelessWidget {
  const _BannerEditor({
    required this.bannerUrl,
    required this.pickedBytes,
    required this.isUploading,
    required this.onTap,
  });

  final String? bannerUrl;
  final Uint8List? pickedBytes;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: AspectRatio(
        aspectRatio: 3 / 1, // 1500×500 → 3:1
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pickedBytes != null)
              Image.memory(pickedBytes!, fit: BoxFit.cover)
            else if (bannerUrl != null && bannerUrl!.isNotEmpty)
              CachedNetworkImage(imageUrl: bannerUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.3),
                      AppColors.secondary.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            Container(color: Colors.black.withValues(alpha: 0.3)),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isUploading
                        ? Icons.cloud_upload_rounded
                        : Icons.photo_camera_outlined,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isUploading ? 'Mengupload...' : 'Tap untuk ubah banner',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (isUploading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.avatarUrl,
    required this.pickedBytes,
    required this.isUploading,
    required this.border,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final String? avatarUrl;
  final Uint8List? pickedBytes;
  final bool isUploading;
  final AvatarBorderStyle border;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  Future<void> _showSheet(BuildContext ctx) async {
    await showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceElevated(ctx),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onPickGallery();
              },
            ),
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onPickCamera();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarChild() {
      if (pickedBytes != null) {
        return Image.memory(pickedBytes!, fit: BoxFit.cover);
      }
      if (avatarUrl != null && avatarUrl!.isNotEmpty) {
        return CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover);
      }
      return Icon(
        Icons.person_outline_rounded,
        size: 48,
        color: AppColors.textMuted(context),
      );
    }

    final innerAvatar = Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated(context),
      ),
      child: ClipOval(child: avatarChild()),
    );

    // Apply border (single color or sweep gradient)
    final wrapped = border.sweepDecoration != null
        ? Container(
            width: 110,
            height: 110,
            decoration: border.sweepDecoration,
            padding: const EdgeInsets.all(4),
            child: ClipOval(child: innerAvatar),
          )
        : Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface(context),
              border: border.border,
            ),
            padding: const EdgeInsets.all(4),
            child: innerAvatar,
          );

    return Center(
      child: GestureDetector(
        onTap: isUploading ? null : () => _showSheet(context),
        child: Stack(
          children: [
            wrapped,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface(context),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ),
            if (isUploading)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: (v) {
            Haptic.selection();
            onChanged(v);
          },
          activeThumbColor: AppColors.primary,
          title: Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}
