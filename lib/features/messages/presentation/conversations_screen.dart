import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../core/utils/nav_helper.dart';
import '../../friends/presentation/friends_providers.dart';
import '../data/direct_message.dart';
import '../data/dm_repository.dart';
import '../../../core/theme/app_radius.dart';

/// List semua conversation aktif — partner + last message + unread badge.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConvos = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.messagesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New Chat',
            onPressed: () => context.push(AppRoutes.friendsList),
          ),
        ],
      ),
      body: asyncConvos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
        ),
        data: (convos) {
          if (convos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 56,
                      color: AppColors.textMuted(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.messagesEmpty,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tambah teman dulu, baru bisa chat',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.userSearch),
                      icon: const Icon(Icons.person_add_rounded),
                      label: Text(context.l10n.friendsSearch),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: convos.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.borderColor(context)),
            itemBuilder: (_, i) => _ConvoRow(convo: convos[i]),
          );
        },
      ),
    );
  }
}

class _ConvoRow extends ConsumerWidget {
  const _ConvoRow({required this.convo});
  final ConversationPreview convo;

  String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}j';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(userProfileProvider(convo.partnerId));
    return asyncProfile.when(
      loading: () =>
          const ListTile(leading: CircleAvatar(), title: Text('Loading...')),
      error: (_, _) => const ListTile(title: Text('Error')),
      data: (profile) {
        if (profile == null) {
          return const ListTile(title: Text('User not found'));
        }
        return ListTile(
          onTap: () => context.push(AppRoutes.dmChatPath(convo.partnerId)),
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceElevated(context),
            backgroundImage: (profile.avatarUrl?.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(profile.avatarUrl!)
                : null,
            child: (profile.avatarUrl?.isEmpty ?? true)
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          title: Text(
            '@${profile.username}',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary(context),
            ),
          ),
          subtitle: Text(
            convo.lastMessage.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: convo.unreadCount > 0
                  ? AppColors.textPrimary(context)
                  : AppColors.textMuted(context),
              fontWeight: convo.unreadCount > 0
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _timeLabel(convo.lastMessage.createdAt),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 4),
              if (convo.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${convo.unreadCount}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
