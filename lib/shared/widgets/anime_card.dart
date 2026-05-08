import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../models/anime.dart';

/// Vertical poster card untuk Home / Search / My List.
class AnimeCard extends StatelessWidget {
  const AnimeCard({
    required this.anime,
    required this.onTap,
    this.width = 130,
    super.key,
  });

  final Anime anime;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: anime.coverImage.isEmpty
                    ? Container(color: AppColors.surfaceDarkElevated)
                    : CachedNetworkImage(
                        imageUrl: anime.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AppColors.surfaceDarkElevated,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.surfaceDarkElevated,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textOnDarkMuted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (anime.averageScore != null) ...[
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    (anime.averageScore! / 10).toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textOnDarkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (anime.episodes != null)
                  Text(
                    '${anime.episodes} eps',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textOnDarkMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
