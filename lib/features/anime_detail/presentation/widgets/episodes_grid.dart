import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/episode.dart';

/// Grid 4 kolom episode tile dengan nomor, gradient ungu→pink.
/// Tap → navigasi ke Player.
class EpisodesGrid extends StatelessWidget {
  const EpisodesGrid({
    required this.episodes,
    required this.onTap,
    super.key,
  });

  final List<Episode> episodes;
  final void Function(Episode episode) onTap;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Belum ada episode untuk anime ini.',
          style: GoogleFonts.inter(color: AppColors.textOnDarkMuted),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: episodes.length,
      itemBuilder: (_, i) {
        final ep = episodes[i];
        return _Tile(
          episode: ep,
          onTap: () => onTap(ep),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.episode, required this.onTap});

  final Episode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.85),
                AppColors.secondary.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${episode.number}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Eps',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
