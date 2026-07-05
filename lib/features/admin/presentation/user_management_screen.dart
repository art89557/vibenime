import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../data/admin_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Admin User Management — list, search, ban, promote.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncUsers = ref.watch(adminUsersProvider(_query));
    final isSuperAdmin =
        ref.watch(appAuthControllerProvider).user?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                hintText: context.l10n.adminSearchUserHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (v) {
                setState(() => _query = v);
              },
            ),
          ),
          Expanded(
            child: asyncUsers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    context.l10n.adminError(e.toString()),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(color: AppColors.error),
                  ),
                ),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      context.l10n.adminNoUsers,
                      style: GoogleFonts.roboto(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) =>
                      _UserRow(user: users[i], isSuperAdmin: isSuperAdmin),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user, required this.isSuperAdmin});

  final AdminUser user;
  final bool isSuperAdmin;

  Future<void> _setRole(BuildContext ctx, WidgetRef ref, String role) async {
    Haptic.medium();
    try {
      await ref.read(adminRepositoryProvider).setRole(user.userId, role);
      ref.invalidate(adminUsersProvider);
      if (ctx.mounted) {
        AppSnackbar.success(ctx, ctx.l10n.adminRoleUpdated(role));
      }
    } catch (e) {
      if (ctx.mounted) {
        AppSnackbar.error(ctx, ctx.l10n.adminFailed(e.toString()));
      }
    }
  }

  Future<void> _ban(BuildContext ctx, WidgetRef ref) async {
    Haptic.heavy();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(ctx.l10n.adminBanQ(user.username)),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(labelText: ctx.l10n.adminReason),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .banUser(user.userId, reasonCtrl.text.trim());
      ref.invalidate(adminUsersProvider);
      if (ctx.mounted) AppSnackbar.success(ctx, ctx.l10n.adminUserBanned);
    } catch (e) {
      if (ctx.mounted) {
        AppSnackbar.error(ctx, ctx.l10n.adminFailed(e.toString()));
      }
    }
  }

  Future<void> _unban(BuildContext ctx, WidgetRef ref) async {
    Haptic.medium();
    try {
      await ref.read(adminRepositoryProvider).unbanUser(user.userId);
      ref.invalidate(adminUsersProvider);
      if (ctx.mounted) AppSnackbar.success(ctx, ctx.l10n.adminUserUnbanned);
    } catch (e) {
      if (ctx.mounted) {
        AppSnackbar.error(ctx, ctx.l10n.adminFailed(e.toString()));
      }
    }
  }

  void _showActions(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceElevated(ctx),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '@${user.username}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary(ctx),
                ),
              ),
            ),
            if (isSuperAdmin &&
                user.role != 'admin' &&
                user.role != 'super_admin')
              ListTile(
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.warning,
                ),
                title: Text(ctx.l10n.adminPromote),
                onTap: () {
                  Navigator.pop(sheet);
                  _setRole(ctx, ref, 'admin');
                },
              ),
            if (isSuperAdmin && user.role == 'admin')
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.warning,
                ),
                title: Text(ctx.l10n.adminDemote),
                onTap: () {
                  Navigator.pop(sheet);
                  _setRole(ctx, ref, 'user');
                },
              ),
            if (!user.isBanned)
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                ),
                title: Text(ctx.l10n.adminBanUser),
                onTap: () {
                  Navigator.pop(sheet);
                  _ban(ctx, ref);
                },
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.lock_open_rounded,
                  color: AppColors.success,
                ),
                title: Text(ctx.l10n.adminUnbanUser),
                onTap: () {
                  Navigator.pop(sheet);
                  _unban(ctx, ref);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin':
        return AppColors.warning;
      case 'admin':
        return AppColors.primary;
      default:
        return AppColors.textMuted(WidgetsBinding.instance.rootElement!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () => _showActions(context, ref),
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceElevated(context),
        backgroundImage: (user.avatarUrl?.isNotEmpty ?? false)
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        child: (user.avatarUrl?.isEmpty ?? true)
            ? const Icon(Icons.person_outline_rounded)
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              '@${user.username}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          if (user.role != 'user') ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor(user.role).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.tiny),
              ),
              child: Text(
                user.role,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _roleColor(user.role),
                ),
              ),
            ),
          ],
          if (user.isBanned) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.tiny),
              ),
              child: Text(
                'BANNED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.roboto(
          fontSize: 11,
          color: AppColors.textMuted(context),
        ),
      ),
      trailing: const Icon(Icons.more_vert_rounded),
    );
  }
}
