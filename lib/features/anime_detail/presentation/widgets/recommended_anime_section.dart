import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/l10n_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/models/recommended_anime.dart';

/// Horizontal scroll "Kamu mungkin suka" — rekomendasi AniList.
/// Data sudah di-fetch di `mediaDetail` (`recommendations`), tinggal ditampilkan.
class RecommendedAnimeSection extends StatelessWidget {
  const RecommendedAnimeSection({required this.items, super.key});

  final List<RecommendedAnime> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            context.l10n.detailRecommended,
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _RecCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.item});

  final RecommendedAnime item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            context.push(AppRoutes.animeDetailPath(item.id.toString())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: item.coverImage.isEmpty
                        ? Container(color: AppColors.surfaceElevated(context))
                        : CachedNetworkImage(
                            memCacheWidth: 300,
                            imageUrl: item.coverImage,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.surfaceElevated(context),
                            ),
                          ),
                  ),
                ),
                if (item.averageScore != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _ScoreBadge(score: item.averageScore!),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
          const SizedBox(width: 2),
          Text(
            (score / 10).toStringAsFixed(1),
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
