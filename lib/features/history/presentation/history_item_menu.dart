import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../data/history_entry.dart';
import '../data/history_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Bottom sheet opsi untuk 1 item history / "Terakhir Ditonton":
/// **Lanjutkan nonton · Buka detail anime · Tandai selesai · Hapus dari riwayat**.
/// Dipakai dari Home (recent row) dan layar Riwayat Menonton.
Future<void> showWatchItemMenu(
  BuildContext context,
  WidgetRef ref,
  HistoryEntry entry,
) async {
  Haptic.light();
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceElevated(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tile(ctx, Icons.play_arrow_rounded, 'Lanjutkan nonton', 'resume'),
          _tile(ctx, Icons.info_outline_rounded, 'Buka detail anime', 'detail'),
          _tile(
            ctx,
            Icons.check_circle_outline_rounded,
            'Tandai selesai',
            'finish',
          ),
          _tile(
            ctx,
            Icons.delete_outline_rounded,
            'Hapus dari riwayat',
            'delete',
            danger: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final repo = ref.read(historyRepositoryProvider);
  switch (choice) {
    case 'resume':
      context.push(
        AppRoutes.playerPath(entry.animeId.toString(), entry.episodeId),
      );
    case 'detail':
      context.push(AppRoutes.animeDetailPath(entry.animeId.toString()));
    case 'finish':
      await repo.markFinished(entry);
    case 'delete':
      await repo.delete(entry.animeId, entry.episodeId);
  }
}

Widget _tile(
  BuildContext ctx,
  IconData icon,
  String label,
  String value, {
  bool danger = false,
}) {
  final color = danger ? AppColors.error : AppColors.textPrimary(ctx);
  return ListTile(
    leading: Icon(icon, color: color, size: 22),
    title: Text(label, style: GoogleFonts.roboto(color: color)),
    onTap: () => Navigator.pop(ctx, value),
  );
}
