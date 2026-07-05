import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../data/download_repository.dart';
import '../../../core/theme/app_radius.dart';

/// Dialog modal yang nge-download episode + show progress real-time.
///
/// **Lifecycle:**
/// 1. Dialog kebuka — start download via repo
/// 2. Listen stream `DownloadProgress` → update UI tiap chunk
/// 3. Selesai → show "Selesai!" + close button
/// 4. Error → show "Gagal" + retry/close
/// 5. User tap "Batalkan" → cancel via [CancelToken]
///
/// **Return value:**
/// - `true` kalau download sukses
/// - `false` kalau cancel / error
class DownloadDialog extends ConsumerStatefulWidget {
  const DownloadDialog({
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.animeTitle,
    required this.episodeTitle,
    required this.coverImage,
    required this.sourceUrl,
    super.key,
  });

  final int animeId;
  final String episodeId;
  final int episodeNumber;
  final String animeTitle;
  final String episodeTitle;
  final String coverImage;
  final String sourceUrl;

  /// Show dialog. Return true kalau berhasil.
  static Future<bool> show({
    required BuildContext context,
    required int animeId,
    required String episodeId,
    required int episodeNumber,
    required String animeTitle,
    required String episodeTitle,
    required String coverImage,
    required String sourceUrl,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DownloadDialog(
        animeId: animeId,
        episodeId: episodeId,
        episodeNumber: episodeNumber,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
        coverImage: coverImage,
        sourceUrl: sourceUrl,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<DownloadDialog> {
  final _cancelToken = CancelToken();
  DownloadProgress? _progress;
  String? _errorMessage;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    final repo = ref.read(downloadRepositoryProvider);
    final stream = repo.downloadVideo(
      animeId: widget.animeId,
      episodeId: widget.episodeId,
      episodeNumber: widget.episodeNumber,
      animeTitle: widget.animeTitle,
      episodeTitle: widget.episodeTitle,
      coverImage: widget.coverImage,
      sourceUrl: widget.sourceUrl,
      cancelToken: _cancelToken,
    );

    stream.listen(
      (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isDone = true);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = e is DioException
              ? (e.message ?? 'Network error')
              : e.toString();
        });
      },
    );
  }

  void _cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('User cancelled');
    }
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    if (!_cancelToken.isCancelled && !_isDone) {
      _cancelToken.cancel('Dialog disposed');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final fraction = p?.fraction ?? 0;
    final receivedMb = (p?.received ?? 0) / (1024 * 1024);
    final totalMb = (p?.total ?? 0) / (1024 * 1024);

    return Dialog(
      backgroundColor: AppColors.surfaceElevated(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _errorMessage != null
                      ? Icons.error_outline_rounded
                      : (_isDone
                            ? Icons.check_circle_rounded
                            : Icons.download_rounded),
                  color: _errorMessage != null
                      ? AppColors.error
                      : (_isDone ? AppColors.success : AppColors.primary),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage != null
                        ? 'Download gagal'
                        : (_isDone
                              ? 'Download selesai'
                              : 'Mengunduh episode...'),
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.animeTitle} · EP ${widget.episodeNumber.toString().padLeft(2, '0')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: GoogleFonts.roboto(fontSize: 12, color: AppColors.error),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tiny),
                child: LinearProgressIndicator(
                  value: _isDone ? 1.0 : (fraction > 0 ? fraction : null),
                  minHeight: 6,
                  backgroundColor: AppColors.surface(context),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p == null
                        ? 'Mempersiapkan...'
                        : '${receivedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  Text(
                    _isDone
                        ? '100%'
                        : '${(fraction * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isDone)
                  FilledButton(
                    onPressed: () {
                      AppSnackbar.success(context, 'Episode tersimpan offline');
                      Navigator.of(context).pop(true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface(context),
                    ),
                    child: const Text('Selesai'),
                  )
                else if (_errorMessage != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Tutup',
                      style: GoogleFonts.roboto(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _cancel,
                    child: Text(
                      'Batalkan',
                      style: GoogleFonts.roboto(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
