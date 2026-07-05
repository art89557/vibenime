import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../shared/models/stream_source.dart';
import '../player_providers.dart';
import '../../../../core/theme/app_radius.dart';

/// Dropdown picker untuk pilih source streaming di player.
///
/// Tampilkan label source aktif (mis. "Otakudesu"), tap untuk buka
/// bottom sheet dengan semua source available untuk episode ini.
/// On pick → set `selectedSourceProvider(animeId)` → trigger reorder
/// payload list di `streamPayloadsProvider`.
///
/// Hide kalau payload list cuma 1 source (tidak ada pilihan).
class SourcePickerDropdown extends ConsumerWidget {
  const SourcePickerDropdown({
    super.key,
    required this.animeId,
    required this.payloads,
  });

  final int animeId;
  final List<StreamPayload> payloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter payload yang punya sourceLabel (skip yang nullable label).
    final labeled = payloads.where((p) => p.sourceLabel != null).toList();
    if (labeled.length < 2) return const SizedBox.shrink();

    final activeId = ref.watch(selectedSourceProvider(animeId));
    final activeLabel = activeId == null
        ? labeled.first.sourceLabel!
        : labeled
              .firstWhere(
                (p) => p.sourceId == activeId,
                orElse: () => labeled.first,
              )
              .sourceLabel!;

    return GestureDetector(
      onTap: () => _showPicker(context, ref, labeled, activeId),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 14,
              color: AppColors.primaryAdaptive(context),
            ),
            const SizedBox(width: 8),
            Text(
              activeLabel,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<StreamPayload> labeled,
    String? activeId,
  ) async {
    Haptic.selection();
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.tiny),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Source Video',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kalau salah satu broken, coba source lain',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 12),
              for (final payload in labeled)
                _SourceTile(
                  label: payload.sourceLabel!,
                  sourceId: payload.sourceId,
                  qualityHint: _qualityHint(payload),
                  isActive:
                      payload.sourceId == activeId ||
                      (activeId == null && payload == labeled.first),
                  onTap: () => Navigator.pop(ctx, payload.sourceId),
                ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    ref.read(selectedSourceProvider(animeId).notifier).state = picked;
  }

  /// Build hint string dari sources list — "1080p HLS" / "720p MP4" / null.
  String? _qualityHint(StreamPayload payload) {
    if (payload.youtubeVideoId != null) return 'YouTube';
    final src = payload.primarySource;
    if (src == null) return null;
    final quality = src.quality;
    final type = src.isHls ? 'HLS' : 'MP4';
    if (quality == null) return type;
    return '$quality $type';
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.label,
    required this.sourceId,
    required this.qualityHint,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String? sourceId;
  final String? qualityHint;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryAdaptive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              _iconFor(sourceId),
              size: 20,
              color: isActive ? color : AppColors.textMuted(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? color : AppColors.textPrimary(context),
                    ),
                  ),
                  if (qualityHint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      qualityHint!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isActive) Icon(Icons.check_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? sourceId) {
    switch (sourceId) {
      case 'otakudesu':
      case 'kuramanime':
      case 'samehadaku':
        return Icons.public_rounded;
      case 'gogoanime':
        return Icons.language_rounded;
      case 'youtube_trailer':
        return Icons.smart_display_rounded;
      case 'local_download':
        return Icons.offline_pin_rounded;
      case 'mux_sample':
        return Icons.science_outlined;
      default:
        return Icons.video_library_outlined;
    }
  }
}
