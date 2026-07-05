import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/anime.dart';
import '../../../../core/theme/app_radius.dart';

/// Card kompak — poster 2:3 + title 1-line. Dipakai di view mode "compact"
/// (6-10 col grid). Lebih kecil dari AnimeCard standar.
class AnimeCompactCard extends StatelessWidget {
  const AnimeCompactCard({super.key, required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: anime.coverImage.isEmpty
                  ? Container(color: AppColors.surfaceElevated(context))
                  : CachedNetworkImage(
                      memCacheWidth: 300,
                      imageUrl: anime.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surfaceElevated(context)),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceElevated(context),
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 24,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // Title — single line bold compact
          Text(
            anime.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
