import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../shared/models/anime.dart';
import '../../../../shared/models/episode.dart';
import '../../../downloads/data/download_option.dart';
import '../../../downloads/data/download_repository.dart';
import '../../../downloads/presentation/download_dialog.dart';
import '../../../history/presentation/history_providers.dart';
import '../../../player/data/streaming_repository.dart';
import '../../../../core/theme/app_radius.dart';

/// Big "Lanjut · EP X" button + tombol download functional.
///
/// **Download behavior:**
/// - Fetch stream payloads untuk episode active
/// - Filter ke source non-YouTube (YouTube punya DRM + ToS, tidak bisa
///   di-download legally)
/// - Kalau ada source .mp4 → show DownloadDialog dengan progress
/// - Kalau cuma YouTube → snackbar warning
/// - Kalau sudah pernah di-download → icon berubah jadi check + tap = info
class WatchNowButton extends ConsumerWidget {
  const WatchNowButton({
    required this.animeId,
    required this.anime,
    required this.episodes,
    super.key,
  });

  final int animeId;
  final Anime anime;
  final List<Episode> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(latestHistoryForAnimeProvider(animeId));
    final hasResume = history != null && !history.isFinished;
    final targetEpisode = hasResume
        ? history.episodeId
        : (episodes.isNotEmpty ? episodes.first.id : null);
    final epNumber = hasResume
        ? history.episodeNumber
        : (episodes.isNotEmpty ? episodes.first.number : 1);

    // Cek apakah episode yang akan di-download (current target) sudah pernah
    // di-download. Show check icon kalau ya.
    final downloadedEntry = targetEpisode == null
        ? null
        : ref.watch(
            downloadEntryProvider((animeId: animeId, episodeId: targetEpisode)),
          );
    final isDownloaded = downloadedEntry != null;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: targetEpisode == null
                  ? null
                  : () => context.push(
                      AppRoutes.playerPath(animeId.toString(), targetEpisode),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    hasResume
                        ? 'Lanjut · EP ${epNumber.toString().padLeft(2, '0')}'
                        : 'Mulai · EP 01',
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Download button (functional)
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDownloaded
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.surfaceElevated(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDownloaded
                  ? AppColors.success
                  : AppColors.borderColor(context),
            ),
          ),
          child: IconButton(
            onPressed: targetEpisode == null
                ? null
                : () => _handleDownload(
                    context,
                    ref,
                    targetEpisode,
                    epNumber,
                    isDownloaded ? downloadedEntry : null,
                  ),
            icon: Icon(
              isDownloaded
                  ? Icons.check_circle_outline_rounded
                  : Icons.download_outlined,
              color: isDownloaded
                  ? AppColors.success
                  : AppColors.textMuted(context),
            ),
            tooltip: isDownloaded
                ? 'Sudah ter-download'
                : 'Download untuk offline',
          ),
        ),
      ],
    );
  }

  /// Tap handler: cek sudah didownload, kalau belum fetch sources & start.
  Future<void> _handleDownload(
    BuildContext context,
    WidgetRef ref,
    String episodeId,
    int episodeNumber,
    dynamic existing,
  ) async {
    Haptic.medium();

    if (existing != null) {
      // Sudah pernah di-download — confirm hapus.
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated(context),
          title: Text(
            'Hapus download?',
            style: GoogleFonts.roboto(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          content: Text(
            'EP ${episodeNumber.toString().padLeft(2, '0')} akan dihapus dari penyimpanan offline.',
            style: GoogleFonts.roboto(
              fontSize: 13,
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
              child: Text(context.l10n.commonDelete),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(downloadRepositoryProvider).delete(animeId, episodeId);
      if (!context.mounted) return;
      AppSnackbar.success(context, 'Download dihapus');
      return;
    }

    // Belum di-download — fetch payloads, pilih source non-YouTube.
    AppSnackbar.info(context, 'Mencari source download...');
    try {
      final repo = ref.read(streamingRepositoryProvider);
      final animeTitle = (anime.englishTitle?.isNotEmpty ?? false)
          ? anime.englishTitle!
          : anime.title;
      // Judul alternatif (romaji/native/title) → match-rate download sama
      // dengan player (otomatis lintas anime, tanpa input).
      final altTitles = <String>[
        anime.romajiTitle ?? '',
        anime.nativeTitle ?? '',
        anime.title,
      ].where((t) => t.isNotEmpty && t != animeTitle).toSet().toList();

      // 1) Coba opsi download multi-kualitas (Sanka `downloadUrl` → Pixeldrain).
      //    Kalau ada → tampilkan picker kualitas, lalu unduh URL pilihan.
      final options = await repo.fetchIndoDownloadOptions(
        anilistId: animeId,
        episodeNumber: episodeNumber,
        animeTitle: animeTitle,
        altTitles: altTitles,
      );
      if (!context.mounted) return;
      if (options.isNotEmpty) {
        final picked = await _showQualityPicker(context, options);
        if (picked == null || !context.mounted) return;
        // Host non-direct (Acefile/Filedon/dll) → buka di browser untuk unduh.
        if (!picked.direct) {
          await launchUrl(
            Uri.parse(picked.url),
            mode: LaunchMode.externalApplication,
          );
          if (!context.mounted) return;
          AppSnackbar.info(context, context.l10n.downloadOpenedInBrowser);
          return;
        }
        await DownloadDialog.show(
          context: context,
          animeId: animeId,
          episodeId: episodeId,
          episodeNumber: episodeNumber,
          animeTitle: anime.title,
          episodeTitle: '',
          coverImage: anime.coverImage,
          sourceUrl: picked.url,
        );
        return;
      }

      // 2) Fallback: source `.mp4` streaming (perilaku lama).
      final payloads = await repo.fetchPayloads(
        anilistId: animeId,
        episodeNumber: episodeNumber,
        episodeId: episodeId,
        youtubeTrailerId: anime.trailerYoutubeId,
        animeTitle: animeTitle,
        altTitles: altTitles,
      );

      // Filter source yang bisa di-download (bukan YouTube, bukan HLS).
      // .mp4 direct URL paling reliable.
      final downloadable = payloads.firstWhere((p) {
        if (p.isYoutube) return false;
        final source = p.primarySource;
        if (source == null) return false;
        final url = source.url.toLowerCase();
        // .mp4 ideal. HLS (.m3u8) kompleks (multi-segment), skip dulu.
        return url.contains('.mp4');
      }, orElse: () => payloads.first);

      if (downloadable.isYoutube) {
        if (!context.mounted) return;
        AppSnackbar.error(
          context,
          'YouTube tidak support download offline. Coba anime dengan source Internet Archive.',
        );
        return;
      }

      final source = downloadable.primarySource;
      if (source == null) {
        if (!context.mounted) return;
        AppSnackbar.error(context, 'Source download tidak tersedia.');
        return;
      }

      if (!context.mounted) return;
      await DownloadDialog.show(
        context: context,
        animeId: animeId,
        episodeId: episodeId,
        episodeNumber: episodeNumber,
        animeTitle: anime.title,
        episodeTitle: '',
        coverImage: anime.coverImage,
        sourceUrl: source.url,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.error(context, 'Gagal mulai download: $e');
    }
  }

  /// Bottom-sheet pilih kualitas unduhan. Return [DownloadOption] terpilih,
  /// atau null kalau dibatalkan.
  Future<DownloadOption?> _showQualityPicker(
    BuildContext context,
    List<DownloadOption> options,
  ) {
    Haptic.light();
    return showModalBottomSheet<DownloadOption>(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderColor(ctx),
                borderRadius: BorderRadius.circular(AppRadius.tiny),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ctx.l10n.downloadChooseQuality,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
              ),
            ),
            for (final opt in options)
              ListTile(
                leading: Icon(
                  opt.direct
                      ? Icons.download_rounded
                      : Icons.open_in_new_rounded,
                  color: opt.direct
                      ? AppColors.primary
                      : AppColors.textMuted(ctx),
                ),
                title: Text(
                  opt.quality,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
                subtitle: Text(
                  opt.direct
                      ? opt.host
                      : '${opt.host} · ${ctx.l10n.downloadViaBrowser}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textMuted(ctx),
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(opt),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
