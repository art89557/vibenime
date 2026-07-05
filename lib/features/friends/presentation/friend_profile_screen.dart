import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../profile/data/avatar_borders.dart';
import '../data/friends_repository.dart';
import 'friends_providers.dart';

/// View read-only profile user lain.
///
/// Action: Send Message · Remove Friend · Block.
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(userProfileProvider(userId));
    final state = ref.watch(friendshipStateProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsProfile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: asyncProfile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(userProfileProvider(userId)),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(context.l10n.errorNotFound));
          }
          final border = AvatarBorderStyle.fromCode(profile.avatarBorder);

          return ListView(
            children: [
              // Banner
              AspectRatio(
                aspectRatio: 3 / 1,
                child: profile.bannerUrl == null || profile.bannerUrl!.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.3),
                              AppColors.secondary.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: profile.bannerUrl!,
                        fit: BoxFit.cover,
                      ),
              ),

              // Avatar with border overlap
              Transform.translate(
                offset: const Offset(0, -50),
                child: Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration:
                        border.sweepDecoration ??
                        BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              border.border ??
                              Border.all(
                                color: AppColors.surface(context),
                                width: 4,
                              ),
                        ),
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      backgroundColor: AppColors.surfaceElevated(context),
                      backgroundImage: (profile.avatarUrl?.isNotEmpty ?? false)
                          ? CachedNetworkImageProvider(profile.avatarUrl!)
                          : null,
                      child: (profile.avatarUrl?.isEmpty ?? true)
                          ? const Icon(Icons.person_outline_rounded, size: 48)
                          : null,
                    ),
                  ),
                ),
              ),

              // Username + Bio
              Transform.translate(
                offset: const Offset(0, -40),
                child: Column(
                  children: [
                    Text(
                      '@${profile.username}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          profile.bio!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: AppColors.textMuted(context),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ActionsRow(state: state, userId: userId),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.state, required this.userId});

  final FriendshipState state;
  final String userId;

  Future<void> _send(BuildContext ctx, WidgetRef ref) async {
    Haptic.medium();
    try {
      await ref.read(friendsRepositoryProvider).sendRequest(userId);
      if (ctx.mounted) AppSnackbar.success(ctx, 'Request terkirim');
    } catch (e) {
      if (ctx.mounted) AppSnackbar.error(ctx, 'Gagal: $e');
    }
  }

  Future<void> _remove(BuildContext ctx, WidgetRef ref) async {
    Haptic.heavy();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(dctx.l10n.friendRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(dctx.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(dctx.l10n.friendsRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(friendsRepositoryProvider).removeFriend(userId);
    if (ctx.mounted) AppSnackbar.success(ctx, 'Pertemanan dihapus');
  }

  Future<void> _block(BuildContext ctx, WidgetRef ref) async {
    Haptic.heavy();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(dctx.l10n.friendBlockConfirm),
        content: Text(dctx.l10n.friendBlockConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(dctx.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(dctx.l10n.friendsBlock),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(friendsRepositoryProvider).blockUser(userId);
    if (ctx.mounted) AppSnackbar.success(ctx, 'User di-block');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state == FriendshipState.blocked) {
      return OutlinedButton.icon(
        onPressed: () async {
          await ref.read(friendsRepositoryProvider).unblockUser(userId);
          if (context.mounted) AppSnackbar.success(context, 'Unblocked');
        },
        icon: const Icon(Icons.lock_open_rounded),
        label: Text(context.l10n.friendUnblock),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    if (state == FriendshipState.accepted) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.dmChatPath(userId)),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(context.l10n.friendSendMessage),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _remove(context, ref),
                  child: Text(context.l10n.friendsRemove),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _block(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: Text(context.l10n.friendsBlock),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (state == FriendshipState.pendingOutgoing) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_empty_rounded),
        label: Text(context.l10n.friendPending),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    if (state == FriendshipState.pendingIncoming) {
      return FilledButton.icon(
        onPressed: () async {
          final all = ref.read(myFriendshipsProvider).valueOrNull ?? const [];
          final f = all.firstWhere(
            (x) => x.requesterId == userId,
            orElse: () => throw 'Not found',
          );
          await ref.read(friendsRepositoryProvider).acceptRequest(f.id);
          if (context.mounted) {
            AppSnackbar.success(context, 'Diterima');
          }
        },
        icon: const Icon(Icons.check_rounded),
        label: Text(context.l10n.friendsAccept),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    // none → can send
    return FilledButton.icon(
      onPressed: () => _send(context, ref),
      icon: const Icon(Icons.person_add_rounded),
      label: Text(context.l10n.friendsAdd),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}
