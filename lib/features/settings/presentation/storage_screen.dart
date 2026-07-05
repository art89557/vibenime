import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../downloads/data/download_entry.dart';
import '../../downloads/data/download_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Storage screen — episode tersimpan offline.
///
/// Sebelumnya tab "Offline" di Pustaka. Sekarang stand-alone screen
/// di-akses dari Settings → Penyimpanan supaya Pustaka fokus ke
/// status tracking (Watching/Completed/Planning).
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  String _totalSize(List<DownloadEntry> list) {
    final total = list.fold<int>(0, (sum, e) => sum + e.fileSizeBytes);
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(0)} KB';
    if (total < 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDownloads = ref.watch(downloadsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penyimpanan Offline'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: asyncDownloads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(downloadsListProvider),
          ),
        ),
        data: (downloads) {
          if (downloads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download_outlined,
                      size: 56,
                      color: AppColors.textMuted(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada episode offline',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap icon ⬇ di Detail anime untuk simpan offline.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Total summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sd_storage_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${downloads.length} episode tersimpan',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total ${_totalSize(downloads)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...downloads.map((d) => _DownloadCard(entry: d)),
            ],
          );
        },
      ),
    );
  }
}

class _DownloadCard extends ConsumerWidget {
  const _DownloadCard({required this.entry});

  final DownloadEntry entry;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    Haptic.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(
          'Hapus dari offline?',
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          '${entry.animeTitle} EP ${entry.episodeNumber} (${entry.fileSizeFormatted}) akan dihapus.',
          style: GoogleFonts.roboto(
            fontSize: 12,
            color: AppColors.textMuted(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(downloadRepositoryProvider)
        .delete(entry.animeId, entry.episodeId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.playerPath(entry.animeId.toString(), entry.episodeId),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: entry.coverImage.isEmpty
                      ? Container(color: AppColors.surface(context))
                      : CachedNetworkImage(
                          imageUrl: entry.coverImage,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.animeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EP ${entry.episodeNumber.toString().padLeft(2, '0')} · ${entry.fileSizeFormatted}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.offline_pin_rounded,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Siap offline',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, ref),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted(context),
                ),
                tooltip: 'Hapus',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
