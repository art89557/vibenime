import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../favorites/data/favorite_entry.dart';
import '../../../../core/theme/app_radius.dart';

/// Result dari status picker sheet:
/// - `value`: status yang dipilih (Watching / Completed / Planning)
/// - `remove`: true kalau user pilih "Remove from list"
/// - null kalau user dismiss
class StatusPickerResult {
  const StatusPickerResult.status(this.value) : remove = false;
  const StatusPickerResult.remove() : value = null, remove = true;

  final WatchStatus? value;
  final bool remove;
}

/// Show bottom sheet untuk pick status anime di list.
///
/// [currentStatus] null = anime belum di-list. Kalau != null, tambah opsi
/// "Remove from list" di paling bawah.
Future<StatusPickerResult?> showStatusPickerSheet({
  required BuildContext context,
  required String animeTitle,
  WatchStatus? currentStatus,
}) {
  return showModalBottomSheet<StatusPickerResult>(
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
              currentStatus == null
                  ? context.l10n.detailAddToList
                  : context.l10n.detailChangeStatus,
              style: GoogleFonts.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              animeTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 16),
            _StatusTile(
              status: WatchStatus.watching,
              icon: Icons.play_circle_outline_rounded,
              isActive: currentStatus == WatchStatus.watching,
              onTap: () {
                Haptic.selection();
                Navigator.pop(
                  ctx,
                  const StatusPickerResult.status(WatchStatus.watching),
                );
              },
            ),
            _StatusTile(
              status: WatchStatus.completed,
              icon: Icons.check_circle_outline_rounded,
              isActive: currentStatus == WatchStatus.completed,
              onTap: () {
                Haptic.selection();
                Navigator.pop(
                  ctx,
                  const StatusPickerResult.status(WatchStatus.completed),
                );
              },
            ),
            _StatusTile(
              status: WatchStatus.planning,
              icon: Icons.bookmark_outline_rounded,
              isActive: currentStatus == WatchStatus.planning,
              onTap: () {
                Haptic.selection();
                Navigator.pop(
                  ctx,
                  const StatusPickerResult.status(WatchStatus.planning),
                );
              },
            ),
            if (currentStatus != null) ...[
              const SizedBox(height: 8),
              Divider(color: AppColors.borderColor(context), height: 1),
              const SizedBox(height: 8),
              _RemoveTile(
                onTap: () {
                  Haptic.heavy();
                  Navigator.pop(ctx, const StatusPickerResult.remove());
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.status,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final WatchStatus status;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryAdaptive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? color : AppColors.textMuted(context),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                status.label,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? color : AppColors.textPrimary(context),
                ),
              ),
            ),
            if (isActive) Icon(Icons.check_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class _RemoveTile extends StatelessWidget {
  const _RemoveTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              size: 22,
              color: AppColors.error,
            ),
            const SizedBox(width: 14),
            Text(
              context.l10n.detailRemoveFromList,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
