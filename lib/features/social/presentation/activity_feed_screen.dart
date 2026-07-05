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
import '../data/activity_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Feed aktivitas teman — apa yang mereka tonton/add/finish.
class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeed = ref.watch(activityFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsActivityFeed),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(activityFeedProvider),
          ),
        ],
      ),
      body: asyncFeed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(activityFeedProvider),
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 56,
                      color: AppColors.textMuted(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.activityEmpty,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tambah teman untuk lihat apa yang mereka tonton',
                      textAlign: TextAlign.center,
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (_, i) => _EventCard(event: events[i]),
          );
        },
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});
  final ActivityEvent event;

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return '${diff.inDays}h';
    if (diff.inHours > 0) return '${diff.inHours}j';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(userProfileProvider(event.userId));
    return asyncProfile.when(
      loading: () => const SizedBox(height: 70),
      error: (_, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.friendProfilePath(event.userId)),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceElevated(context),
                    backgroundImage: (profile.avatarUrl?.isNotEmpty ?? false)
                        ? CachedNetworkImageProvider(profile.avatarUrl!)
                        : null,
                    child: (profile.avatarUrl?.isEmpty ?? true)
                        ? const Icon(Icons.person_outline_rounded, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.animeDetailPath(event.animeId.toString()),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              color: AppColors.textMuted(context),
                            ),
                            children: [
                              TextSpan(
                                text: '@${profile.username} ',
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: event.type.verb),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.animeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(event.createdAt),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (event.animeCover != null &&
                    event.animeCover!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      width: 40,
                      height: 56,
                      child: CachedNetworkImage(
                        imageUrl: event.animeCover!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
