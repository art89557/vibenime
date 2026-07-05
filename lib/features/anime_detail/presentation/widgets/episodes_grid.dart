import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/episode.dart';
import '../../../../core/theme/app_radius.dart';

/// Episode card grid 2 kolom dengan thumbnail real (kalau available).
///
/// **Sumber thumbnail (priority chain):**
/// 1. [thumbnailMap] dari `Anime.streamingEpisodes` (Crunchyroll-licensed)
/// 2. [fallbackImageUrl] — anime banner / cover sebagai default
/// 3. Placeholder hatch pattern + label "EP X"
///
/// **Hide unreleased:** kalau [maxReleasedEpisode] di-set, episode dengan
/// number > nilai itu akan hidden (atau di-mark sebagai "akan tayang").
class EpisodesGrid extends StatelessWidget {
  const EpisodesGrid({
    required this.episodes,
    required this.onTap,
    this.watchedIds = const {},
    this.thumbnailMap = const {},
    this.fallbackImageUrl,
    this.maxReleasedEpisode,
    super.key,
  });

  final List<Episode> episodes;
  final void Function(Episode episode) onTap;
  final Set<String> watchedIds;

  /// Map `episodeNumber → thumbnail URL` dari AniList streamingEpisodes.
  /// Kalau key tidak ada, fallback ke [fallbackImageUrl] atau placeholder.
  final Map<int, String?> thumbnailMap;

  /// Default image untuk episode yang tidak punya thumbnail spesifik.
  /// Biasanya banner / cover anime. Better daripada hatch pattern karena
  /// visual konsisten dengan brand anime tsb.
  final String? fallbackImageUrl;

  /// Episode tertinggi yang sudah rilis. Episode dengan `number >` value ini
  /// akan disembunyikan dari grid (untuk mencegah user tap episode belum tayang).
  ///
  /// Null = tampilkan semua (untuk anime sudah selesai / `nextAiringEpisode`
  /// dari AniList null).
  final int? maxReleasedEpisode;

  @override
  Widget build(BuildContext context) {
    // Filter episode yang belum rilis kalau maxReleasedEpisode ada.
    final visible = maxReleasedEpisode == null
        ? episodes
        : episodes.where((e) => e.number <= maxReleasedEpisode!).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Belum ada episode rilis untuk anime ini.',
          style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final ep = visible[i];
        // Priority: streamingEpisodes thumbnail > anime fallback image
        final thumb = thumbnailMap[ep.number] ?? fallbackImageUrl;
        return _EpisodeCard(
          episode: ep,
          isWatched: watchedIds.contains(ep.id),
          thumbnailUrl: thumb,
          onTap: () => onTap(ep),
        );
      },
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.onTap,
    this.isWatched = false,
    this.thumbnailUrl,
  });

  final Episode episode;
  final VoidCallback onTap;
  final bool isWatched;
  final String? thumbnailUrl;

  bool get _hasThumb => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                border: Border.all(
                  color: isWatched
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.borderColor(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _hasThumb
                        ? CachedNetworkImage(
                            memCacheWidth: 480,
                            imageUrl: thumbnailUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, _) => Container(
                              color: AppColors.surfaceHigh(context),
                            ),
                            errorWidget: (_, _, _) =>
                                _PlaceholderThumb(episode: episode),
                          )
                        : _PlaceholderThumb(episode: episode),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'EP ${episode.number}${episode.title != null && episode.title!.isNotEmpty ? ' · ${episode.title!}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Watched checkmark di pojok kiri atas
          if (isWatched)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.onAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder thumbnail dengan hatch pattern + label EP.
class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.episode});
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DiagonalHatchPainter(),
      child: Center(
        child: Text(
          'THUMB EP${episode.number}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppColors.textMuted(context),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Diagonal hatch pattern untuk placeholder thumbnail.
class _DiagonalHatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const spacing = 8.0;
    final total = size.width + size.height;
    for (double x = -size.height; x < total; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
