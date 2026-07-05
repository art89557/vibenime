import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../shared/models/anime.dart';
import '../../../../core/theme/app_radius.dart';

/// Background banner untuk `FlexibleSpaceBar` di SliverAppBar Detail —
/// banner image + gradient gelap yang berakhir di `surfaceDark` supaya
/// menyatu mulus dengan background page saat header mengkerut (collapse).
///
/// Poster cover + judul TIDAK di sini lagi — sekarang di [DetailTitleBlock]
/// (section terpisah di bawah header yang ikut scroll normal).
class DetailHeaderBackground extends StatelessWidget {
  const DetailHeaderBackground({required this.anime, super.key});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = anime.bannerImage ?? anime.coverImage;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Banner image
        bannerUrl.isEmpty
            ? Container(color: AppColors.surfaceElevated(context))
            : CachedNetworkImage(imageUrl: bannerUrl, fit: BoxFit.cover),
        // Dark overlay — fade ke surfaceDark di bawah supaya seamless ke konten.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(11, 14, 20, 0.5),
                Color.fromRGBO(11, 14, 20, 0.85),
                AppColors.surface(context),
              ],
              stops: [0.0, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Blok judul Detail — poster cover (Hero) + studio·tahun + judul.
///
/// Dirender sebagai section tepat di bawah header collapsing, ikut scroll
/// normal (lihat `AnimeDetailScreen`).
class DetailTitleBlock extends StatelessWidget {
  const DetailTitleBlock({required this.anime, super.key});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Hero tag matches AnimeCard di Home — cover image fly smooth dari
          // Home grid ke posisi ini saat navigasi.
          Hero(
            tag: 'cover-${anime.id}',
            flightShuttleBuilder: (_, _, _, _, _) {
              // Saat in-flight, render plain image tanpa parent styling
              // supaya transition smooth tanpa flicker.
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: anime.coverImage.isEmpty
                    ? Container(color: AppColors.surfaceElevated(context))
                    : CachedNetworkImage(
                        imageUrl: anime.coverImage,
                        fit: BoxFit.cover,
                      ),
              );
            },
            // SizedBox HARUS membungkus AspectRatio (bukan di dalamnya): di
            // dalam Row, AspectRatio menerima lebar unbounded dan gagal layout.
            // Lebar tetap 110 → AspectRatio hitung tinggi.
            child: SizedBox(
              width: 110,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: anime.coverImage.isEmpty
                      ? Container(color: AppColors.surfaceElevated(context))
                      : CachedNetworkImage(
                          imageUrl: anime.coverImage,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _topLine(anime),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  anime.displayTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _topLine(Anime a) {
    final parts = <String>[];
    if (a.studio != null) parts.add(a.studio!.toUpperCase());
    if (a.seasonYear != null) {
      final season = _seasonLabel(a.season);
      parts.add('${a.seasonYear} $season'.trim());
    }
    return parts.join(' · ');
  }

  static String _seasonLabel(String? s) {
    switch (s) {
      case 'WINTER':
        return 'WINTER';
      case 'SPRING':
        return 'SPRING';
      case 'SUMMER':
        return 'SUMMER';
      case 'FALL':
        return 'FALL';
      default:
        return '';
    }
  }
}

/// Circle icon button untuk top action bar (back + bookmark).
///
/// **Public** karena dipakai di `AnimeDetailScreen` (di luar HeroBanner)
/// untuk action bar floating yang lebih responsive ke tap.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: () {
          Haptic.light();
          onTap();
        },
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(icon, color: iconColor ?? Colors.white),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceHigh(
            context,
          ).withValues(alpha: 0.75),
          shape: CircleBorder(
            side: BorderSide(color: AppColors.borderColor(context)),
          ),
        ),
      ),
    );
  }
}
