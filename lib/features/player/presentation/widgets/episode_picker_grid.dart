import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/episode.dart';
import '../../../../core/theme/app_radius.dart';

/// Grid 6 kolom episode picker di dalam PlayerScreen.
/// Episode aktif ter-highlight (border + background cyan).
/// Tap episode lain → switch tanpa keluar dari Player.
///
/// Kalau [maxReleasedEpisode] di-set, episode dengan number > nilai itu akan
/// disembunyikan (sama logic dengan EpisodesGrid di Detail).
class EpisodePickerGrid extends StatelessWidget {
  const EpisodePickerGrid({
    required this.episodes,
    required this.activeEpisodeId,
    required this.onTap,
    this.watchedIds = const {},
    this.progress = const {},
    this.maxReleasedEpisode,
    super.key,
  });

  final List<Episode> episodes;
  final String activeEpisodeId;
  final void Function(Episode ep) onTap;

  /// Set ID episode yang sudah ditonton (history) — untuk show checkmark.
  final Set<String> watchedIds;

  /// Map episodeId → fraction progress (0–1) untuk progress bar di tile.
  final Map<String, double> progress;

  /// Episode tertinggi yang sudah rilis. Null = tampil semua.
  final int? maxReleasedEpisode;

  @override
  Widget build(BuildContext context) {
    // Filter episode yang belum rilis
    final visible = maxReleasedEpisode == null
        ? episodes
        : episodes.where((e) => e.number <= maxReleasedEpisode!).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Belum ada episode rilis.',
          style: GoogleFonts.roboto(color: AppColors.textOnDarkMuted),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final ep = visible[i];
        final isActive = ep.id == activeEpisodeId;
        return _PickerTile(
          number: ep.number,
          isActive: isActive,
          isWatched: watchedIds.contains(ep.id),
          progress: progress[ep.id],
          onTap: isActive ? null : () => onTap(ep),
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.number,
    required this.isActive,
    required this.onTap,
    this.isWatched = false,
    this.progress,
  });

  final int number;
  final bool isActive;
  final bool isWatched;

  /// Fraction progress tonton (0–1). Null = belum pernah / tak ada data.
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary : AppColors.surfaceDarkElevated,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive
                  ? Colors.white
                  : (isWatched
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1)),
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$number',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? Colors.white
                        : (isWatched
                              ? AppColors.primary
                              : AppColors.textOnDark),
                  ),
                ),
              ),
              // Checkmark di pojok kanan atas kalau sudah ditonton (tidak aktif)
              if (isWatched && !isActive)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ),
              // Progress bar tipis di bawah tile (menit terakhir ditonton).
              if (progress != null && progress! > 0 && !isActive)
                Positioned(
                  left: 3,
                  right: 3,
                  bottom: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.tiny),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
