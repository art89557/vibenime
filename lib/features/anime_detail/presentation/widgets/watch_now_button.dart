import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/episode.dart';
import '../../../history/presentation/history_providers.dart';

/// Tombol "Mulai Tonton" full-width.
/// - Kalau ada history → resume label "Lanjutkan Episode N (XX:XX)"
/// - Kalau tidak → "Mulai Tonton" → play episode 1
class WatchNowButton extends ConsumerWidget {
  const WatchNowButton({
    required this.animeId,
    required this.episodes,
    super.key,
  });

  final int animeId;
  final List<Episode> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(latestHistoryForAnimeProvider(animeId));
    final hasResume = history != null && !history.isFinished;

    final targetEpisode = hasResume
        ? history.episodeId
        : (episodes.isNotEmpty ? episodes.first.id : null);

    final label = hasResume
        ? 'Lanjutkan Episode ${history.episodeNumber}'
        : 'Mulai Tonton';
    final subLabel = hasResume
        ? _formatPosition(history.position)
        : 'Episode 1';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: targetEpisode == null
            ? null
            : () => context.push(
                  AppRoutes.playerPath(animeId.toString(), targetEpisode),
                ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_filled_rounded, size: 24),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPosition(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return 'menit ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
