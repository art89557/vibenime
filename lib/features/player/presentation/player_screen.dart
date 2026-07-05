import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/config/constants.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../data/episode_report_repository.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/stream_source.dart';
import '../../../shared/widgets/error_retry.dart';
import '../data/aniskip_client.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../../favorites/data/auto_status_updater.dart';
import '../../history/data/history_entry.dart';
import '../../history/data/history_repository.dart';
import '../../history/presentation/history_providers.dart';
import 'player_providers.dart';
import 'player_session.dart';
import 'widgets/episode_picker_grid.dart';
import 'widgets/playback_controller.dart';
import 'widgets/player_controls_overlay.dart';
import 'widgets/player_metadata_row.dart';
import '../../../core/theme/app_radius.dart';

/// Layar player video dengan **multi-source auto-fallback**.
///
/// State internal:
/// - [_currentEpisodeId]: episode aktif (bisa berubah saat user tap episode lain
///   dari grid di bawah player)
/// - [_currentSourceIndex]: index payload mana yang lagi di-coba dari list
///   `streamPayloadsProvider`. Kalau YouTube error / video 404 / dll, naik
///   ke index berikutnya untuk re-init player.
///
/// Source type ditentukan dari [StreamPayload.isYoutube] — render
/// `YoutubePlayer` atau `BetterPlayer` accordingly.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.animeId,
    required this.episodeId,
    super.key,
  });

  /// AniList anime ID (string karena dari URL path).
  final String animeId;

  /// Episode ID — format `ep-{anilistId}-{number}`.
  final String episodeId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late String _currentEpisodeId;
  int _currentSourceIndex = 0;

  /// True kalau source aktif = video native (better_player). Hanya source ini
  /// yang bisa di-mini saat back; di-set tiap build dari currentPayload.
  bool _currentIsNative = false;

  /// Back dari player: kalau video native sedang hidup → kecilkan ke mini bar
  /// (PiP), video lanjut main. Selain itu → tutup sesi + pop biasa.
  void _handleBack() {
    final notifier = ref.read(playerSessionProvider.notifier);
    if (_currentIsNative && notifier.hasController) {
      notifier.minimize();
    } else {
      notifier.close();
    }
    if (mounted) context.pop();
  }

  /// True kalau SEMUA source di chain sudah dicoba & gagal → tampilkan error
  /// terminal (stop bikin player baru / retry loop tak berujung, mis. Miruro
  /// 500 atau CDN 403). Di-reset saat ganti episode / pilih source manual.
  bool _allSourcesFailed = false;

  @override
  void initState() {
    super.initState();
    _currentEpisodeId = widget.episodeId;
  }

  /// Dipanggil saat current source error. Naik ke source berikutnya
  /// (kalau ada). Kalau sudah di source terakhir, do nothing — player
  /// akan show error UI sendiri.
  void _onSourceError(int totalSources) {
    if (!mounted) return;
    if (_currentSourceIndex < totalSources - 1) {
      setState(() => _currentSourceIndex += 1);
    } else {
      // Source terakhir pun gagal → semua sudah dicoba. Masuk state error
      // terminal supaya player tidak terus di-recreate (loop Init→Release).
      setState(() => _allSourcesFailed = true);
    }
  }

  /// Dipanggil saat user tap episode lain di grid. Reset source index
  /// karena episode baru punya fallback chain sendiri.
  void _switchEpisode(String newEpisodeId) {
    if (newEpisodeId == _currentEpisodeId) return;
    setState(() {
      _currentEpisodeId = newEpisodeId;
      _currentSourceIndex = 0;
      _allSourcesFailed = false;
    });
  }

  /// Cari episode berikutnya (number + 1) dari list. Null kalau sudah terakhir.
  Episode? _nextEpisode(AsyncValue<dynamic> asyncEps, int currentNumber) {
    final list = asyncEps.valueOrNull as List<Episode>?;
    if (list == null) return null;
    for (final e in list) {
      if (e.number == currentNumber + 1) return e;
    }
    return null;
  }

  void _goToNextEpisode(AsyncValue<dynamic> asyncEps, int currentNumber) {
    final next = _nextEpisode(asyncEps, currentNumber);
    if (next == null) return;
    Haptic.medium();
    _switchEpisode(next.id);
  }

  /// Dipanggil saat playback selesai (video habis). Kalau autoNext ON dan
  /// ada episode berikutnya → otomatis lanjut.
  void _onPlaybackComplete(AsyncValue<dynamic> asyncEps, int currentNumber) {
    final autoNext = ref.read(appSettingsProvider).autoNext;
    if (!autoNext) return;
    _goToNextEpisode(asyncEps, currentNumber);
  }

  /// Share judul + link AniList episode.
  Future<void> _shareEpisode({
    required int animeId,
    required dynamic anime,
    required int episodeNumber,
  }) async {
    Haptic.light();
    final title = (anime?.title as String?) ?? 'Anime';
    final url = 'https://anilist.co/anime/$animeId';
    await Share.share(
      'Nonton "$title" Episode $episodeNumber di VibeNime!\n$url',
    );
  }

  /// Tampilkan sheet pilih alasan → kirim laporan episode rusak ke Supabase.
  Future<void> _reportBrokenEpisode({
    required int animeId,
    required int episodeNumber,
    String? animeTitle,
    String? sourceId,
  }) async {
    Haptic.light();
    const reasons = <(String value, String label)>[
      ('tidak_main', 'Video tidak main / loading terus'),
      ('salah_episode', 'Episode yang muncul salah'),
      ('lainnya', 'Masalah lain'),
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Laporkan episode rusak',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                ),
              ),
            ),
            for (final (value, label) in reasons)
              ListTile(
                title: Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textOnDark,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(value),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (reason == null) return;

    final ok = await ref
        .read(episodeReportRepositoryProvider)
        .report(
          anilistId: animeId,
          episodeNumber: episodeNumber,
          animeTitle: animeTitle,
          sourceId: sourceId,
          reason: reason,
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Laporan terkirim. Terima kasih!');
    } else {
      AppSnackbar.info(context, 'Gagal mengirim — pastikan kamu sudah login.');
    }
  }

  /// Pindah ke source tertentu secara manual (lewat picker). Reset error
  /// flag supaya kalau ada masalah dengan source baru, fallback chain
  /// tetap jalan dari index ini.
  void _selectSource(int newIndex, List<StreamPayload> payloads) {
    if (newIndex == _currentSourceIndex) return;
    Haptic.medium();
    setState(() {
      _currentSourceIndex = newIndex;
      _allSourcesFailed = false;
    });

    // Persist user pilihan via selectedSourceProvider supaya reorder
    // payload list di provider — sehingga refetch (mis. ganti episode)
    // tetap pakai source yang sama.
    final picked = payloads[newIndex];
    final sourceId = picked.sourceId;
    if (sourceId != null) {
      final animeId = int.tryParse(widget.animeId) ?? 0;
      ref.read(selectedSourceProvider(animeId).notifier).state = sourceId;
    }
  }

  /// Tampilkan bottom sheet untuk pilih source video manual.
  ///
  /// User bisa lihat semua source available + tap pilih satu. Source yang
  /// lagi aktif ke-highlight dengan border cyan + checkmark.
  Future<void> _showSourcePicker(
    BuildContext context,
    List<StreamPayload> payloads,
    int activeIndex,
  ) async {
    Haptic.light();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDarkElevated,
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.tiny),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih Source',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
                  Text(
                    '${payloads.length} tersedia',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.textOnDarkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < payloads.length; i++)
              _SourceOption(
                payload: payloads[i],
                index: i,
                isActive: i == activeIndex,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _selectSource(i, payloads);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animeId = int.tryParse(widget.animeId) ?? 0;
    final args = (animeId: animeId, episodeId: _currentEpisodeId);

    // Ganti Bahasa Subtitle (Indo/English) di Settings → refresh player yang
    // sedang aktif: reset ke source utama sesuai preferensi baru + refetch.
    // Buang juga override manual supaya urutan preferensi yang dipakai.
    ref.listen(appSettingsProvider.select((s) => s.subtitleLanguage), (
      prev,
      next,
    ) {
      if (prev == next) return;
      ref.read(selectedSourceProvider(animeId).notifier).state = null;
      if (mounted) {
        setState(() {
          _currentSourceIndex = 0;
          _allSourcesFailed = false;
        });
      }
      ref.invalidate(streamPayloadsProvider(args));
    });

    final asyncPayloads = ref.watch(streamPayloadsProvider(args));
    final asyncAnime = ref.watch(animeDetailProvider(animeId));
    final asyncEps = ref.watch(animeEpisodesProvider(animeId));

    return PopScope(
      // Intercept back: video native → minimize ke mini bar (PiP), bukan pop.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SafeArea(
          child: asyncPayloads.when(
            loading: () => const _LoadingState(),
            error: (e, _) => Center(
              child: ErrorRetry(
                message: e.toString(),
                onRetry: () => ref.invalidate(streamPayloadsProvider(args)),
              ),
            ),
            data: (payloads) {
              if (payloads.isEmpty || _allSourcesFailed) {
                return _PlaybackErrorView(
                  onBack: _handleBack,
                  onRetry: () {
                    setState(() {
                      _allSourcesFailed = false;
                      _currentSourceIndex = 0;
                    });
                    ref.invalidate(streamPayloadsProvider(args));
                  },
                  onReport: () => _reportBrokenEpisode(
                    animeId: animeId,
                    episodeNumber: _resolveEpisodeNumber(asyncEps),
                    animeTitle: asyncAnime.valueOrNull?.title,
                  ),
                );
              }

              // Clamp index supaya tidak out-of-bounds (defensive).
              final safeIndex = _currentSourceIndex.clamp(
                0,
                payloads.length - 1,
              );
              final currentPayload = payloads[safeIndex];
              // Hanya video native (bukan YouTube/embed) yang bisa di-mini.
              _currentIsNative =
                  !currentPayload.isYoutube && !currentPayload.isEmbed;
              final episodeNumber = _resolveEpisodeNumber(asyncEps);
              final episodeTitle = _resolveEpisodeTitle(asyncEps);

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Player area (16:9) ───────────────────────────────
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      // Key: re-init player saat payload index berubah.
                      child: KeyedSubtree(
                        key: ValueKey('payload-$safeIndex-$_currentEpisodeId'),
                        child: currentPayload.isYoutube
                            ? _YoutubePlayerView(
                                videoId: currentPayload.youtubeVideoId!,
                                animeId: animeId,
                                episodeId: _currentEpisodeId,
                                episodeNumber: episodeNumber,
                                onError: () => _onSourceError(payloads.length),
                                onCompleted: () => _onPlaybackComplete(
                                  asyncEps,
                                  episodeNumber,
                                ),
                              )
                            : currentPayload.isEmbed
                            ? _WebViewPlayerView(
                                embedUrl: currentPayload.embedUrl!,
                                headers: currentPayload.headers,
                                onError: () => _onSourceError(payloads.length),
                              )
                            : _HlsPlayerView(
                                payload: currentPayload,
                                animeId: animeId,
                                episodeId: _currentEpisodeId,
                                episodeNumber: episodeNumber,
                                title:
                                    asyncAnime.valueOrNull?.displayTitle ??
                                    'VibeNime',
                                coverImage:
                                    asyncAnime.valueOrNull?.coverImage ?? '',
                                onBack: _handleBack,
                                onNextEpisode:
                                    _nextEpisode(asyncEps, episodeNumber) !=
                                        null
                                    ? () => _goToNextEpisode(
                                        asyncEps,
                                        episodeNumber,
                                      )
                                    : null,
                                malId: asyncAnime.valueOrNull?.idMal,
                                autoSkip: ref.watch(
                                  appSettingsProvider.select((s) => s.autoSkip),
                                ),
                                onError: () => _onSourceError(payloads.length),
                                onCompleted: () => _onPlaybackComplete(
                                  asyncEps,
                                  episodeNumber,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // ── Metadata row (back + cover thumb + title + meta) ─
                  asyncAnime.when(
                    loading: () => const SizedBox(height: 64),
                    error: (_, _) => const SizedBox(height: 64),
                    data: (anime) => PlayerMetadataRow(
                      anime: anime,
                      episodeNumber: episodeNumber,
                      episodeTitle: episodeTitle,
                      onBack: _handleBack,
                    ),
                  ),

                  // ── Source picker badge + tombol lapor episode rusak ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _SourceBadge(
                          payload: currentPayload,
                          sourceIndex: safeIndex,
                          totalSources: payloads.length,
                          onTap: payloads.length > 1
                              ? () => _showSourcePicker(
                                  context,
                                  payloads,
                                  safeIndex,
                                )
                              : null,
                        ),
                        const Spacer(),
                        // Next episode (kalau ada episode berikutnya)
                        if (_nextEpisode(asyncEps, episodeNumber) != null)
                          _PlayerActionButton(
                            icon: Icons.skip_next_rounded,
                            label: 'Next',
                            onTap: () =>
                                _goToNextEpisode(asyncEps, episodeNumber),
                          ),
                        _PlayerActionButton(
                          icon: Icons.ios_share_rounded,
                          label: 'Share',
                          onTap: () => _shareEpisode(
                            animeId: animeId,
                            anime: asyncAnime.valueOrNull,
                            episodeNumber: episodeNumber,
                          ),
                        ),
                        _PlayerActionButton(
                          icon: Icons.flag_outlined,
                          label: 'Lapor',
                          onTap: () => _reportBrokenEpisode(
                            animeId: animeId,
                            episodeNumber: episodeNumber,
                            animeTitle: asyncAnime.valueOrNull?.title,
                            sourceId: currentPayload.sourceId,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(
                    color: AppColors.surfaceDarkElevated,
                    height: 1,
                  ),

                  // ── Synopsis section (truncated) ────────────────────
                  asyncAnime.maybeWhen(
                    data: (anime) {
                      if (anime.description == null ||
                          anime.description!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tentang Episode',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _stripHtml(anime.description!),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textOnDarkMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // ── Episode picker grid ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Daftar Episode',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  asyncEps.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (eps) {
                      final watched = ref.watch(
                        watchedEpisodeIdsProvider(animeId),
                      );
                      final epProgress = ref.watch(
                        episodeProgressProvider(animeId),
                      );
                      // Cap unreleased: ambil dari nextAiringEpisode kalau
                      // anime detail sudah load.
                      final maxReleased = asyncAnime.maybeWhen(
                        data: (a) => a.nextAiringEpisode != null
                            ? a.nextAiringEpisode!.episode - 1
                            : null,
                        orElse: () => null,
                      );
                      return EpisodePickerGrid(
                        episodes: eps,
                        activeEpisodeId: _currentEpisodeId,
                        watchedIds: watched,
                        progress: epProgress,
                        maxReleasedEpisode: maxReleased,
                        onTap: (ep) => _switchEpisode(ep.id),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Cari nomor episode dari current `_currentEpisodeId`.
  /// Default 1 kalau tidak match.
  int _resolveEpisodeNumber(AsyncValue eps) {
    final list = eps.valueOrNull;
    if (list == null) return 1;
    final found = list
        .cast<dynamic>()
        .where((e) => e.id == _currentEpisodeId)
        .toList();
    if (found.isEmpty) return 1;
    return found.first.number as int;
  }

  /// Cari title episode dari current `_currentEpisodeId`. Null kalau tidak ada.
  String? _resolveEpisodeTitle(AsyncValue eps) {
    final list = eps.valueOrNull;
    if (list == null) return null;
    final found = list
        .cast<dynamic>()
        .where((e) => e.id == _currentEpisodeId)
        .toList();
    if (found.isEmpty) return null;
    return found.first.title as String?;
  }

  /// Strip HTML tags dari sinopsis AniList (kadang ada `<i>`, `<br>`, dll).
  static final _htmlRegex = RegExp(r'<[^>]*>');
  static String _stripHtml(String input) =>
      input.replaceAll(_htmlRegex, '').replaceAll('&nbsp;', ' ').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// _SourceBadge — display source ke-N dari M
// ─────────────────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.payload,
    required this.sourceIndex,
    required this.totalSources,
    this.onTap,
  });

  final StreamPayload payload;
  final int sourceIndex;
  final int totalSources;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isYoutube = payload.isYoutube;
    final isLocal = payload.primarySource?.isLocal ?? false;
    final isFallback = sourceIndex > 0;
    final color = isLocal
        ? AppColors.success
        : (isFallback ? AppColors.warning : AppColors.primary);

    final label = StringBuffer();
    // Prefer label dari payload (mis. "Otakudesu") kalau ada — bikin user
    // tahu source asli. Fallback ke emoji generic untuk payload tanpa tag.
    final tagged = payload.sourceLabel;
    if (tagged != null && tagged.isNotEmpty) {
      label.write(tagged);
    } else if (isLocal) {
      label.write('Offline');
    } else if (isYoutube) {
      label.write('YouTube');
    } else {
      label.write('Stream');
    }
    if (totalSources > 1) {
      label.write(' · ${sourceIndex + 1}/$totalSources');
    }
    if (isFallback && !isLocal && tagged == null) {
      label.write(' (fallback)');
    }

    // Tanpa animasi entrance (flutter_animate dihapus — diet performa).
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocal
                  ? Icons.offline_pin_rounded
                  : (isYoutube
                        ? Icons.smart_display_rounded
                        : Icons.tv_rounded),
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              label.toString(),
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.swap_horiz_rounded, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SourceOption — single tile di bottom sheet source picker
// ─────────────────────────────────────────────────────────────────────────────

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.payload,
    required this.index,
    required this.isActive,
    required this.onTap,
  });

  final StreamPayload payload;
  final int index;
  final bool isActive;
  final VoidCallback onTap;

  String get _typeLabel {
    // Prefer label dari payload (di-tag oleh streaming_repository) supaya
    // user lihat nama source asli: "Otakudesu" / "Samehadaku" / "YouTube".
    final label = payload.sourceLabel;
    if (label != null && label.isNotEmpty) {
      return payload.isEmbed ? '$label (embed)' : label;
    }
    if (payload.isEmbed) return 'Web Embed';

    // Fallback ke URL-based detection (untuk payload tanpa label, mis.
    // admin-curated Supabase catalog yang belum di-tag).
    if (payload.primarySource?.isLocal ?? false) return 'Offline';
    if (payload.isYoutube) return 'YouTube';
    final url = payload.primarySource?.url ?? '';
    if (url.contains('.m3u8')) return 'HLS Stream';
    if (url.contains('archive.org')) return 'Internet Archive';
    if (url.contains('mux.dev')) return 'Mux Sample';
    return 'Direct MP4';
  }

  IconData get _typeIcon {
    // Icon-by-sourceId (lebih akurat per source) → fallback heuristik
    switch (payload.sourceId) {
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
    }
    if (payload.primarySource?.isLocal ?? false) {
      return Icons.offline_pin_rounded;
    }
    if (payload.isYoutube) return Icons.play_circle_filled_rounded;
    final url = payload.primarySource?.url ?? '';
    if (url.contains('.m3u8')) return Icons.stream_rounded;
    return Icons.movie_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final qualityLabel = payload.primarySource?.quality;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _typeIcon,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textOnDarkMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Source ${index + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppColors.textOnDarkMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (qualityLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDarkHigh,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.tiny,
                                ),
                              ),
                              child: Text(
                                qualityLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: AppColors.textOnDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _typeLabel,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.textOnDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _YoutubePlayerView — render full episode YouTube (Muse Asia, Ani-One, dll)
// ─────────────────────────────────────────────────────────────────────────────

class _YoutubePlayerView extends ConsumerStatefulWidget {
  const _YoutubePlayerView({
    required this.videoId,
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.onError,
    required this.onCompleted,
  });

  final String videoId;
  final int animeId;
  final String episodeId;
  final int episodeNumber;

  /// Callback saat YouTube player error (mis. error 150 — embed disabled).
  /// Parent akan switch ke source berikutnya.
  final VoidCallback onError;

  /// Callback saat video selesai (untuk auto-next).
  final VoidCallback onCompleted;

  @override
  ConsumerState<_YoutubePlayerView> createState() => _YoutubePlayerViewState();
}

class _YoutubePlayerViewState extends ConsumerState<_YoutubePlayerView> {
  late final YoutubePlayerController _controller;
  DateTime _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _errorFired = false;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    final history = ref
        .read(historyRepositoryProvider)
        .get(widget.animeId, widget.episodeId);

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        startAt: history?.positionSeconds ?? 0,
        enableCaption: true,
      ),
    );
    _controller.addListener(_onTick);
  }

  /// Listener YouTube player — handle error + simpan progress.
  void _onTick() {
    // Detect error → trigger fallback ke source berikutnya.
    if (_controller.value.errorCode != 0 && !_errorFired) {
      _errorFired = true;
      widget.onError();
      return;
    }

    // Video selesai → auto-next.
    if (_controller.value.playerState == PlayerState.ended &&
        !_completedFired) {
      _completedFired = true;
      widget.onCompleted();
      return;
    }

    if (!_controller.value.isReady) return;

    // Throttle save: tidak lebih sering dari interval konstanta.
    final now = DateTime.now();
    if (now.difference(_lastSavedAt) <
        TimingConstants.playerProgressSaveInterval) {
      return;
    }
    _lastSavedAt = now;

    final pos = _controller.value.position;
    final dur = _controller.metadata.duration;
    if (pos.inSeconds < 3) return;

    final entry = HistoryEntry(
      animeId: widget.animeId,
      episodeId: widget.episodeId,
      episodeNumber: widget.episodeNumber,
      positionSeconds: pos.inSeconds,
      durationSeconds: dur.inSeconds > 0 ? dur.inSeconds : null,
      watchedAt: DateTime.now(),
    );
    ref.read(historyRepositoryProvider).save(entry);
    // Sync status FavoriteEntry kalau anime ini ada di list.
    // Best-effort; tidak boleh block save() flow.
    ref
        .read(autoStatusUpdaterProvider)
        .onHistorySaved(widget.animeId)
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: true,
      progressIndicatorColor: AppColors.primary,
      progressColors: const ProgressBarColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.secondary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HlsPlayerView — render direct video URL (.mp4 / .m3u8) via better_player
// ─────────────────────────────────────────────────────────────────────────────

class _HlsPlayerView extends ConsumerStatefulWidget {
  const _HlsPlayerView({
    required this.payload,
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.onError,
    required this.onCompleted,
    required this.title,
    required this.coverImage,
    required this.onBack,
    this.onNextEpisode,
    this.malId,
    this.autoSkip = false,
  });

  final StreamPayload payload;
  final int animeId;
  final String episodeId;
  final int episodeNumber;

  /// Judul anime + cover (untuk mini bar) + callback navigasi overlay kustom.
  final String title;
  final String coverImage;
  final VoidCallback onBack;
  final VoidCallback? onNextEpisode;

  /// Callback saat BetterPlayer exception (mis. 404, network, codec error).
  final VoidCallback onError;

  /// Callback saat video selesai (untuk auto-next).
  final VoidCallback onCompleted;

  /// MAL id untuk fallback AniSkip (kalau payload tak punya intro/outro sendiri).
  final int? malId;

  /// Auto-skip intro/outro tanpa tombol (dari Settings).
  final bool autoSkip;

  @override
  ConsumerState<_HlsPlayerView> createState() => _HlsPlayerViewState();
}

class _HlsPlayerViewState extends ConsumerState<_HlsPlayerView> {
  BetterPlayerController? _controller;
  BetterPlayerPlayback? _playback;
  DateTime _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _errorFired = false;
  bool _completedFired = false;

  /// Posisi playback terkini (detik) — feed ke overlay skip intro/outro.
  final ValueNotifier<double> _positionSec = ValueNotifier(0);

  /// Hasil AniSkip (fallback kalau payload tak punya intro/outro). Lazy-fetch.
  SkipTimes? _aniskip;
  bool _aniskipFetched = false;

  // Effective skip times: payload (Miruro) diutamakan, else AniSkip.
  double? get _introStart => widget.payload.introStart ?? _aniskip?.opStart;
  double? get _introEnd => widget.payload.introEnd ?? _aniskip?.opEnd;
  double? get _outroStart => widget.payload.outroStart ?? _aniskip?.edStart;
  double? get _outroEnd => widget.payload.outroEnd ?? _aniskip?.edEnd;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final notifier = ref.read(playerSessionProvider.notifier);

    // Re-expand dari mini bar: controller untuk episode ini masih hidup →
    // adopt, jangan recreate (playback tidak ke-reset).
    if (notifier.hasControllerFor(widget.animeId, widget.episodeId)) {
      _controller = notifier.controller;
      _playback = notifier.playback;
      _controller!.addEventsListener(_onPlayerEvent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notifier.markFull();
      });
      return;
    }

    final source = widget.payload.primarySource;
    if (source == null) return;

    // Episode lama (kalau ada) di-tutup setelah controller baru siap.
    final hadOld = notifier.hasController;

    final history = ref
        .read(historyRepositoryProvider)
        .get(widget.animeId, widget.episodeId);

    final subtitleSources = widget.payload.subtitles
        .map(
          (t) => BetterPlayerSubtitlesSource(
            type: BetterPlayerSubtitlesSourceType.network,
            urls: [t.url],
            name: t.language ?? 'Subtitle',
            selectedByDefault:
                t.language?.toLowerCase().contains('indo') ?? false,
          ),
        )
        .toList();

    // Ukuran font subtitle sesuai preferensi user (untuk source soft-sub).
    final subFontSize = ref.read(appSettingsProvider).subtitleSize.fontSize;

    final dataSource = BetterPlayerDataSource(
      // Local file (downloaded offline) atau network URL.
      source.isLocal
          ? BetterPlayerDataSourceType.file
          : BetterPlayerDataSourceType.network,
      source.url,
      videoFormat: source.isHls ? BetterPlayerVideoFormat.hls : null,
      subtitles: subtitleSources,
      headers: widget.payload.headers,
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        looping: false,
        // PiP: jangan dispose controller saat BetterPlayer widget unmount
        // (pindah host route↔mini bar). Dispose hanya manual via
        // PlayerSessionNotifier.close() (forceDispose: true).
        autoDispose: false,
        startAt: history?.position,
        // Kontrol bawaan disembunyikan untuk mode inline — diganti
        // PlayerControlsOverlay kustom. Saat fullscreen, adapter mengaktifkan
        // kembali kontrol bawaan (lihat BetterPlayerPlayback.enterFullscreen).
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
        subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(
          fontSize: subFontSize,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    _controller!.addEventsListener(_onPlayerEvent);
    _playback = BetterPlayerPlayback(_controller!);

    // Daftarkan ke session global (pemilik tunggal) — setelah frame untuk
    // hindari modifikasi provider saat build. Tutup controller episode lama.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hadOld) notifier.close();
      notifier.register(
        controller: _controller!,
        playback: _playback!,
        animeId: widget.animeId,
        episodeId: widget.episodeId,
        episodeNumber: widget.episodeNumber,
        title: widget.title,
        coverImage: widget.coverImage,
      );
    });
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    // Handle error → fallback ke source berikutnya.
    if (event.betterPlayerEventType == BetterPlayerEventType.exception &&
        !_errorFired) {
      _errorFired = true;
      widget.onError();
      return;
    }

    // Video selesai → auto-next.
    if (event.betterPlayerEventType == BetterPlayerEventType.finished &&
        !_completedFired) {
      _completedFired = true;
      widget.onCompleted();
      return;
    }

    if (event.betterPlayerEventType != BetterPlayerEventType.progress) return;
    final progress = event.parameters?['progress'];
    final duration = event.parameters?['duration'];
    if (progress is! Duration) return;

    // Feed posisi ke overlay skip (murah, tanpa setState).
    _positionSec.value = progress.inSeconds.toDouble();
    _maybeFetchAniSkip(duration is Duration ? duration : null);

    final now = DateTime.now();
    if (now.difference(_lastSavedAt) <
        TimingConstants.playerProgressSaveInterval) {
      return;
    }
    _lastSavedAt = now;
    _saveProgress(progress, duration is Duration ? duration : null);
  }

  /// Lazy-fetch AniSkip sekali — hanya kalau payload TIDAK punya intro/outro
  /// sendiri (mis. bukan source Miruro) dan ada MAL id.
  void _maybeFetchAniSkip(Duration? duration) {
    if (_aniskipFetched) return;
    if (widget.payload.hasIntro || widget.payload.hasOutro) return;
    final mal = widget.malId;
    if (mal == null || mal <= 0) return;
    _aniskipFetched = true;
    ref
        .read(aniSkipClientProvider)
        .fetch(
          malId: mal,
          episodeNumber: widget.episodeNumber,
          episodeLengthSeconds: duration?.inSeconds ?? 0,
        )
        .then((s) {
          if (mounted && !s.isEmpty) setState(() => _aniskip = s);
        });
  }

  Future<void> _saveProgress(Duration position, Duration? duration) async {
    final entry = HistoryEntry(
      animeId: widget.animeId,
      episodeId: widget.episodeId,
      episodeNumber: widget.episodeNumber,
      positionSeconds: position.inSeconds,
      durationSeconds: duration?.inSeconds,
      watchedAt: DateTime.now(),
    );
    await ref.read(historyRepositoryProvider).save(entry);
    // Sync status FavoriteEntry kalau anime ini ada di list.
    await ref
        .read(autoStatusUpdaterProvider)
        .onHistorySaved(widget.animeId)
        .catchError((_) {});
  }

  Future<void> _saveOnExit() async {
    final position =
        _controller?.videoPlayerController?.value.position ?? Duration.zero;
    final duration = _controller?.videoPlayerController?.value.duration;
    if (position.inSeconds < 3) return;
    await _saveProgress(position, duration);
  }

  @override
  void dispose() {
    final notifier = ref.read(playerSessionProvider.notifier);
    final minimizing =
        ref.read(playerSessionProvider).phase == PlayerPhase.minimized;
    _saveOnExit();
    _positionSec.dispose();
    _controller?.removeEventsListener(_onPlayerEvent);
    if (minimizing) {
      // PiP: serahkan surface ke mini bar. Controller & playback TETAP hidup
      // (dimiliki session) → video lanjut main.
      notifier.setVideoInRoute(false);
    } else if (notifier.hasController) {
      // Tutup sesi penuh → session dispose controller + playback.
      notifier.close();
    } else {
      // Belum sempat ke-register (mis. error sebelum register) → dispose lokal.
      // forceDispose karena config autoDispose:false.
      _playback?.dispose();
      _controller?.dispose(forceDispose: true);
    }
    super.dispose();
  }

  void _seekTo(double seconds) {
    _controller?.seekTo(Duration(seconds: seconds.round()));
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _playback == null) {
      return const _LoadingState(message: 'Tidak ada source tersedia');
    }
    return Stack(
      children: [
        BetterPlayer(controller: _controller!),
        // Overlay kontrol kustom (play/±10/seek/speed/quality/fullscreen).
        Positioned.fill(
          child: PlayerControlsOverlay(
            controller: _playback!,
            title: widget.title,
            episodeNumber: widget.episodeNumber,
            onBack: widget.onBack,
            onNextEpisode: widget.onNextEpisode,
          ),
        ),
        // Tombol Skip Intro/Outro (selalu di atas, walau kontrol hilang).
        Positioned(
          right: 12,
          bottom: 72,
          child: _SkipButton(
            position: _positionSec,
            introStart: _introStart,
            introEnd: _introEnd,
            outroStart: _outroStart,
            outroEnd: _outroEnd,
            autoSkip: widget.autoSkip,
            onSeek: _seekTo,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SkipButton — tombol "Skip Intro/Outro" yang muncul saat posisi playback
// masuk rentang intro/outro. Data dari Miruro (payload) atau AniSkip (fallback).
// ─────────────────────────────────────────────────────────────────────────────

class _SkipButton extends StatefulWidget {
  const _SkipButton({
    required this.position,
    required this.onSeek,
    required this.autoSkip,
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });

  final ValueListenable<double> position;
  final void Function(double seconds) onSeek;
  final bool autoSkip;
  final double? introStart;
  final double? introEnd;
  final double? outroStart;
  final double? outroEnd;

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _introSkipped = false;
  bool _outroSkipped = false;

  /// Return label + target seek kalau posisi dalam rentang intro/outro.
  (String label, double target)? _active(double pos) {
    final iS = widget.introStart, iE = widget.introEnd;
    if (iS != null && iE != null && pos >= iS && pos < iE) {
      return ('Skip Intro', iE);
    }
    final oS = widget.outroStart, oE = widget.outroEnd;
    if (oS != null && oE != null && pos >= oS && pos < oE) {
      return ('Skip Outro', oE);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.position,
      builder: (context, pos, _) {
        final active = _active(pos);
        if (active == null) return const SizedBox.shrink();

        // Auto-skip: lompat sekali per segmen (intro/outro).
        if (widget.autoSkip) {
          final isIntro = active.$1 == 'Skip Intro';
          if (isIntro && !_introSkipped) {
            _introSkipped = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.onSeek(active.$2),
            );
            return const SizedBox.shrink();
          }
          if (!isIntro && !_outroSkipped) {
            _outroSkipped = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.onSeek(active.$2),
            );
            return const SizedBox.shrink();
          }
        }

        return Material(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            onTap: () {
              Haptic.light();
              widget.onSeek(active.$2);
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    active.$1,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.skip_next_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WebViewPlayerView — render embed iframe (Otakudesu/Samehadaku host) via
// WebView. Dipakai saat source hanya kasih embed, bukan direct .mp4/.m3u8.
// ─────────────────────────────────────────────────────────────────────────────

class _WebViewPlayerView extends StatefulWidget {
  const _WebViewPlayerView({
    required this.embedUrl,
    required this.headers,
    required this.onError,
  });

  final String embedUrl;
  final Map<String, String> headers;

  /// Callback saat WebView gagal load → parent switch ke source berikutnya.
  final VoidCallback onError;

  @override
  State<_WebViewPlayerView> createState() => _WebViewPlayerViewState();
}

class _WebViewPlayerViewState extends State<_WebViewPlayerView> {
  WebViewController? _controller;
  bool _errorFired = false;

  /// Embed iframe hanya didukung di mobile (Android/iOS). Di web/desktop
  /// plugin webview_flutter tidak jalan / sering diblok CORS.
  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Host asal embed — untuk membatasi navigasi (cegah popup/redirect iklan).
  String get _embedHost => Uri.tryParse(widget.embedUrl)?.host ?? '';

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _initWebView();
    }
  }

  void _initWebView() {
    final referer = widget.headers['Referer'] ?? widget.headers['referer'];
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Izinkan load awal + resource di host yang sama. Blok redirect ke
            // domain lain (umumnya popup iklan / page host yang buka tab baru).
            final targetHost = Uri.tryParse(request.url)?.host ?? '';
            if (targetHost.isEmpty ||
                targetHost == _embedHost ||
                targetHost.endsWith(_embedHost) ||
                _embedHost.endsWith(targetHost)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            // Hanya error main-frame yang fatal → fallback. Subresource (iklan
            // yang ke-blok) jangan trigger fallback.
            if (error.isForMainFrame ?? false) _fireError();
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.embedUrl),
        headers: referer == null ? const {} : {'Referer': referer},
      );
    _controller = controller;
  }

  void _fireError() {
    if (_errorFired || !mounted) return;
    _errorFired = true;
    widget.onError();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) {
      // Web/desktop: embed tidak didukung → pesan jelas, user pilih source lain.
      return const _PlayerMessage(
        icon: Icons.devices_rounded,
        message:
            'Source ini (embed) hanya bisa diputar di perangkat mobile.\n'
            'Pilih source lain dari tombol di bawah, atau buka di HP.',
      );
    }
    if (_controller == null) {
      return const _LoadingState();
    }
    return WebViewWidget(controller: _controller!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _PlayerActionButton — tombol aksi kecil (Next / Share / Lapor) di bawah player
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerActionButton extends StatelessWidget {
  const _PlayerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: GoogleFonts.roboto(fontSize: 11)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textOnDarkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: GoogleFonts.roboto(color: Colors.white70)),
          ],
        ],
      ),
    );
  }
}

/// State error terminal — semua source untuk episode ini gagal diputar.
/// Mengganti player area (16:9) supaya tidak terjebak loop retry tak berujung.
/// Tombol: Coba Lagi (re-fetch source) · Laporkan · Back.
class _PlaybackErrorView extends StatelessWidget {
  const _PlaybackErrorView({
    required this.onRetry,
    required this.onReport,
    required this.onBack,
  });

  final VoidCallback onRetry;
  final VoidCallback onReport;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.warning,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Source gagal diputar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Semua source untuk episode ini gagal. Coba lagi, '
                  'atau pilih episode lain.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textOnDarkMuted,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surfaceDark,
                    minimumSize: const Size(200, 46),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Laporkan episode rusak'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textOnDarkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textOnDark,
            ),
          ),
        ),
      ],
    );
  }
}
