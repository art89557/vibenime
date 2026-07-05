import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/source_type.dart';
import '../../../player/data/video_catalog_repository.dart';
import '../../../../core/theme/app_radius.dart';

/// Card group anime + list episode-nya — admin panel.
///
/// **v2 polished:**
/// - Header: badge anime ID + nama + summary (X episode, Y source types)
/// - Color stripe di kiri sesuai dominant source type
/// - Episodes list dengan source type icon + colored chip
/// - Smooth expand/collapse animation
class AnimeGroupCard extends StatefulWidget {
  const AnimeGroupCard({
    required this.anilistId,
    required this.sources,
    required this.onTapEntry,
    super.key,
  });

  final int anilistId;
  final List<VideoSource> sources;
  final void Function(VideoSource source) onTapEntry;

  @override
  State<AnimeGroupCard> createState() => _AnimeGroupCardState();
}

class _AnimeGroupCardState extends State<AnimeGroupCard> {
  bool _expanded = true;

  /// Dominant source type — yang paling banyak di group ini. Untuk color stripe.
  SourceType get _dominantType {
    final counts = <SourceType, int>{};
    for (final s in widget.sources) {
      final t = s.sourceTypeEnum;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Set source type unik di group ini (untuk summary badge).
  Set<SourceType> get _uniqueTypes =>
      widget.sources.map((s) => s.sourceTypeEnum).toSet();

  /// Color untuk source type — konsisten dengan _StatsHeader._colorForType.
  static Color colorForType(SourceType type) {
    switch (type) {
      case SourceType.archiveOrg:
        return AppColors.success;
      case SourceType.youtube:
        return AppColors.error;
      case SourceType.mux:
        return AppColors.warning;
      case SourceType.cloudflareR2:
        return AppColors.primary;
      case SourceType.manual:
        return AppColors.textOnDarkMuted;
    }
  }

  /// Icon untuk source type.
  static IconData iconForType(SourceType type) {
    switch (type) {
      case SourceType.archiveOrg:
        return Icons.public_rounded;
      case SourceType.youtube:
        return Icons.play_circle_filled_rounded;
      case SourceType.mux:
        return Icons.stream_rounded;
      case SourceType.cloudflareR2:
        return Icons.cloud_rounded;
      case SourceType.manual:
        return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstNote = widget.sources.first.notes ?? '';
    final animeName = firstNote.split('—').first.trim();
    final dominantColor = colorForType(_dominantType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header dengan color stripe + tap to expand
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Color stripe kiri (4px wide)
                  Container(width: 4, color: dominantColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          // Anime ID badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '#${widget.anilistId}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Name + summary
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  animeName.isEmpty
                                      ? 'Anime ${widget.anilistId}'
                                      : animeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textOnDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '${widget.sources.length} eps',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        color: AppColors.textOnDarkMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Source type indicators (dots)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _uniqueTypes
                                          .map(
                                            (t) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              child: Icon(
                                                iconForType(t),
                                                size: 11,
                                                color: colorForType(t),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: _expanded ? 0.5 : 0,
                            child: const Icon(
                              Icons.expand_more_rounded,
                              color: AppColors.textOnDarkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Episodes list (expandable)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const Divider(height: 1, color: AppColors.border),
                ...widget.sources.map(
                  (s) =>
                      _EpisodeRow(source: s, onTap: () => widget.onTapEntry(s)),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.source, required this.onTap});

  final VideoSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = source.sourceTypeEnum;
    final typeColor = _AnimeGroupCardState.colorForType(type);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Episode number badge
            Container(
              width: 38,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  source.episodeNumber.toString().padLeft(2, '0'),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Notes + chips
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    source.notes?.isNotEmpty == true
                        ? source.notes!
                        : source.videoUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ColoredChip(
                        text: type.label,
                        color: typeColor,
                        icon: _AnimeGroupCardState.iconForType(type),
                      ),
                      const SizedBox(width: 5),
                      _PlainChip(text: source.quality),
                      const SizedBox(width: 5),
                      // Priority badge
                      _PriorityChip(priority: source.priority),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textOnDarkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Colored chip dengan icon — untuk source type.
class _ColoredChip extends StatelessWidget {
  const _ColoredChip({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.tiny),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain chip neutral — untuk quality / language.
class _PlainChip extends StatelessWidget {
  const _PlainChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadius.tiny),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          color: AppColors.textOnDarkMuted,
        ),
      ),
    );
  }
}

/// Priority chip — color-coded by priority value (lower = higher priority).
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final int priority;

  Color get _color {
    if (priority <= 50) return AppColors.success; // primary fastest
    if (priority <= 100) return AppColors.primary; // default
    if (priority <= 150) return AppColors.warning; // backup
    return AppColors.textOnDarkMuted; // last resort
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.tiny),
      ),
      child: Text(
        'P$priority',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
