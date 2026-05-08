import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/stream_source.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../../history/data/history_entry.dart';
import '../../history/data/history_repository.dart';
import 'player_providers.dart';
import 'widgets/episode_picker_grid.dart';
import 'widgets/player_metadata_row.dart';

/// PlayerScreen punya state internal:
/// - `_currentEpisodeId`: episode aktif (bisa berubah saat user tap episode lain)
/// - `_useHlsFallback`: flag kalau YouTube error (mis. error 150)
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.animeId,
    required this.episodeId,
    super.key,
  });

  final String animeId;
  final String episodeId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late String _currentEpisodeId;
  bool _useHlsFallback = false;

  @override
  void initState() {
    super.initState();
    _currentEpisodeId = widget.episodeId;
  }

  void _onYoutubeError() {
    if (mounted && !_useHlsFallback) {
      setState(() => _useHlsFallback = true);
    }
  }

  void _switchEpisode(String newEpisodeId) {
    if (newEpisodeId == _currentEpisodeId) return;
    setState(() {
      _currentEpisodeId = newEpisodeId;
      _useHlsFallback = false; // reset, episode baru bisa jadi punya trailer
    });
  }

  @override
  Widget build(BuildContext context) {
    final animeId = int.tryParse(widget.animeId) ?? 0;
    final args = (animeId: animeId, episodeId: _currentEpisodeId);
    final asyncPayload = ref.watch(streamPayloadProvider(args));
    final asyncAnime = ref.watch(animeDetailProvider(animeId));
    final asyncEps = ref.watch(animeEpisodesProvider(animeId));

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: asyncPayload.when(
          loading: () => const _LoadingState(),
          error: (e, _) => Center(
            child: ErrorRetry(
              message: e.toString(),
              onRetry: () => ref.invalidate(streamPayloadProvider(args)),
            ),
          ),
          data: (payload) {
            // Forced HLS fallback mode (error 150 etc).
            final showHls = _useHlsFallback || !payload.isYoutube;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // Top: video player (16:9).
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: showHls
                        ? _HlsPlayerView(
                            payload: _useHlsFallback
                                ? _buildFallbackPayload()
                                : payload,
                            animeId: animeId,
                            episodeId: _currentEpisodeId,
                            episodeNumber: _resolveEpisodeNumber(asyncEps),
                          )
                        : _YoutubePlayerView(
                            videoId: payload.youtubeVideoId!,
                            animeId: animeId,
                            episodeId: _currentEpisodeId,
                            episodeNumber: _resolveEpisodeNumber(asyncEps),
                            onError: _onYoutubeError,
                          ),
                  ),
                ),

                // Metadata row.
                asyncAnime.when(
                  loading: () => const SizedBox(height: 64),
                  error: (_, _) => const SizedBox(height: 64),
                  data: (anime) => PlayerMetadataRow(
                    anime: anime,
                    episodeNumber: _resolveEpisodeNumber(asyncEps),
                    onBack: () => context.pop(),
                  ),
                ),

                // Source badge.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SourceBadge(
                    isYoutube: !showHls,
                    isFallback: _useHlsFallback,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(
                    color: AppColors.surfaceDarkElevated, height: 1),

                // "Tentang Episode" section.
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
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _stripHtml(anime.description!),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
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

                // "Daftar Episode" section.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    'Daftar Episode',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                asyncEps.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (eps) => EpisodePickerGrid(
                    episodes: eps,
                    activeEpisodeId: _currentEpisodeId,
                    onTap: (ep) => _switchEpisode(ep.id),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build payload manual untuk fallback (tanpa lewat repository, supaya
  /// pasti pakai sample stream dari Env).
  StreamPayload _buildFallbackPayload() {
    return StreamPayload(
      sources: [
        StreamSource(
          url: Env.sampleStreamUrl,
          type: 'hls',
          quality: 'auto',
        ),
      ],
      subtitles: const [
        SubtitleTrack(
          url: 'https://test-streams.mux.dev/captions/captions_en.vtt',
          language: 'English',
        ),
      ],
    );
  }

  int _resolveEpisodeNumber(AsyncValue eps) {
    final list = eps.valueOrNull;
    if (list == null) return 1;
    final found =
        list.cast<dynamic>().where((e) => e.id == _currentEpisodeId).toList();
    if (found.isEmpty) return 1;
    return found.first.number as int;
  }

  static final _htmlRegex = RegExp(r'<[^>]*>');
  static String _stripHtml(String input) =>
      input.replaceAll(_htmlRegex, '').replaceAll('&nbsp;', ' ').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Source badge
// ─────────────────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isYoutube, required this.isFallback});

  final bool isYoutube;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    if (isFallback) {
      return _badge(
        '⚠️ Trailer di-block oleh pemilik. Menampilkan sample stream.',
        AppColors.warning,
      );
    }
    if (isYoutube) {
      return _badge('🎬 YouTube Trailer Official', AppColors.primary);
    }
    return _badge('📺 Sample Stream (HLS)', AppColors.warning);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouTube Player
// ─────────────────────────────────────────────────────────────────────────────

class _YoutubePlayerView extends ConsumerStatefulWidget {
  const _YoutubePlayerView({
    required this.videoId,
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.onError,
  });

  final String videoId;
  final int animeId;
  final String episodeId;
  final int episodeNumber;
  final VoidCallback onError;

  @override
  ConsumerState<_YoutubePlayerView> createState() => _YoutubePlayerViewState();
}

class _YoutubePlayerViewState extends ConsumerState<_YoutubePlayerView> {
  late final YoutubePlayerController _controller;
  DateTime _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _errorFired = false;

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

  void _onTick() {
    // Detect error → trigger fallback to HLS.
    if (_controller.value.errorCode != 0 && !_errorFired) {
      _errorFired = true;
      widget.onError();
      return;
    }

    if (!_controller.value.isReady) return;
    final now = DateTime.now();
    if (now.difference(_lastSavedAt).inSeconds < 5) return;
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
// HLS Player (BetterPlayer)
// ─────────────────────────────────────────────────────────────────────────────

class _HlsPlayerView extends ConsumerStatefulWidget {
  const _HlsPlayerView({
    required this.payload,
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
  });

  final StreamPayload payload;
  final int animeId;
  final String episodeId;
  final int episodeNumber;

  @override
  ConsumerState<_HlsPlayerView> createState() => _HlsPlayerViewState();
}

class _HlsPlayerViewState extends ConsumerState<_HlsPlayerView> {
  BetterPlayerController? _controller;
  DateTime _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final source = widget.payload.primarySource;
    if (source == null) return;

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

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
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
        startAt: history?.position,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enableSubtitles: true,
          enableQualities: true,
          enablePlaybackSpeed: true,
          enableFullscreen: true,
          enableSkips: true,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    _controller!.addEventsListener(_onPlayerEvent);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType != BetterPlayerEventType.progress) return;
    final progress = event.parameters?['progress'];
    final duration = event.parameters?['duration'];
    if (progress is! Duration) return;

    final now = DateTime.now();
    if (now.difference(_lastSavedAt).inSeconds < 5) return;
    _lastSavedAt = now;
    _saveProgress(progress, duration is Duration ? duration : null);
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
    _saveOnExit();
    _controller?.removeEventsListener(_onPlayerEvent);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const _LoadingState(message: 'Tidak ada source tersedia');
    }
    return BetterPlayer(controller: _controller!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
            Text(
              message!,
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

