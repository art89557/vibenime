import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/anime.dart';
import '../../../../core/theme/app_radius.dart';

/// Compact header v2 (sesuai screenshot 5): back arrow + title + episode info
/// + 3 icon buttons di kanan (subtitle, download, brightness).
class PlayerMetadataRow extends StatelessWidget {
  const PlayerMetadataRow({
    required this.anime,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.onBack,
    super.key,
  });

  final Anime anime;
  final int episodeNumber;
  final String? episodeTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: onBack,
            tooltip: 'Kembali',
          ),
          // Cover thumbnail (small, 36×52)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.tiny),
            child: SizedBox(
              width: 36,
              height: 52,
              child: anime.coverImage.isEmpty
                  ? Container(color: AppColors.surfaceDarkElevated)
                  : CachedNetworkImage(
                      imageUrl: anime.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surfaceDarkElevated),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.surfaceDarkElevated),
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
                  anime.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _buildSubtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textOnDarkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildSubtitle() {
    final ep = 'EP ${episodeNumber.toString().padLeft(2, '0')}';
    if (episodeTitle == null || episodeTitle!.isEmpty) return ep;
    return '$ep · $episodeTitle';
  }
}
