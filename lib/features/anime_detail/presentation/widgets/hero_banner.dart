import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/anime.dart';

/// Hero banner di top Detail screen — banner image + gradient overlay +
/// title + meta chips. Fixed height ~360 px dengan back button overlay.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    required this.anime,
    required this.onBack,
    super.key,
  });

  final Anime anime;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final url = anime.bannerImage ?? anime.coverImage;

    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image.
          if (url.isNotEmpty)
            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          else
            Container(color: AppColors.surfaceDarkElevated),

          // Gradient overlay biar text di atas tetap kebaca.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(15, 15, 26, 0.3),
                    Color.fromRGBO(15, 15, 26, 0.7),
                    AppColors.surfaceDark,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Back button.
          Positioned(
            top: 0,
            left: 4,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
            ),
          ),

          // "Update Setiap Rabu" badge (kalau airing).
          if (anime.isReleasing)
            const Positioned(
              top: 20,
              right: 16,
              child: SafeArea(
                child: _UpdateBadge(),
              ),
            ),

          // Title block + meta di bawah.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anime.title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                if (anime.englishTitle != null &&
                    anime.englishTitle != anime.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    anime.englishTitle!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _MetaChipsRow(anime: anime),
                if (anime.popularity != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_formatViews(anime.popularity!)} popularity',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatViews(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Text(
            'Sedang Tayang',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChipsRow extends StatelessWidget {
  const _MetaChipsRow({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (anime.averageScore != null)
          _MetaPill(
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            label: (anime.averageScore! / 10).toStringAsFixed(2),
          ),
        if (anime.studio != null) _MetaPill(label: anime.studio!),
        if (anime.seasonYear != null)
          _MetaPill(label: '${_seasonLabel(anime.season)} ${anime.seasonYear}'),
        if (anime.format != null) _MetaPill(label: _formatLabel(anime.format!)),
      ],
    );
  }

  static String _seasonLabel(String? s) {
    switch (s) {
      case 'WINTER':
        return 'Winter';
      case 'SPRING':
        return 'Spring';
      case 'SUMMER':
        return 'Summer';
      case 'FALL':
        return 'Fall';
      default:
        return '';
    }
  }

  static String _formatLabel(String f) {
    switch (f) {
      case 'TV':
        return 'TV';
      case 'TV_SHORT':
        return 'TV Short';
      case 'MOVIE':
        return 'Movie';
      case 'OVA':
        return 'OVA';
      case 'ONA':
        return 'ONA';
      case 'SPECIAL':
        return 'Special';
      default:
        return f;
    }
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    this.icon,
    this.iconColor,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
