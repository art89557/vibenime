import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../data/admin_repository.dart';

/// Admin Moderation — list pesan terbaru dengan action hapus.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMessages = ref.watch(adminRecentMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminMessageModeration),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminRecentMessagesProvider),
          ),
        ],
      ),
      body: asyncMessages.when(
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
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Text(
                context.l10n.adminNoMessages,
                style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
              ),
            );
          }
          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.borderColor(context)),
            itemBuilder: (_, i) => _MessageRow(message: messages[i]),
          );
        },
      ),
    );
  }
}

class _MessageRow extends ConsumerWidget {
  const _MessageRow({required this.message});

  final AdminMessage message;

  String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return '${diff.inDays}h ago';
    if (diff.inHours > 0) return '${diff.inHours}j ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

  Future<void> _delete(BuildContext ctx, WidgetRef ref) async {
    Haptic.heavy();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(ctx.l10n.adminDeleteMessageQ),
        content: Text(ctx.l10n.adminDeleteMessageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteMessage(message.id);
      ref.invalidate(adminRecentMessagesProvider);
      if (ctx.mounted) AppSnackbar.success(ctx, ctx.l10n.adminMessageDeleted);
    } catch (e) {
      if (ctx.mounted) {
        AppSnackbar.error(ctx, ctx.l10n.adminFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${message.senderUsername}',
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeLabel(message.createdAt),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.content,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _delete(context, ref),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            tooltip: context.l10n.commonDelete,
          ),
        ],
      ),
    );
  }
}
