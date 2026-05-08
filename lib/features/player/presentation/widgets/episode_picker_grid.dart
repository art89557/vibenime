import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/episode.dart';

/// Grid 6 kolom episode picker di dalam PlayerScreen.
/// Episode aktif ter-highlight (border + background ungu).
/// Tap episode lain → switch tanpa keluar dari Player.
class EpisodePickerGrid extends StatelessWidget {
  const EpisodePickerGrid({
    required this.episodes,
    required this.activeEpisodeId,
    required this.onTap,
    super.key,
  });

  final List<Episode> episodes;
  final String activeEpisodeId;
  final void Function(Episode ep) onTap;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Tidak ada episode untuk anime ini.',
          style: GoogleFonts.inter(color: AppColors.textOnDarkMuted),
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
      itemCount: episodes.length,
      itemBuilder: (_, i) {
        final ep = episodes[i];
        final isActive = ep.id == activeEpisodeId;
        return _PickerTile(
          number: ep.number,
          isActive: isActive,
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
  });

  final int number;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.primary
          : AppColors.surfaceDarkElevated,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isActive ? Colors.white : Colors.white.withValues(alpha: 0.1),
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$number',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.textOnDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
