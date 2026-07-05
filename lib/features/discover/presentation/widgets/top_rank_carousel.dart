import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../shared/models/anime.dart';

/// Tema warna per peringkat (medali): emas / perak / perunggu.
class _RankTheme {
  const _RankTheme(this.color, this.label);
  final Color color;
  final String label;

  static _RankTheme of(int rank) => switch (rank) {
    1 => const _RankTheme(Color(0xFFFFC107), 'TOP 1'), // gold/amber
    2 => const _RankTheme(Color(0xFFC0C7D1), 'TOP 2'), // silver
    _ => const _RankTheme(Color(0xFFCD7F32), 'TOP 3'), // bronze
  };
}

/// Carousel banner "Top 3" yang bisa di-swipe dengan snap + efek skala kartu
/// non-aktif mengecil + dot indicator yang melar saat aktif.
///
/// Modular & DI-friendly: caller menyuntik [top] (≤3 anime teratas). Kalau
/// kosong → tidak dirender.
class TopRankCarousel extends StatefulWidget {
  const TopRankCarousel({required this.top, super.key});

  /// Hingga 3 anime teratas (urut peringkat #1..#3).
  final List<Anime> top;

  @override
  State<TopRankCarousel> createState() => _TopRankCarouselState();
}

class _TopRankCarouselState extends State<TopRankCarousel> {
  static const _viewportFraction = 0.88;
  static const _cardHeight = 188.0;

  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.top.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: _cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) {
              Haptic.selection();
              setState(() => _currentPage = i);
            },
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Kartu non-aktif mengecil ke 90% saat di-swipe.
                  double scale = index == _currentPage ? 1.0 : 0.9;
                  if (_controller.position.haveDimensions) {
                    final page =
                        _controller.page ?? _controller.initialPage.toDouble();
                    scale = (1 - ((page - index).abs() * 0.1)).clamp(0.9, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: _RankBannerCard(rank: index + 1, anime: items[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _DotsIndicator(count: items.length, active: _currentPage),
      ],
    );
  }
}

/// Dot indicator: dot aktif melar jadi garis pendek.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: isActive ? 20 : 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.textMuted(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

/// Satu banner peringkat: cover + scrim 3-stop + trophy badge + metadata,
/// dibungkus aura BoxShadow sesuai tema medali.
class _RankBannerCard extends StatelessWidget {
  const _RankBannerCard({required this.rank, required this.anime});

  final int rank;
  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final theme = _RankTheme.of(rank);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.animeDetailPath(anime.id.toString())),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          // Aura glow lembut sesuai tema medali.
          boxShadow: [
            BoxShadow(
              color: theme.color.withValues(alpha: 0.15),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover full-bleed.
              if (anime.coverImage.isEmpty)
                Container(color: AppColors.surfaceElevated(context))
              else
                CachedNetworkImage(
                  imageUrl: anime.coverImage,
                  fit: BoxFit.cover,
                  placeholder: (c, _) =>
                      Container(color: AppColors.surfaceElevated(c)),
                  errorWidget: (c, _, _) =>
                      Container(color: AppColors.surfaceElevated(c)),
                ),

              // Scrim 3-stop untuk kontras teks putih.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(0, 0, 0, 0.15),
                      Color.fromRGBO(0, 0, 0, 0.35),
                      Color.fromRGBO(0, 0, 0, 0.88),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              // Trophy badge kiri-atas.
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.color,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: [
                      BoxShadow(
                        color: theme.color.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 14,
                        color: AppColors.onAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        theme.label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Metadata bawah.
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (anime.episodes != null) ...[
                          Text(
                            'Eps ${anime.episodes}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          if (anime.popularity != null)
                            Text(
                              '  ·  ',
                              style: GoogleFonts.roboto(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                        if (anime.popularity != null) ...[
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${compactCount(anime.popularity!)} views',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
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
        ),
      ),
    );
  }
}
