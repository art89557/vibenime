import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/anime.dart';

/// Row metadata di bawah video player: cover thumb + judul anime + episode + meta.
class PlayerMetadataRow extends StatelessWidget {
  const PlayerMetadataRow({
    required this.anime,
    required this.episodeNumber,
    required this.onBack,
    super.key,
  });

  final Anime anime;
  final int episodeNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: anime.coverImage.isEmpty
                  ? Container(color: AppColors.surfaceDarkElevated)
                  : CachedNetworkImage(
                      imageUrl: anime.coverImage,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceDarkElevated,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anime.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Episode $episodeNumber',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                    if (anime.averageScore != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.circle,
                          size: 4, color: AppColors.textOnDarkMuted),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        (anime.averageScore! / 10).toStringAsFixed(2),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textOnDarkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
