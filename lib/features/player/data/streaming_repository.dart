import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/constants.dart';
import '../../../core/config/env.dart';
import '../../../core/settings/subtitle_language.dart';
import '../../downloads/data/download_option.dart';
import '../../../core/utils/youtube_url.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/stream_source.dart';
import 'indo_anime_client.dart';
import 'miruro_client.dart';
import 'video_catalog_repository.dart';

/// Abstraksi sumber streaming dengan **3-layer + multi-source fallback**:
///
/// ```
/// Layer 1: Supabase video catalog (multi-source per episode)
///   ├─ priority 1 (mis. youtube/Muse Asia)
///   ├─ priority 2 (mis. archive_org backup)
///   └─ priority 3 (mis. r2 self-host)
///         ↓ semua gagal
/// Layer 2: AniList YouTube trailer
///         ↓ tidak ada trailer
/// Layer 3: Mux sample HLS (final fallback)
/// ```
///
/// Player coba payload satu per satu sampai ada yang play sukses.
///
/// Contract:
/// - [buildEpisodes] sintesa list episode dari `episodeCount` AniList
/// - [fetchPayloads] return ordered list of [StreamPayload] untuk player coba
abstract class StreamingRepository {
  /// Sintesa list [Episode] berdasar `episodeCount` AniList.
  ///
  /// Kalau `episodeCount` null (anime ongoing), pakai default
  /// [EpisodeConstants.fallbackEpisodeCount].
  List<Episode> buildEpisodes({
    required int anilistId,
    required int? episodeCount,
  });

  /// Fetch ordered list of [StreamPayload] candidates untuk player coba.
  ///
  /// Player akan render payload di index 0 dulu; kalau error/gagal,
  /// switch ke index berikutnya. List dijamin **non-empty** (minimum
  /// satu Mux fallback).
  ///
  /// ```dart
  /// final payloads = await repo.fetchPayloads(
  ///   anilistId: 4082,
  ///   episodeNumber: 1,
  ///   episodeId: 'ep-4082-1',
  ///   youtubeTrailerId: 'abc123',
  /// );
  /// // [StreamPayload(youtubeId: 'abc'), StreamPayload(sources: [archive.org]), ...]
  /// ```
  Future<List<StreamPayload>> fetchPayloads({
    required int anilistId,
    required int episodeNumber,
    required String episodeId,
    String? youtubeTrailerId,
    String animeTitle = '',
    List<String> altTitles = const [],
  });

  /// Pilihan **download** per kualitas (sub Indo, host direct/Pixeldrain) untuk
  /// satu episode. List kosong = tak ada opsi → caller fallback ke stream `.mp4`.
  Future<List<DownloadOption>> fetchIndoDownloadOptions({
    required int anilistId,
    required int episodeNumber,
    String animeTitle = '',
    List<String> altTitles = const [],
  });
}

/// Implementasi default — composes [VideoCatalogRepository] + API Indo (Sanka)
/// + Miruro + AniList trailer + Mux fallback ke single fallback chain.
///
/// **Urutan render player (default = index 0):**
/// 1. Supabase `video_sources` (manual catalog, priority-ranked — override admin)
/// 2. **Sanka (sub Indo) — PRIMARY** (Samehadaku/Otakudesu, auto by judul)
/// 3. Sankanime embed (sub Indo, opsional via `.env`)
/// 4. **Miruro (EN) — SECONDARY** (M3U8 + intro/outro; user bisa pilih English)
/// 5. AniList YouTube trailer (kalau ada)
/// 6. Mux sample HLS (final fallback — selalu available)
///
/// User memilih sub Indo / English lewat source picker di player.
class CompositeStreamingRepository implements StreamingRepository {
  /// Construct dengan dependency injection.
  CompositeStreamingRepository(this._catalog, this._indoApi, this._miruro);

  final VideoCatalogRepository _catalog;
  final IndoAnimeClient _indoApi;
  final MiruroClient _miruro;

  /// Source situs Indonesia yang dicoba berurutan (sub Indo).
  static const _indoSources = <(String id, String label)>[
    ('samehadaku', 'Samehadaku'),
    ('otakudesu', 'Otakudesu'),
  ];

  @override
  List<Episode> buildEpisodes({
    required int anilistId,
    required int? episodeCount,
  }) {
    final count = episodeCount ?? EpisodeConstants.fallbackEpisodeCount;
    return List.generate(count, (i) {
      final number = i + 1;
      return Episode(
        id: 'ep-$anilistId-$number',
        number: number,
        title: 'Episode $number',
      );
    });
  }

  @override
  Future<List<StreamPayload>> fetchPayloads({
    required int anilistId,
    required int episodeNumber,
    required String episodeId,
    String? youtubeTrailerId,
    String animeTitle = '',
    List<String> altTitles = const [],
  }) async {
    // **Fetch semua source dinamis PARALEL.** Future dibuat duluan (sebelum
    // await apa pun) supaya jalan bersamaan — total waktu ≈ source paling
    // lambat, bukan jumlah semua. Tiap source di-wrap timeout + catch
    // (`_guard`) jadi satu mirror yang hang/error tidak menunda yang lain.
    final catalogF = _guardList(
      () => _fetchCatalogPayloads(anilistId, episodeNumber),
    );
    final miruroF = _guardOne(
      () => _fetchMiruroPayload(anilistId, episodeNumber),
    );
    final indoFs = animeTitle.trim().isEmpty
        ? const <Future<StreamPayload?>>[]
        : _indoSources
              .map(
                (s) => _guardOne(
                  () => _fetchIndoPayload(
                    anilistId: anilistId,
                    animeTitle: animeTitle,
                    altTitles: altTitles,
                    episodeNumber: episodeNumber,
                    sourceId: s.$1,
                    label: s.$2,
                  ),
                ),
              )
              .toList();

    // Kumpulkan hasil — **Sanka/Indo (sub Indo) PRIMARY, Miruro (EN) SECONDARY**.
    // Urutan: catalog (override admin) → indo[samehadaku, otakudesu] (Sanka) →
    // sankanime embed → miruro (EN) → youtube → mux. Default play = index 0
    // (sub Indo); user bisa pilih English (Miruro) lewat source picker.
    final catalog = await catalogF;
    final miruro = await miruroF;
    final indo = await Future.wait(indoFs);

    // Grup sub Indo (Sanka/Samehadaku/Otakudesu + Sankanime embed) vs English
    // (Miruro). Urutan ditentukan preferensi user [SubtitlePref] → source utama
    // (index 0, auto-play) ikut pilihan; sisanya tetap pickable di player.
    final indoGroup = <StreamPayload>[
      for (final p in indo) ?p,
      ?_buildSankanimeEmbed(animeTitle, episodeNumber),
    ];
    final enGroup = <StreamPayload>[?miruro];
    final preferEnglish = SubtitlePref.current == SubtitleLanguage.english;

    final payloads = <StreamPayload>[
      ...catalog,
      if (preferEnglish) ...enGroup,
      ...indoGroup,
      if (!preferEnglish) ...enGroup,
    ];

    // ── Layer 2: AniList YouTube trailer (kalau ada) ───────────────────
    if (youtubeTrailerId != null && youtubeTrailerId.isNotEmpty) {
      payloads.add(
        StreamPayload(
          youtubeVideoId: youtubeTrailerId,
          sourceId: 'youtube_trailer',
          sourceLabel: 'YouTube Trailer',
        ),
      );
    }

    // ── Layer 3: Mux sample HLS (final fallback, ALWAYS added) ─────────
    payloads.add(_muxFallbackPayload());

    return payloads;
  }

  @override
  Future<List<DownloadOption>> fetchIndoDownloadOptions({
    required int anilistId,
    required int episodeNumber,
    String animeTitle = '',
    List<String> altTitles = const [],
  }) async {
    if (animeTitle.trim().isEmpty) return const [];
    // Coba sumber Indo berurutan (samehadaku → otakudesu); ambil yang pertama
    // punya opsi. Tiap fetch dibatasi timeout + di-catch (no-op kalau gagal).
    for (final (sourceId, _) in _indoSources) {
      final opts = await _guardList(
        () => _indoApi.fetchDownloadOptions(
          anilistId: anilistId,
          animeTitle: animeTitle,
          altTitles: altTitles,
          episodeNumber: episodeNumber,
          source: sourceId,
        ),
      );
      if (opts.isNotEmpty) return opts;
    }
    return const [];
  }

  /// Wrap fetch yang return list (catalog/download options) dengan timeout +
  /// catch. Gagal/timeout → list kosong (chain lanjut ke source lain).
  Future<List<T>> _guardList<T>(Future<List<T>> Function() task) async {
    try {
      return await task().timeout(TimingConstants.sourceFetchTimeout);
    } catch (e) {
      debugPrint('🎬 [guard:list] gagal: $e');
      return <T>[];
    }
  }

  /// Wrap fetch yang return satu payload (miruro/indo) dengan timeout + catch.
  /// Gagal/timeout → null.
  Future<StreamPayload?> _guardOne(
    Future<StreamPayload?> Function() task,
  ) async {
    try {
      return await task().timeout(TimingConstants.sourceFetchTimeout);
    } catch (e) {
      debugPrint('🎬 [guard:source] gagal: $e');
      return null;
    }
  }

  /// Layer 1: Supabase video catalog (multi-source, priority-ranked).
  Future<List<StreamPayload>> _fetchCatalogPayloads(
    int anilistId,
    int episodeNumber,
  ) async {
    final sources = await _catalog.fetchSources(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    final out = <StreamPayload>[];
    for (final source in sources) {
      final payload = _payloadFromSource(source);
      if (payload != null) out.add(payload);
    }
    return out;
  }

  /// Layer 1.5a: Miruro-API (M3U8 langsung, sub EN, by AniList ID).
  /// Di-skip otomatis kalau MIRURO_API_URL kosong (client return null).
  Future<StreamPayload?> _fetchMiruroPayload(
    int anilistId,
    int episodeNumber,
  ) async {
    final m = await _miruro.fetch(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    if (m == null || m.isEmpty) return null;
    return StreamPayload(
      sources: m.sources,
      subtitles: m.subtitles,
      headers: m.headers,
      sourceId: 'miruro',
      sourceLabel: 'Miruro (EN)',
      introStart: m.introStart,
      introEnd: m.introEnd,
      outroStart: m.outroStart,
      outroEnd: m.outroEnd,
    );
  }

  /// Layer 1.5b: wajik-anime-api (Otakudesu/Samehadaku, sub Indo). Cari by
  /// judul → resolve episodeId → ambil stream. Hasil bisa direct (.mp4/.m3u8)
  /// atau embed (iframe → WebView).
  Future<StreamPayload?> _fetchIndoPayload({
    required int anilistId,
    required String animeTitle,
    required List<String> altTitles,
    required int episodeNumber,
    required String sourceId,
    required String label,
  }) async {
    final result = await _indoApi.fetchSources(
      anilistId: anilistId,
      animeTitle: animeTitle,
      altTitles: altTitles,
      episodeNumber: episodeNumber,
      source: sourceId,
    );
    if (result == null || result.isEmpty) return null;
    return StreamPayload(
      sources: result.sources,
      subtitles: result.subtitles,
      headers: result.headers,
      embedUrl: result.embedUrl,
      sourceId: sourceId,
      sourceLabel: label,
    );
  }

  /// Layer 1.5c: Sankanime (sub Indo) sebagai **WebView embed**. Sankanime
  /// adalah SPA Cloudflare tanpa API publik, jadi URL tonton dibangun dari
  /// template `.env` ([Env.sankanimeEmbedTemplate]) — placeholder
  /// `{slug}`/`{title}`/`{ep}`. Referer di-set ke origin sankanime supaya
  /// embed mau load. Return null kalau template/judul kosong.
  StreamPayload? _buildSankanimeEmbed(String animeTitle, int episodeNumber) {
    if (!Env.isSankanimeConfigured) return null;
    final title = animeTitle.trim();
    if (title.isEmpty) return null;

    final url = Env.sankanimeEmbedTemplate
        .replaceAll('{slug}', _slugify(title))
        .replaceAll('{title}', Uri.encodeComponent(title))
        .replaceAll('{ep}', episodeNumber.toString());

    final origin = Uri.tryParse(url)?.origin;
    return StreamPayload(
      embedUrl: url,
      headers: origin == null ? const {} : {'Referer': origin},
      sourceId: 'sankanime',
      sourceLabel: 'Sankanime (ID)',
    );
  }

  /// Judul → kebab-case slug (lowercase, non-alfanumerik jadi `-`, trim `-`).
  static String _slugify(String input) {
    final lower = input.toLowerCase();
    final dashed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return dashed.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Convert single [VideoSource] ke [StreamPayload].
  ///
  /// Logic per source type:
  /// - `youtube` → return [StreamPayload] dengan `youtubeVideoId` (extract dari URL)
  /// - lainnya → return [StreamPayload] dengan direct URL playback
  ///
  /// Return null kalau YouTube URL invalid (tidak bisa di-extract ID-nya).
  StreamPayload? _payloadFromSource(VideoSource source) {
    if (source.isYoutubeSource) {
      final videoId = extractYoutubeId(source.videoUrl);
      if (videoId == null) return null; // Invalid YouTube URL — skip
      return StreamPayload(youtubeVideoId: videoId);
    }

    // Direct URL playback (archive_org, cloudflare_r2, mux, manual)
    return StreamPayload(
      sources: [
        StreamSource(
          url: source.videoUrl,
          type: _detectVideoType(source.videoUrl),
          quality: source.quality,
        ),
      ],
      subtitles: source.subtitleUrl == null
          ? const []
          : [
              SubtitleTrack(
                url: source.subtitleUrl!,
                language: source.language,
              ),
            ],
    );
  }

  /// Build payload Mux sample HLS (final fallback).
  ///
  /// Selalu tersedia — Mux test stream stabil dan tidak akan kena DMCA.
  StreamPayload _muxFallbackPayload() {
    return StreamPayload(
      sources: [
        StreamSource(url: Env.sampleStreamUrl, type: 'hls', quality: 'auto'),
      ],
      subtitles: const [
        SubtitleTrack(
          url: UrlConstants.muxSampleSubtitleUrl,
          language: 'English',
        ),
      ],
      sourceId: 'mux_sample',
      sourceLabel: 'Mux Sample',
    );
  }

  /// Detect tipe video dari extension URL.
  ///
  /// `m3u8` → HLS adaptive bitrate (better_player needs videoFormat hint)
  /// `mp4` → progressive download
  /// lainnya → unknown (player akan auto-detect)
  String _detectVideoType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'hls';
    if (lower.contains('.mp4')) return 'mp4';
    return 'unknown';
  }
}

/// Riverpod provider untuk [StreamingRepository].
///
/// Compose dengan [videoCatalogRepositoryProvider] sebagai dependency.
final streamingRepositoryProvider = Provider<StreamingRepository>((ref) {
  return CompositeStreamingRepository(
    ref.watch(videoCatalogRepositoryProvider),
    ref.watch(indoAnimeClientProvider),
    ref.watch(miruroClientProvider),
  );
});
