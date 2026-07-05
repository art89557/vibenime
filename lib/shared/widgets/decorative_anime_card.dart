import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/number_format.dart';
import '../models/anime.dart';

/// Kartu anime dekoratif (gaya kartu "Peringkat / Hot Anime"): cover full-bleed
/// + gradient vignette gelap dari atas (transparan) ke bawah (hitam pekat) +
/// metadata menumpuk di bawah (judul · badge episode · views).
///
/// Presentation murni — dipakai di row horizontal (lihat Home) atau grid.
/// Tinggi diambil dari parent (mis. `SizedBox(height: …)` pembungkus ListView
/// horizontal); lebar default ~140dp.
class DecorativeAnimeCard extends StatelessWidget {
  const DecorativeAnimeCard({
    required this.anime,
    required this.onTap,
    this.width = 140,
    this.rank,
    super.key,
  });

  final Anime anime;
  final VoidCallback onTap;
  final double width;

  /// Kalau diisi → badge peringkat kuning "#N" di kiri-atas (dipakai Hot Anime).
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Cover full-bleed.
              if (anime.coverImage.isEmpty)
                Container(color: AppColors.surfaceElevated(context))
              else
                CachedNetworkImage(
                  memCacheWidth: 400,
                  imageUrl: anime.coverImage,
                  fit: BoxFit.cover,
                  placeholder: (c, _) =>
                      Container(color: AppColors.surfaceElevated(c)),
                  errorWidget: (c, _, _) =>
                      Container(color: AppColors.surfaceElevated(c)),
                ),

              // 2. Gradient vignette gelap (transparan → hitam 0.85).
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color.fromRGBO(0, 0, 0, 0.2),
                      Color.fromRGBO(0, 0, 0, 0.85),
                    ],
                    stops: [0.35, 0.6, 1.0],
                  ),
                ),
              ),

              // 3. Badge peringkat (opsional) — kiri-atas.
              if (rank != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ),

              // 4. Metadata bawah — judul · badge episode · views.
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (anime.episodes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Eps ${anime.episodes}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    if (anime.popularity != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${compactCount(anime.popularity!)} views',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
