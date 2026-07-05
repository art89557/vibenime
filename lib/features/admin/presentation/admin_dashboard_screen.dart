import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav_helper.dart';
import '../data/admin_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Admin Dashboard — overview stats global.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminStatsProvider),
          ),
        ],
      ),
      body: asyncStats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              context.l10n.adminStatsError(e.toString()),
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(color: AppColors.error),
            ),
          ),
        ),
        data: (stats) {
          if (stats == null) {
            return Center(
              child: Text(
                context.l10n.adminStatsUnavailable,
                style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel('OVERVIEW'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(
                    label: context.l10n.adminTotalUsers,
                    value: stats.totalUsers,
                    icon: Icons.people_alt_rounded,
                    color: AppColors.primary,
                  ),
                  _StatCard(
                    label: context.l10n.adminSignupsToday,
                    value: stats.signupsToday,
                    icon: Icons.person_add_alt_1_rounded,
                    color: AppColors.success,
                  ),
                  _StatCard(
                    label: context.l10n.adminActive7d,
                    value: stats.activeUsers7d,
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.warning,
                  ),
                  _StatCard(
                    label: context.l10n.adminMessagesLabel,
                    value: stats.totalMessages,
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                  ),
                  _StatCard(
                    label: context.l10n.adminFriendships,
                    value: stats.totalFriendships,
                    icon: Icons.group_rounded,
                    color: AppColors.primaryVariant,
                  ),
                  _StatCard(
                    label: 'Banned',
                    value: stats.bannedUsers,
                    icon: Icons.block_rounded,
                    color: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel(context.l10n.adminActionsLabel),
              _ActionTile(
                icon: Icons.people_outline_rounded,
                title: 'User Management',
                subtitle: context.l10n.adminUsersSub(
                  stats.totalUsers,
                  stats.adminCount,
                ),
                onTap: () => context.push(AppRoutes.adminUsers),
              ),
              _ActionTile(
                icon: Icons.shield_outlined,
                title: context.l10n.adminMessageModeration,
                subtitle: context.l10n.adminModerateSub,
                onTap: () => context.push(AppRoutes.adminModeration),
              ),
              _ActionTile(
                icon: Icons.video_library_outlined,
                title: 'Video Catalog',
                subtitle: context.l10n.adminCatalogSub,
                onTap: () => context.push(AppRoutes.adminPanel),
              ),
              const SizedBox(height: 24),
              _SectionLabel('SIGNUP TREND'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.adminSignupsWeek(stats.signupsWeek),
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.adminSignupsTodayPct(
                        stats.signupsToday,
                        (stats.signupsToday /
                                (stats.signupsWeek == 0
                                    ? 1
                                    : stats.signupsWeek) *
                                100)
                            .toStringAsFixed(0),
                      ),
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted(context),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
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
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
