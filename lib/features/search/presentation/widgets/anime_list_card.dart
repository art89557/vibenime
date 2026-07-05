import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../shared/models/anime.dart';
import '../../../favorites/data/favorites_repository.dart';
import '../../../favorites/presentation/favorites_providers.dart';
import 'airing_countdown.dart';
import '../../../../core/theme/app_radius.dart';

/// Detailed list card — match AniList browse list view.
///
/// Layout: cover left (96×130) + content right (column):
/// - Top row: countdown (airing) atau format · ep count, score% bubble di kanan
/// - Title bold
/// - Synopsis 3-4 lines ellipsis
/// - Studio name (colored)
/// - Genre tag pills (max 3, rotating colors)
/// - Tombol + favorit di pojok kanan bawah
class AnimeListCard extends ConsumerWidget {
  const AnimeListCard({super.key, required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  /// Cycle warna untuk genre tags — match AniList style (warna brand
  /// berbeda per kategori).
  static const _tagColors = [
    Color(0xFFFF8FA3), // pink/red
    Color(0xFF5DD3F0), // cyan
    Color(0xFFFBBF24), // amber
    Color(0xFF4ADE80), // green
    Color(0xFFA78BFA), // violet
    Color(0xFFFB923C), // orange
  ];

  /// Strip HTML tags dari description AniList — sometimes return raw HTML
  /// dengan <br>, <i>, dll.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _formatLabel(String? format) {
    switch (format) {
      case 'TV':
        return 'TV Show';
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
      case 'MUSIC':
        return 'Music';
      default:
        return format ?? '—';
    }
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    Haptic.medium();
    final repo = ref.read(favoritesRepositoryProvider);
    final nowFavorite = await repo.toggle(anime);
    if (!context.mounted) return;
    AppSnackbar.success(
      context,
      nowFavorite
          ? '${anime.displayTitle} ditambah ke favorit'
          : '${anime.displayTitle} dihapus dari favorit',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(anime.id));
    final hasAiring = anime.nextAiringEpisode != null;
    final hasScore = anime.averageScore != null && anime.averageScore! > 0;
    final synopsis = (anime.description?.isNotEmpty ?? false)
        ? _stripHtml(anime.description!)
        : null;
    final epCount = anime.episodes;

    return InkWell(
      onTap: () {
        Haptic.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover left
              SizedBox(
                width: 96,
                child: anime.coverImage.isEmpty
                    ? Container(color: AppColors.surface(context))
                    : CachedNetworkImage(
                        memCacheWidth: 300,
                        imageUrl: anime.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppColors.surface(context)),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.surface(context),
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 24,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ),
              ),
              // Content right
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: airing countdown / format · ep | score %
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasAiring)
                                  AiringCountdown(
                                    episode: anime.nextAiringEpisode!.episode,
                                    airingAt: anime.nextAiringEpisode!.airingAt,
                                    textStyle: GoogleFonts.roboto(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryAdaptive(context),
                                    ),
                                  ),
                                if (hasAiring) const SizedBox(height: 2),
                                Text(
                                  [
                                    _formatLabel(anime.format),
                                    if (epCount != null) '$epCount episodes',
                                  ].join(' · '),
                                  style: GoogleFonts.roboto(
                                    fontSize: 11,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasScore)
                            Row(
                              children: [
                                Icon(
                                  _scoreIcon(anime.averageScore!),
                                  size: 14,
                                  color: _scoreColor(anime.averageScore!),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${anime.averageScore}%',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _scoreColor(anime.averageScore!),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        anime.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                          height: 1.25,
                        ),
                      ),
                      // Studio (colored)
                      if (anime.studio != null && anime.studio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          anime.studios.isNotEmpty
                              ? anime.studios.join(', ')
                              : anime.studio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _studioColor(anime.studio!),
                          ),
                        ),
                      ],
                      // Synopsis
                      if (synopsis != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          synopsis,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Genre tags + favorit button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: anime.genres.take(2).map((g) {
                                final color =
                                    _tagColors[g.hashCode.abs() %
                                        _tagColors.length];
                                return _GenrePill(label: g, color: color);
                              }).toList(),
                            ),
                          ),
                          InkWell(
                            onTap: () => _toggleFavorite(context, ref),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFavorite
                                    ? AppColors.error.withValues(alpha: 0.18)
                                    : AppColors.primaryAdaptive(
                                        context,
                                      ).withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.add_rounded,
                                size: 18,
                                color: isFavorite
                                    ? AppColors.error
                                    : AppColors.primaryAdaptive(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Smile/neutral/sad face icon — matches AniList score sentiment icons.
  IconData _scoreIcon(int score) {
    if (score >= 75) return Icons.sentiment_very_satisfied_rounded;
    if (score >= 60) return Icons.sentiment_satisfied_rounded;
    if (score >= 40) return Icons.sentiment_neutral_rounded;
    return Icons.sentiment_dissatisfied_rounded;
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  /// Studio brand color — hash deterministik supaya studio yang sama dapat
  /// warna konsisten antar card.
  Color _studioColor(String name) {
    final palette = [
      const Color(0xFFFB923C), // orange (Toei, BUG FILMS)
      const Color(0xFF5DD3F0), // cyan (Studio Kafka)
      const Color(0xFFA78BFA), // violet (bones)
      const Color(0xFF4ADE80), // green
      const Color(0xFFFF8FA3), // pink
    ];
    return palette[name.hashCode.abs() % palette.length];
  }
}

class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toLowerCase(),
        style: GoogleFonts.roboto(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.black.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
