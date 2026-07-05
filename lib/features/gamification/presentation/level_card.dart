import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/badges.dart' as gam;
import '../data/xp_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Card progress XP + level + badge grid — render di Profile screen.
///
/// Tampil:
/// - Header: "Level X" + XP total + progress bar ke level berikutnya
/// - Grid 4-col badge — earned (full color) vs locked (grayscale)
class LevelCard extends ConsumerWidget {
  const LevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncXp = ref.watch(myXpProvider);
    final asyncBadges = ref.watch(myBadgesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            asyncXp.when(
              loading: () => const _LoadingHeader(),
              error: (_, _) => const SizedBox(height: 60),
              data: (xp) => _LevelHeader(xp: xp),
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.borderColor(context), height: 1),
            const SizedBox(height: 12),
            Text(
              'BADGES',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 8),
            asyncBadges.when(
              loading: () => const SizedBox(height: 80),
              error: (_, _) => const SizedBox.shrink(),
              data: (earned) => _BadgeGrid(earned: earned),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.xp});

  final UserXp xp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Level ',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppColors.textMuted(context),
              ),
            ),
            Text(
              '${xp.level}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryAdaptive(context),
                height: 1,
              ),
            ),
            const Spacer(),
            Text(
              '${xp.xp} XP',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryAdaptive(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tiny),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: xp.levelProgress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.borderColor(context),
              valueColor: AlwaysStoppedAnimation(
                AppColors.primaryAdaptive(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          xp.xpToNextLevel > 0
              ? '${xp.xpToNextLevel} XP lagi ke Level ${xp.level + 1}'
              : 'Max level',
          style: GoogleFonts.roboto(
            fontSize: 11,
            color: AppColors.textMuted(context),
          ),
        ),
      ],
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned});

  final Set<gam.Badge> earned;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: 0.78,
      children: [
        for (final badge in gam.Badge.values)
          _BadgeChip(badge: badge, isEarned: earned.contains(badge)),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.isEarned});

  final gam.Badge badge;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    final color = isEarned
        ? badge.color
        : AppColors.textMuted(context).withValues(alpha: 0.5);
    return Tooltip(
      message: '${badge.name}\n${badge.description}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isEarned ? 0.2 : 0.08),
              border: Border.all(color: color, width: isEarned ? 2 : 1),
            ),
            child: Icon(
              isEarned ? badge.icon : Icons.lock_outline_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isEarned
                  ? AppColors.textPrimary(context)
                  : AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
