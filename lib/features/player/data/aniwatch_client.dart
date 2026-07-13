import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../shared/models/stream_source.dart';
import 'miruro_client.dart' show MiruroResult;

/// Client untuk **aniwatch-api** (github.com/ghoshRitesh12/aniwatch-api) —
/// pembungkus HiAnime yang balas **M3U8 + subtitle .vtt + intro/outro**, sub
/// English. Wajib **self-host** (Docker `ghcr.io/ghoshritesh12/aniwatch`) —
/// tak ada demo publik andal. Env-gated `ANIWATCH_API_URL`; kosong = di-skip.
///
/// Situs pakai **slug HiAnime** (bukan AniList ID), jadi resolve by judul —
/// mirror pola [IndoAnimeClient]: multi-judul (english→romaji→native) + varian
/// + best-match token-overlap, tahan 5xx, cache in-memory.
///
/// **Alur 3-step** (envelope `{success, data}`):
/// 1. `GET /api/v2/hianime/search?q={judul}` → `data.animes[].id` (slug),
///    `.name`. Pilih match terbaik.
/// 2. `GET /api/v2/hianime/anime/{id}/episodes` → `data.episodes[]`, cari
///    `episodeId` untuk `number == episodeNumber`.
/// 3. `GET /api/v2/hianime/episode/sources?animeEpisodeId={epId}&server=hd-1&category=sub`
///    → `data.sources[]` (m3u8, `type`), `data.tracks[]` (`file` .vtt +
///    `label`/`kind`), `data.intro`/`outro`, `data.headers` (Referer CDN).
///
/// Hasil dibungkus [MiruroResult] (HLS + subtitle + intro/outro + headers) →
/// streaming_repository sudah tahu cara convert-nya ke `StreamPayload`.
class AniwatchClient {
  AniwatchClient(this._dio);

  final Dio _dio;

  String get _base => Env.aniwatchApiUrl;

  /// Prefix endpoint HiAnime v2 (dari README aniwatch-api).
  static const _api = '/api/v2/hianime';

  /// Maks query search berbeda per (anime, episode) — batasi beban + latency.
  static const _maxSearchQueries = 4;

  /// Cache: `{anilistId}:{episodeNumber}` → episodeId.
  final _episodeIdCache = <String, String>{};

  /// Cache: `{judul-ternormalisasi}` → animeId (slug HiAnime).
  final _animeIdCache = <String, String>{};

  /// Fetch streaming untuk [animeTitle] episode [episodeNumber].
  /// [altTitles] = judul alternatif (romaji/native) untuk naikkan match-rate.
  /// [preferDub] → ambil kategori `dub` (fallback `sub`). Return `null` kalau
  /// tak ter-konfigurasi / semua kandidat gagal.
  Future<MiruroResult?> fetch({
    required int anilistId,
    required String animeTitle,
    required int episodeNumber,
    List<String> altTitles = const [],
    bool preferDub = false,
  }) async {
    if (!Env.isAniwatchConfigured) return null;
    final candidates = _titleCandidates(animeTitle, altTitles);
    if (candidates.isEmpty) return null;

    try {
      final episodeId = await _resolveEpisodeId(
        anilistId: anilistId,
        candidates: candidates,
        episodeNumber: episodeNumber,
      );
      if (episodeId == null) return null;

      return await _fetchSources(
        episodeId: episodeId,
        category: preferDub ? 'dub' : 'sub',
      );
    } catch (e) {
      debugPrint('🎬 [aniwatch] gagal: $e');
      return null;
    }
  }

  /// Ping ringan untuk "membangunkan" instance yang tidur (fire-and-forget).
  Future<void> warmup() async {
    if (!Env.isAniwatchConfigured) return;
    try {
      await _dio.get<dynamic>(
        '$_base$_api/home',
        options: Options(
          receiveTimeout: const Duration(seconds: 3),
          validateStatus: (_) => true,
        ),
      );
    } catch (_) {
      /* fire-and-forget */
    }
  }

  // ─── Step 1+2: resolve episodeId (dengan cache) ─────────────────────────

  Future<String?> _resolveEpisodeId({
    required int anilistId,
    required List<String> candidates,
    required int episodeNumber,
  }) async {
    final cacheKey = '$anilistId:$episodeNumber';
    final cached = _episodeIdCache[cacheKey];
    if (cached != null) return cached;

    // Coba tiap kandidat judul sampai ketemu slug + episodeId. Tiap kandidat
    // diisolasi try/catch → satu judul yang bikin API error (500/timeout) tak
    // mematikan kandidat berikutnya yang valid.
    for (final title in candidates) {
      try {
        final animeId = await _searchAnimeId(title);
        if (animeId == null) continue;

        final episodeId = await _findEpisodeId(
          animeId: animeId,
          episodeNumber: episodeNumber,
        );
        if (episodeId != null) {
          _episodeIdCache[cacheKey] = episodeId;
          return episodeId;
        }
      } catch (e) {
        debugPrint('🎬 [aniwatch] kandidat "$title" error: $e — lanjut');
      }
    }
    return null;
  }

  /// Step 1 — `GET /search?q={title}` → slug hasil terbaik (token-overlap).
  Future<String?> _searchAnimeId(String title) async {
    final normalized = title.trim().toLowerCase();
    final cached = _animeIdCache[normalized];
    if (cached != null) return cached;

    final res = await _dio.get<dynamic>(
      '$_base$_api/search',
      queryParameters: {'q': title, 'page': 1},
      options: _opts,
    );
    final data = _dataObject(res);
    final animes = data?['animes'] as List?;
    debugPrint(
      '🎬 [aniwatch] search "$title" → status=${res.statusCode} '
      'hits=${animes?.length ?? 'null(body ${res.data.runtimeType})'}',
    );
    if (animes == null || animes.isEmpty) return null;

    // Pilih match TERBAIK (token-overlap) — kurangi salah anime saat search
    // balikkan banyak kandidat. Di bawah ambang → fallback hasil pertama.
    final entries = animes.cast<Map<String, dynamic>>();
    final queryTokens = _tokens(title);
    Map<String, dynamic> best = entries.first;
    double bestScore = -1;
    int bestExtra =
        1 << 30; // tie-break: makin sedikit token ekstra makin mirip
    for (final e in entries) {
      final cand = _tokens((e['name'] as String?) ?? '');
      final score = _titleScore(queryTokens, cand);
      if (score > bestScore ||
          (score == bestScore && cand.length < bestExtra)) {
        bestScore = score;
        bestExtra = cand.length;
        best = e;
      }
    }
    final picked = bestScore >= 0.34 ? best : entries.first;
    final id = picked['id'] as String?;
    if (id != null && id.isNotEmpty) _animeIdCache[normalized] = id;
    return id;
  }

  /// Step 2 — `GET /anime/{id}/episodes` → episodeId untuk episode ke-N.
  Future<String?> _findEpisodeId({
    required String animeId,
    required int episodeNumber,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_base$_api/anime/$animeId/episodes',
      options: _opts,
    );
    final data = _dataObject(res);
    final episodes = data?['episodes'] as List?;
    debugPrint(
      '🎬 [aniwatch] anime/$animeId/episodes → status=${res.statusCode} '
      'eps=${episodes?.length ?? 'null'}',
    );
    if (episodes == null || episodes.isEmpty) return null;

    final eps = episodes.cast<Map<String, dynamic>>();
    for (final ep in eps) {
      final epNum = (ep['number'] as num?)?.toInt();
      final epId = (ep['episodeId'] as String?) ?? '';
      if (epNum == episodeNumber && epId.isNotEmpty) return epId;
    }

    // Fallback: list biasanya ascending (episode 1 di index 0).
    final idx = episodeNumber - 1;
    if (idx >= 0 && idx < eps.length) {
      final epId = eps[idx]['episodeId'] as String?;
      if (epId != null && epId.isNotEmpty) return epId;
    }
    return null;
  }

  // ─── Step 3: fetch sources (HLS) + subtitle + intro/outro ──────────────

  Future<MiruroResult?> _fetchSources({
    required String episodeId,
    required String category,
  }) async {
    // Coba kategori diminta dulu, lalu kategori lain (sub↔dub).
    for (final cat in [category, category == 'sub' ? 'dub' : 'sub']) {
      final result = await _fetchSourcesFor(
        episodeId: episodeId,
        category: cat,
      );
      if (result != null && !result.isEmpty) return result;
    }
    return null;
  }

  Future<MiruroResult?> _fetchSourcesFor({
    required String episodeId,
    required String category,
  }) async {
    final Response<dynamic> res;
    try {
      res = await _dio.get<dynamic>(
        '$_base$_api/episode/sources',
        queryParameters: {
          'animeEpisodeId': episodeId,
          'server': 'hd-1',
          'category': category,
        },
        options: _opts,
      );
    } catch (_) {
      return null;
    }
    final data = _dataObject(res);
    if (data == null) return null;

    final sourcesRaw = data['sources'] as List?;
    if (sourcesRaw == null || sourcesRaw.isEmpty) return null;

    final sources = <StreamSource>[];
    for (final raw in sourcesRaw.cast<Map<String, dynamic>>()) {
      final url = raw['url'] as String?;
      if (url == null || url.isEmpty) continue;
      final type = (raw['type'] as String?)?.toLowerCase();
      final isHls = type == 'hls' || url.contains('.m3u8');
      final isMp4 = type == 'mp4' || url.contains('.mp4');
      if (!isHls && !isMp4) continue;
      sources.add(StreamSource(url: url, type: isHls ? 'hls' : 'mp4'));
    }
    if (sources.isEmpty) return null;

    // Header CDN: aniwatch balas `data.headers` (mis. `{Referer: ...}`). CDN
    // (megacloud/rapidcloud) cek Referer ini — tanpa-nya 403.
    final headers = <String, String>{};
    final headersRaw = _asMap(data['headers']);
    if (headersRaw != null) {
      headersRaw.forEach((k, v) {
        if (v is String && v.isNotEmpty) headers[k] = v;
      });
    }

    // Subtitle: `data.tracks[]` dengan `kind: "captions"` (buang thumbnails).
    final subtitles = <SubtitleTrack>[];
    final tracksRaw = data['tracks'] as List?;
    if (tracksRaw != null) {
      for (final raw in tracksRaw.cast<Map<String, dynamic>>()) {
        final kind = (raw['kind'] as String?)?.toLowerCase();
        if (kind == 'thumbnails') continue;
        final file = raw['file'] as String?;
        if (file == null || file.isEmpty) continue;
        subtitles.add(
          SubtitleTrack(url: file, language: raw['label'] as String?),
        );
      }
    }

    return MiruroResult(
      sources: sources,
      subtitles: subtitles,
      headers: headers,
      introStart: (_asMap(data['intro'])?['start'] as num?)?.toDouble(),
      introEnd: (_asMap(data['intro'])?['end'] as num?)?.toDouble(),
      outroStart: (_asMap(data['outro'])?['start'] as num?)?.toDouble(),
      outroEnd: (_asMap(data['outro'])?['end'] as num?)?.toDouble(),
    );
  }

  // ─── Best-match helpers (mirror IndoAnimeClient) ───────────────────────

  /// Gabung judul utama + alternatif + varian bersih jadi daftar query unik,
  /// dibatasi [_maxSearchQueries] supaya latency terjaga.
  List<String> _titleCandidates(String primary, List<String> alts) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in [primary, ...alts]) {
      for (final v in _searchVariants(raw)) {
        final key = v.toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        out.add(v);
        if (out.length >= _maxSearchQueries) return out;
      }
    }
    return out;
  }

  /// Varian judul untuk search: judul asli + tanpa klausa setelah `:` +
  /// tanpa suffix `Season N`/`Part N`/`(tahun)`. Dedupe, urut paling spesifik.
  static List<String> _searchVariants(String raw) {
    final base = raw.trim();
    if (base.isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    void add(String s) {
      final t = s.trim();
      final key = t.toLowerCase();
      if (t.isEmpty || !seen.add(key)) return;
      out.add(t);
    }

    add(base);
    if (base.contains(':')) add(base.split(':').first);
    final stripped = base
        .replaceAll(
          RegExp(
            r'\b(\d+(st|nd|rd|th)\s+season|season\s+\d+|part\s+\d+)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\(\d{4}\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    add(stripped);
    return out;
  }

  /// Token judul ternormalisasi (lowercase, hanya alfanumerik).
  static Set<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toSet();

  /// Skor kemiripan = irisan / token query (0..1).
  static double _titleScore(Set<String> query, Set<String> candidate) {
    if (query.isEmpty) return 0;
    final overlap = query.intersection(candidate).length;
    return overlap / query.length;
  }

  Options get _opts => Options(
    sendTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
    // Terima 5xx tanpa lempar → kandidat judul berikutnya tetap dicoba.
    validateStatus: (s) => s != null && s < 600,
  );

  void resetCache() {
    _episodeIdCache.clear();
    _animeIdCache.clear();
  }

  /// Expose varian judul untuk unit test.
  @visibleForTesting
  static List<String> debugSearchVariants(String raw) => _searchVariants(raw);
}

/// Cast aman ke `Map<String, dynamic>` — null kalau bukan Map.
Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// Ambil objek `data` dari envelope aniwatch (`{success, data}`) dengan aman.
Map<String, dynamic>? _dataObject(Response<dynamic> res) {
  final body = res.data;
  return body is Map ? _asMap(body['data']) : null;
}

final aniwatchClientProvider = Provider<AniwatchClient>((ref) {
  final dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ),
  );
  return AniwatchClient(dio);
});
