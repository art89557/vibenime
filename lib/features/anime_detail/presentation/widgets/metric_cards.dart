import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/anime.dart';
import '../../../../core/theme/app_radius.dart';

/// 3 metric cards: ANILIST score · EPISODE · DURASI.
/// Style: bordered card dengan angka serif italic + label mono uppercase.
class MetricCards extends StatelessWidget {
  const MetricCards({required this.anime, super.key});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            value: anime.averageScore != null
                ? (anime.averageScore! / 10).toStringAsFixed(1)
                : '–',
            label: 'ANILIST',
            highlight: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            value: anime.episodes != null ? '06/${anime.episodes}' : '–',
            label: 'EPISODE',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            value: anime.duration != null ? '${anime.duration}m' : '–',
            label: context.l10n.detailMetricDuration,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: highlight
                  ? AppColors.primary
                  : AppColors.textPrimary(context),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.5,
              color: AppColors.textMuted(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
