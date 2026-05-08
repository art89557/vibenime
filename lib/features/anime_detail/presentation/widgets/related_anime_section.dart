import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/related_anime.dart';

/// Horizontal scroll "Anime Terkait".
class RelatedAnimeSection extends StatelessWidget {
  const RelatedAnimeSection({required this.relations, super.key});

  final List<RelatedAnime> relations;

  @override
  Widget build(BuildContext context) {
    if (relations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            'Anime Terkait',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: relations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _RelatedCard(item: relations[i]),
          ),
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.item});

  final RelatedAnime item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
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
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: item.coverImage.isEmpty
                        ? Container(color: AppColors.surfaceDarkElevated)
                        : CachedNetworkImage(
                            imageUrl: item.coverImage,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.surfaceDarkElevated,
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
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: _RelationBadge(label: item.relationLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.episodes != null)
              Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined,
                      size: 12, color: AppColors.textOnDarkMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Eps ${item.episodes}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textOnDarkMuted,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
          const SizedBox(width: 2),
          Text(
            (score / 10).toStringAsFixed(2),
            style: GoogleFonts.inter(
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

class _RelationBadge extends StatelessWidget {
  const _RelationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
