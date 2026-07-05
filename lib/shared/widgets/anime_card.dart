import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../models/anime.dart';
import 'press_animation.dart';
import '../../core/theme/app_radius.dart';

/// Vertical poster card v2 (cyan accent).
/// Layout: poster 2:3 + title bold + meta row (⭐ score · format).
class AnimeCard extends StatelessWidget {
  const AnimeCard({
    required this.anime,
    required this.onTap,
    this.width = 130,
    this.heroTagSalt = '',
    super.key,
  });

  final Anime anime;
  final VoidCallback onTap;
  final double width;

  /// Salt untuk Hero tag — supaya anime yang sama muncul di 2 section
  /// (mis. Trending + Popular) tidak collision. Caller pass salt unik per
  /// section (mis. 'trending', 'popular'). Empty = no Hero (skip transition).
  final String heroTagSalt;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: isolasi repaint kartu dari animasi tetangga saat scroll
    // / stagger — kurangi beban GPU di list panjang.
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        child: PressableScale(
          onTap: onTap,
          scaleDown: 0.95,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero tag — cover image fly smooth saat tap card → buka Detail.
              // Tag dengan salt unik per section supaya anime yang sama
              // muncul di Trending + Popular tidak collision. Kalau salt empty
              // skip Hero (cover image transition tetap fade).
              //
              // Flexible(loose): di kontainer longgar (row Home 270px) cover
              // tetap 2:3 natural; di grid yang sel-nya mepet, cover MENYUSUT
              // dulu sebelum teks — kartu tidak pernah RenderFlex-overflow
              // (kasus nyata: grid Completed rasio lama 0.52 overflow 8.2px).
              // Semua pemakai AnimeCard bounded-height, jadi Flexible aman.
              if (heroTagSalt.isEmpty)
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: anime.coverImage.isEmpty
                          ? _placeholder(context)
                          : CachedNetworkImage(
                              imageUrl: anime.coverImage,
                              fit: BoxFit.cover,
                              placeholder: (c, _) => _placeholder(c),
                              errorWidget: (c, _, _) =>
                                  _placeholder(c, broken: true),
                            ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Hero(
                    tag: 'cover-$heroTagSalt-${anime.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: anime.coverImage.isEmpty
                            ? _placeholder(context)
                            : CachedNetworkImage(
                                imageUrl: anime.coverImage,
                                fit: BoxFit.cover,
                                placeholder: (c, _) => _placeholder(c),
                                errorWidget: (c, _, _) =>
                                    _placeholder(c, broken: true),
                              ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                anime.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (anime.averageScore != null) ...[
                    const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      (anime.averageScore! / 10).toStringAsFixed(1),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  if (anime.format != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatLabel(anime.format!),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, {bool broken = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        border: Border.all(color: AppColors.borderColor(context), width: 1),
      ),
      child: broken
          ? Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted(context),
              ),
            )
          : null,
    );
  }

  static String _formatLabel(String f) {
    switch (f) {
      case 'TV':
        return 'TV';
      case 'TV_SHORT':
        return 'TV';
      case 'MOVIE':
        return 'MOVIE';
      case 'OVA':
        return 'OVA';
      case 'ONA':
        return 'ONA';
      case 'SPECIAL':
        return 'SP';
      default:
        return f;
    }
  }
}
